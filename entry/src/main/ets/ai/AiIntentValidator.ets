import { AiIntent, AiIntentValidationResult } from './AiIntentCore';

/** MVP 安全白名单：单笔收支创建、账户创建、交易只读查询/筛选/排序、明确拒绝。 */
export class AiIntentValidator {
  static validate(intent: AiIntent): AiIntentValidationResult {
    if (intent.steps && intent.steps.length > 0) {
      // 多步骤：逐条校验，任一步不合法则整体拒绝（避免部分执行）
      for (let step of intent.steps) {
        const stepResult = AiIntentValidator.validate(step);
        if (!stepResult.valid) {
          return { valid: false, error: `执行计划第 ${intent.steps.indexOf(step) + 1} 步不被支持：${stepResult.error}` };
        }
      }
      return { valid: true, error: '' };
    }
    // 明确拒绝（大模型判定与记账无关）：直接放行，由 UI 展示拒绝文案
    if (intent.action === 'refuse') {
      return { valid: true, error: '' };
    }
    // 账户操作（account create/query/edit/delete）
    if (intent.domain === 'account') {
      if (intent.action === 'create') {
        const name = intent.fields['name'];
        if (typeof name !== 'string' || name.trim().length === 0) {
          return { valid: false, error: '创建账户必须包含账户名称，暂未执行' };
        }
        const keys: string[] = Object.keys(intent.fields);
        for (let key of keys) {
          if (key !== 'name' && key !== 'currency' && key !== 'accountType') {
            return { valid: false, error: `创建账户包含未知字段「${key}」，暂未执行` };
          }
        }
        return { valid: true, error: '' };
      }
      if (intent.action === 'query' || intent.action === 'edit' || intent.action === 'delete') {
        if (intent.action !== 'query' && !(intent.targets && intent.targets.length > 0)) {
          return { valid: false, error: '账户操作必须提供账户名称' };
        }
        if (intent.action === 'edit' && !(intent.fields['name'] || intent.fields['currency'] || intent.fields['accountType'])) {
          return { valid: false, error: '修改账户必须提供新字段（名称/货币/类型）' };
        }
        return { valid: true, error: '' };
      }
      return { valid: false, error: '当前安全版本仅支持账户创建/查询/修改/删除操作，暂未执行' };
    }
    // 模板操作（template create/query/edit/delete/use）
    if (intent.domain === 'template') {
      if (intent.action === 'create') {
        if (!(intent.fields['title'] || intent.fields['amount'])) {
          return { valid: false, error: '创建模板必须提供标题或金额' };
        }
        return { valid: true, error: '' };
      }
      if (intent.action === 'query') {
        return { valid: true, error: '' };
      }
      if (intent.action === 'edit' || intent.action === 'delete' || intent.action === 'use') {
        if (!(intent.targets && intent.targets.length > 0)) {
          return { valid: false, error: '模板操作必须提供模板名称' };
        }
        return { valid: true, error: '' };
      }
      return { valid: false, error: '当前安全版本仅支持模板创建/查询/修改/删除/使用操作，暂未执行' };
    }
    if (intent.domain !== 'transaction') {
      return { valid: false, error: '当前安全版本仅支持交易与账户操作，暂未执行' };
    }
    if (intent.subItems && intent.subItems.length > 0) {
      return { valid: false, error: '当前安全版本不支持拆分交易，暂未执行' };
    }

    const action = intent.action;
    if (action === 'query' || action === 'filter' || action === 'sort') {
      return { valid: true, error: '' };
    }
    if (action === 'delete' || action === 'edit') {
      // 删除/修改：需要明确目标（targets 含备注关键字/金额），由上层做唯一性匹配与确认
      if (action === 'delete' && !(intent.targets && intent.targets.length > 0) &&
        !(typeof intent.fields['comment'] === 'string' && intent.fields['comment'].length > 0) &&
        !(typeof intent.fields['amount'] === 'number' && intent.fields['amount'] > 0)) {
        return { valid: false, error: '删除交易必须提供目标描述（如备注或金额）' };
      }
      if (action === 'edit' && !(intent.targets && intent.targets.length > 0) &&
        !(typeof intent.fields['comment'] === 'string' && intent.fields['comment'].length > 0)) {
        return { valid: false, error: '修改交易必须提供目标描述（如备注）' };
      }
      return { valid: true, error: '' };
    }
    if (action !== 'create') {

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
        key !== 'categoryId' && key !== 'date' && key !== 'account' && key !== 'category') {
        return { valid: false, error: `创建交易包含未知字段「${key}」，暂未执行` };
      }
    }
    return { valid: true, error: '' };
  }
}
