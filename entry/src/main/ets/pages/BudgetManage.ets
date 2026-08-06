import { Budget } from '../model/SupportEntities';
import { Account } from '../model/Account';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 预算管理页：对应 Android ManageBudgets（预算编制）
 */
@Entry
@Component
struct BudgetManage {
  @State budgets: Budget[] = [];
  @State accounts: Account[] = [];
  @State showDialog: boolean = false;
  @State newTitle: string = '';
  @State newAmount: string = '';
  @State newAccountId: number = -1;

  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.accounts = await this.repository.getAccounts();
    this.budgets = await this.repository.getBudgets();
    if (this.newAccountId < 0 && this.accounts.length > 0) {
      this.newAccountId = this.accounts[0].id;
    }
  }

  private async addBudget(): Promise<void> {
    if (!this.newTitle.trim()) {
      promptAction.showToast({ message: '请输入预算名称' });
      return;
    }
    const b = new Budget();
    b.title = this.newTitle.trim();
    b.accountId = this.newAccountId;
    const acc = this.accounts.find((a: Account) => a.id === this.newAccountId);
    b.currency = acc ? acc.currency : 'CNY';
    b.budgetAmount = parseFloat(this.newAmount) * 100 || 0;
    await this.repository.insertBudget(b);
    this.showDialog = false;
    this.newTitle = '';
    this.newAmount = '';
    await this.load();
  }

  private async deleteBudget(b: Budget): Promise<void> {
    await this.repository.deleteBudget(b.id);
    await this.load();
  }

  build() {
    Column() {
      PageHeader({
        title: '预算编制',
        rightText: '+',
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.showDialog = true;
        }
      })

      if (this.budgets.length === 0) {
        Column({ space: 12 }) {
          Text('暂无预算')
            .fontSize(16)
            .fontColor($r('app.color.textSecondary'))
          Button('新建预算')
            .backgroundColor($r('app.color.primaryColor'))
            .onClick(() => {
              this.showDialog = true;
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.budgets, (b: Budget) => {
            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(b.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.textPrimary'))
                  Text(`${b.description || '未设置描述'} · ${this.symbol(b.currency)}${formatMoney(b.budgetAmount, 2)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.textSecondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Image($r('sys.media.ohos_ic_public_close'))
                  .width(16)
                  .height(16)
                  .opacity(0.6)
                  .onClick(() => {
                    this.deleteBudget(b);
                  })
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
              .backgroundColor($r('app.color.cardBackgroundColor'))
              .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
            }
          }, (b: Budget) => `budget_${b.id}`)
        }
        .layoutWeight(1)
        .width('100%')
      }

      // 新建预算对话框
      if (this.showDialog) {
        Column() {
          Text('新建预算')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 12 })
          TextInput({ placeholder: '预算名称', text: this.newTitle })
            .onChange((v: string) => {
              this.newTitle = v;
            })
          TextInput({ placeholder: '预算金额', text: this.newAmount })
            .type(InputType.Number)
            .margin({ top: 8 })
            .onChange((v: string) => {
              this.newAmount = v;
            })
          Row() {
            Button('取消')
              .backgroundColor($r('app.color.cardBackgroundColor'))
              .fontColor($r('app.color.textPrimary'))
              .layoutWeight(1)
              .onClick(() => {
                this.showDialog = false;
              })
            Button('确定')
              .backgroundColor($r('app.color.primaryColor'))
              .layoutWeight(1)
              .margin({ left: 12 })
              .onClick(() => {
                this.addBudget();
              })
          }
          .margin({ top: 16 })
        }
        .width('80%')
        .padding(20)
        .backgroundColor($r('app.color.cardBackgroundColor'))
        .borderRadius(8)
        .position({ x: '10%', y: '35%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  private symbol(code: string): string {
    return currencyByCode(code).symbol;
  }
}