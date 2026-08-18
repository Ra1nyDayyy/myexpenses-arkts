# 体验优化 + 智能 Agent 模拟真实用户体验 计划（多 Agent 团队版）

> 角色：Planner Agent（本轮只交付计划文档，不执行）
> 目标工程：`/Users/rainyday/Desktop/migration/arkts_new`（myexpenses-arkts，ArkTS / ArkUI）
> 状态：迁移工作已完成（`currentStage: ACCEPTANCE_CANDIDATE`），本计划面向**迁移后的体验优化阶段**
> 核心策略：**最大化使用 Agent 团队并行编排**，通过智能 Agent 在模拟器上以真实用户方式交互式操作应用，发现问题即修复，并持续回归验证

---

## 0. 结论摘要

- **目标**：对已迁移完成的 ArkUI 记账应用（arkts_new）做体验优化，覆盖全部页面；用智能 Agent 在模拟器上模拟真实用户操作（点击/输入/滑动/返回/深浅色切换），发现体验问题后**直接修复并回归验证**。
- **方式**：多 Agent 团队编排 —— Orchestrator 总体规划，Simulator 模拟用户并行走查，UX Auditor 判定问题，Fixer 并行修复，Verifier 回归验证，Evidence Agent 统一归档。
- **交付物**：本文档为执行蓝图；后续每轮执行产出问题账本（ledger）、修复日志（fix-log）、截图/dump/DB 证据、汇总报告，并交用户按迭代节奏 review。
- **已知前置阻塞**：当前模拟器未在线（`hdc list targets` 为空），Release 签名未配置（只能验证 debug unsigned HAP）——均已在 M0 处理并如实记录，不伪造证据。

---

## 1. 背景与现状盘点

### 1.1 迁移完成度

| 项 | 现状 |
|---|---|
| 门禁阶段 | `ACCEPTANCE_CANDIDATE`（迁移验收主体完成） |
| 声明验收页面 | Main（empty/account_list）、AccountEdit、ExpenseEdit、AiAssistant，LIGHT/DARK × PORTRAIT × zh-CN，横屏豁免 |
| 资源限定目录 | `resources/base` + `resources/dark`（深色已映射） |
| 构建 | `hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon` → `entry-default-unsigned.hap`（约 3.15 MB） |
| 安装/启动 | `hdc install -r <hap>`；`hdc shell aa start -a EntryAbility -b org.totschnig.myexpenses` |

### 1.2 页面与导航现状（全页面覆盖的基础）

- 页面文件：`entry/src/main/ets/pages/` 下共 **21 个 `.ets`**，约 14,700 行。
- 注册路由（`main_pages.json`，13 条）：
  `Index, AccountEdit, ExpenseEdit, CategoryManage, CategorySelect, MethodManage, TagManage, TagSelect, SearchPage, BalanceSheet, Settings, Distribution, History`
- NavDestination 挂载（`Index.ets pageMap`）：`BudgetManage, DebtManage, BudgetEdit`。
- `router.pushUrl` 实际可达并带跳转次数的页面：
  `TagManage(4), Settings(4), MethodManage(3), ExpenseEdit(3), CategoryManage(3), CategorySelect(2), BalanceSheet(2), AiAssistant(2), AccountEdit(2), TagSelect(1), SearchPage(1), History(1), Distribution(1)`。
- 页面体量分布（行数）：`Index(2939), AiAssistant(3155), ExpenseEdit(1712), CategorySelect(1328), BalanceSheet(1062), AccountEdit(631), SearchPage(446), Settings(383)` 为高复杂度大页，其余为中/小页。

> 覆盖原则：**以 21 个页面文件为全集**，逐一建立"进入入口 + 模拟场景 + 深色态 + 关键交互"矩阵（见 §5），对未出现在上述跳转源中的页面（如 SettingsMain/SettingsUI/SettingsData/SettingsIO）在 M1 中核对其真实入口并补录。

### 1.3 已有可复用资产（避免重复建设）

