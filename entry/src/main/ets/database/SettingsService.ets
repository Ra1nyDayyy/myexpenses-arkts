import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';

/**
 * 应用设置：对应 Android SharedPreferences/PreferenceActivity
 *
 * FIX-046：新增 apply* 系列方法，设置变更后实时应用到界面（setColorMode / AppStorage 通知订阅组件重渲染），
 *         对齐 Android PreferenceFragment 写入后立即生效的行为，避免"重启才生效"。
 */
export class SettingsService {
  private static instance: SettingsService | null = null;
  private pref: preferences.Preferences | null = null;

  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.pref) {
      return;
    }
    this.pref = await preferences.getPreferences(context, 'myexpenses_settings');
  }

  private ensure(): preferences.Preferences {
    if (!this.pref) {
      throw new Error('设置未初始化');
    }
    return this.pref;
  }

  async getString(key: string, def: string): Promise<string> {
    const val = await this.ensure().get(key, def);
    return val as string;
  }

  async setString(key: string, value: string): Promise<void> {
    await this.ensure().put(key, value);
    await this.ensure().flush();
  }

  async getNumber(key: string, def: number): Promise<number> {
    const val = await this.ensure().get(key, def);
    return val as number;
  }

  async setNumber(key: string, value: number): Promise<void> {
    await this.ensure().put(key, value);
    await this.ensure().flush();
  }

  async getBoolean(key: string, def: boolean): Promise<boolean> {
    const val = await this.ensure().get(key, def);
    return val as boolean;
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    await this.ensure().put(key, value);
    await this.ensure().flush();
  }

  /**
   * FIX-046：应用主题（0 跟随系统 1 浅色 2 深色）。
   * 持久化 + 调用 setColorMode 实时切换 + 同步 AppStorage 供设置页 @StorageProp 显示。
   * 对齐 Android AppCompatDelegate.setDefaultNightMode（立即生效，无需重启）。
   */
  async applyTheme(context: common.Context, theme: number): Promise<void> {
    await this.setNumber(PREF_KEY.THEME, theme);
    const colorMode: ConfigurationConstant.ColorMode = theme === 1
      ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      : (theme === 2 ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    context.getApplicationContext().setColorMode(colorMode);
    AppStorage.setOrCreate('appTheme', theme);
  }

  /**
   * FIX-046：应用字体大小（-1 缩小 0 默认 1 放大）。
   * HarmonyOS Stage 模型无应用级 setFontSize API（setSystemFontSize 会改系统字体，不适用），
   * 故通过 AppStorage['appFontScale'] 通知订阅组件（@StorageProp）按比例缩放 fontSize。
   * 需各页面 Text 通过 @StorageProp('appFontScale') 响应（见 fix-log FIX-046 协调者事项）。
   */
  async applyFontSize(context: common.Context, scale: number): Promise<void> {
    await this.setNumber(PREF_KEY.FONT_SIZE, scale);
    AppStorage.setOrCreate('appFontScale', scale);
  }

  /**
   * FIX-046：应用语言（default/zh_CN/en）。
   * Stage 模型 ApplicationContext 未暴露 setLocale，且当前工程未引入 i18n 框架，
   * 故通过 AppStorage['appLanguage'] 通知订阅组件；后续 i18n 改造后可在此接入 ResourceManager 切换。
   */
  async applyLanguage(context: common.Context, locale: string): Promise<void> {
    await this.setString(PREF_KEY.LANGUAGE, locale);
    AppStorage.setOrCreate('appLanguage', locale);
  }

  /**
   * FIX-046：应用启动屏幕（LastVisited/Accounts/Transactions/BalanceSheet）。
   * 持久化 + AppStorage 通知；EntryAbility 启动时读取并写入 AppStorage['startScreen']，
   * Index.ets aboutToAppear 据此切换初始 Tab（见 fix-log FIX-046 协调者事项）。
   */
  async applyStartScreen(context: common.Context, value: string): Promise<void> {
    await this.setString(PREF_KEY.START_SCREEN, value);
    AppStorage.setOrCreate('startScreen', value);
  }

  /**
   * FIX-046：应用默认操作（LastVisited/Expense/Income/Transfer/Split/Scan）。
   * 持久化 + AppStorage 通知；Index.ets FAB 点击时读取 AppStorage['defaultAction'] 决定默认操作
   *（见 fix-log FIX-046 协调者事项）。
   */
  async applyDefaultAction(context: common.Context, value: string): Promise<void> {
    await this.setString(PREF_KEY.DEFAULT_ACTION, value);
    AppStorage.setOrCreate('defaultAction', value);
  }

}

