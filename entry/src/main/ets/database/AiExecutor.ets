/**
 * AI 意图执行器：把 AiIntent 翻译为 Repository 操作
 * 阶段 1 覆盖：账户/交易/模板 的 创建 / 删除 / 查看 / 使用模板
 */
import { Repository } from './Repository';
import { AiIntent } from './AiService';
import { AiIntentValidator } from '../ai/AiIntentValidator';
import {
  AiExecutionPlan,
  ConfirmedTransactionPlan,
  PreparedTransactionPlan
} from '../ai/AiExecutionPlan';
import { Account, AccountType } from '../model/Account';
import { Transaction } from '../model/Transaction';
import { Template } from '../model/SupportEntities';
import { Category } from '../model/Category';
import { formatDate, generateUuid } from '../common/FormatUtils';
import { formatMoney } from '../model/Money';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { currencyByCode } from '../model/CurrencyUnit';

export interface AiConfirmedTransactionRepository {
  getAccount(id: number): Promise<Account | null>;
  getCategory(id: number): Promise<Category | null>;
  insertTransaction(transaction: Transaction): Promise<number>;
}

export interface AiExecutionResult {
  ok: boolean;
  wrote: boolean;
  message: string;
  transactionId: number;
}

/** 交易匹配结果 */
export interface TransactionMatch {
  tx: Transaction;
}

export class AiExecutor {
  private repository: Repository = Repository.getInstance();
  private confirmedRepository: AiConfirmedTransactionRepository;
  private static instance: AiExecutor;

  constructor(confirmedRepository?: AiConfirmedTransactionRepository) {
    this.confirmedRepository = confirmedRepository ? confirmedRepository : Repository.getInstance();
  }

  static getInstance(): AiExecutor {
    if (!AiExecutor.instance) {
      AiExecutor.instance = new AiExecutor();
    }
    return AiExecutor.instance;
  }

  /**
   * 执行意图，返回执行结果描述
   */
  async execute(intent: AiIntent): Promise<AiExecutionResult> {
    // 最末端安全闸门：即使未来 UI 或调用方误放行，也不能直接执行危险意图。
    const validation = AiIntentValidator.validate(intent);
    if (!validation.valid) {
      const detail = validation.error.replace('，暂未执行', '').replace('暂未执行', '').trim();
      return this.failure(`暂未执行：${detail}`);
    }
    if (intent.domain === 'transaction' && intent.action === 'create') {
      return this.failure('暂未执行：原始指令不能直接写入，请先检查结构化预览并明确确认');
    }
    const message = await this.executeSingle(intent);
    return { ok: true, wrote: false, message: message, transactionId: -1 };
  }

  /** 只接受用户确认后的封闭计划；不从仓库补默认账户、日期或模糊字段。 */
  async executeConfirmed(plan: ConfirmedTransactionPlan): Promise<AiExecutionResult> {
    const prepared: PreparedTransactionPlan = AiExecutionPlan.prepare(plan);
    if (!prepared.valid) {
      return this.failure(`暂未执行：${prepared.error}`);
    }

    const account = await this.confirmedRepository.getAccount(prepared.accountId);
    if (!account) {
      return this.failure('暂未执行：所选账户不存在或已失效');
    }
    if (account.currency !== prepared.currency) {
      return this.failure('暂未执行：所选账户币种已变化，请重新预览确认');
    }
    const actualFractionDigits = currencyByCode(account.currency).fractionDigits;
    if (actualFractionDigits !== prepared.fractionDigits) {
      return this.failure('暂未执行：账户币种精度已变化，请重新预览确认');
    }

    let categoryId = -1;
    if (prepared.categoryId >= 0) {
      const category = await this.confirmedRepository.getCategory(prepared.categoryId);
      if (!category) {
        return this.failure('暂未执行：所选分类不存在或已失效');
      }
      const expectedCategoryType = prepared.type === 'income' ? 1 : -1;
      if (category.type !== 0 && category.type !== expectedCategoryType) {
        return this.failure('暂未执行：所选分类与收支类型不匹配，请重新校对');
      }
      categoryId = category.id;
    }

    const transaction = new Transaction();
    transaction.accountId = account.id;
    transaction.currency = account.currency;
    transaction.amount = prepared.type === 'income' ? prepared.amountMinor : -prepared.amountMinor;
    transaction.date = prepared.date;
    transaction.valueDate = prepared.date;
    transaction.categoryId = categoryId;
    transaction.comment = prepared.comment;
    transaction.uuid = generateUuid();
    const transactionId = await this.confirmedRepository.insertTransaction(transaction);
    if (transactionId <= 0) {
      return this.failure('写入失败：账本没有返回有效交易编号');
    }
    const typeLabel = prepared.type === 'income' ? '收入' : '支出';
    const amountText = formatMoney(prepared.amountMinor, prepared.fractionDigits);
    return {
      ok: true,
      wrote: true,
      message: `已创建${typeLabel}交易 ${amountText} ${account.currency}${prepared.comment ? '（' + prepared.comment + '）' : ''}，账户 ${account.label}`,
      transactionId: transactionId
    };
  }

