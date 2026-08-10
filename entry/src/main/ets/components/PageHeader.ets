/**
 * 统一页面顶部栏（鸿蒙原生风格）
 * 左侧返回箭头 + 标题 + 右侧可选操作（文本/符号按钮）
 */
@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop rightText: string = '';
  @Prop showMore: boolean = false;
  /** 图表按钮（资产负债表右上角，对齐安卓 TooltipIconButton 图表开关） */
  @Prop showChart: boolean = false;
  onBack: () => void = () => {
  };
  onRight: () => void = () => {
  };
  onMore: () => void = () => {
  };
  onChart: () => void = () => {
  };

  build() {
    Row() {
      // 返回按钮
      if (this.showBack) {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24)
          .height(24)
          .onClick(() => {
            this.onBack();
          })
      } else {
        Blank()
          .width(24)
      }

      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))
        .margin({ left: 12 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 右侧操作（文本按钮）
      if (this.rightText.length > 0) {
        Text(this.rightText)
          .fontSize(16)
          .fontColor($r('app.color.primaryColor'))
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.onRight();
          })
      }

      // 图表按钮（资产负债表右上角，对齐安卓图表开关）
      if (this.showChart) {
        Image($r('app.media.ic_chart'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .fillColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.onChart();
          })
      }

      // 更多选项图标
      if (this.showMore) {
        Image($r('sys.media.ohos_ic_public_more'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .onClick(() => {
            this.onMore();
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }
}
