import { Account, AccountGrouping, SortDirection, AccountType } from '../model/Account';
import { Transaction, CrStatus } from '../model/Transaction';
import { Template, Tag } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { SettingsService, PREF_KEY } from '../database/SettingsService';
import { AccountListPage } from '../components/AccountListPage';
import { TransactionListPage } from '../components/TransactionListPage';
import { TransactionDetailDialog } from '../components/TransactionDetailDialog';
import { EmptyState } from '../components/EmptyState';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { BudgetManage } from './BudgetManage';
import { DebtManage } from './DebtManage';
import { BalanceSheetView } from './BalanceSheet';
import { SortDialog } from '../components/SortDialog';
import { AccountDetailDialog } from '../components/AccountDetailDialog';

/**
 * 主界面（V2）：对应 Android MyExpensesV2 + MainScreen
 * 底部 TabBar：账户 / 交易 / 更多
 */
@Entry
@Component
struct Index {
  @State accounts: Account[] = [];
  @State selectedTab: number = 0; // 0 账户 1 交易 2 更多
  /** 账户 Tab 内视图：0=账户列表，1=资产负债表（对齐安卓 AccountsScreenTab，点击左上角标题下拉切换） */
  @State accountView: number = 0;
  /** 资产负债表打印指令计数：headerBar 点击打印图标时递增，触发 BalanceSheetView 导出 PDF */
  @State bsPrintTick: number = 0;

  /** 资产负债表显示隐藏账户开关（对齐安卓 BalanceSheetOptions） */
  @State bsShowHidden: boolean = false;
  /** 资产负债表显示零余额账户开关（对齐安卓 BalanceSheetOptions） */
  @State bsShowZero: boolean = false;
  /** 资产负债表显示图表开关（对齐安卓 BalanceSheetOptions） */
  @State bsShowChart: boolean = false;
  /** 账户页 FAB 展开菜单（对齐安卓 FloatingActionButtonMenu：新建账户/新建资产组合） */
  @State accountFabExpanded: boolean = false;
  /** 账户排序方式（对齐安卓 Sort.accountSort：LABEL/USAGES/LAST_USED/CUSTOM） */
  @State accountSortBy: string = 'label';
  /** 优先标记顺序（对齐安卓 SORT_ACCOUNT_LIST_BY_FLAG_FIRST） */
  @State sortByFlagFirst: boolean = false;
  /** 排序弹窗当前选中排序（临时，确定时保存） */
  @State sortPickerSelection: string = 'label';
  /** 排序弹窗当前优先标记顺序（临时） */
  @State sortPickerFlagFirst: boolean = false;

  @State loading: boolean = true;
  @State grouping: AccountGrouping = AccountGrouping.NONE;
  @State showEquivalent: boolean = false;
  @State expandedAccountId: number = -1;
  @State selectedAccountId: number = -1;
  // 交易页账户类型过滤器：-1 = 显示全部，否则为 AccountType 值（仅聚合视图生效，对齐安卓 AccountFilterMenu）
  @State activeFilterType: number = -1;
  @State isSelectionMode: boolean = false;
  @State selectedTransactionIds: number[] = [];
  @State templates: Template[] = [];
  /** 模板筛选：-1=全部，0=不重复，2=每天，3=每周，4=每月，6=每年（对齐安卓模板计划筛选） */
  @State templateFilter: number = -1;
  @State tags: Tag[] = [];
  // 当前交易列表（响应式数据源：切换账户时整体重新赋值触发列表重渲染）
  @State currentTransactions: Transaction[] = [];
  // 汇总卡片（对齐安卓 Total/收入/支出/转账）：切换账户时由 refreshTransactions 同步更新
  @State summaryIncome: number = 0;
  @State summaryExpense: number = 0;
  @State summaryTransfer: number = 0;
  // 交易页 FAB（对齐安卓 MyExpensesV2 FloatingActionButtonMenu）
  @State fabExpanded: boolean = false; // 展开菜单
  @State lastAction: number = -1; // 记住的上次操作：-1 支出 / 1 收入 / 2 转账


