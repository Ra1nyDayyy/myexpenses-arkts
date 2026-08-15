import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { PageHeader } from '../components/PageHeader';

/**
 * 设置主页面：对应 Android PreferenceActivity + preference_headers.xml
 * 系统性重构：完整对齐安卓端所有设置分类
 */
@Component
export struct SettingsMain {
  navStack: NavPathStack = new NavPathStack();
  private settings: SettingsService = SettingsService.getInstance();

  build() {
    Column() {
      PageHeader({
        title: '设置',
        showBack: true,
        onBack: () => {
          router.back();
        }
      })

      List() {
        // 数据
        ListItem() {
          Column() {
            this.buildSettingItem('数据', '账户、类别、货币等', () => {
              this.navStack.pushPathByName('SettingsData', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 界面
        ListItem() {
          Column() {
            this.buildSettingItem('界面', '主题、字体、语言等', () => {
              this.navStack.pushPathByName('SettingsUI', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 导入导出
        ListItem() {
          Column() {
            this.buildSettingItem('导入/导出', 'CSV、QIF格式导入导出', () => {
              this.navStack.pushPathByName('SettingsIO', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 备份恢复
        ListItem() {
          Column() {
            this.buildSettingItem('备份与恢复', '自动备份、云端备份', () => {
              this.navStack.pushPathByName('SettingsBackup', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 功能分组标题
        ListItem() {
          Text('功能')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, top: 16, bottom: 8 })
        }

        // OCR扫描
        ListItem() {
          Column() {
            this.buildSettingItem('扫描收据', 'OCR识别设置', () => {
              this.navStack.pushPathByName('SettingsOCR', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 同步
        ListItem() {
          Column() {
            this.buildSettingItem('同步', '云端同步设置', () => {
              this.navStack.pushPathByName('SettingsSync', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // Web UI
        ListItem() {
          Column() {
            this.buildSettingItem('Web界面', '浏览器访问设置', () => {
              this.navStack.pushPathByName('SettingsWebUI', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 附加图片
        ListItem() {
          Column() {
            this.buildSettingItem('附加图片', '交易附件设置', () => {
              this.navStack.pushPathByName('SettingsAttachPicture', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 打印
        ListItem() {
          Column() {
            this.buildSettingItem('打印', '打印设置', () => {
              this.navStack.pushPathByName('SettingsPrint', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 专业版
        ListItem() {
          Column() {
            this.buildSettingItem('专业版', '购买与许可证管理', () => {
              this.navStack.pushPathByName('SettingsContrib', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 安全
        ListItem() {
          Column() {
            this.buildSettingItem('安全', '密码、生物识别等', () => {
              this.navStack.pushPathByName('SettingsSecurity', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 帮助与反馈
        ListItem() {
          Column() {
            this.buildSettingItem('帮助与反馈', '使用帮助、问题报告', () => {
              this.navStack.pushPathByName('SettingsFeedback', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 高级
        ListItem() {
          Column() {
            this.buildSettingItem('高级', '高级设置选项', () => {
              this.navStack.pushPathByName('SettingsAdvanced', null);
            })
            Divider().strokeWidth(0.5).color($r('app.color.dividerColor'))
          }
        }

        // 更多信息
        ListItem() {
          this.buildSettingItem('更多信息', '关于应用', () => {
            this.showMoreInfo();
          })
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .width('100%')
    .height('100%')
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

  private showMoreInfo(): void {
    promptAction.showDialog({
      title: '关于 My Expenses',
      message: '版本: 1.0.0\n\n开源记账应用\n基于 HarmonyOS NEXT',
      buttons: [{ text: '确定', color: '#0A59F7' }]
    });
  }
}
