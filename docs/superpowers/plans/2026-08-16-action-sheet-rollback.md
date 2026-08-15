# 大型 ActionSheet 交互回退 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除应用中的系统 `showActionSheet`，将页面级操作恢复为独立 Tab，将工具操作恢复为页面内展开，将短选择恢复为锚定菜单，并完整保留现有回调。

**Architecture:** `Index` 使用页面状态控制交易工具区、模板操作区、批量标签区和第四个“更多”Tab；`ExpenseEdit` 使用行内展开承载拆分项及附件操作；`AccountEdit` 使用可滚动说明 Dialog；`BalanceSheet` 使用顶栏 `bindMenu`。所有新增状态只负责展示，不写入 Repository。

**Tech Stack:** HarmonyOS ArkTS、ArkUI `Tabs`、`List`、`Flex`、`Button`、`Toggle`、`bindMenu`、`CustomDialogController`、Hypium/Hvigor、HDC 模拟器。

## Global Constraints

- 源码最终不得出现 `showActionSheet`。
- 不删除任何现有入口，不修改业务回调参数与 Repository 调用。
- 所有新操作按钮命中区至少 48 vp。
- 长列表必须滚动，小屏按钮必须自动换行。
- 删除操作继续使用独立危险确认 Dialog。
- 当前工作区已有用户改动，不自动 stage 或 commit；每个任务后用限定路径差异复核代替提交。

---

### Task 1: 恢复“更多”Tab 与交易页内工具区

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets:44-75, 470-665, 820-930, 1800-2030`
- Verify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: `navigateToAi()`, `navigateToDistribution()`, `navigateToHistory()`, `navigateToSearch()`, `cycleGrouping()`, `cycleSortOrder()`, `exportCsv()`, `pathStack`。
- Produces: `@State transactionToolsExpanded: boolean`、`moreTab()`、`moreMenuRow(...)`、`transactionToolsPanel()`。

- [ ] **Step 1: 建立回归基线并确认失败**

Run:

```bash
rg -n "showActionSheet\(" entry/src/main/ets/pages/Index.ets
```

Expected: 输出 `showMoreDialog` 和 `showTransactionActions` 等调用，证明当前不符合回退要求。

- [ ] **Step 2: 恢复第四个实际 Tab**

在根 `Tabs` 中加入：

```ets
TabContent() {
  this.moreTab()
}
```

将 `moreTabBuilder()` 的点击改为：

```ets
this.selectedTab = 3;
this.transactionToolsExpanded = false;
```

`moreTab()` 使用 `PageHeader`/标题行与 `List` 展示 8 个入口，逐项复用现有回调：AI、类别、付款方法、标签、资产负债表、预算、债务、设置。

- [ ] **Step 3: 实现交易工具折叠区**

新增状态：

```ets
@State transactionToolsExpanded: boolean = false;
```

交易右上角按钮只切换该状态；`transactionToolsPanel()` 使用可换行 `Flex`，按钮为分组、排序、分布图、历史记录、导出 CSV、筛选。每个按钮执行原方法后收起面板，分组和排序按钮文案显示当前值。

- [ ] **Step 4: 删除两个系统 ActionSheet**

删除 `showMoreDialog()` 与 `showTransactionActions()` 的 `ActionSheetOptions` 组装；保留其中的原回调方法。

- [ ] **Step 5: 编译并复核回调映射**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon --error
```

Expected: exit 0。

Run:

```bash
git diff --check -- entry/src/main/ets/pages/Index.ets
```

Expected: 无输出。

---

