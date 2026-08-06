import { Repository } from '../database/Repository';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { PageHeader } from '../components/PageHeader';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 设置页：对应 Android PreferenceActivity（扩展设置项）
 * 分组：数据管理 / 界面 / 显示 / 导入导出 / 关于
 */
@Entry
@Component
struct Settings {
  @State showEquivalent: boolean = false;
  @State showSumDetails: boolean = false;
  @State theme: number = 0; // 0 跟随系统 1 浅色 2 深色

  private repository: Repository = Repository.getInstance();
  private settings: SettingsService = SettingsService.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.showEquivalent = await this.settings.getBoolean(PREF_KEY.SHOW_EQUIVALENT, false);
    this.showSumDetails = await this.settings.getBoolean(PREF_KEY.SHOW_SUM_DETAILS, false);
    this.theme = await this.settings.getNumber(PREF_KEY.THEME, 0);
  }

  private async toggleEquivalent(v: boolean): Promise<void> {
    this.showEquivalent = v;
    await this.settings.setBoolean(PREF_KEY.SHOW_EQUIVALENT, v);
  }

  private async toggleSumDetails(v: boolean): Promise<void> {
    this.showSumDetails = v;
    await this.settings.setBoolean(PREF_KEY.SHOW_SUM_DETAILS, v);
  }

  private themeLabel(): string {
    if (this.theme === 1) {
      return '浅色';
    }
    if (this.theme === 2) {
      return '深色';
    }
    return '跟随系统';
  }

  /**
   * 主题设置：弹选择，通过 AppStorage 通知应用切换颜色模式
   */
  private setTheme(): void {
    const sheets: Array<SheetInfo> = [
      { title: '跟随系统', action: () => this.applyTheme(0) },
      { title: '浅色', action: () => this.applyTheme(1) },
      { title: '深色', action: () => this.applyTheme(2) }
    ];
    const options: ActionSheetOptions = {
      title: '主题',
      message: '选择界面主题',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
  }

  private async applyTheme(t: number): Promise<void> {
    this.theme = t;
    await this.settings.setNumber(PREF_KEY.THEME, t);
    AppStorage.setOrCreate('appTheme', t);
    promptAction.showToast({ message: '主题已切换，重启后生效' });
  }

  build() {
    Column() {
      PageHeader({
        title: '设置',
        onBack: () => {
          router.back();
        }
      })

      List({ space: 0 }) {
        // 数据管理
        ListItem() {
          this.sectionTitle('数据管理')
        }
        ListItem() {
          this.navRow('账户', () => {
            router.pushUrl({ url: 'pages/AccountEdit' }).catch(() => {
            });
          })
        }
        ListItem() {
          this.navRow('类别', () => {
            router.pushUrl({ url: 'pages/CategoryManage' }).catch(() => {
            });
          })
        }
        ListItem() {
          this.navRow('付款方法', () => {
            router.pushUrl({ url: 'pages/MethodManage' }).catch(() => {
            });
          })
        }
        ListItem() {
          this.navRow('标签', () => {
            router.pushUrl({ url: 'pages/TagManage' }).catch(() => {
            });
          })
        }
        ListItem() {
          this.navRow('货币', () => {
            promptAction.showToast({ message: '货币管理（人民币/美元/欧元等）' });
          })
        }

        // 界面
        ListItem() {
          this.sectionTitle('界面')
        }
        ListItem() {
          this.navRow('主题', () => {
            this.setTheme();
          }, this.themeLabel())
        }
        ListItem() {
          this.navRow('语言', () => {
            promptAction.showToast({ message: '当前仅支持中文' });
          }, '中文')
        }

        // 显示
        ListItem() {
          this.sectionTitle('显示')
        }
        ListItem() {
          this.switchRow('显示等值', this.showEquivalent, (v: boolean) => {
            this.toggleEquivalent(v);
          })
        }
        ListItem() {
          this.switchRow('分组头显示明细', this.showSumDetails, (v: boolean) => {
            this.toggleSumDetails(v);
          })
        }

        // 导入导出
        ListItem() {
          this.sectionTitle('导入导出')
        }
        ListItem() {
          this.navRow('CSV 导出', () => {
            promptAction.showToast({ message: 'CSV 导出功能开发中' });
          })
        }
        ListItem() {
          this.navRow('备份与恢复', () => {
            promptAction.showToast({ message: '备份与恢复功能开发中' });
          })
        }

        // 关于
        ListItem() {
          this.sectionTitle('关于')
        }
        ListItem() {
          this.navRow('版本', () => {
            promptAction.showToast({ message: '开支助手 1.0.0' });
          }, '1.0.0')
        }
        ListItem() {
          this.navRow('AI 助手', () => {
            router.pushUrl({ url: 'pages/AiAssistant' }).catch(() => {
            });
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: $r('app.color.dividerColor') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.primaryColor'))
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16, top: 20 })
  }

  @Builder
  navRow(label: string, onClick: () => void, value: string = '') {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value)
          .fontSize(14)
          .fontColor($r('app.color.textSecondary'))
          .margin({ right: 8 })
      }
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .opacity(0.4)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  switchRow(label: string, checked: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: checked })
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
  }
}
