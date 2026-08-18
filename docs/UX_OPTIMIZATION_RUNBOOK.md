# UX 优化 · 多 Agent 长期自主运行执行规范（Runbook）

> 文档角色：**系统级执行规范**。目标工程：`/Users/rainyday/Desktop/migration/arkts_new`（myexpenses-arkts）。
> 运行模式：**多轮持续自主运行** —— 问题账本驱动，一轮接一轮（走查→审计→修复→构建→回归→汇报）自动循环，
> 直到问题清零或用户主动喊停；支持断点续跑、幂等、错误恢复与资源治理。
> 配套简洁版蓝图：`docs/UX_OPTIMIZATION_AGENT_PLAN.md`（本 Runbook 是其完整展开，如冲突以本文件为准）。
> 本文档自包含：拿本文件 + 末尾「启动提示词」即可启动一个能长期运行的 Orchestrator。

---

## 目录

- Part 0 使用说明
- Part 1 任务定义与边界
- Part 2 环境与工具链（已确认，直接复用）
- Part 3 系统架构：多 Agent 团队 + 长期运行状态机
- Part 4 每轮执行流程（详细步骤）
- Part 5 全页面覆盖矩阵
- Part 6 用户旅程脚本库（J1~J8）
- Part 7 体验判定框架与严重度
- Part 8 修复与回归规则
- Part 9 汇报与用户接口（暂停/继续/终止约定）
- Part 10 交付物与目录结构
- Part 11 风险、重试与对策矩阵
- Part 12 完整启动提示词（可直接复制）
- Part 13 附录：命令速查 / 文件模板 / 常见问题

---

# Part 0 使用说明

1. **谁能用**：任何兼容 Agent（DeepSeek Harness / CodeArts Agent / 其他）粘贴 Part 12 提示词即可接管执行。
2. **怎么开始**：先读本文件全部 → M0 环境就绪（Part 4.0）→ 进入轮次循环（Part 4.1~4.5）。
3. **怎么续跑**：任何时刻中断（断电/资源回收/手动停止）后，重新启动时从 `state.json` + `ledger.json` 恢复（Part 3.5），不需要人工盘点。
4. **怎么停**：见 Part 9 的暂停/继续/终止指令约定；自动暂停条件见 Part 3.4。
5. **唯一事实源**：`docs/ux-optimization/ledger.json` 是问题账本唯一事实源；`docs/ux-optimization/state.json` 是运行状态唯一事实源；两者之外的描述性文档均为参考。

---

# Part 1 任务定义与边界

## 1.1 目标

- 对已完成迁移的 ArkUI 记账应用做**体验优化**：按九维度（Part 7）发现并修复体验问题。
- 用**智能 Agent 以真实用户身份**在模拟器上交互式操作（点击/输入/滑动/返回/深浅色切换），逐步留证。
- 覆盖**全部页面**（21 个页面文件，矩阵见 Part 5）。
- **发现问题即修复**（用户决策），修复最小化、可回退、可验证。

## 1.2 边界（不做什么）

| 不做 | 原因/依据 |
|---|---|
| 不重新验证既有功能 | 功能基线在 `arkts_new/docs/testing/`，迁移门禁已完成（ACCEPTANCE_CANDIDATE） |
| 不重跑迁移验收 | 与本阶段无关 |
| 不做 Git 操作 | AGENTS.md 默认禁止 |
| 不改构建配置/包名/签名掩盖问题 | AGENTS.md §6 |
| 不顺手重构无关模块 | AGENTS.md §6 |
| 不伪造任何证据（设备/像素/日志/测试/审查） | AGENTS.md P3 |
| 不把「无法确认」写成「通过」 | AGENTS.md §8 |

## 1.3 用户已确认约束（不得更改）

1. 模拟环境：DevEco 模拟器（非真机）。
2. 模拟方式：Agent 真实用户式交互操作，逐步留证。
3. 处理方式：发现问题即修复；修复须最小、可回退、可验证。
4. 汇报节奏：每轮结束向用户交付报告；用户 review 后进入下一轮；用户可随时指定优先级/暂停/终止。
5. 并行编排：最大化使用 Agent 团队；能并行的环节必须并行；共享资源串行（构建/设备前台/账本写入）。

---

# Part 2 环境与工具链（已确认，直接复用，禁止重复探测）

## 2.1 静态事实

```
操作系统    macOS 15.7.7 (arm64)
Python      python3 = 3.9.6
DevEco      /Applications/DevEco-Studio.app (6.1)
SDK         /Applications/DevEco-Studio.app/Contents/sdk (default/openharmony, targetSdk 6.1.1(24))
hdc         /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
模拟器二进制 /Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
构建工具     /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
本地LLM网关 /Users/rainyday/Desktop/migration/codearts_api.py (OpenAI兼容, 默认 http://127.0.0.1:8765)
被测应用     bundle=org.totschnig.myexpenses, ability=EntryAbility
模拟器模板   Huawei_Phone(API 11/12/13, 1260x2720, density 520), Huawei_Foldable, Huawei_Tablet
历史可用端口 127.0.0.1:15558, 127.0.0.1:5555
```

## 2.2 命令模板（Simulator/Verifier 统一复用；坐标一律取最新 dumpLayout，禁止复用旧坐标）

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
APP=org.totschnig.myexpenses

# ── 模拟器 ─────────────────────────────────────────────
$EMU -help                        # 查看 create/start/delete/query 用法
$EMU -create <Name> -deviceType phone -osVersion <ver> ...   # 如无 AVD 则创建（M0）
$EMU -start <Name>                # 启动实例
$HDC list targets                 # 确认在线（127.0.0.1:port）
$HDC -t <port> shell echo ok      # 指定端口操作（多实例时必带 -t）

# ── 构建（仅 Orchestrator 串行执行）────────────────────
cd /Users/rainyday/Desktop/migration/arkts_new
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon
# 产物: entry/build/default/outputs/default/entry-default-unsigned.hap

# ── 安装 / 启动 / 停止 ─────────────────────────────────
$HDC install -r entry/build/default/outputs/default/entry-default-unsigned.hap
$HDC shell aa start -a EntryAbility -b $APP
$HDC shell aa force-stop $APP

# ── 界面证据 ───────────────────────────────────────────
$HDC shell uitest dumpLayout > /dev/null   # 写布局到设备端
$HDC shell cat /data/local/tmp/xxxx.json    # 或按 uitest 实际输出路径
$HDC shell snapshot_display                 # 截图到设备端
$HDC file recv <dev_path> <local_path>      # 拉回本地

# ── 交互 ───────────────────────────────────────────────
$HDC shell uitest click <x> <y>
$HDC shell uitest swipe <x1> <y1> <x2> <y2>
$HDC shell uitest uiInput text '<中文>'   # 需先点击 TextInput 聚焦（已探针验证可行）

# ── 数据证据（写操作场景）─────────────────────────────
$HDC shell aa force-stop $APP
$HDC file recv /data/app/el2/100/base/$APP/haps/entry/files/myexpenses.db ./evidence/.../  # 实际路径以设备为准
# 用 sqlite3 查询比对插入/删除；操作前先 recv 基线备份

