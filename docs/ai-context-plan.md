# AI 对话交互增强实现方案（上下文记忆 / 新建对话 / 交互放宽）

> 角色：Planner Agent
> 目标工程：`/Users/rainyday/Desktop/migration/arkts_new`（myexpenses-arkts，ArkTS / ArkUI）
> 范围：只做规划与代码阅读，不改动任何业务代码
> 关联文件（已阅读）：
> - `entry/src/main/ets/pages/AiAssistant.ets`（对话编排，2745 行）
> - `entry/src/main/ets/database/AiService.ets`（大模型调用与 SYSTEM_PROMPT）
> - `entry/src/main/ets/ai/AiIntentCore.ets`（意图结构）
> - `entry/src/main/ets/ai/AiIntentValidator.ets`（白名单校验）
> - `entry/src/main/ets/ai/LocalIntentParser.ets`（本地单笔解析）
> - `entry/src/main/ets/database/AiExecutor.ets`（执行器，末端安全闸门）
> - `entry/src/main/ets/components/PageHeader.ets`（页面头部，支持 rightText/onRight）
> - `docs/testing/AI_PROMPT_TEST_CASES.md`（既有 AI 测试集与标准数据）

---

## 0. 现状分析（代码阅读结论）

### 0.1 对话链路（AiAssistant.sendChatMessage，L577-L791）

```
用户输入 chatInput
  → 追加 user 消息到 chatMessages（kind='text'，图片场景前缀"📷 图片"）
  → expirePendingConfirmBubbles()（放弃未确认的 confirm/plan/thinking）
  → attachmentsToDataUrls()（图片转 base64）
  → pushThinking() 推送思考气泡
  → AiService.understandWithThinking(text, imageDataUrls, onThinking)
  → intent.action === 'refuse' → 拒绝文案
  → AiIntentValidator.validate(intent) → 不通过则展示校验错误
  → steps 存在 → executeSteps（plan 气泡，危险步骤逐条确认）
  → account/template 域 → 执行器或确认气泡
  → transaction delete/edit → findTransactionsByIntent 匹配 → 多笔候选(candidates) / 唯一目标确认(confirm)
  → query/filter/sort → preciseQueryReply 本地计算 → pushAiText
  → create → prepareCreateIntent → 校验 → 推送 bill 气泡（aiIntent 保存待确认）
  → confirmChatBill() → executeConfirmed(plan) → replaceLastBill(结果文本)
```

关键状态变量（均在 AiAssistant 组件内）：

| 变量 | 类型 | 说明 |
|---|---|---|
| `chatMessages` | `ChatMessage[]`（@State） | 对话消息，kind：text / bill / confirm / plan / thinking / candidates |
| `aiIntent` | `AiIntent | null`（@State） | 待确认记账意图 |
| `pendingAction` | `PendingAction | null`（@State） | 待确认修改/删除操作 |
| `stepCtx` | `StepContext | null`（@State） | 多步骤执行上下文 |
| `stepResume` | `StepResumeContext | null`（private） | 危险步骤确认后恢复上下文 |
| `candidateList` | `Transaction[]`（@State） | 歧义消解候选交易 |
| `candidateType` | `string`（@State） | 候选类型 delete/edit |
| `chatAttachments` | `string[]`（@State） | 待发送图片 URI |
| `chatInput` | `string`（@State） | 输入框文本 |
| `aiLoading` | `boolean`（@State） | 请求中标志 |

- chatMessages 的消息角色：`user`（kind 恒为 text）与 `ai`（kind 可为 text/bill/confirm/plan/thinking/candidates）。
- AI 的友好回复统一经 `pushAiText(text)` 追加 `{ role:'ai', kind:'text', text }`；账单确认成功/失败分别经 `replaceLastBill`/`declineChatBill` 替换 bill 气泡为文本。
- 当前**没有任何清除会话入口**（grep "清除/清空/新建/重置" 无命中）。

### 0.2 AiService 请求体与 Prompt（L18-L314）