  private repository: Repository = Repository.getInstance();
  private settings: SettingsService = SettingsService.getInstance();
  // P0-3：根页面 Navigation 的路径栈，二级页面通过 NavDestination 挂载
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.loadData();
  }

  onPageShow(): void {
    // 资产负债表账户行点击后通过 AppStorage 传目标账户：返回时切换到该账户交易页（对齐安卓 onNavigate）
    const target = AppStorage.get<number>('balanceSheetTargetAccountId');
    if (target !== undefined && target !== null && target > 0) {
      AppStorage.delete('balanceSheetTargetAccountId');
      this.selectedAccountId = target;
      this.activeFilterType = -1;
      this.selectedTab = 1;
    }
    this.loadData();
  }

  async loadData(): Promise<void> {
    // 仅首次加载（accounts 为空）显示全屏 loading；
    // 后续刷新保持界面，避免 Tabs 卸载重建导致子组件状态（如账户行展开 expandedId）丢失
    if (this.accounts.length === 0) {
      this.loading = true;
    }
    try {
      const grouping = await this.settings.getNumber(PREF_KEY.GROUPING, AccountGrouping.TYPE);
      const showEquivalent = await this.settings.getBoolean(PREF_KEY.SHOW_EQUIVALENT, false);
      const savedSort = await this.settings.getString(PREF_KEY.SORT_BY, 'label');
      const flagFirst = await this.settings.getBoolean(PREF_KEY.SORT_ACCOUNT_LIST_BY_FLAG_FIRST, false);
      this.grouping = grouping as AccountGrouping;
      this.showEquivalent = showEquivalent;
      this.accountSortBy = savedSort;
      this.sortByFlagFirst = flagFirst;
      this.lastAction = await this.settings.getNumber(PREF_KEY.LAST_ACTION, -1);
      this.accounts = await this.repository.getAccounts();
      this.accounts = this.sortAccounts(this.accounts);
      this.templates = await this.repository.getTemplates();
      this.tags = await this.repository.getTags();
      if (this.accounts.length > 0) {
        if (this.selectedAccountId < 0) {
          this.selectedAccountId = this.accounts[0].id;
        }
        // 聚合模式（0）保持；否则校验选中账户存在
        if (this.selectedAccountId !== 0) {
          const exists = this.accounts.some((a: Account) => a.id === this.selectedAccountId);
          if (!exists) {
            this.selectedAccountId = this.accounts[0].id;
          }
        }
      } else {
        this.selectedAccountId = -1;
      }
      // 刷新交易缓存
      if (this.selectedAccountId > 0) {
        await this.refreshTransactions(this.selectedAccountId);
      } else if (this.selectedAccountId === 0) {
        await this.refreshTransactions(0);
      }
    } catch (e) {
      console.error('加载账户失败: ' + JSON.stringify(e));
    }
    this.loading = false;
  }

  private currentAccount(): Account | null {
    if (this.selectedAccountId === 0) {
      // 聚合模式（全部账户累计）：无单一账户
      return null;
    }
    return this.accounts.find((a: Account) => a.id === this.selectedAccountId) || null;
  }

  /**
   * 是否聚合模式（selectedAccountId = 0）：对应安卓 selectAccount(0) 的聚合账户
   */
  private isAggregate(): boolean {
    return this.selectedAccountId === 0;
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

  // 关闭/计入总数切换防抖集合：避免异步处理期间重复点击造成来回切换
  private sealedBusy: Set<number> = new Set<number>();
  private excludeBusy: Set<number> = new Set<number>();

  private transactionsFor(acc: Account): Transaction[] {
    return this.transactionCache.get(acc.id) || [];
  }


  private async refreshTransactions(accountId: number): Promise<void> {
    // 聚合模式（accountId = 0）：加载全部账户交易（对齐安卓 selectAccount(0) 聚合视图）
    const list = accountId === 0
      ? await this.repository.getAllTransactions()
      : await this.repository.getTransactions(accountId);

    this.transactionCache.set(accountId, list);
    // 刷新的是当前选中账户时，同步更新 @State 触发 UI 重渲染
    if (accountId === this.selectedAccountId) {
      this.currentTransactions = this.applyAccountFilter(list);
      this.recalcSummaries(this.currentTransactions);
    }
  }

  /**
   * 账户类型过滤（对齐安卓 AccountFilterMenu）：
   * 仅聚合视图（selectedAccountId = 0）且设置了 activeFilterType 时按账户类型筛选交易；
   * 单账户视图 / 显示全部时原样返回
   */
  private applyAccountFilter(list: Transaction[]): Transaction[] {
    if (!this.isAggregate() || this.activeFilterType < 0) {
      return list;
    }
    const filtered: Transaction[] = [];
    for (const t of list) {
      const acc = this.accounts.find((a: Account) => a.id === t.accountId);
      if (acc && acc.type === this.activeFilterType) {
        filtered.push(t);
      }
    }
    return filtered;
  }

  /**
   * 当前实际存在的账户类型（去重排序）：对齐安卓 availableGroupFilters 动态生成菜单选项
   */
  private availableAccountTypes(): number[] {
    const types: number[] = [];
    for (const acc of this.accounts) {
      if (types.indexOf(acc.type) === -1) {
        types.push(acc.type);
      }
    }
    return types.sort((a, b) => a - b);
  }

  /**

   * 账户过滤器下拉菜单项（对齐安卓 AccountFilterMenu）：bindMenu 在过滤器图标下方弹出，
   * 显示全部 + 各账户类型（当前选中项带 ✓）
   */
  private accountFilterMenuItems(): Array<MenuElement> {
    const items: Array<MenuElement> = [];
    items.push({
      value: this.activeFilterType < 0 ? '✓ 显示全部' : '显示全部',
      action: () => this.setAccountFilter(-1)
    } as MenuElement);
    const types = this.availableAccountTypes();
    for (const type of types) {
      const label = Account.typeName(type as AccountType);
      items.push({
        value: this.activeFilterType === type ? `✓ ${label}` : label,
        action: () => this.setAccountFilter(type)
      } as MenuElement);
    }
    return items;
  }

  /**
   * 设置账户类型过滤并刷新交易
   * 对齐安卓 MyExpensesV2ViewModel.setFilter：过滤激活时滑动栏只显示该类型账户；
   * 若当前选中账户不在过滤后的账户列表中，自动切回聚合视图
   */
  private setAccountFilter(type: number): void {
    this.activeFilterType = type;
    // 若当前选中账户不在过滤后的账户列表中（如从某类型账户切换过滤器到另一类型），自动切回聚合视图
    const inList = this.filteredTabAccounts().some((a: Account) => a.id === this.selectedAccountId);
    if (!inList && this.selectedAccountId !== 0) {
      this.selectTransactionAccount(0);
      return;
    }
    if (this.isAggregate()) {
      const cached = this.transactionCache.get(0) || [];
      this.currentTransactions = this.applyAccountFilter(cached);
      this.recalcSummaries(this.currentTransactions);
    }
  }

  /**
   * 汇总卡片计算：对齐安卓 AccountsScreen 的 Total/收入/支出/转账
   */
  private recalcSummaries(list: Transaction[]): void {
    let income = 0;
    let expense = 0;
    let transfer = 0;
    for (let t of list) {
      if (t.isTransfer()) {
        transfer += t.amount;
      }
      if (t.amount > 0) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    this.summaryIncome = income;
    this.summaryExpense = expense;
    this.summaryTransfer = transfer;

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

  private navigateToExpenseEdit(id: number, accountId: number, type: number = -1): void {
    router.pushUrl({ url: 'pages/ExpenseEdit', params: { id: id, accountId: accountId, type: type } }).catch(() => {
    });
  }

  private navigateToAi(): void {
    router.pushUrl({ url: 'pages/AiAssistant' }).catch(() => {
    });
  }

  private navigateToSearch(): void {
    router.pushUrl({ url: 'pages/SearchPage' }).catch(() => {
    });
  }

  /**
   * FAB 主按钮图标：默认/上次操作类型；展开时显示加号并旋转45°（对齐安卓）
   * 类型：-1 支出 / 1 收入 / 2 转账 / 3 拆分 / 4 扫描（对齐安卓 Action.STANDARD_ACTIONS）
   */
  private fabMainIcon(): Resource {
    if (this.fabExpanded) {
      return $r('sys.media.ohos_ic_public_add');
    }
    switch (this.lastAction) {
      case 1:
        return $r('app.media.ic_income');
      case 2:
        return $r('app.media.ic_transfer');
      case 3:
        return $r('app.media.ic_split');
      case 4:
        return $r('sys.media.ohos_ic_public_scan');
      default:
        return $r('app.media.ic_expense');
    }
  }

  /**
   * 从 FAB 创建交易：记录上次操作并跳转编辑页
   * 扫描（4）尚未实现 OCR，提示开发中（对齐安卓 contribFeatureRequested OCR）
   */
  private async createFromFab(type: number): Promise<void> {
    this.fabExpanded = false;
    if (type === 4) {
      promptAction.showToast({ message: $r('app.string.toast_scan_developing') });
      return;
    }
    this.lastAction = type;
    await this.settings.setNumber(PREF_KEY.LAST_ACTION, type);
    this.navigateToExpenseEdit(-1, this.selectedAccountId, type);
  }

  /**
   * FAB 内容色：根据账户颜色亮度返回黑/白（对齐安卓 Color.calculateOnColor）
   */
  private fabOnColor(): ResourceColor {
    const acc = this.currentAccount();
    if (acc && acc.color) {
      const r = (acc.color >> 16) & 0xFF;
      const g = (acc.color >> 8) & 0xFF;
      const b = acc.color & 0xFF;
      const luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      return luminance > 0.5 ? Color.Black : Color.White;
    }
    return Color.White;
  }

  /**
   * FAB 展开菜单项（对齐安卓 FloatingActionButtonMenu Popup 圆形项）
   * 背景色为账户颜色、内容色为高对比黑/白（对齐安卓 containerColor = accountColor）
   */
  @Builder
  fabMenuItem(label: string, icon: Resource, type: number) {
    Row({ space: 8 }) {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor(this.fabOnColor())
      Text(label)
        .fontSize(14)
        .fontColor(this.fabOnColor())
    }
    .height(48)
    .padding({ left: 16, right: 16 })
    .borderRadius(24)
    .backgroundColor(this.accountColor())
    .shadow({ radius: 4, color: '#40000000', offsetY: 2 })
    .onClick(() => {
      this.createFromFab(type);
    })
  }

  /** 账户页 FAB 展开菜单项（对齐安卓 FloatingActionButtonMenu 的 actions） */
  @Builder
  accountFabMenuItem(label: string, icon: Resource, onClick: () => void) {
    Row({ space: 8 }) {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor($r('app.color.textPrimary'))
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.textPrimary'))
    }
    .height(48)
    .padding({ left: 16, right: 16 })
    .borderRadius(24)
    .backgroundColor($r('app.color.cardBackgroundColor'))
    .shadow({ radius: 4, color: '#40000000', offsetY: 2 })
    .onClick(() => {
      this.accountFabExpanded = false;
      onClick();
    })
  }

  build() {
    // P0-3：Navigation 作为根容器承载二级 NavDestination 页面
    // hideTitleBar(true) 关闭 Navigation 自带的默认标题栏占位，避免底部 TabBar 被抬高
    Navigation(this.pathStack) {
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
          // 原生 Tabs：底部 TabBar 贴底（对齐 Android BottomNavigation）
          // 绑定 index 使其受控：程序修改 selectedTab 时（如点击累计行跳转交易页）同步切换页签内容
          Tabs({ barPosition: BarPosition.End, index: this.selectedTab }) {
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
          .barHeight(56)
          .animationDuration(300)
          .scrollable(false)
          .barBackgroundColor($r('app.color.tabBarBackground'))
          .onChange((index: number) => {
            this.selectedTab = index;
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.pageBackground'))
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.pageMap)
  }

  /**
   * P0-3：Navigation 二级页面映射
   * 已迁移为 NavDestination 的页面在此注册；未迁移页面继续走 router
   */
  @Builder
  pageMap(name: string) {
    if (name === 'BudgetManage') {
      BudgetManage()
    } else if (name === 'DebtManage') {
      DebtManage()
    }
  }

  /**
   * 底部 TabBar 单项（对齐 Android BottomNavigation）
   * 选中态：蓝色图标/文字 + 底部蓝色指示线
   */
  @Builder
  tabBuilder(tabIndex: number, label: string, icon: Resource) {
    Stack() {
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

      // 选中指示线（底部蓝色短横线）
      if (this.selectedTab === tabIndex) {
        Row()
          .width(24)
          .height(3)
          .borderRadius(1.5)
          .backgroundColor($r('app.color.primaryColor'))
          .position({ x: '50%', y: 52 })
          .translate({ x: -12 })
      }
    }
    .width('100%')
    .height('100%')
  }


  /**
   * 账户页标题下拉菜单（对齐安卓 AccountsScreenTab：账户 / 资产负债表 同页切换）
   */
  private accountViewMenu(): Array<MenuElement> {
    return [
      {
        value: '账户',
        action: () => {
          this.accountView = 0;
        }
      },
      {
        value: '资产负债表',
        action: () => {
          this.accountView = 1;
        }
      }
    ];
  }

  /** 是否存在隐藏（sealed）账户（对齐安卓 accounts.any { !it.isVisible }） */
  private hasHiddenAccounts(): boolean {
    return this.accounts.some((a: Account) => a.sealed);
  }

  /** 是否存在零余额且计入总数的账户（对齐安卓 accounts.any { it.effectiveBalance == 0L }） */
  private hasZeroAccounts(): boolean {
    return this.accounts.some((a: Account) => a.currentBalance === 0 && !a.excludeFromTotals);
  }

  /**
   * 资产负债表选项下拉菜单（对齐安卓 BalanceSheetOptions TooltipIconMenu）
   * 菜单项：显示隐藏账户 / 显示零余额账户 / 显示图表（带勾选标记）
   */
  private balanceSheetOptionsMenu(): Array<MenuElement> {
    const menu: Array<MenuElement> = [];
    if (this.hasHiddenAccounts()) {
      menu.push({
        value: (this.bsShowHidden ? '✓ ' : '') + '显示隐藏账户',
        action: () => {
          this.bsShowHidden = !this.bsShowHidden;
        }
      } as MenuElement);
    }
    if (this.hasZeroAccounts()) {
      menu.push({
        value: (this.bsShowZero ? '✓ ' : '') + '显示零余额账户',
        action: () => {
          this.bsShowZero = !this.bsShowZero;
        }
      } as MenuElement);
    }
    menu.push({
      value: (this.bsShowChart ? '✓ ' : '') + '显示图表',
      action: () => {
        this.bsShowChart = !this.bsShowChart;
      }
    } as MenuElement);
    return menu;
  }

  @Builder
  accountsTab() {
    Stack() {
      Column() {
        this.headerBar('账户')
        if (this.accountView === 1) {
          // 资产负债表视图（对齐安卓 AccountsScreenTab.BALANCE_SHEET：同一页面内切换）
          BalanceSheetView({
            embedded: true,
            printTick: $bsPrintTick,

            showHidden: $bsShowHidden,
            showZero: $bsShowZero,
            showChart: $bsShowChart,
            onNavigateAccount: (id: number) => {
              this.selectedAccountId = id;
              this.activeFilterType = -1;
              this.selectedTab = 1;
            }
          })
            .width('100%')
            .layoutWeight(1)
        } else if (this.accounts.length === 0) {
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
            onSetFlag: (id: number) => {
              this.setAccountFlag(id);
            },
            onCreateAccount: () => {
              this.navigateToAccountEdit(-1);
            },
            onGrandTotal: () => {
              // 点击累计行：跳转交易页全部账户聚合视图（对齐安卓 navigateToGroup(null)）
              this.selectedAccountId = 0;
              this.activeFilterType = -1;
              this.selectedTab = 1;
              this.refreshTransactions(0);
            },
            onGroupSelected: (type: AccountType) => {
              // 点击分组头箭头：跳转交易页该账户类型聚合视图（对齐安卓 navigateToGroup(filter)）
              this.selectedAccountId = 0;
              this.activeFilterType = type;
              this.selectedTab = 1;
              this.refreshTransactions(0);
            }
          })
        }
      }
      .width('100%')
      .height('100%')

      // 账户页 FAB（对齐安卓 AccountsScreen FloatingActionButtonMenu：银行图标 + 竖线 + 上箭头）
      if (this.accountView === 0) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          // 展开菜单（对齐安卓 Popup：图标+文字，垂直排列，圆角胶囊）
          if (this.accountFabExpanded) {
            Column({ space: 8 }) {
              this.accountFabMenuItem('新建账户', $r('app.media.ic_account_balance'), () => {
                this.navigateToAccountEdit(-1);
              })
              this.accountFabMenuItem('新建资产组合', $r('app.media.ic_portfolio'), () => {
                // 对齐安卓：组合账户为付费功能，未解锁时显示升级提示
                promptAction.showToast({ message: '新建资产组合需升级（开发中）' });
              })
            }
            .alignItems(HorizontalAlign.End)
            .margin({ bottom: 64 })
          }
          // FAB 主体（对齐安卓 Material3 ExtendedFAB：surface 背景 + 高对比内容色）
          Row({ space: 8 }) {
            // 主按钮：点击直接新建账户；展开时图标旋转45°（对齐安卓）
            Image(this.accountFabExpanded ? $r('app.media.ic_add') : $r('app.media.ic_account_balance'))
              .width(22)
              .height(22)
              .fillColor($r('app.color.textPrimary'))
              .rotate({ angle: this.accountFabExpanded ? 45 : 0 })
              .onClick(() => {
                if (this.accountFabExpanded) {
                  this.accountFabExpanded = false;
                } else {
                  this.navigateToAccountEdit(-1);
                }
              })
              .gesture(
                LongPressGesture()
                  .onAction(() => {
                    this.accountFabExpanded = !this.accountFabExpanded;
                  })
              )
            // 竖线 + 上箭头：点击展开菜单（对齐安卓 standard FAB）
            Divider()
              .vertical(true)
              .color($r('app.color.textPrimary'))
              .opacity(0.4)
              .height(22)
            Image($r('sys.media.ohos_ic_public_arrow_up'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.textPrimary'))
              .onClick(() => {
                this.accountFabExpanded = !this.accountFabExpanded;
              })
          }
          .width(96)
          .height(56)
          .borderRadius(28)
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .shadow({ radius: 8, color: '#40000000', offsetY: 4 })
        }
        .markAnchor({ x: '100%', y: '100%' })
        .position({ x: '95%', y: '98%' })
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
        // 账户滑动选择器（对齐安卓 SecondaryScrollableTabRow：累计 + 各账户，可横向滑动）
        if (this.accounts.length > 1) {
          this.accountTabsRow()
        }
        // 汇总卡片（对齐安卓 AccountsScreen 汇总区）
        if (this.accounts.length > 0) {
          this.summaryCard()
        }
        if (this.accounts.length === 0) {
          this.emptyState()
        } else {
          TransactionListPage({
            account: this.currentAccount() || new Account(),
            transactions: this.currentTransactions,
            grouping: 3,
            selectionMode: this.isSelectionMode,
            showAccount: this.isAggregate(),
            selectedIds: this.selectedTransactionIds,
            onToggleStatus: (id: number) => {
              this.toggleStatus(id);
            },
            onClickTransaction: (id: number) => {
              // 选择模式：点击行切换多选；普通模式：由 TransactionRow 的 bindMenu 在行下方弹出操作菜单
              if (this.isSelectionMode) {
                this.toggleSelect(id);
              }
            },
            onMenuAction: (id: number, action: string) => {
              this.handleTransactionMenuAction(id, action);
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
        // 展开菜单时点击外部关闭（半透明遮罩，捕获点击）
        if (this.fabExpanded) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#00000000')
            .onClick(() => {
              this.fabExpanded = false;
            })
        }
        // FAB 主体 + 展开菜单（整体定位在右下角，菜单弹出在 FAB 上方）
        Stack({ alignContent: Alignment.BottomEnd }) {
          // 展开菜单（对齐安卓 Popup：图标+文字，垂直排列，圆角胶囊）
          // 菜单项与安卓 Action.STANDARD_ACTIONS 一致：支出/收入/转账/拆分/扫描
          if (this.fabExpanded) {
            // 菜单项顺序对齐安卓 Action.STANDARD_ACTIONS.reversed()：
            // 扫描/拆分/转账/收入/支出（支出在底部最靠近 FAB）
            Column({ space: 8 }) {
              this.fabMenuItem('扫描', $r('sys.media.ohos_ic_public_scan'), 4)
              this.fabMenuItem('拆分', $r('app.media.ic_split'), 3)
              this.fabMenuItem('转账', $r('app.media.ic_transfer'), 2)
              this.fabMenuItem('收入', $r('app.media.ic_income'), 1)
              this.fabMenuItem('支出', $r('app.media.ic_expense'), -1)
            }
            .alignItems(HorizontalAlign.End)
            .margin({ bottom: 64 })
          }
          // FAB 主体
          if (this.currentAccount()?.sealed === true) {
            // 账户关闭：圆形 FAB + 半透明锁图标（对齐安卓 sealed FloatingActionButton：
            // containerColor=surfaceVariant, contentColor=onSurfaceVariant 38%, 无阴影）
            Row() {
              Image($r('app.media.ic_locked'))
                .width(24)
                .height(24)
                .fillColor('#61000000')
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#E0E0E0')
            .onClick(() => {
              promptAction.showToast({ message: $r('app.string.account_closed') });
            })
          } else {
            Row({ space: 8 }) {
              // 主按钮：点击直接创建默认类型；展开时图标旋转45°
              Image(this.fabMainIcon())
                .width(22)
                .height(22)
                .fillColor(this.fabOnColor())
                .rotate({ angle: this.fabExpanded ? 45 : 0 })
                .onClick(() => {
                  if (this.fabExpanded) {
                    this.fabExpanded = false;
                  } else {
                    this.createFromFab(this.lastAction);
                  }
                })
                .gesture(
                  LongPressGesture()
                    .onAction(() => {
                      this.fabExpanded = !this.fabExpanded;
                    })
                )
              // 竖线 + 上箭头：点击展开菜单（对齐安卓 standard FAB）
              Divider()
                .vertical(true)
                .color(this.fabOnColor())
                .opacity(0.4)
                .height(22)
              Image($r('sys.media.ohos_ic_public_arrow_up'))
                .width(20)
                .height(20)
                .fillColor(this.fabOnColor())
                .onClick(() => {
                  this.fabExpanded = !this.fabExpanded;
                })
            }
            .width(96)
            .height(56)
            .borderRadius(28)
            .padding({ left: 16, right: 16 })
            .backgroundColor(this.accountColor())
            .shadow({ radius: 8, color: '#40000000', offsetY: 4 })
          }
        }
        .markAnchor({ x: '100%', y: '100%' })
        .position({ x: '95%', y: '98%' })
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
              this.navigateToTemplateEdit(-1);
            }
          })
          .width('100%')
          .layoutWeight(1)
        } else {
          // 筛选后模板列表（无匹配时显示空提示）
          if (this.filteredTemplates().length === 0) {
            Column() {
              Text('该筛选条件下暂无模板')
                .fontSize(15)
                .fontColor($r('app.color.textSecondary'))
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            List({ space: 0 }) {
              ForEach(this.filteredTemplates(), (tpl: Template) => {
              ListItem() {
                Row() {
                  // 左侧：模板图标（对齐安卓 Plan ImageView）
                  Image($r('app.media.ic_tab_template'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .fillColor($r('app.color.textSecondary'))
                    .opacity(0.8)

                  // 账户颜色竖条（对齐安卓 colorAccount）
                  Column()
                    .width(4)
                    .height('100%')
                    .backgroundColor(this.templateAccountColor(tpl))
                    .margin({ left: 8, right: 10 })
                    .borderRadius(2)

                  // 中间：标题（加粗，有周期追加后缀）+ 副标题（类别 · 备注 · 收款人）
                  Column() {
                    Text(tpl.title + (tpl.recurrence > 0 ? ` (${this.recurrenceLabel(tpl.recurrence)})` : ''))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.textPrimary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(this.templateSubtitle(tpl))
                      .fontSize(12)
                      .fontColor($r('app.color.textSecondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 12 })

                  // 右侧：金额（收入绿/支出红/转账蓝，对齐安卓 Amount）
                  Text(this.templateAmount(tpl))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.templateAmountColor(tpl))
                    .margin({ left: 8 })
                }
                .width('100%')
                .height(60)
                .padding({ left: 16, right: 16 })
                .backgroundColor($r('app.color.cardBackgroundColor'))
                .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
                .onClick(() => {
                  this.useTemplate(tpl);
                })
                .gesture(LongPressGesture().onAction(() => {
                  this.showTemplateMenu(tpl);
                }))
              }
            }, (tpl: Template) => `tpl_${tpl.id}_${tpl.recurrence}_${tpl.advanceDays}_${tpl.autoExecute}_${tpl.amount}_${tpl.title}`)
          }
          .layoutWeight(1)
          .width('100%')
          }
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
        this.navigateToTemplateEdit(-1);
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
   * 模板金额着色（对齐安卓 template_row Amount：转账蓝/收入绿/支出红）
   */
  private templateAmountColor(tpl: Template): ResourceColor {
    if (tpl.isTransfer()) {
      return $r('app.color.colorTransfer');
    }
    return tpl.amount >= 0 ? $r('app.color.colorIncome') : $r('app.color.colorExpense');
  }

  /**
   * 模板账户颜色竖条（对齐安卓 colorAccount）
   */
  private templateAccountColor(tpl: Template): ResourceColor {
    const c = tpl.accountColor;
    if (c) {
      const rgb = c & 0xFFFFFF;
      return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
    }
    return $r('app.color.defaultAccountColor');
  }

  /**
   * 模板行副标题（对齐安卓 template_row Category：类别 · 备注 · 收款人；转账显示 账户 → 账户）
   */
  private templateSubtitle(tpl: Template): string {
    const parts: string[] = [];
    if (tpl.isTransfer()) {
      const from = tpl.isIncome ? tpl.transferAccountLabel : tpl.accountLabel;
      const to = tpl.isIncome ? tpl.accountLabel : tpl.transferAccountLabel;
      parts.push(`${from || '账户'} → ${to || '账户'}`);
    } else {
      parts.push(tpl.categoryPath || '未分类');
    }
    if (tpl.comment) {
      parts.push(tpl.comment);
    }
    if (tpl.payeeName) {
      parts.push(tpl.payeeName);
    }
    return parts.join(' · ');
  }

  /**
   * 模板行长按操作菜单（对齐安卓 contextual action bar：生成计划/设置周期/删除）
   */
  private showTemplateMenu(tpl: Template): void {
    const sheets: SheetInfo[] = [];
    sheets.push({
      title: '编辑模板',
      action: () => {
        this.navigateToTemplateEdit(tpl.id);
      }
    });
    if (tpl.recurrence > 0) {
      sheets.push({
        title: '生成计划交易',
        action: () => {
          this.generatePlan(tpl);
        }
      });
    }
    sheets.push({
      title: '设置周期',
      action: () => {
        this.setRecurrence(tpl);
      }
    });
    sheets.push({
      title: '删除模板',
      action: () => {
        this.confirmDeleteTemplate(tpl);
      }
    });
    const options: ActionSheetOptions = {
      title: tpl.title,
      message: '模板操作',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
  }

  /**
   * 删除模板二次确认（对齐安卓 warning_delete_template）
   */
  private confirmDeleteTemplate(tpl: Template): void {
    this.getUIContext().showAlertDialog({
      title: '删除模板',
      message: `确定要删除模板「${tpl.title}」吗？此操作不可恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.colorExpense'),
        action: () => {
          this.deleteTemplate(tpl);
        }
      }
    });
  }

  /**
   * 跳转模板编辑页（新建模板）
   * 对齐安卓 TemplatesList 新建模板：进入 ExpenseEdit 的模板模式
   */
  private navigateToTemplateEdit(templateId: number): void {
    const acc = this.currentAccount() || (this.accounts.length > 0 ? this.accounts[0] : null);
    if (!acc) {
      promptAction.showToast({ message: $r('app.string.toast_create_account_first') });
      return;
    }
    router.pushUrl({
      url: 'pages/ExpenseEdit',
      params: {
        accountId: acc.id,
        isTemplate: true,
        templateId: templateId
      }
    }).catch(() => {
    });
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

  /** 模板筛选菜单（对齐安卓模板与计划筛选：全部/不重复/每天/每周/每月/每年，就近展开） */
  private templateFilterMenu(): Array<MenuElement> {
    const values: number[] = [-1, 0, 2, 3, 4, 6];
    const labels: string[] = ['全部模板', '不重复', '每天', '每周', '每月', '每年'];
    const menu: Array<MenuElement> = [];
    for (let i = 0; i < values.length; i++) {
      const v = values[i];
      const lb = labels[i];
      menu.push({
        value: (this.templateFilter === v ? '✓ ' : '') + lb,
        action: () => {
          this.templateFilter = v;
        }
      } as MenuElement);
    }
    return menu;
  }

  /** 按筛选条件过滤模板列表 */
  private filteredTemplates(): Template[] {
    if (this.templateFilter === -1) {
      return this.templates;
    }
    return this.templates.filter((tpl: Template) => tpl.recurrence === this.templateFilter);
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
      // 账户标题 + 资产负债表切换箭头（对齐安卓：点击弹出下拉菜单，账户/资产负债表 同页切换）
      if (this.selectedTab === 0) {
        Row() {
          Text(this.accountView === 0 ? '账户' : '资产负债表')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.textPrimary'))
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(16)
            .height(16)
            .margin({ left: 4 })
        }
        .bindMenu(this.accountViewMenu())
      } else {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.textPrimary'))
      }
      Blank()
      // 模板页右上角筛选（对齐安卓模板与计划筛选，就近展开非弹窗）
      if (this.selectedTab === 2) {
        Image($r('app.media.ic_filter_list'))
          .width(22)
          .height(22)
          .margin({ right: 8 })
          .fillColor($r('app.color.textSecondary'))
          .bindMenu(this.templateFilterMenu())
      }
      // 账户列表视图右上角操作（对齐安卓：ViewOptionsMenu Tune + ManageEntitiesMenu DataObject）
      if (this.selectedTab === 0 && this.accountView === 0) {
        // 选项（Tune）：分组 + 排序方式（对齐安卓 TooltipIconMenu 就近展开）
        Image($r('app.media.ic_tune'))
          .width(22)
          .height(22)
          .margin({ right: 16 })
          .fillColor($r('app.color.textSecondary'))
          .bindMenu(this.accountViewOptionsMenu())
        // 数据（DataObject）：管理账户类型/标记
        Image($r('app.media.ic_data_object'))
          .width(22)
          .height(22)
          .fillColor($r('app.color.textSecondary'))
          .bindMenu(this.manageEntitiesMenu())
      }
      // 资产负债表视图右上角操作（对齐安卓 BalanceSheetOptions：Print 图标 + Tune 下拉菜单，与标题同高）
      if (this.selectedTab === 0 && this.accountView === 1) {
        Image($r('app.media.ic_print'))
          .width(22)
          .height(22)
          .margin({ right: 16 })
          .fillColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.bsPrintTick++;
          })
        Image($r('app.media.ic_tune'))
          .width(22)
          .height(22)
          .fillColor($r('app.color.textSecondary'))
          .bindMenu(this.balanceSheetOptionsMenu())
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }

  /**
   * 账户列表视图选项菜单（对齐安卓 ViewOptionsMenu：分组单选 + 排序方式入口）
   */
  private accountViewOptionsMenu(): Array<MenuElement> {
    const menu: Array<MenuElement> = [];
    const groups: Array<AccountGrouping> = [AccountGrouping.NONE, AccountGrouping.TYPE, AccountGrouping.CURRENCY, AccountGrouping.FLAG];
    const labels: Array<string> = ['不分组', '按类型', '按货币', '按标记'];
    for (let i = 0; i < groups.length; i++) {
      menu.push({
        value: (this.grouping === groups[i] ? '✓ ' : '') + labels[i],
        action: () => {
          this.grouping = groups[i];
          this.settings.setNumber(PREF_KEY.GROUPING, i);
        }
      } as MenuElement);
    }
    menu.push({
      value: '排序方式',
      action: () => {
        this.showSortDialog();
      }
    } as MenuElement);
    return menu;
  }

  /** 打开排序方式对话框（对齐安卓 AccountListDisplayConfigurationDialogFragment 居中模态框） */
  private showSortDialog(): void {
    const dialog = new CustomDialogController({
      builder: SortDialog({
        sortByFlagFirst: this.sortByFlagFirst,
        currentSort: this.accountSortBy,
        onResult: (flagFirst: boolean, sortBy: string) => {
          this.sortByFlagFirst = flagFirst;
          this.accountSortBy = sortBy;
          this.applyAccountSort();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      cornerRadius: 16
    });
    dialog.open();
  }

  /**
   * 数据菜单（对齐安卓 ManageEntitiesMenu：管理账户类型/标记）
   */
  private manageEntitiesMenu(): Array<MenuElement> {
    return [
      {
        value: '账户类型',
        action: () => {
          this.showAccountTypes();
        }
      } as MenuElement,
      {
        value: '账户标记',
        action: () => {
          this.showAccountFlagsManage();
        }
      } as MenuElement
    ];
  }


  /** 应用账户排序 */
  private applyAccountSort(): void {
    this.settings.setString(PREF_KEY.SORT_BY, this.accountSortBy);
    this.settings.setBoolean(PREF_KEY.SORT_ACCOUNT_LIST_BY_FLAG_FIRST, this.sortByFlagFirst);
    // 按当前分组重新加载数据
    this.loadData();
  }

  /** 按排序方式排序账户列表（对齐安卓 Sort.accountSort：LABEL/USAGES/LAST_USED/CUSTOM） */
  private sortAccounts(accounts: Account[]): Account[] {
    const sorted = [...accounts];
    const flagFirst = this.sortByFlagFirst;
    if (flagFirst) {
      // 优先标记顺序：标记分组靠前
      sorted.sort((a: Account, b: Account) => a.flagId - b.flagId);
    }
    switch (this.accountSortBy) {
      case 'usages':
        sorted.sort((a: Account, b: Account) => (b as Account).lastUsed - (a as Account).lastUsed);
        break;
      case 'last_used':
        sorted.sort((a: Account, b: Account) => b.lastUsed - a.lastUsed);
        break;
      case 'custom':
        break;
      default:
        sorted.sort((a: Account, b: Account) => a.label.localeCompare(b.label));
    }
    return sorted;
  }

  private showAccountOptions(): void {
    const options: ActionSheetOptions = {
      title: '账户选项',
      message: '账户管理操作',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: [
        {
          title: '新建账户',
          action: () => this.navigateToAccountEdit(-1)
        },
        {
          title: '账户类型',
          action: () => this.showAccountTypes()
        },
        {
          title: '账户标记',
          action: () => this.showAccountFlagsManage()
        },
        {
          title: '显示等值',
          action: () => this.toggleShowEquivalent()
        },
        {
          title: '资产负债表',
          action: () => {
            this.accountView = 1;
          }
        }
      ]
    };
    this.getUIContext().showActionSheet(options);
  }

  private showAccountTypes(): void {
    promptAction.showToast({ message: '账户类型管理（开发中）' });
  }

  private showAccountFlagsManage(): void {
    promptAction.showToast({ message: '账户标记管理（开发中）' });
  }

  private async toggleShowEquivalent(): Promise<void> {
    this.showEquivalent = !this.showEquivalent;
    await this.settings.setBoolean(PREF_KEY.SHOW_EQUIVALENT, this.showEquivalent);
    await this.loadData();
  }

  private navigateToBalanceSheet(): void {
    router.pushUrl({ url: 'pages/BalanceSheet' }).catch(() => {
    });
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
          Text(this.isAggregate() ? '累计' : (this.currentAccount()?.label || '交易'))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(14)
            .height(14)
            .opacity(0.4)
            .margin({ left: 4 })
            .onClick(() => {
              this.showAccountDetail();
            })
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


      // AI 助手
      Image($r('sys.media.ohos_ic_public_scan'))
        .width(22)
        .height(22)
        .margin({ right: 8 })
        .onClick(() => {
          this.navigateToAi();
        })

      // 更多操作图标（对齐安卓 Actions 菜单：排序/分组/导出）
      Image($r('sys.media.ohos_ic_public_more'))
        .width(22)
        .height(22)
        .onClick(() => {
          this.showTransactionActions();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.pageBackground'))
  }

  /**
   * 交易页账户滑动选择器（对齐安卓 SecondaryScrollableTabRow）
   * 未过滤时：首项为"累计"（聚合账户，对应安卓 HOME_AGGREGATE_ID），随后为各账户
   * 过滤器激活时：仅显示该类型下的账户，右侧末尾为聚合 tab（账户类型名，对齐安卓 AggregateAccount.labelV2）
   * 可横向滑动，点击切换所选账户并刷新交易
   */
  @Builder
  accountTabsRow() {
    Scroll() {
      Row() {
        // 账户过滤器图标（对齐安卓 AccountFilterMenu）：聚合视图或过滤激活时显示，点击弹出账户类型筛选
        if (this.isAggregate() || this.activeFilterType >= 0) {
          Image($r('app.media.ic_filter'))
            .width(20)
            .height(20)
            .fillColor(this.activeFilterType >= 0 ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
            .bindMenu(this.accountFilterMenuItems())
            .margin({ left: 4, right: 4 })
        }
        if (this.activeFilterType >= 0) {
          // 过滤激活：各该类型账户 + 右侧末尾聚合 tab（账户类型名）
          ForEach(this.filteredTabAccounts(), (acc: Account) => {
            this.accountTabItem(acc.id, acc.label, this.hexColor(acc.color))
          }, (acc: Account) => `tab_${acc.id}`)
          this.accountTabItem(0, `${Account.typeName(this.activeFilterType as AccountType)} (Σ)`,
            $r('app.color.defaultAccountColor'))
        } else {
          // 未过滤：累计（聚合账户：全部账户交易）
          this.accountTabItem(0, '累计', $r('app.color.defaultAccountColor'))
          // 各账户
          ForEach(this.accounts, (acc: Account) => {
            this.accountTabItem(acc.id, acc.label, this.hexColor(acc.color))
          }, (acc: Account) => `tab_${acc.id}`)
        }
      }
      .padding({ left: 8, right: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(44)
    .backgroundColor($r('app.color.pageBackground'))
  }

  /**
   * 滑动栏账户列表：过滤器激活时仅返回该类型下的账户（对齐安卓 accountList 过滤）
   */
  private filteredTabAccounts(): Account[] {
    if (this.activeFilterType >= 0) {
      return this.accounts.filter((a: Account) => a.type === this.activeFilterType);
    }
    return this.accounts;
  }

  /**
   * 账户 Tab 单项：选中时主色文字 + 底部账户色指示线（对齐安卓 SecondaryIndicator color = accountColor）
   */
  @Builder
  accountTabItem(id: number, label: string, indicatorColor: ResourceColor) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor(this.selectedAccountId === id ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
        .fontWeight(this.selectedAccountId === id ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 8, right: 8 })
      // 底部指示线：选中时显示账户色，否则透明占位保持高度一致
      Divider()
        .width(36)
        .strokeWidth(2)
        .color(this.selectedAccountId === id ? indicatorColor : Color.Transparent)
        .margin({ top: 3 })
    }
    .height(44)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectTransactionAccount(id);
    })
  }

  private hexColor(color: number): ResourceColor {
    if (color) {
      const rgb = color & 0xFFFFFF;
      return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
    }
    return $r('app.color.defaultAccountColor');
  }

  /**
   * 交易页切换所选账户：聚合（0）加载全部交易，单个账户加载该账户交易
   * 对齐安卓：过滤器激活时保留过滤状态（点击具体账户不清除过滤）
   */
  private async selectTransactionAccount(id: number): Promise<void> {
    this.selectedAccountId = id;
    // 立即用缓存（避免显示上一个账户的旧数据），随后异步刷新
    const cached = this.transactionCache.get(id) || [];
    this.currentTransactions = this.applyAccountFilter(cached);
    this.recalcSummaries(this.currentTransactions);
    await this.refreshTransactions(id);
  }

  /**
   * 交易页更多操作菜单（对齐安卓 Actions：排序/分组/导出）
   */
  private showTransactionActions(): void {
    const sheets: Array<SheetInfo> = [];
    sheets.push({
      title: `分组：${this.groupingLabel()}`,
      action: () => this.cycleGrouping()
    } as SheetInfo);
    sheets.push({
      title: '排序（日期）',
      action: () => this.cycleSortOrder()
    } as SheetInfo);
    sheets.push({
      title: '导出 CSV',
      action: () => this.exportCsv()
    } as SheetInfo);
    sheets.push({
      title: '筛选',
      action: () => this.navigateToSearch()
    } as SheetInfo);
    const options: ActionSheetOptions = {
      title: '交易操作',
      message: '排序/分组/导出/筛选',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
  }

  private cycleSortOrder(): void {
    promptAction.showToast({ message: '排序已切换（日期降序）' });
  }

  private exportCsv(): void {
    promptAction.showToast({ message: '导出 CSV 功能开发中' });
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

      // 收入/支出/转账：直接读取 @State 值（不经过 @Builder 参数传递，确保响应式追踪）
      Row() {
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Image($r('app.media.ic_income'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.colorIncome'))
            Text(`${this.symbol()}${formatMoney(this.summaryIncome, this.fractionDigits())}`)
              .fontSize(14)
              .fontColor($r('app.color.colorIncome'))
              .fontWeight(FontWeight.Medium)
          }
          Text('收入')
            .fontSize(11)
            .fontColor($r('app.color.textSecondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Image($r('app.media.ic_expense'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.colorExpense'))
            Text(`${this.symbol()}${formatMoney(this.summaryExpense, this.fractionDigits())}`)
              .fontSize(14)
              .fontColor($r('app.color.colorExpense'))
              .fontWeight(FontWeight.Medium)
          }
          Text('支出')
            .fontSize(11)
            .fontColor($r('app.color.textSecondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Image($r('app.media.ic_transfer'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.colorTransfer'))
            Text(`${this.symbol()}${formatMoney(this.summaryTransfer, this.fractionDigits())}`)
              .fontSize(14)
              .fontColor($r('app.color.colorTransfer'))
              .fontWeight(FontWeight.Medium)
          }
          Text('转帐')
            .fontSize(11)
            .fontColor($r('app.color.textSecondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.summaryCardBackground'))
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
        this.menuRow('预算编制', $r('app.media.ic_category'), () => {
          // P0-3：已迁移 NavDestination 的页面走 Navigation 栈
          this.pathStack.pushPathByName('BudgetManage', null);
        })
      }
      ListItem() {
        this.menuRow('债务', $r('app.media.ic_locked'), () => {
          // P0-3：已迁移 NavDestination 的页面走 Navigation 栈
          this.pathStack.pushPathByName('DebtManage', null);
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
    if (this.isAggregate()) {
      // 聚合模式：显示全部账户合计（对齐安卓 AggregateAccount 主货币余额）
      return `¥${formatMoney(this.currentBalance(), 2)}`;
    }
    const acc = this.currentAccount();
    if (!acc) {
      return '';
    }
    const symbol = currencyByCode(acc.currency).symbol;
    return `${symbol}${formatMoney(acc.currentBalance, currencyByCode(acc.currency).fractionDigits)}`;
  }

  /**
   * 当前余额：聚合模式返回全部账户合计（对齐安卓 AggregateAccount currentBalance）
   */
  private currentBalance(): number {
    const acc = this.currentAccount();
    if (acc) {
      return acc.currentBalance;
    }
    if (this.isAggregate()) {
      let sum = 0;
      for (let a of this.accounts) {
        sum += a.currentBalance;
      }
      return sum;
    }
    return 0;
  }

  /**
   * 账户详情弹窗（对齐安卓：点击交易页左上角账户标题倒三角）
   */
  private showAccountDetail(): void {
    const acc = this.currentAccount();
    const isAgg = this.isAggregate();
    let label = isAgg ? '累计' : (acc?.label || '交易');
    let curBalance = 0;
    let opening = 0;
    let income = 0;
    let expense = 0;
    let transfer = 0;
    let symbol = '¥';
    let digits = 2;
    if (isAgg) {
      for (const a of this.accounts) {
        curBalance += a.currentBalance;
        opening += a.openingBalance;
        income += a.sumIncome;
        expense += a.sumExpense;
        transfer += a.sumTransfer;
      }
    } else if (acc) {
      curBalance = acc.currentBalance;
      opening = acc.openingBalance;
      income = acc.sumIncome;
      expense = acc.sumExpense;
      transfer = acc.sumTransfer;
      const cu = currencyByCode(acc.currency);
      symbol = cu.symbol;
      digits = cu.fractionDigits;
    }
    const dialog = new CustomDialogController({
      builder: AccountDetailDialog({
        accountLabel: label,
        currentBalance: curBalance,
        openingBalance: opening,
        sumIncome: income,
        sumExpense: expense,
        sumTransfer: transfer,
        isAggregate: isAgg,
        currencySymbol: symbol,
        fractionDigits: digits,
        onCopy: () => {
          const text = `${label} 当前余额 ${symbol}${formatMoney(curBalance, digits)}`;
          const ctx = getContext(this) as common.UIAbilityContext;
          const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
          pasteboard.getSystemPasteboard().setData(pasteData);
          promptAction.showToast({ message: '已复制到剪贴板' });
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      cornerRadius: 16
    });
    dialog.open();
  }

  private accountColor(): ResourceColor {
    const acc = this.currentAccount();
    if (acc && acc.color) {
      const rgb = acc.color & 0xFFFFFF;
      return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
    }
    return $r('app.color.defaultAccountColor');
  }


  private balanceColor(): ResourceColor {
    const acc = this.currentAccount();
    if (!acc && !this.isAggregate()) {
      return $r('app.color.textTertiary');
    }
    const balance = this.currentBalance();
    if (balance > 0) {
      return $r('app.color.colorIncome');
    }
    if (balance < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  /**
   * 处理交易行操作菜单动作（bindMenu 在行下方弹出，对齐安卓 PopupMenu）
   */
  private handleTransactionMenuAction(id: number, action: string): void {
    const tx = this.currentTransactions.find((t: Transaction) => t.id === id);
    if (!tx) {
      return;
    }
    if (action === 'detail') {
      this.showTransactionDetail(tx);
    } else if (action === 'edit') {
      this.navigateToExpenseEdit(id, this.selectedAccountId);
    } else if (action === 'delete') {
      this.confirmDeleteTransaction(tx);
    }
  }

  private detailDialog: CustomDialogController | null = null;

  /**
   * 显示交易只读详情弹窗（对齐安卓 TransactionDetailFragment）
   */
  private showTransactionDetail(tx: Transaction): void {
    if (this.detailDialog) {
      this.detailDialog.close();
    }
    this.detailDialog = new CustomDialogController({
      builder: TransactionDetailDialog({
        transaction: tx,
        tagLabels: this.tagLabelList(tx),
        onClose: () => {
          this.detailDialog?.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      cornerRadius: 16
    });
    this.detailDialog.open();
  }

  private tagLabelList(tx: Transaction): string[] {
    const list: string[] = [];
    for (let tagId of tx.tagIds) {
      const t = this.tags.find((tag: Tag) => tag.id === tagId);
      if (t) {
        list.push(t.label);
      }
    }
    return list;
  }

  /**
   * 删除确认框：防止误删（对齐安卓删除确认）
   */
  private confirmDeleteTransaction(tx: Transaction): void {
    this.getUIContext().showAlertDialog({
      title: '删除交易',
      message: '确定要删除这笔交易吗？此操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.colorExpense'),
        action: () => {
          this.deleteTransaction(tx);
        }
      }
    });
  }

  private async deleteTransaction(tx: Transaction): Promise<void> {
    try {
      if (tx.isSplit()) {
        await this.repository.deleteSplitTransaction(tx.id);
      } else {
        await this.repository.deleteTransaction(tx.id);
      }
      promptAction.showToast({ message: '已删除' });
      // 刷新当前视图的交易列表与汇总
      await this.refreshTransactions(this.selectedAccountId);
    } catch (e) {
      console.error('删除交易失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '删除失败' });
    }
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
    if (this.sealedBusy.has(id)) {
      return; // 防抖：处理中忽略重复点击，避免异步竞态来回切换
    }
    const acc = this.accounts.find((a: Account) => a.id === id);
    if (!acc) {
      return;
    }
    this.sealedBusy.add(id);
    const target = !acc.sealed;
    // 乐观更新：先本地翻转，UI 立即反馈（对齐安卓 toggleAccountSealed 即时生效）
    acc.sealed = target;
    this.accounts = [...this.accounts];
    try {
      await this.repository.setAccountSealed(id, target);
      await this.loadData();
    } catch (e) {
      console.error('切换账户关闭状态失败: ' + JSON.stringify(e));
      // 写库失败回滚本地状态
      acc.sealed = !target;
      this.accounts = [...this.accounts];
    } finally {
      this.sealedBusy.delete(id);
    }
  }

  private async toggleExclude(id: number): Promise<void> {
    if (this.excludeBusy.has(id)) {
      return; // 防抖：处理中忽略重复点击
    }
    const acc = this.accounts.find((a: Account) => a.id === id);
    if (!acc) {
      return;
    }
    this.excludeBusy.add(id);
    const target = !acc.excludeFromTotals;
    // 乐观更新：先本地翻转，UI 立即反馈
    acc.excludeFromTotals = target;
    this.accounts = [...this.accounts];
    try {
      await this.repository.setAccountExcludeFromTotals(id, target);
      await this.loadData();
    } catch (e) {
      console.error('切换账户计入总数失败: ' + JSON.stringify(e));
      acc.excludeFromTotals = !target;
      this.accounts = [...this.accounts];
    } finally {
      this.excludeBusy.delete(id);
    }
  }

  /**
   * 设置账户标记（对齐安卓 Flag 菜单）
   */
  private async setAccountFlag(id: number): Promise<void> {
    const flags = await this.repository.getAccountFlags();
    if (flags.length === 0) {
      promptAction.showToast({ message: '暂无可用标记' });
      return;
    }
    const sheets: Array<SheetInfo> = [];
    for (let f of flags) {
      sheets.push({
        title: f.label,
        action: () => this.applyAccountFlag(id, f.id)
      } as SheetInfo);
    }
    const options: ActionSheetOptions = {
      title: '设置账户标记',
      message: '选择账户标记',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
  }

  private async applyAccountFlag(id: number, flagId: number): Promise<void> {
    await this.repository.setAccountFlag(id, flagId);
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