# ── 深色切换（M0 探针验证生效后再用于全页面）──────────
$HDC shell settings put system color_mode 2   # 2=深色, 1=浅色（以设备实际为准，先 dump 确认）
```

## 2.3 模拟器隔离规则（强制，防止跨项目业务错乱）

> 用户本机同时运行**其他项目**，那些项目使用各自的模拟器实例并已有业务数据。
> 本任务**必须使用为本任务全新创建的专用模拟器**；任何已存在的模拟器实例一律**禁止连接、禁止操作、禁止读写**。

### 2.3.1 强制规则（违反 = 任务失败）

1. **M0 第一步**：枚举本机全部既有模拟器实例并记录到 `env_decision.md`（实例名 / 端口 / API 版本），
   该清单作为 **`forbiddenInstances`（禁用实例清单）** 固化，全程不得触碰。
2. **新建专用实例**：为本任务创建全新模拟器实例（命名强制含本任务标识，如 `MyExpensesUX_<日期>`），
   记录实例名、端口、创建命令与输出到 `env_decision.md`。
3. **只连专用实例**：`hdc list targets` 出现多个设备时，必须以 `-t <专用实例端口>` 显式指定目标；
   绝不允许默认端口（如 5555）免选连接，绝不允许把 `-t` 指向禁用清单中的任何端口。
4. **冲突检测**：新建实例端口必须避开禁用清单中所有端口及常见占用端口（5555/15558 等）；端口冲突 = 立即放弃该端口重选。
5. 每轮开始（含断点恢复）先核对 `state.json.instances[].port` 属于专用实例清单，不属于禁用清单，否则不得继续。
6. 全程禁止对非本任务 HAP/数据做任何读写；DB 快照只从专用实例拉取。

### 2.3.2 env_decision.md 必须包含的隔离字段

```jsonc
{
  "forbiddenInstances": [              // 执行全程不得连接
    {"name": "<既有实例名>", "port": 5555, "api": 12, "note": "其他项目在用"},
    {"name": "<既有实例名>", "port": 15558, "api": 12, "note": "其他项目在用"}
  ],
  "dedicatedInstance": {               // 本任务专用
    "name": "MyExpensesUX_20260818", "port": 5561, "api": 12,
    "createCmd": "$EMU -create ...", "createdAt": "..."
  },
  "confirmations": [
    "已枚举全部既有实例并记录", "已创建专用实例且端口无冲突",
    "已用 -t 指定专用端口完成首次连接", "未触碰任何禁用实例"
  ]
}
```

### 2.3.3 常见误操作与禁令

| 误操作 | 禁令说明 |
|---|---|
| `hdc install` 不指定 `-t` | 多设备时可能装到其他项目实例 → **一律禁止**，必须 `$HDC -t <专用端口> install` |
| `hdc shell aa start/force-stop` 不带 `-t` | 同上 → 必须带 `-t` |
| 连接后发现不对就顺手操作 | 一旦发现目标非专用实例：**立即停止**，不得进行任何读写，记录后换专用端口 |
| 复用旧的模拟器快照/AVD | 禁止；专用实例必须新建（`-create`），不得复用任何既有 AVD |

---

# Part 3 系统架构：多 Agent 团队 + 长期运行状态机

## 3.1 角色与并发上限

| 角色 | 职责 | 并发 | 说明 |
|---|---|---|---|
| Orchestrator（主控） | 读/写 state.json 与 ledger；分片；串行构建；轮次调度；用户接口 | 1 | 唯一有权写 state.json、触发构建、向用户汇报 |
| Simulator | 领页面组/旅程，真实操作，逐步留证，上报疑似问题 | 4~6 | 受设备实例数约束（3.7） |
| UX Auditor | 对 dump/截图按九维度判定，产出结构化条目 | 2 | 流水消费 Simulator 产物 |
| Fixer | 按页面/模块领取问题，最小修改源码 | 3~4 | 只改源码，不构建 |
| Verifier | 安装新 HAP，重放场景，双证据存档 | 2 | 每次只操作自己分配的场景 |
| Evidence | ledger/fix-log/目录维护、进度汇总 | 1 | 单点原子写入 |

并行原则：**只在无共享状态的工作上并行**；共享资源一律由 Orchestrator 或单点角色串行。

## 3.2 全局状态机（state.json）

```jsonc
{
  "schemaVersion": 1,
  "state": "BOOTSTRAPPING | WALKTHROUGH | AUDITING | FIXING | BUILDING | VERIFYING | REPORTING | SUSPENDED | DONE | FAILED",
  "iter": 3,                    // 当前轮次
  "phase": "WALKTHROUGH",       // 当前阶段（每轮内复用同一组阶段）
  "startedAt": "2026-08-18T10:00:00+08:00",
  "updatedAt": "2026-08-18T11:23:00+08:00",
  "lastReport": "2026-08-18T11:30:00+08:00",
  "devicePlan": "MULTI_INSTANCE | TIME_SLICE",   // M0 决策
  // 隔离（2.3）：只能是本任务专用实例；forbiddenInstances 全程不得触碰
  "dedicatedInstances": [{"name":"MyExpensesUX_<日期>","port":5561,"owner":null}],
  "forbiddenInstances": [{"name":"<其他项目实例>","port":5555}],
  "build": {"lastHap": "entry-default-unsigned.hap", "lastBuildAt": "...", "sha256": "..."},
  "autoPause": null,             // {"reason":"no-progress","at":"..."} 触发自动暂停时置非空
  "pausedByUser": false,
  "stopRequested": false
}
```

状态转换（仅 Orchestrator 执行，每次转换原子重写 state.json）：

```
BOOTSTRAPPING ──(M0 完成)──▶ WALKTHROUGH
WALKTHROUGH ──(simulator 全部提交)──▶ AUDITING
AUDITING ──(条目入账本)──▶ FIXING
FIXING ──(全部 FIXED/串行构建成功)──▶ VERIFYING
VERIFYING ──(全部 VERIFIED 或部分 BLOCKED)──▶ REPORTING
REPORTING ──(汇报完成，有遗留问题)──▶ WALKTHROUGH   // 下一轮
REPORTING ──(问题清零 或 用户终止)──▶ DONE
任意阶段 ──(用户暂停/自动暂停)──▶ SUSPENDED
SUSPENDED ──(用户继续)──▶ 回到暂停前阶段
任意阶段 ──(不可恢复错误)──▶ FAILED（记录原因后等待用户指令，不自动重试）
```

## 3.3 问题账本（ledger.json）—— 唯一事实源

### 3.3.1 条目 Schema

```jsonc
{
  "id": "UX-0001",                 // 全局唯一，顺序递增
  "iter": 1,                       // 发现轮次
  "page": "ExpenseEdit",           // 页面文件基名
  "dimension": "D3",               // 九维度编号
  "severity": "P0|P1|P2|P3",
  "status": "NEW|SIMULATED|AUDITED|FIXING|FIXED|VERIFYING|VERIFIED|CLOSED|WONTFIX|BLOCKED|DEFERRED",
  "summary": "保存成功后无反馈",
  "repro": "ExpenseEdit → 填金额 → 保存",
  "evidence": ["docs/ux-optimization/evidence/iter1/ExpenseEdit/01_save_ui.png", "..._dump.json"],
  "fixer": null,                    // 领取后写 Fixer 标识
  "fixFiles": [],                   // 修复涉及文件相对路径
  "fixNote": "",                    // 改动说明（文件/行/原因）
  "verifiedBy": null,               // Verifier 标识
  "verifyEvidence": [],
  "regressionRisk": "none",         // 或 "rerun: AC-01,TX-12"
  "deferReason": "",                // WONTFIX/BLOCKED/DEFERRED 时必填
  "openedAt": "", "closedAt": ""
}
```

### 3.3.2 条目状态机

```
NEW →(Simulator 留证完毕)→ SIMULATED
SIMULATED →(Auditor 判定)→ AUDITED
AUDITED →(Fixer 领取)→ FIXING
FIXING →(改码完成)→ FIXED
FIXED →(Verifier 领取, 安装新HAP)→ VERIFYING
VERIFYING →(双证据通过)→ VERIFIED →(下一轮汇报时批量)→ CLOSED
VERIFYING →(验证失败, 修复无效)→ FIXING   (退回调修, 最多 2 次, 仍失败→ BLOCKED)
任意 →(用户确认不做/不可修)→ WONTFIX (需 deferReason)
任意 →(依赖缺失/资源不足, 非问题本身)→ BLOCKED
P2/P3 →(用户要求延后)→ DEFERRED (deferReason 记录目标轮次)
```

### 3.3.3 账本操作规则

- **单点写入**：只有 Evidence 角色（或 Orchestrator）原子重写整个 ledger.json（先写临时文件再 rename）。
- **幂等**：条目按 `id` 更新；写入前校验 `updatedAt`，避免覆盖新状态。
- **归档**：每轮结束把 ledger.json 复制为 `ledger_iterN.json` 后继续使用主文件。

## 3.4 轮次循环与自动暂停

### 3.4.1 一轮定义

一轮 = WALKTHROUGH → AUDITING → FIXING → VERIFYING → REPORTING（Part 4 详解）。
每轮目标：**处理上轮遗留 + 新发现**，输出一份 `iteration_report_vN.md`。

### 3.4.2 轮次进入条件

下一轮在 REPORTING 完成后自动进入，除非：
- 账本中无 OPEN 状态条目且本轮新增条目全部 CLOSED/WONTFIX → **DONE**（问题清零）；
- 用户发出暂停/终止指令（Part 9）。

### 3.4.3 自动暂停阈值（触发即 SUSPENDED，写 state.json.autoPause，等待用户）

| 条件 | 阈值（默认，M0 可校准） | 说明 |
|---|---|---|
| 连续无进展 | 连续 2 轮新增 VERIFIED < 2 且无新增条目 | 防空转 |
| 修复失败率过高 | 同一条目 2 次 FIXING→VERIFYING 失败转 BLOCKED 且单轮 BLOCKED ≥ 3 | 防死循环 |
| 模拟器资源不足 | 实例数 < 计划数 且 hdc 离线 > 30 分钟 | 等设备 |
| LLM 依赖大面积失效 | 单轮 ≥ 5 条目标 LLM-DEPENDENT 且 J4 完全无法执行 | 等模型服务 |
| 磁盘/空间告警 | evidence 目录剩余 < 2 GB | 防证据丢失 |
| 用户告警 | 用户消息要求暂停 | 最高优先 |

### 3.4.4 运行预算（防失控）

- **单轮硬超时**：默认 8 小时；超时强制进入 REPORTING（未完成条目标记 BLOCKED+deferReason=timeout）。
- **总轮次上限**：默认 20 轮；达到上限进入 SUSPENDED，由用户决定是否继续。
- 预算可被用户在汇报时修改（写入 state.json 的 `budget` 字段）。

## 3.5 断点续跑 / 恢复

任何中断后（进程被杀/断电/手动停止），重启 Orchestrator 时执行：

```
0. 【隔离复核，见 2.3】核对 state.json.dedicatedInstances 与 env_decision.md：
   确认目标端口属于专用实例、不属于 forbiddenInstances；hdc list targets 只认专用端口，
   任何其他在线实例一律不碰。