### Task 2: 将模板操作与周期设置改为行内展开

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets:60-75, 1030-1420`
- Verify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: `navigateToTemplateEdit()`, `generatePlan()`, `applyRecurrence()`, `toggleAutoExecute()`, `pickPlanStartDate()`, `applyAdvanceDays()`, `confirmDeleteTemplate()`。
- Produces: `@State expandedTemplateId: number`、`templateActionPanel(tpl)`、`recurrenceMenu(tpl)`、`advanceDaysMenu(tpl)`。

- [ ] **Step 1: 记录当前失败点**

Run:

```bash
rg -n "showTemplateMenu|setRecurrence|setAdvanceDays|showActionSheet" entry/src/main/ets/pages/Index.ets
```

Expected: 三组模板 ActionSheet 均存在。

- [ ] **Step 2: 模板长按切换行内展开**

模板行长按时执行：

```ets
this.expandedTemplateId = this.expandedTemplateId === tpl.id ? -1 : tpl.id;
```

当 `expandedTemplateId === tpl.id` 时，在模板卡下方渲染 `templateActionPanel(tpl)`。

- [ ] **Step 3: 实现模板操作区**

操作区包含：编辑、生成计划（仅有周期时）、设置周期、自动执行开关、下次执行日期、提前执行天数、删除。周期和提前天数按钮分别：

```ets
.bindMenu(this.recurrenceMenu(tpl))
.bindMenu(this.advanceDaysMenu(tpl))
```

菜单元素直接调用现有 `applyRecurrence(tpl, value)` 和 `applyAdvanceDays(tpl, days)`。

- [ ] **Step 4: 移除模板 ActionSheet 方法**

删除 `showTemplateMenu()`、`setRecurrence()`、`setAdvanceDays()` 的 ActionSheet 实现；保留 `apply...`、日期选择和危险确认方法。

- [ ] **Step 5: 编译与静态检查**

运行 Task 1 的 `assembleHap` 命令，Expected: exit 0。

Run:

```bash
rg -n "showTemplateMenu|showActionSheet" entry/src/main/ets/pages/Index.ets
```

Expected: 不再出现模板相关 ActionSheet。

---

### Task 3: 回退账户选项、账户标记与批量标签

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets:65-80, 720-815, 1550-1665, 1700-1795, 2420-2590`
- Modify: `entry/src/main/ets/components/AccountRow.ets:10-35, 160-235`
- Verify: both files above

**Interfaces:**
- Consumes: `navigateToAccountEdit()`, `showAccountTypes()`, `showAccountFlagsManage()`, `toggleShowEquivalent()`, `applyAccountFlag()`, `repository.updateTransaction()`。
- Produces: `@State batchTagPickerExpanded: boolean`、`@State accountFlagTargetId: number`、`accountOptionsPanel()`、`batchTagPanel()`；`AccountRow` 新增 `flags` 与 `onApplyFlag` 属性。

- [ ] **Step 1: 记录当前账户相关 ActionSheet**

Run:

```bash
rg -n "showAccountOptions|pickTag|setAccountFlag|showActionSheet" entry/src/main/ets/pages/Index.ets
```

Expected: 账户选项、标签和标记选择仍依赖 ActionSheet。

- [ ] **Step 2: 补齐账户 FAB 展开操作**

在现有账户 FAB 展开菜单中增加新建账户、账户类型、账户标记管理、显示等值、资产负债表，逐项复用原回调。移除 `showAccountOptions()`。

- [ ] **Step 3: 批量标签改为多选栏下方展开**

点击多选栏“标签”只切换 `batchTagPickerExpanded`；面板用 `Flex` 显示 `this.tags`。点击标签后执行当前 `batchAddTag` 的循环更新逻辑，然后退出选择模式并刷新。

- [ ] **Step 4: 账户标记改为账户卡内锚定菜单**

页面加载账户标记列表并传入 `AccountRow`。`AccountRow` 的“标记”按钮使用 `bindMenu`，每个 `MenuElement.action` 调用 `onApplyFlag(account.id, flag.id)`。移除 `setAccountFlag()` 的 ActionSheet。

- [ ] **Step 5: 编译与功能映射检查**

运行 `assembleHap`，Expected: exit 0。

Run:

```bash
git diff --check -- entry/src/main/ets/pages/Index.ets entry/src/main/ets/components/AccountRow.ets
```

Expected: 无输出。

---

### Task 4: 将交易编辑页的表单操作改为行内展开

**Files:**
- Modify: `entry/src/main/ets/pages/ExpenseEdit.ets:25-70, 490-790, 900-1450`
- Verify: `entry/src/main/ets/pages/ExpenseEdit.ets`

**Interfaces:**
- Consumes: `toggleOriginalAmount()`, `editSplitPartAmount()`, `selectSplitPartCategory()`, `takePhoto()`, `pickPhoto()`, `pickDocument()`、已有标签数据。
- Produces: `@State expandedSplitPartIndex: number`、`@State attachmentSourcesExpanded: boolean`、拆分项行内操作区与附件来源区。

- [ ] **Step 1: 记录当前编辑页 ActionSheet**

Run:

```bash
rg -n "showEditOptions|editSplitPart\(|selectSplitPartTag|pickAttachment|showActionSheet" entry/src/main/ets/pages/ExpenseEdit.ets
```

Expected: 四类系统 ActionSheet 存在。

- [ ] **Step 2: 原始金额改为表单内开关**

删除右上角 `showEditOptions()`；在金额行下方加入“显示原始金额”开关，`onChange` 调用 `toggleOriginalAmount()`，模板模式不显示。

