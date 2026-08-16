import { SettingsMain } from './SettingsMain';
import { SettingsData } from './SettingsData';

import { SettingsUI } from './SettingsUI';
import { SettingsIO } from './SettingsIO';
import { Repository } from '../database/Repository';
import { DataManager } from '../database/DataManager';
import { promptAction } from '@kit.ArkUI';

/**
 * 设置入口页面：包含Navigation导航栈
 * 对应 Android PreferenceActivity
 */
@Entry
@Component
struct Settings {
  private navStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.navStack) {
      SettingsMain({ navStack: this.navStack })
    }
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .navDestination(this.settingsPageMap)
  }

  @Builder
  settingsPageMap(name: string) {
    if (name === 'SettingsData') {
      SettingsData()
    } else if (name === 'SettingsUI') {
      SettingsUI()
    } else if (name === 'SettingsIO') {
      SettingsIO()
    } else if (name === 'SettingsBackup') {
      SettingsBackup()
    } else if (name === 'SettingsOCR') {
      SettingsOCR()
    } else if (name === 'SettingsSync') {
      SettingsSync()
    } else if (name === 'SettingsWebUI') {
      SettingsWebUI()
    } else if (name === 'SettingsAttachPicture') {
      SettingsAttachPicture()
    } else if (name === 'SettingsPrint') {
      SettingsPrint()
    } else if (name === 'SettingsContrib') {
      SettingsContrib()
    } else if (name === 'SettingsSecurity') {
      SettingsSecurity()
    } else if (name === 'SettingsFeedback') {
      SettingsFeedback()
    } else if (name === 'SettingsAdvanced') {
      SettingsAdvanced()

    }
  }
}

// 临时占位组件，后续逐个实现
@Component

struct SettingsBackup {
  private pathStack: NavPathStack = new NavPathStack();
  private dataManager: DataManager = DataManager.getInstance();

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text('备份当前数据库到文件，或从备份文件恢复。')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, right: 16, top: 8 })

          Button('备份数据库')
            .width('100%')
            .height(48)
            .fontSize(16)
            .backgroundColor($r('app.color.primaryColor'))
            .fontColor(Color.White)
            .margin({ left: 16, right: 16, top: 8 })
            .onClick(async () => {
              promptAction.showToast({ message: '正在备份...' });
              const ok = await this.dataManager.backupDatabase();
              promptAction.showToast({ message: ok ? '备份成功' : '备份失败或已取消' });
            })

          Button('恢复数据库')
            .width('100%')
            .height(48)
            .fontSize(16)
            .backgroundColor($r('app.color.cardBackgroundColor'))
            .fontColor($r('app.color.primaryColor'))
            .margin({ left: 16, right: 16 })
            .onClick(() => {
              promptAction.showDialog({
                title: '恢复数据库',
                message: '恢复将覆盖当前数据，恢复后需要重启应用生效。确定继续？',
                buttons: [
                  { text: '取消', color: '#666666' },
                  { text: '恢复', color: '#E53935' }
                ]
              }).then(async (result) => {
                if (result.index === 1) {
                  const ok = await this.dataManager.restoreDatabase();
                  promptAction.showToast({ message: ok ? '恢复成功，请重启应用' : '恢复失败或已取消' });
                }
              }).catch(() => {
              });
            })

          Text('提示：备份文件为数据库文件（.db），请妥善保存。')
            .fontSize(12)
            .fontColor($r('app.color.textSecondary'))
            .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .title('备份与恢复')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsOCR {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('OCR设置 - 开发中')
        .fontSize(16)
    }
    .title('扫描收据')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsSync {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('同步设置 - 开发中')
        .fontSize(16)
    }
    .title('同步')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsWebUI {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('Web界面设置 - 开发中')
        .fontSize(16)
    }
    .title('Web界面')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsAttachPicture {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('附加图片设置 - 开发中')
        .fontSize(16)
    }
    .title('附加图片')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsPrint {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('打印设置 - 开发中')
        .fontSize(16)
    }
    .title('打印')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsContrib {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('专业版设置 - 开发中')
        .fontSize(16)
    }
    .title('专业版')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsSecurity {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Text('安全设置 - 开发中')
        .fontSize(16)
    }
    .title('安全')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsFeedback {
  private pathStack: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text('使用帮助')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, top: 16 })

          Text('· 记账：底部"交易"页点击 + 新建交易，或使用 AI 对话直接说"午饭35元"')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })
          Text('· 分类：设置 → 数据 → 管理类别')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })
          Text('· 洞察：AI 页问"这个月花了多少"')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })
          Text('· 数据安全：设置 → 备份与恢复 可备份数据库')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })

          Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

          Text('关于')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16 })
          Text('MyExpenses（鸿蒙版）\n版本: 1.0.0\n开源记账应用，基于 HarmonyOS ArkTS 迁移自 Android 版。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textSecondary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .title('帮助与反馈')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Component
struct SettingsAdvanced {
  private pathStack: NavPathStack = new NavPathStack();
  @State dbInfo: string = '';

  aboutToAppear(): void {
    this.loadDbInfo();
  }

  private async loadDbInfo(): Promise<void> {
    try {
      const repo = Repository.getInstance();
      const accounts = await repo.getAccounts();
      const categories = await repo.getCategories();
      this.dbInfo = `账户：${accounts.length}\n分类：${categories.length}`;
    } catch (e) {
      this.dbInfo = '数据读取失败';
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text('数据库信息')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, top: 16 })
          Text(this.dbInfo)
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })

          Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

          Text('应用信息')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.textPrimary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16 })
          Text('MyExpenses（鸿蒙版）\n版本: 1.0.0\n数据存储：relationalStore 本地数据库')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.textSecondary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })

          Text('更多调试与高级选项（如数据库导出、日志）将在后续版本提供。')
            .fontSize(12)
            .fontColor($r('app.color.textSecondary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .title('高级')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}