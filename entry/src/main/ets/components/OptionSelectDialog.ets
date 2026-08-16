/**
 * 通用单选对话框（用于设置页选项选择：主题/字体大小/语言/启动屏幕等）
 * 对齐 SortDialog 的 CustomDialog 模式，避免 promptAction.showDialog 多按钮 index 失效问题
 * 选项用字符串数组传递（@Prop 基础类型，避免对象数组深拷贝/类型问题）
 */
@CustomDialog
export struct OptionSelectDialog {
  controller?: CustomDialogController;
  /** 对话框标题 */
  @Prop title: string = '';
  /** 选项 key 列表（与 labels 一一对应） */
  @Prop optionKeys: string[] = [];
  /** 选项显示文案列表（与 keys 一一对应） */
  @Prop optionLabels: string[] = [];
  /** 当前选中项 key（用于高亮） */
  @Prop selectedKey: string = '';
  /** 确认回调：返回选中项的 key 与 index */
  onResult: (key: string, index: number) => void = () => {
  };
  onClose: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))

      Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

      ForEach(this.optionKeys, (key: string, index: number) => {
        Row() {
          Text(this.optionLabels[index] || key)
            .fontSize(15)
            .fontColor($r('app.color.textPrimary'))
            .layoutWeight(1)
          if (key === this.selectedKey) {
            Text('✓')
              .fontSize(15)
              .fontColor($r('app.color.primaryColor'))
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .borderRadius(8)
        .backgroundColor(key === this.selectedKey ? $r('app.color.surfaceBrandSoft') : Color.Transparent)
        .onClick(() => {
          this.onResult(key, index);
          this.onClose();
        })
      }, (key: string, index: number) => `opt_${index}_${key}`)

      Row() {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize(15)
          .backgroundColor($r('app.color.pageBackground'))
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.onClose();
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
