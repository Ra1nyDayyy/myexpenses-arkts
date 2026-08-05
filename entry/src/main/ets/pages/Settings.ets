import { Repository } from '../database/Repository';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';

/**
 * 设置页：对应 Android PreferenceActivity（核心设置项）
 */
@Entry
@Component
struct Settings {
  @State showEquivalent: boolean = false;
  @State showSumDetails: boolean = false;

  private repository: Repository = Repository.getInstance();
  private settings: SettingsService = SettingsService.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.showEquivalent = await this.settings.getBoolean(PREF_KEY.SHOW_EQUIVALENT, false);
    this.showSumDetails = await this.settings.getBoolean(PREF_KEY.SHOW_SUM_DETAILS, false);
  }

  private async toggleEquivalent(v: boolean): Promise<void> {
    this.showEquivalent = v;
    await this.settings.setBoolean(PREF_KEY.SHOW_EQUIVALENT, v);
  }

  private async toggleSumDetails(v: boolean): Promise<void> {
    this.showSumDetails = v;
    await this.settings.setBoolean(PREF_KEY.SHOW_SUM_DETAILS, v);
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

        // 显示
        ListItem() {
          this.sectionTitle('显示')
        }
        ListItem() {
          this.switchRow('显示等值', this.showEquivalent, (v: boolean) => {
            this.toggleEquivalent(v);
          })
        }

        // AI
        ListItem() {
          this.sectionTitle('AI')
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
  navRow(label: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .layoutWeight(1)
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