  private failure(message: string): AiExecutionResult {
    return { ok: false, wrote: false, message: message, transactionId: -1 };
  }

  private async executeSingle(intent: AiIntent): Promise<string> {
    const domain = intent.domain;
    const action = intent.action;
    if (domain === 'account') {
      return this.executeAccount(action, intent);
    }
    if (domain === 'transaction') {
      return this.executeTransaction(action, intent);
    }
    if (domain === 'template') {
      return this.executeTemplate(action, intent);
    }
    return `暂不支持的操作：${domain}/${action}`;
  }

  /** ===== 账户操作 ===== */
  private async executeAccount(action: string, intent: AiIntent): Promise<string> {
    if (action === 'edit') {
      return this.editAccount(intent);
    }
    if (action === 'sort') {
      return this.sortAccounts(intent);
    }
    if (action === 'create') {
      const name = String(intent.fields['name'] || 'AI 账户');
      const acc = new Account();
      acc.label = name;
      acc.currency = String(intent.fields['currency'] || 'CNY');
      acc.type = intent.fields['accountType'] === 'cash' ? AccountType.CASH : AccountType.BANK;
      acc.uuid = generateUuid();
      await this.repository.insertAccount(acc);
      return `已创建账户「${name}」（${acc.type === AccountType.CASH ? '现金' : '银行'}，${acc.currency}）`;
    }
    if (action === 'delete') {
      const name = this.firstTarget(intent);
      const accounts = await this.repository.getAccounts();
      const acc = accounts.find((a: Account) => a.label.includes(name));
      if (!acc) {
        return `未找到账户「${name}」，无法删除`;
      }
      const txCount = (await this.repository.getTransactions(acc.id)).length;
      if (txCount > 0) {
        return `账户「${name}」下有 ${txCount} 笔交易，删除账户不会删除交易（安全起见请到账户页操作）`;
      }
      await this.repository.deleteAccount(acc.id);
      return `已删除账户「${name}」`;
    }
    if (action === 'query') {
      const name = this.firstTarget(intent);
      const accounts = await this.repository.getAccounts();
      if (name) {
        const acc = accounts.find((a: Account) => a.label.includes(name));
        if (acc) {
          const tx = await this.repository.getTransactions(acc.id);
          let bal = 0;
          for (let t of tx) {
            bal += t.amount;
          }
          return `账户「${acc.label}」余额：${formatMoney(bal, 2)} 元（共 ${tx.length} 笔交易）`;
        }
        return `未找到账户「${name}」`;
      }
      // 列出所有账户余额
      let lines: string[] = [];
      for (let acc of accounts) {
        const tx = await this.repository.getTransactions(acc.id);
        let bal = 0;
        for (let t of tx) {
          bal += t.amount;
        }
        lines.push(`${acc.label}：${formatMoney(bal, 2)} 元`);
      }
      return `账户余额：\n${lines.join('\n')}`;
    }
    return `暂不支持的账户操作：${action}`;
  }

  /** ===== 交易操作 ===== */
  private async executeTransaction(action: string, intent: AiIntent): Promise<string> {
    if (action === 'create') {
      return this.createTransaction(intent);
    }
    if (action === 'delete') {
      return this.deleteTransaction(intent);
    }
    if (action === 'query') {
      return this.queryTransactions(intent);
    }
    if (action === 'edit') {
      return this.editTransaction(intent);
    }
    if (action === 'filter') {
      return this.filterTransactions(intent);
    }
    if (action === 'split') {
      return this.splitTransaction(intent);
    }
    if (action === 'export') {
      return this.exportTransactions(intent);
    }
    return `暂不支持的交易操作：${action}`;
  }

