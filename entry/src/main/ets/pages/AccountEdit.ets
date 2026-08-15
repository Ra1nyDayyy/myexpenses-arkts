import { Account, AccountType, AccountGrouping } from '../model/Account';
import { Repository } from '../database/Repository';
import { Tag } from '../model/SupportEntities';
import { CurrencyUnit, COMMON_CURRENCIES } from '../model/CurrencyUnit';
import { PageHeader } from '../components/PageHeader';
import { CalculatorDialog } from '../components/CalculatorDialog';
import { AccountColorDialog } from '../components/ColorPickerDialog';
import { parseMoney, formatMoney } from '../model/Money';
import { generateUuid } from '../common/FormatUtils';
import { router, promptAction } from '@kit.ArkUI';
import { InlineExpansionState } from '../ui/InlineExpansionState';

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
  @State tags: Tag[] = [];
  @State accountTagIds: number[] = [];
  /** 不计入总计（对齐安卓 EXCLUDE_FROM_TOTALS_COMMAND） */
  @State excludeFromTotals: boolean = false;
  /** 动态汇率（对齐安卓 DYNAMIC_EXCHANGE_RATE_COMMAND，仅外币账户） */
  @State dynamicExchangeRates: boolean = false;
  /** 起始余额正负开关（对齐安卓 type_switch：true=+收入 false=−支出，默认+） */
  @State openingPositive: boolean = true;
  /** 储蓄目标/信用额度正负开关（对齐安卓 type_switch，默认−支出） */
  @State criterionPositive: boolean = false;
  @State fieldHelpExpanded: boolean = false;
  /** 默认本币（用于判断是否外币账户） */
  private defaultCurrency: string = 'CNY';
  /** 当前编辑中账户货币（用于动态汇率判断） */
  private get homeCurrency(): string {
    return this.defaultCurrency;
  }
  /** 当前正在编辑的金额字段（opening/criterion），计算器结果写入对应字段 */
  private amountTarget: string = 'opening';
  private calculator: CustomDialogController = new CustomDialogController({
    builder: CalculatorDialog({
      onResult: (value: string) => {
        if (this.amountTarget === 'opening') {
          this.openingBalanceInput = value;
        } else {
          this.criterionInput = value;
        }
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    cornerRadius: 16
  });
  private colorDialog: CustomDialogController = new CustomDialogController({
    builder: AccountColorDialog({
      color: 0xFFC107,
      onResult: (c: number) => {
        this.color = c;
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    cornerRadius: 16
  });

  private repository: Repository = Repository.getInstance();
  private currencies: CurrencyUnit[] = COMMON_CURRENCIES;
  private accountTypes: AccountType[] = [AccountType.BANK, AccountType.CASH, AccountType.CCARD, AccountType.ASSET, AccountType.LIABILITY];


  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id'] !== undefined) {
      this.accountId = params['id'] as number;
    }
    this.loadTags();
    if (this.accountId > 0) {
      this.loadAccount();
    }
  }

  // 从标签管理页返回时刷新标签列表（不重置已填写的表单字段）
  onPageShow(): void {
    this.loadTags();
  }

  async loadTags(): Promise<void> {
    this.tags = await this.repository.getTags();
    if (this.accountId > 0) {
      this.accountTagIds = await this.repository.getAccountTagIds(this.accountId);
    }
  }

  async loadAccount(): Promise<void> {
    const acc = await this.repository.getAccount(this.accountId);
    if (acc) {
      this.label = acc.label;
      this.description = acc.description;
      this.openingBalanceInput = formatMoney(Math.abs(acc.openingBalance), this.fractionDigits());
      this.openingPositive = acc.openingBalance >= 0;
      this.currency = acc.currency;
      this.type = acc.type;
      this.color = acc.color;
      this.excludeFromTotals = acc.excludeFromTotals;
      if (acc.criterion !== 0) {
        this.criterionInput = formatMoney(Math.abs(acc.criterion), this.fractionDigits());
        this.criterionPositive = acc.criterion >= 0;
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

  /** 打开金额计算器（对齐安卓 AmountInput 的计算器按钮，target: opening/criterion） */
  private showAmountCalculator(target: string): void {
    this.amountTarget = target;
    const current = target === 'opening' ? this.openingBalanceInput : this.criterionInput;
    this.calculator = new CustomDialogController({
      builder: CalculatorDialog({
        display: current || '0',
        onResult: (value: string) => {
          if (target === 'opening') {
            this.openingBalanceInput = value;
          } else {
            this.criterionInput = value;
          }
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      cornerRadius: 16
    });
    this.calculator.open();
  }

  /** 打开颜色选择对话框（对齐安卓 SimpleColorDialog：常用色板 + 调色盘） */
  private showColorDialog(): void {
    this.colorDialog = new CustomDialogController({
      builder: AccountColorDialog({
        color: this.color,
        onResult: (c: number) => {
          this.color = c;
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      cornerRadius: 16
    });
    this.colorDialog.open();
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
      promptAction.showToast({ message: $r('app.string.toast_enter_account_name') });
      return;
    }
    const acc = new Account();
    acc.id = this.accountId;
    acc.label = this.label.trim();
    acc.description = this.description.trim();
    let opening = parseMoney(this.openingBalanceInput, this.fractionDigits());
    if (!this.openingPositive) {
      opening = -opening;
    }
    acc.openingBalance = opening;
    acc.currency = this.currency;
    acc.type = this.type;
    acc.color = this.color;
    acc.excludeFromTotals = this.excludeFromTotals;
    let criterion = parseMoney(this.criterionInput, this.fractionDigits());
    if (!this.criterionPositive) {
      criterion = -criterion;
    }
    acc.criterion = criterion;
    acc.uuid = this.accountId > 0 ? acc.uuid : generateUuid();

    try {
      let savedId = this.accountId;
      if (this.accountId > 0) {
        await this.repository.updateAccount(acc);
      } else {
        savedId = await this.repository.insertAccount(acc);
      }
      // 写账户标签
      if (savedId > 0) {
        await this.repository.setAccountTagIds(savedId, this.accountTagIds);
      }
      promptAction.showToast({ message: $r('app.string.toast_save_success') });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: $r('app.string.toast_save_failed') });
    }
  }

  /** 更多选项菜单（对齐安卓 AccountEdit 工具栏更多菜单：不计入总数 + 动态汇率） */
  /** 更多按钮下拉菜单（对齐安卓 account_edit.xml 工具栏菜单：在按钮附近展开，非弹窗） */
  private accountMoreMenu(): Array<MenuElement> {
    const menu: Array<MenuElement> = [];
    menu.push({
      value: (this.excludeFromTotals ? '✓ ' : '') + '不计入总数',
      action: () => {
        this.excludeFromTotals = !this.excludeFromTotals;
      }
    } as MenuElement);
    // 动态汇率（对齐安卓 DYNAMIC_EXCHANGE_RATE_COMMAND，仅外币账户显示）
    if (this.currency !== this.homeCurrency) {
      menu.push({
        value: (this.dynamicExchangeRates ? '✓ ' : '') + '动态汇率',
        action: () => {
          this.dynamicExchangeRates = !this.dynamicExchangeRates;
        }
      } as MenuElement);
    }
    return menu;
  }

  /** 更多按钮回调（无下拉菜单时触发，兼容） */
  private showMoreMenu(): void {
  }

  /** 删除当前账户 */
  private async deleteAccount(): Promise<void> {
    try {
      await this.repository.deleteAccount(this.accountId);
      promptAction.showToast({ message: $r('app.string.toast_deleted') });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: $r('app.string.toast_save_failed') });
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

  @Builder
  fieldHelpPanel() {
    Column({ space: 8 }) {
      Row() {
        Text('账户字段说明')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textPrimary'))
        Blank()
        Button('收起')
          .height($r('app.float.native_touch_target'))
          .fontSize(13)
          .fontColor($r('app.color.primaryColor'))
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.fieldHelpExpanded = false;
          })
      }
      .width('100%')
      this.fieldHelpRow('名称', '用于在账户列表中识别账户。')
      this.fieldHelpRow('描述', '仅作为账户的补充信息。')
      this.fieldHelpRow('起始余额', '正负开关决定期初余额方向，计算器按钮可辅助输入。')
      this.fieldHelpRow('货币', '从应用提供的币种列表中选择。')
      this.fieldHelpRow('类型', '可设为现金、银行、资产、负债或信用卡。')
      this.fieldHelpRow('颜色', '用于账户列表和交易页的账户标识色。')
      this.fieldHelpRow('活跃标签', '可关联一个或多个标签，新建交易时按所选账户自动标记。')
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 10 })
    .borderRadius(16)
    .backgroundColor($r('app.color.surfaceBrandSoft'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  fieldHelpRow(label: string, description: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))
      Text(description)
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
    Column() {
      PageHeader({
        title: this.accountId > 0 ? '编辑账户' : '新建账户',
        showHelp: true,
        showMore: true,
        moreMenu: this.accountMoreMenu(),
        onBack: () => {
          router.back();
        },
        onHelp: () => {
          this.fieldHelpExpanded = InlineExpansionState.toggle(this.fieldHelpExpanded);
        },
        onMore: () => {
          this.showMoreMenu();
        }
      })

      Scroll() {
        Column() {
          if (this.fieldHelpExpanded) {
            this.fieldHelpPanel()
          }
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

          // 起始余额（对齐安卓 AmountInput：+/− 类型开关 + 计算器按钮）
          Row() {
            Text('起始余额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            // 收入/支出类型开关（对齐安卓 type_switch：textOn="+" textOff="−"）
            Toggle({ type: ToggleType.Switch, isOn: this.openingPositive })
              .selectedColor($r('app.color.colorIncome'))
              .switchPointColor(Color.White)
              .onChange((isOn: boolean) => {
                this.openingPositive = isOn;
              })
            Text(this.openingPositive ? '+' : '−')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.openingPositive ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
              .margin({ left: 4 })
            TextInput({ placeholder: '0.00', text: this.openingBalanceInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.openingBalanceInput = v;
              })
            Image($r('app.media.ic_calculate'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.textSecondary'))
              .margin({ left: 8 })
              .onClick(() => {
                this.showAmountCalculator('opening');
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

          // 颜色（对齐安卓 color_input：色块 + 铅笔编辑图标，点击打开色板）
          Row() {
            Text('颜色')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Row() {
              // 当前色块
              Circle()
                .width(24)
                .height(24)
                .fill(this.colorToHex(this.color))
                .stroke($r('app.color.dividerColor'))
                .strokeWidth(1)
              // 铅笔编辑图标（对齐安卓 ic_menu_edit，点击打开颜色对话框）
              Image($r('app.media.ic_color_edit'))
                .width(20)
                .height(20)
                .fillColor($r('app.color.textSecondary'))
                .margin({ left: 10 })
                .onClick(() => {
                  this.showColorDialog();
                })
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 标签（对齐安卓 tag_row：位于颜色与储蓄目标之间，行末加号跳转标签管理页）
          Row() {
            Text('标签')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            if (this.tags.length === 0) {
              Text('暂无标签')
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
                .layoutWeight(1)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.tags, (tag: Tag) => {
                  Row() {
                    Text(tag.label)
                      .fontSize(12)
                      .fontColor(this.accountTagIds.indexOf(tag.id) >= 0 ? Color.White : $r('app.color.textPrimary'))
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  }
                  .backgroundColor(this.accountTagIds.indexOf(tag.id) >= 0 ? $r('app.color.primaryColor') : $r('app.color.cardBackgroundColor'))
                  .borderRadius(8)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    const idx = this.accountTagIds.indexOf(tag.id);
                    if (idx >= 0) {
                      this.accountTagIds.splice(idx, 1);
                      this.accountTagIds = [...this.accountTagIds];
                    } else {
                      this.accountTagIds = [...this.accountTagIds, tag.id];
                    }
                  })
                }, (tag: Tag) => `atag_${tag.id}`)
              }
              .layoutWeight(1)
            }
            // 加号：跳转标签管理页（对齐安卓 TagSelection -> ManageTags）
            Image($r('sys.media.ohos_ic_public_add'))
              .width(20)
              .height(20)
              .opacity(0.6)
              .margin({ left: 8 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/TagManage' }).catch(() => {
                });
              })
          }
          .width('100%')
          .height(48)
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          .alignItems(VerticalAlign.Top)

          // 储蓄目标/信用额度（对齐安卓 AmountInput：+/− 类型开关 + 计算器按钮）
          Row() {
            Text(this.type === AccountType.CCARD || this.type === AccountType.LIABILITY ? '信用额度' : '储蓄目标')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            // 收入/支出类型开关（对齐安卓 type_switch：textOn="+" textOff="−"）
            Toggle({ type: ToggleType.Switch, isOn: this.criterionPositive })
              .selectedColor($r('app.color.colorIncome'))
              .switchPointColor(Color.White)
              .onChange((isOn: boolean) => {
                this.criterionPositive = isOn;
              })
            Text(this.criterionPositive ? '+' : '−')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.criterionPositive ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
              .margin({ left: 4 })
            TextInput({ placeholder: '0.00', text: this.criterionInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.criterionInput = v;
              })
            Image($r('app.media.ic_calculate'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.textSecondary'))
              .margin({ left: 8 })
              .onClick(() => {
                this.showAmountCalculator('criterion');
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        .borderRadius($r('app.float.native_emphasis_radius'))
        .backgroundColor($r('app.color.surfacePrimary'))
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 12, bottom: 76 })
      // 内容从页面顶部开始（对齐安卓 NestedScrollView 表单贴工具栏下方）
      // Scroll 默认 align 为 Center，内容高度小于视口时会被垂直居中，需显式顶部对齐
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')

    Button() {
        Image($r('app.media.ic_check'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
    }
    .type(ButtonType.Capsule)
    .width(88)
    .height(52)
    .backgroundColor($r('app.color.primaryColor'))
    .stateEffect(true)
    .shadow({ radius: 6, color: '#26000000', offsetY: 3 })
    .accessibilityText('保存账户')
    .onClick(() => {
      this.save();
    })
    .markAnchor({ x: '100%', y: '100%' })
    .position({ x: '92%', y: '94%' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }
}
