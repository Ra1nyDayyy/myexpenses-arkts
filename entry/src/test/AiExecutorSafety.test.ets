import { describe, expect, it } from '@ohos/hypium';
import {
  AiConfirmedTransactionRepository,
  AiExecutionResult,
  AiExecutor
} from '../main/ets/database/AiExecutor';
import { AiIntent } from '../main/ets/database/AiService';
import {
  AiExecutionPlan,
  CONFIRMED_TRANSACTION_SCHEMA,
  ConfirmedTransactionPlan
} from '../main/ets/ai/AiExecutionPlan';
import { AiIntentValidator } from '../main/ets/ai/AiIntentValidator';
import { Account } from '../main/ets/model/Account';
import { Category } from '../main/ets/model/Category';
import { Transaction } from '../main/ets/model/Transaction';

class FakeConfirmedRepository implements AiConfirmedTransactionRepository {
  account: Account | null = null;
  category: Category | null = null;
  accessCount: number = 0;
  writeCount: number = 0;
  lastTransaction: Transaction | null = null;

  async getAccount(id: number): Promise<Account | null> {
    this.accessCount++;
    if (this.account && this.account.id === id) {
      return this.account;
    }
    return null;
  }

  async getCategory(id: number): Promise<Category | null> {
    this.accessCount++;
    if (this.category && this.category.id === id) {
      return this.category;
    }
    return null;
  }

  async insertTransaction(transaction: Transaction): Promise<number> {
    this.accessCount++;
    this.writeCount++;
    this.lastTransaction = transaction;
    return 88;
  }
}

function account(id: number, currency: string): Account {
  const result = new Account();
  result.id = id;
  result.label = '测试账户';
  result.currency = currency;
  return result;
}

function confirmedPlan(
  amountMajor: string = '12.34', currency: string = 'CNY', fractionDigits: number = 2
): ConfirmedTransactionPlan {
  const fields: Record<string, string | number> = {};
  fields['type'] = 'expense';
  fields['amountMajor'] = amountMajor;
  fields['accountId'] = 7;
  fields['date'] = 1786723200;
  fields['currency'] = currency;
  fields['fractionDigits'] = fractionDigits;
  fields['categoryId'] = -1;
  fields['comment'] = '午饭';
  return {
    schema: CONFIRMED_TRANSACTION_SCHEMA,
    fields: fields
  };
}