  private async createTransaction(intent: AiIntent): Promise<string> {
    return '暂未执行：原始指令不能直接写入，请先检查结构化预览并明确确认';
  }

  private async deleteTransaction(intent: AiIntent): Promise<string> {
    const keyword = this.firstTarget(intent) || String(intent.fields['comment'] || '');
    if (!keyword) {
      return '请说明要删除哪笔交易（如"删除咖啡那笔"）';
    }
    const accounts = await this.repository.getAccounts();
    let found: Transaction | null = null;
    for (let acc of accounts) {
      const txList = await this.repository.getTransactions(acc.id);
      // 按备注/金额匹配
      const amount = Number(intent.fields['amount'] || 0);
      found = txList.find((t: Transaction) => {
        const matchKw = keyword.length > 0 && t.comment.includes(keyword);
        const matchAmt = amount > 0 && Math.abs(t.amount) === Math.round(amount * 100);
        return matchKw || matchAmt;
      }) || null;
      if (found) {
        break;
      }
    }
    if (!found) {
      return `未找到匹配「${keyword}」的交易`;
    }
    await this.repository.deleteTransaction(found.id);
    return `已删除交易「${found.comment || '无备注'}」${formatMoney(Math.abs(found.amount), 2)} 元`;
  }

  private async queryTransactions(intent: AiIntent): Promise<string> {
    const keyword = this.firstTarget(intent) || String(intent.fields['comment'] || '');
    const accounts = await this.repository.getAccounts();
    let lines: string[] = [];
    let count = 0;
    for (let acc of accounts) {
      const txList = await this.repository.getTransactions(acc.id);
      for (let t of txList.slice(0, 50)) {
        if (keyword && !t.comment.includes(keyword)) {
          continue;
        }
        count++;
        const dateStr = formatDate(t.date);
        const typeLabel = t.isTransfer() ? '转账' : (t.amount > 0 ? '收入' : '支出');
        lines.push(`${dateStr} ${typeLabel} ${formatMoney(Math.abs(t.amount), 2)} ${t.comment || ''}`);
        if (count >= 10) {
          break;
        }
      }
      if (count >= 10) {
        break;
      }
    }
    if (lines.length === 0) {
      return keyword ? `未找到包含「${keyword}」的交易` : '暂无交易记录';
    }
    return `最近交易${keyword ? '（含' + keyword + '）' : ''}：\n${lines.join('\n')}`;
  }

  /** ===== 模板操作 ===== */
  private async executeTemplate(action: string, intent: AiIntent): Promise<string> {
    if (action === 'edit') {
      return this.editTemplate(intent);
    }
    if (action === 'create') {
      const accounts = await this.repository.getAccounts();
      if (accounts.length === 0) {
        return '没有可用账户，请先创建账户';
      }
      const tpl = new Template();
      tpl.title = String(intent.fields['title'] || 'AI 模板');
      tpl.accountId = accounts[0].id;
      const type = String(intent.fields['type'] || 'expense');
      const amount = Number(intent.fields['amount'] || 0);
      tpl.amount = Math.round(amount * 100) * (type === 'income' ? 1 : -1);
      tpl.comment = String(intent.fields['comment'] || '');
      tpl.isIncome = type === 'income';
      const categoryName = String(intent.fields['category'] || '');
      if (categoryName) {
        const cats = await this.repository.getCategories();
        const cat = cats.find((c: Category) => c.label.includes(categoryName));
        if (cat) {
          tpl.categoryId = cat.id;
        }
      }
      const recurrence = String(intent.fields['recurrence'] || '');
      tpl.recurrence = this.recurrenceValue(recurrence);
      await this.repository.insertTemplate(tpl);
      return `已创建模板「${tpl.title}」${type === 'income' ? '收入' : '支出'} ${amount} 元${tpl.recurrence > 0 ? '（' + recurrence + '）' : ''}`;
    }
    if (action === 'delete') {
      const name = this.firstTarget(intent);
      const templates = await this.repository.getTemplates();
      const tpl = templates.find((t: Template) => t.title.includes(name));
      if (!tpl) {
        return `未找到模板「${name}」`;
      }
      await this.repository.deleteTemplate(tpl.id);
      return `已删除模板「${tpl.title}」`;
    }
    if (action === 'use') {
      const name = this.firstTarget(intent);
      const templates = await this.repository.getTemplates();
      const tpl = templates.find((t: Template) => t.title.includes(name));
      if (!tpl) {
        return `未找到模板「${name}」`;
      }
      const txId = await this.repository.instantiateTemplate(tpl);
      if (txId > 0) {
        return `已按模板「${tpl.title}」创建交易 ${formatMoney(Math.abs(tpl.amount), 2)} 元`;
      }
      return '模板创建交易失败';
    }
    return `暂不支持的模板操作：${action}`;
  }

