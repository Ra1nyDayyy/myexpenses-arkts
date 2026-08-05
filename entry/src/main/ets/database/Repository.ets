import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { Account, AccountType, AccountGrouping, SortDirection } from '../model/Account';
import { Transaction, CrStatus } from '../model/Transaction';
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag, Budget, Debt } from '../model/SupportEntities';
import { currencyByCode } from '../model/CurrencyUnit';

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
      'last_used': account.lastUsed
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
      'dynamic': account.dynamic ? 1 : 0
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
}