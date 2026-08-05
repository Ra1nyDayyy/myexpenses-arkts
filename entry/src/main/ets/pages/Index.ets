import { Account, AccountGrouping, SortDirection } from '../model/Account';
import { Transaction, CrStatus } from '../model/Transaction';
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
    promptAction.showToast({ message: '搜索功能开发中' });
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
          }.tabBar(this.tabBuilder(0, '账户', '🏦'))

          TabContent() {
            this.transactionsTab()
          }.tabBar(this.tabBuilder(1, '交易', '💳'))

          TabContent() {
            this.templatesTab()
          }.tabBar(this.tabBuilder(2, '模板', '📋'))

          TabContent() {
            this.moreTab()
          }.tabBar(this.tabBuilder(3, '更多', '⋯'))
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
  tabBuilder(tabIndex: number, label: string, emoji: string) {
    Column({ space: 2 }) {
      Text(emoji)
        .fontSize(20)
        .opacity(this.selectedTab === tabIndex ? 1 : 0.6)
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

      // 鸿蒙圆形 FAB（点击进入记账编辑）
      if (this.accounts.length > 0) {
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
          this.navigateToExpenseEdit(-1, this.selectedAccountId);
        })
        .gesture(
          LongPressGesture().onAction(() => {
            this.showCreateMenu();
          })
        )
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  templatesTab() {
    Column() {
      this.headerBar('模板')
      this.templateEmpty()
    }
    .width('100%')
    .height('100%')
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
      // 账户名 + 当前余额（对齐安卓 Current balance）
      Column() {
        Row() {
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
        Text(this.balanceText())
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
      icon: '🏦',
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
        this.summaryItem('⊕', '收入', this.sumIncome(), $r('app.color.colorIncome'))
        this.summaryItem('⊖', '支出', this.sumExpense(), $r('app.color.colorExpense'))
        this.summaryItem('⇄', '转帐', this.sumTransfer(), $r('app.color.colorTransfer'))
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.summaryCardBackground'))
  }

  @Builder
  summaryItem(icon: string, label: string, amount: number, color: ResourceColor) {
    Column({ space: 2 }) {
      Text(`${icon} ${this.symbol()}${formatMoney(amount, this.fractionDigits())}`)
        .fontSize(14)
        .fontColor(color)
        .fontWeight(FontWeight.Medium)
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
      icon: '📋',
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
        this.menuRow('AI 助手', '🤖', () => {
          this.navigateToAi();
        })
      }
      ListItem() {
        this.menuRow('类别', '🏷️', () => {
          router.pushUrl({ url: 'pages/CategoryManage' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('付款方法', '💳', () => {
          router.pushUrl({ url: 'pages/MethodManage' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('标签', '🔖', () => {
          router.pushUrl({ url: 'pages/TagManage' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('资产负债表', '📊', () => {
          router.pushUrl({ url: 'pages/BalanceSheet' }).catch(() => {
          });
        })
      }
      ListItem() {
        this.menuRow('设置', '⚙️', () => {
          router.pushUrl({ url: 'pages/Settings' }).catch(() => {
          });
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  menuRow(label: string, icon: string, onClick: () => void) {
    Row() {
      Text(icon)
        .fontSize(18)
        .margin({ right: 12 })
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
}
