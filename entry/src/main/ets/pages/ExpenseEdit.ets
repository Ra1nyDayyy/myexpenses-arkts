import { Transaction, OperationType, CrStatus } from '../model/Transaction';
import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { parseMoney, formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { generateUuid, formatDateTime } from '../common/FormatUtils';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 记账编辑页：对应 Android ExpenseEdit + one_expense.xml
 */
@Entry
@Component
struct ExpenseEdit {
  @State transactionId: number = -1;
  @State accountId: number = -1;
  @State operationType: OperationType = OperationType.TRANSACTION;
  @State isIncome: boolean = false;
  @State amountInput: string = '';
  @State comment: string = '';
  @State payeeInput: string = '';
  @State selectedCategoryId: number = -1;
  @State selectedCategoryLabel: string = '';
  @State methodId: number = -1;
  @State transferAccountId: number = -1;
  @State date: number = Math.floor(Date.now() / 1000);
  @State crStatus: CrStatus = CrStatus.UNRECONCILED;
  @State referenceNumber: string = '';
  @State tagIds: number[] = [];

  private repository: Repository = Repository.getInstance();
  @State accounts: Account[] = [];
  @State categories: Category[] = [];
  @State methods: PaymentMethod[] = [];
  @State payees: Payee[] = [];
  @State tags: Tag[] = [];
  private currencyCode: string = 'CNY';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id'] !== undefined) {
      this.transactionId = params['id'] as number;
    }
    if (params && params['accountId'] !== undefined) {
      this.accountId = params['accountId'] as number;
    }
    this.loadData();
  }

  onPageShow(): void {
    const selected = AppStorage.get<Record<string, Object>>('selectedCategory');
    if (selected && selected['categoryId'] !== undefined) {
      this.selectedCategoryId = selected['categoryId'] as number;
      this.selectedCategoryLabel = selected['categoryLabel'] as string;
      AppStorage.delete('selectedCategory');
    }
  }

  async loadData(): Promise<void> {
    this.accounts = await this.repository.getAccounts();
    // 默认选择第一个账户（保证首帧即有账户）
    if (this.accountId <= 0 && this.accounts.length > 0) {
      this.accountId = this.accounts[0].id;
      this.currencyCode = this.accounts[0].currency;
    }
    this.categories = await this.repository.getCategories();
    this.methods = await this.repository.getPaymentMethods();
    this.payees = await this.repository.getPayees();
    this.tags = await this.repository.getTags();
    if (this.methodId <= 0 && this.methods.length > 0) {
      this.methodId = this.methods[0].id;
    }
    const acc = this.accounts.find((a: Account) => a.id === this.accountId);
    if (acc) {
      this.currencyCode = acc.currency;
    }
    if (this.transactionId > 0) {
      await this.loadTransaction();
    }
  }

  async loadTransaction(): Promise<void> {
    const t = await this.repository.getTransaction(this.transactionId);
    if (t) {
      this.accountId = t.accountId;
      this.comment = t.comment;
      this.payeeInput = t.payeeName;
      this.selectedCategoryId = t.categoryId;
      this.selectedCategoryLabel = t.categoryPath;
      this.methodId = t.methodId;
      this.date = t.date;
      this.crStatus = t.crStatus;
      this.referenceNumber = t.referenceNumber;
      this.tagIds = t.tagIds;
      this.isIncome = t.amount > 0;
      this.amountInput = formatMoney(Math.abs(t.amount), this.fractionDigits());
      if (t.transferAccountId > 0) {
        this.operationType = OperationType.TRANSFER;
        this.transferAccountId = t.transferAccountId;
      }
    }
  }

  private fractionDigits(): number {
    return currencyByCode(this.currencyCode).fractionDigits;
  }

  private currencySymbol(): string {
    return currencyByCode(this.currencyCode).symbol;
  }

  private methodName(id: number): string {
    const m = this.methods.find((item: PaymentMethod) => item.id === id);
    return m ? m.label : '选择';
  }

  private accountLabel(): string {
    const acc = this.accounts.find((a: Account) => a.id === this.accountId);
    return acc ? acc.label : '选择';
  }

  private accountIndex(): number {
    return this.accounts.findIndex((a: Account) => a.id === this.accountId);
  }

  private transferAccountLabel(): string {
    const acc = this.accounts.find((a: Account) => a.id === this.transferAccountId);
    return acc ? acc.label : '选择';
  }

  private transferAccounts(): Account[] {
    return this.accounts.filter((a: Account) => a.id !== this.accountId);
  }

  private transferAccountIndex(): number {
    const list = this.transferAccounts();
    return list.findIndex((a: Account) => a.id === this.transferAccountId);
  }

  private accountOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let a of this.accounts) {
      options.push({ value: a.label } as SelectOption);
    }
    return options;
  }

  private transferAccountOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let a of this.transferAccounts()) {
      options.push({ value: a.label } as SelectOption);
    }
    return options;
  }

  private methodOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let m of this.methods) {
      options.push({ value: m.label } as SelectOption);
    }
    return options;
  }

  private async save(): Promise<void> {
    const amount = parseMoney(this.amountInput, this.fractionDigits());
    if (this.accountId <= 0) {
      promptAction.showToast({ message: '请选择账户' });
      return;
    }
    if (this.operationType === OperationType.TRANSFER && this.transferAccountId <= 0) {
      promptAction.showToast({ message: '请选择目标账户' });
      return;
    }
    if (this.operationType !== OperationType.TRANSFER && amount === 0) {
      promptAction.showToast({ message: '请输入金额' });
      return;
    }
    const t = new Transaction();
    t.id = this.transactionId;
    t.accountId = this.accountId;
    t.amount = this.isIncome ? Math.abs(amount) : -Math.abs(amount);
    t.comment = this.comment.trim();
    t.categoryId = this.selectedCategoryId;
    t.payeeId = this.payeeInput.trim() ? await this.repository.findOrCreatePayee(this.payeeInput) : -1;
    t.methodId = this.methodId;
    t.date = this.date;
    t.valueDate = this.date;
    t.crStatus = this.crStatus;
    t.referenceNumber = this.referenceNumber;
    t.uuid = this.transactionId > 0 ? t.uuid : generateUuid();
    t.tagIds = this.tagIds;

    try {
      if (this.operationType === OperationType.TRANSFER && this.transferAccountId > 0) {
        if (this.transactionId > 0) {
          await this.repository.updateTransaction(t);
        } else {
          const sourceId = await this.repository.insertTransaction(t);
          const dest = new Transaction();
          dest.accountId = this.transferAccountId;
          dest.amount = -t.amount;
          dest.comment = t.comment;
          dest.categoryId = -1;
          dest.methodId = t.methodId;
          dest.date = t.date;
          dest.valueDate = t.valueDate;
          dest.crStatus = t.crStatus;
          dest.uuid = generateUuid();
          const destId = await this.repository.insertTransaction(dest);
          t.transferPeerId = destId;
          t.transferAccountId = this.transferAccountId;
          await this.repository.updateTransaction(t);
          dest.transferPeerId = sourceId;
          dest.transferAccountId = this.accountId;
          await this.repository.updateTransaction(dest);
        }
      } else if (this.transactionId > 0) {
        await this.repository.updateTransaction(t);
      } else {
        await this.repository.insertTransaction(t);
      }
      promptAction.showToast({ message: '保存成功' });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '保存失败: ' + JSON.stringify(e) });
    }
  }

  private navigateCategorySelect(): void {
    router.pushUrl({
      url: 'pages/CategorySelect',
      params: { type: this.isIncome ? 1 : -1 }
    }).catch(() => {
    });
  }

  /**
   * 弹出鸿蒙原生日期选择器
   */
  private showDatePicker(): void {
    const current = new Date(this.date * 1000);
    const pickerOptions: DatePickerDialogOptions = {
      start: new Date(current.getFullYear() - 10, 0, 1),
      end: new Date(current.getFullYear() + 10, 11, 31),
      selected: current,
      onDateAccept: (value: Date) => {
        this.date = Math.floor(value.getTime() / 1000);
      }
    };
    this.getUIContext().showDatePickerDialog(pickerOptions);
  }

  build() {
    Column() {
      PageHeader({
        title: this.transactionId > 0 ? '编辑交易' : '新建交易',
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
          // 类型切换（鸿蒙原生 Tabs 分段控件，仅用 TabBar，内容区不占空间）
          Tabs({ barPosition: BarPosition.Start }) {
            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(0, '支出'))

            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(1, '收入'))

            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(2, '转账'))
          }
          .width('100%')
          .height(44)
          .barHeight(44)
          .scrollable(false)
          .animationDuration(150)
          .onChange((index: number) => {
            if (index === 0) {
              this.isIncome = false;
              this.operationType = OperationType.TRANSACTION;
            } else if (index === 1) {
              this.isIncome = true;
              this.operationType = OperationType.TRANSACTION;
            } else {
              this.operationType = OperationType.TRANSFER;
            }
          })

          // 账户
          Row() {
            Text('账户')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.accountLabel())
              .fontSize(16)
              .layoutWeight(1)
            Select(this.accountOptions())
              .selected(this.accountIndex())
              .onSelect((index: number) => {
                this.accountId = this.accounts[index].id;
                this.currencyCode = this.accounts[index].currency;
                this.amountInput = '';
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 转账目标账户
          if (this.operationType === OperationType.TRANSFER) {
            Row() {
              Text('至')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Text(this.transferAccountLabel())
                .fontSize(16)
                .layoutWeight(1)
              Select(this.transferAccountOptions())
                .selected(this.transferAccountIndex())
                .onSelect((index: number) => {
                  this.transferAccountId = this.transferAccounts()[index].id;
                })
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 金额
          Row() {
            Text('金额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.currencySymbol())
              .fontSize(16)
              .fontColor($r('app.color.textSecondary'))
              .margin({ right: 6 })
            TextInput({ placeholder: '0.00', text: this.amountInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .onChange((v: string) => {
                this.amountInput = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 类别
          Row() {
            Text('类别')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.selectedCategoryLabel || '选择')
              .fontSize(16)
              .fontColor(this.selectedCategoryId >= 0 ? $r('app.color.textPrimary') : $r('app.color.textSecondary'))
              .layoutWeight(1)
            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(16)
              .height(16)
              .opacity(0.4)
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          .onClick(() => {
            this.navigateCategorySelect();
          })

          // 收款人
          Row() {
            Text('收款人')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '收款人', text: this.payeeInput })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.payeeInput = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 日期（点击弹出鸿蒙原生日期选择器）
          Row() {
            Text('日期')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(formatDateTime(this.date))
              .fontSize(16)
              .layoutWeight(1)
            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(16)
              .height(16)
              .opacity(0.4)
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          .onClick(() => {
            this.showDatePicker();
          })

          // 付款方法
          Row() {
            Text('付款方法')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.methodName(this.methodId))
              .fontSize(16)
              .layoutWeight(1)
            Select(this.methodOptions())
              .selected(this.methods.findIndex((m: PaymentMethod) => m.id === this.methodId))
              .onSelect((index: number) => {
                this.methodId = this.methods[index].id;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 备注
          Row() {
            Text('备注')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '备注', text: this.comment })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.comment = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 标签
          if (this.tags.length > 0) {
            Row() {
              Text('标签')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.tags, (tag: Tag) => {
                  Row() {
                    Text(tag.label)
                      .fontSize(12)
                      .fontColor(this.tagIds.indexOf(tag.id) >= 0 ? Color.White : $r('app.color.textPrimary'))
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  }
                  .backgroundColor(this.tagIds.indexOf(tag.id) >= 0 ? $r('app.color.primaryColor') : $r('app.color.cardBackgroundColor'))
                  .borderRadius(8)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    const idx = this.tagIds.indexOf(tag.id);
                    if (idx >= 0) {
                      this.tagIds.splice(idx, 1);
                      this.tagIds = [...this.tagIds];
                    } else {
                      this.tagIds = [...this.tagIds, tag.id];
                    }
                  })
                }, (tag: Tag) => `tag_${tag.id}`)
              }
              .layoutWeight(1)

            }
            .width('100%')
            .height(48)
            .padding({ top: 8, bottom: 8 })
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
            .alignItems(VerticalAlign.Top)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  tabTypeBuilder(tabIndex: number, label: string) {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.typeActive(tabIndex) ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
      .width('100%')
      .height('100%')
      .textAlign(TextAlign.Center)
  }

  private typeActive(tabIndex: number): boolean {
    if (tabIndex === 0) {
      return !this.isIncome && this.operationType !== OperationType.TRANSFER;
    }
    if (tabIndex === 1) {
      return this.isIncome && this.operationType !== OperationType.TRANSFER;
    }
    return this.operationType === OperationType.TRANSFER;
  }
}
