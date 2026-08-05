import { Account } from '../model/Account';
import { intToColor } from '../common/Theme';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';

/**
 * 账户行组件：对应 Android AccountCardV2
 * 显示账户指示器（颜色圆/环形进度）、名称、描述、余额、展开汇总
 */
@Component
export struct AccountRow {
  account: Account = new Account();
  @Prop selected: boolean = false;
  @Prop expanded: boolean = false;
  @Prop showEquivalent: boolean = false;
  onToggle: (id: number) => void = () => {
  };
  onNavigate: (id: number) => void = () => {
  };
  onEdit: (id: number) => void = () => {
  };
  onDelete: (id: number) => void = () => {
  };
  onToggleSealed: (id: number) => void = () => {
  };
  onToggleExclude: (id: number) => void = () => {
  };

  private accountColor(): string {
    return intToColor(this.account.color);
  }

  private fractionDigits(): number {
    return currencyByCode(this.account.currency).fractionDigits;
  }

  private symbol(): string {
    return currencyByCode(this.account.currency).symbol;
  }

  build() {
    Column() {
      Row() {
        // 账户颜色指示器
        Stack() {
          if (this.account.criterion > 0) {
            // 环形进度（简化：圆形+百分比文字）
            Circle()
              .width(36)
              .height(36)
              .fill(Color.Transparent)
              .stroke(this.accountColor())
              .strokeWidth(3)
            Text(this.progressPercent())
              .fontSize(9)
              .fontColor(this.accountColor())
          } else {
            Circle()
              .width(36)
              .height(36)
              .fill(this.accountColor())
          }
        }
        .width(42)
        .height(42)

        // 名称与描述
        Column() {
          Row() {
            Text(this.account.label)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.account.sealed) {
              Image($r('app.media.ic_locked'))
                .width(14)
                .height(14)
                .margin({ left: 4 })
            }
            if (this.account.excludeFromTotals) {
              Image($r('app.media.ic_exclude'))
                .width(14)
                .height(14)
                .margin({ left: 4 })
            }
          }
          .width('100%')

          if (this.account.description.length > 0) {
            Text(this.account.description)
              .fontSize(12)
              .fontColor($r('app.color.textSecondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12, right: 8 })

        // 余额
        Column() {
          Text(`${this.symbol()}${formatMoney(this.account.currentBalance, this.fractionDigits())}`)
            .fontSize(15)
            .fontColor(this.balanceColor())
            .maxLines(1)
          if (this.showEquivalent && this.account.currency !== 'CNY') {
            Text(`≈ ${formatMoney(this.account.equivalentCurrentBalance, 2)}`)
              .fontSize(11)
              .fontColor($r('app.color.textSecondary'))
          }
        }
        .alignItems(HorizontalAlign.End)

        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .opacity(0.5)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .onClick(() => {
        this.onToggle(this.account.id);
      })

      // 展开的汇总
      if (this.expanded) {
        Column({ space: 4 }) {
          this.sumRow('起始余额', formatMoney(this.account.openingBalance, this.fractionDigits()))
          if (this.account.sumIncome !== 0) {
            this.sumRow('收入', formatMoney(this.account.sumIncome, this.fractionDigits()), $r('app.color.colorIncome'))
          }
          if (this.account.sumExpense !== 0) {
            this.sumRow('支出', formatMoney(this.account.sumExpense, this.fractionDigits()), $r('app.color.colorExpense'))
          }
          if (this.account.sumTransfer !== 0) {
            this.sumRow('转帐', formatMoney(this.account.sumTransfer, this.fractionDigits()), $r('app.color.colorTransfer'))
          }
          Divider()
            .color($r('app.color.dividerColor'))
            .strokeWidth(1)
          this.sumRow('当前余额', formatMoney(this.account.currentBalance, this.fractionDigits()), this.balanceColor(), true)

          // 操作按钮行（对齐安卓账户操作）
          Row({ space: 16 }) {
            Text('编辑')
              .fontSize(13)
              .fontColor($r('app.color.primaryColor'))
              .onClick(() => {
                this.onEdit(this.account.id);
              })
            Text(this.account.excludeFromTotals ? '计入总数' : '不计入总数')
              .fontSize(13)
              .fontColor($r('app.color.primaryColor'))
              .onClick(() => {
                this.onToggleExclude(this.account.id);
              })
            Text(this.account.sealed ? '解除关闭' : '关闭账户')
              .fontSize(13)
              .fontColor($r('app.color.textTertiary'))
              .onClick(() => {
                this.onToggleSealed(this.account.id);
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 6 })
        }
        .padding({ left: 62, right: 16, bottom: 12 })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .backgroundColor(this.selected ? $r('app.color.rowSelectedBackground') : Color.Transparent)
    .borderRadius(0)
  }

  @Builder
  sumRow(label: string, value: string, color: ResourceColor = $r('app.color.textPrimary'), bold: boolean = false) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor(color)
        .fontWeight(bold ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
  }

  private balanceColor(): ResourceColor {
    if (this.account.currentBalance > 0) {
      return $r('app.color.colorIncome');
    }
    if (this.account.currentBalance < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  private progressPercent(): string {
    if (this.account.criterion > 0) {
      const progress = Math.min(100, Math.abs(this.account.currentBalance) / this.account.criterion * 100);
      return `${Math.round(progress)}%`;
    }
    return '';
  }
}