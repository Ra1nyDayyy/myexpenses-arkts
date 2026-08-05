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
    Column({ space: 16 }) {
      // 图标占位（圆形底）
      Stack() {
        if (this.iconResource !== null) {
          Image(this.iconResource)
            .width(36)
            .height(36)
            .fillColor($r('app.color.textSecondary'))
        } else {
          Text(this.icon)
            .fontSize(36)
        }
      }
      .width(72)
      .height(72)
      .borderRadius(36)
      .backgroundColor($r('app.color.cardBackgroundColor'))
      .alignContent(Alignment.Center)

      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(13)
          .fontColor($r('app.color.textSecondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(20)
          .padding({ left: 24, right: 24 })
      }

      if (this.actionText.length > 0) {
        Button(this.actionText)
          .height(40)
          .padding({ left: 24, right: 24 })
          .backgroundColor($r('app.color.primaryColor'))
          .fontSize(15)
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