1. 读 state.json → 若不存在，视为全新启动（走 M0）。
2. 读 ledger.json → 统计各状态条目数。
3. 恢复规则：
   - state=WALKTHROUGH   → 检查是否有 SIMULATED/NEW 条目：有则跳 AUDITING，无则继续 WALKTHROUGH。
   - state=AUDITING      → 继续消费 Simulator 产物（产物目录证据在 evidence/iterN/对应页面/）。
   - state=FIXING        → FIXING 且无 fixFiles 的条目：视为未开始，重新分派；有 fixFiles 的：保持，进构建。
   - state=BUILDING      → 重跑构建（构建幂等，产物覆盖）。
   - state=VERIFYING     → VERIFYING 无 verifyEvidence 的条目：重新验证；有证据的：保留。
   - state=REPORTING     → 重写 iteration_report（证据都在，报告可重生成）。
   - state=SUSPENDED     → 保持暂停，等待用户指令。
   - state=FAILED        → 保持失败，等待用户指令（README 由恢复日志记录原因）。
4. 校验残留一致性：
   - 存在 verifierEvidence 但 leder 状态非 VERIFYING/VERIFIED → 回写状态。
   - evidence/iterN 有孤儿文件 → 尝试按文件名前缀匹配条目，匹配不到则忽略并记录。
