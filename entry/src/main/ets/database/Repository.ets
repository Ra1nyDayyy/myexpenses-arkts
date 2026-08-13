import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { Account, AccountType, AccountGrouping, SortDirection } from '../model/Account';
import { Transaction, CrStatus, SPLIT_CATID } from '../model/Transaction';
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag, Budget, Debt, Template } from '../model/SupportEntities';
import { currencyByCode } from '../model/CurrencyUnit';
import { generateUuid } from '../common/FormatUtils';

/** 复杂搜索条件（对齐安卓 SearchRequest） */
export interface SearchCriterion {
  type: string;
  op: string;
  value: string;
  extra?: string;
}

/**
 * 数据仓库：对应 Android db2/Repository* 系列
 * 单例，负责所有 CRUD 与汇总查询
 */
export class Repository {
  private static instance: Repository | null = null;

  static getInstance(): Repository {
    if (!Repository.instance) {
      Repository.instance = new Repository();
    }
    return Repository.instance;
  }

  private store(): relationalStore.RdbStore {
    const s = DbHelper.getInstance().getStore();
    if (!s) {
      throw new Error('数据库未初始化');
    }
    return s;
  }

  // ==================== 账户 ====================

  async getAccounts(): Promise<Account[]> {
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.orderByAsc('grouping');
    predicates.orderByDesc('opening_balance');
    const result = await this.store().query(predicates);
    const accounts: Account[] = [];
    try {
      while (result.goToNextRow()) {
        accounts.push(this.rowToAccount(result));
      }
    } finally {
      result.close();
    }
    // 计算汇总
    for (let acc of accounts) {
      await this.fillAccountSums(acc);
    }
    return accounts;
  }

  async getAccount(id: number): Promise<Account | null> {
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    const result = await this.store().query(predicates);
    let account: Account | null = null;
    try {
      if (result.goToNextRow()) {
        account = this.rowToAccount(result);
      }
    } finally {
      result.close();
    }
    if (account) {
      await this.fillAccountSums(account);
    }
    return account;
  }

