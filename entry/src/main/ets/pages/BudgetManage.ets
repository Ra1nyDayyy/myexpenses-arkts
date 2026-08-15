import { Budget } from '../model/SupportEntities';
import { Account } from '../model/Account';
import { Repository } from '../database/Repository';
import { formatMoney } from '../model/Money';
import { EmptyState } from '../components/EmptyState';
import { currencyByCode } from '../model/CurrencyUnit';
import { promptAction } from '@kit.ArkUI';

/**
 * 预算输入对话框（鸿蒙原生 CustomDialog）
 * 对应 Android ManageBudgets 的"新建预算"表单
 */
@CustomDialog
export struct BudgetInputDialog {
  controller?: CustomDialogController;
  accounts: Account[] = [];
  @State title: string = '';
  @State amount: string = '';
  @State accountId: number = -1;
  onConfirm: (title: string, amount: string, accountId: number) => void = () => {
  };

  private accountOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let a of this.accounts) {
      options.push({ value: a.label } as SelectOption);
    }
    return options;
  }

  private accountName(): string {
    const acc = this.accounts.find((a: Account) => a.id === this.accountId);
    return acc ? acc.label : '未选择账户';
  }

  build() {
    Column() {
      Text('新建预算')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '预算名称', text: this.title })
        .width('100%')
        .height(44)
        .onChange((v: string) => {
          this.title = v;
        })

      TextInput({ placeholder: '预算金额', text: this.amount })
        .type(InputType.Number)
        .width('100%')
        .height(44)
        .margin({ top: 12 })
        .onChange((v: string) => {
          this.amount = v;
        })

      // 账户选择（原生 Select，对应 Android 预算表单的账户下拉）
      Row() {
        Text('账户')
          .fontSize(14)
          .fontColor($r('app.color.textPrimary'))
          .width(56)
        Select(this.accountOptions())
          .selected(this.accounts.findIndex((a: Account) => a.id === this.accountId))
          .layoutWeight(1)
          .onSelect((index: number) => {
            if (index >= 0 && index < this.accounts.length) {
              this.accountId = this.accounts[index].id;
            }
          })
      }
      .width('100%')
      .height(44)
      .margin({ top: 8 })

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
            this.onConfirm(this.title, this.amount, this.accountId);
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
 * 预算管理页：对应 Android ManageBudgets（预算编制）
 * P0-3：已迁移为 NavDestination（原生标题栏 + 原生返回），不再使用手工 PageHeader
 */
@Component
export struct BudgetManage {
  @State budgets: Budget[] = [];
  @State accounts: Account[] = [];
  @State newAccountId: number = -1;

  private repository: Repository = Repository.getInstance();
  private pathStack: NavPathStack = new NavPathStack();
  private dialog: CustomDialogController = new CustomDialogController({
    builder: BudgetInputDialog({
      accounts: [],
      onConfirm: (title: string, amount: string, accountId: number) => {
        this.addBudget(title, amount, accountId);
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
    this.accounts = await this.repository.getAccounts();
    this.budgets = await this.repository.getBudgets();
    if (this.newAccountId < 0 && this.accounts.length > 0) {
      this.newAccountId = this.accounts[0].id;
    }
  }

  private openAddDialog(): void {
    // 每次打开重建 controller，确保传入最新的账户列表和默认账户
    this.dialog = new CustomDialogController({
      builder: BudgetInputDialog({
        accounts: this.accounts,
        accountId: this.newAccountId,
        onConfirm: (title: string, amount: string, accountId: number) => {
          this.addBudget(title, amount, accountId);
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: false,
      cornerRadius: 12
    });
    this.dialog.open();
  }

  private async addBudget(title: string, amount: string, accountId: number): Promise<void> {
    if (!title.trim()) {
      promptAction.showToast({ message: '请输入预算名称' });
      return;
    }
    const b = new Budget();
    b.title = title.trim();
    b.accountId = accountId;
    const acc = this.accounts.find((a: Account) => a.id === accountId);
    b.currency = acc ? acc.currency : 'CNY';
    b.budgetAmount = parseFloat(amount) * 100 || 0;
    await this.repository.insertBudget(b);
    this.newAccountId = accountId;
    await this.load();
  }

  private confirmDeleteBudget(b: Budget): void {
    promptAction.showDialog({
      title: '删除预算',
      message: `确定要删除预算"${b.title}"吗？`,
      buttons: [
        { text: '取消', color: '#808080' },
        { text: '删除', color: '#E84026' }
      ]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        this.deleteBudget(b);
      }
    }).catch(() => {
    });
  }

  private async deleteBudget(b: Budget): Promise<void> {
    await this.repository.deleteBudget(b.id);
    await this.load();
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          if (this.budgets.length === 0) {
            EmptyState({
              iconResource: $r('app.media.ic_category'),
              title: '暂无预算',
              subtitle: '点击右下角按钮新建预算'
            })
            .width('100%')
            .layoutWeight(1)
          } else {
            List({ space: 8 }) {
              ForEach(this.budgets, (b: Budget) => {
                ListItem() {
                  Row() {
                    Column({ space: 2 }) {
                      Text(b.title)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r('app.color.textPrimary'))
                      Text(`${b.description || '未设置描述'} · ${this.symbol(b.currency)}${formatMoney(b.budgetAmount, 2)}`)
                        .fontSize(12)
                        .fontColor($r('app.color.textSecondary'))
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

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
                    .onClick(() => {
                      this.confirmDeleteBudget(b);
                    })
                  }
                  .width('100%')
                  .height(68)
                  .padding({ left: 16, right: 16 })
                  .margin({ left: 12, right: 12 })
                  .borderRadius($r('app.float.native_card_radius'))
                  .backgroundColor($r('app.color.surfacePrimary'))
                }
              }, (b: Budget) => `budget_${b.id}`)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ bottom: 88 })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.pageBackground'))

        // 右下角FAB：新建预算（对齐安卓，跳转到独立编辑页面）
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
        .accessibilityText('新建预算')
        .position({ x: '100%', y: '100%' })
        .translate({ x: -72, y: -72 })
        .onClick(() => {
          this.openAddDialog();
        })
      }
      .width('100%')
      .height('100%')
    }
    .title('预算编制')
    .menus([
      {
        value: '新建预算',
        icon: $r('sys.media.ohos_ic_public_add'),
        action: () => {
          this.openAddDialog();
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

  private symbol(code: string): string {
    return currencyByCode(code).symbol;
  }
}