| 资产 | 位置 | 复用方式 |
|---|---|---|
| 上一轮 AI 字段级测试全套 | `AI_test/`（test plan / progress / fix report / evidence/{ui,logs,db}） | 复用其操作证据规范、DB 备份恢复法、模拟器操作词表（`uitest dumpLayout` / `uitest uiInput` / `snapshot_display`） |
| 功能/UI 测试报告 | `arkts_new/docs/testing/`（ACCOUNT/THEME/SETTINGS/AI_FUNCTION/FINAL_REGRESSION 等） | 复用已验证功能基线，体验优化不重复验证功能 |
| 本地 LLM 网关 | `migration/codearts_api.py`（OpenAI 兼容，默认 8765 端口） | Simulator/Fixer 的模型推理入口（如 AI 对话页面模拟需要真实模型响应时） |
| 既有证据目录 | `evidence/`（工程级）、`docs/testing/evidence/` | 新增 `docs/ux-optimization/evidence/` 独立归档 |

### 1.4 环境事实（本计划直接复用，不重复探测）

- 系统：macOS 15.7.7（arm64）
- hdc：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`（不在 PATH，需绝对路径调用）
- 模拟器二进制：`/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator`
- 模拟器设备模板（emulator.json）：`Huawei_Phone`（API 11/12/13，1260×2720，density 520）、`Huawei_Foldable`、`Huawei_Tablet`
- 以往使用过的模拟器地址：`127.0.0.1:15558`、`127.0.0.1:5555`

---

## 2. 目标与验收口径

### 2.1 体验优化维度（Simulator/UX Auditor 的判定框架）

| 维度 | 检查要点 |
|---|---|
| D1 可用性 | 核心记账链路（增/改/删/查）步骤数、必填校验时机、误触概率、返回路径 |
| D2 视觉还原 | 对 Android 原图：间距/圆角/字号/颜色/图标一致性（沿用迁移期"微妙圆角"风格），深色模式无发灰发虚 |
| D3 反馈与状态 | 点击有响应（按压态）、loading/空态/错误态/成功态齐全且文案准确 |
| D4 输入体验 | 中文输入、数字键盘、输入法弹起不遮挡字段、金额/日期控件易用性 |
| D5 导航与可达 | 底部 Tab、更多菜单、面包屑/返回、深层页面入口一致、无死链 |
| D6 动效与性能感知 | 页面切换流畅、列表滚动不掉帧、无明显白屏/闪烁 |
| D7 深色主题 | dark 限定目录覆盖无遗漏，对比度达标 |
| D8 无障碍 | accessibilityText/标签存在，TalkBack 可读（抽查） |
| D9 文案与本地化 | 中文文案无英文残留、无截断、无错别字 |

### 2.2 验收口径

- **发现即修复**：Simulator 走查发现的问题直接进入修复队列（无需用户先确认），但修复遵循最小修改、可回退原则（AGENTS.md §1/§6）。
- **每项修复双证据**：操作证据（hdc/uitest 命令及返回）+ 状态证据（截图/dumpLayout 变化或 DB 实测），证据落盘后才算完成。
- **人工 review 节奏**：每个迭代轮次（M1→M4）结束出一份汇总（账本 + 关键截图 + 修复清单），用户 review 后进入下一轮；用户可中途指定优先项。
- **不回归的功能边界**：本阶段只处理体验问题；功能行为回归由既有 `docs/testing/` 基线覆盖，若修复波及功能则必须跑对应回归用例。

---

## 3. 多 Agent 团队架构与并行编排（核心）

### 3.1 角色分工

| 角色 | 职责 | 并行度 |
|---|---|---|
| **Orchestrator（主控）** | 总规划、分片、构建队列调度、账本合并、迭代节奏、用户 review 输出 | 1（主线程） |
| **Simulator（用户模拟器）** | 每个 Agent 领 1 组页面/1 条用户旅程，在模拟器上真实操作（点击/输入/滑动/返回/深色切换），记录每一步的 dumpLayout+截图 证据；遇到疑似问题上报 | 多 Agent 并行（按页面分片，≥4 路） |
| **UX Auditor（体验审计）** | 对 Simulator 上报的 dump/截图按 §2.1 九维度判定，产出结构化问题条目（id/页面/严重度/复现/证据/建议） | 与 Simulator 流水衔接，2 路并行 |
| **Fixer（修复 Agent）** | 按页面/模块领取问题，读源码 → 最小修改 → 交给构建队列 | 按问题分片并行（≥3 路） |
| **Verifier（回归验证 Agent）** | 对修复后的 HAP 重装，重放该问题场景，确认修复 + 无副作用，存档双证据 | 并行（≥2 路），每次只操作自己分配的场景 |
| **Evidence/Report（证据归档）** | 统一写入 ledger/fix-log/evidence 目录，维护进度与汇总 | 1（串行收口） |

### 3.2 并行流水（单迭代示例）

```
M1 分片准备（Orchestrator）
   ├─ 页面分片表（21 页 → 4~6 组，按入口/依赖关系聚类）
   ├─ 场景脚本 × N（用户旅程 + 每页状态/深色/输入场景）
   └─ 模拟器实例准备（多实例 or 单实例时间片，见 §3.3）

