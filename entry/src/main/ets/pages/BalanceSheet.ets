import { Account, AccountType } from '../model/Account';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router } from '@kit.ArkUI';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';

/**
 * 资产负债表：对应 Android BalanceSheet
 * 含日期、资产按类型分组（现金/银行/资产账户）、负债详情
 */
@Entry
@Component
struct BalanceSheet {
  @State accounts: Account[] = [];
  @State assets: number = 0;
  @State liabilities: number = 0;
  @State netWorth: number = 0;
  @State showDate: boolean = false;

  private repository: Repository = Repository.getInstance();
  private date: number = Math.floor(Date.now() / 1000);

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
      if (acc.type === AccountType.CCARD || acc.type === AccountType.LIABILITY) {
        liabilities += acc.currentBalance;
      } else {
        assets += acc.currentBalance;
      }
    }
    this.assets = assets;
    this.liabilities = liabilities;
    this.netWorth = assets + liabilities;
  }

  private assetAccounts(): Account[] {
    return this.accounts.filter((a: Account) => a.type !== AccountType.CCARD && a.type !== AccountType.LIABILITY);
  }

  private liabilityAccounts(): Account[] {
    return this.accounts.filter((a: Account) => a.type === AccountType.CCARD || a.type === AccountType.LIABILITY);
  }

  private cashAccounts(): Account[] {
    return this.assetAccounts().filter((a: Account) => a.type === AccountType.CASH);
  }

  private bankAccounts(): Account[] {
    return this.assetAccounts().filter((a: Account) => a.type === AccountType.BANK);
  }

  private otherAssetAccounts(): Account[] {
    return this.assetAccounts().filter((a: Account) => a.type === AccountType.ASSET);
  }

  private accountTypeName(acc: Account): string {
    return Account.typeName(acc.type);
  }

  private showDatePicker(): void {
    const current = new Date(this.date * 1000);
    const pickerOptions: DatePickerDialogOptions = {
      start: new Date(current.getFullYear() - 10, 0, 1),
      end: new Date(current.getFullYear() + 10, 11, 31),
      selected: current,
      onDateAccept: (value: Date) => {
        this.date = Math.floor(value.getTime() / 1000 / 86400) * 86400;
      }
    };
    this.getUIContext().showDatePickerDialog(pickerOptions);
  }

  build() {
    Column() {
      PageHeader({
        title: '资产负债表',
        onBack: () => {
          router.back();
        }
      })

      // 日期栏（对齐安卓日期显示）
      Row() {
        Text('日期')
          .fontSize(14)
          .fontColor($r('app.color.textPrimary'))
        Text(formatDate(this.date))
          .fontSize(14)
          .fontColor($r('app.color.primaryColor'))
          .margin({ left: 8 })
        Image($r('sys.media.ohos_ic_public_arrow_down'))
          .width(14)
          .height(14)
          .opacity(0.4)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.cardBackgroundColor'))
      .onClick(() => {
        this.showDatePicker();
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

          // 资产（按类型分组：现金/银行/资产账户）
          Column({ space: 8 }) {
            Row() {
              Text('资产')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text(this.amountText(this.assets))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.colorIncome'))
            }
            .width('100%')

            // 现金
            if (this.cashAccounts().length > 0) {
              this.assetGroup('现金', this.cashAccounts())
            }
            // 银行
            if (this.bankAccounts().length > 0) {
              this.assetGroup('银行', this.bankAccounts())
            }
            // 资产账户
            if (this.otherAssetAccounts().length > 0) {
              this.assetGroup('资产账户', this.otherAssetAccounts())
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius($r('app.float.card_radius'))

          // 负债
          Column({ space: 8 }) {
            Row() {
              Text('负债')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text(this.amountText(this.liabilities))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.colorExpense'))
            }
            .width('100%')

            ForEach(this.liabilityAccounts(), (acc: Account) => {
              Row() {
                Column({ space: 2 }) {
                  Text(acc.label)
                    .fontSize(14)
                    .layoutWeight(1)
                  Text(this.accountTypeName(acc))
                    .fontSize(11)
                    .fontColor($r('app.color.textSecondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text(this.amountText(acc.currentBalance))
                  .fontSize(14)
                  .fontColor($r('app.color.colorExpense'))
              }
              .width('100%')
              .height(44)
            }, (acc: Account) => `liab_${acc.id}`)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.cardBackgroundColor'))
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

  @Builder
  assetGroup(title: string, list: Account[]) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textSecondary'))
        .width('100%')
      ForEach(list, (acc: Account) => {
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
      }, (acc: Account) => `asset_${acc.id}_${title}`)
    }
    .width('100%')
  }

  private amountText(amount: number): string {
    return `¥${formatMoney(amount, 2)}`;
  }

  private netWorthText(): string {
    return `¥${formatMoney(this.netWorth, 2)}`;
  }
}
