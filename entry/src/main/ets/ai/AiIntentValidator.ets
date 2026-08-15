import { AiIntent, AiIntentValidationResult } from './AiIntentCore';

/** MVP 安全白名单：单笔收支创建，以及交易的只读查询、筛选和排序。 */
export class AiIntentValidator {
  static validate(intent: AiIntent): AiIntentValidationResult {
    if (intent.steps && intent.steps.length > 0) {
      return { valid: false, error: '当前安全版本不支持多步骤操作，暂未执行' };
    }
    if (intent.domain !== 'transaction') {
      return { valid: false, error: '当前安全版本仅支持交易操作，暂未执行' };
    }
    if (intent.subItems && intent.subItems.length > 0) {
      return { valid: false, error: '当前安全版本不支持拆分交易，暂未执行' };
    }

    const action = intent.action;
    if (action === 'query' || action === 'filter' || action === 'sort') {
      return { valid: true, error: '' };
    }
    if (action !== 'create') {
      if (action === 'edit') {
        return { valid: false, error: '当前安全版本不支持通过 AI 编辑历史交易，暂未执行' };
      }
      if (action === 'delete') {
        return { valid: false, error: '当前安全版本不支持通过 AI 删除历史交易，暂未执行' };
      }
      if (action === 'split') {
        return { valid: false, error: '当前安全版本不支持通过 AI 拆分交易，暂未执行' };
      }
      if (action === 'export') {
        return { valid: false, error: '当前安全版本不支持通过 AI 导出交易，暂未执行' };
      }
      return { valid: false, error: '当前安全版本不支持此交易操作，暂未执行' };
    }

    const transactionType = intent.fields['type'];
    if (transactionType !== 'expense' && transactionType !== 'income') {
      return { valid: false, error: '创建交易必须明确收入或支出类型，暂未执行' };
    }
    const amount = intent.fields['amount'];
    if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
      return { valid: false, error: '创建交易必须包含大于 0 的有效金额，暂未执行' };
    }
    const keys: string[] = Object.keys(intent.fields);
    for (let key of keys) {
      if (key !== 'type' && key !== 'amount' && key !== 'comment' && key !== 'accountId' &&
        key !== 'categoryId' && key !== 'date') {
        return { valid: false, error: `创建交易包含未知字段「${key}」，暂未执行` };
      }
    }
    return { valid: true, error: '' };
  }
}