M2 并行走查（Simulator × N 并行）
   │   每个 Simulator：入口 → 逐步操作 → 每步截图+dump 存档 → 疑似问题上报
   ▼
M3 审计判定（UX Auditor × 2，流水消费）
   ▼
M4 问题分派与并行修复（Fixer × 3）
   │   修改 → 提交变更说明（文件/行/原因）→ 进构建队列
   ▼
M5 串行构建（Orchestrator 统一调度 hvigor，避免并发写同一 build 目录）
   ▼
M6 并行回归（Verifier × 2：安装新 HAP → 重放场景 → 双证据存档）
   ▼
M7 账本合并 + 汇总报告（Evidence Agent）→ 用户 review → 下一迭代
```

### 3.3 模拟器并发策略（关键约束）

- **约束1：构建并发冲突** —— hvigor 对同一工程并发构建会写同一 `entry/build` 目录，**构建必须由 Orchestrator 串行统一执行**（Fixer 只改源码不构建；一次迭代出 1 个 HAP）。
- **约束2：设备操作互斥** —— 多 Simulator 同时操作同一模拟器会互相干扰（前台页面被抢占）。
  - 方案 A（推荐）：**同一迭代内单模拟器实例 + 时间片**；Simulator 数量 = 页面组数，但并发上限设为 1~2 个前端操作实例，其余组排队；
  - 方案 B：启动**多个模拟器实例**（不同端口，如 5555/5557/15558），每组 Simulator 绑定独立实例，互不干扰，走查速度最快；代价是内存占用高（每实例 4GB RAM 配置）。
  - 决策建议：**先按方案 B 评估本机资源（闲置内存决定实例数），不足则回落方案 A**；方案在 M0 用一次实测确认并写入 `env_decision.md`。

### 3.4 Agent 团队规模建议（"最大化使用"的落点）

- Simulator：4~6 路（按分片）
- UX Auditor：2 路（流水消费，不阻塞 Simulator）
- Fixer：3~4 路（问题按页面归属聚类，跨页耦合问题时由 Orchestrator 单独路由给 1 路避免边冲突）
- Verifier：2 路
- 总计约 12 路并发上限；以"设备实例数"与"问题间依赖"为实际瓶颈而非 LLM 并发。
- 并行度原则：**只在无共享状态的工作上并行**（走查、审计、独立页面修复、独立场景回归）；共享资源（构建、设备前台、DB、账本文件）一律串行或加锁。

---

## 4. 工具链与操作词表（Agent 复用，减少试错）

所有命令封装为可粘贴模板，Simulator/Verifier 直接复用（不做环境重复探测）。

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator

# 模拟器启停
$EMU -start <InstanceName>            # 启动（InstanceName 需先 -create 或复用既有 AVD）
$HDC list targets                     # 确认在线（返回 127.0.0.1:port 即就绪）

# 构建（Orchestrator 串行）
cd /Users/rainyday/Desktop/migration/arkts_new
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon

# 安装/启动/停止
$HDC install -r entry/build/default/outputs/default/entry-default-unsigned.hap
$HDC shell aa start -a EntryAbility -b org.totschnig.myexpenses
$HDC shell aa force-stop org.totschnig.myexpenses

# 界面证据：布局 dump + 截图
$HDC shell uitest dumpLayout          # 输出控件树（含 bounds/text）到 /data/local/tmp，再 file recv
$HDC shell snapshot_display          # 截图（即时），file recv 到 evidence/<场景>/<步>_ui.png
$HDC file recv <设备路径> <本地路径>

# 交互（坐标以 dumpLayout bounds 为准，禁止复用旧坐标）
$HDC shell uitest click <x> <y>
$HDC shell uitest swipe <x1> <y1> <x2> <y2>
$HDC shell uitest uiInput text '<中文文本>'     # 需先点击 TextInput 聚焦（上一轮已验证此路可用）

# 数据证据（写操作类场景）
$HDC shell aa force-stop org.totschnig.myexpenses
$HDC file recv /data/app/el2/100/base/org.totschnig.myexpenses/haps/entry/files/myexpenses.db ./evidence/db/  # 路径以实际为准
# sqlite3 查询比对插入/删除结果；操作前先 recv 备份基线（复用 AI_test 备份法）

# 深浅色切换（如支持）
$HDC shell settings put system color_mode 2      # 2=深色 1=浅色（以设备实际配置为准，先 dump 确认）
```

