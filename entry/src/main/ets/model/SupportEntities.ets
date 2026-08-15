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

/**
 * 交易模板：对应 Android Template（交易蓝图）
 * 可实例化为新交易（重复交易）
 */
export class Template {
  id: number = 0;
  title: string = '';
  accountId: number = -1;
  accountLabel: string = ''; // 展示字段：账户名（对齐安卓 KEY_ACCOUNT_LABEL）
  accountColor: number = 0xFFC107; // 展示字段：账户颜色（对齐安卓 KEY_COLOR 色条）
  transferAccountLabel: string = ''; // 展示字段：转账目标账户名
  amount: number = 0;
  comment: string = '';
  categoryId: number = -1;
  categoryPath: string = '';
  payeeId: number = -1;
  payeeName: string = '';
  methodId: number = -1;
  methodLabel: string = '';
  transferAccountId: number = -1;
  uuid: string = '';
  parentId: number = -1;
  currency: string = 'CNY';
  isIncome: boolean = false;
  tagIds: number[] = [];
  recurrence: number = 0; // Recurrence 枚举值
  dtStart: number = 0;
  lastExecuted: number = 0;
  autoExecute: boolean = false; // 自动执行开关
  advanceDays: number = 0; // 提前执行天数 0-30
  /** 默认操作（对齐安卓 Template.Action：SAVE=点击直接创建交易，EDIT=点击打开编辑页） */
  defaultAction: string = 'SAVE';

  isTransfer(): boolean {
    return this.transferAccountId !== -1;
  }

  isSplit(): boolean {
    return this.categoryId === -2;
  }
}

/**
 * 周期类型：对应 Android Recurrence
 */
export enum Recurrence {
  NONE = 0,
  ONETIME = 1,
  DAILY = 2,
  WEEKLY = 3,
  MONTHLY = 4,
  LAST_DAY_OF_MONTH = 5,
  YEARLY = 6
}

/**
 * 周期计划：对应 Android Plan（固定收支）
 * 关联模板，按周期生成重复交易
 */
export class Plan {
  id: number = 0;
  templateId: number = -1;
  dtStart: number = 0; // epoch 秒（首次发生日期）
  recurrence: Recurrence = Recurrence.NONE;
  title: string = '';
  description: string = '';
  lastExecuted: number = 0; // 上次生成交易的时间

  recurrenceLabel(): string {
    switch (this.recurrence) {
      case Recurrence.ONETIME:
        return '仅一次';
      case Recurrence.DAILY:
        return '每天';
      case Recurrence.WEEKLY:
        return '每周';
      case Recurrence.MONTHLY:
        return '每月';
      case Recurrence.LAST_DAY_OF_MONTH:
        return '每月最后一天';
      case Recurrence.YEARLY:
        return '每年';
      default:
        return '不重复';
    }
  }

  /**
   * 计算下一次应发生的日期（基于 dtStart + 周期 + 上次执行）
   */
  nextDueDate(now: number): number {
    const start = this.dtStart > 0 ? this.dtStart : now;
    const next = this.nextOccurrenceAfter(start, this.lastExecuted > 0 ? this.lastExecuted : start - 1);
    return next;
  }

  private nextOccurrenceAfter(start: number, after: number): number {
    const startDate = new Date(start * 1000);
    const afterDate = new Date(after * 1000);
    // 从 after+1 天开始找
    let cursor = new Date(afterDate.getFullYear(), afterDate.getMonth(), afterDate.getDate() + 1, 12, 0, 0);
    const dayOfWeekStart = startDate.getDay(); // 0=周日
    const dayOfMonthStart = startDate.getDate();
    let count = 0;
    while (count < 400) {
      switch (this.recurrence) {
        case Recurrence.ONETIME:
          return start > after ? start : 0;
        case Recurrence.DAILY:
          break;
        case Recurrence.WEEKLY:
          // 对齐到开始日期的星期几
          if (cursor.getDay() !== dayOfWeekStart) {
            cursor.setDate(cursor.getDate() + 1);
            count++;
            continue;
          }
          break;
        case Recurrence.MONTHLY:
          if (cursor.getDate() !== dayOfMonthStart) {
            cursor.setDate(cursor.getDate() + 1);
            count++;
            continue;
          }
          break;
        case Recurrence.LAST_DAY_OF_MONTH:
          {
            const nextMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0);
            if (cursor.getDate() !== nextMonth.getDate()) {
              cursor.setDate(cursor.getDate() + 1);
              count++;
              continue;
            }
          }
          break;
        case Recurrence.YEARLY:
          if (cursor.getMonth() !== startDate.getMonth() || cursor.getDate() !== dayOfMonthStart) {
            cursor.setDate(cursor.getDate() + 1);
            count++;
            continue;
          }
          break;
        default:
          return 0;
      }
      break;
    }
    return Math.floor(cursor.getTime() / 1000);
  }
}