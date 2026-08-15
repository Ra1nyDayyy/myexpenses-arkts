/**
 * 统一空态组件：图标 + 主文案 + 次文案 + 操作按钮
 * 对应 Android 空态（no_accounts/no_expenses），采用鸿蒙原生简洁风格
 */
@Component
export struct EmptyState {
  icon: string = '';
  iconResource: Resource | null = null;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop actionText: string = '';
  onAction: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Stack() {
        if (this.iconResource !== null) {
          Image(this.iconResource)
            .width(38)
            .height(38)
            .fillColor($r('app.color.iconSecondary'))
        } else {
          Text(this.icon)
            .fontSize(36)
        }
      }
      .width(80)
      .height(80)
      .borderRadius(40)
      .backgroundColor($r('app.color.surfaceSecondary'))
      .alignContent(Alignment.Center)
      .margin({ bottom: 4 })

      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(14)
          .fontColor($r('app.color.textSecondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(21)
          .padding({ left: 32, right: 32 })
      }

      if (this.actionText.length > 0) {
        Button(this.actionText)
          .height($r('app.float.native_touch_target'))
          .padding({ left: 24, right: 24 })
          .borderRadius(24)
          .backgroundColor($r('app.color.primaryColor'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .stateEffect(true)
          .margin({ top: 8 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
