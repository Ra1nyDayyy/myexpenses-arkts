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
  /** 帮助按钮（对齐安卓 Toolbar 帮助图标） */
  @Prop showHelp: boolean = false;
  /** 图表按钮（资产负债表右上角，对齐安卓 TooltipIconButton 图表开关） */
  @Prop showChart: boolean = false;
  /** 更多按钮下拉菜单（对齐安卓 TooltipIconMenu：在按钮附近展开，非弹窗） */
  @Prop moreMenu: Array<MenuElement> = [];
  /** 语音输入按钮（AI 助手等） */
  @Prop showSpeech: boolean = false;
  /** 标题下拉菜单（对齐安卓标题下拉切换类型，就近展开非弹窗） */
  @Prop titleMenu: Array<MenuElement> = [];
  /** 筛选按钮（对齐安卓 ic_filter，TYPE_FILTER_COMMAND；filterActive 时高亮） */
  @Prop showFilter: boolean = false;
  @Prop filterActive: boolean = false;
  /** 搜索按钮（对齐安卓 ic_menu_search，SEARCH_COMMAND；searchActive 时高亮） */
  @Prop showSearch: boolean = false;
  @Prop searchActive: boolean = false;
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

      if (this.titleMenu.length > 0) {
        Row() {
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.textPrimary'))
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(14)
            .height(14)
            .margin({ left: 4 })
        }
        .margin({ left: 12 })
        .bindMenu(this.titleMenu)
      } else {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textPrimary'))
          .margin({ left: 12 })
      }
      Blank()


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

      // 语音输入按钮（对齐 AI 助手语音）
      if (this.showSpeech) {
        Image($r('app.media.ic_mic'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .fillColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.onSpeech();
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

      // 帮助图标（对齐安卓 Toolbar 帮助按钮）
      if (this.showHelp) {
        Image($r('app.media.ic_help'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .fillColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.onHelp();
          })
      }

      // 筛选按钮（对齐安卓 ic_filter / TYPE_FILTER_COMMAND）
      if (this.showFilter) {
        Image($r('app.media.ic_filter'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .fillColor(this.filterActive ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
          .onClick(() => {
            this.onFilter();
          })
      }

      // 搜索按钮（对齐安卓 ic_menu_search / SEARCH_COMMAND）
      if (this.showSearch) {
        Image($r('sys.media.ohos_ic_public_search_filled'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .fillColor(this.searchActive ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
          .onClick(() => {
            this.onSearch();
          })
      }

      // 更多选项图标（对齐安卓：有菜单时在按钮附近下拉展开，否则触发回调）
      if (this.showMore) {
        Image($r('sys.media.ohos_ic_public_more'))
          .width(22)
          .height(22)
          .margin({ left: 16 })
          .bindMenu(this.moreMenu)
          .onClick(() => {
            if (this.moreMenu.length === 0) {
              this.onMore();
            }
          })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }
}
