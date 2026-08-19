import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DbHelper } from '../database/DbHelper';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { DataManager } from '../database/DataManager';


const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {

    hilog.info(DOMAIN, 'MyExpenses', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'MyExpenses', '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, 'MyExpenses', '%{public}s', 'Ability onWindowStageCreate');

    // 初始化数据库与设置（全局单例）
    try {
      await DbHelper.getInstance().init(this.context);
      await SettingsService.getInstance().init(this.context);
      // 初始化数据管理器（导入导出/备份恢复依赖 context 打开文件选择器）
      DataManager.getInstance().setContext(this.context);
      AppStorage.setOrCreate('dbReady', true);
    } catch (err) {
      hilog.error(DOMAIN, 'MyExpenses', 'DB init failed: %{public}s', JSON.stringify(err));
      AppStorage.setOrCreate('dbReady', false);
    }

    // 应用用户选择的主题（0 跟随系统 1 浅色 2 深色），对齐安卓 AppCompatDelegate.setDefaultNightMode
    try {
      const theme = await SettingsService.getInstance().getNumber(PREF_KEY.THEME, 0);
      const colorMode: ConfigurationConstant.ColorMode = theme === 1
        ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : (theme === 2 ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      this.context.getApplicationContext().setColorMode(colorMode);
      // 同步到 AppStorage，供设置页 @StorageProp('appTheme') 显示
      AppStorage.setOrCreate('appTheme', theme);
    } catch (err) {
      hilog.error(DOMAIN, 'MyExpenses', 'Failed to apply theme. Cause: %{public}s', JSON.stringify(err));
    }

    // FIX-046：启动时读取界面设置并写入 AppStorage，供 Index.ets 等订阅组件响应
    try {
      const fontSize = await SettingsService.getInstance().getNumber(PREF_KEY.FONT_SIZE, 0);
      AppStorage.setOrCreate('appFontScale', fontSize);
      const language = await SettingsService.getInstance().getString(PREF_KEY.LANGUAGE, 'default');
      AppStorage.setOrCreate('appLanguage', language);
      const startScreen = await SettingsService.getInstance().getString(PREF_KEY.START_SCREEN, 'LastVisited');
      AppStorage.setOrCreate('startScreen', startScreen);
      const defaultAction = await SettingsService.getInstance().getString(PREF_KEY.DEFAULT_ACTION, 'LastVisited');
      AppStorage.setOrCreate('defaultAction', defaultAction);
    } catch (err) {
      hilog.error(DOMAIN, 'MyExpenses', 'Failed to load UI settings. Cause: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'MyExpenses', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'MyExpenses', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'MyExpenses', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'MyExpenses', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'MyExpenses', '%{public}s', 'Ability onBackground');
  }
}
