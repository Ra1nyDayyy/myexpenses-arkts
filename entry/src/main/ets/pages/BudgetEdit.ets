import { Budget } from '../model/SupportEntities';
import { Account } from '../model/Account';
import { Repository } from '../database/Repository';
import { promptAction } from '@kit.ArkUI';

/**
 * 新建/编辑预算页面：对应 Android BudgetEdit (one_budget.xml)
 */
@Component
export struct BudgetEdit {
  @State title: string = '';
  @State amount: string = '';
  @State description: string = '';
  @State accountId: number = -1;
  @State accounts: Account[] = [];
  @State budgetType: number = 0; // 0=年度，1=月度等
  @State isDefaultBudget: boolean = false;
  @State filterCategory: string = '所有类别';
  @State filterPayee: string = '所有交易对手';
  @State filterMethod: string = '所有付款方式';
  @State filterStatus: string = '所有状态';
  @State filterTag: string = '所有标签';

  private repository: Repository = Repository.getInstance();
  private pathStack: NavPathStack = new NavPathStack();
  private budgetId: number = -1;
  private budgetTypes: string[] = ['年度', '月度', '周', '日'];

  aboutToAppear(): void {
    this.loadAccounts();
  }

  async loadAccounts(): Promise<void> {
    this.accounts = await this.repository.getAccounts();
    if (this.accountId < 0 && this.accounts.length > 0) {
      this.accountId = this.accounts[0].id;
    }
  }

  private async saveBudget(): Promise<void> {
    if (!this.title.trim()) {
      promptAction.showToast({ message: '请输入预算名称' });
      return;
    }
    if (!this.amount || parseFloat(this.amount) <= 0) {
      promptAction.showToast({ message: '请输入有效的预算金额' });
      return;
    }

    const budget = new Budget();
    budget.id = this.budgetId;
    budget.title = this.title.trim();
    budget.description = this.description.trim();
    budget.accountId = this.accountId;
    const acc = this.accounts.find((a: Account) => a.id === this.accountId);
    budget.currency = acc ? acc.currency : 'CNY';
    budget.budgetAmount = parseFloat(this.amount) * 100;

    await this.repository.insertBudget(budget);
    promptAction.showToast({ message: this.budgetId < 0 ? '预算创建成功' : '预算更新成功' });

    this.pathStack.pop();
  }

  private openCalculator(): void {
    promptAction.showToast({ message: '计算器功能开发中' });
  }

  build() {
    NavDestination() {
      Column() {
        // 滚动内容区
        Scroll() {
          Column({ space: 0 }) {
            // 标题
            Row() {
              Text('标题')
                .fontSize(16)
                .fontColor($r('app.color.textPrimary'))
                .width(100)
              TextInput({ placeholder: '输入预算标题', text: this.title })
                .layoutWeight(1)
                .backgroundColor(Color.Transparent)
                .onChange((value: string) => {
                  this.title = value;
                })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.cardBackgroundColor'))

            Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

            // 描述
            Row() {
              Text('描述')
                .fontSize(16)
                .fontColor($r('app.color.textPrimary'))
                .width(100)
              TextInput({ placeholder: '输入描述（可选）', text: this.description })
                .layoutWeight(1)
                .backgroundColor(Color.Transparent)
                .onChange((value: string) => {
                  this.description = value;
                })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.cardBackgroundColor'))

            Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

            // 分配的金额（带计算器）
            Row() {
              Text('分配的金额')
                .fontSize(16)
                .fontColor($r('app.color.textPrimary'))
                .width(100)
              Row({ space: 8 }) {
                TextInput({ placeholder: '0.00', text: this.amount })
                  .type(InputType.NUMBER_DECIMAL)
                  .layoutWeight(1)
                  .backgroundColor(Color.Transparent)
                  .onChange((value: string) => {
                    this.amount = value;
                  })

                // 计算器按钮
                Button() {
                  Image($r('app.media.ic_calculator'))
                    .width(20)
                    .height(20)
                    .fillColor($r('app.color.textSecondary'))
                }
                .width(36)
                .height(36)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.openCalculator();
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.cardBackgroundColor'))

            Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

            // 账户
            Row() {
              Text('账户')
                .fontSize(16)
                .fontColor($r('app.color.textPrimary'))
                .width(100)
              Select(this.accounts.map((a: Account) => ({ value: a.label } as SelectOption)))
                .selected(this.accounts.findIndex((a: Account) => a.id === this.accountId))
                .layoutWeight(1)
                .onSelect((index: number) => {
                  if (index >= 0 && index < this.accounts.length) {
                    this.accountId = this.accounts[index].id;
                  }
                })
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.cardBackgroundColor'))

            Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

            // 过滤器
            this.buildFilterRow()

            Divider().color($r('app.color.dividerColor')).strokeWidth(0.5)

            // 类型
            this.buildTypeRow()
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor($r('app.color.pageBackground'))

        // 底部保存按钮
        Button('保存')
          .width('90%')
          .height(48)
          .margin({ top: 16, bottom: 16 })
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.saveBudget();
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .title(this.budgetId < 0 ? '新建预算' : '编辑预算')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder

  buildFilterRow() {
    Row() {
      Text('过滤器')
        .fontSize(16)
        .fontColor($r('app.color.textPrimary'))
        .width(100)
        .alignSelf(ItemAlign.Start)
      
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.buildFilterChip(this.filterCategory, () => {
          promptAction.showToast({ message: '选择类别' });
        })
        this.buildFilterChip(this.filterPayee, () => {
          promptAction.showToast({ message: '选择交易对手' });
        })
        this.buildFilterChip(this.filterMethod, () => {
          promptAction.showToast({ message: '选择付款方式' });
        })
        this.buildFilterChip(this.filterStatus, () => {
          promptAction.showToast({ message: '选择状态' });
        })
        this.buildFilterChip(this.filterTag, () => {
          promptAction.showToast({ message: '选择标签' });
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildFilterChip(text: string, onClick: () => void) {
    Text(text)
      .fontSize(14)
      .fontColor($r('app.color.textSecondary'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .margin({ right: 8, bottom: 8 })
      .backgroundColor($r('app.color.pageBackground'))
      .borderRadius(16)
      .onClick(onClick)
  }

  @Builder
  buildTypeRow() {
    Row() {
      Text('类型')
        .fontSize(16)
        .fontColor($r('app.color.textPrimary'))
        .width(100)
      
      Row({ space: 12 }) {
        Select(this.budgetTypes.map((t: string) => ({ value: t } as SelectOption)))
          .selected(this.budgetType)
          .layoutWeight(1)
          .onSelect((index: number) => {
            this.budgetType = index;
          })
        
        Row({ space: 4 }) {
          Checkbox()
            .select(this.isDefaultBudget)
            .onChange((value: boolean) => {
              this.isDefaultBudget = value;
            })
          Text('默认')
            .fontSize(14)
            .fontColor($r('app.color.textPrimary'))
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
  }
}
