import { Debt } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';
import { EmptyState } from '../components/EmptyState';
import { promptAction } from '@kit.ArkUI';

/**
 * 债务输入对话框（鸿蒙原生 CustomDialog）
 * 对应 Android ManageDebts 的"新建债务"表单，描述使用多行 TextArea
 */
@CustomDialog
export struct DebtInputDialog {
  controller?: CustomDialogController;
  @State label: string = '';
  @State amount: string = '';
  @State description: string = '';
  onConfirm: (label: string, amount: string, description: string) => void = () => {
  };

  build() {
    Column() {
      Text('新建债务')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '债务名称', text: this.label })
        .width('100%')
        .height(44)
        .onChange((v: string) => {
          this.label = v;
        })

      TextInput({ placeholder: '债务金额', text: this.amount })
        .type(InputType.NUMBER_DECIMAL)
        .width('100%')
        .height(44)
        .margin({ top: 12 })
        .onChange((v: string) => {
          this.amount = v;
        })

      // 描述使用多行 TextArea
      TextArea({ placeholder: '描述', text: this.description })
        .width('100%')
        .height(72)
        .margin({ top: 12 })
        .onChange((v: string) => {
          this.description = v;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .fontColor($r('app.color.textPrimary'))
          .onClick(() => {
            this.controller?.close();
          })
        Button('确定')
          .layoutWeight(1)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.onConfirm(this.label, this.amount, this.description);
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
 * 债务管理页：对应 Android ManageDebts（债务）
 * P0-3：已迁移为 NavDestination（原生标题栏 + 原生返回），不再使用手工 PageHeader
 */
@Component
export struct DebtManage {
  @State debts: Debt[] = [];

  private repository: Repository = Repository.getInstance();
  private pathStack: NavPathStack = new NavPathStack();
  private dialog: CustomDialogController = new CustomDialogController({
    builder: DebtInputDialog({
      onConfirm: (label: string, amount: string, description: string) => {
        this.addDebt(label, amount, description);
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


  async load(): Promise<void> {
    this.debts = await this.repository.getDebts();
  }

  private openAddDialog(): void {
    this.dialog = new CustomDialogController({
      builder: DebtInputDialog({
        onConfirm: (label: string, amount: string, description: string) => {
          this.addDebt(label, amount, description);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    this.dialog.open();
  }

  private async addDebt(label: string, amount: string, description: string): Promise<void> {
    if (!label.trim()) {
      promptAction.showToast({ message: '请输入债务名称' });
      return;
    }
    const d = new Debt();
    d.label = label.trim();
    d.amount = parseFloat(amount) * 100 || 0;
    d.currency = 'CNY';
    d.description = description.trim();
    d.date = Math.floor(Date.now() / 1000);
    await this.repository.insertDebt(d);
    await this.load();
  }

  private confirmDeleteDebt(d: Debt): void {
    promptAction.showDialog({
      title: '删除债务',
      message: `确定要删除债务"${d.label}"吗？`,
      buttons: [
        { text: '取消', color: '#808080' },
        { text: '删除', color: '#E84026' }
      ]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        this.deleteDebt(d);
      }
    }).catch(() => {
    });
  }

  private async deleteDebt(d: Debt): Promise<void> {
    await this.repository.deleteDebt(d.id);
    await this.load();
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          if (this.debts.length === 0) {
            EmptyState({
              iconResource: $r('app.media.ic_locked'),
              title: '暂无债务',
              subtitle: '点击右下角按钮新建债务记录'
            })
            .width('100%')
            .layoutWeight(1)
          } else {
            List({ space: 8 }) {
              ForEach(this.debts, (d: Debt) => {
                ListItem() {
                  Row() {
                    Column({ space: 2 }) {
                      Text(d.label)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r('app.color.textPrimary'))
                      Text(`${d.description || '未设置描述'} · ${formatDate(d.date)}`)
                        .fontSize(12)
                        .fontColor($r('app.color.textSecondary'))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Text(`¥${formatMoney(d.amount, 2)}`)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.colorExpense'))

                    // 删除按钮：Button 包裹保证足够点击热区（P0-3）
                    Button() {
                      Image($r('sys.media.ohos_ic_public_close'))
                        .width(16)
                        .height(16)
                        .opacity(0.6)
                    }
                    .type(ButtonType.Normal)
                    .width($r('app.float.native_touch_target'))
                    .height($r('app.float.native_touch_target'))
                    .backgroundColor(Color.Transparent)
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.confirmDeleteDebt(d);
                    })
                  }
                  .width('100%')
                  .height(68)
                  .padding({ left: 16, right: 16 })
                  .margin({ left: 12, right: 12 })
                  .borderRadius($r('app.float.native_card_radius'))
                  .backgroundColor($r('app.color.surfacePrimary'))
                }
              }, (d: Debt) => `debt_${d.id}`)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ bottom: 88 })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.pageBackground'))

        // 右下角FAB：新建债务（对齐安卓）
        Button() {
          Image($r('sys.media.ohos_ic_public_add'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .width(56)
        .height(56)
        .type(ButtonType.Circle)
        .backgroundColor($r('app.color.primaryColor'))
        .stateEffect(true)
        .accessibilityText('新建债务')
        .position({ x: '100%', y: '100%' })
        .translate({ x: -72, y: -72 })
        .onClick(() => {
          this.openAddDialog();
        })
      }
      .width('100%')
      .height('100%')
    }
    .title('交易对手/债务')
    .menus([
      {
        value: '搜索',
        icon: $r('sys.media.ohos_ic_public_search_filled'),
        action: () => {
          promptAction.showToast({ message: '搜索功能开发中' });
        }
      },
      {
        value: '帮助',
        icon: $r('app.media.ic_help'),
        action: () => {
          promptAction.showToast({ message: '帮助功能开发中' });
        }
      }
    ])
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .onShown(() => {
      this.load();
    })
    .backgroundColor($r('app.color.pageBackground'))
  }
}