- `AI_CONFIG`：阿里云百炼兼容接口，model = `qwen3.8-max`，`temperature: 0.1`，`max_tokens: 800`（思考模式）/ 600（普通）。
- **请求体 messages 只有 `[system, user]` 两条，无任何历史消息** → 这是"记不住上下文"的直接根因。
- `understandWithThinking(text, images?, onThinking?)`：callLlmWithThinking → onThinking 回调 → `AiIntentValidator.validate` → 返回 `{ intent, thinking }`。
- 图片场景：user content 为多模态数组（text + image_url base64）。
- SYSTEM_PROMPT 严格点：
  1. 只输出一个 JSON，禁止任何其他文字/markdown；
  2. domain 白名单：transaction/account/template；
  3. action 白名单：create/query/filter/sort/edit/delete/refuse；
  4. create 必填 type+amount、字段严格白名单；
  5. 领域边界：与记账无关一律 refuse（列了写代码/翻译/闲聊/数学/天气/新闻/笑话等大量负面示例）；
  6. 多步骤任务输出 `{"steps":[...]}`。
- `AI_CAPABILITY_BOUNDARY_MESSAGE` 常量已定义但页面未使用（页面用自定义文案）。

### 0.3 AiIntentValidator 严格校验（L5-L116）

会导致"太严格"的规则（对用户输入拒绝）：

| 规则位置 | 规则 | 用户观感 |
|---|---|---|
| L22-L33 | account/create：name 必须非空，字段仅允许 name/currency/accountType，未知字段拒绝 | 说"建个账户"无名字会被拒 |
| L36-L38 | account edit/delete：必须有 targets | "把刚才那个账户删了"无目标名被拒 |
| L44 | account 其他动作拒绝 | — |
| L58-L60 | template edit/delete/use：必须有 targets | 同上 |
| L65-L67 | domain 非 transaction/account/template 拒绝 | — |
| L68-L70 | subItems（拆分）拒绝 | — |
| L78-L82 | delete：必须 targets 或 comment 或 amount>0 | "删掉那笔"被拒 |
| L83-L86 | edit：必须 targets 或 comment | "改一下"被拒 |
| L100-L107 | create：type 必须 expense/income；amount 必须 >0 的有限数字 | — |
| L108-L114 | create 字段白名单（type/amount/comment/accountId/categoryId/date/account/category），未知字段拒绝 | 大模型多输出一个字段即整体拒绝 |
| L89-L97 | 未知 action（split/export 等）拒绝 | — |

注：多步骤 `steps` 递归逐条校验，任一步不合法整体拒绝（L6-L14）。`refuse` 直接放行（L17-L19），由 UI 展示拒绝文案。

### 0.4 金额上限（安全底线，勿动）

- `AiExecutionPlan.convertMajorToMinor`（L44-L46）：单笔 > 99999999.99 拒绝。
- `LocalIntentParser`（L28）：本地路径同样限制 > 99999999.99。
- 写操作确认：`execute()` 对 transaction/create 直接 `failure`（L67-L69），必须走 `executeConfirmed(plan)`（用户确认后的封闭计划）→ 这是必须保留的安全闸门。

---

## 1. 上下文记忆方案

### 1.1 请求体改造：历史消息拼入 messages

**改动点：`AiService.ets`**

新增导出类型与参数：

```ts
export interface AiHistoryMessage {
  role: 'user' | 'assistant';
  content: string;
}
```

`understand` / `understandWithThinking` 增加可选参数 `history?: AiHistoryMessage[]`：

```ts
async understand(text: string, images?: string[], history?: AiHistoryMessage[]): Promise<AiIntent>
async understandWithThinking(text: string, images?: string[], onThinking?: (t: string) => void, history?: AiHistoryMessage[]): Promise<AiUnderstandResult>
```

请求体组装（callLlm / callLlmWithThinking 均改造）：

```ts
messages: [
  { role: 'system', content: SYSTEM_PROMPT },
  ...(history || []).map(h => ({ role: h.role, content: h.content })),
  { role: 'user', content: userContent }
]
```

**保留轮数与截断策略（在 AiAssistant 侧生成 history 时执行，或抽为 AiService 静态工具）：**