  /** ===== 编辑操作（阶段 2）===== */

  /** 编辑账户（改名/改类型/改货币） */
  private async editAccount(intent: AiIntent): Promise<string> {
    const name = this.firstTarget(intent);
    const accounts = await this.repository.getAccounts();
    const acc = accounts.find((a: Account) => a.label.includes(name));
    if (!acc) {
      return `未找到账户「${name}」`;
    }
    let changed: string[] = [];
    const newName = String(intent.fields['name'] || '');
    if (newName && newName !== acc.label) {
      acc.label = newName;
      changed.push(`名称→${newName}`);
    }
    const newCurrency = String(intent.fields['currency'] || '');
    if (newCurrency && newCurrency !== acc.currency) {
      acc.currency = newCurrency;
      changed.push(`货币→${newCurrency}`);
    }
    const newType = String(intent.fields['accountType'] || '');
    if (newType) {
      const t = newType === 'cash' ? AccountType.CASH : AccountType.BANK;
      if (t !== acc.type) {
        acc.type = t;
        changed.push(`类型→${newType === 'cash' ? '现金' : '银行'}`);
      }
    }
    if (changed.length === 0) {
      return `未识别到要修改的账户字段（改名/改货币/改类型）`;
    }
    await this.repository.updateAccount(acc);
    return `已修改账户「${name}」：${changed.join('，')}`;
  }

  /** 账户排序（按名称/余额） */
  private async sortAccounts(intent: AiIntent): Promise<string> {
    const sortBy = String(intent.fields['sortBy'] || 'date');
    const direction = String(intent.fields['sortDirection'] || 'asc');
    const accounts = await this.repository.getAccounts();
    let sorted = [...accounts];
    if (sortBy.includes('名') || sortBy.includes('name') || sortBy.includes('label')) {
      sorted.sort((a: Account, b: Account) => a.label.localeCompare(b.label));
    } else if (sortBy.includes('额') || sortBy.includes('余') || sortBy.includes('balance') || sortBy.includes('amount')) {
      // 按余额排序（需要计算余额）
      const bal = new Map<number, number>();
      for (let acc of sorted) {
        const tx = await this.repository.getTransactions(acc.id);
        let s = 0;
        for (let t of tx) {
          s += t.amount;
        }
        bal.set(acc.id, s);
      }
      sorted.sort((a: Account, b: Account) => {
        const ba = bal.get(a.id) || 0;
        const bb = bal.get(b.id) || 0;
        return ba - bb;
      });
    } else {
      return `暂不支持按「${sortBy}」排序账户`;
    }
    if (direction.includes('desc') || direction.includes('降')) {
      sorted.reverse();
    }
    // 更新排序字段（账户列表顺序由 id 决定，这里只展示结果）
    let lines: string[] = [];
    for (let acc of sorted) {
      const tx = await this.repository.getTransactions(acc.id);
      let s = 0;
      for (let t of tx) {
        s += t.amount;
      }
      lines.push(`${acc.label}：${formatMoney(s, 2)} 元`);
    }
    return `账户排序结果（${sortBy} ${direction === 'desc' ? '降序' : '升序'}）：\n${lines.join('\n')}`;
  }

