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
  // 聚合模式（全部账户）：显示所属账户名（对齐安卓 transaction.accountLabel 行）
  @Prop showAccount: boolean = false;
  // 操作菜单项（点击行时在行下方弹出，对齐安卓 PopupMenu）：空数组表示不弹菜单（如选择模式）
  menuItems: Array<MenuElement> = [];
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
    // 对齐安卓 buildPrimaryInfo：无分类时显示备注/收款人，避免"未分类"占位
    if (this.transaction.categoryPath && this.transaction.categoryPath.length > 0) {
      return this.transaction.categoryPath;
    }
    return this.transaction.comment || this.transaction.payeeName || '';
  }

  private secondaryText(): string {
    const parts: string[] = [];
    if (this.transaction.methodLabel) {
      parts.push(this.transaction.methodLabel);
    }
    // 主标题已含分类或备注，副标题补充收款人（避免重复）
    if (this.transaction.payeeName && this.transaction.payeeName !== this.primaryText()) {
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

      // 状态切换块（点击缩放动画 + 涟漪）；ArkUI 点击事件不冒泡，不会触发行级操作菜单
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
        // 聚合模式显示账户名（对齐安卓：非转账且 accountLabel != null 时显示账户行）
        if (this.showAccount && !this.transaction.isTransfer() && this.transaction.accountLabel.length > 0) {
          Text(this.transaction.accountLabel)
            .fontSize(11)
            .fontColor($r('app.color.textSecondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        if (this.primaryText().length > 0) {
          Text(this.primaryText())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
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

      // 查看箭头（对齐安卓交易记录查看入口）
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(14)
        .height(14)
        .opacity(0.35)
        .margin({ left: 6 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.selected ? $r('app.color.rowSelectedBackground') : Color.Transparent)
    // 操作菜单锚定在交易行下方（对齐安卓 PopupMenu，替代底部 ActionSheet）
    .bindMenu(this.menuItems, { placement: Placement.Bottom })
    .onClick(() => {
      this.onItemClick(this.transaction.id);
    })
    .gesture(LongPressGesture().onAction(() => {
      this.onItemLongPress(this.transaction.id);
    }))
  }
}