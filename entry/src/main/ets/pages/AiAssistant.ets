import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { Transaction } from '../model/Transaction';
import { Template } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { AiIntent, AiService, AiUnderstandResult } from '../database/AiService';
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
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

interface InsightSnapshot {
  overview: InsightSummary;
  trend: MonthlyInsight[];
}

/** 对话消息：role user/ai，kind text（普通文本）/bill（待确认账单预览）/confirm（修改删除确认）/plan（多步骤执行计划）/thinking（大模型思考过程） */
interface ChatMessage {
  role: string;
  text: string;
  kind: string;
  /** confirm 消息携带的操作快照（避免全局 pendingAction 被后续输入覆盖导致错乱） */
  action?: PendingAction;
  /** plan 消息携带的多步骤执行计划 */
  planSteps?: AiIntent[];
  /** 多步骤执行上下文 ID（危险步骤确认后据此恢复执行） */
  stepCtxId?: number;
  /** 危险步骤确认消息对应步骤号 */
  confirmStepNo?: number;
  /** thinking 消息：是否仍在思考（true=进行中，false=已输出思考内容） */
  thinkingDone?: boolean;
}

/** 多步骤执行上下文（对话内确认机制：保存计划与游标，危险步骤确认后恢复） */
interface StepContext {
  id: number;
  steps: AiIntent[];
  index: number;
}

/** 危险步骤确认后恢复执行上下文 */
interface StepResumeContext {
  ctxId: number;
  nextIndex: number;
  actionType: string;
}

