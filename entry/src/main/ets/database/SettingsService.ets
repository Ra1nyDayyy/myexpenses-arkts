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
  static readonly SHOW_EQUIVALENT: string = 'show_equivalent_value';
  static readonly SHOW_STATUS: string = 'show_status_handle';
  static readonly WEEK_START: string = 'week_start';
  static readonly MONTH_START: string = 'month_start';
  static readonly DEFAULT_ACCOUNT: string = 'default_account';
  static readonly SHOW_SUM_DETAILS: string = 'group_header_show_details';
  static readonly USE_CUSTOM_CATEGORY_COLORS: string = 'use_custom_category_colors';
  static readonly AI_ANALYSIS_RESULT: string = 'ai_analysis_result';
  static readonly AI_ANALYSIS_TIME: string = 'ai_analysis_time';
}