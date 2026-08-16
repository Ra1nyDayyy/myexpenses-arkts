/**
 * 类别分隔符编辑对话框（用于 CSV 导出配置）
 * 允许用户编辑主类别与子类别的连接分隔符
 */
@CustomDialog
export struct CategorySeparatorDialog {
  controller?: CustomDialogController;
  @Prop currentValue: string = ' > ';
  /** 确认回调：返回新的分隔符 */
  onResult: (value: string) => void = () => {
  };
  onClose: () => void = () => {
  };

  @State input: string = ' > ';

  aboutToAppear(): void {
    this.input = this.currentValue;
  }

  private confirm(): void {
    let v = this.input.trim();
    if (v.length === 0) {
      v = ' > ';
    }
    this.onResult(v);
    this.onClose();
  }

  build() {
    Column({ space: 16 }) {
      Text('类别分隔符')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))

      TextInput({ placeholder: '如： > 或 :', text: this.input })
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .backgroundColor($r('app.color.surfaceSecondary'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => {
          this.input = v;
        })

      Text('用于连接主类别和子类别的字符。')
        .fontSize(12)
        .fontColor($r('app.color.textSecondary'))

      Row({ space: 8 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .backgroundColor($r('app.color.pageBackground'))
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.onClose();
          })
        Button('确定')
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .backgroundColor($r('app.color.primaryColor'))
          .fontColor(Color.White)
          .onClick(() => {
            this.confirm();
          })
      }
      .width('100%')
    }
    .width('92%')
    .padding(20)
    .backgroundColor($r('app.color.surfaceElevated'))
    .borderRadius(18)
  }
}