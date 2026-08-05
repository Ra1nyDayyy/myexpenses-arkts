import { Account, AccountType, AccountGrouping } from '../model/Account';
import { Repository } from '../database/Repository';
import { CurrencyUnit, COMMON_CURRENCIES } from '../model/CurrencyUnit';
import { PageHeader } from '../components/PageHeader';
import { parseMoney, formatMoney } from '../model/Money';
import { generateUuid } from '../common/FormatUtils';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 账户编辑页：对应 Android AccountEdit + one_account.xml
 */
@Entry
@Component
struct AccountEdit {
  @State accountId: number = -1;
  @State label: string = '';
  @State description: string = '';
  @State openingBalanceInput: string = '';
  @State currency: string = 'CNY';
  @State type: AccountType = AccountType.BANK;
  @State color: number = 0xFFC107;
  @State criterionInput: string = '';

  private repository: Repository = Repository.getInstance();
  private currencies: CurrencyUnit[] = COMMON_CURRENCIES;
  private accountTypes: AccountType[] = [AccountType.BANK, AccountType.CASH, AccountType.CCARD, AccountType.ASSET, AccountType.LIABILITY];
  private colorOptions: number[] = [0xFFC107, 0x0050A7, 0x008000, 0x800000, 0x800080, 0x008080, 0x808000, 0x000080];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id'] !== undefined) {
      this.accountId = params['id'] as number;
    }
    if (this.accountId > 0) {
      this.loadAccount();
    }
  }

  async loadAccount(): Promise<void> {
    const acc = await this.repository.getAccount(this.accountId);
    if (acc) {
      this.label = acc.label;
      this.description = acc.description;
      this.openingBalanceInput = formatMoney(acc.openingBalance, this.fractionDigits());
      this.currency = acc.currency;
      this.type = acc.type;
      this.color = acc.color;
      if (acc.criterion > 0) {
        this.criterionInput = formatMoney(acc.criterion, this.fractionDigits());
      }
    }
  }

  private fractionDigits(): number {
    const c = this.currencies.find((item: CurrencyUnit) => item.code === this.currency);
    return c ? c.fractionDigits : 2;
  }

  private currencySymbol(): string {
    const c = this.currencies.find((item: CurrencyUnit) => item.code === this.currency);
    return c ? c.symbol : '¥';
  }

  private typeName(t: AccountType): string {
    return Account.typeName(t);
  }

  private colorToHex(color: number): string {
    const rgb = color & 0xFFFFFF;
    return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
  }

  private currencyOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let c of this.currencies) {
      options.push({ value: c.code } as SelectOption);
    }
    return options;
  }

  private typeOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let t of this.accountTypes) {
      options.push({ value: this.typeName(t) } as SelectOption);
    }
    return options;
  }

  private async save(): Promise<void> {
    if (!this.label.trim()) {
      promptAction.showToast({ message: '请输入账户名称' });
      return;
    }
    const acc = new Account();
    acc.id = this.accountId;
    acc.label = this.label.trim();
    acc.description = this.description.trim();
    acc.openingBalance = parseMoney(this.openingBalanceInput, this.fractionDigits());
    acc.currency = this.currency;
    acc.type = this.type;
    acc.color = this.color;
    acc.criterion = parseMoney(this.criterionInput, this.fractionDigits());
    acc.uuid = this.accountId > 0 ? acc.uuid : generateUuid();

    try {
      if (this.accountId > 0) {
        await this.repository.updateAccount(acc);
      } else {
        await this.repository.insertAccount(acc);
      }
      promptAction.showToast({ message: '保存成功' });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '保存失败' });
    }
  }

  @Builder
  formRow(label: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.textPrimary'))
        .width('30%')
    }
    .width('100%')
    .height(48)
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      PageHeader({
        title: this.accountId > 0 ? '编辑账户' : '新建账户',
        rightText: '保存',
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.save();
        }
      })

      Scroll() {
        Column() {
          // 名称
          Row() {
            Text('名称')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '账户名称', text: this.label })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.label = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 描述
          Row() {
            Text('描述')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '描述', text: this.description })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.description = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 起始余额
          Row() {
            Text('起始余额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.currencySymbol())
              .fontSize(16)
              .fontColor($r('app.color.textSecondary'))
              .margin({ right: 6 })
            TextInput({ placeholder: '0.00', text: this.openingBalanceInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.openingBalanceInput = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 货币
          Row() {
            Text('货币')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.currency)
              .fontSize(16)
              .layoutWeight(1)
            Select(this.currencyOptions())
              .selected(this.currencies.findIndex((c: CurrencyUnit) => c.code === this.currency))
              .onSelect((index: number) => {
                this.currency = this.currencies[index].code;
                this.openingBalanceInput = '';
                this.criterionInput = '';
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 类型
          Row() {
            Text('类型')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.typeName(this.type))
              .fontSize(16)
              .layoutWeight(1)
            Select(this.typeOptions())
              .selected(this.type)
              .onSelect((index: number) => {
                this.type = this.accountTypes[index];
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 颜色
          Row() {
            Text('颜色')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Row() {
              ForEach(this.colorOptions, (c: number) => {
                Stack() {
                  Circle()
                    .width(this.color === c ? 32 : 28)
                    .height(this.color === c ? 32 : 28)
                    .fill(this.colorToHex(c))
                    .stroke(this.color === c ? $r('app.color.primaryColor') : Color.Transparent)
                    .strokeWidth(3)
                }
                .width(38)
                .height(38)
                .alignContent(Alignment.Center)
                .onClick(() => {
                  this.color = c;
                })
              }, (c: number) => `color_${c}`)
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
          }
          .width('100%')
          .height(56)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 储蓄目标/信用额度
          Row() {
            Text(this.type === AccountType.CCARD || this.type === AccountType.LIABILITY ? '信用额度' : '储蓄目标')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.currencySymbol())
              .fontSize(16)
              .fontColor($r('app.color.textSecondary'))
              .margin({ right: 6 })
            TextInput({ placeholder: '0.00', text: this.criterionInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.criterionInput = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }
}
