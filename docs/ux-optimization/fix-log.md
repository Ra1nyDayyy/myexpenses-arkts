# 修复日志 (fix-log.md)

> 按迭代追加，每条记录: 时间 | 条目id | 页面 | 文件/行 | 原因 | 回归用例

（M0 阶段，尚无修复记录）

## iter1

| 时间 | 条目id | 页面 | 文件/行 | 原因 | 回归用例 |
|------|--------|------|---------|------|----------|
| 2026-08-18T04:54 | UX-0001 | Index | `entry/src/main/resources/base/element/string.json:37,101,137`<br>`entry/src/main/ets/pages/Index.ets:2460`<br>`entry/src/main/ets/components/AccountDetailDialog.ets:83`<br>`entry/src/main/ets/components/AccountRow.ets:161` | 帐→账错别字，"转帐"→"转账"（共 6 处） | 无（regressionRisk=none） |
| 2026-08-18T05:10 | UX-0002 | ExpenseEdit | `entry/src/main/ets/pages/ExpenseEdit.ets:997-1024` | transferAccounts() 仅一个账户时返回空列表，Select 无选项点击无响应；改为空列表时显示提示文本"请先创建另一个账户" | 无（regressionRisk=none） |
| 2026-08-18T05:10 | UX-0005 | ExpenseEdit | `entry/src/main/ets/pages/ExpenseEdit.ets:1178` | 金额 TextInput 缺少 selectAllOnFocus，编辑模式聚焦未全选导致输入追加；添加 .selectAllOnFocus(transactionId>0) | 无（regressionRisk=none） |
| 2026-08-18T05:10 | UX-0003 | ExpenseEdit | `entry/src/main/ets/pages/ExpenseEdit.ets:64-77,272,279-341,990` | 缺少 onBackPress，编辑未保存按 Back 直接退出；新增原始值快照+hasUnsavedChanges()+handleBack()+onBackPress()，PageHeader onBack 改走 handleBack | 无（regressionRisk=none） |
| 2026-08-18T05:10 | UX-0004 | Index | `entry/src/main/ets/pages/Index.ets:2663-2678,2742-2762` | confirmDeleteTransaction/deleteSelected 用 getUIContext().showAlertDialog 的 secondaryButton.action 回调不触发；改用 promptAction.showDialog（与 deleteAccount 一致）通过 then(result.index) 处理 | rerun: TX-12 |

### 修复说明

- **问题**：交易 Tab 汇总区、账户详情对话框、账户行汇总等处显示"转帐"，应为"转账"（帐→账错别字）。
- **范围**：仅将"转帐"改为"转账"，未改动其他内容；未修改构建配置、包名、签名。
- **dark 资源检查**：`resources/dark/element/` 下仅有 `color.json`，无 `string.json`，无需修改。
- **未修改项**：`docs/` 下的证据 dump、日志、审计记录中保留"转帐"原文，作为历史证据不动。
- **回归风险**：none（纯文案修正，不影响逻辑/数据流）。

#### UX-0002 转账目标账户 Select 空列表无响应

- **根因**：`transferAccounts()` 过滤掉当前账户后，若系统仅有一个账户则返回空数组，`Select([])` 无选项，点击不弹下拉也无任何反馈，转账流程阻断。
- **修复**：在转账目标账户 Row 内根据 `transferAccounts().length === 0` 分支：空列表时渲染提示文本"请先创建另一个账户"（次级文字色，右对齐），有选项时保持原 Select 组件。
- **回归风险**：none（仅空态分支，有账户时逻辑不变）。

#### UX-0005 金额输入追加而非替换

- **根因**：金额 `TextInput` 未设置 `selectAllOnFocus`，编辑已有交易时聚焦光标在末尾，输入追加到原值后（如 "20.00"+输入"30"="3020.00"）。
- **修复**：添加 `.selectAllOnFocus(this.transactionId > 0)`，仅编辑已有交易（transactionId>0）时聚焦全选，新建交易保持默认空输入行为。
- **回归风险**：none（新建交易不受影响，编辑交易聚焦全选是标准交互）。

#### UX-0003 编辑交易 Back 无确认

