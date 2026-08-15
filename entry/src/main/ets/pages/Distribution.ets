/**
 * 分布图页面（对齐安卓 DistributionActivity）
 * 支持按 分类 / 收款人 / 付款方式 分布展示支出占比
 * 可视化：水平条形图（无第三方图表库，用 Progress/比例条实现）
 */
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';
import { formatMoney } from '../model/Money';
import { EmptyState } from '../components/EmptyState';

interface DistItem {
  label: string;
  amount: number;
}

@Entry
@Component
struct Distribution {
  /** 分布维度：category/payee/method */
  @State dim: number = 0;
  @State items: DistItem[] = [];
  @State total: number = 0;
  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    let map: Map<string, number>;
    if (this.dim === 1) {
      map = await this.repository.getPayeeSummary();
    } else if (this.dim === 2) {
      map = await this.repository.getMethodSummary();
    } else {
      map = await this.repository.getCategorySummary();
    }
    const list: DistItem[] = [];
    let sum = 0;
    map.forEach((v: number, k: string) => {
      if (v !== 0) {
        list.push({ label: k, amount: Math.abs(v) } as DistItem);
        sum += Math.abs(v);
      }
    });
    list.sort((a: DistItem, b: DistItem) => b.amount - a.amount);
    this.items = list;
    this.total = sum;
  }

  private dimLabel(): string {
    if (this.dim === 1) {
      return '按收款人';
    }
    if (this.dim === 2) {
      return '按付款方式';
    }
    return '按分类';
  }

  build() {
    Column() {
      PageHeader({
        title: '分布图',
        onBack: () => {
          router.back();
        }
      })

      // 维度切换（对齐安卓 DistributionBaseActivity 的 radio group）
      Row({ space: 8 }) {
        Button('分类')
          .height($r('app.float.native_touch_target'))
          .fontSize(14)
          .fontColor(this.dim === 0 ? Color.White : $r('app.color.textPrimary'))
          .padding({ left: 16, right: 16 })
          .borderRadius(24)
          .stateEffect(true)
          .backgroundColor(this.dim === 0 ? $r('app.color.primaryColor') : $r('app.color.chipBackground'))
          .onClick(() => {
            this.dim = 0;
            this.load();
          })
        Button('收款人')
          .height($r('app.float.native_touch_target'))
          .fontSize(14)
          .fontColor(this.dim === 1 ? Color.White : $r('app.color.textPrimary'))
          .padding({ left: 16, right: 16 })
          .borderRadius(24)
          .stateEffect(true)
          .backgroundColor(this.dim === 1 ? $r('app.color.primaryColor') : $r('app.color.chipBackground'))
          .onClick(() => {
            this.dim = 1;
            this.load();
          })
        Button('付款方式')
          .height($r('app.float.native_touch_target'))
          .fontSize(14)
          .fontColor(this.dim === 2 ? Color.White : $r('app.color.textPrimary'))
          .padding({ left: 16, right: 16 })
          .borderRadius(24)
          .stateEffect(true)
          .backgroundColor(this.dim === 2 ? $r('app.color.primaryColor') : $r('app.color.chipBackground'))
          .onClick(() => {
            this.dim = 2;
            this.load();
          })
      }
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 8 })

      // 汇总
      Row() {
        Text(`支出合计 ${this.dimLabel()}`)
          .fontSize(13)
          .fontColor($r('app.color.textSecondary'))
        Blank()
        Text(`¥${formatMoney(this.total, 2)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .margin({ left: 12, right: 12, bottom: 8 })
      .borderRadius($r('app.float.native_card_radius'))
      .backgroundColor($r('app.color.surfacePrimary'))

      if (this.items.length === 0) {
        EmptyState({
          iconResource: $r('app.media.ic_chart'),
          title: '暂无支出数据',
          subtitle: '产生支出后会在这里显示分布情况'
        })
        .width('100%')
        .layoutWeight(1)
      } else {
        // 水平条形分布列表
        List({ space: 8 }) {
          ForEach(this.items, (item: DistItem) => {
            ListItem() {
              this.distRow(item)
            }
          }, (item: DistItem) => `dist_${item.label}_${item.amount}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  distRow(item: DistItem) {
    Column({ space: 4 }) {
      Row() {
      Text(item.label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textPrimary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`¥${formatMoney(item.amount, 2)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.colorExpense'))
      }
      .width('100%')
      // 比例条（对齐安卓 PieChart 的占比视觉）
      Row() {
        Row()
          .width(this.total > 0 ? `${Math.max(2, Math.round(item.amount / this.total * 100))}%` : '0%')
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.primaryColor'))
        Blank()
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.surfacePrimary'))
    .borderRadius($r('app.float.native_card_radius'))
  }
}
