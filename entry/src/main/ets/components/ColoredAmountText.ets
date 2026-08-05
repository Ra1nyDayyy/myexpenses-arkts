import { formatMoney } from '../model/Money';

/**
 * 金额文本：颜色按正负（正=收入色、负=支出色、零=灰色）
 * 对应 Android ColoredAmountText
 */
@Component
export struct ColoredAmountText {
  @Prop amountMinor: number = 0;
  @Prop fractionDigits: number = 2;
  @Prop type: number = 0; // 1 收入 / -1 支出 / 0 自动
  @Prop fontSize: number = 16;
  @Prop fontWeight: FontWeight = FontWeight.Normal;
  @Prop withSymbol: boolean = true;
  @Prop symbol: string = '¥';
  @Prop absolute: boolean = false;

  private color(): ResourceColor {
    if (this.type === 1) {
      return $r('app.color.colorIncome');
    }
    if (this.type === -1) {
      return $r('app.color.colorExpense');
    }
    if (this.amountMinor > 0) {
      return $r('app.color.colorIncome');
    }
    if (this.amountMinor < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  private text(): string {
    let amount = this.absolute ? Math.abs(this.amountMinor) : this.amountMinor;
    let formatted = formatMoney(amount, this.fractionDigits);
    if (this.withSymbol) {
      return `${this.symbol}${formatted}`;
    }
    return formatted;
  }

  build() {
    Text(this.text())
      .fontSize(this.fontSize)
      .fontWeight(this.fontWeight)
      .fontColor(this.color())
  }
}