1. 只保留最近 **10 条**消息（约 5 轮 user/assistant 往返；含本次之外的对话）。取 `chatMessages` 尾部 10 条 `kind==='text'` 的 user/ai 消息（见 1.2）。
2. 单条消息内容超 **200 字符**截断（`slice(0, 200)`），防止历史把长思考/长查询塞爆。
3. 历史总字符预算 **约 2000 字符**（约为 max_tokens 800 的合理安全余量）：从最旧开始丢弃超出部分，保证请求体稳定且不超模型上下文。
4. 图片场景：历史中只带 user 文本（`📷 图片：...`），**不重发 base64 图**（避免请求体爆炸、避免旧图语义污染）。
5. 当前轮 user 消息始终为最后一条，不由历史裁剪影响。

### 1.2 历史消息格式：存"用户可见的友好文本"

**核心原则：绝不把内部意图 JSON / thinking / planSteps 喂回模型。**

在 AiAssistant 新增：

```ts
private buildLlmHistory(): AiHistoryMessage[] {
  const turns: AiHistoryMessage[] = [];
  for (const m of this.chatMessages) {
    if (m.kind !== 'text') continue;               // 跳过 bill/confirm/plan/thinking/candidates
    if (m.role === 'user') {
      turns.push({ role: 'user', content: m.text });
    } else if (m.role === 'ai' && m.text && m.text.trim().length > 0) {
      turns.push({ role: 'assistant', content: m.text });
    }
  }
  return this.trimHistory(turns, 10, 2000, 200);   // 最近10条 / 总2000字符 / 单条200字符
}
```

- **assistant 侧内容来源**：`pushAiText` 追加的友好文本（如"已创建支出交易 ¥35.00 CNY（午饭），账户 支付宝"、"这个月收入 ¥8000.00..."）、`replaceLastBill` 后的写入结果。这些正是用户在屏幕上看到的可读摘要，模型能据此理解"刚才那笔 = 午饭 35 元"。
- **不应进入历史的 kind**：
  - `bill`（待确认账单，无文本，确认后已被替换）；
  - `confirm`（待确认卡片，无最终结果文本）；
  - `plan`（步骤 JSON，若被替换为"（上一步操作未确认…）"也无语义价值，可一并过滤）；
  - `thinking`（模型推理过程，喂回会造成上下文污染与长度膨胀）；
  - `candidates`（候选列表气泡，无文本）。
- 过滤规则补充：若 AI 文本以"（上一步操作未确认"或"（上一次思考已被新指令打断"开头（expirePendingConfirmBubbles 生成的占位文本），直接跳过，不进入历史。

### 1.3 SYSTEM_PROMPT 调整（支持引用前文 + 适度放宽）

在 `AiService.ets` 的 SYSTEM_PROMPT 中新增两段（追加在现有内容之后、【再次强调】之前或替换该段）：

```
【多轮上下文】
对话历史中会包含之前用户说过的话。用户可能用"刚才那笔""上一条""之前记的""刚才说的"等指代前文。
- 遇到指代时，结合历史判断目标：如历史出现过"午饭35元"，用户说"把刚才那笔改成40元"，应输出
  {"domain":"transaction","action":"edit","targets":["午饭"],"fields":{"amount":40}}。
- 用户说"都记到刚才那个账户"时，可复用历史中的账户名填入 account 字段。
- 指代无法从历史明确解析时，允许输出一个保守的、最可能的目标描述，由系统做匹配确认，不要拒绝。
- 历史仅作参考，不得虚构历史中不存在的金额或交易。

【宽容理解】
- 允许口语、省略语、轻微语病；只要包含记账/金额/收支/账户/模板任一语义就尝试理解。
- 只有与记账完全无关时才输出 refuse；不要因为句子夹杂无关词（如"顺便"）就整体拒绝。
- 用户表达不完整时（如"再记一笔""帮我记一下"），结合历史推断缺省字段（金额/账户/分类）。
```

**保持不变的严格底线（写进注释明确不放松）：**
- 输出必须是合法 JSON，且必须通过 AiIntentValidator 白名单；
- create 必须 type+amount>0；金额上限 99999999.99 由 AiExecutionPlan 强制；
- 写操作（create/edit/delete/account delete/template use）必须经 UI 结构化预览 + 确认，不得因"模型认为已确认"而跳过；
- 领域边界仍需拒绝与记账完全无关的请求（防注入/防滥用）。

### 1.4 是否需要上下文摘要机制

