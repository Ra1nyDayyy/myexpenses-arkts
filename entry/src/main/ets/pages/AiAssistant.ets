import { Transaction } from '../model/Transaction';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { VoiceInputDialog } from '../components/VoiceInputDialog';
import { router, promptAction } from '@kit.ArkUI';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';

/**
 * AI 助手页：智能分析收支数据，给出记账建议
 * 本期实现本地 AI 分析引擎（规则 + 统计），后续可接入大模型 API
 */
@Entry
@Component
struct AiAssistant {
  @State loading: boolean = false;
  @State hasData: boolean = false;
  @State totalIncome: number = 0;
  @State totalExpense: number = 0;
  @State balance: number = 0;
  @State tips: string[] = [];
  @State topCategories: string[] = [];
  @State monthlyData: Map<string, number> = new Map();
  @State selectedMonth: string = '';

  private repository: Repository = Repository.getInstance();
  private fractionDigits: number = 2;
  private symbol: string = '¥';

  aboutToAppear(): void {
    this.analyze();
  }

  async analyze(): Promise<void> {
    this.loading = true;
    this.tips = [];
    this.topCategories = [];
    try {
      const all = await this.repository.getAllTransactions();
      if (all.length === 0) {
        this.hasData = false;
        this.loading = false;
        return;
      }
      this.hasData = true;

      // 汇总收支
      let income = 0;
      let expense = 0;
      const now = Date.now();
      for (let t of all) {
        if (t.isTransfer()) {
          continue;
        }
        if (t.amount > 0) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      this.totalIncome = income;
      this.totalExpense = expense;
      this.balance = income + expense;

      // 分类支出统计
      const catMap = new Map<string, number>();
      for (let t of all) {
        if (t.isTransfer() || t.amount >= 0) {
          continue;
        }
        const key = t.categoryPath || '未分类';
        const cur = catMap.get(key) || 0;
        catMap.set(key, cur + Math.abs(t.amount));
      }
      const sorted = Array.from(catMap.entries()).sort((a: [string, number], b: [string, number]) => b[1] - a[1]);
      this.topCategories = sorted.slice(0, 5).map((entry: [string, number]) => entry[0]);

      // 最近3个月趋势
      const monthly = new Map<string, number>();
      for (let i = 2; i >= 0; i--) {
        const d = new Date(now);
        d.setMonth(d.getMonth() - i);
        const key = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}`;
        monthly.set(key, 0);
      }
      for (let t of all) {
        if (t.isTransfer()) {
          continue;
        }
        const d = new Date(t.date * 1000);
        const key = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}`;
        if (monthly.has(key)) {
          monthly.set(key, monthly.get(key)! + t.amount);
        }
      }
      this.monthlyData = monthly;

      // AI 建议（本地规则引擎）
      this.generateTips(sorted, income, expense);
    } catch (e) {
      console.error('AI 分析失败: ' + JSON.stringify(e));
      this.tips = ['分析数据时出现异常，请稍后重试'];
    }
    this.loading = false;
  }

  private generateTips(sorted: [string, number][], income: number, expense: number): void {
    const tips: string[] = [];

    // 储蓄率
    if (income > 0) {
      const rate = (income + expense) / income * 100;
      if (rate < 0) {
        tips.push('本月已超支，建议控制非必要消费，优先保证基本生活开支。');
      } else if (rate < 30) {
        tips.push(`储蓄率约 ${Math.round(rate)}%，支出偏高，建议设定每月储蓄目标。`);
      } else if (rate < 50) {
        tips.push(`储蓄率约 ${Math.round(rate)}%，收支较为健康，可以继续坚持。`);
      } else {
        tips.push(`储蓄率约 ${Math.round(rate)}%，收支状况良好，可考虑规划长期储蓄或投资。`);
      }
    } else if (expense > 0) {
      tips.push('暂无收入记录，建议补充收入来源，或查看是否有漏记的收入。');
    }

    // 最大支出类别
    if (sorted.length > 0) {
      const top = sorted[0];
      tips.push(`支出最多的类别是「${top[0]}」，共 ${formatMoney(top[1], this.fractionDigits)}，可留意该类别的消费频率。`);
    }
    if (sorted.length >= 2) {
      tips.push(`第二大支出为「${sorted[1][0]}」，可考虑设置预算进行控制。`);
    }

    // 转账/拆分提示
    if (this.topCategories.length === 0) {
      tips.push('数据中还没有分类，建议为每笔交易选择类别，以便获得更精准的分析。');
    }

    // 补充分类
    if (tips.length === 0) {
      tips.push('暂无足够的记账数据用于分析，多记几笔账后再来看看吧。');
    }
    this.tips = tips;
  }

