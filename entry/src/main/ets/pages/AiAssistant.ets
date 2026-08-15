import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { Transaction } from '../model/Transaction';
import { Repository } from '../database/Repository';
import { AiIntent, AiService } from '../database/AiService';
import { AiExecutionResult, AiExecutor } from '../database/AiExecutor';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, Permissions, bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AiIntentValidator } from '../ai/AiIntentValidator';
import {
  AiExecutionPlan,
  CONFIRMED_TRANSACTION_SCHEMA,
  ConfirmedTransactionPlan
} from '../ai/AiExecutionPlan';
import {
  CategoryInsight,
  InsightCalculator,
  InsightSummary,
  InsightTimeRange,
  MonthlyInsight
} from '../ai/InsightCalculator';
import { PageHeader } from '../components/PageHeader';
import { router, promptAction } from '@kit.ArkUI';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';

interface InsightSnapshot {
  overview: InsightSummary;
  trend: MonthlyInsight[];
}

/** 对话消息：role user/ai，kind text（普通文本）/bill（待确认账单预览） */
interface ChatMessage {
  role: string;
  text: string;
  kind: string;
}

/**
 * AI 记账与洞察。
 *
 * 写操作只开放单笔收支创建，并且必须经过结构化预览；洞察完全在本地计算。
 */
@Component
export struct AiAssistant {
  /** 数据变更回调（创建账户/记账后通知宿主刷新账户/交易/模板） */
  onDataChanged: () => void = () => {
  };
  @State mode: number = 0; // 0 一句话记账，1 消费洞察
  @State loading: boolean = false;
  @State hasData: boolean = false;
  @State analysisError: string = '';
  @State accountContextId: number = 0;
  @State scopeLabel: string = '全部账户';
  @State accounts: Account[] = [];
  @State categories: Category[] = [];
  @State currencyCodes: string[] = [];
  @State selectedCurrency: string = 'CNY';
  @State totalIncome: number = 0;
  @State totalExpense: number = 0;
  @State balance: number = 0;
  @State tips: string[] = [];
  @State categoryBreakdown: CategoryInsight[] = [];
  @State monthlyTrend: MonthlyInsight[] = [];

  @State aiInput: string = '';
  @State aiLoading: boolean = false;
  @State aiIntent: AiIntent | null = null;
  @State aiStatusText: string = '';
  @State aiStatusIsError: boolean = false;
  /** 对话式消息列表（ChatGPT 风格） */
  @State chatMessages: ChatMessage[] = [];
  @State chatInput: string = '';
  /** 待发送附件（图片 URI 列表） */
  @State chatAttachments: string[] = [];
  /** 语音输入（麦克风）状态 */
  @State isRecording: boolean = false;
  /** 录音采集器与数据 */
  private capturer: audio.AudioCapturer | null = null;
  private recordChunks: ArrayBuffer[] = [];
  private recordTimer: number | undefined = undefined;