---

## 5. 全页面覆盖矩阵（执行时的检查清单底稿）

| # | 页面文件 | 入口 | 走查场景（含深色） | 关键交互 | 优先级 |
|---|---|---|---|---|---|
| 1 | Index.ets | 启动即达 | 空态 / 有数据 / 深色 | Tab 切换、更多菜单、列表滚动 | P0 |
| 2 | AccountEdit.ets | Index 点账户 / 新建 | 默认 / 深色 | 表单、保存/取消、返回 | P0 |
| 3 | ExpenseEdit.ets | Index 记录按钮 / 条目点按 | 默认 / 深色 | 金额键盘、分类选择、日期、保存 | P0 |
| 4 | CategoryManage.ets | 设置/分类管理 | 默认 / 深色 | 增删改分类 | P1 |
| 5 | CategorySelect.ets | 记账时选分类 | 默认 / 深色 | 搜索、单选、滚动 | P1 |
| 6 | MethodManage.ets | 设置/付款方式 | 默认 / 深色 | 增删改方式 | P1 |
| 7 | TagManage.ets | 设置/标签 | 默认 / 深色 | 增删改标签 | P1 |
| 8 | TagSelect.ets | 记账时选标签 | 默认 / 深色 | 多选、搜索 | P1 |
| 9 | SearchPage.ets | Index 搜索入口 | 默认 / 深色 / 空结果 | 关键字搜索、筛选、结果点按 | P1 |
| 10 | BalanceSheet.ets | Index 报表入口 | 默认 / 深色 / 空数据 | Tab 切换、图表、导出 | P1 |
| 11 | Distribution.ets | Index 分布入口 | 默认 / 深色 / 空数据 | 图表交互 | P1 |
| 12 | History.ets | Index 历史入口 | 默认 / 深色 | 列表加载、筛选、滚动 | P1 |
| 13 | Settings.ets | Index 更多→设置 | 默认 / 深色 | 分组列表、跳转 | P0 |
| 14 | SettingsMain / SettingsUI / SettingsData / SettingsIO.ets | 归属核实（M1 补录） | 默认 / 深色 | 各设置项 | P2 |
| 15 | BudgetManage / BudgetEdit.ets | NavDestination pageMap | 默认 / 深色 | 预算增删改、金额输入 | P1 |
| 16 | DebtManage.ets | NavDestination pageMap | 默认 / 深色 | 债务增删改 | P1 |
| 17 | AiAssistant.ets | Index AI 入口 | 默认 / 深色 | 对话输入、气泡、确认流、候选选择（LLM 依赖项标注） | P0 |
| 18 | MethodManage/CategoryManage 等次级页 | 已列 | — | — | — |

> 执行时在 M1 依据 `router.pushUrl` 统计与 NavDestination pageMap 生成最终矩阵并逐页打勾；未出现在导航源中的页面先定位入口再走查，找不到入口的记入"可达性缺陷"（本身即体验问题）。

---

## 6. 用户旅程场景库（Simulator 的输入脚本模板）

