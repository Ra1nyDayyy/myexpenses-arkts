import { PaymentMethod } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';

/**
 * 付款方法输入对话框（鸿蒙原生 CustomDialog）
 */
@CustomDialog
export struct MethodInputDialog {
  controller?: CustomDialogController;
  title: string = '新建付款方法';
  @State label: string = '';
  onConfirm: (label: string) => void = () => {
  };

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '名称', text: this.label })
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.surfaceSecondary'))
        .onChange((v: string) => {
          this.label = v;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.surfaceSecondary'))
          .fontColor($r('app.color.textPrimary'))
          .onClick(() => {
            this.controller?.close();
          })
        Button('确定')
          .layoutWeight(1)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.onConfirm(this.label);
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .padding(20)
    .width('100%')
  }
}

/**
 * 付款方式管理页：对应 Android ManageMethods
 */
@Entry
@Component
struct MethodManage {
  @State methods: PaymentMethod[] = [];

  private repository: Repository = Repository.getInstance();
  private editMethod: PaymentMethod | null = null;
  private dialog: CustomDialogController = new CustomDialogController({
    builder: MethodInputDialog({
      title: '新建付款方法',
      onConfirm: (label: string) => {
        this.saveMethod(label);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false,
    cornerRadius: 12
  });

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.methods = await this.repository.getPaymentMethods();
  }

  private openAddDialog(): void {
    this.editMethod = null;
    this.dialog = new CustomDialogController({
      builder: MethodInputDialog({
        title: '新建付款方法',
        onConfirm: (label: string) => {
          this.saveMethod(label);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    this.dialog.open();
  }

  private async saveMethod(label: string): Promise<void> {
    if (!label.trim()) {
      return;
    }
    if (this.editMethod) {
      this.editMethod.label = label.trim();
      await this.repository.updatePaymentMethod(this.editMethod);
    } else {
      const m = new PaymentMethod();
      m.label = label.trim();
      m.isNumbered = false;
      m.type = 0;
      await this.repository.insertPaymentMethod(m);
    }
    this.editMethod = null;
    await this.load();
  }

  private async deleteMethod(m: PaymentMethod): Promise<void> {
    await this.repository.deletePaymentMethod(m.id);
    await this.load();
  }

  build() {
    Column() {
      PageHeader({
        title: '付款方法',
        rightText: '+',
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.openAddDialog();
        }
      })

      List({ space: 8 }) {
        ForEach(this.methods, (m: PaymentMethod) => {
          ListItem() {
            Row() {
              Text(m.label)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Image($r('sys.media.ohos_ic_public_close'))
                .width(18)
                .height(18)
                .opacity(0.6)
                .onClick(() => {
                  this.deleteMethod(m);
                })
            }
            .width('100%')
            .height(60)
            .padding({ left: 16, right: 12 })
            .margin({ left: 12, right: 12 })
            .borderRadius($r('app.float.native_card_radius'))
            .backgroundColor($r('app.color.surfacePrimary'))
          }
        }, (m: PaymentMethod) => `method_${m.id}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }
}