5. 确认专用实例仍在在线（`hdc -t <专用端口> shell echo ok`）；离线则重启该专用实例，不换其他实例。
6. 写 state.json（updatedAt=now, 备注恢复点）→ 继续执行。
```

幂等保证的关键动作：
- `hdc install -r` 可重复安装；`aa start` 幂等；截图/dump 按 `<issueId|场景>_<step>` 命名覆盖写。
- 构建产物每次生成后记录 sha256 到 state.json，验证时以 sha256 匹配 HAP，避免旧包误验。

## 3.6 并发与互斥令牌

- **设备令牌**：每个模拟器实例一个令牌文件 `state/deviceTokens/<port>.lock`；Simulator/Verifier 操作设备前先 `mkdir` 抢锁（原子），用完释放；持有超过 15 分钟视为死锁可回收（Orchestrator 强制释放并记录）。
- **构建互斥**：只有 Orchestrator 执行构建；构建期间 state=BUILDING，其他阶段暂停设备上的写操作（读/截图可以）。
- **账本互斥**：Evidence 单点写；写前 `flock` 或临时文件 rename。

## 3.7 资源治理

- **实例合规（2.3 强制）**：所有使用实例必须是本任务新建的专用实例（`dedicatedInstances`），
  端口不得与 `forbiddenInstances`（其他项目实例）冲突；数量增减只在该清单内操作，永远不借用既有实例。
- **实例数决策**（M0 实测）：`sysctl hw.memsize` 与 `vm_stat` 估空闲内存；单实例约需 3~4 GB。
  - 空闲 ≥ 16 GB → MULTI_INSTANCE（2~3 个专用实例，端口 +2 递增且避让禁用端口，如 5561/5563/5565）；
  - 否则 → TIME_SLICE（单专用实例，Simulator 按分片排队，前台令牌串行）。
- **端口避让**：专用实例端口从禁用清单最大端口 +10 起选，且逐个探测未被占用；冲突即换。
- **并发上限**：TIME_SLICE 下 Simulator 实际同时只有 1 个在设备上操作，其余等待令牌；MULTI_INSTANCE 下每实例 1 个操作者。
- **监控**：每阶段结束记录 `df`（evidence 空间）与专用实例 hdc 在线状态到 `run.log`。

## 3.8 日志

```
docs/ux-optimization/logs/
├── run.log            # Orchestrator 主日志：状态转换/轮次/构建/暂停/恢复（含时间戳）
├── simulator_N.log    # 每个 Simulator 的操作日志（命令+输出+证据路径）
├── fixer_N.log        # 每个 Fixer 的改码日志
├── verifier_N.log     # 每个 Verifier 的验证日志
└── recovery.log       # 每次断点续跑的恢复动作记录
```

日志格式：`[时间戳] [角色] [动作] [结果] [证据路径]`；失败必须记 exit code。

## 3.9 上下文治理与压缩（CodeArts 小上下文适配，长期运行质量保障）

> 目标：在 CodeArts 等**上下文窗口有限**的执行环境里，长时间自主运行（多轮、多子代理）的质量不因对话膨胀而劣化。
> 总原则：**「磁盘即记忆，对话只放指针与摘要」** —— 所有事实性状态落盘为文件，对话内只保留
> 最少的指针（文件路径）与摘要（统计/结论），需要细节时按需读文件，绝不把长内容复制进对话。

### 3.9.1 上下文分层与预算

| 层 | 内容 | 常驻对话 | 说明 |
|---|---|---|---|
| L0 操作契约（常驻，只读） | Runbook Part 2 命令模板、Part 9 用户指令约定、AGENTS.md 硬规则摘要、state.json 关键字段 | ✅ 每轮开始时注入一次 | Orchestrator 每次重启会话后必须重新注入；来自文件，不靠记忆 |
| L1 当前轮事实（每轮重置） | 本轮分片表、当前 ledger 增量（仅 OPEN/FIXED/VERIFYING 条目，截断 summary 等长字段）、本轮已生成证据路径清单 | ✅ 每轮开始时注入 | 逐段注入并明确「读完即不必常驻」，本轮结束后全部移除 |
| L2 按需加载（不在对话） | Part 5 矩阵、Part 6 旅程脚本、Part 7 判定框架、既有测试报告、源码文件 | ❌ 不常驻 | 需要时用 read/grep 精确读取 1~3 个文件，用完不留在对话 |
| L3 只留指针（永久落盘） | 截图/dump/DB/日志/报告全文、ledger 全部历史、本轮完整对话记录 | ❌ 绝不进对话 | 文件路径写入对话即可，内容在磁盘 |

**对话预算上限**：主对话在任意时刻不得包含超过约 4 个长文件全文级别的冗余文本（估算值，M0 校准）；
超过即按 3.9.3 强制压缩。

### 3.9.2 每轮「压缩交接」（round handoff）

每轮进入 REPORTING 收尾时，Orchestrator 必须生成一份 **`round_handoff_vN.md`**（模板见 13.D），
它同时是下一轮的「唯一注入物」：

```
文档: docs/ux-optimization/round_handoff_vN.md   （每轮结束覆盖写 vN，永不追加长篇）
字段:
- 轮次 vN / 时间范围 / 预算消耗
- 环境快照: 实例数+端口、最新 HAP sha256、LLM 可用性、磁盘剩余
- 本轮统计: 新增/修复/验证/BLOCKED/WONTFIX/DEFERRED 计数（仅计数，不列明细）
- 下轮必须处理: OPEN 与 FIXED 未验证条目的 id+page+severity 列表（一行一条）
- 下轮分片表（页面×旅程 组合，供 Simulator 直接领取）
- 已知坑（本轮教训 ≤5 条，每条 ≤1 行）
```

**规则**：
1. 下一轮启动时，Orchestrator **只注入 round_handoff_vN.md + L0 契约 + L1 增量**，上一轮的对话内容一律不延续；
2. 子代理（Simulator/Fixer/Verifier）之间不传递对话，只传递 `handoff 片段（从文件中截取）+ 自己的任务说明`；
3. 一个「会话」最长运行 1 轮；跨轮必须新建会话（新会话从磁盘恢复，见 3.9.4）。

### 3.9.3 主对话压缩触发与流程

**触发条件**（任一满足即执行压缩，不等轮次结束）：
- 上下文接近上限（如剩余 < 30%，或 Agent 提示上下文紧张）；
- 已连续执行 2 个以上大页面（Index/AiAssistant/ExpenseEdit/CategorySelect/BalanceSheet）的走查；
- 对话中检测到 ≥3 个已读过的长文件正文残留（按 3.9.1 L2 判断）；
- 单次汇报回复超过合理篇幅（报告正文必须落盘，回复只给摘要+链接）。

**压缩流程（可随时执行，勿丢状态）**：
1. 先写 `round_handoff_vN.md`（从 ledger/state/本轮产物生成，2 分钟内完成）；
2. 把当前对话中所有「已完成的中间结果」（如已 LRU 的源码阅读、旧 dump 文本、旧讨论）从对话中移除 ——
   实现方式：**不依赖模型删除历史**，而是直接「重启会话/新建子代理」，新会话只带 handoff；
3. 新会话启动后按 3.5 断点续跑规则恢复（state.json + ledger.json + handoff），并记录到 `recovery.log`；
4. 恢复后第一动作：校验 ledger 与磁盘证据一致（残留校验见 3.5 第 4 步），确认无丢失再继续。

### 3.9.4 子代理上下文治理（每个子代理窗口同样小）

| 子代理 | 注入内容（应小于一屏） | 输出要求（结构化，不吐原文） |
|---|---|---|
| Simulator | 分片表行（页面+旅程+入口）+ Part 2.2 命令模板路径 + 证据命名规范 | `evidence/iterN/_pending/<page>_<seq>.json`；日志只留命令+关键结果 |
| UX Auditor | 待审计条目 id 列表 + Part 7 判定框架路径 | 结构化条目（schema 字段），每条 ≤ 正文一段 |
| Fixer | 条目 id + page + summary + 相关源码文件路径 | fixNote（文件/行/原因）+ fixFiles，禁止贴整文件 |
| Verifier | 条目 id + repro + 关联回归用例名 | verifyEvidence 路径 + 结论（VERIFIED/FAILED 原因） |
| Evidence | 仅目录路径与写入规范 | 只回“已写入 <路径>” |

子代理输出超规格（长文本/贴文件全文）时，Orchestrator 拒绝接收并退回重产出结构化结果。

### 3.9.5 反膨胀硬规则（全员适用）

1. 命令输出只保留退出码+关键行（先落盘 logs/，再 grep 关键行回填）；截图/dump 一律不贴进对话，只留路径；
2. 同一文件不得在对话中重复出现两次以上；需要再看时重新 read（文件是真相，对话是缓存）；
3. 一切「已写入磁盘」的信息（证据、报告、ledger）在对话内只保留最少一句话结论；
4. 讨论/决策一旦落盘（fix-log/iteration_report/handoff）即视为「已存档」，后续不重复叙述；
5. 汇报给用户：先落盘报告，回复只给「摘要 + 文件链接」，不贴报告全文。

### 3.9.6 质量保持校验（每轮 REPORTING 前自检）

```
[ ] round_handoff_vN.md 已生成且为最新轮次
[ ] ledger.json 与 evidence/ 磁盘证据一致（抽查 ≥3 条目：evidence 路径真实存在）
[ ] 子代理输出均为结构化结果，无长文残留
[ ] 对话中无已读长文件全文残留（若有 → 按 3.9.3 重启会话恢复）
[ ] 本轮所有「结论/证据」已在磁盘，对话中无未落盘的独有信息
[ ] 本机剩余空间 ≥ 2GB，state.json.updatedAt 为最近
[ ] 隔离合规（2.3）：本轮所有设备命令均带 -t 专用端口；未触碰 forbiddenInstances
```

---

# Part 4 每轮执行流程（详细步骤）

## 4.0 M0 环境就绪（仅首次）

```
[Orchestrator]
0. 【隔离前置，见 2.3】枚举本机全部既有模拟器实例 → 写入 env_decision.md.forbiddenInstances（禁用清单）；
   确认全程不得连接这些实例。