  private repository: Repository = Repository.getInstance();
  private insightCache: Map<string, InsightSnapshot> = new Map();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['accountId'] !== undefined) {
      this.accountContextId = params['accountId'] as number;
    }
    this.analyze();
    // 欢迎消息（ChatGPT 风格）
    if (this.chatMessages.length === 0) {
      this.chatMessages = [{
        role: 'ai',
        text: '你好，我是你的记账助手。\n· 说一句"午饭35元"来记账\n· 问"这个月花了多少"查看收支洞察',
        kind: 'text'
      }];
    }
  }

  private currentMonthRange(): InsightTimeRange {
    const now = new Date();
    return {
      startInclusive: Math.floor(new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000),
      endExclusive: Math.floor(new Date(now.getFullYear(), now.getMonth() + 1, 1).getTime() / 1000)
    };
  }

  private trendRange(): InsightTimeRange {
    const now = new Date();
    return {
      startInclusive: Math.floor(new Date(now.getFullYear(), now.getMonth() - 2, 1).getTime() / 1000),
      endExclusive: Math.floor(new Date(now.getFullYear(), now.getMonth() + 1, 1).getTime() / 1000)
    };
  }

  private scopedTransactions(all: Transaction[]): Transaction[] {
    if (this.accountContextId <= 0) {
      return all;
    }
    return all.filter((transaction: Transaction) => transaction.accountId === this.accountContextId);
  }

  private transactionCurrency(transaction: Transaction): string {
    if (transaction.currency.length > 0) {
      return transaction.currency;
    }
    const account = this.accounts.find((item: Account) => item.id === transaction.accountId);
    return account ? account.currency : 'CNY';
  }

  private collectCurrencies(transactions: Transaction[]): string[] {
    const result: string[] = [];
    for (let transaction of transactions) {
      const code = this.transactionCurrency(transaction);
      if (result.indexOf(code) === -1) {
        result.push(code);
      }
    }
    if (result.length === 0) {
      const account = this.defaultAccount();
      result.push(account ? account.currency : 'CNY');
    }
    return result;
  }

  async analyze(): Promise<void> {
    this.loading = true;
    this.analysisError = '';
    try {
      const accounts = await this.repository.getAccounts();
      const categories = await this.repository.getCategories();
      const all = await this.repository.getAllTransactions();
      this.accounts = accounts;
      this.categories = categories;

      const contextAccount = accounts.find((item: Account) => item.id === this.accountContextId);
      this.scopeLabel = contextAccount ? contextAccount.label : '全部账户';

      const scoped = this.scopedTransactions(all);
      this.hasData = scoped.length > 0;
      this.currencyCodes = this.collectCurrencies(scoped);
      this.insightCache.clear();

      const currentRange = this.currentMonthRange();
      const recentRange = this.trendRange();
      for (let code of this.currencyCodes) {
        const sameCurrency = scoped.filter((transaction: Transaction) =>
          this.transactionCurrency(transaction) === code);
        const overview = InsightCalculator.calculate(sameCurrency, currentRange);
        const trend = InsightCalculator.calculate(sameCurrency, recentRange).monthlyTrend;
        const snapshot: InsightSnapshot = {
          overview: overview,
          trend: trend
        };
        this.insightCache.set(code, snapshot);
      }

      if (this.currencyCodes.indexOf(this.selectedCurrency) === -1) {
        this.selectedCurrency = this.currencyCodes[0];
      }
      this.applyInsight(this.selectedCurrency);
    } catch (error) {
      console.error('AI 洞察计算失败: ' + JSON.stringify(error));
      this.analysisError = '暂时无法读取账本数据，请稍后重试。';
      this.hasData = false;
    } finally {
      this.loading = false;
    }
  }

  private applyInsight(code: string): void {
    const snapshot = this.insightCache.get(code);
    if (!snapshot) {
      this.totalIncome = 0;
      this.totalExpense = 0;
      this.balance = 0;
      this.categoryBreakdown = [];
      this.monthlyTrend = [];
      this.tips = [];
      return;
    }
    this.selectedCurrency = code;
    this.totalIncome = snapshot.overview.totalIncome;
    this.totalExpense = snapshot.overview.totalExpense;
    this.balance = snapshot.overview.netAmount;
    this.categoryBreakdown = snapshot.overview.categoryBreakdown;
    this.monthlyTrend = snapshot.trend;
    this.generateTips(snapshot.overview);
  }

  private generateTips(summary: InsightSummary): void {
    const result: string[] = [];
    if (summary.totalIncome > 0) {
      const rate = (summary.totalIncome - summary.totalExpense) / summary.totalIncome * 100;
      if (rate < 0) {
        result.push('本月支出已经超过收入，建议先检查大额和非必要消费。');
      } else if (rate < 30) {
        result.push(`本月结余率约 ${Math.round(rate)}%，可以先设一个容易坚持的储蓄目标。`);
      } else {
        result.push(`本月结余率约 ${Math.round(rate)}%，当前收支处于正结余。`);
      }
    } else if (summary.totalExpense > 0) {
      result.push('本月有支出但没有收入记录，可以确认是否存在漏记的收入。');
    }
    if (summary.categoryBreakdown.length > 0) {
      const top = summary.categoryBreakdown[0];
      result.push(`本月支出最多的是「${top.label}」，占支出的 ${Math.round(top.percentage)}%。`);
    }
    if (result.length === 0) {
      result.push('本月数据还比较少，多记几笔后再回来查看趋势。');
    }
    this.tips = result;
  }

  private defaultAccount(): Account | null {
    if (this.accountContextId > 0) {
      const context = this.accounts.find((item: Account) => item.id === this.accountContextId);
      if (context) {
        return context;
      }
    }
    return this.accounts.length > 0 ? this.accounts[0] : null;
  }

  private prepareCreateIntent(intent: AiIntent): AiIntent {
    if (intent.domain !== 'transaction' || intent.action !== 'create') {
      return intent;
    }
    const requestedAccountId = Number(intent.fields['accountId'] || 0);
    const account = requestedAccountId > 0 ?
      this.accounts.find((item: Account) => item.id === requestedAccountId) : this.defaultAccount();
    if (account) {
      intent.fields['accountId'] = account.id;
    }
    if (!intent.fields['date']) {
      intent.fields['date'] = Math.floor(Date.now() / 1000);
    }
    return intent;
  }

  private friendlyError(error: Object): string {
    const message = `${error}`.replace('Error: ', '');
    if (message.includes('当前') || message.includes('暂未') || message.includes('仅支持')) {
      return message;
    }
    return '暂时没能理解这句话。当前支持“午饭35元”这类单笔收支记录。';
  }

  /** 选择图片附件（photoAccessHelper 相册选择） */
  private async pickAttachment(): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const selectResult = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 9
      });
      if (selectResult && selectResult.photoUris && selectResult.photoUris.length > 0) {
        this.chatAttachments = [...this.chatAttachments, ...selectResult.photoUris];
      }
    } catch (e) {
      promptAction.showToast({ message: '选择附件失败：' + JSON.stringify(e) });
    }
  }

  /** 开始录音（AudioCapturer 采集麦克风音频） */
  private async startRecording(): Promise<void> {
    try {
      // 直接尝试采集（module.json5 已声明 MICROPHONE；模拟器权限状态可能异常，capturer 失败再提示）
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };
      this.capturer = await audio.createAudioCapturer({
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      });
      // 用 readData 事件订阅数据，避免阻塞读卡死主线程
      this.capturer.on('readData', (buffer: ArrayBuffer) => {
        if (buffer && buffer.byteLength > 0) {
          this.recordChunks.push(buffer);
        }
      });
      await this.capturer.start();
      this.isRecording = true;
      this.recordChunks = [];
      promptAction.showToast({ message: '正在录音，再次点击结束' });
    } catch (e) {
      this.isRecording = false;
      const err = JSON.stringify(e);
      if (err.includes('201') || err.includes('permission') || err.includes('Permission')) {
        promptAction.showToast({ message: '需要麦克风权限才能语音输入' });
      } else {
        promptAction.showToast({ message: '录音启动失败：' + err });
      }
    }
  }


  /** 停止录音：保存 WAV 并尝试 ASR 转文字 */
  private async stopRecording(): Promise<void> {
    this.isRecording = false;
    try {
      if (this.capturer) {
        this.capturer.off('readData');
        await this.capturer.stop();
        await this.capturer.release();
        this.capturer = null;
      }
      if (this.recordChunks.length === 0) {
        promptAction.showToast({ message: '未采集到音频' });
        return;
      }
      // 拼接 WAV（16kHz 16bit 单声道）
      const wav = this.buildWav(this.recordChunks);
      const recognized = await this.tryAsr(wav);
      if (recognized.length > 0) {
        this.chatInput = recognized;
        promptAction.showToast({ message: '已识别：' + recognized });
      } else {
        promptAction.showToast({ message: '语音识别服务暂不可用（未识别到文字）' });
      }
    } catch (e) {
      promptAction.showToast({ message: '录音结束异常：' + JSON.stringify(e) });
    } finally {
      this.recordChunks = [];
    }
  }

  /** 组装 WAV 文件（PCM 加 WAV 头） */
  private buildWav(chunks: ArrayBuffer[]): Uint8Array {
    let total = 0;
    for (let c of chunks) {
      total += c.byteLength;
    }
    const dataSize = total;
    const buffer = new ArrayBuffer(44 + dataSize);
    const view = new DataView(buffer);
    const writeStr = (offset: number, s: string): void => {
      for (let i = 0; i < s.length; i++) {
        view.setUint8(offset + i, s.charCodeAt(i));
      }
    };
    writeStr(0, 'RIFF');
    view.setUint32(4, 36 + dataSize, true);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, 1, true);
    view.setUint32(24, 16000, true);
    view.setUint32(28, 16000 * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    writeStr(36, 'data');
    view.setUint32(40, dataSize, true);
    let offset = 44;
    for (let c of chunks) {
      const chunk = new Uint8Array(c);
      for (let i = 0; i < chunk.length; i++) {
        view.setUint8(offset + i, chunk[i]);
      }
      offset += chunk.length;
    }
    return new Uint8Array(buffer);
  }

  /** 尝试语音识别（ASR）。当前专属实例音频接口不可用，预留接入点 */
  private async tryAsr(wav: Uint8Array): Promise<string> {
    // 预留：接入阿里云 NLS / 讯飞 / 其他 ASR 服务
    // 当前专属大模型实例不支持音频输入，返回空串由上层提示
    return '';
  }

  /** 与记账无关的请求检测（本地兜底，明确拒绝） */
  private isUnrelatedQuery(text: string): boolean {
    const keywords: string[] = [
      '写代码', '写一段', '编程', '写文章', '写诗', '写小说', '翻译', '数学题', '解方程',
      '新闻', '天气', '股票行情', '代码', '算法', 'python', 'java', 'javascript', 'sql',
      '怎么实现', '帮我开发', '写个程序', '聊天', '讲个笑话', '推荐电影', '音乐'
    ];
    for (let kw of keywords) {
      if (text.toLowerCase().includes(kw)) {
        return true;
      }
    }
    return false;
  }

  /** 对话式发送：用户消息 → AI 识别 → 待确认账单 / 洞察回复 */
  private async sendChatMessage(): Promise<void> {
    const text = this.chatInput.trim();
    if (text.length === 0 || this.aiLoading) {
      return;
    }
    this.chatMessages = [...this.chatMessages, { role: 'user', text: text, kind: 'text' }];
    this.chatInput = '';
    this.aiLoading = true;
    this.aiIntent = null;
    try {
      // 全程调用大模型识别意图（领域边界/拒绝/账户创建均由大模型判断）
      const intent = await AiService.getInstance().understand(text);
      // 无关请求（大模型判定 action=refuse）：明确拒绝
      if (intent.action === 'refuse') {
        this.pushAiText('我只用于记账和记账分析相关操作，无法处理与此无关的问题。');
        return;
      }
      const validation = AiIntentValidator.validate(intent);
      if (!validation.valid) {
        this.pushAiText(validation.error);
        return;
      }
      // 创建账户（account create）：直接执行并回复
      if (intent.domain === 'account' && intent.action === 'create') {
        const execResult = await AiExecutor.getInstance().execute(intent);
        this.pushAiText(execResult.message);
        if (execResult.ok) {
          this.onDataChanged();
        }
        return;
      }
      // 查询/筛选/排序 → 洞察回复
      if (intent.action === 'query' || intent.action === 'filter' || intent.action === 'sort') {
        this.pushAiText(this.insightReply());
        return;
      }
      // 记账（create）→ 待确认账单
      const prepared = this.prepareCreateIntent(intent);
      const v2 = AiIntentValidator.validate(prepared);
      if (!v2.valid) {
        this.pushAiText(v2.error);
        return;
      }
      if (!this.intentAccount(prepared)) {
        this.pushAiText(this.accounts.length === 0 ?
          '当前没有可用账户，请先创建账户后再记账。' : '指定账户不存在，请重新选择账户。');
        return;
      }
      this.aiIntent = prepared;
      this.chatMessages = [...this.chatMessages, { role: 'ai', text: '', kind: 'bill' }];
    } catch (error) {
      this.pushAiText(this.friendlyError(error as Object));
    } finally {
      this.aiLoading = false;
    }
  }

  /** 追加 AI 文本消息 */
  private pushAiText(text: string): void {
    this.chatMessages = [...this.chatMessages, { role: 'ai', text: text, kind: 'text' }];
  }

  /** 洞察提问词法判断（不调大模型，直接本地回复） */
  private isInsightQuery(text: string): boolean {
    const keywords: string[] = ['这个月', '本月', '花了多少', '用了多少', '收支', '结余', '收入', '支出', '趋势', '分析', '消费', '账单'];
    for (let kw of keywords) {
      if (text.includes(kw)) {
        return true;
      }
    }
    return false;
  }

  /** 洞察回复摘要（复用本地分析数据） */
  private insightReply(): string {
    const lines: string[] = [];
    lines.push(`本月收入 ${this.moneyText(this.totalIncome, true)}，支出 ${this.moneyText(this.totalExpense)}，结余 ${this.moneyText(this.balance)}。`);
    if (this.tips.length > 0) {
      for (let t of this.tips.slice(0, 3)) {
        lines.push(`· ${t}`);
      }
    } else {
      lines.push('本月数据还比较少，多记几笔后再回来查看趋势。');
    }
    return lines.join('\n');
  }

  private async recognizeIntent(): Promise<void> {
    const text = this.aiInput.trim();

    if (text.length === 0 || this.aiLoading) {
      return;
    }
    this.aiLoading = true;
    this.aiIntent = null;
    this.aiStatusText = '';
    this.aiStatusIsError = false;
    try {
      const intent = this.prepareCreateIntent(await AiService.getInstance().understand(text));
      const validation = AiIntentValidator.validate(intent);
      if (!validation.valid) {
        this.aiStatusText = validation.error;
        this.aiStatusIsError = true;
        return;
      }
      if (!this.intentAccount(intent)) {
        this.aiStatusText = this.accounts.length === 0 ?
          '当前没有可用账户，请先创建账户后再记账。' : '指定账户不存在，请重新选择账户。';
        this.aiStatusIsError = true;
        return;
      }
      this.aiIntent = intent;
    } catch (error) {
      this.aiStatusText = this.friendlyError(error as Object);
      this.aiStatusIsError = true;
    } finally {
      this.aiLoading = false;
    }
  }

  private async confirmExecute(): Promise<void> {
    const intent = this.aiIntent;
    if (!intent || this.aiLoading) {
      return;
    }
    const validation = AiIntentValidator.validate(intent);
    if (!validation.valid) {
      this.aiStatusText = validation.error;
      this.aiStatusIsError = true;
      return;
    }
    this.aiLoading = true;
    this.aiStatusText = '';
    try {
      const plan = this.confirmedPlan(intent);
      if (!plan) {
        this.aiStatusText = '所选账户不存在或已失效，请重新校对账单。';
        this.aiStatusIsError = true;
        return;
      }
      const result: AiExecutionResult = await AiExecutor.getInstance().executeConfirmed(plan);
      if (!result.ok || !result.wrote) {
        this.aiStatusText = result.message;
        this.aiStatusIsError = true;
        return;
      }
      this.aiStatusText = result.message;
      this.aiStatusIsError = false;
      this.aiIntent = null;
      this.aiInput = '';
      promptAction.showToast({ message: '已记入账本' });
      await this.analyze();
    } catch (error) {
      this.aiStatusText = '保存失败，请检查账本状态后重试。';
      this.aiStatusIsError = true;
    } finally {
      this.aiLoading = false;
    }
  }

  private openIntentEditDialog(): void {
    const intent = this.aiIntent;
    if (!intent) {
      return;
    }
    const dialog = new CustomDialogController({
      builder: AiIntentEditDialog({
        intent: intent,
        accounts: this.accounts,
        categories: this.categories,
        onApply: (fields: Record<string, string | number>) => {
          const updated: AiIntent = {
            domain: 'transaction',
            action: 'create',
            targets: [],
            fields: fields
          };
          const validation = AiIntentValidator.validate(updated);
          if (!validation.valid) {
            this.aiStatusText = validation.error;
            this.aiStatusIsError = true;
            return;
          }
          this.aiIntent = updated;
          this.aiStatusText = '';
          this.aiStatusIsError = false;
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    dialog.open();
  }

  private selectExample(text: string): void {
    this.aiInput = text;
    this.aiIntent = null;
    this.aiStatusText = '';
  }

  private currencySymbol(): string {
    return currencyByCode(this.selectedCurrency).symbol;
  }

  private fractionDigits(): number {
    return currencyByCode(this.selectedCurrency).fractionDigits;
  }

  private moneyText(amount: number, showPositive: boolean = false): string {
    const prefix = showPositive && amount > 0 ? '+' : '';
    return `${prefix}${this.currencySymbol()}${formatMoney(amount, this.fractionDigits())}`;
  }

  private intentTypeLabel(intent: AiIntent): string {
    return intent.fields['type'] === 'income' ? '收入' : '支出';
  }

  private intentAccount(intent: AiIntent): Account | null {
    const id = Number(intent.fields['accountId'] || 0);
    return this.accounts.find((item: Account) => item.id === id) || null;
  }

  private intentAccountLabel(intent: AiIntent): string {
    const account = this.intentAccount(intent);
    return account ? `${account.label} · ${account.currency}` : '待选择';
  }

  private intentAmountLabel(intent: AiIntent): string {
    const account = this.intentAccount(intent);
    if (!account) {
      return String(intent.fields['amount'] || '待填写');
    }
    const unit = currencyByCode(account.currency);
    return `${unit.symbol}${String(intent.fields['amount'])} ${account.currency}`;
  }

  private intentCategoryLabel(intent: AiIntent): string {
    const id = Number(intent.fields['categoryId'] || -1);
    const category = this.categories.find((item: Category) => item.id === id);
    return category ? category.label : '未分类';
  }

  private intentDate(intent: AiIntent): number {
    return Number(intent.fields['date'] || 0);
  }

  private confirmedPlan(intent: AiIntent): ConfirmedTransactionPlan | null {
    const account = this.intentAccount(intent);
    if (!account) {
      return null;
    }
    const fields: Record<string, string | number> = {};
    fields['type'] = String(intent.fields['type']);
    fields['amountMajor'] = String(intent.fields['amount']);
    fields['accountId'] = account.id;
    fields['date'] = Number(intent.fields['date']);
    fields['currency'] = account.currency;
    fields['fractionDigits'] = currencyByCode(account.currency).fractionDigits;
    fields['categoryId'] = Number(intent.fields['categoryId'] === undefined ? -1 : intent.fields['categoryId']);
    fields['comment'] = String(intent.fields['comment'] || '');
    return {
      schema: CONFIRMED_TRANSACTION_SCHEMA,
      fields: fields
    };
  }

  @Builder
  private modeTabs() {
    Row({ space: 4 }) {
      Button('一句话记账')
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .fontColor(this.mode === 0 ? Color.White : $r('app.color.textSecondary'))
        .backgroundColor(this.mode === 0 ? $r('app.color.primaryColor') : Color.Transparent)
        .borderRadius(8)
        .onClick(() => {
          this.mode = 0;
        })
      Button('消费洞察')
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .fontColor(this.mode === 1 ? Color.White : $r('app.color.textSecondary'))
        .backgroundColor(this.mode === 1 ? $r('app.color.primaryColor') : Color.Transparent)
        .borderRadius(8)
        .onClick(() => {
          this.mode = 1;
        })
    }
    .width('100%')
    .padding(4)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .borderRadius(10)
  }

  @Builder
  private exampleChip(text: string) {
    Button(text)
      .height(32)
      .fontSize(12)
      .fontColor($r('app.color.primaryColor'))
      .backgroundColor($r('app.color.primaryContainer'))
      .borderRadius(16)
      .margin({ right: 8, bottom: 8 })
      .onClick(() => {
        this.selectExample(text);
      })
  }

  @Builder
  private previewRow(label: string, value: string, valueColor: ResourceColor = $r('app.color.textPrimary')) {
    Row() {
      Text(label)
        .width(82)
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
      Text(value)
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(valueColor)
        .textAlign(TextAlign.End)
        .maxLines(2)
    }
    .width('100%')
    .height(32)
  }

  @Builder
  private bookkeepingContent() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Text('说清金额和用途，就能先生成一张待确认账单。')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.textPrimary'))
          Text('识别不会直接写入账本；请在确认前检查金额、账户、分类和日期。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor($r('app.color.textSecondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          TextInput({ placeholder: '例如：午饭35元', text: this.aiInput })
            .width('100%')
            .height(48)
            .fontSize(16)
            .onChange((value: string) => {
              this.aiInput = value;
              this.aiIntent = null;
              this.aiStatusText = '';
            })
            .onSubmit(() => {
              this.recognizeIntent();
            })
          Button(this.aiLoading ? '处理中…' : '生成待确认账单')
            .width('100%')
            .height(44)
            .fontSize(15)
            .backgroundColor($r('app.color.primaryColor'))
            .enabled(this.aiInput.trim().length > 0 && !this.aiLoading)
            .onClick(() => {
              this.recognizeIntent();
            })
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.cardBackgroundColor'))
        .borderRadius(12)

        Column() {
          Text('可以这样说')
            .fontSize(13)
            .fontColor($r('app.color.textSecondary'))
            .margin({ bottom: 8 })
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            this.exampleChip('午饭35元')
            this.exampleChip('工资到账8000元')
            this.exampleChip('打车18.5元')
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.aiStatusText.length > 0) {
          Row({ space: 8 }) {
            Image(this.aiStatusIsError ? $r('app.media.ic_help') : $r('app.media.ic_check'))
              .width(18)
              .height(18)
              .fillColor(this.aiStatusIsError ? $r('app.color.colorExpense') : $r('app.color.colorIncome'))
            Text(this.aiStatusText)
              .fontSize(13)
              .lineHeight(20)
              .fontColor(this.aiStatusIsError ? $r('app.color.colorExpense') : $r('app.color.textPrimary'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius(10)
        }

        if (this.aiIntent) {
          Column({ space: 8 }) {
            Row() {
              Text('待确认账单')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.textPrimary'))
              Blank()
              Text('尚未写入')
                .fontSize(12)
                .fontColor($r('app.color.colorExpense'))
            }
            .width('100%')

            Divider().color($r('app.color.dividerColor'))

            this.previewRow('收支类型', this.intentTypeLabel(this.aiIntent),
              this.aiIntent.fields['type'] === 'income' ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
            this.previewRow('金额', this.intentAmountLabel(this.aiIntent))
            this.previewRow('账户', this.intentAccountLabel(this.aiIntent))
            this.previewRow('分类', this.intentCategoryLabel(this.aiIntent))
            this.previewRow('备注', String(this.aiIntent.fields['comment'] || '无'))
            this.previewRow('日期', formatDate(this.intentDate(this.aiIntent)))

            Text('确认后只会新增这一笔交易，不会修改或删除已有数据。')
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor($r('app.color.textSecondary'))
              .margin({ top: 4 })

            Row({ space: 8 }) {
              Button('返回修改')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
                .backgroundColor($r('app.color.pageBackground'))
                .onClick(() => {
                  this.aiIntent = null;
                })
              Button('校对要素')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .fontColor($r('app.color.primaryColor'))
                .backgroundColor($r('app.color.primaryContainer'))
                .onClick(() => {
                  this.openIntentEditDialog();
                })
              Button(this.aiLoading ? '保存中…' : '确认记账')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .backgroundColor($r('app.color.primaryColor'))
                .enabled(!this.aiLoading)
                .onClick(() => {
                  this.confirmExecute();
                })
            }
            .width('100%')
            .margin({ top: 6 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.primaryColor') })
        }

        Column({ space: 6 }) {
          Text('当前能力边界')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.textPrimary'))
          Text('支持：单笔支出、单笔收入。暂不支持：语音识别、转账、拆分、批量操作，以及通过 AI 编辑或删除历史记录。')
            .fontSize(12)
            .lineHeight(19)
            .fontColor($r('app.color.textSecondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor($r('app.color.primaryContainer'))
        .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%')
    .align(Alignment.Top)
    .layoutWeight(1)
  }

  @Builder
  private currencyChip(code: string) {
    Button(code)
      .height(32)
      .fontSize(12)
      .fontColor(this.selectedCurrency === code ? Color.White : $r('app.color.primaryColor'))
      .backgroundColor(this.selectedCurrency === code ? $r('app.color.primaryColor') : $r('app.color.primaryContainer'))
      .borderRadius(16)
      .margin({ right: 8 })
      .onClick(() => {
        this.applyInsight(code);
      })
  }

  @Builder
  private overviewMetric(label: string, amount: number, color: ResourceColor) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.textSecondary'))
      Text(this.moneyText(amount))
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private insightsContent() {
    if (this.loading) {
      Column({ space: 12 }) {
        LoadingProgress().width(44).height(44)
        Text('正在读取账本并计算本月洞察…')
          .fontSize(14)
          .fontColor($r('app.color.textSecondary'))
      }
      .width('100%')
      .align(Alignment.Top)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.analysisError.length > 0) {
      Column({ space: 12 }) {
        Text(this.analysisError)
          .fontSize(14)
          .fontColor($r('app.color.textSecondary'))
        Button('重试')
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.analyze();
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (!this.hasData) {
      Column({ space: 12 }) {
        Text('这个范围还没有账本数据')
          .fontSize(16)
          .fontColor($r('app.color.textSecondary'))
        Button('去记一笔')
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.mode = 0;
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Column({ space: 3 }) {
              Text('本月洞察')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.textPrimary'))
              Text(`范围：${this.scopeLabel} · 本自然月`)
                .fontSize(12)
                .fontColor($r('app.color.textSecondary'))
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('本地计算')
              .fontSize(11)
              .fontColor($r('app.color.primaryColor'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.primaryContainer'))
              .borderRadius(10)
          }
          .width('100%')

          if (this.currencyCodes.length > 1) {
            Column({ space: 8 }) {
              Text('检测到多币种，请切换币种分别查看（未做无汇率加总）')
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.textSecondary'))
              Row() {
                ForEach(this.currencyCodes, (code: string) => {
                  this.currencyChip(code)
                }, (code: string) => `currency_${code}`)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor($r('app.color.primaryContainer'))
            .borderRadius(10)
          }

          Column({ space: 12 }) {
            Row({ space: 12 }) {
              this.overviewMetric('收入', this.totalIncome, $r('app.color.colorIncome'))
              this.overviewMetric('支出', this.totalExpense, $r('app.color.colorExpense'))
            }
            .width('100%')
            Divider().color($r('app.color.dividerColor'))
            Row() {
              Text('本月结余')
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
              Blank()
              Text(this.moneyText(this.balance, true))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.balance >= 0 ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius(12)

          Column({ space: 10 }) {
            Text('近三个月趋势')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.textPrimary'))
            Row({ space: 8 }) {
              ForEach(this.monthlyTrend, (item: MonthlyInsight) => {
                Column({ space: 4 }) {
                  Text(item.month.substring(5) + '月')
                    .fontSize(12)
                    .fontColor($r('app.color.textSecondary'))
                  Text(`收 ${this.moneyText(item.income)}`)
                    .fontSize(11)
                    .fontColor($r('app.color.colorIncome'))
                    .maxLines(1)
                  Text(`支 ${this.moneyText(item.expense)}`)
                    .fontSize(11)
                    .fontColor($r('app.color.colorExpense'))
                    .maxLines(1)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .padding(10)
                .backgroundColor($r('app.color.cardBackgroundColor'))
                .borderRadius(8)
              }, (item: MonthlyInsight) => `month_${item.month}`)
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.categoryBreakdown.length > 0) {
            Column({ space: 10 }) {
              Text('本月支出分类')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              ForEach(this.categoryBreakdown.slice(0, 5), (item: CategoryInsight, index: number) => {
                Column({ space: 5 }) {
                  Row() {
                    Text(`${index + 1}. ${item.label}`)
                      .fontSize(14)
                      .fontColor($r('app.color.textPrimary'))
                      .layoutWeight(1)
                    Text(`${this.moneyText(item.amount)} · ${Math.round(item.percentage)}%`)
                      .fontSize(13)
                      .fontColor($r('app.color.textSecondary'))
                  }
                  .width('100%')
                  Progress({ value: item.percentage, total: 100, type: ProgressType.Linear })
                    .width('100%')
                    .height(4)
                    .color($r('app.color.primaryColor'))
                    .backgroundColor($r('app.color.dividerColor'))
                }
                .width('100%')
              }, (item: CategoryInsight, index: number) => `category_${item.label}_${index}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .backgroundColor($r('app.color.cardBackgroundColor'))
            .borderRadius(12)
          }

          Column({ space: 10 }) {
            Text('智能提示')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.textPrimary'))
            ForEach(this.tips, (tip: string, index: number) => {
              Row() {
                Circle()
                  .width(6)
                  .height(6)
                  .fill($r('app.color.primaryColor'))
                  .margin({ top: 7 })
                Text(tip)
                  .fontSize(14)
                  .lineHeight(22)
                  .fontColor($r('app.color.textPrimary'))
                  .layoutWeight(1)
                  .margin({ left: 8 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (tip: string, index: number) => `tip_${index}`)
            Text('提示由本地规则根据账本统计生成，仅供参考。')
              .fontSize(11)
              .fontColor($r('app.color.textSecondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius(12)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  build() {
    Column() {
      PageHeader({
        title: 'AI 记账与洞察',
        showBack: false,
        showSpeech: false,
        onBack: () => {
          router.back();
        }
      })

      // 对话消息列表（ChatGPT 风格）
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.chatMessages, (msg: ChatMessage) => {
            if (msg.role === 'user') {
              this.userBubble(msg.text)
            } else if (msg.kind === 'bill') {
              this.billBubble()
            } else {
              this.aiBubble(msg.text)
            }
          }, (msg: ChatMessage, index: number) => `chat_${index}_${msg.text}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)

      // 底部输入栏
      Column() {
        // 附件预览（可删除）
        if (this.chatAttachments.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.chatAttachments, (uri: string, index: number) => {
              Stack({ alignContent: Alignment.TopEnd }) {
                Image(uri)
                  .width(64)
                  .height(64)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                Text('✕')
                  .fontSize(12)
                  .fontColor(Color.White)
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#99000000')
                  .borderRadius(10)
                  .onClick(() => {
                    this.chatAttachments.splice(index, 1);
                    this.chatAttachments = [...this.chatAttachments];
                  })
              }
              .width(64)
              .height(64)
              .margin({ right: 8, bottom: 8 })
            }, (uri: string, index: number) => `att_${index}_${uri}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8 })
        }

        Row({ space: 8 }) {
          // 附件上传按钮
          Button() {
            Image($r('sys.media.ohos_ic_public_add'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.iconSecondary'))
          }
            .type(ButtonType.Circle)
            .width(44)
            .height(44)
            .backgroundColor(Color.Transparent)
            .accessibilityText('上传附件')
            .onClick(() => {
              this.pickAttachment();
            })
          // 麦克风按钮（语音输入）
          Button() {
            if (this.isRecording) {
              Text('●')
                .fontSize(16)
                .fontColor(Color.Red)
            } else {
              Image($r('app.media.ic_mic'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.iconSecondary'))
            }
          }
            .type(ButtonType.Circle)
            .width(44)
            .height(44)
            .backgroundColor(this.isRecording ? $r('app.color.surfaceBrandSoft') : Color.Transparent)
            .accessibilityText(this.isRecording ? '停止录音' : '语音输入')
            .onClick(() => {
              promptAction.showToast({ message: '麦克风按钮已点击' });
              if (this.isRecording) {
                this.stopRecording();
              } else {
                this.startRecording();
              }
            })
          TextInput({
            placeholder: '例如：午饭35元，或问"这个月花了多少"',
            text: this.chatInput
          })
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .backgroundColor($r('app.color.cardBackgroundColor'))
            .borderRadius(22)
            .padding({ left: 16, right: 16 })
            .onChange((v: string) => {
              this.chatInput = v;
            })
            .onSubmit(() => {
              this.sendChatMessage();
            })
          Button(this.aiLoading ? '…' : '发送')
            .height(44)
            .fontSize(15)
            .backgroundColor($r('app.color.primaryColor'))
            .enabled((this.chatInput.trim().length > 0 || this.chatAttachments.length > 0) && !this.aiLoading)
            .onClick(() => {
              this.sendChatMessage();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.pageBackground'))
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  /** 用户消息气泡（右侧） */
  @Builder
  userBubble(text: string) {
    Row() {
      Text(text)
        .fontSize(15)
        .fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.primaryColor'))
        .borderRadius(18)
        .constraintSize({ maxWidth: '75%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
  }

  /** AI 文本消息气泡（左侧） */
  @Builder
  aiBubble(text: string) {
    Row() {
      Text(text)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.cardBackgroundColor'))
        .borderRadius(18)
        .constraintSize({ maxWidth: '80%' })
        .lineHeight(22)
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** 待确认账单气泡（左侧，含预览与操作） */
  @Builder
  billBubble() {
    Column({ space: 8 }) {
      Row() {
        Text('待确认账单')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
        Blank()
        Text('尚未写入')
          .fontSize(11)
          .fontColor($r('app.color.colorExpense'))
      }
      .width('100%')

      if (this.aiIntent) {
        Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)
        this.previewRow('收支类型', this.intentTypeLabel(this.aiIntent),
          this.aiIntent.fields['type'] === 'income' ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
        this.previewRow('金额', this.intentAmountLabel(this.aiIntent))
        this.previewRow('账户', this.intentAccountLabel(this.aiIntent))
        this.previewRow('分类', this.intentCategoryLabel(this.aiIntent))
        this.previewRow('备注', String(this.aiIntent.fields['comment'] || '无'))
        this.previewRow('日期', formatDate(this.intentDate(this.aiIntent)))

        Row({ space: 8 }) {
          Button('返回修改')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .fontColor($r('app.color.textSecondary'))
            .backgroundColor($r('app.color.pageBackground'))
            .onClick(() => {
              this.declineChatBill();
            })
          Button('确认写入')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .backgroundColor($r('app.color.primaryColor'))
            .onClick(() => {
              this.confirmChatBill();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .borderRadius(18)
    .constraintSize({ maxWidth: '90%' })
  }

  /** 确认写入（对话版：执行后替换账单气泡为结果） */
  private async confirmChatBill(): Promise<void> {
    const intent = this.aiIntent;
    if (!intent || this.aiLoading) {
      return;
    }
    const validation = AiIntentValidator.validate(intent);
    if (!validation.valid) {
      this.pushAiText(validation.error);
      return;
    }
    this.aiLoading = true;
    try {
      const plan = this.confirmedPlan(intent);
      if (!plan) {
        this.pushAiText('所选账户不存在或已失效，请重新校对账单。');
        return;
      }
      const result: AiExecutionResult = await AiExecutor.getInstance().executeConfirmed(plan);
      // 关联附件（图片）到交易
      if (result.ok && result.wrote && result.transactionId > 0 && this.chatAttachments.length > 0) {
        try {
          await this.repository.setTransactionAttachments(result.transactionId, this.chatAttachments);
        } catch (e) {
          // 附件关联失败不影响交易写入
        }
      }
      this.replaceLastBill(result.ok && result.wrote ? result.message : (result.message || '保存失败，请重试'));
      if (result.ok && result.wrote) {
        promptAction.showToast({ message: '已记入账本' });
        this.chatAttachments = [];
        this.onDataChanged();
        await this.analyze();
      }
    } catch (error) {
      this.replaceLastBill('保存失败，请检查账本状态后重试。');
    } finally {
      this.aiLoading = false;
      this.aiIntent = null;
    }
  }

  /** 返回修改（对话版：移除账单气泡，提示重新描述） */
  private declineChatBill(): void {
    const msgs = [...this.chatMessages];
    const last = msgs[msgs.length - 1];
    if (last && last.kind === 'bill') {
      msgs.pop();
    }
    msgs.push({ role: 'ai', text: '好的，请重新描述这笔账（例如"午饭35元"）。', kind: 'text' });
    this.chatMessages = msgs;
    this.aiIntent = null;
  }

  /** 替换最后一条账单气泡为结果文本 */
  private replaceLastBill(text: string): void {
    const msgs = [...this.chatMessages];
    const last = msgs[msgs.length - 1];
    if (last && last.kind === 'bill') {
      msgs.pop();
    }
    msgs.push({ role: 'ai', text: text, kind: 'text' });
    this.chatMessages = msgs;
  }
}

/** 单笔收支创建的执行前校对。 */
@CustomDialog
struct AiIntentEditDialog {
  controller?: CustomDialogController;
  intent: AiIntent = { domain: 'transaction', action: 'create', targets: [], fields: {} };
  accounts: Account[] = [];
  categories: Category[] = [];
  onApply: (fields: Record<string, string | number>) => void = () => {
  };

  @State editType: string = 'expense';
  @State editAmount: string = '';
  @State editComment: string = '';
  @State editAccountId: number = 0;
  @State editCategoryId: number = -1;
  @State editDate: number = 0;
  @State validationText: string = '';

  aboutToAppear(): void {
    this.editType = String(this.intent.fields['type'] || 'expense');
    this.editAmount = String(this.intent.fields['amount'] || '');
    this.editComment = String(this.intent.fields['comment'] || '');
    this.editAccountId = Number(this.intent.fields['accountId'] || 0);
    this.editCategoryId = Number(this.intent.fields['categoryId'] || -1);
    this.editDate = Number(this.intent.fields['date'] || Math.floor(Date.now() / 1000));
    if (this.editAccountId <= 0 && this.accounts.length > 0) {
      this.editAccountId = this.accounts[0].id;
    }
  }

  private accountOptions(): SelectOption[] {
    return this.accounts.map((item: Account) => ({ value: `${item.label} · ${item.currency}` } as SelectOption));
  }

  private selectedAccountValue(): string {
    const account = this.accounts.find((item: Account) => item.id === this.editAccountId);
    return account ? `${account.label} · ${account.currency}` : '请选择账户';
  }

  private amountPlaceholder(): string {
    const account = this.accounts.find((item: Account) => item.id === this.editAccountId);
    if (!account) {
      return '请输入金额';
    }
    const unit = currencyByCode(account.currency);
    return `金额（${unit.symbol} · ${account.currency}）`;
  }

  private availableCategories(): Category[] {
    const expected = this.editType === 'income' ? 1 : -1;
    return this.categories.filter((item: Category) => item.type === 0 || item.type === expected);
  }

  private categoryOptions(): SelectOption[] {
    const result: SelectOption[] = [{ value: '未分类' } as SelectOption];
    for (let item of this.availableCategories()) {
      result.push({ value: item.label } as SelectOption);
    }
    return result;
  }

  private selectedCategoryIndex(): number {
    const index = this.availableCategories().findIndex((item: Category) => item.id === this.editCategoryId);
    return index < 0 ? 0 : index + 1;
  }

  private selectedCategoryValue(): string {
    const category = this.categories.find((item: Category) => item.id === this.editCategoryId);
    return category ? category.label : '未分类';
  }

  private showDatePicker(): void {
    const selected = new Date(this.editDate * 1000);
    const options: DatePickerDialogOptions = {
      start: new Date(selected.getFullYear() - 5, 0, 1),
      end: new Date(selected.getFullYear() + 5, 11, 31),
      selected: selected,
      onDateAccept: (value: Date) => {
        const current = new Date(this.editDate * 1000);
        value.setHours(current.getHours(), current.getMinutes(), current.getSeconds(), 0);
        this.editDate = Math.floor(value.getTime() / 1000);
      }
    };
    this.getUIContext().showDatePickerDialog(options);
  }

  private apply(): void {
    const account = this.accounts.find((item: Account) => item.id === this.editAccountId);
    if (!account) {
      this.validationText = '请选择要记入的账户';
      return;
    }
    const conversion = AiExecutionPlan.convertMajorToMinor(
      this.editAmount.trim(), currencyByCode(account.currency).fractionDigits);
    if (!conversion.valid) {
      this.validationText = conversion.error;
      return;
    }
    const amount = Number(this.editAmount);
    const category = this.categories.find((item: Category) => item.id === this.editCategoryId);
    const fields: Record<string, string | number> = {};
    fields['type'] = this.editType;
    fields['amount'] = amount;
    fields['comment'] = this.editComment.trim();
    fields['accountId'] = account.id;
    fields['categoryId'] = category ? category.id : -1;
    fields['date'] = this.editDate;
    this.onApply(fields);
    if (this.controller) {
      this.controller.close();
    }
  }

  @Builder
  private fieldLabel(text: string) {
    Text(text)
      .width(72)
      .fontSize(13)
      .fontColor($r('app.color.textSecondary'))
  }

  build() {
    Column({ space: 12 }) {
      Text('校对账单要素')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')

      Row({ space: 8 }) {
        this.fieldLabel('收支类型')
        Button('支出')
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .fontColor(this.editType === 'expense' ? Color.White : $r('app.color.textSecondary'))
          .backgroundColor(this.editType === 'expense' ? $r('app.color.colorExpense') : $r('app.color.pageBackground'))
          .onClick(() => {
            this.editType = 'expense';
            this.editCategoryId = -1;
          })
        Button('收入')
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .fontColor(this.editType === 'income' ? Color.White : $r('app.color.textSecondary'))
          .backgroundColor(this.editType === 'income' ? $r('app.color.colorIncome') : $r('app.color.pageBackground'))
          .onClick(() => {
            this.editType = 'income';
            this.editCategoryId = -1;
          })
      }
      .width('100%')

      Row() {
        this.fieldLabel('金额')
        TextInput({ placeholder: this.amountPlaceholder(), text: this.editAmount })
          .layoutWeight(1)
          .height(40)
          .type(InputType.NUMBER_DECIMAL)
          .onChange((value: string) => {
            this.editAmount = value;
            this.validationText = '';
          })
      }
      .width('100%')

      Row() {
        this.fieldLabel('账户')
        Select(this.accountOptions())
          .selected(this.accounts.findIndex((item: Account) => item.id === this.editAccountId))
          .value(this.selectedAccountValue())
          .layoutWeight(1)
          .onSelect((index: number) => {
            if (index >= 0 && index < this.accounts.length) {
              this.editAccountId = this.accounts[index].id;
            }
          })
      }
      .width('100%')

      Row() {
        this.fieldLabel('分类')
        Select(this.categoryOptions())
          .selected(this.selectedCategoryIndex())
          .value(this.selectedCategoryValue())
          .layoutWeight(1)
          .onSelect((index: number) => {
            if (index === 0) {
              this.editCategoryId = -1;
              return;
            }
            const options = this.availableCategories();
            if (index - 1 < options.length) {
              this.editCategoryId = options[index - 1].id;
            }
          })
      }
      .width('100%')

      Row() {
        this.fieldLabel('备注')
        TextInput({ placeholder: '可选', text: this.editComment })
          .layoutWeight(1)
          .height(40)
          .onChange((value: string) => {
            this.editComment = value;
          })
      }
      .width('100%')

      Row() {
        this.fieldLabel('日期')
        Button(formatDate(this.editDate))
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .fontColor($r('app.color.textPrimary'))
          .backgroundColor($r('app.color.pageBackground'))
          .onClick(() => {
            this.showDatePicker();
          })
      }
      .width('100%')

      if (this.validationText.length > 0) {
        Text(this.validationText)
          .fontSize(12)
          .fontColor($r('app.color.colorExpense'))
          .width('100%')
      }

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontColor($r('app.color.textSecondary'))
          .backgroundColor($r('app.color.pageBackground'))
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
          })
        Button('应用修改')
          .layoutWeight(1)
          .height(42)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.apply();
          })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('92%')
    .constraintSize({ maxWidth: 520 })
    .padding(20)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .borderRadius(16)
  }
}
