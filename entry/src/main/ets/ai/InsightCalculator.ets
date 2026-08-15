import { Transaction } from '../model/Transaction';

/** Epoch-second interval with an inclusive start and an exclusive end. */
export interface InsightTimeRange {
  startInclusive: number;
  endExclusive: number;
}

/** Expense category values use the same smallest-currency-unit as Transaction.amount. */
export interface CategoryInsight {
  label: string;
  amount: number;
  percentage: number;
}

/** Monthly expense is positive; netAmount is income minus expense. */
export interface MonthlyInsight {
  month: string;
  income: number;
  expense: number;
  netAmount: number;
}

export interface InsightSummary {
  totalIncome: number;
  totalExpense: number;
  netAmount: number;
  categoryBreakdown: CategoryInsight[];
  monthlyTrend: MonthlyInsight[];
}

/**
 * Pure transaction insight calculation.
 *
 * Callers must pass transactions from one currency. Calendar month labels use the
 * device's local timezone, matching the app's transaction date presentation.
 */
export class InsightCalculator {
  static calculate(transactions: Transaction[], range: InsightTimeRange): InsightSummary {
    const monthlyTrend = InsightCalculator.createMonthlyTrend(range);
    const monthlyByKey: Map<string, MonthlyInsight> = new Map<string, MonthlyInsight>();
    for (let month of monthlyTrend) {
      monthlyByKey.set(month.month, month);
    }

    let totalIncome = 0;
    let totalExpense = 0;
    for (let transaction of transactions) {
      if (!InsightCalculator.isInRange(transaction, range) ||
        transaction.isTransfer() || transaction.isSplitPart()) {
        continue;
      }

      const month = monthlyByKey.get(InsightCalculator.monthKey(transaction.date));
      if (transaction.amount > 0) {
        totalIncome += transaction.amount;
        if (month) {
          month.income += transaction.amount;
          month.netAmount += transaction.amount;
        }
      } else if (transaction.amount < 0) {
        const expense = Math.abs(transaction.amount);
        totalExpense += expense;
        if (month) {
          month.expense += expense;
          month.netAmount -= expense;
        }
      }
    }

    const categoryBreakdown = InsightCalculator.calculateCategories(transactions, range);
    const result: InsightSummary = {
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netAmount: totalIncome - totalExpense,
      categoryBreakdown: categoryBreakdown,
      monthlyTrend: monthlyTrend
    };
    return result;
  }

  private static calculateCategories(
    transactions: Transaction[],
    range: InsightTimeRange
  ): CategoryInsight[] {
    const splitParentIds: Set<number> = new Set<number>();
    for (let transaction of transactions) {
      if (transaction.isSplitPart()) {
        splitParentIds.add(transaction.parentId);
      }
    }

    const amounts: Map<string, number> = new Map<string, number>();
    let total = 0;
    for (let transaction of transactions) {
      if (!InsightCalculator.isInRange(transaction, range) ||
        transaction.isTransfer() || transaction.amount >= 0) {
        continue;
      }

      const isSplitParent = !transaction.isSplitPart() &&
        (transaction.isSplit() || splitParentIds.has(transaction.id));
      if (isSplitParent) {
        continue;
      }

      const label = transaction.categoryPath.length > 0 ? transaction.categoryPath : '未分类';
      const amount = Math.abs(transaction.amount);
      const existing = amounts.get(label);
      amounts.set(label, (existing === undefined ? 0 : existing) + amount);
      total += amount;
    }

    const result: CategoryInsight[] = [];
    amounts.forEach((amount: number, label: string) => {
      const item: CategoryInsight = {
        label: label,
        amount: amount,
        percentage: total > 0 ? amount / total * 100 : 0
      };
      result.push(item);
    });
    result.sort((left: CategoryInsight, right: CategoryInsight): number => {
      if (left.amount !== right.amount) {
        return right.amount - left.amount;
      }
      if (left.label < right.label) {
        return -1;
      }
      if (left.label > right.label) {
        return 1;
      }
      return 0;
    });
    return result;
  }

  private static createMonthlyTrend(range: InsightTimeRange): MonthlyInsight[] {
    const result: MonthlyInsight[] = [];
    if (range.endExclusive <= range.startInclusive) {
      return result;
    }

    const start = new Date(range.startInclusive * 1000);
    let year = start.getFullYear();
    let month = start.getMonth();

    while (Math.floor(new Date(year, month, 1).getTime() / 1000) < range.endExclusive) {
      const item: MonthlyInsight = {
        month: InsightCalculator.monthKeyFromParts(year, month),
        income: 0,
        expense: 0,
        netAmount: 0
      };
      result.push(item);
      month += 1;
      if (month > 11) {
        month = 0;
        year += 1;
      }
    }
    return result;
  }

  private static isInRange(transaction: Transaction, range: InsightTimeRange): boolean {
    return transaction.date >= range.startInclusive && transaction.date < range.endExclusive;
  }

  private static monthKey(epochSeconds: number): string {
    const date = new Date(epochSeconds * 1000);
    return InsightCalculator.monthKeyFromParts(date.getFullYear(), date.getMonth());
  }

  private static monthKeyFromParts(year: number, zeroBasedMonth: number): string {
    return `${year}-${(zeroBasedMonth + 1).toString().padStart(2, '0')}`;
  }
}
