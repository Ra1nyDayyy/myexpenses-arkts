import { promptAction } from '@kit.ArkUI';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { DataManager } from '../database/DataManager';
import { CategorySeparatorDialog } from '../components/CategorySeparatorDialog';

/**
 * 导入/导出设置页面：对应 Android preferences_io.xml
 * 包含：CSV导入导出、QIF导入、Grisbi导入等
 */
@Component
export struct SettingsIO {
  private pathStack: NavPathStack = new NavPathStack();
  private settings: SettingsService = SettingsService.getInstance();
  private dataManager: DataManager = DataManager.getInstance();
  private separatorDialog: CustomDialogController | null = null;
  
  @State csvSplitCategories: boolean = false;
  @State csvCategorySeparator: string = ' > ';
  @State csvSplitAmount: boolean = true;
  @State csvSplitDateTime: boolean = false;
  @State csvOriginalEquivalent: boolean = false;

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    this.csvSplitCategories = await this.settings.getBoolean(PREF_KEY.CSV_SPLIT_CATEGORIES, false);
    this.csvCategorySeparator = await this.settings.getString(PREF_KEY.CSV_CATEGORY_SEPARATOR, ' > ');
    this.csvSplitAmount = await this.settings.getBoolean(PREF_KEY.CSV_SPLIT_AMOUNT, true);
    this.csvSplitDateTime = await this.settings.getBoolean(PREF_KEY.CSV_SPLIT_DATETIME, false);
    this.csvOriginalEquivalent = await this.settings.getBoolean(PREF_KEY.CSV_ORIGINAL_EQUIVALENT, false);
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // 导入CSV
          this.buildSettingItem('导入CSV', '从CSV文件导入交易', () => {
            this.importCsv();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 导入QIF
          this.buildSettingItem('导入QIF', '从Quicken格式文件导入', () => {
            this.importQif();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 从Grisbi导入
          this.buildSettingItem('从Grisbi导入', '导入Grisbi个人财务管理软件的数据', () => {
            this.importGrisbi();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // CSV导出设置分组
          Text('CSV导出')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          // 拆分类别
          this.buildSwitchItem(
            '拆分类别',
            '主类别和子类别拆分为两列',
            this.csvSplitCategories,
            async (value: boolean) => {
              this.csvSplitCategories = value;
              await this.settings.setBoolean(PREF_KEY.CSV_SPLIT_CATEGORIES, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 类别分隔符（仅在不拆分时显示）
          if (!this.csvSplitCategories) {
            this.buildSettingItem('类别分隔符', this.csvCategorySeparator, () => {
              this.showCategorySeparatorDialog();
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }

          // 拆分金额
          this.buildSwitchItem(
            '拆分金额',
            '收入和支出拆分为两列',
            this.csvSplitAmount,
            async (value: boolean) => {
              this.csvSplitAmount = value;
              await this.settings.setBoolean(PREF_KEY.CSV_SPLIT_AMOUNT, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 拆分日期时间
          this.buildSwitchItem(
            '拆分日期时间',
            '日期和时间拆分为两列',
            this.csvSplitDateTime,
            async (value: boolean) => {
              this.csvSplitDateTime = value;
              await this.settings.setBoolean(PREF_KEY.CSV_SPLIT_DATETIME, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 导出原始和等值金额
          this.buildSwitchItem(
            '导出原始和等值金额',
            '同时导出交易的原始币种和等值金额',
            this.csvOriginalEquivalent,
            async (value: boolean) => {
              this.csvOriginalEquivalent = value;
              await this.settings.setBoolean(PREF_KEY.CSV_ORIGINAL_EQUIVALENT, value);
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
    .title('导入/导出')
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

  private async importCsv(): Promise<void> {
    promptAction.showToast({ message: '正在导入CSV...' });
    const count = await this.dataManager.importCsv();
    if (count >= 0) {
      promptAction.showToast({ message: `成功导入 ${count} 条交易` });
    } else {
      promptAction.showToast({ message: '导入失败或已取消' });
    }
  }

  private importQif(): void {
    promptAction.showToast({ message: 'QIF导入功能开发中' });
  }

  private importGrisbi(): void {
    promptAction.showToast({ message: 'Grisbi导入功能开发中' });
  }

  private showCategorySeparatorDialog(): void {
    this.separatorDialog = new CustomDialogController({
      builder: CategorySeparatorDialog({
        currentValue: this.csvCategorySeparator,
        onResult: (value: string) => {
          this.csvCategorySeparator = value;
          this.settings.setString(PREF_KEY.CSV_CATEGORY_SEPARATOR, value);
        },
        onClose: () => {
          this.separatorDialog?.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
    this.separatorDialog.open();
  }
}