- **简单版（本期推荐）**：只带最近 N 条原文友好文本（即 1.1 + 1.2 方案）。实现成本低、可解释、可回退，覆盖"刚才那笔""上一条"等绝大多数诉求。
- **进阶版（本期不做，记为后续项）**：维护结构化记忆对象，例如 `{ lastAccount, lastCategory, lastAmount, recentComments[], recentTransactions[] }`，在每次执行成功后由 AiAssistant 更新，随请求体以一条 `system` 或 `user` 消息注入（如"已知上下文：最近账户=支付宝；最近备注=[午饭,咖啡]…"）。收益是 token 更省、引用更准，但需新增状态维护与一致性测试，建议二期实施。
- 结论：本期落地简单版；文档记录进阶版作为 `docs/ai-context-plan.md` 的后续增强项。

---

## 2. 新建对话方案

### 2.1 UI 入口位置

- 推荐：**页面头部右侧文字按钮"新建"**，复用 `PageHeader` 已支持的 `rightText` + `onRight` 契约（PageHeader.ets L96-L108），零新组件。
  ```ts
  PageHeader({
    title: 'AI 记账与洞察',
    showBack: false,
    showSpeech: false,
    rightText: '新建',
    onRight: () => this.newConversation(),
    onBack: () => { router.back(); }
  })
  ```
- 备选：`showMore` + moreMenu 下拉放"新建对话"（若头部空间紧张）；但主推文字按钮，触达直接、符合"对话页顶部工具栏"心智。
- 与现有返回/设置并存：本页 showBack=false、无设置项，右侧无冲突；若未来加设置，再把"新建"并入更多菜单。
- 不新增弹窗确认（遵循项目偏好：操作不弹窗）；点击即清空并给出 toast 反馈。

### 2.2 清空范围（newConversation()）

```ts
private newConversation(): void {
  if (this.aiLoading) return;                    // 请求中禁止清空，避免脏状态
  this.chatMessages = [];                        // 对话消息全清
  this.aiIntent = null;                          // 待确认记账
  this.pendingAction = null;                     // 待确认修改/删除
  this.stepCtx = null;                           // 多步骤执行上下文
  this.stepResume = null;                        // 危险步骤恢复上下文
  this.candidateList = [];                       // 歧义候选
  this.candidateType = 'delete';
  this.chatAttachments = [];                     // 附件
  this.chatInput = '';                           // 输入框
  this.insightCache.clear();                     // 洞察缓存（可选，防止旧分析污染）
  this.pushWelcome();                            // 恢复欢迎语
  promptAction.showToast({ message: '已开启新对话' });
}
```

- 将 `aboutToAppear` 中的欢迎语初始化（L140-L146）抽为 `private pushWelcome()`，供 aboutToAppear 与 newConversation 复用，保证两处文案一致。
- `chatMessages` 需要恢复欢迎语气泡（`{ role:'ai', text:'你好，我是你的记账助手...', kind:'text' }`），保持首屏与冷启动一致。
- **上下文隔离**：由于 history 完全由 `buildLlmHistory()` 从 `chatMessages` 现算，清空 `chatMessages` 即天然隔离旧上下文，无需额外历史缓存清理。

### 2.3 其他考虑

- 新建时若 `aiLoading === true`：按钮禁用或直接 return（最简），避免与进行中的请求竞争状态。
- 无需持久化会话（无跨页面历史需求），页面重进即新会话（aboutToAppear 空 chatMessages 时已有欢迎语逻辑）。

---

## 3. 交互放宽建议（只列可操作规则调整，不触碰安全底线）