// 设置 key 常量
export class PREF_KEY {
  static readonly GROUPING: string = 'grouping';
  static readonly SORT_BY: string = 'sort_by';
  static readonly SORT_DIRECTION: string = 'sort_direction';
  static readonly SORT_ACCOUNT_LIST_BY_FLAG_FIRST: string = 'sort_account_list_by_flag_first';
  static readonly SHOW_EQUIVALENT: string = 'show_equivalent_value';
  static readonly SHOW_STATUS: string = 'show_status_handle';
  static readonly WEEK_START: string = 'week_start';
  static readonly MONTH_START: string = 'month_start';
  static readonly DEFAULT_ACCOUNT: string = 'default_account';
  static readonly SHOW_SUM_DETAILS: string = 'group_header_show_details';
  static readonly USE_CUSTOM_CATEGORY_COLORS: string = 'use_custom_category_colors';
  static readonly AI_ANALYSIS_RESULT: string = 'ai_analysis_result';
  static readonly AI_ANALYSIS_TIME: string = 'ai_analysis_time';
  static readonly THEME: string = 'theme'; // 0 跟随系统 1 浅色 2 深色
  static readonly LANGUAGE: string = 'language';
  static readonly LAST_ACTION: string = 'last_action'; // 交易页 FAB 记住的上次操作：-1 支出 / 1 收入 / 2 转账
  // FIX-046：界面设置新增 key（对齐 Android preferences_ui.xml pref_ui_start_screen_key / pref_default_action_key）
  static readonly START_SCREEN: string = 'start_screen'; // LastVisited/Accounts/Transactions/BalanceSheet
  static readonly DEFAULT_ACTION: string = 'default_action'; // LastVisited/Expense/Income/Transfer/Split/Scan
  
  // 数据设置相关
  static readonly UNMAPPED_AS_TRANSFER: string = 'unmapped_transaction_as_transfer';
  static readonly AUTO_EXCHANGE_RATE: string = 'automatic_exchange_rate_download';
  static readonly AUTO_UPDATE_EQUIVALENT: string = 'equivalent_amounts_automatic_update';
  
  // 界面设置相关
  static readonly FONT_SIZE: string = 'font_size';
  static readonly AUTO_FILL: string = 'auto_fill_enabled';
  static readonly AUTO_FILL_AMOUNT: string = 'auto_fill_amount';
  static readonly AUTO_FILL_CATEGORY: string = 'auto_fill_category';
  static readonly CATEGORY_ICONS: string = 'category_icons';
  static readonly TRANSACTION_TIME: string = 'transaction_time';
  static readonly CLONE_CURRENT_DATE: string = 'clone_with_current_date';
  
  // 导入导出设置相关
  static readonly CSV_SPLIT_CATEGORIES: string = 'csv_export_split_categories';
  static readonly CSV_CATEGORY_SEPARATOR: string = 'csv_export_category_separator';
  static readonly CSV_SPLIT_AMOUNT: string = 'csv_export_split_amount';
  static readonly CSV_SPLIT_DATETIME: string = 'csv_export_split_date_time';
  static readonly CSV_ORIGINAL_EQUIVALENT: string = 'csv_export_original_equivalent_amounts';
}