import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { OptionSelectDialog } from '../components/OptionSelectDialog';

/**
 * 界面设置页面：对应 Android preferences_ui.xml
 * 包含：主题、字体、语言、启动屏幕、自动填充、交易列表显示等
 *
 * FIX-046：主题/字体/语言/启动屏幕/默认操作修改后调用 SettingsService.apply* 实时生效
 *         （setColorMode + AppStorage 通知），不再提示"重启应用生效"。
 * FIX-052：主题/字体大小/语言/启动屏幕/默认操作 5 项改为内联 Row 渲染（不调 buildSettingItem），
 *         因 @Builder 参数 summary: string 不响应 @State 变化（ArkTS @Builder 参数按值传递限制）。
 *         静态项（菜单/显示配置/周起始日/月起始日）继续用 buildSettingItem。
 */
@Component
export struct SettingsUI {
  private pathStack: NavPathStack = new NavPathStack();
  private settings: SettingsService = SettingsService.getInstance();
  private optionDialog: CustomDialogController | null = null;
  @State theme: number = 0; // 0=跟随系统 1=浅色 2=深色
  @State fontSize: number = 0; // 字体大小调整
  @State language: string = 'default';
  @State startScreen: string = 'LastVisited';
  @State defaultAction: string = 'LastVisited';
  @State showSumDetails: boolean = true;
  @State autoFillEnabled: boolean = false;
  @State autoFillAmount: boolean = true;
  @State autoFillCategory: boolean = true;
  @State categoryIcons: boolean = true;

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    this.theme = await this.settings.getNumber(PREF_KEY.THEME, 0);
    this.fontSize = await this.settings.getNumber(PREF_KEY.FONT_SIZE, 0);
    this.language = await this.settings.getString(PREF_KEY.LANGUAGE, 'default');
    this.startScreen = await this.settings.getString(PREF_KEY.START_SCREEN, 'LastVisited');
    this.defaultAction = await this.settings.getString(PREF_KEY.DEFAULT_ACTION, 'LastVisited');
    this.showSumDetails = await this.settings.getBoolean(PREF_KEY.SHOW_SUM_DETAILS, true);
    this.autoFillEnabled = await this.settings.getBoolean(PREF_KEY.AUTO_FILL, false);
    this.autoFillAmount = await this.settings.getBoolean(PREF_KEY.AUTO_FILL_AMOUNT, true);
    this.autoFillCategory = await this.settings.getBoolean(PREF_KEY.AUTO_FILL_CATEGORY, true);
    this.categoryIcons = await this.settings.getBoolean(PREF_KEY.CATEGORY_ICONS, true);
  }

  /**
   * FIX-046：获取 UIAbilityContext，供 SettingsService.apply* 调用 context.getApplicationContext().setColorMode 等。
   */
  private ctx(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // 主题（FIX-052：内联渲染以响应 @State theme 变化，@Builder 参数不响应 @State）
          Row() {
            Column({ space: 4 }) {
              Text('主题')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              Text(this.getThemeName())
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.iconSecondary'))
          }
          .width('100%')
          .height(68)
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius($r('app.float.native_card_radius'))
          .backgroundColor($r('app.color.surfacePrimary'))
          .onClick(() => {
            this.showThemeDialog();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 字体大小（FIX-052：内联渲染以响应 @State fontSize 变化）
          Row() {
            Column({ space: 4 }) {
              Text('字体大小')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              Text(this.getFontSizeName())
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.iconSecondary'))
          }
          .width('100%')
          .height(68)
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius($r('app.float.native_card_radius'))
          .backgroundColor($r('app.color.surfacePrimary'))
          .onClick(() => {
            this.showFontSizeDialog();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 语言（FIX-052：内联渲染以响应 @State language 变化）
          Row() {
            Column({ space: 4 }) {
              Text('语言')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              Text(this.getLanguageName())
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.iconSecondary'))
          }
          .width('100%')
          .height(68)
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius($r('app.float.native_card_radius'))
          .backgroundColor($r('app.color.surfacePrimary'))
          .onClick(() => {
            this.showLanguageDialog();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 自定义菜单
          this.buildSettingItem('菜单', '自定义', () => {
            promptAction.showToast({ message: '菜单自定义功能开发中' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 启动屏幕（FIX-052：内联渲染以响应 @State startScreen 变化）
          Row() {
            Column({ space: 4 }) {
              Text('启动屏幕')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              Text(this.getStartScreenName())
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.iconSecondary'))
          }
          .width('100%')
          .height(68)
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius($r('app.float.native_card_radius'))
          .backgroundColor($r('app.color.surfacePrimary'))
          .onClick(() => {
            this.showStartScreenDialog();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 默认操作（FIX-052：内联渲染以响应 @State defaultAction 变化）
          Row() {
            Column({ space: 4 }) {
              Text('默认操作')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              Text(this.getDefaultActionName())
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.iconSecondary'))
          }
          .width('100%')
          .height(68)
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, top: 4, bottom: 4 })
          .borderRadius($r('app.float.native_card_radius'))
          .backgroundColor($r('app.color.surfacePrimary'))
          .onClick(() => {
            this.showDefaultActionDialog();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 账户列表显示配置
          Text('账户列表')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          this.buildSettingItem('显示配置', '自定义账户列表显示内容', () => {
            promptAction.showToast({ message: '账户列表配置' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 自动填充
          Text('自动填充')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          this.buildSwitchItem(
            '启用自动填充',
            '根据交易对手自动填充字段',
            this.autoFillEnabled,
            async (value: boolean) => {
              this.autoFillEnabled = value;
              await this.settings.setBoolean(PREF_KEY.AUTO_FILL, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          if (this.autoFillEnabled) {
            this.buildSwitchItem(
              '金额',
              '',
              this.autoFillAmount,
              async (value: boolean) => {
                this.autoFillAmount = value;
                await this.settings.setBoolean(PREF_KEY.AUTO_FILL_AMOUNT, value);
              }
            )
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

            this.buildSwitchItem(
              '类别',
              '',
              this.autoFillCategory,
              async (value: boolean) => {
                this.autoFillCategory = value;
                await this.settings.setBoolean(PREF_KEY.AUTO_FILL_CATEGORY, value);
              }
            )
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }

          // 交易列表
          Text('交易列表')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          this.buildSwitchItem(
            '类别图标',
            '',
            this.categoryIcons,
            async (value: boolean) => {
              this.categoryIcons = value;
              await this.settings.setBoolean(PREF_KEY.CATEGORY_ICONS, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          this.buildSwitchItem(
            '显示汇总详情',
            '在分组标题显示收入、支出明细',
            this.showSumDetails,
            async (value: boolean) => {
              this.showSumDetails = value;
              await this.settings.setBoolean(PREF_KEY.SHOW_SUM_DETAILS, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 分组周期
          Text('分组周期')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          this.buildSettingItem('周起始日', '周一', () => {
            promptAction.showToast({ message: '选择周起始日' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          this.buildSettingItem('月起始日', '1日', () => {
            promptAction.showToast({ message: '选择月起始日' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 日期
          Text('日期')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          this.buildSwitchItem(
            '记录交易时间',
            '精确到时分秒',
            true,
            async (value: boolean) => {
              await this.settings.setBoolean(PREF_KEY.TRANSACTION_TIME, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          this.buildSwitchItem(
            '克隆时使用当前日期',
            '',
            true,
            async (value: boolean) => {
              await this.settings.setBoolean(PREF_KEY.CLONE_CURRENT_DATE, value);
            }
          )
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .title('界面')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  buildSettingItem(title: string, summary: string, onClick: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textPrimary'))
        if (summary) {
          Text(summary)
            .fontSize(13)
            .fontColor($r('app.color.textSecondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(20)
        .height(20)
        .fillColor($r('app.color.iconSecondary'))
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ left: 12, right: 12, top: 4, bottom: 4 })
    .borderRadius($r('app.float.native_card_radius'))
    .backgroundColor($r('app.color.surfacePrimary'))
    .onClick(onClick)
  }

  @Builder
  buildSwitchItem(title: string, summary: string, checked: boolean, onChange: (value: boolean) => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textPrimary'))
        if (summary) {
          Text(summary)
            .fontSize(13)
            .fontColor($r('app.color.textSecondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: checked })
        .onChange(onChange)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .margin({ left: 12, right: 12, top: 4, bottom: 4 })
    .borderRadius($r('app.float.native_card_radius'))
    .backgroundColor($r('app.color.surfacePrimary'))
  }

  private getThemeName(): string {
    return ['跟随系统', '浅色', '深色'][this.theme] || '跟随系统';
  }

  private getFontSizeName(): string {
    if (this.fontSize === 0) return '默认';
    return this.fontSize > 0 ? `+${this.fontSize}` : `${this.fontSize}`;
  }

  private getLanguageName(): string {
    const languages: Record<string, string> = {
      'default': '跟随系统',
      'zh_CN': '简体中文',
      'en': 'English'
    };
    return languages[this.language] || '跟随系统';
  }

  /**
   * FIX-046：启动屏幕/默认操作显示名（对齐 Android arrays.xml pref_start_screen_entries / pref_default_action_entries）
   */
  private getStartScreenName(): string {
    const map: Record<string, string> = {
      'LastVisited': '上次访问',
      'Accounts': '账户',
      'Transactions': '交易',
      'BalanceSheet': '资产负债表'
    };
    return map[this.startScreen] || '上次访问';
  }

  private getDefaultActionName(): string {
    const map: Record<string, string> = {
      'LastVisited': '上次使用',
      'Expense': '支出',
      'Income': '收入',
      'Transfer': '转账',
      'Split': '拆分',
      'Scan': '扫描'
    };
    return map[this.defaultAction] || '上次使用';
  }

  private showThemeDialog(): void {
    this.openOptionDialog('主题', ['0', '1', '2'], ['跟随系统', '浅色', '深色'], String(this.theme), (key: string) => {
      const val = Number(key);
      if (val >= 0 && val <= 2) {
        this.theme = val;
        // FIX-046：实时切换主题（setColorMode + AppStorage），不再提示"重启应用生效"
        this.settings.applyTheme(this.ctx(), val);
        promptAction.showToast({ message: '主题已切换' });
      }
    });
  }

  private showFontSizeDialog(): void {
    this.openOptionDialog('字体大小', ['-1', '0', '1'], ['缩小', '默认', '放大'], String(this.fontSize), (key: string) => {
      const val = Number(key);
      this.fontSize = val;
      // FIX-046：写入 AppStorage['appFontScale']，订阅组件（@StorageProp）实时响应
      this.settings.applyFontSize(this.ctx(), val);
      promptAction.showToast({ message: '字体大小已应用' });
    });
  }

  private showLanguageDialog(): void {
    this.openOptionDialog('语言', ['default', 'zh_CN', 'en'], ['跟随系统', '简体中文', 'English'], this.language, (key: string) => {
      this.language = key;
      // FIX-046：写入 AppStorage['appLanguage']，订阅组件实时响应；不再提示"重启生效"
      this.settings.applyLanguage(this.ctx(), key);
      promptAction.showToast({ message: '语言已切换' });
    });
  }

  private showStartScreenDialog(): void {
    this.openOptionDialog('启动屏幕',
      ['LastVisited', 'Accounts', 'Transactions', 'BalanceSheet'],
      ['上次访问', '账户', '交易', '资产负债表'],
      this.startScreen, (key: string) => {
        this.startScreen = key;
        // FIX-046：写入 AppStorage['startScreen']，EntryAbility 启动时读取，Index.ets 据此切初始 Tab
        this.settings.applyStartScreen(this.ctx(), key);
        promptAction.showToast({ message: '启动屏幕已设置' });
      });
  }

  /**
   * FIX-046：默认操作选择对话框（对齐 Android preferences_ui.xml ListPreference pref_default_action_key）。
   * 选项：上次使用/支出/收入/转账/拆分/扫描；写入 AppStorage['defaultAction']，Index.ets FAB 点击时读取。
   */
  private showDefaultActionDialog(): void {
    this.openOptionDialog('默认操作',
      ['LastVisited', 'Expense', 'Income', 'Transfer', 'Split', 'Scan'],
      ['上次使用', '支出', '收入', '转账', '拆分', '扫描'],
      this.defaultAction, (key: string) => {
        this.defaultAction = key;
        this.settings.applyDefaultAction(this.ctx(), key);
        promptAction.showToast({ message: '默认操作已设置' });
      });
  }


  /** 通用选项对话框（CustomDialog 模式，避免 promptAction 多按钮 index 失效） */
  private openOptionDialog(title: string, optionKeys: string[], optionLabels: string[], selected: string,
    onSelect: (key: string) => void): void {
    this.optionDialog = new CustomDialogController({
      builder: OptionSelectDialog({
        title: title,
        optionKeys: optionKeys,
        optionLabels: optionLabels,
        selectedKey: selected,
        onResult: (key: string) => {
          onSelect(key);
        },
        onClose: () => {
          this.optionDialog?.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
    this.optionDialog.open();
  }
}