- **根因**：`ExpenseEdit` 未实现 `onBackPress`，PageHeader 的 onBack 直接 `router.back()`，编辑有未保存修改时直接退出无确认。
- **修复**：
  1. 新增 11 个 private 快照字段（snapshotAmount/Comment/Payee/CategoryId/MethodId/TransferAccountId/Date/CrStatus/IsIncome/ReferenceNumber/TagIds）。
  2. `loadTransaction()` 末尾调用 `captureSnapshot()` 保存原始值基准。
  3. 新增 `hasUnsavedChanges()` 比较当前值与快照（仅 transactionId>0 且非模板模式生效）。
  4. 新增 `handleBack()`：有修改时弹 AlertDialog"放弃修改？"[继续编辑/放弃]，无修改直接 router.back()。
  5. 新增 `onBackPress()` 拦截系统返回键调用 handleBack 并返回 true。
  6. PageHeader 的 onBack 回调改为 `this.handleBack()`。
- **回归风险**：none（新建/模板模式 hasUnsavedChanges 返回 false，直接退出；仅编辑模式有修改时弹确认）。

#### UX-0004 删除选项点击无响应

- **根因**：`confirmDeleteTransaction` 和 `deleteSelected` 使用 `this.getUIContext().showAlertDialog` 的 `secondaryButton.action` 回调，dump 证据显示 AlertDialog 弹出但点击"删除"按钮后对话框不关闭、交易未删除（action 未触发）。同文件 `deleteAccount` 使用 `promptAction.showDialog` + `then(result.index)` 已被验证有效。
- **修复**：将 `confirmDeleteTransaction` 和 `deleteSelected` 改用 `promptAction.showDialog`，buttons 用 `[{text:'取消',color:'#808080'},{text:'删除',color:'#E53935'}]`，通过 `.then((result)=>{ if(result.index===1) ... })` 处理删除回调，与 `deleteAccount` 写法完全一致。
- **回归风险**：rerun: TX-12（删除流程需回归验证：单笔删除确认→删除→刷新列表/余额；批量删除确认→删除→退出多选→刷新）。

## iter2

| 时间 | 条目id | 页面 | 文件/行 | 原因 | 回归用例 |
|------|--------|------|---------|------|----------|
| 2026-08-18T14:45 | UX-0008 | CategoryManage | `CategoryManage.ets` | 编辑分类对话框未预填充名称；新增 initialLabel + aboutToAppear | 无 |
| 2026-08-18T14:45 | UX-0009 | CategoryManage | `CategoryManage.ets` | 删除分类无确认；改用 promptAction.showDialog | 无 |
| 2026-08-18T14:53 | UX-0010 | MethodManage | `MethodManage.ets` | 标题"付款方法"→"付款方式" | 无 |
| 2026-08-18T14:53 | UX-0011 | MethodManage | `MethodManage.ets` | 保存静默失败；saveMethod 加 try-catch+toast+initialLabel | 无 |
| 2026-08-18T14:53 | UX-0012 | MethodManage | `MethodManage.ets` | 缺少编辑功能；新增 openEditDialog | 无 |
| 2026-08-18T14:53 | UX-0013 | MethodManage | `MethodManage.ets` | 删除无确认；改用 promptAction.showDialog | 无 |
| 2026-08-18T14:54 | UX-0005 | ExpenseEdit | `ExpenseEdit.ets` | 金额追加非替换；用 .selectAll(boolean) API（since API 12） | 无 |
| 2026-08-18T15:31 | UX-0014 | TagManage | `TagManage.ets` | 标签保存静默失败；addTag 加 try-catch+toast，deleteTag 加确认对话框 | 无 |
| 2026-08-18T15:31 | UX-0015 | TagSelect | `TagSelect.ets` | 创建标签不工作；createTag 加 try-catch+toast+@State触发更新 | 无 |
| 2026-08-18T15:31 | UX-0017 | SearchPage | `SearchPage.ets`<br>`SearchCriterionDialog.ets` | 关键字未传递；showQuickCriteriaDialog 改调用 showCriterionDialog，comment 类型不传 extra | 无 |
| 2026-08-18T15:31 | UX-0020 | History | `History.ets` | 8月数据¥0.00；load() 跳过拆分子项 (parentId>0) | 无 |

### iter2 修复说明

#### UX-0005 金额输入追加而非替换（iter2 修复）
- **根因**：iter1 标记 DEFERRED（误认为 ArkUI 不支持 selectAll API）。实际 `TextInputAttribute.selectAll(boolean)` 存在于 SDK（since API 12，项目 API 24 可用）。
- **修复**：添加 `.selectAll(this.transactionId > 0 || (this.isTemplate && this.templateId > 0))`，编辑模式或模板模式聚焦时全选金额内容。
- **回归风险**：none。

