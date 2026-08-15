/**
 * 统一页面顶部栏（鸿蒙原生风格）。
 * 保留原有属性与回调契约，只统一标题、触控区域、状态色和无障碍语义。
 */
@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop rightText: string = '';
  @Prop showMore: boolean = false;
  @Prop showHelp: boolean = false;
  @Prop showChart: boolean = false;
  @Prop moreMenu: Array<MenuElement> = [];
  @Prop showSpeech: boolean = false;
  @Prop titleMenu: Array<MenuElement> = [];
  @Prop showFilter: boolean = false;
  @Prop filterActive: boolean = false;
  @Prop showSearch: boolean = false;
  @Prop searchActive: boolean = false;
  @Prop showTemplates: boolean = false;
  onBack: () => void = () => {
  };
  onRight: () => void = () => {
  };
  onMore: () => void = () => {
  };
  onHelp: () => void = () => {
  };
  onChart: () => void = () => {
  };
  onSpeech: () => void = () => {
  };
  onFilter: () => void = () => {
  };
  onSearch: () => void = () => {
  };
  onTemplates: () => void = () => {
  };

  @Builder
  iconAction(icon: Resource, label: string, color: ResourceColor, onClick: () => void) {
    Button() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(color)
    }
    .type(ButtonType.Circle)
    .width($r('app.float.native_touch_target'))
    .height($r('app.float.native_touch_target'))
    .backgroundColor(Color.Transparent)
    .stateEffect(true)
    .accessibilityText(label)
    .onClick(onClick)
  }

  build() {
    Row() {
      if (this.showBack) {
        this.iconAction(
          $r('sys.media.ohos_ic_public_arrow_left'),
          '返回',
          $r('app.color.textPrimary'),
          () => this.onBack()
        )
      }

      if (this.titleMenu.length > 0) {
        Row() {
          Text(this.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.textPrimary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.iconSecondary'))
            .margin({ left: 4 })
        }
        .height($r('app.float.native_touch_target'))
        .margin({ left: this.showBack ? 0 : 8 })
        .bindMenu(this.titleMenu)
      } else {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: this.showBack ? 0 : 8 })
      }
      Blank()

      if (this.rightText.length > 0) {
        Button(this.rightText)
          .height($r('app.float.native_touch_target'))
          .padding({ left: 14, right: 14 })
          .backgroundColor(Color.Transparent)
          .fontSize(16)
          .fontColor($r('app.color.primaryColor'))
          .fontWeight(FontWeight.Medium)
          .stateEffect(true)
          .onClick(() => {
            this.onRight();
          })
      }

      if (this.showSpeech) {
        this.iconAction($r('app.media.ic_mic'), '语音输入', $r('app.color.iconSecondary'), () => this.onSpeech())
      }
      if (this.showChart) {
        this.iconAction($r('app.media.ic_chart'), '切换图表', $r('app.color.iconSecondary'), () => this.onChart())
      }
      if (this.showHelp) {
        this.iconAction($r('app.media.ic_help'), '帮助', $r('app.color.iconSecondary'), () => this.onHelp())
      }
      if (this.showFilter) {
        this.iconAction(
          $r('app.media.ic_filter'),
          this.filterActive ? '筛选已启用' : '筛选',
          this.filterActive ? $r('app.color.primaryColor') : $r('app.color.iconSecondary'),
          () => this.onFilter()
        )
      }
      if (this.showSearch) {
        this.iconAction(
          $r('sys.media.ohos_ic_public_search_filled'),
          '搜索',
          this.searchActive ? $r('app.color.primaryColor') : $r('app.color.iconSecondary'),
          () => this.onSearch()
        )
      }
      if (this.showTemplates) {
        this.iconAction($r('app.media.ic_tab_template'), '我的模板', $r('app.color.iconSecondary'), () => this.onTemplates())
      }
      if (this.showMore) {
        Button() {
          Image($r('sys.media.ohos_ic_public_more'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.iconSecondary'))
        }
        .type(ButtonType.Circle)
        .width($r('app.float.native_touch_target'))
        .height($r('app.float.native_touch_target'))
        .backgroundColor(Color.Transparent)
        .stateEffect(true)
        .accessibilityText('更多操作')
        .bindMenu(this.moreMenu)
        .onClick(() => {
          if (this.moreMenu.length === 0) {
            this.onMore();
          }
        })
      }
    }
    .width('100%')
    .height($r('app.float.native_header_height'))
    .padding({ left: this.showBack ? 4 : 8, right: 4 })
    .backgroundColor($r('app.color.pageBackground'))
  }
}