每个 Simulator Agent 领一条旅程，按步骤执行并逐步留证：

- **J1 新用户首启**：空态 → 建账户 → 记第一笔 -> 查看首页汇总 → 走查空态引导
- **J2 日常记账**：记录 3 类交易（餐饮/交通/转账）→ 改金额 → 删一笔 → 撤销/确认流校验
- **J3 报表查看**：BalanceSheet → 切 Tab → 查分布 → 导出（若有导出入口）
- **J4 AI 对话记账**：AiAssistant 输入自然语言（中文）→ 确认气泡 → 落库校验（LLM 不可用时降级为"界面与流程走查"，标注依赖）
- **J5 设置漫游**：Settings 全分组遍历 → 切换 UI/数据设置 → 返回一致性
- **J6 搜索与筛选**：SearchPage 关键字 → 筛选 → 结果跳转详情
- **J7 深色模式专项**：切深色 → 全页面截图比对（对 Android 原图 dark 截图）
- **J8 边界与健壮性**：超长中文输入、超大金额、快速连点、返回键连按、横屏（豁免页面跳过）

---

## 7. 问题账本与修复闭环

### 7.1 问题条目 Schema（ledger）

```json
{
  "id": "UX-0001",
  "iter": 1,
  "page": "ExpenseEdit",
  "dimension": "D3 反馈与状态",
  "severity": "P0|P1|P2|P3",
  "summary": "保存成功后无 toast 反馈",
  "repro": "ExpenseEdit → 填金额 → 保存",
  "evidence": ["docs/ux-optimization/evidence/iter1/ExpenseEdit/save_after_ui.png",
               "docs/ux-optimization/evidence/iter1/ExpenseEdit/save_after_dump.json"],
  "status": "OPEN|FIXED|VERIFIED|WONTFIX",
  "fixer": "Fixer-3",
  "fixFiles": ["entry/src/main/ets/pages/ExpenseEdit.ets"],
  "fixNote": "保存分支补 Toast",
  "verifiedBy": "Verifier-1",
  "verifyEvidence": ["docs/ux-optimization/evidence/iter1/ExpenseEdit/verify_*.png"],
  "regressionRisk": "none|rerun AC-xx"
}
```

- 严重度：P0 阻断核心流程；P1 明显体验缺陷；P2 一般缺陷/一致性；P3 建议。
- 账本文件：`docs/ux-optimization/ledger.json`（Evidence Agent 每次变更后原子重写，加 `updatedAt`）。

### 7.2 修复原则（AGENTS.md §1/§6 落地）

- 最小修改：只改问题直接相关的文件与行；不顺手重构、不改无关样式/文案。
- 可回退：每个 Fixer 记录改动前后文件清单（不执行 Git，用 `fix-log.md` 记录文件/行/原因；如需基线对比用改动前副本备份到 evidence）。
- 不掩盖：不通过改构建配置/测试数据掩盖源码问题。
- 波及检测：修复涉及 D4 输入、列表、状态机时，必须核对 loading/空态/选中/刷新/返回路径，并在 fixNote 注明需跑的既有回归用例（`docs/testing/` 中找对应项）。

### 7.3 回归闭环

1. Fixer 完成 → Orchestrator 串行构建 1 次 → 产出新 HAP。
2. Verifier 领取 `FIXED` 条目 → 安装新 HAP → 重放 repro → 双证据存档 → 状态置 `VERIFIED`。
3. 回归中发现新问题 → 新开条目（同迭代或下迭代）。
4. 每迭代末：`fix-log.md`（按迭代追加）+ `iteration_report.md`（账本快照、严重度统计、剩余 OPEN、待用户决策项）。

---

## 8. 里程碑与迭代节奏