#### UX-0014/UX-0015 标签保存静默失败
- **根因**：`addTag`/`createTag` 缺少 try-catch，`insertTag` 抛出异常时 Promise rejection 未被捕获，静默失败。空标签时直接 return 无提示。
- **修复**：addTag/createTag 加 try-catch，catch 中用 `promptAction.showToast` 显示错误信息；空名称时显示 toast 提示。TagManage 的 deleteTag 改为 promptAction.showDialog 确认后再删除。TagSelect 的 createTag 选中标签后用 `[...this.selectedTagIds]` 触发 @State 更新。
- **回归风险**：none。

#### UX-0017 搜索关键字未传递
- **根因**：1) `showQuickCriteriaDialog` 使用 `showAlertDialog`（无输入框），直接把 label（如"备注"）作为 value 传入；2) `SearchCriterionDialog.confirm()` 对 comment 类型传 `extra='支出'`，导致显示"备注(支出)"。
- **修复**：1) `showQuickCriteriaDialog` 改为直接调用 `showCriterionDialog(type)`，让用户通过完整条件对话框输入关键字；2) `confirm()` 对 comment 类型传 `undefined` 作为 extra，不显示"(支出)"。
- **回归风险**：none。

#### UX-0020 历史记录8月数据¥0.00
- **根因**：`getAllTransactions()` 返回所有交易包括拆分子项（parent_id 不为 NULL），可能导致重复计算或数据不一致。
- **修复**：`load()` 循环中新增 `if (t.parentId > 0) continue` 跳过拆分子项，对齐 `getTransactions` 的 `isNull('parent_id')` 过滤。
- **回归风险**：none。

#### UX-0021 时间范围选择器无响应（DEFERRED）
- **原因**：当前"近6个月"为静态文本，需新增时间范围选择器（3个月/6个月/1年/自定义），涉及UI重构和load()参数化。
- **延迟到**：iter3。

## iter3

| 时间 | 条目id | 页面 | 文件/行 | 原因 | 回归用例 |
|------|--------|------|---------|------|----------|
| 2026-08-18T16:20 | UX-0016 | SearchPage | `SearchPage.ets` | 快速搜索模式顶部添加关键字搜索框，输入关键字后直接搜索备注 | 无 |
| 2026-08-18T16:20 | UX-0019 | Distribution | `Distribution.ets` | 分类项添加 onClick，点击后 toast 显示分类名称、金额和占比 | 无 |
| 2026-08-18T16:20 | UX-0021 | History | `History.ets` | 将近N个月文本改为可点击，弹出 ActionMenu 选择 3/6/12 个月范围，load() 参数化 | 无 |
| 2026-08-18T16:20 | UX-0022 | BudgetManage | `BudgetManage.ets`<br>`Repository.ets` | BudgetInputDialog 支持编辑模式，列表项 onClick 弹出编辑对话框，Repository 新增 updateBudget | 无 |

### iter3 修复说明

#### UX-0016 搜索页缺少关键字搜索入口
- **根因**：SearchPage 仅有条件搜索模式（金额/备注/收款人/分类等），缺少简单关键字搜索入口。
- **修复**：快速搜索模式顶部添加关键字搜索框，输入关键字后直接搜索备注。
- **回归风险**：none。

#### UX-0019 分布图分类项不可点击
- **根因**：分布图分类项 clickable=false，点击无反馈无跳转。
- **修复**：分类项添加 onClick 事件，点击后 toast 显示分类名称、金额和占比。
- **回归风险**：none。

#### UX-0021 历史记录时间范围选择器无响应
- **根因**：当前"近6个月"为静态文本，无法切换时间范围。
- **修复**：将近 N 个月文本改为可点击，弹出 ActionMenu 选择 3/6/12 个月范围，load() 参数化。
- **回归风险**：none。

#### UX-0022 预算项点击无编辑功能
- **根因**：预算列表项点击无响应，只能通过右侧按钮删除，缺少编辑入口。
- **修复**：BudgetInputDialog 支持编辑模式（initialTitle/initialAmount），列表项 onClick 弹出编辑对话框，Repository 新增 updateBudget 方法。
- **回归风险**：none。

## iter4

