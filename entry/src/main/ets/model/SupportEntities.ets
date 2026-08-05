/**
 * 付款方法：对应 Android PaymentMethod
 */
export class PaymentMethod {
  id: number = 0;
  label: string = '';
  isNumbered: boolean = false;
  type: number = 0; // -1 支出 / 0 中性 / 1 收入
  icon: string = '';
  // 关联账户类型（逗号分隔的 AccountType 值）
  accountTypes: string = '';
}

/**
 * 收款人/交易对手：对应 Android Payee/Party
 */
export class Payee {
  id: number = 0;
  name: string = '';
  shortName: string = '';
  nameNormalized: string = '';
  parentId: number = 0;
  iban: string = '';
  bic: string = '';
}

/**
 * 标签：对应 Android Tag
 */
export class Tag {
  id: number = 0;
  label: string = '';
  color: number = 0;
}

/**
 * 预算：对应 Android Budget
 */
export class Budget {
  id: number = 0;
  title: string = '';
  description: string = '';
  accountId: number = -1;
  currency: string = 'CNY';
  start: number = 0;
  end: number = 0;
  isDefault: boolean = false;
  uuid: string = '';
  budgetAmount: number = 0; // 汇总已分配
  spentAmount: number = 0; // 汇总已花费
}

/**
 * 债务：对应 Android Debt
 */
export class Debt {
  id: number = 0;
  payeeId: number = -1;
  date: number = 0;
  label: string = '';
  amount: number = 0;
  currency: string = 'CNY';
  description: string = '';
  sealed: boolean = false;
}