1. 读本 Runbook 与 AGENTS.md。
2. 初始化目录：docs/ux-optimization/{evidence,logs,state/deviceTokens}
   + 写入 state.json（state=BOOTSTRAPPING）。
3. 决策设备方案（3.7）→ 写入 env_decision.md + state.json.devicePlan。
4. 创建本任务专用模拟器实例（命名含 MyExpensesUX_ 前缀；端口避开禁用清单与常见占用端口）
   → 记录创建命令/输出/端口到 env_decision.md.dedicatedInstance →
   仅用该实例（所有命令必须 `-t <专用端口>`）启动 → hdc list targets 确认只有专用实例被操作。
5. 串行构建 debug HAP → 记录 sha256 → `-t 专用端口` 安装 → 启动 EntryAbility。
6. 输入探针：dumpLayout → click 聚焦某个 TextInput → uiInput text '测试' → 验证文本提交。
7. 深色探针：settings put color_mode 2 → screenshot 确认实际变深色；记录实际生效命令。
8. DB 路径探针：hdc shell find 定位 myexpenses.db 实际路径，记录进 env_decision.md。
9. 复核隔离清单确认项（2.3.2 confirmations 全部为真）; 写 run.log；
   状态 →（等待用户确认或直接进入 WALKTHROUGH，按提示词约定）。
```

产出：`env_decision.md`（含禁用清单+专用实例）、构建日志、探针截图/日志。

## 4.1 WALKTHROUGH（并行走查）

```
[Orchestrator]
1. 生成该轮分片表：页面×旅程 组合（Part 5 × Part 6），按页面归属聚类成 4~6 组。
2. 为每组启动 1 个 Simulator（受设备令牌约束排队）。
3. 下发：旅程脚本、命令模板（Part 2.2）、证据命名规范、上报格式。

[Simulator ×N]
1. 读分片表与旅程脚本。
2. 对每个场景：
   a. 确保应用在前台（aa start / force-stop 后重启 → 回到场景入口）；
   b. 每步操作：先 dumpLayout 取最新控件 bounds → 操作（click/swipe/uiInput）→ 截图+dump 存档；
   c. 状态变化后必须重新 dump，禁止复用旧坐标；
   d. 疑似问题：写一条 NEW 条目（summary/repro/evidence 路径）到"待审计队列"文件
      （evidence/iterN/_pending/<page>_<seq>.json），不直接改 ledger。
3. 写 simulator_N.log。
```

产出：每场景截图/dump 栈 + `_pending` 待审计条目。

## 4.2 AUDITING（审计判定）

```
[UX Auditor ×2]
1. 消费 _pending 目录（无则等待）。
2. 对每条：按 Part 7 判定维度/严重度；将条目写入 ledger（状态 AUDITED）；
   把 simulator 的待定结论合并/去重（同页面同问题合并，保留最早证据）。
3. 自动补扫描：对 Simulator 证据目录做"九维度核对"，补漏条目（如无障碍缺失等静态可判项）。
4. 写对应日志；产出 ledger 增量。
```

## 4.3 FIXING（修复）

```
[Orchestrator]
1. 取全部 AUDITED 条目，按 page 聚类 → 分派 Fixer（跨页耦合问题单独路由给 1 个 Fixer）。
2. 单轮修复上限：默认 12 条/轮（预算可调），超出 DEFERRED 到下一轮。

[Fixer ×N]
1. 领取条目：状态置 FIXING（原子更新 ledger）。
2. 读相关源码（先读再改）→ 最小修改 → 更新 fixFiles/fixNote。
3. 涉及 D4 输入/列表/状态联动的修复，必须核对 loading/空态/选中/刷新/返回路径，
   并在 fixNote 注明需跑的既有回归用例（docs/testing/ 对应项）。
4. 完成 → 状态 FIXED。写 fixer_N.log。
```

## 4.4 BUILDING + VERIFYING（构建与回归）

```
[Orchestrator，串行]
1. 收集本轮全部 FIXED 条目 → 状态不变，执行一次 debug 构建。
   构建成功 → 记录 sha256 → state=BUILDING→VERIFYING。
   构建失败 → 只分析当前错误相关文件，最小修复后重试一次；仍失败 → 记录 BLOCKED 并暂停等用户。
2. 安装新 HAP → 按条目分派 Verifier。

[Verifier ×2]
1. 领取 VERIFYING 条目：安装（install -r；可重复）→ 重放 repro → 双证据存档
   （操作命令+返回 与 截图/dump 或 DB 实测）。
2. 通过 → VERIFIED；不通过 → 退回 FIXING（同一条目最多 2 次；仍失败 → BLOCKED）。
3. regressionRisk 非 none 时，另跑关联既有用例并记录结果。
4. 写 verifier_N.log。
```

## 4.5 REPORTING（汇报）

```
[Evidence + Orchestrator]
1. 复制 ledger → ledger_iterN.json；问题清零判定。
2. 生成 iteration_report_vN.md（模板 Part 13.B）：
   - 本轮新增/修复/验证/遗留统计（P0~P3 分布）
   - 修复清单（id/页面/严重度/摘要/证据链接）
   - 关键前后对照截图
   - BLOCKED/WONTFIX/DEFERRED 明细与原因
   - 运行预算消耗、自动暂停触发情况
   - 下一轮分片计划
