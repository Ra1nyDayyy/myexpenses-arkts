/**
 * 历史记录页面（对齐安卓 HistoryActivity + HistoryChart）
 * 按月展示收入/支出趋势（柱状图，无第三方图表库用 Column 高度模拟）
 */
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';
import { formatMoney } from '../model/Money';
import { Transaction } from '../model/Transaction';

interface MonthBar {
  label: string;
  income: number;
  expense: number;
}

@Entry
@Component
struct History {
  @State bars: MonthBar[] = [];
  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const all = await this.repository.getAllTransactions();
    // 取最近 6 个月
    const now = new Date();
    const list: MonthBar[] = [];
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      list.push({
        label: `${d.getMonth() + 1}月`,
        income: 0,
        expense: 0
      } as MonthBar);
    }
    for (let t of all) {
      const d = new Date(t.date * 1000);
      const idx = (now.getFullYear() - d.getFullYear()) * 12 + (now.getMonth() - d.getMonth());
      if (idx >= 0 && idx < 6) {
        if (t.isTransfer()) {
          continue;
        }
        if (t.amount > 0) {
          list[5 - idx].income += t.amount;
        } else {
          list[5 - idx].expense += t.amount;
        }
      }
    }
    this.bars = list;
  }

  private maxAbs(): number {
    let m = 0;
    for (let b of this.bars) {
      if (Math.abs(b.income) > m) { m = Math.abs(b.income); }
      if (Math.abs(b.expense) > m) { m = Math.abs(b.expense); }
    }
    return m || 1;
  }

  build() {
    Column() {
      PageHeader({
        title: '历史记录',
        onBack: () => {
          router.back();
        }
      })

      // 图例
      Row({ space: 16 }) {
        Row({ space: 4 }) {
          Row().width(12).height(12).borderRadius(2).backgroundColor($r('app.color.colorIncome'))
          Text('收入').fontSize(12).fontColor($r('app.color.textSecondary'))
        }
        Row({ space: 4 }) {
          Row().width(12).height(12).borderRadius(2).backgroundColor($r('app.color.colorExpense'))
          Text('支出').fontSize(12).fontColor($r('app.color.textSecondary'))
        }
        Blank()
        Text('近 6 个月')
          .fontSize(12)
          .fontColor($r('app.color.textTertiary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 柱状图区域
      Row() {
        ForEach(this.bars, (b: MonthBar) => {
          Column({ space: 4 }) {
            // 并列柱：左侧支出（红）、右侧收入（绿），底部对齐
            Row({ space: 3 }) {
              Column()
                .width(16)
                .height(this.barHeight(b.expense))
                .backgroundColor($r('app.color.colorExpense'))
                .borderRadius({ topLeft: 2, topRight: 2 })
              Column()
                .width(16)
                .height(this.barHeight(b.income))
                .backgroundColor($r('app.color.colorIncome'))
                .borderRadius({ topLeft: 2, topRight: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
            .height(200)
            Text(b.label)
              .fontSize(11)
              .fontColor($r('app.color.textSecondary'))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)
        }, (b: MonthBar) => `bar_${b.label}`)
      }
      .width('100%')
      .height(260)
      .padding({ left: 16, right: 16, top: 8 })
      .margin({ left: 12, right: 12, bottom: 12 })
      .borderRadius($r('app.float.native_emphasis_radius'))
      .backgroundColor($r('app.color.surfacePrimary'))

      // 数值明细
      List({ space: 8 }) {
        ForEach(this.bars, (b: MonthBar) => {
          ListItem() {
            Row() {
              Text(b.label)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
              Text(`收入 ¥${formatMoney(b.income, 2)}`)
                .fontSize(13)
                .fontColor($r('app.color.colorIncome'))
                .width('33%')
                .textAlign(TextAlign.End)
              Text(`支出 ¥${formatMoney(Math.abs(b.expense), 2)}`)
                .fontSize(13)
                .fontColor($r('app.color.colorExpense'))
                .width('33%')
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .height(60)
            .padding({ left: 16, right: 16 })
            .margin({ left: 12, right: 12 })
            .borderRadius($r('app.float.native_card_radius'))
            .backgroundColor($r('app.color.surfacePrimary'))
          }
        }, (b: MonthBar) => `m_${b.label}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  private barHeight(v: number): number {
    const ratio = Math.abs(v) / this.maxAbs();
    return Math.max(2, Math.round(ratio * 180));
  }
}