| 里程碑 | 内容 | 产出 |
|---|---|---|
| **M0 环境就绪** | 启动模拟器实例（方案 B/A 决策）、hdc 连线确认、Debug 构建通过、安装启动、输入探针（`uitest uiInput` 中文）、证据目录初始化 | `env_decision.md`、构建日志、探针截图 |
| **M1 首轮并行走查** | Simulator ×4~6 按分片执行 J1~J8，UX Auditor 判定 | `ledger.json` v1、逐页截图/dump 栈 |
| **M2 首批修复+回归** | Fixer ×3~4 修 P0/P1 → 串行构建 → Verifier 回归 | `fix-log.md` 第 1 轮、`iteration_report.md` v1 |
| **M3 全量覆盖+深色专项** | 补齐 P2 页面（Settings* 入口核实）、深色全页面比对、AI 页面 LLM 依赖项标注 | 全页面覆盖矩阵 100% 打勾、deep-diff 报告 |
| **M4 收口与人工 review** | 账本清零或明确 WONTFIX、汇总报告、遗留项移交 | `UX_OPTIMIZATION_REPORT.md`（对照 §2.1 九维度结论）、用户确认 |

> 每里程碑为 1 个迭代轮次；每轮结束必须向用户呈现：修复清单 + 关键前后截图 + 账本统计，用户 review 后才推进下一轮。若用户中途追加优先级，Orchestrator 下轮分片时纳入。

---

## 9. 证据与交付物清单

```
arkts_new/docs/ux-optimization/
├── README.md                       # 本计划（或指向本文件）
├── env_decision.md                 # M0：模拟器实例数/方案决策、构建产物记录
├── ledger.json                     # 问题账本（全量、原子更新）
├── fix-log.md                      # 修复日志（每迭代追加：文件/行/原因/验证）
├── iteration_report_v1..vN.md      # 每轮汇总（统计+待决策项）
├── UX_OPTIMIZATION_REPORT.md       # M4 最终报告（九维度结论+遗留）
└── evidence/
    ├── iter1..iterN/
    │   ├── <Page>/
    │   │   ├── <step>_ui.png       # 截图（snapshot_display）
    │   │   ├── <step>_dump.json    # dumpLayout
    │   │   └── <step>_db.sqlite    # 写操作场景的 DB 快照/查询结果
    │   └── ...
    └── 深色比对/
        ├── <Page>_dark_arkts.png
        └── <Page>_dark_android.png   # Android 原图（取自迁移期证据/MyExpenses assets）
```

---

## 10. 风险与规避

| 风险 | 影响 | 规避 |
|---|---|---|
| 模拟器当前离线/无实例 | M0 无法开始 | M0 首步用 `Emulator` 创建/启动实例；启动失败如实记录阻塞，不伪造连线证据 |
| 多实例内存不足 | 并行走查受限 | §3.3 方案 A/B 决策；实例数≥2 时优先方案 B，否则回落时间片 |
| 并发构建写同一 build 目录 | 构建产物互相污染 | 构建统一由 Orchestrator 串行，Fixer 只改源码 |
| 多 Agent 同设备操作互斥 | 走查证据失真 | 单实例时间片 or 每 Simulator 独立实例 |
| AI 对话页面依赖 LLM 服务 | J4 无法完整执行 | 降级走查界面/确认流并标注 `LLM-DEPENDENT`，不把降级当通过 |
| 深色设置命令与设备不符 | 证据无效 | M0 探针先验证 color_mode 命令实际生效后再用于全页面 |
| Release 签名缺失 | 只能验 debug 包 | 如实标注验证包型；不申请第三方规避 |
| 面板修复触碰功能逻辑 | 引入功能回归 | Fixer 声明 `regressionRisk`，Verifier 对关联既有用例复跑（docs/testing 基线） |
| 账本并发写坏 | 进度丢失 | Evidence Agent 单点写，原子替换 |

---

## 11. 下一迭代的启动清单（执行时的第一步）

1. （Orchestrator）读取本文档 + 确认模拟器实例方案 → 写入 `env_decision.md`。
2. （Orchestrator）生成 M1 分片表与旅程分配 → 启动 Simulator 团队。
3. （Simulator）按 §4 命令模板操作并逐步留证；操作后重新 dumpLayout，不沿用旧坐标。
4. 每轮结束按 §8 汇报，等待用户 review 后再推进。

---

*本计划为执行蓝图，不包含任何代码改动。执行时以本文档 §3 编排、§4 工具链、§5 覆盖矩阵、§7 闭环为准，并遵守项目 AGENTS.md 与环境约束。*