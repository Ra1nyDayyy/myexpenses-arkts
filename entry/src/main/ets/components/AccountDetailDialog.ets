/**
 * 账户详情弹窗（对齐安卓：点击交易页左上角账户标题倒三角弹出）
 * 显示：起始余额 / 收入 / 支出 / 转账 / 当前余额 + 复制到剪贴板
 */
@CustomDialog
export struct AccountDetailDialog {
  controller?: CustomDialogController;
  /** 账户名 */
  @Prop accountLabel: string = '';
  /** 余额（当前） */
  @Prop currentBalance: number = 0;
  @Prop openingBalance: number = 0;
  @Prop sumIncome: number = 0;
  @Prop sumExpense: number = 0;
  @Prop sumTransfer: number = 0;
  /** 是否聚合视图（累计） */
  @Prop isAggregate: boolean = false;
  /** 货币符号 */
  @Prop currencySymbol: string = '¥';
  /** 小数位 */
  @Prop fractionDigits: number = 2;
  onCopy: () => void = () => {
  };

  private format(v: number): string {
    // 传入值单位为分（account 汇总），除以 10^fractionDigits 转元
    const divisor = Math.pow(10, this.fractionDigits);
    const value = v / divisor;
    const abs = Math.abs(value);
    const neg = value < 0;
    const fixed = abs.toFixed(this.fractionDigits);
    return (neg ? '-' : '') + this.currencySymbol + fixed;
  }

  @Builder
  detailRow(label: string, value: string, color: ResourceColor = $r('app.color.textPrimary')) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.textSecondary'))
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor(color)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(44)
  }

  build() {
    Column() {
      // 标题：账户名
      Row() {
        Text(this.accountLabel)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
        Blank()
        Text('✕')
          .fontSize(16)
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')
      .padding({ bottom: 8 })

      Divider()
        .color($r('app.color.dividerColor'))
        .strokeWidth(0.5)

      // 详情行
      this.detailRow('起始余额', this.format(this.openingBalance))
      if (this.sumIncome !== 0) {
        this.detailRow('收入', this.format(this.sumIncome), $r('app.color.colorIncome'))
      }
      if (this.sumExpense !== 0) {
        this.detailRow('支出', this.format(this.sumExpense), $r('app.color.colorExpense'))
      }
      if (this.sumTransfer !== 0) {
        this.detailRow('转帐', this.format(this.sumTransfer), $r('app.color.colorTransfer'))
      }
      Divider()
        .color($r('app.color.dividerColor'))
        .strokeWidth(0.5)
      this.detailRow('当前余额', this.format(this.currentBalance), $r('app.color.textPrimary'))

      // 复制到剪贴板（对齐安卓）
      Row({ space: 8 }) {
        Text('复制到剪贴板')
          .fontSize(14)
          .fontColor($r('app.color.primaryColor'))
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Start)
      .onClick(() => {
        this.onCopy();
        this.controller?.close();
      })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}