3. 向用户交付报告 → 等待 review。
```

---

# Part 5 全页面覆盖矩阵

| # | 页面文件 | 入口 | 走查场景 | 关键交互 | 优先级 |
|---|---|---|---|---|---|
| 1 | Index.ets | 启动即达 | 空态/有数据/深色 | Tab 切换、更多菜单、列表滚动 | P0 |
| 2 | AccountEdit.ets | Index 账户点按/新建 | 默认/深色 | 表单、保存/取消、返回 | P0 |
| 3 | ExpenseEdit.ets | Index 记录按钮/条目点按 | 默认/深色 | 金额键盘、分类、日期、保存 | P0 |
| 4 | CategoryManage.ets | 设置→分类管理 | 默认/深色 | 增删改分类 | P1 |
| 5 | CategorySelect.ets | 记账选分类 | 默认/深色 | 搜索、单选、滚动 | P1 |
| 6 | MethodManage.ets | 设置→付款方式 | 默认/深色 | 增删改方式 | P1 |
| 7 | TagManage.ets | 设置→标签 | 默认/深色 | 增删改标签 | P1 |
| 8 | TagSelect.ets | 记账选标签 | 默认/深色 | 多选、搜索 | P1 |
| 9 | SearchPage.ets | Index 搜索 | 默认/深色/空结果 | 搜索、筛选、结果跳转 | P1 |
| 10 | BalanceSheet.ets | Index 报表 | 默认/深色/空数据 | Tab 切换、图表、导出 | P1 |
| 11 | Distribution.ets | Index 分布 | 默认/深色/空数据 | 图表交互 | P1 |
| 12 | History.ets | Index 历史 | 默认/深色 | 列表加载、筛选、滚动 | P1 |
| 13 | Settings.ets | 更多→设置 | 默认/深色 | 分组列表、跳转 | P0 |
| 14 | SettingsMain / SettingsUI / SettingsData / SettingsIO.ets | 入口 M1 核实 | 默认/深色 | 各设置项 | P2 |
| 15 | BudgetManage / BudgetEdit.ets | NavDestination pageMap | 默认/深色 | 预算增删改 | P1 |
| 16 | DebtManage.ets | NavDestination pageMap | 默认/深色 | 债务增删改 | P1 |
| 17 | AiAssistant.ets | Index AI 入口 | 默认/深色 | 对话、确认流、候选（LLM 依赖标注） | P0 |
| 18 | CategorySelect 等次级页 | 已列 | — | — | — |

覆盖口径：21 个页面文件全部进入；matrix 每项必须记录「已走查一轮 + 证据路径」，未覆盖的记入状态（如入口未找到 = 可达性缺陷条目）。

---

# Part 6 用户旅程脚本库（J1~J8）

每条旅程 = 一组有序场景；Simulator 按脚本逐步执行并留证。

- **J1 新用户首启**：空态 → 建账户 → 记第一笔 → 首页汇总 → 空态引导走查。
- **J2 日常记账**：记录 3 类交易（餐饮/交通/转账）→ 改金额 → 删一笔 → 确认/撤销流校验。
- **J3 报表查看**：BalanceSheet → 切 Tab → 分布 → 图表交互 → 导出（有入口才做）。
- **J4 AI 对话记账**：AiAssistant 中文自然语言 → 确认气泡 → 落库校验（LLM 不可用→降级走查界面/确认流，标注 LLM-DEPENDENT）。
- **J5 设置漫游**：Settings 全分组遍历 → UI/数据设置 → 返回一致性。
- **J6 搜索与筛选**：SearchPage → 关键字 → 筛选 → 结果跳详情。
- **J7 深色模式专项**：切深色 → 全页面截图比对 Android 原图 dark 截图。
- **J8 边界与健壮性**：超长中文输入、超大金额、快速连点、返回键连按、横屏（豁免页面跳过）。

每旅程输出：`evidence/iterN/<Page>/<step>_ui.png` + `_dump.json` + 旅程摘要（可选 `_journey.json`：步骤-操作-结果-问题引用）。

---

# Part 7 体验判定框架与严重度

## 7.1 九维度

| 维度 | 检查要点 |
|---|---|
| D1 可用性 | 核心记账链路步骤数、必填校验时机、误触概率、返回路径 |
| D2 视觉还原 | 对 Android 原图：间距/圆角/字号/颜色/图标一致性；深色不发灰发虚 |
| D3 反馈与状态 | 点击按压态、loading/空态/错误态/成功态齐全且文案准确 |
| D4 输入体验 | 中文输入、数字键盘、输入法弹起不遮挡、金额/日期控件易用 |
| D5 导航与可达 | Tab/更多菜单/返回/深层入口一致、无死链 |
| D6 动效与性能感知 | 切换流畅、列表不掉帧、无白屏闪烁 |
| D7 深色主题 | dark 目录覆盖无遗漏、对比度达标 |
| D8 无障碍 | accessibilityText/标签存在，抽查可读 |
| D9 文案与本地化 | 无英文残留、无截断、无错别字 |

## 7.2 严重度定义

- **P0**：阻断核心流程（无法记账/崩溃/关键数据丢失风险）。
- **P1**：明显体验缺陷（布局错位、遮挡、输入不可用、无反馈）。
- **P2**：一般缺陷/一致性（间距字号不齐、深色遗漏、文案不足）。
- **P3**：建议项（动效润色、无障碍增强、体验优化建议）。

## 7.3 判定纪律

- 截图+dump 不足以支持的结论不得入账（如「动效卡顿」需视频/连拍证据，无法取得则 WONTFIX+标注）。
- 同一问题多页复现 → 每页独立条目，便于分派。
- Auditor 与 Simulator 结论冲突 → 以证据为准；无证据 → 「无法确认」不入账或标 BLOCKED。

---

# Part 8 修复与回归规则

1. 最小修改：只改问题直接相关的文件与行；不重构、不改无关样式/文案。
2. 可回退：fix-log.md 按迭代追加：文件/行/原因；改动前必要时留副本到 evidence 备份。
3. 不掩盖：不通过改构建配置/包名/签名/测试数据掩盖源码问题。
4. 波及检测：D4/列表/状态机修复必须核对联动路径（loading/空态/选中/刷新/返回），fixNote 注明回归用例。
5. 回归闭环：FIXED → 串行构建新 HAP → Verifier 重放 → 双证据 → VERIFIED；失败最多回修 2 次 → BLOCKED。
6. 功能回归：修复可能影响功能时，跑 docs/testing/ 中对应用例并记录。

---

# Part 9 汇报与用户接口（暂停/继续/终止约定）

## 9.1 汇报节奏与内容

- 每轮 REPORTING 交付 `iteration_report_vN.md` + 口头摘要（修复清单、前后截图、账本统计、下一轮计划）。
- 自动暂停（3.4.3）随时可额外触发汇报，附原因与建议。

## 9.2 用户指令约定（优先级从高到低）

| 用户说法 | 动作 | 状态 |
|---|---|---|
| 「暂停 / 停一下 / 等我看」 | 当前操作完成后进入 SUSPENDED；不丢证据；不重试 | `pausedByUser=true` |
| 「继续 / 接着跑」 | 从 SUSPENDED 恢复（按 3.5 恢复规则） | 清 pausedByUser |
| 「终止 / 结束 / 不用跑了」 | 当前轮收尾（REPORTING）→ DONE | `stopRequested=true` |
| 「先修 XX / 优先 XX」 | 下一轮分片把 XX 页/条目排最前 | 写入 state.json.priority |
| 「这个不用管 / 关闭 XXX」 | 对应条目 → WONTFIX（deferReason=用户指示） | — |
| 「只测不修」 | 切换策略：FIXING 阶段跳过，条目全标 BLOCKED-FOR-REVIEW 等确认 | 提示词承诺项 |

任何指令都要在 run.log 记录。

---

# Part 10 交付物与目录结构

```
arkts_new/docs/ux-optimization/
├── README.md                      # 指向本 Runbook 与简约蓝图
├── UX_OPTIMIZATION_AGENT_PLAN.md  # 简约蓝图（保留，冲突以本文件为准）
├── env_decision.md                # M0：禁用清单+专用实例（2.3.2）/设备方案/深色命令/DB 路径/构建 sha256
├── state.json                     # 运行状态唯一事实源
├── ledger.json                    # 问题账本唯一事实源（+每轮 ledger_iterN.json 归档）
├── fix-log.md                     # 修复日志（按迭代追加）
├── iteration_report_vN.md         # 每轮汇报（模板 Part 13.B）
├── UX_OPTIMIZATION_REPORT.md      # 最终报告（九维度结论+遗留）
├── logs/                          # run.log / simulator_N / fixer_N / verifier_N / recovery.log
├── state/deviceTokens/            # 设备令牌（互斥锁）
└── evidence/
    ├── iterN/<Page>/<step>_ui.png, _dump.json, 可选 _db.sqlite
    ├── iterN/_pending/<page>_<seq>.json     # Simulator 待审计条目
    └── 深色比对/<Page>_dark_arkts.png + _dark_android.png
