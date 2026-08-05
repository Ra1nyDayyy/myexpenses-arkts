# Code Mapping: MyExpenses (Android) → ArkUI

> 本文档记录 Android → ArkUI 的架构映射。Android 源为唯一行为依据。

## 0. UI 实现策略（用户确认）

- **信息架构与布局以 Android 为基准**（页面结构、字段顺序、交互逻辑一致）。
- **组件呈现优先使用鸿蒙原生样式**：底部导航用原生 `Tabs`（自带选中态动画、图标文字、深浅色适配）；FAB 用鸿蒙圆形样式；按钮/输入框/下拉/对话框用 ArkUI 原生组件。
- **鸿蒙无对应原生组件的业务元素才完全模仿 Android**：账户颜色圆形指示器、金额颜色规则、交易行状态块等业务自定义 UI 按 Android 复刻。
- 颜色统一走资源限定目录（base + dark），随系统深浅色自动切换。

## 1. 架构映射总表

| Android | ArkUI | 说明 |
|---|---|---|
| Activity/Fragment | UIAbility + Page + @Component | EntryAbility 只做入口，页面逻辑放独立组件 |
| MyExpenses (DrawerLayout + CoordinatorLayout + ViewPager) | Index 主页面：原生 Tabs（底部 4 Tab）+ Swiper | 底部导航用鸿蒙原生 Tabs，内容页跟随 Tab 切换 |
| ViewPager/ComposeView | Swiper + LazyForEach | 每页一个账户的交易列表 |
| RecyclerView + LazyColumn | List + LazyForEach | 稳定 keyGenerator |
| AccountList (Compose) | AccountListPage 组件 | 账户行、分组、展开汇总 |
| TransactionList | TransactionListPage 组件 | 分组 sticky 头 + 交易行 |
| ExpenseEdit Activity | ExpenseEditPage | 表单表格 1:2.5，行高 48vp |
| ManageCategories/ManageMethods 等 | ManagePage + 子页 | 管理页 |
| SharedPreferences | @ohos.data.preferences | 设置存储 |
| SQLite (TransactionDatabase) | @ohos.data.relationalStore | 同构表结构 |
| ContentProvider | Repository + AppStorage | 单例 Repository |
| ViewModel | 状态容器 + 业务 Service | @State/@Observed/@ObjectLink |
| Money (BigDecimal minor units) | Money class (amountMinor + fractionDigits) | 最小货币单位存储 |
| CurrencyUnit | CurrencyUnit class | code/symbol/fractionDigits |
| Account/Transaction/Category 实体 | model/*.ets class | 字段一一对应 |
| 深浅色主题 | resources/base + resources/dark | 金额颜色规则一致 |
| 语言 | 仅 zh_CN（本期范围） | 中文字符串资源 |

## 2. 数据表映射（relationalStore）

| Android 表 | ArkUI 表 | 关键列 |
|---|---|---|
| accounts | accounts | id, label, description, opening_balance, currency, type, color, grouping, sort_by, sort_direction, criterion, exclude_from_totals, uuid, sealed, dynamic, parent_id, bank_id |
| transactions | transactions | id, comment, date, value_date, amount, cat_id, account_id, payee_id, transfer_peer, transfer_account, method_id, parent_id, status, cr_status, number, uuid, original_amount, original_currency, debt_id |
| categories | categories | id, label, label_normalized, parent_id, usages, last_used, color, icon, uuid, type |
| paymentmethods | paymentmethods | id, label, is_numbered, type, icon |
| payee | payee | id, name, short_name, name_normalized, parent_id |
| currency | currency | id, code, label, fraction_digits, symbol |
| tags / transactions_tags | tags / transactions_tags | id, label, color |
| budgets / budget_allocations | budgets / budget_allocations | 预算表 |
| debts | debts | id, payee_id, date, label, amount, currency, description, sealed |
| settings | preferences | key, value |
| account_types / account_flags | account_types / account_flags | 类型/标记 |

## 3. 金额与颜色规则

- 金额存储为**最小货币单位**（如分），显示时按 fractionDigits 转换。
- 颜色规则：正数/收入 → colorIncome(#006800 浅/#00D000 深)；负数/支出 → colorExpense(#800000 浅/#FF5E5E 深)；转账 → colorTransfer(#000080 浅/#7777FF 深)；中性/零 → 主文本色。

## 4. 页面路由

| 页面 | 路由 | 对应 Android |
|---|---|---|
| Index（主界面） | pages/Index | MyExpenses.kt |
| AccountEdit | pages/AccountEdit | AccountEdit.kt + one_account.xml |
| ExpenseEdit | pages/ExpenseEdit | ExpenseEdit.kt + one_expense.xml |
| CategoryManage | pages/CategoryManage | ManageCategories |
| CategorySelect | pages/CategorySelect | 分类选择树 |
| MethodManage | pages/MethodManage | ManageMethods |
| TagManage | pages/TagManage | ManageTags |
| BalanceSheet | pages/BalanceSheet | BalanceSheet |
| Settings | pages/Settings | PreferenceActivity |
| AI Assistant | pages/AiAssistant | 新增 AI 功能 |
| Distribution | pages/Distribution | DistributionActivity |

## 5. 分阶段切片

1. 数据层：relationalStore 建表 + Repository（账户/交易/分类/付款方式/收款人/货币/标签/预算/债务）
2. 主界面：账户列表抽屉 + 交易列表 Pager + FAB + 工具栏
3. 记账编辑：ExpenseEdit（收入/支出/转账/拆分、金额、日期、收款人、类别、备注、方法、标签）
4. 管理页：账户编辑、分类管理/选择、付款方式、标签
5. 辅助页：资产负债表、设置、分布统计
6. AI 功能：AI 助手页（本地规则分析收支，给出记账建议）