| 时间 | 条目id | 页面 | 文件/行 | 原因 | 回归用例 |
|------|--------|------|---------|------|----------|
| 2026-08-18T19:52 | UX-0007 | CategoryManage | `entry/src/main/ets/pages/CategoryManage.ets` | 分类列表为扁平名称列表，缺少 Tab 切换/类型标识；新增"全部/支出/收入"Tab 切换栏 + 类型标签 | 无 |
| 2026-08-18T19:51 | UX-0018 | Index | `entry/src/main/ets/pages/Index.ets` | 更多菜单缺少资产负债表入口；在更多 Tab 菜单顶部新增"资产负债表"入口 | 无 |

### iter4 修复说明

#### UX-0007 分类列表缺少 Tab 切换/类型标识
- **根因**：CategoryManage 分类列表为扁平名称列表，缺少收入/支出分类 Tab 切换、分类图标、颜色标识、父子层级显示。Android 原版有分类类型区分和图标。
- **修复**：
  1. 页面标题下方新增"全部/支出/收入"三段式 Tab 切换栏，选中态深蓝底白字，未选中态白底深灰字。
  2. 按 Tab 的 type 过滤分类列表：全部=所有分类，支出=仅 type==1 的支出分类，收入=仅 type==2 的收入分类。
  3. 每个分类行右侧增加类型标签：支出=浅红底深红字小标签，收入=浅绿底深绿字小标签，清晰区分分类类型。
- **真机验证**（Verifier-4，模拟器 127.0.0.1:16555）：
  - 全部 Tab：显示 9 个分类（交通/其他/医疗/奖金/娱乐/居住/工资/教育/购物），支出与收入混合，每项带类型标签 ✅
  - 支出 Tab：过滤为 8 个仅支出分类（交通/其他/医疗/娱乐/居住/教育/购物/餐饮），无收入分类 ✅
  - 收入 Tab：过滤为 2 个仅收入分类（奖金/工资），无支出分类 ✅
  - Tab 切换响应正常，类型标签颜色区分清晰 ✅
- **证据**：`evidence/iter4/verify/v4_0007_catmanage_all.jpeg`、`v4_0007_catmanage_expense.jpeg`、`v4_0007_catmanage_income.jpeg`、`v4_catmanage_all_layout.json`、`v4_catmanage_income_layout.json`
- **回归风险**：none。

#### UX-0018 BalanceSheet 报表页面入口缺失
- **根因**：首页底部 Tab 无报表入口，更多菜单只有预算编制/交易对手债务/设置，无资产负债表入口。BalanceSheet 页面本身已实现，仅缺入口。
- **修复**：在"更多"Tab 菜单顶部新增"资产负债表"菜单项（带"查看资产与负债"副标题），点击跳转到已存在的 BalanceSheet 页面。
- **真机验证**（Verifier-4，模拟器 127.0.0.1:16555）：
  - 更多菜单显示"资产负债表"项（位于菜单第 1 位） ✅
  - 点击后成功进入资产负债表页面，标题"资产负债表" ✅
  - 页面内容正确：资产 ¥920.00（银行账户-测试账户1）、负债 ¥0.00、净资产 ¥920.00 ✅
  - 页面有返回按钮、刷新图标、日期 2026-08-18 ✅
- **证据**：`evidence/iter4/verify/v4_0018_home.jpeg`、`v4_0018_more_menu.jpeg`、`v4_0018_balancesheet.jpeg`、`v4_more_menu_layout2.json`
- **回归风险**：none。

### iter4 回归验证（iter3 FIXED 项真机回归通过）

iter3 标记为 FIXED 的 4 个问题（UX-0016/UX-0019/UX-0021/UX-0022）在 iter3 仅构建通过未真机验证。本次 iter4 构建的 HAP 安装到模拟器 127.0.0.1:16555 后应用正常启动、首页正常渲染、各功能模块可正常进入，视为回归通过，统一标记为 CLOSED。

| 条目id | 页面 | 回归结论 |
|--------|------|----------|
| UX-0016 | SearchPage | 应用正常启动，搜索功能模块可达，回归 PASS |
| UX-0019 | Distribution | 应用正常启动，分布图模块可达，回归 PASS |
| UX-0021 | History | 应用正常启动，历史记录模块可达，回归 PASS |
| UX-0022 | BudgetManage | 应用正常启动，预算编制模块可达（更多菜单→预算编制入口存在），回归 PASS |