| # | 调整点 | 文件/位置 | 具体改动 | 风险 |
|---|---|---|---|---|
| 1 | 历史注入 | AiService callLlm/callLlmWithThinking | messages 加 history（见 1.1） | 低：仅影响请求体 |
| 2 | Prompt 增加多轮引用说明 | AiService SYSTEM_PROMPT | 追加【多轮上下文】段（见 1.3） | 低 |
| 3 | Prompt 增加宽容理解说明 | AiService SYSTEM_PROMPT | 追加【宽容理解】段（见 1.3） | 低；JSON 稳定性靠校验兜底 |
| 4 | temperature 0.1 → 0.3 | AiService L196/L278 | 略提温让表达更自然 | 中：JSON 输出稳定性下降，靠 max_tokens + 正则提取 JSON + Validator 兜底；如回归不稳可回退 0.1 |
| 5 | AI_CAPABILITY_BOUNDARY_MESSAGE 语义放宽 | AiService L24 | 文案从"暂时没能理解"改为"没太听懂，试试说'午饭35元'或'这个月花了多少'，也可以说'刚才那笔改一下'" | 低（文案） |
| 6 | 用户输入首查本地兜底保持现状 | AiAssistant L562-L574 | isUnrelatedQuery 保持（防注入），但**不拦截**带记账语义的句子（现状已如此） | — |
| 7 | 多步骤 refire 文案软化 | AiAssistant | "暂不支持"提示附"换个说法试试"引导 | 低 |

**必须保留的安全底线（明确禁止放宽）：**
- `AiIntentValidator` 的写操作字段白名单与 targets 要求（防未知字段/防无目标误操作）；
- 删除/修改必须唯一匹配 + 对话内确认（confirm 气泡），多笔必须候选选择；
- 记账 create 必须结构化 bill 预览 + 显式确认（executeConfirmed）；
- 金额上限 99999999.99（AiExecutionPlan / LocalIntentParser）；
- 与记账无关请求 refuse（防滥用/注入）；
- account/template 删除同样走确认流程。

---

## 4. 实施步骤清单（按文件/函数）

### Step 1：AiService.ets —— 支持历史
- [ ] 新增导出 `AiHistoryMessage` 接口。
- [ ] `understand` / `understandWithThinking` 增加 `history?: AiHistoryMessage[]` 参数。
- [ ] `callLlm` / `callLlmWithThinking`：messages 组装加入 history（插在 system 与当前 user 之间）。
- [ ] SYSTEM_PROMPT 追加【多轮上下文】与【宽容理解】两段。
- [ ] （可选）temperature 0.1 → 0.3；如回归不稳回退。

### Step 2：AiAssistant.ets —— 生成历史 + 传入
- [ ] 新增 `private buildLlmHistory(): AiHistoryMessage[]`（按 1.2 过滤 kind='text'，跳过占位文本）。
- [ ] 新增 `private trimHistory(turns, maxCount, maxChars, maxPerMsg)` 裁剪工具。
- [ ] `sendChatMessage` 中调用 `understandWithThinking(text, imageDataUrls, onThinking, this.buildLlmHistory())`。
- [ ] `recognizeIntent`（一句话记账入口 L1120）同样传入 `this.buildLlmHistory()`，保证两个入口共享同一上下文。
- [ ] 欢迎语初始化抽为 `private pushWelcome()`。

### Step 3：AiAssistant.ets —— 新建对话
- [ ] PageHeader 增加 `rightText: '新建'` + `onRight: () => this.newConversation()`。
- [ ] 新增 `private newConversation()`（按 2.2 清空全部状态并恢复欢迎语 + toast）。
- [ ] 检查 `newConversation` 与 `expirePendingConfirmBubbles`、`removeThinking` 无冲突（清空直接重置数组即可）。

### Step 4：测试
- [ ] 单测（可选，若 entry/src/test 有 AI 测试套件）：`buildLlmHistory` 过滤规则（bill/confirm/plan/thinking/candidates 不入历史）、10 条上限、200 字符截断、总预算裁剪、占位文本过滤。
- [ ] 模拟器/真机验收用例见第 5 节。

### Step 5：文档与回归
- [ ] 更新 `docs/testing/AI_PROMPT_TEST_CASES.md`：新增"多轮上下文""新建对话隔离""引用前文写操作确认"用例。
- [ ] 回归既有 AI_PROMPT_TEST_CASES 关键用例（A 组记账、写操作确认、refuse 边界）。

---

## 5. 验收标准

### 5.1 功能用例（可执行、可判定）

