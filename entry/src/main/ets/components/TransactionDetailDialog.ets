import { Transaction, CrStatus } from '../model/Transaction';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDateTime } from '../common/FormatUtils';

/**
 * 交易详情弹窗：对应 Android TransactionDetailFragment
 * 只读展示交易全部字段（金额、类型、分类、账户、日期、方式、收款人、备注、状态、标签、参考号）
 */
@CustomDialog
export struct TransactionDetailDialog {
  controller: CustomDialogController;
  transaction: Transaction = new Transaction();
  // 标签名列表（与 transaction.tagIds 按序对应）
  tagLabels: string[] = [];
  onClose: () => void = () => {
  };

  private fractionDigits(): number {
    return currencyByCode(this.transaction.currency).fractionDigits;
  }

  private symbol(): string {
    return currencyByCode(this.transaction.currency).symbol;
  }

  private typeLabel(): string {
    if (this.transaction.isTransfer()) {
      return '转账';
    }
    if (this.transaction.isSplit()) {
      return '拆分交易';
    }
    if (this.transaction.amount > 0) {
      return '收入';
    }
    if (this.transaction.amount < 0) {
      return '支出';
    }
    return '交易';
  }

  private amountText(): string {
    const sign = this.transaction.amount > 0 ? '+' : '';
    return `${sign}${this.symbol()}${formatMoney(this.transaction.amount, this.fractionDigits())}`;
  }

  private statusLabel(): string {
    switch (this.transaction.crStatus) {
      case CrStatus.CLEARED:
        return '已结算';
      case CrStatus.RECONCILED:
        return '已对账';
      case CrStatus.VOID:
        return '作废';
      case CrStatus.UNRECONCILED:
      default:
        return '未结算';
    }
  }

  private accountText(): string {
    if (this.transaction.isTransfer() && this.transaction.transferAccountLabel.length > 0) {
      return `${this.transaction.accountLabel || '账户'} → ${this.transaction.transferAccountLabel}`;
    }
    return this.transaction.accountLabel || '账户';
  }

  private tagsText(): string {
    return this.tagLabels.length > 0 ? this.tagLabels.join('、') : '';
  }

  build() {
    Column() {
      Row() {
        Text('交易详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
          .layoutWeight(1)
        Image($r('sys.media.ohos_ic_public_close'))
          .width(18)
          .height(18)
          .opacity(0.5)
          .onClick(() => {
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ bottom: 12 })

      // 金额 + 类型
      Row() {
        Text(this.amountText())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.amountColor())
          .layoutWeight(1)
        Text(this.typeLabel())
          .fontSize(13)
          .fontColor($r('app.color.textSecondary'))
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
      }
      .width('100%')
      .padding({ bottom: 16 })

      this.detailRow('分类', this.transaction.categoryPath || '未分类')
      this.detailRow('账户', this.accountText())
      this.detailRow('日期时间', formatDateTime(this.transaction.date))
      if (this.transaction.methodLabel.length > 0) {
        this.detailRow('付款方式', this.transaction.methodLabel)
      }
      if (this.transaction.payeeName.length > 0) {
        this.detailRow('收款人', this.transaction.payeeName)
      }
      if (this.transaction.comment.length > 0) {
        this.detailRow('备注', this.transaction.comment)
      }
      if (this.transaction.referenceNumber.length > 0) {
        this.detailRow('参考号', this.transaction.referenceNumber)
      }
      if (this.tagsText().length > 0) {
        this.detailRow('标签', this.tagsText())
      }
      this.detailRow('状态', this.statusLabel())
    }
    .width('88%')
    .padding(20)
    .backgroundColor($r('app.color.pageBackground'))
    .borderRadius(16)
  }

  @Builder
  detailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.textSecondary'))
        .width(80)
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.textPrimary'))
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
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
}