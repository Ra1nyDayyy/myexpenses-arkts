import { Account, AccountGrouping, SortDirection } from '../model/Account';
import { Transaction, CrStatus } from '../model/Transaction';
import { Template } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { AccountListPage } from '../components/AccountListPage';
import { TransactionListPage } from '../components/TransactionListPage';
import { EmptyState } from '../components/EmptyState';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { router, promptAction } from '@kit.ArkUI';

/**
 * 主界面（V2）：对应 Android MyExpensesV2 + MainScreen
 * 底部 TabBar：账户 / 交易 / 更多
 */
@Entry
@Component
struct Index {
  @State accounts: Account[] = [];
  @State selectedTab: number = 0; // 0 账户 1 交易 2 更多
  @State loading: boolean = true;
  @State grouping: AccountGrouping = AccountGrouping.NONE;
  @State showEquivalent: boolean = false;
  @State expandedAccountId: number = -1;
  @State selectedAccountId: number = -1;
  @State isSelectionMode: boolean = false;
  @State selectedTransactionIds: number[] = [];
  @State templates: Template[] = [];

  private repository: Repository = Repository.getInstance();
  private settings: SettingsService = SettingsService.getInstance();

  aboutToAppear(): void {
    this.loadData();
  }

  onPageShow(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      const grouping = await this.settings.getNumber(PREF_KEY.GROUPING, AccountGrouping.NONE);
      const showEquivalent = await this.settings.getBoolean(PREF_KEY.SHOW_EQUIVALENT, false);
      this.grouping = grouping as AccountGrouping;
      this.showEquivalent = showEquivalent;
      this.accounts = await this.repository.getAccounts();
      this.templates = await this.repository.getTemplates();
      if (this.accounts.length > 0) {
        if (this.selectedAccountId < 0) {
          this.selectedAccountId = this.accounts[0].id;
        }
        // 账户存在时默认交易页需要账户，选中账户校验
        const exists = this.accounts.some((a: Account) => a.id === this.selectedAccountId);
        if (!exists) {
          this.selectedAccountId = this.accounts[0].id;
        }
      } else {
        this.selectedAccountId = -1;
      }
      // 刷新交易缓存
      if (this.selectedAccountId > 0) {
        await this.refreshTransactions(this.selectedAccountId);
      }
    } catch (e) {
      console.error('加载账户失败: ' + JSON.stringify(e));
    }
    this.loading = false;
  }

  private currentAccount(): Account | null {
    return this.accounts.find((a: Account) => a.id === this.selectedAccountId) || null;
  }

  private symbol(): string {
    const acc = this.currentAccount();
    return acc ? currencyByCode(acc.currency).symbol : '¥';
  }

  private fractionDigits(): number {
    const acc = this.currentAccount();
    return acc ? currencyByCode(acc.currency).fractionDigits : 2;
  }

  private transactionCache: Map<number, Transaction[]> = new Map();

  private transactionsFor(acc: Account): Transaction[] {
    return this.transactionCache.get(acc.id) || [];
  }

  private transactionsForCurrent(): Transaction[] {
    return this.transactionCache.get(this.selectedAccountId) || [];
  }

  private async refreshTransactions(accountId: number): Promise<void> {
    const list = await this.repository.getTransactions(accountId);
    this.transactionCache.set(accountId, list);
    const tmp = this.accounts;
    this.accounts = [];
    this.accounts = tmp;
  }

  private groupingLabel(): string {
    switch (this.grouping) {
      case AccountGrouping.NONE:
        return '不分组';
      case AccountGrouping.TYPE:
        return '按类型';
      case AccountGrouping.CURRENCY:
        return '按货币';
      case AccountGrouping.FLAG:
        return '按标记';
      default:
        return '不分组';
    }
  }

  private cycleGrouping(): void {
    const next = (this.grouping + 1) % 4;
    this.grouping = next as AccountGrouping;
    this.settings.setNumber(PREF_KEY.GROUPING, next);
  }

  private async toggleStatus(id: number): Promise<void> {
    const list = this.transactionCache.get(this.selectedAccountId) || [];
    const t = list.find((item: Transaction) => item.id === id);
    if (!t) {
      return;
    }
    const next = t.crStatus === CrStatus.CLEARED ? CrStatus.UNRECONCILED : CrStatus.CLEARED;
    await this.repository.setTransactionCrStatus(id, next);
    await this.refreshTransactions(this.selectedAccountId);
    await this.loadData();
  }

  private navigateToAccountEdit(id: number): void {
    router.pushUrl({ url: 'pages/AccountEdit', params: { id: id } }).catch(() => {
    });
  }

  private navigateToExpenseEdit(id: number, accountId: number): void {
    router.pushUrl({ url: 'pages/ExpenseEdit', params: { id: id, accountId: accountId } }).catch(() => {
    });
  }

  private navigateToAi(): void {
    router.pushUrl({ url: 'pages/AiAssistant' }).catch(() => {
    });
  }

  private navigateToSearch(): void {
    promptAction.showToast({ message: $r('app.string.toast_search_developing') });
  }

  /**
   * 长按 FAB 弹出新建菜单（支出/收入/转账）
   */
  private showCreateMenu(): void {
    const options: ActionSheetOptions = {
      title: '新建交易',
      message: '选择交易类型',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: [
        {
          title: '支出',
          action: () => {
            this.navigateToExpenseEdit(-1, this.selectedAccountId);
          }
        },
        {
          title: '收入',
          action: () => {
            this.navigateToExpenseEdit(-1, this.selectedAccountId);
          }
        },
        {
          title: '转账',
          action: () => {
            this.navigateToExpenseEdit(-1, this.selectedAccountId);
          }
        }
      ]
    };
    this.getUIContext().showActionSheet(options);
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 原生 Tabs：底部 TabBar（鸿蒙原生样式，含选中态动画与深浅色适配）
        Tabs({ barPosition: BarPosition.End }) {
          TabContent() {
            this.accountsTab()
          }.tabBar(this.tabBuilder(0, '账户', $r('app.media.ic_tab_account')))

          TabContent() {
            this.transactionsTab()
          }.tabBar(this.tabBuilder(1, '交易', $r('app.media.ic_tab_transaction')))

          TabContent() {
            this.templatesTab()
          }.tabBar(this.tabBuilder(2, '模板', $r('app.media.ic_tab_template')))

          TabContent() {
            this.moreTab()
          }.tabBar(this.tabBuilder(3, '更多', $r('app.media.ic_tab_more')))
        }
        .width('100%')
        .layoutWeight(1)
        .barHeight(64)
        .animationDuration(200)
        .scrollable(false)
        .onChange((index: number) => {
          this.selectedTab = index;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  tabBuilder(tabIndex: number, label: string, icon: Resource) {
    Column({ space: 2 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.selectedTab === tabIndex ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
      Text(label)
        .fontSize(11)
        .fontColor(this.selectedTab === tabIndex ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
        .fontWeight(this.selectedTab === tabIndex ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  accountsTab() {
    Stack() {
      Column() {
        this.headerBar('账户')
        if (this.accounts.length === 0) {
          this.emptyState()
        } else {
          AccountListPage({
            accounts: this.accounts,
            grouping: this.grouping,
            selectedAccountId: this.selectedAccountId,
            showEquivalent: this.showEquivalent,
            onReorder: (from: number, to: number) => {
              this.reorderAccounts(from, to);
            },
            onSelect: (id: number) => {
              this.selectedAccountId = id;
              this.selectedTab = 1;
              this.refreshTransactions(id);
            },
            onEdit: (id: number) => {
              this.navigateToAccountEdit(id);
            },
            onDelete: (id: number) => {
              this.deleteAccount(id);
            },
            onToggleSealed: (id: number) => {
              this.toggleSealed(id);
            },
            onToggleExclude: (id: number) => {
              this.toggleExclude(id);
            },
            onCreateAccount: () => {
              this.navigateToAccountEdit(-1);
            }
          })
        }
      }
      .width('100%')
      .height('100%')

    }
    .width('100%')
    .height('100%')
  }

  @Builder
  transactionsTab() {
    Stack() {
      Column() {
        this.transactionHeader()
        // 汇总卡片（对齐安卓 AccountsScreen 汇总区）
        if (this.accounts.length > 0) {
          this.summaryCard()
        }
        if (this.accounts.length === 0) {
          this.emptyState()
        } else {
          TransactionListPage({
            account: this.currentAccount() || new Account(),
            transactions: this.transactionsForCurrent(),
            grouping: 3,
            selectionMode: this.isSelectionMode,
            selectedIds: this.selectedTransactionIds,
            onToggleStatus: (id: number) => {
              this.toggleStatus(id);
            },
            onClickTransaction: (id: number) => {
              if (this.isSelectionMode) {
                this.toggleSelect(id);
              } else {
                this.navigateToExpenseEdit(id, this.selectedAccountId);
              }
            },
            onCreateTransaction: () => {
              this.navigateToExpenseEdit(-1, this.selectedAccountId);
            }
          })
        }
      }
      .width('100%')
      .height('100%')

      // 交易 FAB（对齐安卓 Material3 圆角矩形 + 展开菜单）
      if (this.accounts.length > 0) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_expense'))
            .width(22)
            .height(22)
            .fillColor(Color.White)
          Divider()
            .vertical(true)
            .color('#66FFFFFF')
            .height(22)
          Image($r('app.media.ic_income'))
            .width(22)
            .height(22)
            .fillColor(Color.White)
        }
        .width(96)
        .height(52)
        .borderRadius(26)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.primaryColor'))
        .shadow({ radius: 8, color: '#40000000', offsetY: 4 })
        .position({ x: '70%', y: '78%' })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.showCreateMenu();
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  templatesTab() {
    Stack() {
      Column() {
        this.headerBar('模板')
        if (this.templates.length === 0) {
          EmptyState({
            iconResource: $r('app.media.ic_empty_template'),
            title: '暂无模板',
            subtitle: '常用交易可以保存为模板，方便重复记账',
            actionText: '新建模板',
            onAction: () => {
              this.createTemplate();
            }
          })
          .width('100%')
          .layoutWeight(1)
        } else {
          List({ space: 0 }) {
            ForEach(this.templates, (tpl: Template) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(tpl.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.textPrimary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${tpl.categoryPath || '未分类'} · ${this.templateAmount(tpl)}${tpl.recurrence > 0 ? ' · ' + this.recurrenceLabel(tpl.recurrence) : ''}`)
                      .fontSize(12)
                      .fontColor($r('app.color.textSecondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 12 })

                  // 生成交易（按周期计划生成固定收支）
                  if (tpl.recurrence > 0) {
                    Button('生成')
                      .height(28)
                      .fontSize(12)
                      .backgroundColor($r('app.color.primaryColor'))
                      .fontColor(Color.White)
                      .margin({ right: 8 })
                      .onClick(() => {
                        this.generatePlan(tpl);
                      })
                  }

                  Button('用于交易')
                    .height(28)
                    .fontSize(12)
                    .backgroundColor($r('app.color.primaryContainer'))
                    .fontColor($r('app.color.primaryColor'))
                    .onClick(() => {
                      this.useTemplate(tpl);
                    })

                  // 设置周期（长按模板行弹出）
                  Image($r('sys.media.ohos_ic_public_edit'))
                    .width(16)
                    .height(16)
                    .opacity(0.6)
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.setRecurrence(tpl);
                    })

                  Image($r('sys.media.ohos_ic_public_close'))
                    .width(16)
                    .height(16)
                    .opacity(0.6)
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.deleteTemplate(tpl);
                    })
                }
                .width('100%')
                .height(56)
                .padding({ left: 16, right: 16 })
                .backgroundColor($r('app.color.cardBackgroundColor'))
                .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
              }
            }, (tpl: Template) => `tpl_${tpl.id}_${tpl.recurrence}_${tpl.advanceDays}_${tpl.autoExecute}`)
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')

      // 新建模板 FAB
      Stack() {
        Text('+')
          .fontSize(28)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.primaryColor'))
      .shadow({ radius: 8, color: '#40000000', offsetY: 4 })
      .position({ x: '76%', y: '78%' })
      .onClick(() => {
        this.createTemplate();
      })
    }
    .width('100%')
    .height('100%')
  }

  private templateAmount(tpl: Template): string {
    const symbol = currencyByCode(tpl.currency).symbol;
    const prefix = tpl.isIncome ? '+' : '';
    return `${prefix}${symbol}${formatMoney(Math.abs(tpl.amount), currencyByCode(tpl.currency).fractionDigits)}`;
  }

  /**
   * 新建模板：用当前账户创建一个简单模板
   */
  private async createTemplate(): Promise<void> {
    const acc = this.currentAccount() || (this.accounts.length > 0 ? this.accounts[0] : null);
    if (!acc) {
      promptAction.showToast({ message: $r('app.string.toast_create_account_first') });
      return;
    }
    const tpl = new Template();
    tpl.title = '新模板';
    tpl.accountId = acc.id;
    tpl.currency = acc.currency;
    await this.repository.insertTemplate(tpl);
    await this.loadData();
  }

  /**
   * 用于交易：模板实例化为交易并进入编辑
   */
  private async useTemplate(tpl: Template): Promise<void> {
    const txId = await this.repository.instantiateTemplate(tpl);
    if (txId > 0) {
      promptAction.showToast({ message: $r('app.string.toast_tx_generated') });
      this.navigateToExpenseEdit(txId, tpl.accountId);
    }
  }

  private async deleteTemplate(tpl: Template): Promise<void> {
    await this.repository.deleteTemplate(tpl.id);
    await this.loadData();
  }

  private recurrenceLabel(recurrence: number): string {
    const labels: string[] = ['不重复', '仅一次', '每天', '每周', '每月', '每月最后一天', '每年'];
    return recurrence >= 0 && recurrence < labels.length ? labels[recurrence] : '';
  }

  /**
   * 生成计划交易（每月固定收支）
   */
  private async generatePlan(tpl: Template): Promise<void> {
    const txId = await this.repository.generatePlanTransaction(tpl);
    if (txId > 0) {
      promptAction.showToast({ message: `已按「${this.recurrenceLabel(tpl.recurrence)}」生成交易` });
    } else {
      promptAction.showToast({ message: $r('app.string.toast_no_plan_due') });
    }
    await this.loadData();
  }

  /**
   * 设置模板周期（弹出选择）
   */
  private setRecurrence(tpl: Template): void {
    const options: ActionSheetOptions = {
      title: '设置周期',
      message: `${tpl.title} 的重复规则`,
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: [
        { title: '不重复', action: () => this.applyRecurrence(tpl, 0) },
        { title: '仅一次', action: () => this.applyRecurrence(tpl, 1) },
        { title: '每天', action: () => this.applyRecurrence(tpl, 2) },
        { title: '每周', action: () => this.applyRecurrence(tpl, 3) },
        { title: '每月', action: () => this.applyRecurrence(tpl, 4) },
        { title: '每月最后一天', action: () => this.applyRecurrence(tpl, 5) },
        { title: '每年', action: () => this.applyRecurrence(tpl, 6) },
        { title: '设置下次执行日期', action: () => this.pickPlanStartDate(tpl) },
        { title: tpl.autoExecute ? '自动执行：开（点击关闭）' : '自动执行：关（点击开启）', action: () => this.toggleAutoExecute(tpl) },
        { title: `提前执行：${tpl.advanceDays} 天`, action: () => this.setAdvanceDays(tpl) }
      ]
    };
    this.getUIContext().showActionSheet(options);
  }

  /**
   * 切换计划自动执行
   */
  private async toggleAutoExecute(tpl: Template): Promise<void> {
    tpl.autoExecute = !tpl.autoExecute;
    await this.repository.updateTemplate(tpl);
    await this.loadData();
  }

  /**
   * 设置提前执行天数（0-30）
   */
  private setAdvanceDays(tpl: Template): void {
    const options: ActionSheetOptions = {
      title: '提前执行天数',
      message: `当前：${tpl.advanceDays} 天（0-30）`,
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: [
        { title: '0 天（不提前）', action: () => this.applyAdvanceDays(tpl, 0) },
        { title: '3 天', action: () => this.applyAdvanceDays(tpl, 3) },
        { title: '7 天', action: () => this.applyAdvanceDays(tpl, 7) },
        { title: '14 天', action: () => this.applyAdvanceDays(tpl, 14) },
        { title: '30 天', action: () => this.applyAdvanceDays(tpl, 30) }
      ]
    };
    this.getUIContext().showActionSheet(options);
  }

  private async applyAdvanceDays(tpl: Template, days: number): Promise<void> {
    tpl.advanceDays = days;
    await this.repository.updateTemplate(tpl);
    await this.loadData();
  }

  /**
   * 选择计划下次执行日期（对齐安卓 DateButton）
   */
  private pickPlanStartDate(tpl: Template): void {
    const current = tpl.dtStart > 0 ? new Date(tpl.dtStart * 1000) : new Date();
    const pickerOptions: DatePickerDialogOptions = {
      start: new Date(current.getFullYear() - 10, 0, 1),
      end: new Date(current.getFullYear() + 10, 11, 31),
      selected: current,
      onDateAccept: (value: Date) => {
        tpl.dtStart = Math.floor(value.getTime() / 1000 / 86400) * 86400;
        if (tpl.recurrence <= 0) {
          tpl.recurrence = 4; // 默认每月
        }
        this.applyRecurrence(tpl, tpl.recurrence);
      }
    };
    this.getUIContext().showDatePickerDialog(pickerOptions);
  }

  private async applyRecurrence(tpl: Template, recurrence: number): Promise<void> {
    tpl.recurrence = recurrence;
    if (tpl.dtStart <= 0) {
      tpl.dtStart = Math.floor(Date.now() / 1000);
    }
    await this.repository.updateTemplate(tpl);
    await this.loadData();
  }

  @Builder
  moreTab() {
    Column() {
      this.headerBar('更多')
      this.moreMenu()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  headerBar(title: string) {
    Row() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))
      Blank()
      // 搜索图标（账户页对齐安卓）
      if (this.selectedTab === 0) {
        Image($r('sys.media.ohos_ic_public_search_filled'))
          .width(22)
          .height(22)
          .margin({ right: 16 })
          .onClick(() => {
            this.navigateToSearch();
          })
      }
      Image($r('sys.media.ohos_ic_public_add'))
        .width(22)
        .height(22)
        .onClick(() => {
          if (this.selectedTab === 0) {
            this.navigateToAccountEdit(-1);
          }
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  transactionHeader() {
    Row() {
      // 账户名 + 当前余额（对齐安卓 Current balance + 颜色圆点）
      Column() {
        Row() {
          // 账户颜色圆点（对齐安卓青色圆点）
          Circle()
            .width(12)
            .height(12)
            .fill(this.accountColor())
            .margin({ right: 6 })
          Text(this.currentAccount()?.label || '交易')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(14)
            .height(14)
            .opacity(0.4)
            .margin({ left: 4 })
        }
        Text(`当前余额 ${this.balanceText()}`)
          .fontSize(13)
          .fontColor(this.balanceColor())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 搜索（对齐安卓 Search）
      Image($r('sys.media.ohos_ic_public_search_filled'))
        .width(22)
        .height(22)
        .margin({ right: 12 })
        .onClick(() => {
          this.navigateToSearch();
        })

      // 分组切换
      Button() {
        Text(this.groupingLabel())
          .fontSize(12)
          .fontColor($r('app.color.primaryColor'))
      }
      .height(30)
      .backgroundColor($r('app.color.primaryContainer'))
      .borderRadius(4)
      .margin({ right: 8 })
      .onClick(() => {
        this.cycleGrouping();
      })

      // AI 助手
      Image($r('sys.media.ohos_ic_public_scan'))
        .width(22)
        .height(22)
        .margin({ right: 8 })
        .onClick(() => {
          this.navigateToAi();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  emptyState() {
    EmptyState({
      iconResource: $r('app.media.ic_empty_account'),
      title: '没有账户。',
      subtitle: '创建第一个账户开始记账',
      actionText: '新建账户',
      onAction: () => {
        this.navigateToAccountEdit(-1);
      }
    })
    .width('100%')
    .height('100%')
  }

  /**
   * 汇总卡片：对齐安卓 Total/收入/支出/转账
   */
  @Builder
  summaryCard() {
    Column() {
      Row() {
        Text('Total')
          .fontSize(13)
          .fontColor($r('app.color.textSecondary'))
        Blank()
        Text(`${this.symbol()}${formatMoney(this.currentBalance(), this.fractionDigits())}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.balanceColor())
      }
      .width('100%')

      Row() {
        this.summaryItem($r('app.media.ic_income'), '收入', this.sumIncome(), $r('app.color.colorIncome'))
        this.summaryItem($r('app.media.ic_expense'), '支出', this.sumExpense(), $r('app.color.colorExpense'))
        this.summaryItem($r('app.media.ic_transfer'), '转帐', this.sumTransfer(), $r('app.color.colorTransfer'))
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.summaryCardBackground'))
  }

  @Builder
  summaryItem(icon: Resource, label: string, amount: number, color: ResourceColor) {
    Column({ space: 2 }) {
      Row({ space: 4 }) {
        Image(icon)
          .width(14)
          .height(14)
          .fillColor(color)
        Text(`${this.symbol()}${formatMoney(amount, this.fractionDigits())}`)
          .fontSize(14)
          .fontColor(color)
          .fontWeight(FontWeight.Medium)
      }
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.textSecondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  templateEmpty() {
    EmptyState({
      iconResource: $r('app.media.ic_empty_template'),
      title: '暂无模板',
      subtitle: '常用交易可以保存为模板'
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  moreMenu() {
    List({ space: 0 }) {
      ListItem() {
        this.menuRow('AI 助手', $r('app.media.ic_ai_robot'), () => {
          this.navigateToAi();
        })
      }
      ListItem() {
        this.menuRow('类别', $r('app.media.ic_category'), () => {
          router.pushUrl({ url: 'pages/CategoryManage' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('付款方法', $r('app.media.ic_method'), () => {
          router.pushUrl({ url: 'pages/MethodManage' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('标签', $r('app.media.ic_tag'), () => {
          router.pushUrl({ url: 'pages/TagManage' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('资产负债表', $r('app.media.ic_balance'), () => {
          router.pushUrl({ url: 'pages/BalanceSheet' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('设置', $r('app.media.ic_settings'), () => {
          router.pushUrl({ url: 'pages/Settings' }).catch(() => {
          });
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  menuRow(label: string, icon: Resource, onClick: () => void) {
    Row() {
      Image(icon)
        .width(22)
        .height(22)
        .margin({ right: 12 })
        .fillColor($r('app.color.textSecondary'))
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .layoutWeight(1)
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .opacity(0.4)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
    .onClick(() => {
      onClick();
    })
  }

  private balanceText(): string {
    const acc = this.currentAccount();
    if (!acc) {
      return '';
    }
    const symbol = currencyByCode(acc.currency).symbol;
    return `${symbol}${formatMoney(acc.currentBalance, currencyByCode(acc.currency).fractionDigits)}`;
  }

  private currentBalance(): number {
    const acc = this.currentAccount();
    return acc ? acc.currentBalance : 0;
  }

  private accountColor(): ResourceColor {
    const acc = this.currentAccount();
    if (acc && acc.color) {
      const rgb = acc.color & 0xFFFFFF;
      return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
    }
    return $r('app.color.defaultAccountColor');
  }

  private sumIncome(): number {
    const acc = this.currentAccount();
    return acc ? acc.sumIncome : 0;
  }

  private sumExpense(): number {
    const acc = this.currentAccount();
    return acc ? acc.sumExpense : 0;
  }

  private sumTransfer(): number {
    const acc = this.currentAccount();
    return acc ? acc.sumTransfer : 0;
  }

  private balanceColor(): ResourceColor {
    const acc = this.currentAccount();
    if (!acc) {
      return $r('app.color.textTertiary');
    }
    if (acc.currentBalance > 0) {
      return $r('app.color.colorIncome');
    }
    if (acc.currentBalance < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  private toggleSelect(id: number): void {
    const idx = this.selectedTransactionIds.indexOf(id);
    if (idx >= 0) {
      this.selectedTransactionIds.splice(idx, 1);
      this.selectedTransactionIds = [...this.selectedTransactionIds];
    } else {
      this.selectedTransactionIds = [...this.selectedTransactionIds, id];
    }
  }

  private async deleteAccount(id: number): Promise<void> {
    await this.repository.deleteAccount(id);
    if (this.selectedAccountId === id) {
      this.selectedAccountId = -1;
    }
    await this.loadData();
  }

  private async toggleSealed(id: number): Promise<void> {
    const acc = this.accounts.find((a: Account) => a.id === id);
    if (!acc) {
      return;
    }
    await this.repository.setAccountSealed(id, !acc.sealed);
    await this.loadData();
  }

  private async toggleExclude(id: number): Promise<void> {
    const acc = this.accounts.find((a: Account) => a.id === id);
    if (!acc) {
      return;
    }
    await this.repository.setAccountExcludeFromTotals(id, !acc.excludeFromTotals);
    await this.loadData();
  }

  /**
   * 账户拖拽排序（对齐安卓 ItemTouchHelper）
   * 重排 accounts 数组，触发 UI 刷新
   */
  private reorderAccounts(from: number, to: number): void {
    if (from < 0 || to < 0 || from >= this.accounts.length || to >= this.accounts.length || from === to) {
      return;
    }
    const item = this.accounts.splice(from, 1)[0];
    this.accounts.splice(to, 0, item);
    // 触发状态刷新
    this.accounts = [...this.accounts];
  }
}
