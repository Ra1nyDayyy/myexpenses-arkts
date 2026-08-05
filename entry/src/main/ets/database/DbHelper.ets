import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/**
 * 数据库表结构：与 Android TransactionDatabase 同构
 */
export const DB_NAME = 'myexpenses.db';
export const DB_VERSION = 1;

/**
 * 建表语句（relationalStore 使用 SQL）
 */
export const CREATE_TABLES: string[] = [
  `CREATE TABLE IF NOT EXISTS accounts (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     label TEXT NOT NULL,
     description TEXT,
     opening_balance INTEGER NOT NULL DEFAULT 0,
     currency TEXT NOT NULL DEFAULT 'CNY',
     type INTEGER NOT NULL DEFAULT 0,
     color INTEGER NOT NULL DEFAULT 4294908935,
     grouping INTEGER NOT NULL DEFAULT 0,
     criterion INTEGER,
     exclude_from_totals INTEGER NOT NULL DEFAULT 0,
     uuid TEXT,
     sealed INTEGER NOT NULL DEFAULT 0,
     sort_by TEXT NOT NULL DEFAULT 'date',
     sort_direction INTEGER NOT NULL DEFAULT -1,
     exchange_rate REAL NOT NULL DEFAULT 1.0,
     dynamic INTEGER NOT NULL DEFAULT 0,
     parent_id INTEGER,
     bank_id INTEGER,
     last_used INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS transactions (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     comment TEXT,
     date INTEGER NOT NULL,
     value_date INTEGER NOT NULL,
     amount INTEGER NOT NULL,
     cat_id INTEGER,
     account_id INTEGER NOT NULL,
     payee_id INTEGER,
     transfer_peer INTEGER,
     transfer_account INTEGER,
     method_id INTEGER,
     parent_id INTEGER,
     status INTEGER NOT NULL DEFAULT 0,
     cr_status TEXT NOT NULL DEFAULT 'UNRECONCILED',
     number TEXT,
     uuid TEXT,
     original_amount INTEGER,
     original_currency TEXT,
     debt_id INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS categories (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     label TEXT NOT NULL,
     label_normalized TEXT,
     parent_id INTEGER NOT NULL DEFAULT 0,
     usages INTEGER NOT NULL DEFAULT 0,
     last_used INTEGER,
     color INTEGER,
     icon TEXT,
     uuid TEXT,
     type INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS paymentmethods (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     label TEXT NOT NULL,
     is_numbered INTEGER NOT NULL DEFAULT 0,
     type INTEGER NOT NULL DEFAULT 0,
     icon TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS payee (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     name TEXT NOT NULL,
     short_name TEXT,
     name_normalized TEXT,
     parent_id INTEGER NOT NULL DEFAULT 0,
     iban TEXT,
     bic TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS currency (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     code TEXT NOT NULL UNIQUE,
     label TEXT,
     fraction_digits INTEGER NOT NULL DEFAULT 2,
     symbol TEXT,
     grouping INTEGER NOT NULL DEFAULT 0,
     sort_by TEXT,
     sort_direction INTEGER NOT NULL DEFAULT 1,
     commodity_type INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS tags (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     label TEXT NOT NULL UNIQUE,
     color INTEGER
  )`,
  `CREATE TABLE IF NOT EXISTS transactions_tags (
     tag_id INTEGER NOT NULL,
     transaction_id INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS accounts_tags (
     tag_id INTEGER NOT NULL,
     account_id INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS budgets (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     title TEXT,
     description TEXT,
     account_id INTEGER,
     currency TEXT NOT NULL DEFAULT 'CNY',
     start INTEGER,
     end INTEGER,
     is_default INTEGER NOT NULL DEFAULT 0,
     uuid TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS budget_allocations (
     budget_id INTEGER NOT NULL,
     cat_id INTEGER NOT NULL,
     year INTEGER,
     second INTEGER,
     budget INTEGER,
     roll_over_previous INTEGER NOT NULL DEFAULT 0,
     roll_over_next INTEGER NOT NULL DEFAULT 0,
     one_time INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS debts (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     payee_id INTEGER,
     date INTEGER,
     label TEXT,
     amount INTEGER,
     currency TEXT,
     description TEXT,
     sealed INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE TABLE IF NOT EXISTS account_types (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     label TEXT NOT NULL,
     type_sort_key INTEGER NOT NULL DEFAULT 0,
     is_asset INTEGER NOT NULL DEFAULT 1,
     supports_reconciliation INTEGER NOT NULL DEFAULT 1
  )`,
  `CREATE TABLE IF NOT EXISTS account_flags (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     flag_label TEXT NOT NULL,
     flag_sort_key INTEGER NOT NULL DEFAULT 0,
     flag_icon TEXT,
     visible INTEGER NOT NULL DEFAULT 1
  )`
];

/**
 * 种子数据：默认账户类型/付款方法/分类/货币
 */
export const SEED_SQL: string[] = [
  `INSERT OR IGNORE INTO account_types (id, label, type_sort_key, is_asset, supports_reconciliation) VALUES
     (0, '银行账户', 0, 1, 1),
     (1, '现金账户', 1, 1, 1),
     (2, '信用卡', 2, 0, 1),
     (3, '其他资产', 3, 1, 1),
     (4, '其他负债账户', 4, 0, 1)`,
  `INSERT OR IGNORE INTO paymentmethods (id, label, is_numbered, type, icon) VALUES
     (1, '现金', 0, 0, ''),
     (2, '银行卡', 0, 0, ''),
     (3, '信用卡', 0, 0, ''),
     (4, '支票', 1, 0, ''),
     (5, '转账', 0, 0, ''),
     (6, '其他', 0, 0, '')`,
  `INSERT OR IGNORE INTO currency (code, label, fraction_digits, symbol) VALUES
     ('CNY', '人民币', 2, '¥'),
     ('USD', '美元', 2, '$'),
     ('EUR', '欧元', 2, '€'),
     ('GBP', '英镑', 2, '£'),
     ('JPY', '日元', 0, '¥')`,
  `INSERT OR IGNORE INTO categories (id, label, label_normalized, parent_id, type) VALUES
     (1, '餐饮', '餐饮', 0, -1),
     (2, '购物', '购物', 0, -1),
     (3, '交通', '交通', 0, -1),
     (4, '居住', '居住', 0, -1),
     (5, '娱乐', '娱乐', 0, -1),
     (6, '医疗', '医疗', 0, -1),
     (7, '教育', '教育', 0, -1),
     (8, '工资', '工资', 0, 1),
     (9, '奖金', '奖金', 0, 1),
     (10, '其他', '其他', 0, -1)`
];

/**
 * 数据库单例辅助
 */
export class DbHelper {
  private static instance: DbHelper | null = null;
  private store: relationalStore.RdbStore | null = null;

  static getInstance(): DbHelper {
    if (!DbHelper.instance) {
      DbHelper.instance = new DbHelper();
    }
    return DbHelper.instance;
  }

  /**
   * 初始化数据库（在 UIAbility onCreate 后调用）
   */
  async init(context: common.Context): Promise<relationalStore.RdbStore> {
    if (this.store) {
      return this.store;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.store.executeSql('PRAGMA journal_mode = WAL');
    for (let sql of CREATE_TABLES) {
      await this.store.executeSql(sql);
    }
    for (let sql of SEED_SQL) {
      await this.store.executeSql(sql);
    }
    return this.store;
  }

  getStore(): relationalStore.RdbStore | null {
    return this.store;
  }
}