- [ ] **Step 3: 拆分项改为行内操作**

点击编辑图标切换 `expandedSplitPartIndex`。展开区包含编辑金额、选择分类、标签 chips、删除。标签点击直接更新该 `part.tagIds` 并刷新 `splitParts`；删除仍使用红色按钮，并保持当前删除数组逻辑。

- [ ] **Step 4: 附件来源改为展开按钮组**

点击“添加附件”切换 `attachmentSourcesExpanded`；显示拍照、相册、文件三个 48 vp 按钮，分别调用现有方法并在调用后收起。

- [ ] **Step 5: 删除编辑页 ActionSheet 并编译**

Run:

```bash
rg -n "showActionSheet\(" entry/src/main/ets/pages/ExpenseEdit.ets
```

Expected: 无输出。

运行 `assembleHap`，Expected: exit 0。

---

### Task 5: 回退帮助说明与资产负债表选项

**Files:**
- Create: `entry/src/main/ets/components/AccountFieldHelpDialog.ets`
- Modify: `entry/src/main/ets/pages/AccountEdit.ets:220-295, 335-365`
- Modify: `entry/src/main/ets/pages/BalanceSheet.ets:650-710` and header call site
- Verify: all three files above

**Interfaces:**
- Consumes: `AccountEdit.showFieldHelp()`、`BalanceSheet.optionsMenu()`、`exportToPdf()`。
- Produces: `AccountFieldHelpDialog`、`BalanceSheet.moreMenu(): Array<MenuElement>`。

- [ ] **Step 1: 建立失败基线**

Run:

```bash
rg -n "showActionSheet\(" entry/src/main/ets/pages/AccountEdit.ets entry/src/main/ets/pages/BalanceSheet.ets
```

Expected: 两个页面均有匹配。

- [ ] **Step 2: 创建可滚动字段帮助 Dialog**

`AccountFieldHelpDialog` 使用固定标题、限高 `Scroll` 和底部 48 vp “知道了”按钮。说明项以标题加正文展示，不绑定点击行为。

- [ ] **Step 3: AccountEdit 接入帮助 Dialog**

`showFieldHelp()` 重建并打开 `CustomDialogController`；删除原 `SheetInfo` 列表。

- [ ] **Step 4: BalanceSheet 使用锚定菜单**

新增 `moreMenu()`：复制 `optionsMenu()` 的元素，并追加“导出为 PDF”。顶栏更多按钮通过 `bindMenu` 使用该数组；删除 `showOptionsSheet()`。

- [ ] **Step 5: 编译与静态扫描**

运行 `assembleHap`，Expected: exit 0。

Run:

```bash
rg -n "showActionSheet\(" entry/src/main/ets
```

Expected: 无输出。

---

### Task 6: 全量验证、模拟器验收与报告更新

**Files:**
- Modify: `migration/native-harmony-ui-modification-report.md`
- Verify: all changed ArkTS files

**Interfaces:**
- Consumes: Tasks 1-5 的最终 UI。
- Produces: 构建产物、测试结果、模拟器截图和更新后的报告。

- [ ] **Step 1: 全量源码守卫**

Run:

```bash
rg -n "showActionSheet\(|ActionSheetOptions|SheetInfo" entry/src/main/ets
```

Expected: 无输出。

- [ ] **Step 2: 全量测试**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test \
  --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon --error
tail -n 1 entry/.test/default/intermediates/test/coverage_data/test_result.txt
```

Expected: 56 tests, 0 failure, 0 error。

- [ ] **Step 3: 最终 HAP 构建**

运行 Task 1 的 `assembleHap` 命令，Expected: exit 0，产物为 `entry/build/default/outputs/default/entry-default-unsigned.hap`。

- [ ] **Step 4: 安装并验收模拟器**

安装并启动：

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
"$HDC" -t 127.0.0.1:5557 install -r entry/build/default/outputs/default/entry-default-unsigned.hap
"$HDC" -t 127.0.0.1:5557 shell aa start -a EntryAbility -b org.totschnig.myexpenses
```

验收：交易工具展开/收起、更多 Tab 8 个入口、模板行展开、批量标签、账户标记、拆分项、附件来源、帮助说明、资产负债表菜单。不得触发保存或删除。

- [ ] **Step 5: 更新报告并检查差异**

报告写明 ActionSheet 回退映射、测试结果和模拟器证据。

Run:

```bash
git diff --check -- entry/src/main/ets docs/superpowers migration/native-harmony-ui-modification-report.md
```

Expected: 无输出。

