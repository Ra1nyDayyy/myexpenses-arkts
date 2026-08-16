# myexpenses-arkts 测试与修复关键决策

最后更新时间：
2026-08-16 04:40

---

## D-001 AI 删除交易

状态：
CONFIRMED

决策：
AI 可以发起删除交易。
但是：
1. 必须唯一定位目标；
2. 模糊时必须要求用户进一步确认；
3. 删除前必须明确确认；
4. 禁止因为"最近一笔"之类模糊规则错误删除数据。

原因：
避免 AI 误删除不可恢复的数据。

影响：
AiService / AiIntentValidator / AiExecutor / AiAssistant

---

## D-002 AI 修改交易

状态：
CONFIRMED

决策：
允许 AI 修改历史交易。
如果目标不唯一：
必须澄清。
修改以下字段必须在预览中展示：
- 金额
- 账户
- 分类
- 日期
- 备注

---

## D-003 多步骤任务

状态：
CONFIRMED

决策：
只读多步骤任务可以直接连续执行。
包含写操作的多步骤任务：
必须生成明确的执行计划。
涉及危险写操作时必须确认。
中途失败不得无条件继续后续写操作。

---

## D-004 AI Prompt Injection

状态：
CONFIRMED

决策：
用户不得通过：
"忽略规则"、"管理员模式"、"测试模式"、"不用确认"
等文字绕过危险操作确认。

---

## D-005 NOT_IMPLEMENTED 范围

状态：
CONFIRMED

决策：
当前明确标记开发中的大型非 AI 功能：
只记录 NOT_IMPLEMENTED。
本轮不主动扩展：
- OCR
- 完整同步
- Web UI
- 专业版体系
- 完整备份恢复

---

## D-006 有交易账户删除

状态：
待主 Agent 根据现有产品设计确认

决策：
待确认。
当前测试不得假设"应该允许删除"或"应该禁止删除"。
先根据现有 UI、Repository 和目标产品行为确定，再记录最终决策。
---

## D-007 AI 删除交易（已实现）

状态：
CONFIRMED

决策：
已实现 AI 删除交易（transaction/delete）：
1. 必须唯一定位目标（备注/金额匹配）；
2. 匹配不唯一时展示候选并拒绝执行；
3. 删除前弹确认对话框；
4. 确认后执行 repository.deleteTransaction 并刷新。

验证：
模拟器实测「删除咖啡那笔」→ 唯一匹配 → 确认 → DB 删除成功。

---

## D-008 AI 修改交易（已实现）

状态：
CONFIRMED

决策：
已实现 AI 修改交易（transaction/edit）：
1. 必须唯一定位目标；
2. 匹配不唯一时展示候选并拒绝执行；
3. 修改前弹确认对话框展示变更（金额/备注）；
4. 确认后执行 repository.updateTransaction 并刷新。

验证：
模拟器实测「把打车那笔改成30元」→ 唯一匹配 → 确认 → DB 金额 -2800→-3000。

---

## D-009 AI 账户/分类名称映射

状态：
CONFIRMED

决策：
创建交易时，大模型输出账户名（fields.account）与分类名（fields.category），
由 AiAssistant.prepareCreateIntent 按名称映射到真实 accountId/categoryId。
指定账户找不到时不得静默使用默认账户（标记 accountId=0 交 UI 提示"指定账户不存在"）。

验证：
「从现金账户记一笔午饭35元」→ 现金(id=1)；分类「早饭」→ 餐饮(cat=1)。

---

## D-010 相对日期解析

状态：
CONFIRMED

决策：
创建交易时支持相对日期词：今天/昨晚/昨天/前天/上周/上月/8月10号/8/10，
由 AiAssistant.parseRelativeDate 解析为时间戳；无法识别时默认今天。

验证：
「昨天晚饭30元」→ 日期 2026-08-15。