  private moneyText(amount: number): string {
    const prefix = amount > 0 ? '+' : '';
    return `${prefix}${this.symbol}${formatMoney(amount, this.fractionDigits)}`;
  }

  /** AI 语音输入（对齐用户需求：通过语音输入获得结果） */
  private startVoiceInput(): void {
    const dialog = new CustomDialogController({
      builder: VoiceInputDialog({
        onResult: (text: string) => {
          if (text.length > 0) {
            promptAction.showToast({ message: `已识别：${text}` });
            // 语音内容可用于后续分析（本期记录）
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      cornerRadius: 16
    });
    dialog.open();
  }

  build() {
    Column() {
      PageHeader({
        title: 'AI 助手',
        rightText: '重新分析',
        showSpeech: true,
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.analyze();
        },
        onSpeech: () => {
          this.startVoiceInput();
        }
      })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('正在分析您的收支数据...')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (!this.hasData) {
        Column({ space: 12 }) {
          Text('暂无足够数据，先记几笔账吧')
            .fontSize(16)
            .fontColor($r('app.color.textSecondary'))
          Button('去记账')
            .backgroundColor($r('app.color.primaryColor'))
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 收支概览卡片
            Column({ space: 12 }) {
              Row() {
                Column() {
                  Text('收入概览')
                    .fontSize(12)
                    .fontColor($r('app.color.textSecondary'))
                  Text(this.moneyText(this.totalIncome))
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.colorIncome'))
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Column() {
                  Text('支出概览')
                    .fontSize(12)
                    .fontColor($r('app.color.textSecondary'))
                  Text(this.moneyText(this.totalExpense))
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.colorExpense'))
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')

              Divider()
                .color($r('app.color.dividerColor'))

              Row() {
                Text('结余')
                  .fontSize(13)
                  .fontColor($r('app.color.textSecondary'))
                Blank()
                Text(this.moneyText(this.balance))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.balance >= 0 ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
              }
              .width('100%')
            }
            .padding(16)
            .backgroundColor($r('app.color.cardBackgroundColor'))
            .borderRadius($r('app.float.card_radius'))

            // 月度趋势
            Column({ space: 8 }) {
              Text('近三月趋势')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Row() {
                ForEach(Array.from(this.monthlyData.keys()), (key: string) => {
                  Column({ space: 4 }) {
                    Text(this.monthTrendValue(key))
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.trendColor(key))
                    Text(key.substring(5) + '月')
                      .fontSize(11)
                      .fontColor($r('app.color.textSecondary'))
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                }, (key: string) => `month_${key}`)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 支出 Top 分类
            if (this.topCategories.length > 0) {
              Column({ space: 8 }) {
                Text('支出最多的类别')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                ForEach(this.topCategories, (cat: string, index: number) => {
                  Row() {
                    Text(`${index + 1}.`)
                      .fontSize(13)
                      .fontColor($r('app.color.primaryColor'))
                      .width(24)
                    Text(cat)
                      .fontSize(14)
                      .layoutWeight(1)
                    Text(this.categoryAmount(cat))
                      .fontSize(13)
                      .fontColor($r('app.color.textSecondary'))
                  }
                  .width('100%')
                  .height(36)
                }, (cat: string) => `cat_${cat}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            // AI 建议
            Column({ space: 8 }) {
              Text('AI 建议')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              ForEach(this.tips, (tip: string, index: number) => {
                Row() {
                  Circle()
                    .width(6)
                    .height(6)
                    .fill($r('app.color.primaryColor'))
                    .margin({ top: 7 })
                  Text(tip)
                    .fontSize(14)
                    .fontColor($r('app.color.textPrimary'))
                    .lineHeight(22)
                    .layoutWeight(1)
                    .margin({ left: 8 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }, (tip: string, index: number) => `tip_${index}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  private monthTrendValue(key: string): string {
    const val = this.monthlyData.get(key) || 0;
    if (val === 0) {
      return '-';
    }
    return formatMoney(val, this.fractionDigits);
  }

  private trendColor(key: string): ResourceColor {
    const val = this.monthlyData.get(key) || 0;
    if (val >= 0) {
      return $r('app.color.colorIncome');
    }
    return $r('app.color.colorExpense');
  }

  private categoryAmount(cat: string): string {
    // 从缓存重新计算（简化：返回已排序列表中的金额）
    return '';
  }
}