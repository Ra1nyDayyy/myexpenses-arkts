# AI Safe MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to execute this plan task-by-task.

**Goal:** 把当前 AI 功能收敛为可用、可解释、不会误操作的安全 MVP：一句话记账可离线工作，消费洞察统计口径正确，所有写操作先预览再确认，危险能力明确禁用，并改善入口、状态反馈和校对界面。

**Architecture:** 将 AI 能力拆成纯逻辑层和界面/执行层。`LocalIntentParser` 负责高频简单记账的本地解析；`AiIntentValidator` 负责动作白名单和字段校验；`InsightCalculator` 统一交易、拆分账单和转账的统计口径；`AiAssistant` 只承担交互编排；`AiExecutor` 在最末端再次执行安全校验。客户端不保存模型供应商密钥，复杂自然语言请求在未配置可信后端时返回明确的能力边界提示。

**Tech Stack:** ArkTS、ArkUI、Hypium、relationalStore、Hvigor

## Global Constraints

- 不在客户端源码、资源或构建配置中保存任何模型供应商密钥；现有密钥必须删除并立即轮换。
- 当前脏工作区是正在运行的迁移基线，不重置、不覆盖无关改动，也不在用户未要求时暂存或提交。
- 简单收支识别优先走本地解析；可信后端未配置时，复杂请求必须清楚说明暂不可用，不得伪装成网络或模型故障。
- MVP 只开放安全、可预览的单笔收支创建和只读洞察；编辑、删除、多步骤、拆分、导出等危险或不完整能力明确禁用。
- 所有写操作都必须经过结构化预览和用户显式确认；执行层再次校验，不能只靠 UI 隐藏。
- 未接入真实语音识别前，不展示录音入口。
- 统计必须区分普通交易、拆分父记录、拆分子记录和转账，避免重复计算。
- 新纯逻辑先写测试并确认失败，再写最小实现；页面改动至少通过完整构建和模拟器流程验证。

## Task 1: 建立安全意图核心与本地解析

**Files:**

- Create: `entry/src/main/ets/ai/AiIntentCore.ets`
- Create: `entry/src/main/ets/ai/LocalIntentParser.ets`
- Create: `entry/src/main/ets/ai/AiIntentValidator.ets`
- Modify: `entry/src/main/ets/database/AiService.ets`
- Test: `entry/src/test/AiIntentCore.test.ets`

### Step 1: 写失败测试

覆盖：金额/备注提取、收入关键词、默认支出、小数金额、无金额拒绝、危险动作拒绝、多步骤拒绝、创建动作必要字段检查。

### Step 2: 运行测试或测试编译，确认 RED

优先运行项目 Hypium 单测；若仓库没有可执行本地测试任务，则用 `assembleHap` 触发测试源码编译，并记录缺失符号导致的失败证据。

### Step 3: 写最小实现

定义统一 `AiIntent` 与校验结果；实现本地简单收支解析；安全白名单只允许 transaction/create 与只读 query/filter/sort；写操作必须包含合法金额。

### Step 4: 移除客户端密钥并改造服务

删除硬编码 Authorization 密钥。简单表达先由本地解析处理；复杂请求仅在配置可信业务后端时转发，未配置时抛出面向用户的能力边界错误。不得将模型供应商密钥改放到另一个客户端文件。

### Step 5: 运行 GREEN

运行目标测试/测试编译和完整模块构建，确认通过。

## Task 2: 统一 AI 洞察统计口径

**Files:**

- Create: `entry/src/main/ets/ai/InsightCalculator.ets`
- Test: `entry/src/test/InsightCalculator.test.ets`

### Step 1: 写失败测试

覆盖：普通支出/收入、转账排除、拆分父记录不重复计入总额、拆分子记录用于分类、月份筛选边界、分类金额汇总。

### Step 2: 运行 RED

确认测试因实现缺失失败，并保留命令与输出摘要。

### Step 3: 写最小计算器

