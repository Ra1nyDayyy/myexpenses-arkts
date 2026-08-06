/**
 * 账户实体：对应 Android model2/Account.kt
 */
export enum AccountType {
  BANK = 0,
  CASH = 1,
  CCARD = 2,
  ASSET = 3,
  LIABILITY = 4
}

export enum AccountGrouping {
  NONE = 0,
  TYPE = 1,
  CURRENCY = 2,
  FLAG = 3
}

export enum SortDirection {
  ASC = 1,
  DESC = -1
}

export enum BalanceType {
  OPENING = 0,
  CURRENT = 1
}

export class Account {
  id: number = 0;
  label: string = '';
  description: string = '';
  openingBalance: number = 0; // 最小货币单位
  currency: string = 'CNY';
  type: AccountType = AccountType.BANK;
  color: number = 0xFFC107; // 0xAARRGGBB
  grouping: AccountGrouping = AccountGrouping.NONE;
  criterion: number = 0; // 储蓄目标/信用额度
  excludeFromTotals: boolean = false;
  uuid: string = '';
  sealed: boolean = false;
  sortBy: string = 'date'; // date | amount
  sortDirection: SortDirection = SortDirection.DESC;
  exchangeRate: number = 1.0;
  dynamic: boolean = false;
  parentId: number = -1;
  bankId: number = -1;
  lastUsed: number = 0;
  flagId: number = 1; // 账户标记 id（对应 account_flags）
  flagLabel: string = '默认';
  // 汇总字段（查询时填充）
  currentBalance: number = 0;
  sumIncome: number = 0;
  sumExpense: number = 0;
  sumTransfer: number = 0;
  equivalentCurrentBalance: number = 0;
  equivalentOpeningBalance: number = 0;
  equivalentSumIncome: number = 0;
  equivalentSumExpense: number = 0;
  equivalentSumTransfer: number = 0;
  clearedTotal: number = 0;
  reconciledTotal: number = 0;
  hasCleared: boolean = false;

  static DEFAULT_COLOR = 0xFFA6978; // -0xff6978 = 0xFF009688

  static typeName(type: AccountType): string {
    switch (type) {
      case AccountType.BANK:
        return '银行账户';
      case AccountType.CASH:
        return '现金账户';
      case AccountType.CCARD:
        return '信用卡';
      case AccountType.ASSET:
        return '其他资产';
      case AccountType.LIABILITY:
        return '其他负债账户';
      default:
        return '银行账户';
    }
  }
}