```

---

# Part 11 风险、重试与对策矩阵

| 风险 | 影响 | 对策 | 重试策略 |
|---|---|---|---|
| 模拟器离线/启动失败 | 设备操作无法进行 | M0 处理；如失败如实记录阻塞 | 最多 2 次（间隔 5 分钟）；仍失败→SUSPENDED 等用户 |
| **误用其他项目模拟器（P0 事故）** | 业务数据错乱、跨项目污染 | 2.3 隔离强制：禁用清单+专用实例+全程 `-t` | 一旦发现目标非专用实例：立即停止并零读写，记录后先复核 2.3 再继续 |
| 专用实例端口被占用/冲突 | 启动失败或连错设备 | 端口从禁用清单最大端口+10 起选并探测 | 换端口重试；仍冲突则上报用户 |
| 多实例内存不足 | 并行受限 | 3.7 实例数决策；回落 TIME_SLICE | 一次性回落，不反复 |
| 并发构建污染 build 目录 | 产物错乱 | 构建仅 Orchestrator 串行 | 单次失败重试 1 次；再失败暂停 |
| 多 Agent 同设备互斥 | 证据失真 | 设备令牌锁（3.6） | 死锁检测自动释放（15 分钟） |
| LLM 服务不可用 | J4 受限 | 降级走查+标注 LLM-DEPENDENT | 每轮探测一次，恢复即补跑 J4 |
| 深色命令与实际不符 | 证据无效 | M0 探针确认 | 按探针结果固化命令 |
| Release 签名缺失 | 只能验 debug | 全程标注 debug 包 | 不规避 |
| 修复引入功能回归 | 功能坏 | fixNote 标注回归用例 | Verifier 复跑对应用例 |
| 账本并发写坏 | 进度丢失 | Evidence 单点+原子写 | 每轮归档可回退 |
| 磁盘空间不足 | 证据丢失 | 每阶段 df 监控；低于阈值自动暂停 | 用户清理后恢复 |
| 长时间无进展 | 空转烧资源 | 自动暂停阈值（3.4.3） | 向用户汇报建议调整范围 |

---

# Part 12 完整启动提示词（可整体复制）

```
【角色】
你是本项目的 Orchestrator 执行 Agent。唯一任务是依据 Runbook 开展「体验优化 + 智能 Agent 模拟真实用户体验」的长期自主运行：用多 Agent 团队并行编排，问题账本驱动多轮循环（走查→审计→修复→构建→回归→汇报），直到问题清零或用户喊停。你不做任务范围之外的任何改动。

【定位与背景】
- Runbook（必须最先通读并持续以它为准）：
  /Users/rainyday/Desktop/migration/arkts_new/docs/UX_OPTIMIZATION_RUNBOOK.md
- 配套蓝图（冲突时以 Runbook 为准）：/Users/rainyday/Desktop/migration/arkts_new/docs/UX_OPTIMIZATION_AGENT_PLAN.md
- 目标工程：/Users/rainyday/Desktop/migration/arkts_new（bundle=org.totschnig.myexpenses，EntryAbility）
- 迁移已完成（ACCEPTANCE_CANDIDATE）。本阶段只做体验优化与真实用户模拟：不重复验证既有功能（复用 arkts_new/docs/testing/ 基线），不重跑迁移验收。
- 范围：全部页面（21 个页面文件，矩阵 Runbook Part 5）。

【用户确定约束（不得更改）】
1. 模拟环境=DevEco 模拟器；2. Agent 真实用户式交互操作逐步留证；3. 发现问题即修复（最小、可回退、可验证）；4. 每轮结束交付报告等待 review；5. 最大化使用 Agent 团队并行，共享资源串行。
6. **模拟器隔离（Runbook 2.3，P0 硬约束）**：本机有其他项目在用模拟器。执行前必须枚举并记录全部既有实例到 env_decision.md.forbiddenInstances（禁用清单），**必须新建本任务专用模拟器**（命名含 MyExpensesUX_ 前缀，端口避让禁用端口），**全程只连接专用实例**，所有 hdc 命令必须 `-t <专用端口>`；任何既有实例禁止连接/操作/读写。

【环境事实（已确认，直接复用，禁止重复探测）】
- macOS 15.7.7 (arm64)；python3=3.9.6；DevEco Studio 6.1 位于 /Applications/DevEco-Studio.app
- hdc=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc（绝对路径调用）
- 模拟器二进制=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator；模板 Huawei_Phone(API 11/12/13) 等
- 构建=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw（debug unsigned，Release 签名未配置）
- 本地 LLM 网关=/Users/rainyday/Desktop/migration/codearts_api.py（OpenAI 兼容，http://127.0.0.1:8765）
- 命令模板见 Runbook Part 2.2；模拟器隔离规则见 Runbook Part 2.3

【执行】
按 Runbook Part 4 执行：
- M0 环境就绪（读完 Runbook 后立即执行：**0. 先枚举既有实例记录禁用清单 → 新建专用模拟器 → 仅用专用实例**；然后 目录/设备方案/构建/安装/启动/输入探针/深色探针/DB 路径探针，产出 env_decision.md），然后进入轮次循环。
- 每轮：WALKTHROUGH（Simulator 并行，留证+待审计队列）→ AUDITING（Auditor 九维度判定入账本）→ FIXING（Fixer 最小修复）→ 串行构建（仅你执行，记 sha256）→ VERIFYING（Verifier 双证据）→ REPORTING（iteration_report_vN.md + 向用户汇报，等待 review）。
- 状态机、账本、断点续跑、自动暂停、资源治理、日志：Runbook Part 3；恢复流程 Part 3.5。
- 页面矩阵 Part 5；旅程脚本 Part 6；判定框架 Part 7；修复回归规则 Part 8；用户接口 Part 9。

【硬规则】
- 遵守 AGENTS.md：禁 Git；最小修改；不改构建配置/包名/签名掩盖；不重构无关模块。
- 双证据：操作证据（命令+返回）+ 状态证据（截图/dump/DB）；命令成功/未崩溃/回到初始页都不能单独算通过。
- 不伪造任何证据；日志含命令、时间戳、退出码。
- 每次操作后重新读最新状态，禁止复用旧坐标；环境异常先停止结论，恢复后再做。
- 达不到通过标准=未通过；证据不足=无法确认；两者都不得写成通过。
- 每个里程碑/轮次结束停下汇报，用户 review 后继续；用户「暂停/继续/终止/优先/关闭」按 Runbook Part 9 处理。
- **模拟器隔离（2.3，违反即 P0）**：绝不连接 forbiddenInstances 中的任何实例；所有设备命令必须 `-t <专用端口>`；一旦发现连接目标非专用实例，立即停止一切读写并上报。

【上下文治理（CodeArts 上下文小，必须执行 Part 3.9）】
- 磁盘即记忆：事实全部落盘（state/ledger/evidence/logs/handoff），对话只放指针和摘要；长文件、截图、日志全文绝不贴进对话。
- 每轮生成 round_handoff_vN.md（模板 13.D），跨轮/跨会话交接只带 handoff + L0 契约 + 当前列表，不延续上一轮对话。
- 子代理只收结构化任务、只回结构化结果（JSON/短字段），吐长文一律退回重产出。
- 上下文紧张（剩余<30% / 大页面 ×2 / 长文残留≥3）时立即执行 3.9.3：写 handoff → 重启会话 → 按 3.5 恢复，禁止硬撑。
- 命令输出先落盘 logs/ 再 grep 关键行回填；同一文件不得在对话中重复出现两次以上。