总收支和月度趋势只统计非拆分子记录的主交易并排除转账；分类统计使用普通主交易与拆分子项，排除拆分父记录和转账；支出展示使用绝对值。

### Step 4: 运行 GREEN

运行目标测试/测试编译与完整构建，确认通过。

## Task 3: 收紧执行边界

**Files:**

- Modify: `entry/src/main/ets/database/AiExecutor.ets`
- Test: `entry/src/test/AiExecutorSafety.test.ets`（若数据库依赖无法隔离，则由意图校验纯逻辑测试覆盖，并用构建验证集成）

### Step 1: 在执行入口增加二次校验

任何意图在访问数据库前调用 `AiIntentValidator`。不在 MVP 白名单内的动作立即返回明确错误。

### Step 2: 限制可执行写操作

只允许单笔 transaction/create；禁止模糊匹配编辑/删除、多步骤、拆分和未完成的高级动作。写入字段必须来自已经通过校验的结构化预览。

### Step 3: 验证

运行安全测试和完整构建；检查所有原调用点仍能编译。

## Task 4: 重构 AI 助手交互

**Files:**

- Modify: `entry/src/main/ets/pages/AiAssistant.ets`
- Modify as needed: `entry/src/main/resources/base/element/string.json`

### Step 1: 明确页面信息架构

将页面拆成“一句话记账”和“消费洞察”两个清晰模式；默认展示可点击示例，不再让长示例挤在单行输入框里。

### Step 2: 完成状态模型

覆盖空白、识别中、待校对、执行中、成功、失败、能力暂不可用。错误显示在页面内并提供重试或返回编辑，不输出原始 JSON/异常堆栈。

### Step 3: 完成结构化校对

对单笔收支显示并允许校对：收支类型、金额、账户、分类/备注、日期。写操作只在用户点击确认后执行。修正把备注同时写入分类的错误。

### Step 4: 接入正确洞察

使用 `InsightCalculator`；分类卡片显示金额和占比；时间范围标签与实际筛选一致；多币种场景不做无汇率的直接加总，至少按币种分组或明确限制。

### Step 5: 隐藏未完成能力

移除/隐藏伪语音入口和不能安全落地的动作示例；在不可用请求上说明当前支持范围。

## Task 5: 改善 AI 入口与可发现性

**Files:**

- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify/Create as needed: AI 图标和无障碍文案资源

### Step 1: 替换误导图标

把类似扫码的系统图标换成明确的 AI/星光图标，并添加“AI 记账与洞察”无障碍说明。

### Step 2: 增加稳定入口

在更多菜单中增加同名入口，保留列表页快捷入口；导航时传入当前账户上下文，便于校对页给出合理默认账户。

### Step 3: 构建验证

运行完整模块构建，处理 ArkUI 类型或资源错误。

## Task 6: 集成、回归与模拟器验收

**Files:**

- Modify: `entry/src/test/List.test.ets`
- Update: `migration/ai-function-ui-modification-report.md`（补充落地状态与遗留项）

### Step 1: 注册新测试套件

确保核心意图和统计测试进入现有测试入口。

### Step 2: 安全扫描

运行密钥特征扫描，确认 `entry/src/main` 不再存在供应商密钥；检查客户端请求不再携带模型供应商 Authorization。

### Step 3: 完整构建

使用 DevEco SDK/JBR 执行 debug HAP 构建，区分既有警告与新增错误。

### Step 4: 模拟器端到端验收

安装新 HAP，验证：AI 入口含义明确；“午饭35元”能本地识别；校对可修改关键字段；未确认前不写库；确认后仅新增一笔；危险请求被拦截；洞察无拆分重复统计；无语音假入口；离线/无后端时提示清楚。

### Step 5: 更新报告

把每一项标记为已完成、部分完成或后续项，附构建/模拟器证据和仍需服务端配合的事项（密钥轮换、可信 AI 网关、真实 ASR）。

