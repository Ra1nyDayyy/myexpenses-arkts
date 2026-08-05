import { Transaction, CrStatus } from '../model/Transaction';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';

/**
 * 交易行组件：对应 Android NewTransactionRenderer
 * 显示类别图标、状态切换、分类/备注/收款人、金额/日期
 */
@Component
export struct TransactionRow {
  transaction: Transaction = new Transaction();
  @Prop selected: boolean = false;
  onToggleStatus: (id: number) => void = () => {
  };
  onItemLongPress: (id: number) => void = () => {
  };
  onItemClick: (id: number) => void = () => {
  };

  private fractionDigits(): number {
    return currencyByCode(this.transaction.currency).fractionDigits;
  }

  private symbol(): string {
    return currencyByCode(this.transaction.currency).symbol;
  }

  private primaryText(): string {
    if (this.transaction.isTransfer()) {
      return `${this.transaction.accountLabel || '账户'} → ${this.transaction.transferAccountLabel || '账户'}`;
    }
    if (this.transaction.isSplit()) {
      return '拆分交易';
    }
    return this.transaction.categoryPath || '未分类';
  }

  private secondaryText(): string {
    const parts: string[] = [];
    if (this.transaction.methodLabel) {
      parts.push(this.transaction.methodLabel);
    }
    if (this.transaction.comment) {
      parts.push(this.transaction.comment);
    }
    if (this.transaction.payeeName) {
      parts.push(this.transaction.payeeName);
    }
    return parts.join(' · ');
  }

  private amountColor(): ResourceColor {
    if (this.transaction.isTransfer()) {
      return $r('app.color.colorTransfer');
    }
    if (this.transaction.amount > 0) {
      return $r('app.color.colorIncome');
    }
    if (this.transaction.amount < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  private statusColor(): ResourceColor {
    if (this.transaction.crStatus === CrStatus.CLEARED) {
      return $r('app.color.CLEARED');
    }
    if (this.transaction.crStatus === CrStatus.RECONCILED) {
      return $r('app.color.RECONCILED');
    }
    if (this.transaction.crStatus === CrStatus.VOID) {
      return $r('app.color.VOID');
    }
    return $r('app.color.UNRECONCILED');
  }

  private iconResource(): Resource {
    if (this.transaction.isTransfer()) {
      return $r('app.media.ic_transfer');
    }
    if (this.transaction.isSplit()) {
      return $r('app.media.ic_split');
    }
    if (this.transaction.amount > 0) {
      return $r('app.media.ic_income');
    }
    if (this.transaction.amount < 0) {
      return $r('app.media.ic_expense');
    }
    return $r('app.media.ic_neutral');
  }

  private dateText(): string {
    const d = new Date(this.transaction.date * 1000);
    const h = d.getHours().toString().padStart(2, '0');
    const min = d.getMinutes().toString().padStart(2, '0');
    return `${d.getMonth() + 1}月${d.getDate()}日 ${h}:${min}`;
  }

  build() {
    Row() {
      // 类别图标
      Stack() {
        Image(this.iconResource())
          .width(18)
          .height(18)
          .fillColor(this.amountColor())
      }
      .width(30)
      .height(30)
      .alignContent(Alignment.Center)

      // 状态切换块（点击缩放动画 + 涟漪）
      Row()
        .width(8)
        .height(20)
        .backgroundColor(this.statusColor())
        .margin({ left: 4, right: 10 })
        .borderRadius(2)
        .onClick(() => {
          animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
            this.onToggleStatus(this.transaction.id);
          })
        })

      // 主信息
      Column({ space: 2 }) {
        Text(this.primaryText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.secondaryText().length > 0) {
          Text(this.secondaryText())
            .fontSize(12)
            .fontColor($r('app.color.textSecondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 0, right: 8 })

      // 金额与日期
      Column({ space: 2 }) {
        Text(`${this.transaction.amount > 0 ? '+' : ''}${this.symbol()}${formatMoney(this.transaction.amount, this.fractionDigits())}`)
          .fontSize(15)
          .fontColor(this.amountColor())
          .maxLines(1)
        Text(this.dateText())
          .fontSize(11)
          .fontColor($r('app.color.textSecondary'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.selected ? $r('app.color.rowSelectedBackground') : Color.Transparent)
    .onClick(() => {
      this.onItemClick(this.transaction.id);
    })
    .gesture(LongPressGesture().onAction(() => {
      this.onItemLongPress(this.transaction.id);
    }))
  }
}