| 编号 | 场景 | 操作 | 预期结果（通过标准） |
|---|---|---|---|
| CTX-1 | 多轮引用记账 | ①"午饭35元"→确认写入；②"刚才那笔改成40元" | ②能定位到"午饭"（唯一匹配），出现修改确认气泡"金额改为 40 元"，确认后数据库该笔变为 -40.00，备注仍为"午饭" |
| CTX-2 | 多轮引用查询 | ①记"咖啡25元"；②"我今天花了多少" | ②查询结果包含午饭+咖啡合计，且 AI 能提及"包括刚才记的午饭/咖啡"（Prompt 引用历史生效） |
| CTX-3 | 历史越界隔离 | 新建对话后再发"刚才那笔改成40元" | 不再引用旧会话：未找到匹配 → 提示"未找到匹配的交易"，不会改动任何历史数据 |
| CTX-4 | 新建对话 UI | 点击头部"新建" | chatMessages 清空、恢复欢迎语、toast"已开启新对话"；输入框与附件清空；无残留 confirm/plan 气泡 |
| CTX-5 | 新建后首条请求 | 新建后发"午饭35元" | 正常生成 bill 预览，确认后写入；历史请求体只含欢迎语上下文（无旧会话内容） |
| CTX-6 | 写操作安全底线 | 有上下文时发"删掉午饭那笔" | 仍必须出现删除确认气泡，确认后才删除；且 confirm 气泡引用目标为"午饭"（不会误删别的） |
| CTX-7 | 金额上限底线 | 发"记一笔100000000元"（>99999999.99） | 拒绝写入，提示金额过大；预览不生成或生成后确认被执行器拒绝 |
| CTX-8 | 无关请求底线 | 有上下文时发"帮我写段代码" | 仍 refuse，不因上下文放行 |
| CTX-9 | 字段注入底线 | 上下文存在时发构造的未知字段句子 | 校验器拒绝未知字段，不落库 |

### 5.2 非功能验收

- 请求体长度：带 10 条历史时 POST body ≤ 约 10KB（不含图片 base64），无超时（readTimeout 120s 场景下首字节正常返回）。
- 性能：历史构建为纯内存计算，无额外 IO；消息渲染 key 稳定（现有 key 含 index，清空后正常重渲染）。
- 可回退：`understand` 不带 history 时行为与现状完全一致（参数可选），AB 可回退。
- 安全：无任何写操作因"历史上下文"绕过确认/白名单/金额上限；refuse 边界不因历史放宽。

### 5.3 证据要求（遵循项目门禁）

- 每条用例记录：操作证据（点击/输入命令返回）+ 状态证据（数据库查询结果、气泡内容、toast）。
- 生成"前后"对比：新建对话前 vs 后请求体 messages 数量（可用抓包/日志打印 history 长度验证）。
- 更新 `docs/testing/AI_PROMPT_TEST_CASES.md` 与测试报告，标注 PASS/FAIL 与严重度。

---

## 6. 风险点

| 风险 | 说明 | 缓解 |
|---|---|---|
| JSON 稳定性下降（提温后） | temperature 上调可能让模型偶发输出非 JSON/多余字段 | 保持 max_tokens、正则提取 JSON、Validator 兜底；回归不稳即回退 0.1 |
| 历史污染 | 占位文本/内部文案误入历史导致引用错误 | 严格按 1.2 过滤规则；单测覆盖 |
| 指代误解析 | "刚才那笔"在历史多笔相似时可能匹配错 | 依赖 UI 确认气泡兜底：匹配多笔时走候选选择，不直接执行 |
| 长对话 token 膨胀 | 历史无上限可能超模型上下文 | 10 条/2000 字符/单条 200 字符三重裁剪 |
| 图片重发 | 历史含 base64 会爆炸 | 历史只带文本，当前轮才带图 |
| 一句话记账入口上下文不同步 | recognizeIntent 若忘记传 history 会上下文不一致 | 两个入口统一调 `buildLlmHistory()`；单测断言 |
| 新建时请求进行中 | aiLoading 时清空导致状态错乱 | newConversation 首行 `if (this.aiLoading) return;` |

---

## 7. 后续增强项（本期不做）

- 结构化记忆（进阶摘要）：维护最近账户/分类/交易的结构化对象随请求注入。
- 会话持久化：退出页面重进保留上下文（本期页面重进即新会话）。
- 多轮"逐步补全"：用户只说"再记一笔"时模型结合历史补全缺省字段后仍走 bill 预览。