/** 对话内待确认操作（修改/删除） */
interface PendingAction {
  type: string; // delete | edit
  target: Transaction;
  fields: Record<string, string | number>;
  stepNo?: number;
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
  /** 待确认操作（修改/删除，对话内确认，不用系统弹窗） */
  @State pendingAction: PendingAction | null = null;
  /** 多步骤执行上下文（对话内确认机制，保存计划与游标） */
  @State stepCtx: StepContext | null = null;
  /** 危险步骤确认后恢复执行上下文（confirm 按钮回调使用） */
  private stepResume: StepResumeContext | null = null;
  /** 多笔候选（歧义消解：用户点击选择） */
  @State candidateList: Transaction[] = [];
  @State candidateType: string = 'delete';
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
    // 账户：优先按名称映射（大模型输出用户可见名称），其次按数字 id，最后默认
    const accountName = String(intent.fields['account'] || '');
    const requestedAccountId = Number(intent.fields['accountId'] || 0);
    let account: Account | null = null;
    if (accountName.length > 0) {
      account = this.accounts.find((item: Account) => item.label.includes(accountName)) || null;
      // 指定了名称但找不到：不静默使用默认账户（交给 UI 提示"指定账户不存在"）
      if (account) {
        intent.fields['accountId'] = account.id;
      } else {
        intent.fields['accountId'] = 0;
      }
    } else if (requestedAccountId > 0) {
      account = this.accounts.find((item: Account) => item.id === requestedAccountId) || null;
      if (account) {
        intent.fields['accountId'] = account.id;
      } else {
        intent.fields['accountId'] = 0;
      }
    } else {
      account = this.defaultAccount();
      if (account) {
        intent.fields['accountId'] = account.id;
      }
    }
    // 分类：按名称映射
    const categoryName = String(intent.fields['category'] || '');
    if (categoryName.length > 0) {
      const cat = this.categories.find((item: Category) => item.label.includes(categoryName));
      if (cat) {
        intent.fields['categoryId'] = cat.id;
      }
    }
    // 日期：空则今天；相对词解析为时间戳
    const rawDate = intent.fields['date'];
    if (rawDate === undefined || rawDate === '' || rawDate === 0) {
      intent.fields['date'] = Math.floor(Date.now() / 1000);
    } else if (typeof rawDate === 'string' && !/^\d+$/.test(rawDate)) {
      intent.fields['date'] = this.parseRelativeDate(rawDate);
    } else {
      intent.fields['date'] = Number(rawDate);
    }
    return intent;
  }

  /** 相对日期解析（今天/昨天/前天/上周/上月/晚上等 → 秒时间戳） */
  private parseRelativeDate(raw: string): number {
    const now = new Date();
    const startOfDay = (d: Date): Date => new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const toTs = (d: Date): number => Math.floor(d.getTime() / 1000);
    const text = raw.trim();
    if (text.includes('昨天') || text.includes('昨晚')) {
      const d = startOfDay(now); d.setDate(d.getDate() - 1); return toTs(d);
    }
    if (text.includes('前天')) {
      const d = startOfDay(now); d.setDate(d.getDate() - 2); return toTs(d);
    }
    if (text.includes('上周') || text.includes('上个星期')) {
      const d = startOfDay(now); d.setDate(d.getDate() - 7); return toTs(d);
    }
    if (text.includes('上个月') || text.includes('上月')) {
      const d = new Date(now.getFullYear(), now.getMonth() - 1, 1); return toTs(d);
    }
    if (text.includes('今天') || text.includes('今晚') || text.includes('晚上') || text.includes('刚刚') || text.includes('刚才')) {
      return toTs(startOfDay(now));
    }
    // 8月10号 / 8/10 形式
    const m = text.match(/(\d{1,2})月(\d{1,2})日|\d{1,2}月\d{1,2}|(\d{4})-(\d{1,2})-(\d{1,2})/);
    if (m) {
      if (m[3] && m[4] && m[5]) {
        return toTs(new Date(Number(m[3]), Number(m[4]) - 1, Number(m[5])));
      }
      const month = Number(m[1]);
      const day = Number(m[2]);
      const year = month > now.getMonth() + 1 ? now.getFullYear() - 1 : now.getFullYear();
      return toTs(new Date(year, month - 1, day));
    }
    return toTs(startOfDay(now));
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
      // 读取相册图片需要 READ_IMAGEVIDEO 权限（动态申请，用于发送给大模型理解）
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      try {
        await atManager.requestPermissionsFromUser(context,
          ['ohos.permission.READ_IMAGEVIDEO'] as Permissions[]);
      } catch (permErr) {
        hilog.warn(0x0000, 'AiAssistant', 'request READ_IMAGEVIDEO failed: ' + JSON.stringify(permErr));
      }
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

  /** 读取图片文件并转为 base64 data-url（供多模态请求发给大模型） */
  private async attachmentToDataUrl(uri: string): Promise<string> {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const size = stat.size;
      if (size <= 0 || size > 20 * 1024 * 1024) {
        fs.closeSync(file);
        return '';
      }
      const buf = new ArrayBuffer(size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const base64Helper = new util.Base64Helper();
      const base64 = base64Helper.encodeToString(new Uint8Array(buf));
      // photoAccessHelper 返回的 URI 一般为 image/jpeg，统一按 jpeg 处理
      return `data:image/jpeg;base64,${base64}`;
    } catch (e) {
      hilog.error(0x0000, 'AiAssistant', 'attachmentToDataUrl failed: ' + JSON.stringify(e));
      return '';
    }
  }

  /** 将当前待发送图片附件转为 data-url 数组（失败/超大的忽略） */
  private async attachmentsToDataUrls(): Promise<string[]> {
    const urls: string[] = [];
    for (const uri of this.chatAttachments) {
      const dataUrl = await this.attachmentToDataUrl(uri);
      if (dataUrl) {
        urls.push(dataUrl);
      }
    }
    return urls;
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
    // 允许纯图片发送（无文字时给默认提示，让大模型看图识别记账内容）
    let text = this.chatInput.trim();
    if ((text.length === 0 && this.chatAttachments.length === 0) || this.aiLoading) {
      return;
    }
    const hasImage = this.chatAttachments.length > 0;
    if (text.length === 0 && hasImage) {
      text = '请识别图片内容，如果图片是一张账单或小票，请按其中的金额和用途记账；否则说明图片内容。';
    }
    this.chatMessages = [...this.chatMessages, { role: 'user', text: hasImage ? '📷 图片' + (text.length > 0 ? '：' + text : '') : text, kind: 'text' }];
    this.chatInput = '';
    this.aiLoading = true;
    this.aiIntent = null;
    // 用户发出新指令：放弃此前未确认的修改/删除操作，避免旧 confirm 缩成一行且不可操作
    this.expirePendingConfirmBubbles();
    try {
      // 将待发送图片附件转为 base64（多模态请求），供大模型理解图片内容
      const imageDataUrls = await this.attachmentsToDataUrls();
      if (this.chatAttachments.length > 0 && imageDataUrls.length === 0) {
        this.pushAiText('图片读取失败或超过大小限制（20MB），已忽略图片，仅按文字理解。');
      }
      // 推送"思考中"气泡（大模型推理期间展示）
      const thinkingId = this.pushThinking();
      let understandResult: AiUnderstandResult | null = null;
      try {
        // 开启思考模式调用大模型识别意图，并实时回调思考过程
        understandResult = await AiService.getInstance().understandWithThinking(
          text, imageDataUrls, (t: string) => {
            if (t && t.trim().length > 0) {
              this.updateThinking(thinkingId, t);
            }
          });
      } finally {
        // 请求结束移除思考气泡（无论成功失败）
        this.removeThinking(thinkingId);
      }
      const intent = understandResult.intent;
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
      // 多步骤任务：展示执行计划 → 确认 → 逐条执行（写操作需整体确认，危险步骤逐条确认）
      if (intent.steps && intent.steps.length > 0) {
        this.executeSteps(intent.steps);
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
      // 账户查询/修改/删除：通过执行器处理（删除危险操作需确认）
      if (intent.domain === 'account') {
        if (intent.action === 'delete') {
          // 删除账户：对话内确认（危险操作）
          const targetName = intent.targets.length > 0 ? intent.targets[0] : String(intent.fields['name'] || '');
          const accounts = await this.repository.getAccounts();
          const acc = accounts.find((a: Account) => a.label.includes(targetName));
          if (!acc) {
            this.pushAiText(`未找到账户「${targetName}」。`);
            return;
          }
          const txCount = (await this.repository.getTransactions(acc.id)).length;
          const f: Record<string, string | number> = {};
          f['accountId'] = acc.id;
          f['comment'] = targetName;
          f['amount'] = txCount;
          const accDelAction: PendingAction = {
            type: 'accountDelete',
            target: new Transaction(),
            fields: f
          };
          this.pendingAction = accDelAction;
          this.chatMessages = [...this.chatMessages, {
            role: 'ai', text: '', kind: 'confirm',
            action: accDelAction
          }];
          return;
        }
        const execResult = await AiExecutor.getInstance().execute(intent);
        this.pushAiText(execResult.message);
        if (execResult.ok && intent.action === 'edit') {
          this.onDataChanged();
        }
        return;
      }
      // 删除交易：唯一定位 + 明确确认（危险写操作）
      if (intent.domain === 'transaction' && intent.action === 'delete') {
        const matches = await this.findTransactionsByIntent(intent);
        if (matches.length === 0) {
          this.pushAiText('未找到匹配的交易，请补充备注或金额。');
          return;
        }
        if (matches.length > 1) {
          // 多笔候选：展示详细列表（日期/账户/分类/金额/备注），用户点击选择
          this.candidateList = matches;
          this.candidateType = 'delete';
          this.chatMessages = [...this.chatMessages, { role: 'ai', text: '', kind: 'candidates' }];
          return;
        }
        const target = matches[0];
        // 对话内确认（不用系统弹窗）：设置待确认操作并推送确认气泡
        this.pendingAction = { type: 'delete', target: target, fields: {} };
        this.chatMessages = [...this.chatMessages, {
          role: 'ai', text: '', kind: 'confirm',
          action: { type: 'delete', target: target, fields: {} }
        }];
        return;
      }
      // 修改交易：唯一定位 + 对话内预览确认
      if (intent.domain === 'transaction' && intent.action === 'edit') {
        const matches = await this.findTransactionsByIntent(intent);
        if (matches.length === 0) {
          this.pushAiText('未找到匹配的交易，请补充备注或金额。');
          return;
        }
        if (matches.length > 1) {
          // 多笔候选：展示详细列表，用户点击选择
          this.candidateList = matches;
          this.candidateType = 'edit';
          this.chatMessages = [...this.chatMessages, { role: 'ai', text: '', kind: 'candidates' }];
          return;
        }
        const target = matches[0];
        const changes: string[] = [];
        const newAmount = Number(intent.fields['amount'] || 0);
        if (newAmount > 0) {
          changes.push(`金额改为 ${newAmount} 元`);
        }
        const newComment = String(intent.fields['comment'] || '');
        if (newComment && newComment !== target.comment) {
          changes.push(`备注改为「${newComment}」`);
        }
        if (changes.length === 0) {
          this.pushAiText('未识别到要修改的字段（金额/备注/分类/账户/日期）。');
          return;
        }
        // 对话内确认（不用系统弹窗）
        this.pendingAction = { type: 'edit', target: target, fields: intent.fields };
        this.chatMessages = [...this.chatMessages, {
          role: 'ai', text: '', kind: 'confirm',
          action: { type: 'edit', target: target, fields: intent.fields }
        }];
        return;
      }
      // 模板操作：通过执行器处理（删除/使用模板前确认）
      if (intent.domain === 'template') {
        if (intent.action === 'delete' || intent.action === 'use') {
          const tplName = intent.targets.length > 0 ? intent.targets[0] : '';
          const templates = await this.repository.getTemplates();
          const tpl = templates.find((t: Template) => t.title.includes(tplName));
          if (!tpl) {
            this.pushAiText(`未找到模板「${tplName}」。`);
            return;
          }
          const f: Record<string, string | number> = {};
          f['templateId'] = tpl.id;
          f['comment'] = tpl.title;
          f['amount'] = Math.abs(tpl.amount);
          const tplAction: PendingAction = {
            type: intent.action === 'delete' ? 'templateDelete' : 'templateUse',
            target: new Transaction(),
            fields: f
          };
          this.pendingAction = tplAction;
          this.chatMessages = [...this.chatMessages, {
            role: 'ai', text: '', kind: 'confirm',
            action: tplAction
          }];
          return;
        }
        const execResult = await AiExecutor.getInstance().execute(intent);
        this.pushAiText(execResult.message);
        if (execResult.ok && intent.action !== 'query') {
          this.onDataChanged();
        }
        return;
      }
      // 查询/筛选/排序 → 精确查询（按账户/分类/时间/金额过滤）或洞察总览
      if (intent.action === 'query' || intent.action === 'filter' || intent.action === 'sort') {
        const precise = await this.preciseQueryReply(intent);
        this.pushAiText(precise);
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

  /** 按意图匹配交易（备注关键字/金额），返回候选列表 */
  private async findTransactionsByIntent(intent: AiIntent): Promise<Transaction[]> {
    const keyword = intent.targets && intent.targets.length > 0 ?
      intent.targets[0] : String(intent.fields['comment'] || '');
    const amount = Number(intent.fields['amount'] || 0);
    const accounts = await this.repository.getAccounts();
    const result: Transaction[] = [];
    for (let acc of accounts) {
      const txList = await this.repository.getTransactions(acc.id);
      for (let t of txList) {
        if (keyword && t.comment.includes(keyword)) {
          result.push(t);
        } else if (amount > 0 && Math.abs(t.amount) === Math.round(amount * 100)) {
          result.push(t);
        }
      }
    }
    return result;
  }

  /** 多步骤任务：对话内展示执行计划 → 用户点执行 → 逐条执行（不使用系统弹窗） */
  private executeSteps(steps: AiIntent[]): void {
    const ctxId = Date.now();
    this.stepCtx = { id: ctxId, steps: steps, index: 0 };
    this.chatMessages = [...this.chatMessages, {
      role: 'ai', text: '', kind: 'plan', planSteps: steps, stepCtxId: ctxId
    }];
  }

  /** 计划卡片点"执行"：从指定游标开始逐条执行 */
  private async runStepsFromIndex(ctxId: number, startIndex: number): Promise<void> {
    const ctx = this.stepCtx;
    if (!ctx || ctx.id !== ctxId) {
      this.pushAiText('该执行计划已失效，请重新描述。');
      return;
    }
    const steps = ctx.steps;
    let i = startIndex;
    while (i < steps.length) {
      const s = steps[i];
      try {
        const stepNo = i + 1;
        if (s.action === 'query' || s.action === 'filter' || s.action === 'sort') {
          // 查询前刷新数据，确保包含此前写操作的结果
          await this.analyze();
          const lastQuery = await this.preciseQueryReply(s);
          this.pushAiText(`第${stepNo}步：${lastQuery}`);
          i++;
          continue;
        }
        if (s.domain === 'account' && s.action === 'create') {
          const r = await AiExecutor.getInstance().execute(s);
          this.pushAiText(`第${stepNo}步：${r.message}`);
          i++;
          continue;
        }
        if (s.action === 'delete' || s.action === 'edit') {
          // 危险步骤：对话内逐条确认（不用系统弹窗）；确认后恢复执行
          const confirmed = await this.confirmDangerStepInChat(s, stepNo, ctxId, i);
          if (!confirmed) {
            this.pushAiText(`第${stepNo}步未执行（已取消/未匹配），剩余步骤已停止。`);
            this.stepCtx = null;
            this.onDataChanged();
            return;
          }
          i++;
          continue;
        }
        if (s.action === 'create') {
          const prepared = this.prepareCreateIntent(s);
          const v2 = AiIntentValidator.validate(prepared);
          if (!v2.valid) {
            this.pushAiText(`第${stepNo}步失败：${v2.error}`);
            break;
          }
          if (!this.intentAccount(prepared)) {
            this.pushAiText(`第${stepNo}步失败：指定账户不存在，请重新描述。`);
            break;
          }
          const plan = this.confirmedPlan(prepared);
          if (!plan) {
            this.pushAiText(`第${stepNo}步失败：无法生成执行计划。`);
            break;
          }
          const r = await AiExecutor.getInstance().executeConfirmed(plan);
          if (!r.ok || !r.wrote) {
            this.pushAiText(`第${stepNo}步失败：${r.message}`);
            break;
          }
          this.pushAiText(`第${stepNo}步：${r.message}`);
          i++;
          continue;
        }
        this.pushAiText(`第${stepNo}步暂不支持：${s.domain}/${s.action}`);
        break;
      } catch (e) {
        this.pushAiText(`第${i + 1}步异常：${JSON.stringify(e)}`);
        break;
      }
    }
    // 全部执行完成
    this.stepCtx = null;
    this.onDataChanged();
  }

  /**
   * 多步骤中危险步骤（删除/修改）对话内确认。
   * 确认后推送 confirm 气泡挂起执行，用户点击确认/取消时通过 confirmStepCtx 恢复。
   * 返回 true 表示已挂起等待用户确认（执行由 confirmPendingAction 继续），
   * 返回 false 表示未匹配/多匹配已直接处理（无需等待）。
   */
  private confirmDangerStepInChat(step: AiIntent, stepNo: number, ctxId: number, index: number): Promise<boolean> {
    return new Promise<boolean>(async (resolve) => {
      const matches = await this.findTransactionsByIntent(step);
      if (matches.length === 0) {
        this.pushAiText(`第${stepNo}步：未找到匹配交易，跳过。`);
        resolve(true);
        return;
      }
      if (matches.length > 1) {
        const labels = matches.map((t: Transaction) =>
          `${new Date(t.date * 1000).toISOString().slice(0, 10)} ${t.comment || '无备注'} ${formatMoney(Math.abs(t.amount), 2)}`).join('\n');
        this.pushAiText(`第${stepNo}步：找到多笔匹配，跳过并请补充信息：\n${labels}`);
        resolve(true);
        return;
      }
      const target = matches[0];
      const isDelete = step.action === 'delete';
      const f: Record<string, string | number> = {};
      if (!isDelete) {
        const newAmount = Number(step.fields['amount'] || 0);
        if (newAmount > 0) { f['amount'] = newAmount; }
        const newComment = String(step.fields['comment'] || '');
        if (newComment) { f['comment'] = newComment; }
      }
      const stepConfirmAction: PendingAction = {
        type: isDelete ? 'delete' : 'edit',
        target: target,
        fields: f,
        stepNo: stepNo
      };
      // 记录确认后恢复上下文（继续执行 index+1）
      this.stepResume = { ctxId: ctxId, nextIndex: index + 1, actionType: stepConfirmAction.type };
      this.pendingAction = stepConfirmAction;
      this.chatMessages = [...this.chatMessages, {
        role: 'ai', text: '', kind: 'confirm',
        action: stepConfirmAction,
        stepCtxId: ctxId,
        confirmStepNo: stepNo
      }];
      // 挂起等待用户确认（confirmPendingAction 中恢复）
      resolve(true);
    });
  }


  /** 步骤摘要 */
  private stepSummary(step: AiIntent): string {
    const domainLabel = step.domain === 'account' ? '账户' : (step.domain === 'template' ? '模板' : '交易');
    const actionLabel = step.action === 'create' ? '创建' :
      (step.action === 'edit' ? '修改' :
      (step.action === 'delete' ? '删除' :
      (step.action === 'query' ? '查询' :
      (step.action === 'filter' ? '筛选' : '排序'))));
    const detail = step.action === 'create' ?
      `${step.fields['amount'] || ''} 元${step.fields['comment'] ? '（' + step.fields['comment'] + '）' : ''}` :
      (step.targets.length > 0 ? step.targets.join('、') : '');
    return `${domainLabel}·${actionLabel}${detail ? '：' + detail : ''}`;
  }

  /** 追加 AI 文本消息 */
  private pushAiText(text: string): void {
    this.chatMessages = [...this.chatMessages, { role: 'ai', text: text, kind: 'text' }];
  }

  /** 推送"思考中"气泡（进行中，无内容） */
  private pushThinking(): number {
    const id = Date.now();
    this.chatMessages = [...this.chatMessages, {
      role: 'ai', text: '', kind: 'thinking', thinkingDone: false, stepCtxId: id
    }];
    return id;
  }

  /** 更新思考气泡内容（收到 reasoning_content 后展示思考过程） */
  private updateThinking(id: number, content: string): void {
    this.chatMessages = this.chatMessages.map((m: ChatMessage) => {
      if (m.stepCtxId === id && m.kind === 'thinking') {
        return {
          role: 'ai', text: content, kind: 'thinking', thinkingDone: true, stepCtxId: id
        } as ChatMessage;
      }
      return m;
    });
  }

  /** 移除思考气泡（请求完成或失败） */
  private removeThinking(id: number): void {
    this.chatMessages = this.chatMessages.filter((m: ChatMessage) => !(m.stepCtxId === id && m.kind === 'thinking'));
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

  /** 精确查询：按账户/分类/时间范围/金额/收支类型过滤交易并返回明细 */
  private async preciseQueryReply(intent: AiIntent): Promise<string> {
    const accountName = String(intent.fields['account'] || '');
    const categoryName = String(intent.fields['category'] || '');
    const dateRange = String(intent.fields['dateRange'] || '');
    const keyword = intent.targets.length > 0 ? intent.targets[0] : String(intent.fields['comment'] || '');
    const minAmount = Number(intent.fields['amount'] || 0);
    const typeFilter = String(intent.fields['type'] || '');
    // 时间范围起点
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
    let startTs = 0;
    let endTs = 0;
    if (dateRange.includes('今天')) {
      startTs = startOfToday;
    } else if (dateRange.includes('昨天')) {
      startTs = startOfToday - 86400;
      endTs = startOfToday;
    } else if (dateRange.includes('本周')) {
      startTs = startOfToday - 7 * 86400;
    } else if (dateRange.includes('本月') || dateRange.includes('这个月')) {
      startTs = new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000;
    } else if (dateRange.includes('上月')) {
      startTs = new Date(now.getFullYear(), now.getMonth() - 1, 1).getTime() / 1000;
      endTs = new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000;
    }
    const accounts = await this.repository.getAccounts();
    const lines: string[] = [];
    let total = 0;
    let count = 0;
    for (let acc of accounts) {
      if (accountName && !acc.label.includes(accountName)) {
        continue;
      }
      const txList = await this.repository.getTransactions(acc.id);
      for (let t of txList) {
        if (startTs > 0 && t.date < startTs) {
          continue;
        }
        if (endTs > 0 && t.date >= endTs) {
          continue;
        }
        if (keyword && !t.comment.includes(keyword)) {
          continue;
        }
        if (minAmount > 0 && Math.abs(t.amount) < Math.round(minAmount * 100)) {
          continue;
        }
        // 转账默认排除（除非用户明确要转账）
        if (t.isTransfer && t.isTransfer()) {
          continue;
        }
        // 收支类型过滤
        if (typeFilter === 'expense' && t.amount >= 0) {
          continue;
        }
        if (typeFilter === 'income' && t.amount <= 0) {
          continue;
        }
        if (categoryName && t.categoryId >= 0) {
          const cat = this.categories.find((c: Category) => c.id === t.categoryId);
          if (cat && !cat.label.includes(categoryName)) {
            continue;
          }
        }
        count++;
        total += Math.abs(t.amount);
        const dateStr = new Date(t.date * 1000).toISOString().slice(0, 10);
        lines.push(`${dateStr} ${t.amount > 0 ? '收入' : '支出'} ${formatMoney(Math.abs(t.amount), 2)} ${t.comment || ''}`);
        if (count >= 10) {
          break;
        }
      }
      if (count >= 10) {
        break;
      }
    }
    if (lines.length === 0) {
      return `未找到符合条件的交易${keyword ? '（' + keyword + '）' : ''}。`;
    }
    const conds: string[] = [];
    if (accountName) { conds.push(`账户${accountName}`); }
    if (categoryName) { conds.push(`分类${categoryName}`); }
    if (dateRange) { conds.push(dateRange); }
    if (typeFilter === 'expense') { conds.push('支出'); }
    if (typeFilter === 'income') { conds.push('收入'); }
    const head = `共 ${count} 笔交易，合计 ${formatMoney(total, 2)} 元${conds.length > 0 ? '（' + conds.join('·') + '）' : ''}：`;
    return `${head}\n${lines.join('\n')}`;
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
            } else if (msg.kind === 'plan') {
              this.planBubble(msg)
            } else if (msg.kind === 'thinking') {
              this.thinkingBubble(msg)
            } else if (msg.kind === 'confirm') {
              this.confirmBubble(msg)
            } else if (msg.kind === 'candidates') {
              this.candidatesBubble()
            } else {
              this.aiBubble(msg.text)
            }
          }, (msg: ChatMessage, index: number) => `chat_${index}_${msg.kind}_${msg.text}_${msg.stepCtxId || 0}_${msg.confirmStepNo || 0}_${msg.thinkingDone === true ? 'T' : 'P'}`)
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

  /** 修改/删除确认气泡（对话内交互，不用系统弹窗） */
  @Builder
  confirmBubble(msg: ChatMessage) {
    Column({ space: 8 }) {
      if (msg.action) {
        Text(`${msg.confirmStepNo ? '第' + msg.confirmStepNo + '步·' : ''}${msg.action.type === 'delete' || msg.action.type === 'accountDelete' ? '删除确认' : '修改确认'}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
        Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)
        if (msg.action.type === 'accountDelete') {
          Text(this.accountDeleteSummary(msg.action))
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.textPrimary'))
        } else if (msg.action.type === 'templateDelete') {
          Text(`确定删除模板「${String(msg.action.fields['comment'] || '')}」吗？删除后不可恢复。`)
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.textPrimary'))
        } else if (msg.action.type === 'templateUse') {
          Text(`将按模板「${String(msg.action.fields['comment'] || '')}」创建一笔交易（${formatMoney(Number(msg.action.fields['amount'] || 0), 2)} 元）。确认执行吗？`)
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.textPrimary'))
        } else if (msg.action.type === 'delete') {
          Text(`确定删除这笔交易吗？删除后不可恢复。\n${this.txDetailText(msg.action.target)}`)
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.textPrimary'))
        } else {
          Text(`将修改以下交易：\n${this.txDetailText(msg.action.target)}\n\n${this.pendingEditSummary(msg.action)}`)
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.textPrimary'))
        }
        Row({ space: 8 }) {
          Button('取消')
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor($r('app.color.pageBackground'))
            .fontColor($r('app.color.textSecondary'))
            .onClick(() => {
              this.cancelPendingAction(msg.action!);
            })
          Button(this.confirmButtonLabel(msg.action))
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor(msg.action.type === 'delete' || msg.action.type === 'accountDelete' || msg.action.type === 'templateDelete' ? $r('app.color.colorExpense') : $r('app.color.primaryColor'))
            .fontColor(Color.White)
            .onClick(() => {
              this.confirmPendingAction(msg.action!);
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

  /** 确认按钮文案 */
  private confirmButtonLabel(action: PendingAction): string {
    const type = action?.type;
    if (type === 'templateUse') {
      return '确认执行';
    }
    if (type === 'delete' || type === 'accountDelete' || type === 'templateDelete') {
      return '确认删除';
    }
    return '确认修改';
  }

  /** 账户删除确认摘要 */
  private accountDeleteSummary(action: PendingAction): string {
    const accName = String(action?.fields['comment'] || '');
    const txCount = Number(action?.fields['amount'] || 0);
    const txNote = txCount > 0 ? `该账户下有 ${txCount} 笔交易（删除账户不会删除交易）。` : '该账户无交易。';
    return `确定删除账户「${accName}」吗？${txNote}删除后不可恢复。`;
  }

  /** 修改确认摘要（供 confirmBubble 使用） */
  private pendingEditSummary(action: PendingAction): string {
    const changes: string[] = [];
    const newAmount = Number(action?.fields['amount'] || 0);
    if (newAmount > 0) {
      changes.push(`金额改为 ${newAmount} 元`);
    }
    const newComment = String(action?.fields['comment'] || '');
    if (newComment) {
      changes.push(`备注改为「${newComment}」`);
    }
    const target = action?.target;
    const label = target ? target.comment || '无备注' : '';
    return `将修改「${label}」：${changes.join('，') || '无变更'}`;
  }

  /** 多步骤执行计划气泡（对话内确认，不使用系统弹窗） */
  @Builder
  planBubble(msg: ChatMessage) {
    Column({ space: 10 }) {
      Text('执行计划')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
      Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)
      if (msg.planSteps && msg.planSteps.length > 0) {
        ForEach(msg.planSteps, (s: AiIntent, i: number) => {
          Row() {
            Text(`${i + 1}.`)
              .fontSize(14)
              .fontColor($r('app.color.textSecondary'))
              .width(28)
            Text(this.stepSummary(s))
              .fontSize(14)
              .lineHeight(20)
              .fontColor($r('app.color.textPrimary'))
              .layoutWeight(1)
          }
          .width('100%')
        }, (s: AiIntent, i: number) => `plan_${i}_${s.domain}_${s.action}`)
      }
      Text(`将按顺序执行以上 ${msg.planSteps ? msg.planSteps.length : 0} 步；任一步失败将停止后续写操作。`)
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.textSecondary'))
      Row({ space: 8 }) {
        Button('取消')
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .backgroundColor($r('app.color.pageBackground'))
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.removePlanBubble(msg.stepCtxId!);
            this.stepCtx = null;
            this.pushAiText('已取消执行。');
          })
        Button('执行')
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .backgroundColor($r('app.color.primaryColor'))
          .fontColor(Color.White)
          .onClick(() => {
            this.removePlanBubble(msg.stepCtxId!);
            if (this.stepCtx && this.stepCtx.id === msg.stepCtxId) {
              this.runStepsFromIndex(msg.stepCtxId!, 0);
            } else {
              this.pushAiText('该执行计划已失效，请重新描述。');
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .borderRadius(18)
    .constraintSize({ maxWidth: '92%' })
  }

  /** 移除指定执行计划气泡 */
  private removePlanBubble(ctxId: number): void {
    const msgs = [...this.chatMessages];
    const idx = msgs.findIndex((m: ChatMessage) => m.kind === 'plan' && m.stepCtxId === ctxId);
    if (idx >= 0) {
      msgs.splice(idx, 1);
      this.chatMessages = msgs;
    }
  }

  /** 大模型思考气泡（请求期间显示"思考中…"，收到 reasoning_content 后展示思考过程） */
  @Builder
  thinkingBubble(msg: ChatMessage) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        if (msg.thinkingDone === true) {
          Image($r('app.media.ic_ai_robot'))
            .width(18)
            .height(18)
            .fillColor($r('app.color.textSecondary'))
        } else {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.primaryColor'))
        }
        Text(msg.thinkingDone === true ? '思考过程' : '正在思考…')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textSecondary'))
      }
      .width('100%')

      if (msg.thinkingDone === true && msg.text.length > 0) {
        Text(msg.text)
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.textSecondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.pageBackground'))
    .borderRadius(12)
    .constraintSize({ maxWidth: '90%' })
  }

  /** 多笔候选气泡（歧义消解：展示详细列表，用户点击选择） */
  @Builder
  candidatesBubble() {
    Column({ space: 6 }) {
      Text(`找到 ${this.candidateList.length} 笔匹配交易，请选择要${this.candidateType === 'delete' ? '删除' : '修改'}的一笔：`)
        .fontSize(14)
        .fontColor($r('app.color.textPrimary'))
      ForEach(this.candidateList, (tx: Transaction, index: number) => {
        Column() {
          Text(`${index + 1}. ${this.txDetailText(tx)}`)
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.textPrimary'))
            .width('100%')
        }
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.pageBackground'))
        .borderRadius(8)
        .onClick(() => {
          this.selectCandidate(tx);
        })
      }, (tx: Transaction, index: number) => `cand_${index}_${tx.id}`)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .borderRadius(18)
    .constraintSize({ maxWidth: '92%' })
  }

  /** 选择候选交易 → 转为待确认操作 */
  private selectCandidate(tx: Transaction): void {
    const f: Record<string, string | number> = {};
    f['amount'] = 0;
    f['comment'] = '';
    const candAction: PendingAction = {
      type: this.candidateType,
      target: tx,
      fields: f
    };
    this.pendingAction = candAction;
    // 移除候选气泡
    const msgs = [...this.chatMessages];
    const last = msgs[msgs.length - 1];
    if (last && last.kind === 'candidates') {
      msgs.pop();
    }
    msgs.push({ role: 'ai', text: '', kind: 'confirm', action: candAction });
    this.chatMessages = msgs;
    this.candidateList = [];
  }

  /** 交易详细信息文本（日期/账户/分类/金额/备注） */
  private txDetailText(tx: Transaction): string {
    const dateStr = new Date(tx.date * 1000).toISOString().slice(0, 10);
    const account = this.accounts.find((a: Account) => a.id === tx.accountId);
    const category = tx.categoryId >= 0 ? this.categories.find((c: Category) => c.id === tx.categoryId) : null;
    const accountLabel = account ? account.label : '未知账户';
    const categoryLabel = category ? category.label : '未分类';
    return `${dateStr} ${tx.comment || '无备注'} ${formatMoney(Math.abs(tx.amount), 2)} 元（${accountLabel}·${categoryLabel}）`;
  }

  /** 执行待确认操作（修改/删除）—— action 由调用方从 confirm 消息快照传入 */
  private async confirmPendingAction(action: PendingAction | null): Promise<void> {
    const act = action || this.pendingAction;
    if (!act) {
      return;
    }
    const target = act.target;
    try {
      if (act.type === 'templateDelete') {
        const tplId = Number(act.fields['templateId'] || 0);
        const tplTitle = String(act.fields['comment'] || '');
        await this.repository.deleteTemplate(tplId);
        this.pushAiText(`已删除模板「${tplTitle}」。`);
      } else if (act.type === 'templateUse') {
        const tplId = Number(act.fields['templateId'] || 0);
        const tplTitle = String(act.fields['comment'] || '');
        const templates = await this.repository.getTemplates();
        const tpl = templates.find((t: Template) => t.id === tplId);
        if (tpl) {
          const txId = await this.repository.instantiateTemplate(tpl);
          if (txId > 0) {
            this.pushAiText(`已按模板「${tplTitle}」创建交易 ${formatMoney(Math.abs(tpl.amount), 2)} 元。`);
          } else {
            this.pushAiText('模板创建交易失败。');
          }
        } else {
          this.pushAiText('模板不存在或已失效。');
        }
      } else if (act.type === 'accountDelete') {
        const accId = Number(act.fields['accountId'] || 0);
        const accName = String(act.fields['comment'] || '');
        await this.repository.deleteAccount(accId);
        this.pushAiText(`已删除账户「${accName}」。`);
      } else if (act.type === 'delete') {
        await this.repository.deleteTransaction(target.id);
        this.pushAiText(`已删除交易「${target.comment || '无备注'}」${formatMoney(Math.abs(target.amount), 2)} 元。`);
      } else {
        const newAmount = Number(act.fields['amount'] || 0);
        if (newAmount > 0) {
          const sign = target.amount >= 0 ? 1 : -1;
          target.amount = sign * Math.round(newAmount * 100);
        }
        const newComment = String(act.fields['comment'] || '');
        if (newComment) {
          target.comment = newComment;
        }
        await this.repository.updateTransaction(target);
        const changes: string[] = [];
        if (newAmount > 0) { changes.push(`金额改为 ${newAmount} 元`); }
        if (newComment) { changes.push(`备注改为「${newComment}」`); }
        this.pushAiText(`已修改交易：${changes.join('，')}。`);
      }
      this.removeConfirmBubble(act);
      if (this.pendingAction === act) {
        this.pendingAction = null;
      }
      this.onDataChanged();
      // 多步骤：若该确认来自步骤执行（stepResume 匹配），恢复执行剩余步骤
      const resume = this.stepResume;
      this.stepResume = null;
      if (resume && resume.actionType === act.type) {
        await this.runStepsFromIndex(resume.ctxId, resume.nextIndex);
      }
    } catch (e) {
      this.pushAiText('操作执行失败：' + JSON.stringify(e));
      if (this.pendingAction === act) {
        this.pendingAction = null;
      }
    }
  }

  /** 取消待确认操作—— action 由调用方从 confirm 消息快照传入 */
  private cancelPendingAction(action: PendingAction | null): void {
    this.removeConfirmBubble(action || this.pendingAction);
    if (this.pendingAction === (action || this.pendingAction)) {
      this.pendingAction = null;
    }
    // 多步骤取消：停止剩余步骤执行
    if (this.stepResume) {
      this.stepResume = null;
      this.stepCtx = null;
      this.pushAiText('已取消执行。');
    }
  }

  /** 移除指定确认气泡（action 匹配或最后一条 confirm） */
  private removeConfirmBubble(action?: PendingAction | null): void {
    const msgs = [...this.chatMessages];
    if (action) {
      // 按操作快照匹配移除（target/type/fields 相同的 confirm 消息）
      const idx = msgs.findIndex((m: ChatMessage) => m.kind === 'confirm' && m.action === action);
      if (idx >= 0) {
        msgs.splice(idx, 1);
        this.chatMessages = msgs;
        return;
      }
    }
    const last = msgs[msgs.length - 1];
    if (last && last.kind === 'confirm') {
      msgs.pop();
    }
    this.chatMessages = msgs;
  }

  /**
   * 用户发出新指令时调用：把此前未确认的修改/删除气泡折叠为一行提示，避免
   * "缩成一行后点击无反应"以及 pendingAction 被后续输入覆盖导致的错乱。
   * 同时放弃未执行的 plan / 步骤执行上下文。
   */
  private expirePendingConfirmBubbles(): void {
    // 将所有 confirm/plan/thinking 消息替换为已放弃/完成的提示文本（保留对话可读性，不产生空卡）
    const msgs = this.chatMessages.map((m: ChatMessage) => {
      if (m.kind === 'confirm' || m.kind === 'plan') {
        return {
          role: 'ai', text: '（上一步操作未确认，已被新指令覆盖，不再执行）', kind: 'text'
        } as ChatMessage;
      }
      if (m.kind === 'thinking') {
        return {
          role: 'ai', text: '（上一次思考已被新指令打断）', kind: 'text'
        } as ChatMessage;
      }
      return m;
    });
    this.chatMessages = msgs;
    this.pendingAction = null;
    this.stepCtx = null;
    this.stepResume = null;
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
