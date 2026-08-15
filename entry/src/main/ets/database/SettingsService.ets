import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 应用设置：对应 Android SharedPreferences/PreferenceActivity
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