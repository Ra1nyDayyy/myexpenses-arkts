import { describe, it, expect } from '@ohos/hypium';
import { InsightCalculator, InsightTimeRange } from '../main/ets/ai/InsightCalculator';
import { SPLIT_CATID, Transaction } from '../main/ets/model/Transaction';

function localEpoch(year: number, month: number, day: number, hour: number = 0): number {
  return Math.floor(new Date(year, month - 1, day, hour, 0, 0).getTime() / 1000);
}

function transaction(
  amount: number,
  date: number,
  categoryId: number,
  categoryPath: string,
  parentId: number = -1,
  transferAccountId: number = -1,
  id: number = 0
): Transaction {
  const value = new Transaction();
  value.id = id;
  value.amount = amount;
  value.date = date;
  value.valueDate = date;
  value.categoryId = categoryId;
  value.categoryPath = categoryPath;
  value.parentId = parentId;
  value.transferAccountId = transferAccountId;
  return value;
}

export default function insightCalculatorTest() {
  describe('InsightCalculator', () => {
    it('reports ordinary income, absolute expense and net amount', 0, () => {
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2026, 1, 1),
        endExclusive: localEpoch(2026, 2, 1)
      };
      const transactions: Transaction[] = [
        transaction(10000, localEpoch(2026, 1, 5), 1, '工资'),
        transaction(-3500, localEpoch(2026, 1, 10), 2, '餐饮')
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.totalIncome).assertEqual(10000);
      expect(result.totalExpense).assertEqual(3500);
      expect(result.netAmount).assertEqual(6500);
    });

    it('excludes both sides of transfers from every insight', 0, () => {
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2026, 1, 1),
        endExclusive: localEpoch(2026, 2, 1)
      };
      const transactions: Transaction[] = [
        transaction(-5000, localEpoch(2026, 1, 8), 2, '餐饮'),
        transaction(-9000, localEpoch(2026, 1, 9), -1, '', -1, 2),
        transaction(9000, localEpoch(2026, 1, 9), -1, '', -1, 1)
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.totalIncome).assertEqual(0);
      expect(result.totalExpense).assertEqual(5000);
      expect(result.netAmount).assertEqual(-5000);
      expect(result.categoryBreakdown.length).assertEqual(1);
      expect(result.monthlyTrend[0].expense).assertEqual(5000);
    });

    it('counts a split parent once in totals and its children only in categories', 0, () => {
      const date = localEpoch(2026, 1, 12);
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2026, 1, 1),
        endExclusive: localEpoch(2026, 2, 1)
      };
      const transactions: Transaction[] = [
        transaction(-10000, date, SPLIT_CATID, '拆分', -1, -1, 42),
        transaction(-4000, date, 2, '餐饮', 42),
        transaction(-6000, date, 3, '日用', 42)
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.totalExpense).assertEqual(10000);
      expect(result.netAmount).assertEqual(-10000);
      expect(result.monthlyTrend[0].expense).assertEqual(10000);
      expect(result.categoryBreakdown.length).assertEqual(2);
      expect(result.categoryBreakdown[0].label).assertEqual('日用');
      expect(result.categoryBreakdown[0].amount).assertEqual(6000);
      expect(result.categoryBreakdown[1].label).assertEqual('餐饮');
      expect(result.categoryBreakdown[1].amount).assertEqual(4000);
    });

    it('recognizes a split parent after its category sentinel is lost on database round-trip', 0, () => {
      const date = localEpoch(2026, 1, 13);
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2026, 1, 1),
        endExclusive: localEpoch(2026, 2, 1)
      };
      const transactions: Transaction[] = [
        // Repository persists a negative category id as NULL, then reads it back as -1.
        transaction(-10000, date, -1, '', -1, -1, 73),
        transaction(-4000, date, 2, '餐饮', 73),
        transaction(-6000, date, 3, '日用', 73)
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.totalExpense).assertEqual(10000);
      expect(result.categoryBreakdown.length).assertEqual(2);
      expect(result.categoryBreakdown[0].label).assertEqual('日用');
      expect(result.categoryBreakdown[0].amount).assertEqual(6000);
      expect(result.categoryBreakdown[1].label).assertEqual('餐饮');
      expect(result.categoryBreakdown[1].amount).assertEqual(4000);
    });

    it('keeps an ordinary uncategorized expense in category insights', 0, () => {
      const date = localEpoch(2026, 1, 14);
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2026, 1, 1),
        endExclusive: localEpoch(2026, 2, 1)
      };

      const result = InsightCalculator.calculate([
        transaction(-500, date, -1, '', -1, -1, 74)
      ], range);

      expect(result.categoryBreakdown.length).assertEqual(1);
      expect(result.categoryBreakdown[0].label).assertEqual('未分类');
      expect(result.categoryBreakdown[0].amount).assertEqual(500);
      expect(result.categoryBreakdown[0].percentage).assertEqual(100);
    });

    it('uses a start-inclusive and end-exclusive time range', 0, () => {
      const start = localEpoch(2026, 1, 1);
      const end = localEpoch(2026, 2, 1);
      const range: InsightTimeRange = {
        startInclusive: start,
        endExclusive: end
      };
      const transactions: Transaction[] = [
        transaction(100, start - 1, 1, '工资'),
        transaction(500, start, 1, '工资'),
        transaction(700, end, 1, '工资'),
        transaction(-100, start - 1, 2, '餐饮'),
        transaction(-200, start, 2, '餐饮'),
        transaction(-400, end, 2, '餐饮'),
        transaction(-150, start - 1, 3, '日用', 42),
        transaction(-300, start, 3, '日用', 42),
        transaction(-450, end, 3, '日用', 42)
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.totalIncome).assertEqual(500);
      expect(result.totalExpense).assertEqual(200);
      expect(result.netAmount).assertEqual(300);
      expect(result.categoryBreakdown.length).assertEqual(2);
      expect(result.categoryBreakdown[0].label).assertEqual('日用');
      expect(result.categoryBreakdown[0].amount).assertEqual(300);
      expect(result.categoryBreakdown[0].percentage).assertEqual(60);
      expect(result.categoryBreakdown[1].label).assertEqual('餐饮');
      expect(result.categoryBreakdown[1].amount).assertEqual(200);
      expect(result.categoryBreakdown[1].percentage).assertEqual(40);
      expect(result.monthlyTrend.length).assertEqual(1);
      expect(result.monthlyTrend[0].income).assertEqual(500);
      expect(result.monthlyTrend[0].expense).assertEqual(200);
      expect(result.monthlyTrend[0].netAmount).assertEqual(300);
    });

    it('returns no month for an empty mid-month interval', 0, () => {
      const boundary = localEpoch(2026, 1, 15, 12);
      const range: InsightTimeRange = {
        startInclusive: boundary,
        endExclusive: boundary
      };

      const result = InsightCalculator.calculate([
        transaction(-500, boundary, 2, '餐饮')
      ], range);

      expect(result.totalIncome).assertEqual(0);
      expect(result.totalExpense).assertEqual(0);
      expect(result.netAmount).assertEqual(0);
      expect(result.categoryBreakdown.length).assertEqual(0);
      expect(result.monthlyTrend.length).assertEqual(0);
    });

    it('aggregates ordinary and split-child expenses by category with percentages', 0, () => {
      const date = localEpoch(2026, 1, 16);
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2026, 1, 1),
        endExclusive: localEpoch(2026, 2, 1)
      };
      const transactions: Transaction[] = [
        transaction(-2000, date, 2, '餐饮'),
        transaction(-8000, date, SPLIT_CATID, '拆分', -1, -1, 88),
        transaction(-1000, date, 2, '餐饮', 88),
        transaction(-7000, date, 3, '日用', 88)
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.categoryBreakdown.length).assertEqual(2);
      expect(result.categoryBreakdown[0].label).assertEqual('日用');
      expect(result.categoryBreakdown[0].amount).assertEqual(7000);
      expect(result.categoryBreakdown[0].percentage).assertEqual(70);
      expect(result.categoryBreakdown[1].label).assertEqual('餐饮');
      expect(result.categoryBreakdown[1].amount).assertEqual(3000);
      expect(result.categoryBreakdown[1].percentage).assertEqual(30);
    });

    it('returns chronological monthly entries including empty months', 0, () => {
      const range: InsightTimeRange = {
        startInclusive: localEpoch(2025, 12, 15),
        endExclusive: localEpoch(2026, 3, 1)
      };
      const transactions: Transaction[] = [
        transaction(1000, localEpoch(2025, 12, 20), 1, '工资'),
        transaction(-250, localEpoch(2026, 2, 10), 2, '餐饮')
      ];

      const result = InsightCalculator.calculate(transactions, range);

      expect(result.monthlyTrend.length).assertEqual(3);
      expect(result.monthlyTrend[0].month).assertEqual('2025-12');
      expect(result.monthlyTrend[0].income).assertEqual(1000);
      expect(result.monthlyTrend[0].netAmount).assertEqual(1000);
      expect(result.monthlyTrend[1].month).assertEqual('2026-01');
      expect(result.monthlyTrend[1].income).assertEqual(0);
      expect(result.monthlyTrend[1].expense).assertEqual(0);
      expect(result.monthlyTrend[2].month).assertEqual('2026-02');
      expect(result.monthlyTrend[2].expense).assertEqual(250);
      expect(result.monthlyTrend[2].netAmount).assertEqual(-250);
    });
  });
}
