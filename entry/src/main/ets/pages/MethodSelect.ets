import { PaymentMethod } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 付款方式选择页面（对齐安卓 MethodRow 点击：弹出选择列表）
 * - 单选：点击即选中并返回
 * - 通过 AppStorage('selectedMethodId') 回传结果
 */
@Entry
@Component
struct MethodSelect {
  @State methods: PaymentMethod[] = [];
  @State selectedMethodId: number = -1;
  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['selectedMethodId']) {
      this.selectedMethodId = params['selectedMethodId'] as number;
    }
    this.load();
  }

  async load(): Promise<void> {
    this.methods = await this.repository.getPaymentMethods();
  }

  /**
   * 选中并返回
   */
  private pick(methodId: number): void {
    AppStorage.setOrCreate('selectedMethodId', methodId);
    router.back();
  }

  build() {
    Column() {
      PageHeader({
        title: '选择付款方式',
        onBack: () => {
          router.back();
        }
      })

      if (this.methods.length === 0) {
        EmptyState({
          iconResource: $r('app.media.ic_method'),
          title: '暂无付款方式',
          subtitle: '请先在设置中添加付款方式'
        })
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 8 }) {
          ForEach(this.methods, (m: PaymentMethod) => {
            ListItem() {
              Row() {
                Text(m.label)
                  .fontSize(16)
                  .fontColor($r('app.color.textPrimary'))
                  .layoutWeight(1)
                  .margin({ left: 16 })

                if (this.selectedMethodId === m.id) {
                  Image($r('sys.media.ohos_ic_public_ok'))
                    .width(24)
                    .height(24)
                    .fillColor($r('app.color.primaryColor'))
                }
              }
              .width('100%')
              .height(56)
              .padding({ right: 16 })
              .margin({ left: 12, right: 12 })
              .borderRadius($r('app.float.native_card_radius'))
              .backgroundColor(this.selectedMethodId === m.id ?
                $r('app.color.surfaceBrandSoft') : $r('app.color.surfacePrimary'))
              .onClick(() => {
                this.pick(m.id);
              })
            }
          })
        }
        .layoutWeight(1)
        .backgroundColor($r('app.color.pageBackground'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }
}