  /** 编辑交易（改金额/备注/类别） */
  private async editTransaction(intent: AiIntent): Promise<string> {
    const keyword = this.firstTarget(intent) || String(intent.fields['comment'] || '');
    if (!keyword) {
      return '请说明要修改哪笔交易（如"把咖啡改成40"）';
    }
    const found = await this.findTransaction(keyword);
    if (!found) {
      return `未找到匹配「${keyword}」的交易`;
    }
    const tx = found.tx;
    let changed: string[] = [];
    const amount = Number(intent.fields['amount'] || 0);
    if (amount > 0) {
      const sign = tx.amount >= 0 ? 1 : -1;
      tx.amount = sign * Math.round(amount * 100);
      changed.push(`金额→${amount} 元`);
    }
    const newComment = String(intent.fields['comment'] || '');
    if (newComment && newComment !== tx.comment) {
      tx.comment = newComment;
      changed.push(`备注→${newComment}`);
    }
    const categoryName = String(intent.fields['category'] || '');
    if (categoryName) {
      const cats = await this.repository.getCategories();
      const cat = cats.find((c: Category) => c.label.includes(categoryName));
      if (cat) {
        tx.categoryId = cat.id;
        changed.push(`类别→${categoryName}`);
      }
    }
    if (changed.length === 0) {
      return '未识别到要修改的字段（金额/备注/类别）';
    }
    await this.repository.updateTransaction(tx);
    return `已修改交易「${tx.comment || '无备注'}」：${changed.join('，')}`;
  }

  /** 筛选交易（按时间范围/类别） */
  private async filterTransactions(intent: AiIntent): Promise<string> {
    const dateRange = String(intent.fields['dateRange'] || '');
    const categoryName = String(intent.fields['category'] || '');
    const accounts = await this.repository.getAccounts();
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
    let startTs = 0;
    if (dateRange.includes('本') && dateRange.includes('月')) {
      startTs = new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000;
    } else if (dateRange.includes('上') && dateRange.includes('月')) {
      startTs = new Date(now.getFullYear(), now.getMonth() - 1, 1).getTime() / 1000;
      // 上月结束 = 本月1号
    } else if (dateRange.includes('周')) {
      startTs = startOfToday - 7 * 86400;
    } else if (dateRange.includes('天') || dateRange.includes('今天')) {
      startTs = startOfToday;
    }
    let lines: string[] = [];
    let count = 0;
    for (let acc of accounts) {
      const txList = await this.repository.getTransactions(acc.id);
      for (let t of txList.slice(0, 100)) {
        if (startTs > 0 && t.date < startTs) {
          continue;
        }
        if (dateRange.includes('上') && dateRange.includes('月') && t.date >= new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000) {
          continue;
        }
        if (categoryName && t.categoryId >= 0) {
          const cat = await this.repository.getCategory(t.categoryId);
          if (cat && !cat.label.includes(categoryName)) {
            continue;
          }
        }
        count++;
        const dateStr = formatDate(t.date);
        lines.push(`${dateStr} ${t.amount > 0 ? '收入' : '支出'} ${formatMoney(Math.abs(t.amount), 2)} ${t.comment || ''}`);
        if (count >= 10) {
          break;
        }
      }
      if (count >= 10) {
        break;
      }
    }
    if (lines.length === 0) {
      return `筛选「${dateRange || '当前'}」无交易记录`;
    }
    return `筛选结果（${dateRange || '全部'}${categoryName ? '·' + categoryName : ''}）：\n${lines.join('\n')}`;
  }

  /** 编辑模板（改金额/标题/周期） */
  private async editTemplate(intent: AiIntent): Promise<string> {
    const name = this.firstTarget(intent);
    const templates = await this.repository.getTemplates();
    const tpl = templates.find((t: Template) => t.title.includes(name));
    if (!tpl) {
      return `未找到模板「${name}」`;
    }
    let changed: string[] = [];
    const amount = Number(intent.fields['amount'] || 0);
    if (amount > 0) {
      const sign = tpl.amount >= 0 ? 1 : -1;
      tpl.amount = sign * Math.round(amount * 100);
      changed.push(`金额→${amount} 元`);
    }
    const newTitle = String(intent.fields['title'] || '');
    if (newTitle && newTitle !== tpl.title) {
      tpl.title = newTitle;
      changed.push(`标题→${newTitle}`);
    }
    const recurrence = String(intent.fields['recurrence'] || '');
    if (recurrence) {
      const v = this.recurrenceValue(recurrence);
      if (v > 0) {
        tpl.recurrence = v;
        changed.push(`周期→${recurrence}`);
      }
    }
    if (changed.length === 0) {
      return '未识别到要修改的模板字段（金额/标题/周期）';
    }
    await this.repository.updateTemplate(tpl);
    return `已修改模板「${name}」：${changed.join('，')}`;
  }

