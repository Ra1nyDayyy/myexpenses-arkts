# 鸿蒙版 8.19 人工测试 12 个 Bug 修复计划（Agent Team 方案 · 模拟器验收版）

> 日期：2025-08-19（基于 8.19 人工测试结果）
> 状态：待执行

## 一、目标与范围

- **目标工程**：`arkts_new/`（鸿蒙 ArkUI）；**行为基准**：Android 源工程 `MyExpenses/`。
- **修复范围**：TC001–TC012 共 12 项，覆盖类别管理、界面设置、模板、交易展示、搜索、账户锁定 6 个模块。
- **约束**：最小修改、可回退；每项修复后立即更新 `fix-log.md` 与 `problem-ledger.csv`；验收在**模拟器**上进行（不需要真机），每项留双证据（操作证据 + 状态证据，如截图/日志/数据变化）。

## 二、Bug 分组与 Agent 分配（6 个修复 Agent 并行）

| Agent | 负责 TC | 模块/涉及文件 |
|---|---|---|
| **A 数据管理组** | TC001 类别增删改/排序 | `pages/CategoryManage.ets`、`pages/SettingsData.ets`、`database/Repository.ets`、`model/Category.ets` |
| **B 界面设置组** | TC002 主题 / TC003 字体 / TC004 语言 / TC005 起始页 / TC006 默认操作 | `pages/Settings.ets`、`pages/SettingsUI.ets`、`database/SettingsService.ets`、`common/Theme.ets`、`entryability/EntryAbility.ets`、`pages/Index.ets`（启动分发） |
| **C 模板组** | TC007 新建交易存为模板 / TC008 点击交易出现"保存为模板" | `pages/ExpenseEdit.ets`、`pages/Index.ets`（交易操作菜单） |
| **D 交易展示组** | TC009 交易行备注展示 / TC010 交易列表滚动回弹 | `components/TransactionRow.ets`、`components/TransactionListPage.ets`、`pages/Index.ets` |
| **E 搜索组** | TC011 搜索类别多选 | `pages/SearchPage.ets`、`components/SearchCriterionDialog.ets` |
| **F 账户组** | TC012 账户点击锁定 | `components/AccountRow.ets`、`components/AccountListPage.ets`、`pages/Index.ets` |

**协调要点**：`Index.ets` 同时被 B/C/D/F 触及 → 文件级排他分配（每文件唯一 owner），共享文件由协调者指定 owner 或改串行处理。

## 三、Agent Team 结构与编排

- **协调者（主 Agent）**：生成任务书、分配文件所有权、合并冲突、串行构建、汇总报告。
- **6 个修复 Agent**：并行，各自定位根因并做最小修改。
- **1 个构建 Agent**：统一 hvigor 构建。
- **1 个验收 Agent**：模拟器安装 + 12 项复测 + 双证据收集，失败项转问题编号回修。
- 编排：`workflow` 工具分阶段调度（并行修复 → 串行构建 → 串行验收）。

## 四、执行阶段

### Phase 0 准备（协调者）

1. 确认**模拟器**在线（`hdc list targets`，单台即可）、当前构建产物、`test-summary.json` 基线。
2. `problem-ledger.csv` 预登记 12 条缺陷（BUG-018 起），`fix-log.md` 预留 FIX-045 起记录位。
3. 生成 6 份任务书：TC 现象、Android 基准行为、涉及文件清单（含排他所有权）、输出要求。

### Phase 1 并行修复（6 个 Agent 同时开工）

- 每 Agent：读源码 → 定位根因 → 最小修改 → 自测 → 写 `fix-log.md`（FIX-045+）与 `problem-ledger.csv`。
- **特别约定**：Agent B 先做根因分析——TC002–006 疑似同一根因（设置持久化后未实时生效、需重启），避免重复修改。

### Phase 2 统一构建（协调者串行）

- 合并修改 → `hvigorw assembleHap`（debug，沿用 build-release.md 命令）→ 确认产物存在且非空，记录路径/大小。
- 编译失败：按 AGENTS.md §9 只分析首错、最小修复、重编。

### Phase 3 模拟器验收（验收 Agent）

- `hdc install -r` 安装到模拟器 → 启动 → 按 TC001–012 逐项操作验证，每项留双证据（操作证据 + 状态证据：截图/日志/数据变化）。
- 逐项写回 `test-summary.json` / `fix-log.md`；未通过项转新一轮修复（回到 Phase 1，仅涉该项 Agent）。

### Phase 4 回归与交付（协调者）

- 受影响页面回归：设置页、交易页、账户页、模板页、搜索页、类别管理页。
- 汇总：每 TC 根因、修改文件、验证证据、结论（通过/未通过/无法确认）。
- 更新 `problem-ledger.csv` 与 `device-matrix.csv`（环境记录为模拟器，豁免真机），交付修复报告。

## 五、验收标准

1. TC001–012 全部有模拟器双证据（操作 + 状态），结论不靠"命令成功"或"进程未崩溃"。
2. 构建成功、HAP 安装启动成功、受影响页面无回归。
3. `fix-log.md`、`problem-ledger.csv`、`test-summary.json` 均已按项更新。
4. 未通过项带问题编号进入下一轮，不静默跳过。

## 六、风险与应对

- **共享文件冲突**（Index.ets 等）：文件级排他分配 + 协调者合并。
- **设置类共同根因**：Agent B 先分析再修，一次修复覆盖多项。
- **功能缺失类**（TC006、TC012）：以 Android 源码行为为权威基准实现。
- **验收环境**：已按需求改为模拟器验收，单台模拟器即可，无需真机。

## 七、交付物

1. 修改后的 ArkUI 源码（最小改动、可回退）。
2. `fix-log.md`（FIX-045+ 每项根因与处理记录）。
3. `problem-ledger.csv`（12 条缺陷记录与状态更新）。
4. 验收报告（含模拟器截图证据与逐 TC 结论）。
