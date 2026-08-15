import { promptAction } from '@kit.ArkUI';
import { SettingsService, PREF_KEY } from '../database/SettingsService';

/**
 * 数据设置页面：对应 Android preferences_data.xml
 * 包含：类别、付款方式、标签、货币、汇率等管理
 */
@Component
export struct SettingsData {
  private pathStack: NavPathStack = new NavPathStack();
  private settings: SettingsService = SettingsService.getInstance();
  @State unmappedAsTransfer: boolean = false;
  @State autoExchangeRate: boolean = false;
  @State autoUpdateEquivalent: boolean = true;

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    this.unmappedAsTransfer = await this.settings.getBoolean(PREF_KEY.UNMAPPED_AS_TRANSFER, false);
    this.autoExchangeRate = await this.settings.getBoolean(PREF_KEY.AUTO_EXCHANGE_RATE, false);
    this.autoUpdateEquivalent = await this.settings.getBoolean(PREF_KEY.AUTO_UPDATE_EQUIVALENT, true);
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // 管理类别
          this.buildSettingItem('管理类别', '添加、编辑、删除类别', () => {
            promptAction.showToast({ message: '跳转到类别管理' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 管理付款方式
          this.buildSettingItem('管理付款方式', '现金、信用卡、支付宝等', () => {
            promptAction.showToast({ message: '跳转到付款方式管理' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 管理标签
          this.buildSettingItem('标签', '为交易添加标签', () => {
            promptAction.showToast({ message: '跳转到标签管理' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 未映射交易作为转账
          this.buildSwitchItem(
            '未映射交易作为转账',
            this.unmappedAsTransfer ? '开启' : '关闭',
            this.unmappedAsTransfer,
            async (value: boolean) => {
              this.unmappedAsTransfer = value;
              await this.settings.setBoolean(PREF_KEY.UNMAPPED_AS_TRANSFER, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 货币与汇率分组
          Text('货币与汇率')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          // 管理货币
          this.buildSettingItem('管理货币', '添加、删除货币', () => {
            this.showCurrencyInfo();
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 本位币
          this.buildSettingItem('本位币', 'CNY - 人民币', () => {
            promptAction.showToast({ message: '选择本位币' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 汇率提供商
          this.buildSettingItem('汇率提供商', '选择汇率数据来源', () => {
            promptAction.showToast({ message: '选择汇率提供商' });
          })
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 自动下载每日汇率
          this.buildSwitchItem(
            '自动下载每日汇率',
            this.autoExchangeRate ? '已启用' : '已禁用',
            this.autoExchangeRate,
            async (value: boolean) => {
              this.autoExchangeRate = value;
              await this.settings.setBoolean(PREF_KEY.AUTO_EXCHANGE_RATE, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 价格历史分组
          Text('价格历史')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })

          // 自动更新等值金额
          this.buildSwitchItem(
            '自动更新等值金额',
            this.autoUpdateEquivalent ? '已启用' : '已禁用',
            this.autoUpdateEquivalent,
            async (value: boolean) => {
              this.autoUpdateEquivalent = value;
              await this.settings.setBoolean(PREF_KEY.AUTO_UPDATE_EQUIVALENT, value);
            }
          )
          Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))

          // 动态汇率
          this.buildSettingItem('动态汇率', '按账户', () => {
            promptAction.showToast({ message: '选择动态汇率模式' });
          })
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .title('数据')
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
        Text(summary)
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
        Text(summary)
          .fontSize(13)
          .fontColor($r('app.color.textSecondary'))
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

  private showCurrencyInfo(): void {
    promptAction.showDialog({
      title: '货币',
      message: '应用支持多种货币记账：\n\n' +
        '· 人民币 (CNY) ¥\n' +
        '· 美元 (USD) $\n' +
        '· 欧元 (EUR) €\n' +
        '· 日元 (JPY) ¥\n' +
        '· 英镑 (GBP) £\n\n' +
        '在编辑账户时选择账户币种即可使用。',
      buttons: [{ text: '确定', color: '#0A59F7' }]
    });
  }
}