  /** 查找交易（按备注关键字） */
  private async findTransaction(keyword: string): Promise<TransactionMatch | null> {
    const accounts = await this.repository.getAccounts();
    for (let acc of accounts) {
      const txList = await this.repository.getTransactions(acc.id);
      const tx = txList.find((t: Transaction) => t.comment.includes(keyword));
      if (tx) {
        return { tx: tx };
      }
    }
    return null;
  }

  /** 拆分交易（对齐安卓拆分：父记录 + 子项） */
  private async splitTransaction(intent: AiIntent): Promise<string> {
    const amount = Number(intent.fields['amount'] || 0);
    const subItems = intent.subItems;
    if (amount <= 0 || !subItems || subItems.length < 2) {
      return '无法识别拆分项，请说明拆分金额和各项（如"拆分50买日用品和菜"）';
    }
    const accounts = await this.repository.getAccounts();
    const account = accounts.length > 0 ? accounts[0] : null;
    if (!account) {
      return '没有可用账户';
    }
    const parent = new Transaction();
    parent.accountId = account.id;
    parent.comment = '';
    parent.date = Math.floor(Date.now() / 1000);
    parent.valueDate = parent.date;
    const parts: Transaction[] = [];
    for (let item of subItems) {
      const part = new Transaction();
      part.accountId = account.id;
      part.comment = String(item['comment'] || '');
      part.amount = -Math.round(Number(item['amount'] || 0) * 100);
      part.date = parent.date;
      part.valueDate = parent.date;
      const categoryName = String(item['category'] || '');
      if (categoryName) {
        const cats = await this.repository.getCategories();
        const cat = cats.find((c: Category) => c.label.includes(categoryName));
        if (cat) {
          part.categoryId = cat.id;
        }
      }
      parts.push(part);
    }
    await this.repository.saveSplitTransaction(parent, parts);
    return `已创建拆分交易 ${amount} 元（${subItems.map((i: Record<string, string | number>) => `${i['comment']} ${i['amount']}`).join('、')}）`;
  }

  /** 导出交易 CSV（写入应用沙箱） */
  private async exportTransactions(intent: AiIntent): Promise<string> {
    const dateRange = String(intent.fields['dateRange'] || '');
    const accounts = await this.repository.getAccounts();
    const now = new Date();
    let startTs = 0;
    if (dateRange.includes('本') && dateRange.includes('月')) {
      startTs = new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000;
    } else if (dateRange.includes('上') && dateRange.includes('月')) {
      startTs = new Date(now.getFullYear(), now.getMonth() - 1, 1).getTime() / 1000;
    }
    let lines: string[] = ['日期,类型,金额,备注'];
    for (let acc of accounts) {
      const txList = await this.repository.getTransactions(acc.id);
      for (let t of txList) {
        if (startTs > 0 && t.date < startTs) {
          continue;
        }
        const dateStr = new Date(t.date * 1000).toISOString().slice(0, 10);
        const typeLabel = t.isTransfer() ? '转账' : (t.amount > 0 ? '收入' : '支出');
        const comment = t.comment ? t.comment : '';
        lines.push(`${dateStr},${typeLabel},${formatMoney(Math.abs(t.amount), 2)},${comment}`);
      }
    }
    const csv = lines.join('\n');
    // 写入应用沙箱 files 目录
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const dir = context.filesDir;
      const fileName = `export_${Date.now()}.csv`;
      const file = await fs.open(`${dir}/${fileName}`, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      await fs.write(file.fd, csv);
      await fs.close(file.fd);
      return `已导出 ${lines.length - 1} 笔交易到 ${dir}/${fileName}`;
    } catch (e) {
      return '导出失败：' + JSON.stringify(e);
    }
  }

  /** ===== 工具方法 ===== */
  private firstTarget(intent: AiIntent): string {
    return intent.targets && intent.targets.length > 0 ? intent.targets[0] : '';
  }

  private recurrenceValue(label: string): number {
    if (label.includes('每')) {
      if (label.includes('月')) return 4;
      if (label.includes('周')) return 3;
      if (label.includes('年')) return 6;
      if (label.includes('天')) return 2;
    }
    return 0;
  }
}