  async insertAccount(account: Account): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': account.label,
      'description': account.description,
      'opening_balance': account.openingBalance,
      'currency': account.currency,
      'type': account.type,
      'color': account.color,
      'grouping': account.grouping,
      'criterion': account.criterion,
      'exclude_from_totals': account.excludeFromTotals ? 1 : 0,
      'uuid': account.uuid,
      'sealed': account.sealed ? 1 : 0,
      'sort_by': account.sortBy,
      'sort_direction': account.sortDirection,
      'exchange_rate': account.exchangeRate,
      'dynamic': account.dynamic ? 1 : 0,
      'parent_id': account.parentId >= 0 ? account.parentId : null,
      'bank_id': account.bankId >= 0 ? account.bankId : null,
      'last_used': account.lastUsed,
      'flag_id': account.flagId > 0 ? account.flagId : 1
    };
    return this.store().insert('accounts', values);
  }

  async updateAccount(account: Account): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': account.label,
      'description': account.description,
      'opening_balance': account.openingBalance,
      'currency': account.currency,
      'type': account.type,
      'color': account.color,
      'grouping': account.grouping,
      'criterion': account.criterion,
      'exclude_from_totals': account.excludeFromTotals ? 1 : 0,
      'sealed': account.sealed ? 1 : 0,
      'sort_by': account.sortBy,
      'sort_direction': account.sortDirection,
      'exchange_rate': account.exchangeRate,
      'dynamic': account.dynamic ? 1 : 0,
      'flag_id': account.flagId > 0 ? account.flagId : 1
    };
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', account.id);
    return this.store().update(values, predicates);
  }

  async deleteAccount(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  async setAccountSealed(id: number, sealed: boolean): Promise<number> {
    const values: relationalStore.ValuesBucket = { 'sealed': sealed ? 1 : 0 };
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    return this.store().update(values, predicates);
  }

  async setAccountExcludeFromTotals(id: number, exclude: boolean): Promise<number> {
    const values: relationalStore.ValuesBucket = { 'exclude_from_totals': exclude ? 1 : 0 };
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    return this.store().update(values, predicates);
  }

  async setAccountGrouping(id: number, grouping: AccountGrouping): Promise<number> {
    const values: relationalStore.ValuesBucket = { 'grouping': grouping };
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    return this.store().update(values, predicates);
  }

  async setAccountCriterion(id: number, criterion: number): Promise<number> {
    const values: relationalStore.ValuesBucket = { 'criterion': criterion };
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    return this.store().update(values, predicates);
  }

  /**
   * 获取账户标记列表（account_flags）
   */
  async getAccountFlags(): Promise<Tag[]> {
    const predicates = new relationalStore.RdbPredicates('account_flags');
    predicates.orderByAsc('flag_sort_key');
    const result = await this.store().query(predicates);
    const flags: Tag[] = [];
    try {
      while (result.goToNextRow()) {
        const tag = new Tag();
        tag.id = result.getLong(result.getColumnIndex('id'));
        tag.label = result.getString(result.getColumnIndex('flag_label'));
        flags.push(tag);
      }
    } finally {
      result.close();
    }
    return flags;
  }

  /**
   * 设置账户标记
   */
  async setAccountFlag(id: number, flagId: number): Promise<number> {
    const values: relationalStore.ValuesBucket = { 'flag_id': flagId };
    const predicates = new relationalStore.RdbPredicates('accounts');
    predicates.equalTo('id', id);
    return this.store().update(values, predicates);
  }

  private rowToAccount(result: relationalStore.ResultSet): Account {
    const account = new Account();
    account.id = result.getLong(result.getColumnIndex('id'));
    account.label = result.getString(result.getColumnIndex('label'));
    account.description = result.getString(result.getColumnIndex('description'));
    account.openingBalance = result.getLong(result.getColumnIndex('opening_balance'));
    account.currency = result.getString(result.getColumnIndex('currency'));
    account.type = result.getLong(result.getColumnIndex('type')) as AccountType;
    account.color = result.getLong(result.getColumnIndex('color'));
    account.grouping = result.getLong(result.getColumnIndex('grouping')) as AccountGrouping;
    account.criterion = result.getLong(result.getColumnIndex('criterion'));
    account.excludeFromTotals = result.getLong(result.getColumnIndex('exclude_from_totals')) === 1;
    account.uuid = result.getString(result.getColumnIndex('uuid'));
    account.sealed = result.getLong(result.getColumnIndex('sealed')) === 1;
    account.sortBy = result.getString(result.getColumnIndex('sort_by'));
    account.sortDirection = result.getLong(result.getColumnIndex('sort_direction')) as SortDirection;
    account.exchangeRate = result.getDouble(result.getColumnIndex('exchange_rate'));
    account.dynamic = result.getLong(result.getColumnIndex('dynamic')) === 1;
    const parentIdIdx = result.getColumnIndex('parent_id');
    account.parentId = result.isColumnNull(parentIdIdx) ? -1 : result.getLong(parentIdIdx);
    const bankIdIdx = result.getColumnIndex('bank_id');
    account.bankId = result.isColumnNull(bankIdIdx) ? -1 : result.getLong(bankIdIdx);
    const lastUsedIdx = result.getColumnIndex('last_used');
    account.lastUsed = result.isColumnNull(lastUsedIdx) ? 0 : result.getLong(lastUsedIdx);
    const flagIdx = result.getColumnIndex('flag_id');
    account.flagId = result.isColumnNull(flagIdx) ? 1 : result.getLong(flagIdx);
    return account;
  }

  /**
   * 填充账户汇总（当前余额/收入/支出/转账等）
   */
  private async fillAccountSums(account: Account): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('account_id', account.id);
    // 主交易行（非拆分部分）：parent_id 为 NULL
    predicates.isNull('parent_id');
    const result = await this.store().query(predicates);
    let currentBalance = account.openingBalance;
    let sumIncome = 0;
    let sumExpense = 0;
    let sumTransfer = 0;
    let clearedTotal = 0;
    let reconciledTotal = 0;
    try {
      while (result.goToNextRow()) {
        const amount = result.getLong(result.getColumnIndex('amount'));
        const accountIdIdx = result.getColumnIndex('account_id');
        const transferAccountIdx = result.getColumnIndex('transfer_account');
        const isTransfer = !result.isColumnNull(transferAccountIdx) && result.getLong(transferAccountIdx) !== -1;
        currentBalance += amount;
        if (amount > 0) {
          sumIncome += amount;
        } else {
          sumExpense += amount;
        }
        if (isTransfer) {
          sumTransfer += amount;
        }
        const crIdx = result.getColumnIndex('cr_status');
        const cr = result.getString(crIdx);
        if (cr === CrStatus.CLEARED) {
          clearedTotal += amount;
        } else if (cr === CrStatus.RECONCILED) {
          reconciledTotal += amount;
          clearedTotal += amount;
        }
      }
    } finally {
      result.close();
    }
    account.currentBalance = currentBalance;
    account.sumIncome = sumIncome;
    account.sumExpense = sumExpense;
    account.sumTransfer = sumTransfer;
    account.clearedTotal = clearedTotal;
    account.reconciledTotal = reconciledTotal;
    account.hasCleared = clearedTotal !== 0 || reconciledTotal !== 0;
  }

  // ==================== 交易 ====================

  async getTransactions(accountId: number): Promise<Transaction[]> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('account_id', accountId);
    predicates.orderByDesc('date');
    const result = await this.store().query(predicates);
    const list: Transaction[] = [];
    try {
      while (result.goToNextRow()) {
        list.push(this.rowToTransaction(result));
      }
    } finally {
      result.close();
    }
    // 填充展示字段
    for (let t of list) {
      await this.fillTransactionDisplay(t);
    }
    return list;
  }

  /**
   * 复杂搜索交易（对齐安卓 SearchRequest：按条件过滤交易）
   * criteria: type=amount/comment/status/date/account
   */
  async searchTransactions(criteria: Array<SearchCriterion>): Promise<Transaction[]> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    const all = await this.store().query(predicates);
    const list: Transaction[] = [];
    try {
      while (all.goToNextRow()) {
        list.push(this.rowToTransaction(all));
      }
    } finally {
      all.close();
    }
    for (let t of list) {
      await this.fillTransactionDisplay(t);
    }
    // 应用搜索条件
    return list.filter((t: Transaction) => {
      for (const c of criteria) {
        if (c.type === 'amount') {
          const v = parseFloat(c.value) || 0;
          const amt = t.amount / 100;
          if (c.extra === '收入' && amt < 0) {
            return false;
          }
          if (c.extra === '支出' && amt > 0) {
            return false;
          }
          if (c.op === '大于' && Math.abs(amt) <= v) {
            return false;
          }
          if (c.op === '小于' && Math.abs(amt) >= v) {
            return false;
          }
          if (c.op === '等于' && Math.abs(Math.abs(amt) - v) > 0.005) {
            return false;
          }
        } else if (c.type === 'comment') {
          if (c.value.length > 0 && !(t.comment || '').includes(c.value)) {
            return false;
          }
        } else if (c.type === 'status') {
          // 状态：c.value=未结算/已结算，映射 cr_status
          const statusVal = c.value === '已结算' ? 'RECONCILED' : c.value === '未结算' ? 'UNRECONCILED' : '';
          if (statusVal.length > 0 && t.crStatus !== statusVal) {
            return false;
          }
        } else if (c.type === 'date') {
          // 日期范围（简化）：今天/本周/本月/今年
          const now = new Date();
          const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() / 1000;
          let start = startOfDay;
          if (c.value === '本周') {
            const day = now.getDay() || 7;
            start = startOfDay - (day - 1) * 86400;
          } else if (c.value === '本月') {
            start = new Date(now.getFullYear(), now.getMonth(), 1).getTime() / 1000;
          } else if (c.value === '今年') {
            start = new Date(now.getFullYear(), 0, 1).getTime() / 1000;
          }
          if (t.date < start) {
            return false;
          }
        } else if (c.type === 'account') {
          // 账户：通过 label 匹配（c.value 为账户名）
          if (c.value.length > 0 && t.accountLabel !== c.value) {
            return false;
          }
        }
      }
      return true;
    });
  }

  async getTransaction(id: number): Promise<Transaction | null> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('id', id);
    const result = await this.store().query(predicates);
    let t: Transaction | null = null;
    try {
      if (result.goToNextRow()) {
        t = this.rowToTransaction(result);
      }
    } finally {
      result.close();
    }
    if (t) {
      await this.fillTransactionDisplay(t);
    }
    return t;
  }

  async insertTransaction(t: Transaction): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'comment': t.comment,
      'date': t.date,
      'value_date': t.valueDate,
      'amount': t.amount,
      'cat_id': t.categoryId >= 0 ? t.categoryId : null,
      'account_id': t.accountId,
      'payee_id': t.payeeId >= 0 ? t.payeeId : null,
      'transfer_peer': t.transferPeerId >= 0 ? t.transferPeerId : null,
      'transfer_account': t.transferAccountId >= 0 ? t.transferAccountId : null,
      'method_id': t.methodId >= 0 ? t.methodId : null,
      'parent_id': t.parentId >= 0 ? t.parentId : null,
      'status': t.status,
      'cr_status': t.crStatus,
      'number': t.referenceNumber,
      'uuid': t.uuid,
      'original_amount': t.originalAmount !== 0 ? t.originalAmount : null,
      'original_currency': t.originalCurrency,
      'debt_id': t.debtId >= 0 ? t.debtId : null
    };
    const id = await this.store().insert('transactions', values);
    // 标签
    if (t.tagIds.length > 0) {
      for (let tagId of t.tagIds) {
        const tagValues: relationalStore.ValuesBucket = {
          'tag_id': tagId,
          'transaction_id': id
        };
        await this.store().insert('transactions_tags', tagValues);
      }
    }
    return id;
  }

  async updateTransaction(t: Transaction): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'comment': t.comment,
      'date': t.date,
      'value_date': t.valueDate,
      'amount': t.amount,
      'cat_id': t.categoryId >= 0 ? t.categoryId : null,
      'payee_id': t.payeeId >= 0 ? t.payeeId : null,
      'transfer_account': t.transferAccountId >= 0 ? t.transferAccountId : null,
      'method_id': t.methodId >= 0 ? t.methodId : null,
      'cr_status': t.crStatus,
      'number': t.referenceNumber
    };
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('id', t.id);
    return this.store().update(values, predicates);
  }

  /**
   * 保存交易附件（先删后插）
   */
  async setTransactionAttachments(transactionId: number, uris: string[]): Promise<void> {
    const delPred = new relationalStore.RdbPredicates('attachments');
    delPred.equalTo('transaction_id', transactionId);
    await this.store().delete(delPred);
    for (let uri of uris) {
      const values: relationalStore.ValuesBucket = {
        'transaction_id': transactionId,
        'uri': uri
      };
      await this.store().insert('attachments', values);
    }
  }

  /**
   * 获取交易附件 uri 列表
   */
  async getTransactionAttachments(transactionId: number): Promise<string[]> {
    const predicates = new relationalStore.RdbPredicates('attachments');
    predicates.equalTo('transaction_id', transactionId);
    const result = await this.store().query(predicates);
    const uris: string[] = [];
    try {
      while (result.goToNextRow()) {
        uris.push(result.getString(result.getColumnIndex('uri')));
      }
    } finally {
      result.close();
    }
    return uris;
  }

  async deleteTransaction(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  async deleteTransactionsByIds(ids: number[]): Promise<number> {
    let count = 0;
    for (let id of ids) {
      count += await this.deleteTransaction(id);
    }
    return count;
  }

  /**
   * 保存拆分交易：父交易（amount=0, cat_id=SPLIT）+ 子交易集合
   * @param parentId 父交易 id；<=0 表示新建父交易
   * @returns 父交易 id
   */
  async saveSplitTransaction(parent: Transaction, parts: Transaction[]): Promise<number> {
    parent.categoryId = SPLIT_CATID;
    parent.amount = 0;
    let savedParentId = parent.id;
    if (parent.id > 0) {
      await this.updateTransaction(parent);
    } else {
      parent.uuid = generateUuid();
      savedParentId = await this.insertTransaction(parent);
    }
    // 先删旧子交易
    const delPred = new relationalStore.RdbPredicates('transactions');
    delPred.equalTo('parent_id', savedParentId);
    await this.store().delete(delPred);
    // 插入子交易
    for (let part of parts) {
      part.parentId = savedParentId;
      part.accountId = parent.accountId;
      part.date = parent.date;
      part.valueDate = parent.valueDate;
      part.uuid = generateUuid();
      await this.insertTransaction(part);
    }
    return savedParentId;
  }

  /**
   * 获取拆分交易的子交易列表
   */
  async getSplitParts(parentId: number): Promise<Transaction[]> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('parent_id', parentId);
    const result = await this.store().query(predicates);
    const list: Transaction[] = [];
    try {
      while (result.goToNextRow()) {
        list.push(this.rowToTransaction(result));
      }
    } finally {
      result.close();
    }
    for (let t of list) {
      await this.fillTransactionDisplay(t);
    }
    return list;
  }

  /**
   * 删除拆分父交易及其子交易
   */
  async deleteSplitTransaction(parentId: number): Promise<number> {
    const delPred = new relationalStore.RdbPredicates('transactions');
    delPred.equalTo('parent_id', parentId);
    await this.store().delete(delPred);
    return this.deleteTransaction(parentId);
  }

  async setTransactionCrStatus(id: number, cr: CrStatus): Promise<number> {
    const values: relationalStore.ValuesBucket = { 'cr_status': cr };
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.equalTo('id', id);
    return this.store().update(values, predicates);
  }

  private rowToTransaction(result: relationalStore.ResultSet): Transaction {
    const t = new Transaction();
    t.id = result.getLong(result.getColumnIndex('id'));
    t.comment = result.getString(result.getColumnIndex('comment'));
    t.date = result.getLong(result.getColumnIndex('date'));
    t.valueDate = result.getLong(result.getColumnIndex('value_date'));
    t.amount = result.getLong(result.getColumnIndex('amount'));
    const catIdx = result.getColumnIndex('cat_id');
    t.categoryId = result.isColumnNull(catIdx) ? -1 : result.getLong(catIdx);
    t.accountId = result.getLong(result.getColumnIndex('account_id'));
    const payeeIdx = result.getColumnIndex('payee_id');
    t.payeeId = result.isColumnNull(payeeIdx) ? -1 : result.getLong(payeeIdx);
    const transferPeerIdx = result.getColumnIndex('transfer_peer');
    t.transferPeerId = result.isColumnNull(transferPeerIdx) ? -1 : result.getLong(transferPeerIdx);
    const transferAccountIdx = result.getColumnIndex('transfer_account');
    t.transferAccountId = result.isColumnNull(transferAccountIdx) ? -1 : result.getLong(transferAccountIdx);
    const methodIdx = result.getColumnIndex('method_id');
    t.methodId = result.isColumnNull(methodIdx) ? -1 : result.getLong(methodIdx);
    const parentIdx = result.getColumnIndex('parent_id');
    t.parentId = result.isColumnNull(parentIdx) ? -1 : result.getLong(parentIdx);
    t.status = result.getLong(result.getColumnIndex('status'));
    t.crStatus = result.getString(result.getColumnIndex('cr_status')) as CrStatus;
    t.referenceNumber = result.getString(result.getColumnIndex('number'));
    t.uuid = result.getString(result.getColumnIndex('uuid'));
    const origIdx = result.getColumnIndex('original_amount');
    t.originalAmount = result.isColumnNull(origIdx) ? 0 : result.getLong(origIdx);
    t.originalCurrency = result.getString(result.getColumnIndex('original_currency'));
    const debtIdx = result.getColumnIndex('debt_id');
    t.debtId = result.isColumnNull(debtIdx) ? -1 : result.getLong(debtIdx);
    return t;
  }

  private async fillTransactionDisplay(t: Transaction): Promise<void> {
    // 分类路径
    if (t.categoryId >= 0) {
      const cat = await this.getCategory(t.categoryId);
      if (cat) {
        t.categoryPath = cat.label;
        t.categoryIcon = cat.icon;
        t.color = cat.color;
      }
    }
    // 收款人
    if (t.payeeId >= 0) {
      const payee = await this.getPayee(t.payeeId);
      if (payee) {
        t.payeeName = payee.name;
      }
    }
    // 付款方法
    if (t.methodId >= 0) {
      const method = await this.getPaymentMethod(t.methodId);
      if (method) {
        t.methodLabel = method.label;
      }
    }
    // 账户
    if (t.accountId >= 0) {
      const acc = await this.getAccount(t.accountId);
      if (acc) {
        t.accountLabel = acc.label;
        t.currency = acc.currency;
      }
    }
    // 转账目标账户
    if (t.transferAccountId >= 0) {
      const acc = await this.getAccount(t.transferAccountId);
      if (acc) {
        t.transferAccountLabel = acc.label;
      }
    }
    // 时间分组
    const d = new Date(t.date * 1000);
    t.year = d.getFullYear();
    t.month = d.getMonth();
    t.week = Math.ceil((d.getDate() + (new Date(t.year, t.month, 1).getDay())) / 7);
    t.day = d.getDate();
  }

  // ==================== 分类 ====================

  async getCategories(): Promise<Category[]> {
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.orderByAsc('sort_order');
    predicates.orderByAsc('label');
    const result = await this.store().query(predicates);
    const list: Category[] = [];
    try {
      while (result.goToNextRow()) {
        list.push(this.rowToCategory(result));
      }
    } finally {
      result.close();
    }
    return list;
  }

  async getCategory(id: number): Promise<Category | null> {
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    const result = await this.store().query(predicates);
    let cat: Category | null = null;
    try {
      if (result.goToNextRow()) {
        cat = this.rowToCategory(result);
      }
    } finally {
      result.close();
    }
    return cat;
  }

  /**
   * 批量更新分类排序（拖拽排序持久化）
   */
  async updateCategoryOrders(ids: number[]): Promise<void> {
    for (let i = 0; i < ids.length; i++) {
      const values: relationalStore.ValuesBucket = { 'sort_order': i };
      const predicates = new relationalStore.RdbPredicates('categories');
      predicates.equalTo('id', ids[i]);
      await this.store().update(values, predicates);
    }
  }

  async insertCategory(cat: Category): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': cat.label,
      'label_normalized': cat.labelNormalized || cat.label,
      'parent_id': cat.parentId,
      'usages': cat.usages,
      'last_used': cat.lastUsed,
      'color': cat.color,
      'icon': cat.icon,
      'uuid': cat.uuid,
      'type': cat.type
    };
    return this.store().insert('categories', values);
  }

  async updateCategory(cat: Category): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': cat.label,
      'label_normalized': cat.labelNormalized || cat.label,
      'color': cat.color,
      'icon': cat.icon,
      'type': cat.type
    };
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', cat.id);
    return this.store().update(values, predicates);
  }

  async deleteCategory(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  private rowToCategory(result: relationalStore.ResultSet): Category {
    const cat = new Category();
    cat.id = result.getLong(result.getColumnIndex('id'));
    cat.label = result.getString(result.getColumnIndex('label'));
    cat.labelNormalized = result.getString(result.getColumnIndex('label_normalized'));
    cat.parentId = result.getLong(result.getColumnIndex('parent_id'));
    cat.usages = result.getLong(result.getColumnIndex('usages'));
    cat.lastUsed = result.getLong(result.getColumnIndex('last_used'));
    cat.color = result.getLong(result.getColumnIndex('color'));
    cat.icon = result.getString(result.getColumnIndex('icon'));
    cat.uuid = result.getString(result.getColumnIndex('uuid'));
    cat.type = result.getLong(result.getColumnIndex('type'));
    return cat;
  }

  // ==================== 付款方法 ====================

  async getPaymentMethods(): Promise<PaymentMethod[]> {
    const predicates = new relationalStore.RdbPredicates('paymentmethods');
    predicates.orderByAsc('id');
    const result = await this.store().query(predicates);
    const list: PaymentMethod[] = [];
    try {
      while (result.goToNextRow()) {
        const m = new PaymentMethod();
        m.id = result.getLong(result.getColumnIndex('id'));
        m.label = result.getString(result.getColumnIndex('label'));
        m.isNumbered = result.getLong(result.getColumnIndex('is_numbered')) === 1;
        m.type = result.getLong(result.getColumnIndex('type'));
        m.icon = result.getString(result.getColumnIndex('icon'));
        list.push(m);
      }
    } finally {
      result.close();
    }
    return list;
  }

  async getPaymentMethod(id: number): Promise<PaymentMethod | null> {
    const predicates = new relationalStore.RdbPredicates('paymentmethods');
    predicates.equalTo('id', id);
    const result = await this.store().query(predicates);
    let m: PaymentMethod | null = null;
    try {
      if (result.goToNextRow()) {
        m = new PaymentMethod();
        m.id = result.getLong(result.getColumnIndex('id'));
        m.label = result.getString(result.getColumnIndex('label'));
        m.isNumbered = result.getLong(result.getColumnIndex('is_numbered')) === 1;
        m.type = result.getLong(result.getColumnIndex('type'));
        m.icon = result.getString(result.getColumnIndex('icon'));
      }
    } finally {
      result.close();
    }
    return m;
  }

  async insertPaymentMethod(m: PaymentMethod): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': m.label,
      'is_numbered': m.isNumbered ? 1 : 0,
      'type': m.type,
      'icon': m.icon
    };
    return this.store().insert('paymentmethods', values);
  }

  async updatePaymentMethod(m: PaymentMethod): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': m.label,
      'is_numbered': m.isNumbered ? 1 : 0,
      'type': m.type,
      'icon': m.icon
    };
    const predicates = new relationalStore.RdbPredicates('paymentmethods');
    predicates.equalTo('id', m.id);
    return this.store().update(values, predicates);
  }

  async deletePaymentMethod(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('paymentmethods');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  // ==================== 收款人 ====================

  async getPayees(): Promise<Payee[]> {
    const predicates = new relationalStore.RdbPredicates('payee');
    predicates.orderByAsc('name');
    const result = await this.store().query(predicates);
    const list: Payee[] = [];
    try {
      while (result.goToNextRow()) {
        const p = new Payee();
        p.id = result.getLong(result.getColumnIndex('id'));
        p.name = result.getString(result.getColumnIndex('name'));
        p.shortName = result.getString(result.getColumnIndex('short_name'));
        p.nameNormalized = result.getString(result.getColumnIndex('name_normalized'));
        p.iban = result.getString(result.getColumnIndex('iban'));
        p.bic = result.getString(result.getColumnIndex('bic'));
        list.push(p);
      }
    } finally {
      result.close();
    }
    return list;
  }

  async getPayee(id: number): Promise<Payee | null> {
    const predicates = new relationalStore.RdbPredicates('payee');
    predicates.equalTo('id', id);
    const result = await this.store().query(predicates);
    let p: Payee | null = null;
    try {
      if (result.goToNextRow()) {
        p = new Payee();
        p.id = result.getLong(result.getColumnIndex('id'));
        p.name = result.getString(result.getColumnIndex('name'));
        p.shortName = result.getString(result.getColumnIndex('short_name'));
        p.nameNormalized = result.getString(result.getColumnIndex('name_normalized'));
        p.iban = result.getString(result.getColumnIndex('iban'));
        p.bic = result.getString(result.getColumnIndex('bic'));
      }
    } finally {
      result.close();
    }
    return p;
  }

  async findOrCreatePayee(name: string): Promise<number> {
    const trimmed = name.trim();
    if (!trimmed) {
      return -1;
    }
    const predicates = new relationalStore.RdbPredicates('payee');
    predicates.equalTo('name', trimmed);
    const result = await this.store().query(predicates);
    try {
      if (result.goToNextRow()) {
        return result.getLong(result.getColumnIndex('id'));
      }
    } finally {
      result.close();
    }
    const values: relationalStore.ValuesBucket = {
      'name': trimmed,
      'name_normalized': trimmed
    };
    return this.store().insert('payee', values);
  }

  // ==================== 标签 ====================

  /**
   * 获取账户关联标签 id
   */
  async getAccountTagIds(accountId: number): Promise<number[]> {
    const predicates = new relationalStore.RdbPredicates('accounts_tags');
    predicates.equalTo('account_id', accountId);
    const result = await this.store().query(predicates);
    const ids: number[] = [];
    try {
      while (result.goToNextRow()) {
        ids.push(result.getLong(result.getColumnIndex('tag_id')));
      }
    } finally {
      result.close();
    }
    return ids;
  }

  /**
   * 设置账户关联标签（先删后插）
   */
  async setAccountTagIds(accountId: number, tagIds: number[]): Promise<void> {
    const delPred = new relationalStore.RdbPredicates('accounts_tags');
    delPred.equalTo('account_id', accountId);
    await this.store().delete(delPred);
    for (let tagId of tagIds) {
      const values: relationalStore.ValuesBucket = {
        'tag_id': tagId,
        'account_id': accountId
      };
      await this.store().insert('accounts_tags', values);
    }
  }

  async getTags(): Promise<Tag[]> {
    const predicates = new relationalStore.RdbPredicates('tags');
    predicates.orderByAsc('label');
    const result = await this.store().query(predicates);
    const list: Tag[] = [];
    try {
      while (result.goToNextRow()) {
        const tag = new Tag();
        tag.id = result.getLong(result.getColumnIndex('id'));
        tag.label = result.getString(result.getColumnIndex('label'));
        tag.color = result.getLong(result.getColumnIndex('color'));
        list.push(tag);
      }
    } finally {
      result.close();
    }
    return list;
  }

  async insertTag(label: string, color: number): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': label,
      'color': color
    };
    return this.store().insert('tags', values);
  }

  async updateTag(tag: Tag): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'label': tag.label,
      'color': tag.color
    };
    const predicates = new relationalStore.RdbPredicates('tags');
    predicates.equalTo('id', tag.id);
    return this.store().update(values, predicates);
  }

  async deleteTag(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('tags');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  // ==================== 预算 ====================

  async getBudgets(): Promise<Budget[]> {
    const predicates = new relationalStore.RdbPredicates('budgets');
    predicates.orderByDesc('id');
    const result = await this.store().query(predicates);
    const list: Budget[] = [];
    try {
      while (result.goToNextRow()) {
        const b = new Budget();
        b.id = result.getLong(result.getColumnIndex('id'));
        b.title = result.getString(result.getColumnIndex('title'));
        b.description = result.getString(result.getColumnIndex('description'));
        const accIdx = result.getColumnIndex('account_id');
        b.accountId = result.isColumnNull(accIdx) ? -1 : result.getLong(accIdx);
        b.currency = result.getString(result.getColumnIndex('currency'));
        b.start = result.getLong(result.getColumnIndex('start'));
        b.end = result.getLong(result.getColumnIndex('end'));
        b.isDefault = result.getLong(result.getColumnIndex('is_default')) === 1;
        b.uuid = result.getString(result.getColumnIndex('uuid'));
        list.push(b);
      }
    } finally {
      result.close();
    }
    // 汇总已分配金额
    for (let b of list) {
      const allocPred = new relationalStore.RdbPredicates('budget_allocations');
      allocPred.equalTo('budget_id', b.id);
      const allocResult = await this.store().query(allocPred);
      try {
        while (allocResult.goToNextRow()) {
          b.budgetAmount += allocResult.getLong(allocResult.getColumnIndex('budget'));
        }
      } finally {
        allocResult.close();
      }
    }
    return list;
  }

  async insertBudget(budget: Budget): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'title': budget.title,
      'description': budget.description,
      'account_id': budget.accountId >= 0 ? budget.accountId : null,
      'currency': budget.currency,
      'start': budget.start > 0 ? budget.start : null,
      'end': budget.end > 0 ? budget.end : null,
      'is_default': budget.isDefault ? 1 : 0,
      'uuid': generateUuid()
    };
    return this.store().insert('budgets', values);
  }

  async deleteBudget(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('budgets');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  // ==================== 债务 ====================

  async getDebts(): Promise<Debt[]> {
    const predicates = new relationalStore.RdbPredicates('debts');
    predicates.orderByDesc('date');
    const result = await this.store().query(predicates);
    const list: Debt[] = [];
    try {
      while (result.goToNextRow()) {
        const d = new Debt();
        d.id = result.getLong(result.getColumnIndex('id'));
        d.payeeId = result.getLong(result.getColumnIndex('payee_id'));
        d.date = result.getLong(result.getColumnIndex('date'));
        d.label = result.getString(result.getColumnIndex('label'));
        d.amount = result.getLong(result.getColumnIndex('amount'));
        d.currency = result.getString(result.getColumnIndex('currency'));
        d.description = result.getString(result.getColumnIndex('description'));
        d.sealed = result.getLong(result.getColumnIndex('sealed')) === 1;
        list.push(d);
      }
    } finally {
      result.close();
    }
    return list;
  }

  async insertDebt(debt: Debt): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'payee_id': debt.payeeId >= 0 ? debt.payeeId : null,
      'date': debt.date > 0 ? debt.date : null,
      'label': debt.label,
      'amount': debt.amount,
      'currency': debt.currency,
      'description': debt.description,
      'sealed': debt.sealed ? 1 : 0
    };
    return this.store().insert('debts', values);
  }

  async deleteDebt(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('debts');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  // ==================== 汇总统计（AI / 分布） ====================

  async getMonthlySummary(months: number): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    const now = new Date();
    const allTransactions = await this.getAllTransactions();
    for (let i = months - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const key = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}`;
      result.set(key, 0);
    }
    for (let t of allTransactions) {
      if (t.isTransfer()) {
        continue;
      }
      const d = new Date(t.date * 1000);
      const key = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}`;
      if (result.has(key)) {
        result.set(key, result.get(key)! + t.amount);
      }
    }
    return result;
  }

  async getCategorySummary(): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    const allTransactions = await this.getAllTransactions();
    for (let t of allTransactions) {
      if (t.isTransfer() || t.amount >= 0) {
        continue;
      }
      const catPath = t.categoryPath || '未分类';
      const existing = result.get(catPath) || 0;
      result.set(catPath, existing + t.amount);
    }
    return result;
  }

  async getAllTransactions(): Promise<Transaction[]> {
    const predicates = new relationalStore.RdbPredicates('transactions');
    predicates.orderByDesc('date');
    const result = await this.store().query(predicates);
    const list: Transaction[] = [];
    try {
      while (result.goToNextRow()) {
        list.push(this.rowToTransaction(result));
      }
    } finally {
      result.close();
    }
    for (let t of list) {
      await this.fillTransactionDisplay(t);
    }
    return list;
  }

  // ==================== 模板 ====================

  /**
   * 读取单个模板（模板编辑页使用，填充展示字段）
   */
  async getTemplate(id: number): Promise<Template | null> {
    const predicates = new relationalStore.RdbPredicates('templates');
    predicates.equalTo('id', id);
    const result = await this.store().query(predicates);
    try {
      if (result.goToNextRow()) {
        const tpl = new Template();
        tpl.id = result.getLong(result.getColumnIndex('id'));
        tpl.title = result.getString(result.getColumnIndex('title'));
        tpl.comment = result.getString(result.getColumnIndex('comment'));
        tpl.amount = result.getLong(result.getColumnIndex('amount'));
        tpl.accountId = result.getLong(result.getColumnIndex('account_id'));
        const catIdx = result.getColumnIndex('cat_id');
        tpl.categoryId = result.isColumnNull(catIdx) ? -1 : result.getLong(catIdx);
        const payeeIdx = result.getColumnIndex('payee_id');
        tpl.payeeId = result.isColumnNull(payeeIdx) ? -1 : result.getLong(payeeIdx);
        const methodIdx = result.getColumnIndex('method_id');
        tpl.methodId = result.isColumnNull(methodIdx) ? -1 : result.getLong(methodIdx);
        const transferIdx = result.getColumnIndex('transfer_account');
        tpl.transferAccountId = result.isColumnNull(transferIdx) ? -1 : result.getLong(transferIdx);
        tpl.parentId = result.getLong(result.getColumnIndex('parent_id'));
        tpl.uuid = result.getString(result.getColumnIndex('uuid'));
        tpl.isIncome = result.getLong(result.getColumnIndex('is_income')) === 1;
        const recIdx = result.getColumnIndex('recurrence');
        tpl.recurrence = result.isColumnNull(recIdx) ? 0 : result.getLong(recIdx);
        const dtIdx = result.getColumnIndex('dt_start');
        tpl.dtStart = result.isColumnNull(dtIdx) ? 0 : result.getLong(dtIdx);
        const lastIdx = result.getColumnIndex('last_executed');
        tpl.lastExecuted = result.isColumnNull(lastIdx) ? 0 : result.getLong(lastIdx);
        const autoIdx = result.getColumnIndex('auto_execute');
        tpl.autoExecute = !result.isColumnNull(autoIdx) && result.getLong(autoIdx) === 1;
        const advIdx = result.getColumnIndex('advance_days');
        tpl.advanceDays = result.isColumnNull(advIdx) ? 0 : result.getLong(advIdx);
        // 填充展示字段
        const acc = await this.getAccount(tpl.accountId);
        if (acc) {
          tpl.currency = acc.currency;
          tpl.accountLabel = acc.label;
          tpl.accountColor = acc.color;
        }
        if (tpl.transferAccountId >= 0) {
          const tAcc = await this.getAccount(tpl.transferAccountId);
          if (tAcc) {
            tpl.transferAccountLabel = tAcc.label;
          }
        }
        if (tpl.categoryId >= 0) {
          const cat = await this.getCategory(tpl.categoryId);
          if (cat) {
            tpl.categoryPath = cat.label;
          }
        }
        if (tpl.payeeId >= 0) {
          const payee = await this.getPayee(tpl.payeeId);
          if (payee) {
            tpl.payeeName = payee.name;
          }
        }
        if (tpl.methodId >= 0) {
          const method = await this.getPaymentMethod(tpl.methodId);
          if (method) {
            tpl.methodLabel = method.label;
          }
        }
        return tpl;
      }
      return null;
    } finally {
      result.close();
    }
  }

  async getTemplates(): Promise<Template[]> {
    const predicates = new relationalStore.RdbPredicates('templates');
    predicates.orderByDesc('id');
    const result = await this.store().query(predicates);
    const list: Template[] = [];
    try {
      while (result.goToNextRow()) {
        const tpl = new Template();
        tpl.id = result.getLong(result.getColumnIndex('id'));
        tpl.title = result.getString(result.getColumnIndex('title'));
        tpl.comment = result.getString(result.getColumnIndex('comment'));
        tpl.amount = result.getLong(result.getColumnIndex('amount'));
        tpl.accountId = result.getLong(result.getColumnIndex('account_id'));
        const catIdx = result.getColumnIndex('cat_id');
        tpl.categoryId = result.isColumnNull(catIdx) ? -1 : result.getLong(catIdx);
        const payeeIdx = result.getColumnIndex('payee_id');
        tpl.payeeId = result.isColumnNull(payeeIdx) ? -1 : result.getLong(payeeIdx);
        const methodIdx = result.getColumnIndex('method_id');
        tpl.methodId = result.isColumnNull(methodIdx) ? -1 : result.getLong(methodIdx);
        const transferIdx = result.getColumnIndex('transfer_account');
        tpl.transferAccountId = result.isColumnNull(transferIdx) ? -1 : result.getLong(transferIdx);
        tpl.parentId = result.getLong(result.getColumnIndex('parent_id'));
        tpl.uuid = result.getString(result.getColumnIndex('uuid'));
        tpl.isIncome = result.getLong(result.getColumnIndex('is_income')) === 1;
        const recIdx = result.getColumnIndex('recurrence');
        tpl.recurrence = result.isColumnNull(recIdx) ? 0 : result.getLong(recIdx);
        const dtIdx = result.getColumnIndex('dt_start');
        tpl.dtStart = result.isColumnNull(dtIdx) ? 0 : result.getLong(dtIdx);
        const lastIdx = result.getColumnIndex('last_executed');
        tpl.lastExecuted = result.isColumnNull(lastIdx) ? 0 : result.getLong(lastIdx);
        const autoIdx = result.getColumnIndex('auto_execute');
        tpl.autoExecute = !result.isColumnNull(autoIdx) && result.getLong(autoIdx) === 1;
        const advIdx = result.getColumnIndex('advance_days');
        tpl.advanceDays = result.isColumnNull(advIdx) ? 0 : result.getLong(advIdx);
        list.push(tpl);
      }
    } finally {
      result.close();
    }
    // 填充展示字段
    for (let tpl of list) {
      if (tpl.categoryId >= 0) {
        const cat = await this.getCategory(tpl.categoryId);
        if (cat) {
          tpl.categoryPath = cat.label;
        }
      }
      if (tpl.payeeId >= 0) {
        const payee = await this.getPayee(tpl.payeeId);
        if (payee) {
          tpl.payeeName = payee.name;
        }
      }
      if (tpl.methodId >= 0) {
        const method = await this.getPaymentMethod(tpl.methodId);
        if (method) {
          tpl.methodLabel = method.label;
        }
      }
      const acc = await this.getAccount(tpl.accountId);
      if (acc) {
        tpl.currency = acc.currency;
        tpl.accountLabel = acc.label;
        tpl.accountColor = acc.color;
      }
      if (tpl.transferAccountId >= 0) {
        const tAcc = await this.getAccount(tpl.transferAccountId);
        if (tAcc) {
          tpl.transferAccountLabel = tAcc.label;
        }
      }
    }
    return list;
  }

  async insertTemplate(tpl: Template): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'title': tpl.title,
      'comment': tpl.comment,
      'amount': tpl.amount,
      'account_id': tpl.accountId,
      'cat_id': tpl.categoryId >= 0 ? tpl.categoryId : null,
      'payee_id': tpl.payeeId >= 0 ? tpl.payeeId : null,
      'method_id': tpl.methodId >= 0 ? tpl.methodId : null,
      'transfer_account': tpl.transferAccountId >= 0 ? tpl.transferAccountId : null,
      'parent_id': tpl.parentId >= 0 ? tpl.parentId : null,
      'uuid': generateUuid(),
      'is_income': tpl.isIncome ? 1 : 0,
      'recurrence': tpl.recurrence,
      'dt_start': tpl.dtStart > 0 ? tpl.dtStart : null,
      'last_executed': tpl.lastExecuted > 0 ? tpl.lastExecuted : null,
      'auto_execute': tpl.autoExecute ? 1 : 0,
      'advance_days': tpl.advanceDays
    };
    return this.store().insert('templates', values);
  }

  /**
   * 更新模板（含周期字段）
   */
  async updateTemplate(tpl: Template): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'title': tpl.title,
      'comment': tpl.comment,
      'amount': tpl.amount,
      'cat_id': tpl.categoryId >= 0 ? tpl.categoryId : null,
      'payee_id': tpl.payeeId >= 0 ? tpl.payeeId : null,
      'method_id': tpl.methodId >= 0 ? tpl.methodId : null,
      'transfer_account': tpl.transferAccountId >= 0 ? tpl.transferAccountId : null,
      'recurrence': tpl.recurrence,
      'dt_start': tpl.dtStart > 0 ? tpl.dtStart : null,
      'last_executed': tpl.lastExecuted > 0 ? tpl.lastExecuted : null,
      'auto_execute': tpl.autoExecute ? 1 : 0,
      'advance_days': tpl.advanceDays
    };
    const predicates = new relationalStore.RdbPredicates('templates');
    predicates.equalTo('id', tpl.id);
    return this.store().update(values, predicates);
  }

  /**
   * 按周期生成交易（计划固定收支）
   * 计算下一次应发生的日期并创建交易，更新 last_executed
   * @returns 生成的交易 id；无到期返回 0
   */
  async generatePlanTransaction(tpl: Template): Promise<number> {
    if (tpl.recurrence <= 0) {
      return 0;
    }
    const now = Math.floor(Date.now() / 1000);
    const due = this.nextDue(tpl, now);
    if (due <= 0 || due > now + 90 * 86400) {
      return 0; // 未来超过 90 天不生成
    }
    // 自动执行：允许提前 advanceDays 天生成
    if (tpl.autoExecute) {
      const advance = Math.min(tpl.advanceDays, 30) * 86400;
      if (due > now + advance) {
        return 0; // 未到提前窗口
      }
    }
    const t = new Transaction();
    t.accountId = tpl.accountId;
    t.amount = tpl.isIncome ? Math.abs(tpl.amount) : -Math.abs(tpl.amount);
    t.comment = tpl.comment;
    t.categoryId = tpl.categoryId;
    t.payeeId = tpl.payeeId;
    t.methodId = tpl.methodId;
    t.transferAccountId = tpl.transferAccountId;
    t.date = due;
    t.valueDate = due;
    t.uuid = generateUuid();
    t.crStatus = CrStatus.UNRECONCILED;
    const txId = await this.insertTransaction(t);
    // 更新 last_executed
    tpl.lastExecuted = due;
    await this.updateTemplate(tpl);
    return txId;
  }

  /**
   * 计算模板下一次应发生的时间
   */
  private nextDue(tpl: Template, now: number): number {
    const start = tpl.dtStart > 0 ? tpl.dtStart : now;
    const after = tpl.lastExecuted > 0 ? tpl.lastExecuted : start - 1;
    const startDate = new Date(start * 1000);
    const afterDate = new Date(after * 1000);
    let cursor = new Date(afterDate.getFullYear(), afterDate.getMonth(), afterDate.getDate() + 1, 12, 0, 0);
    const dayOfWeekStart = startDate.getDay();
    const dayOfMonthStart = startDate.getDate();
    const recur = tpl.recurrence;
    if (recur === 1) { // ONETIME
      return start > now ? start : 0;
    }
    let count = 0;
    while (count < 400) {
      if (recur === 2) { // DAILY
        // 每天
      } else if (recur === 3) { // WEEKLY
        if (cursor.getDay() !== dayOfWeekStart) {
          cursor.setDate(cursor.getDate() + 1);
          count++;
          continue;
        }
      } else if (recur === 4) { // MONTHLY
        if (cursor.getDate() !== dayOfMonthStart) {
          cursor.setDate(cursor.getDate() + 1);
          count++;
          continue;
        }
      } else if (recur === 5) { // LAST_DAY_OF_MONTH
        const nextMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0);
        if (cursor.getDate() !== nextMonth.getDate()) {
          cursor.setDate(cursor.getDate() + 1);
          count++;
          continue;
        }
      } else if (recur === 6) { // YEARLY
        if (cursor.getMonth() !== startDate.getMonth() || cursor.getDate() !== dayOfMonthStart) {
          cursor.setDate(cursor.getDate() + 1);
          count++;
          continue;
        }
      }
      break;
    }
    const due = Math.floor(cursor.getTime() / 1000);
    return due > now ? due : 0;
  }

  async deleteTemplate(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('templates');
    predicates.equalTo('id', id);
    return this.store().delete(predicates);
  }

  /**
   * 从模板实例化为交易（重复交易）
   */
  async instantiateTemplate(tpl: Template): Promise<number> {
    const t = new Transaction();
    t.accountId = tpl.accountId;
    t.amount = tpl.isIncome ? Math.abs(tpl.amount) : -Math.abs(tpl.amount);
    t.comment = tpl.comment;
    t.categoryId = tpl.categoryId;
    t.payeeId = tpl.payeeId;
    t.methodId = tpl.methodId;
    t.transferAccountId = tpl.transferAccountId;
    t.date = Math.floor(Date.now() / 1000);
    t.valueDate = t.date;
    t.uuid = generateUuid();
    t.crStatus = CrStatus.UNRECONCILED;
    return this.insertTransaction(t);
  }
}