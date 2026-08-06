import { Debt } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 债务管理页：对应 Android ManageDebts（债务）
 */
@Entry
@Component
struct DebtManage {
  @State debts: Debt[] = [];
  @State showDialog: boolean = false;
  @State newLabel: string = '';
  @State newAmount: string = '';
  @State newDescription: string = '';

  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.debts = await this.repository.getDebts();
  }

  private async addDebt(): Promise<void> {
    if (!this.newLabel.trim()) {
      promptAction.showToast({ message: '请输入债务名称' });
      return;
    }
    const d = new Debt();
    d.label = this.newLabel.trim();
    d.amount = parseFloat(this.newAmount) * 100 || 0;
    d.currency = 'CNY';
    d.description = this.newDescription.trim();
    d.date = Math.floor(Date.now() / 1000);
    await this.repository.insertDebt(d);
    this.showDialog = false;
    this.newLabel = '';
    this.newAmount = '';
    this.newDescription = '';
    await this.load();
  }

  private async deleteDebt(d: Debt): Promise<void> {
    await this.repository.deleteDebt(d.id);
    await this.load();
  }

  build() {
    Column() {
      PageHeader({
        title: '债务',
        rightText: '+',
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.showDialog = true;
        }
      })

      if (this.debts.length === 0) {
        Column({ space: 12 }) {
          Text('暂无债务')
            .fontSize(16)
            .fontColor($r('app.color.textSecondary'))
          Button('新建债务')
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
          ForEach(this.debts, (d: Debt) => {
            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(d.label)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.textPrimary'))
                  Text(`${d.description || '未设置描述'} · ${formatDate(d.date)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.textSecondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(`¥${formatMoney(d.amount, 2)}`)
                  .fontSize(14)
                  .fontColor($r('app.color.colorExpense'))

                Image($r('sys.media.ohos_ic_public_close'))
                  .width(16)
                  .height(16)
                  .opacity(0.6)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.deleteDebt(d);
                  })
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
              .backgroundColor($r('app.color.cardBackgroundColor'))
              .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
            }
          }, (d: Debt) => `debt_${d.id}`)
        }
        .layoutWeight(1)
        .width('100%')
      }

      // 新建债务对话框
      if (this.showDialog) {
        Column() {
          Text('新建债务')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 12 })
          TextInput({ placeholder: '债务名称', text: this.newLabel })
            .onChange((v: string) => {
              this.newLabel = v;
            })
          TextInput({ placeholder: '债务金额', text: this.newAmount })
            .type(InputType.Number)
            .margin({ top: 8 })
            .onChange((v: string) => {
              this.newAmount = v;
            })
          TextInput({ placeholder: '描述', text: this.newDescription })
            .margin({ top: 8 })
            .onChange((v: string) => {
              this.newDescription = v;
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
                this.addDebt();
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
}