【阻塞与降级】
- 模拟器起不来/连线失败：如实记录+最多 2 次重试（间隔 5 分钟）→ SUSPENDED 等用户；只针对专用实例，不换既有实例。
- **误连接其他项目实例**：立即停止一切读写、记录时间与端口、不上报前不继续；如实汇报用户。
- LLM 不可用：J4 降级走查+标注 LLM-DEPENDENT，每轮探测恢复后补跑。
- Release 签名缺失：全程 debug 包标注，不冒充 release。
- 深色命令与实际不符：以 M0 探针结果固化。
- 自动暂停阈值触发：写 state.json.autoPause，汇报等待用户。

【交付物（落盘到本机）】
- env_decision.md、state.json、ledger.json（+每轮归档）、fix-log.md、iteration_report_vN.md、
  round_handoff_vN.md（每轮生成，供跨会话恢复）、UX_OPTIMIZATION_REPORT.md（最终）、
  logs/（run/simulator/fixer/verifier/recovery）、evidence/iterN/<Page>/...（截图/dump/DB）、state/deviceTokens/
- 最终汇报：修改文件清单、构建结果、安装运行结果、验证环境、已知限制与未修复问题。

【开始】
先通读 Runbook 与 AGENTS.md，输出执行计划摘要（状态机、并行策略、M0 命令序列、自动暂停阈值），然后从 M0 开始执行。以长期自主运行为目标：每轮结束汇报并等待 review，按用户指令继续或暂停。
```

---

# Part 13 附录

## 13.A 命令速查

> 所有设备命令必须显式 `-t <专用实例端口>`（隔离规则 2.3）；`P` 表示专用端口变量，如 `5561`。

| 目的 | 命令 |
|---|---|
| 枚举既有实例（禁用清单） | `$EMU -query`（或按 DevEco 实际子命令）；结果写入 env_decision.md.forbiddenInstances |
| 列出所有在线设备（核对用途） | `$HDC list targets`（只允许连接专用端口） |
| 新建专用实例 | `$EMU -create MyExpensesUX_<日期> -deviceType phone -osVersion <ver> ...`（端口避让） |
| 构建 | `hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon` |
| 安装 | `$HDC -t $P install -r <hap>` |
| 启动/停止 | `$HDC -t $P shell aa start -a EntryAbility -b org.totschnig.myexpenses` / `$HDC -t $P shell aa force-stop org.totschnig.myexpenses` |
| 布局 dump | `$HDC -t $P shell uitest dumpLayout`（结果 file recv 拉回） |
| 截图 | `$HDC -t $P shell snapshot_display`（file recv 拉回） |
| 点击/滑动/输入 | `$HDC -t $P shell uitest click x y` / `swipe x1 y1 x2 y2` / `uiInput text '中文'` |
| DB 快照 | `$HDC -t $P file recv /data/app/el2/100/base/org.totschnig.myexpenses/.../myexpenses.db <local>`（路径以 M0 探针为准） |
| 深色 | `$HDC -t $P shell settings put system color_mode 2`（M0 确认生效） |
| 内存评估 | `sysctl hw.memsize; vm_stat` |

## 13.B 轮次汇报模板（iteration_report_vN.md）

```md
# 迭代报告 vN
- 时间 / 轮次 / 运行时长 / 是否自动暂停
## 统计
- 本轮新增: X | 修复: Y | 验证通过: Z | BLOCKED: A | WONTFIX: B | DEFERRED: C
- 严重度分布: P0=x P1=y P2=z P3=w
## 修复清单
| id | 页面 | 严重度 | 摘要 | 证据 | 验证 |
## 关键对照截图
（修复前/后各 1~3 张，标注页面与步骤）
## 遗留与解释
- BLOCKED: ...（原因）
- WONTFIX: ...（原因）
- DEFERRED: ...（目标轮次）
## 预算消耗
- 轮次 x/20；单轮时长；磁盘剩余；实例状态
## 下一轮计划
- 分片调整 / 优先项（含用户指令）
## 待用户决策
- （若有）
```

## 13.C 常见问题

- **Q: 模拟器实例怎么查有哪些？** A: `$EMU -query` 或 `$EMU -help` 查看子命令；M0 探针后记录。
- **Q: dumpLayout 输出在哪？** A: 执行后在设备端生成文件，用 `$HDC file recv` 拉回；路径随版本变化，M0 记为固定值。
- **Q: 某条目一直 VERIFYING 卡住？** A: 同条目 2 次回修仍失败→BLOCKED；验证动作死锁由设备令牌回收处理。
- **Q: 用户中途要求只测不修？** A: 切换策略：FIXING 跳过，条目标 BLOCKED-FOR-REVIEW，待用户逐条确认。
- **Q: 中断很久后回来，状态乱了？** A: 永远先跑 Part 3.5 恢复流程，以 state.json+ledger.json 为准重建现场。
- **Q: 上下文快满了怎么办？** A: 执行 Part 3.9.3 压缩流程：生成 round_handoff → 重启会话 → 按 3.5 恢复；事实都在磁盘，不丢状态。
- **Q: 怎么看当前上下文剩余？** A: 无法精确计量时以触发条件为准（3.9.3）；保守起见每完成 1 个大页面走查即做一次「重启会话」式压缩。
- **Q: 多台设备在线，分不清哪台是专用实例？** A: 永远用 `-t <专用端口>` 显式指定（2.3）；专用端口以 env_decision.md.dedicatedInstance.port 为准，其余一律当作禁用。
- **Q: 想用既有模拟器省事可以吗？** A: 绝对不行（2.3 P0 约束）：那些是其他项目在用的实例，连接=业务错乱风险；必须新建专用实例。

## 13.D 轮次压缩交接模板（round_handoff_vN.md）

```md
# Round Handoff vN

- 轮次: vN | 起止: <time>~<time> | 预算: 轮 x/20, 本轮时长 <h>
- 生成者: Orchestrator | 生成时间: <time>

## 环境快照
- 实例: PhoneA(:5555) / PhoneB(:5557) | 在线: yes/no
- 最新 HAP: entry-default-unsigned.hap | sha256: <hash>
- LLM 网关: 可用/不可用 | 磁盘剩余: <x> GB

## 本轮统计（仅计数）
- 新增: <n> | 修复: <n> | 验证通过: <n> | BLOCKED: <n> | WONTFIX: <n> | DEFERRED: <n>

## 下轮必须处理（一行一条，id|page|severity|当前状态）
- UX-0007 | ExpenseEdit | P1 | VERIFIED(待 CLOSED)
- UX-0012 | AiAssistant | P1 | FIXED(待验证)
- UX-0021 | BalanceSheet | P2 | OPEN(待分派)

## 下轮分片表
- 组1: [PageA, PageB] ← 旅程 J2/J7
- 组2: [PageC] ← 旅程 J4(LLM-DEPENDENT)
- ...

## 已知坑（≤5 条，每条 ≤1 行）
- BalanceSheet 导出入口在顶栏三点菜单，截图标注意
- AiAssistant 确认气泡需等 2s 再 dump
- ...

## 待用户决策
- （若有：如 DEFERRED 项是否提前、范围是否收缩）
```

---

*本文档为执行规范，不包含代码改动。执行时遵守项目 AGENTS.md；所有证据必须真实落盘，不伪造。*