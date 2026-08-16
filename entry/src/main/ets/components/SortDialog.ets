/**
 * 排序方式对话框（对齐安卓 AccountListDisplayConfigurationDialogFragment）
 * - Prioritize flag order 复选框（优先标记顺序）
 * - 排序单选：文本标签 / 使用次数 / 最后使用的 / 自定义
 * - 确定按钮（居中模态对话框）
 */

interface SortOption {
  key: string;
  label: string;
}

@CustomDialog
export struct SortDialog {
  controller?: CustomDialogController;
  /** 优先标记顺序（对齐安卓 SORT_ACCOUNT_LIST_BY_FLAG_FIRST） */
  @Prop sortByFlagFirst: boolean = false;
  /** 当前排序方式（label/usages/last_used/custom） */
  @Prop currentSort: string = 'label';
  /** 确认回调 */
  onResult: (flagFirst: boolean, sortBy: string) => void = () => {
  };

  private sortOptions: Array<SortOption> = [
    { key: 'label', label: '文本标签' } as SortOption,
    { key: 'usages', label: '使用次数' } as SortOption,
    { key: 'last_used', label: '最后使用的' } as SortOption,
    { key: 'custom', label: '自定义' } as SortOption
  ];

  @State flagFirstChecked: boolean = false;
  @State sortChecked: string = 'label';

  aboutToAppear(): void {
    this.flagFirstChecked = this.sortByFlagFirst;
    this.sortChecked = this.currentSort;
  }

  build() {
    Column() {
      // 标题
      Text('排序方式')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')
        .textAlign(TextAlign.Start)

      // Prioritize flag order（复选框，对齐安卓 CheckBoxWithLabel）
      Row({ space: 10 }) {
        Checkbox({ name: 'flagFirst' })
          .select(this.flagFirstChecked)
          .selectedColor($r('app.color.primaryColor'))
          .onChange((checked: boolean) => {
            this.flagFirstChecked = checked;
          })
        Text('优先标记顺序')
          .fontSize(15)
          .fontColor($r('app.color.textPrimary'))
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12 })

      // 排序单选（对齐安卓 RadioGroupSection）
      Column() {
        ForEach(this.sortOptions, (opt: SortOption) => {
          Row({ space: 10 }) {
            Radio({ value: opt.key, group: 'sortGroup' })
              .checked(this.sortChecked === opt.key)
              .radioStyle({
                checkedBackgroundColor: $r('app.color.primaryColor'),
                uncheckedBorderColor: $r('app.color.textSecondary')
              })
              .onChange((checked: boolean) => {
                if (checked) {
                  this.sortChecked = opt.key;
                }
              })
            Text(opt.label)
              .fontSize(15)
              .fontColor($r('app.color.textPrimary'))
          }
          .width('100%')
          .height(48)
          .alignItems(VerticalAlign.Center)
        }, (opt: SortOption) => `sort_${opt.key}`)
      }
      .margin({ top: 4 })

      // 确定按钮（对齐安卓 ButtonRow）
      Button('确定')
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.primaryColor'))
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          this.onResult(this.flagFirstChecked, this.sortChecked);
          this.controller?.close();
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.surfaceElevated'))
    .borderRadius(16)
  }
}
