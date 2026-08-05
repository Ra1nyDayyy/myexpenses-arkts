import { Account } from '../model/Account';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';

/**
 * 资产负债表：对应 Android BalanceSheet
 */
@Entry
@Component
struct BalanceSheet {
  @State accounts: Account[] = [];
  @State assets: number = 0;
  @State liabilities: number = 0;
  @State netWorth: number = 0;

  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.accounts = await this.repository.getAccounts();
    let assets = 0;
    let liabilities = 0;
    for (let acc of this.accounts) {
      if (acc.excludeFromTotals) {
        continue;
      }
      if (acc.type === 2 || acc.type === 4) { // 信用卡/负债
        liabilities += acc.currentBalance;
      } else {
        assets += acc.currentBalance;
      }
    }
    this.assets = assets;
    this.liabilities = liabilities;
    this.netWorth = assets + liabilities;
  }

  build() {
    Column() {
      PageHeader({
        title: '资产负债表',
        onBack: () => {
          router.back();
        }
      })

      Scroll() {
        Column({ space: 16 }) {
          // 净资产卡片
          Column({ space: 4 }) {
            Text('净资产')
              .fontSize(12)
              .fontColor($r('app.color.textSecondary'))
            Text(this.netWorthText())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.netWorth >= 0 ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius($r('app.float.card_radius'))
          .alignItems(HorizontalAlign.Center)

          // 资产
          Column({ space: 8 }) {
            Text('资产')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
            ForEach(this.accounts.filter((a: Account) => a.type !== 2 && a.type !== 4), (acc: Account) => {
              Row() {
                Text(acc.label)
                  .fontSize(14)
                  .layoutWeight(1)
                Text(this.amountText(acc.currentBalance))
                  .fontSize(14)
                  .fontColor($r('app.color.colorIncome'))
              }
              .width('100%')
              .height(40)
            }, (acc: Account) => `asset_${acc.id}`)
            Divider()
              .color($r('app.color.dividerColor'))
            Row() {
              Text('资产合计')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Blank()
              Text(this.amountText(this.assets))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.colorIncome'))
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius($r('app.float.card_radius'))

          // 负债
          Column({ space: 8 }) {
            Text('负债')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
            ForEach(this.accounts.filter((a: Account) => a.type === 2 || a.type === 4), (acc: Account) => {
              Row() {
                Text(acc.label)
                  .fontSize(14)
                  .layoutWeight(1)
                Text(this.amountText(acc.currentBalance))
                  .fontSize(14)
                  .fontColor($r('app.color.colorExpense'))
              }
              .width('100%')
              .height(40)
            }, (acc: Account) => `liab_${acc.id}`)
            Divider()
              .color($r('app.color.dividerColor'))
            Row() {
              Text('负债合计')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Blank()
              Text(this.amountText(this.liabilities))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.colorExpense'))
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.pageBackground'))
          .borderRadius($r('app.float.card_radius'))
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  private amountText(amount: number): string {
    return `¥${formatMoney(amount, 2)}`;
  }

  private netWorthText(): string {
    return `¥${formatMoney(this.netWorth, 2)}`;
  }
}