export default function aiExecutorSafetyTest() {
  describe('AiExecutorSafety', () => {
    it('blocks destructive transaction actions before repository access', 0, async () => {
      const repository = new FakeConfirmedRepository();
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'delete',
        targets: [],
        fields: {}
      };

      const result: AiExecutionResult = await new AiExecutor(repository).execute(intent);

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('暂未执行');
      expect(result.message).assertContain('删除');
      expect(repository.accessCount).assertEqual(0);
    });

    it('blocks multi-step intents before repository access', 0, async () => {
      const repository = new FakeConfirmedRepository();
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: {},
        steps: [{
          domain: 'unknown',
          action: 'query',
          targets: [],
          fields: {}
        }]
      };

      const result = await new AiExecutor(repository).execute(intent);

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('多步骤');
      expect(repository.accessCount).assertEqual(0);
    });

    it('never writes a raw create intent even when all fields look complete', 0, async () => {
      const repository = new FakeConfirmedRepository();
      const fields: Record<string, string | number> = {};
      fields['type'] = 'expense';
      fields['amount'] = 35;
      fields['accountId'] = 7;
      fields['date'] = 1786723200;
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: fields
      };

      const result = await new AiExecutor(repository).execute(intent);

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('预览');
      expect(repository.accessCount).assertEqual(0);
      expect(repository.writeCount).assertEqual(0);
    });

    it('rejects unknown preview fields instead of matching payees or categories by text', 0, () => {
      const fields: Record<string, string | number> = {};
      fields['type'] = 'expense';
      fields['amount'] = 35;
      fields['payee'] = '模糊收款人';
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: fields
      };

      const validation = AiIntentValidator.validate(intent);

      expect(validation.valid).assertEqual(false);
      expect(validation.error).assertContain('未知字段');
    });

    it('converts JPY major units without adding decimal places', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('123', 0);

      expect(result.valid).assertEqual(true);
      expect(result.minorUnits).assertEqual(123);
    });

    it('converts two-decimal currency to exact minor units', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('12.34', 2);

      expect(result.valid).assertEqual(true);
      expect(result.minorUnits).assertEqual(1234);
    });

    it('accepts a leading decimal amount entered in the correction dialog', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('.5', 2);

      expect(result.valid).assertEqual(true);
      expect(result.minorUnits).assertEqual(50);
    });

    it('converts three-decimal currency to exact minor units', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('1.234', 3);

      expect(result.valid).assertEqual(true);
      expect(result.minorUnits).assertEqual(1234);
    });

    it('rejects precision beyond the account currency', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('0.001', 2);

      expect(result.valid).assertEqual(false);
      expect(result.error).assertContain('小数');
    });

    it('rejects amounts that quantize to zero', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('0.00', 2);

      expect(result.valid).assertEqual(false);
      expect(result.error).assertContain('大于 0');
    });

    it('rejects amounts beyond the safe integer range', 0, () => {
      const result = AiExecutionPlan.convertMajorToMinor('90071992547409.92', 2);

      expect(result.valid).assertEqual(false);
      expect(result.error).assertContain('过大');
    });

    it('rejects confirmed plans with unknown fields before repository access', 0, async () => {
      const repository = new FakeConfirmedRepository();
      const plan = confirmedPlan();
      plan.fields['payee'] = '不允许的隐式字段';

      const result = await new AiExecutor(repository).executeConfirmed(plan);

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('未知字段');
      expect(repository.accessCount).assertEqual(0);
    });

    it('rejects a missing account without writing', 0, async () => {
      const repository = new FakeConfirmedRepository();

      const result = await new AiExecutor(repository).executeConfirmed(confirmedPlan());

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('账户');
      expect(repository.writeCount).assertEqual(0);
    });

    it('rejects a currency snapshot that differs from the exact account', 0, async () => {
      const repository = new FakeConfirmedRepository();
      repository.account = account(7, 'JPY');

      const result = await new AiExecutor(repository).executeConfirmed(confirmedPlan('123', 'CNY', 2));

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('币种');
      expect(repository.writeCount).assertEqual(0);
    });

    it('rejects an exact category whose type conflicts with the transaction type', 0, async () => {
      const repository = new FakeConfirmedRepository();
      repository.account = account(7, 'CNY');
      const incomeCategory = new Category();
      incomeCategory.id = 9;
      incomeCategory.type = 1;
      repository.category = incomeCategory;
      const plan = confirmedPlan();
      plan.fields['categoryId'] = 9;

      const result = await new AiExecutor(repository).executeConfirmed(plan);

      expect(result.ok).assertEqual(false);
      expect(result.wrote).assertEqual(false);
      expect(result.message).assertContain('分类');
      expect(repository.writeCount).assertEqual(0);
    });

    it('writes exactly once with the explicit account date currency and amount', 0, async () => {
      const repository = new FakeConfirmedRepository();
      repository.account = account(7, 'CNY');

      const result = await new AiExecutor(repository).executeConfirmed(confirmedPlan());

      expect(result.ok).assertEqual(true);
      expect(result.wrote).assertEqual(true);
      expect(result.transactionId).assertEqual(88);
      expect(repository.writeCount).assertEqual(1);
      expect(repository.lastTransaction === null).assertEqual(false);
      if (!repository.lastTransaction) {
        return;
      }
      expect(repository.lastTransaction.accountId).assertEqual(7);
      expect(repository.lastTransaction.date).assertEqual(1786723200);
      expect(repository.lastTransaction.valueDate).assertEqual(1786723200);
      expect(repository.lastTransaction.amount).assertEqual(-1234);
      expect(repository.lastTransaction.currency).assertEqual('CNY');
      expect(repository.lastTransaction.payeeId).assertEqual(-1);
      expect(repository.lastTransaction.uuid.length > 0).assertEqual(true);
    });

    it('writes JPY exactly once without multiplying by one hundred', 0, async () => {
      const repository = new FakeConfirmedRepository();
      repository.account = account(7, 'JPY');

      const result = await new AiExecutor(repository).executeConfirmed(confirmedPlan('123', 'JPY', 0));

      expect(result.ok).assertEqual(true);
      expect(result.wrote).assertEqual(true);
      expect(repository.writeCount).assertEqual(1);
      expect(repository.lastTransaction === null).assertEqual(false);
      if (repository.lastTransaction) {
        expect(repository.lastTransaction.amount).assertEqual(-123);
        expect(repository.lastTransaction.currency).assertEqual('JPY');
      }
    });
  });
}
