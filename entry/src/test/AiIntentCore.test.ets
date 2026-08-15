import { describe, it, expect } from '@ohos/hypium';
import { AiIntent } from '../main/ets/ai/AiIntentCore';
import { LocalIntentParser } from '../main/ets/ai/LocalIntentParser';
import { AiIntentValidator } from '../main/ets/ai/AiIntentValidator';

export default function aiIntentCoreTest() {
  describe('AiIntentCore', () => {
    it('parses_amount_and_cleans_expense_comment', 0, () => {
      const intent = LocalIntentParser.parse('买了午饭花了35元');

      expect(intent === null).assertEqual(false);
      if (intent === null) {
        return;
      }
      expect(intent.domain).assertEqual('transaction');
      expect(intent.action).assertEqual('create');
      expect(intent.fields['type']).assertEqual('expense');
      expect(intent.fields['amount']).assertEqual(35);
      expect(intent.fields['comment']).assertEqual('午饭');
    });

    it('parses_decimal_amount', 0, () => {
      const intent = LocalIntentParser.parse('咖啡 18.50 元');

      expect(intent === null).assertEqual(false);
      if (intent === null) {
        return;
      }
      expect(intent.fields['amount']).assertEqual(18.5);
      expect(intent.fields['comment']).assertEqual('咖啡');
    });

    it('recognizes_income_keyword_and_cleans_comment', 0, () => {
      const intent = LocalIntentParser.parse('工资到账 8000 元');

      expect(intent === null).assertEqual(false);
      if (intent === null) {
        return;
      }
      expect(intent.fields['type']).assertEqual('income');
      expect(intent.fields['amount']).assertEqual(8000);
      expect(intent.fields['comment']).assertEqual('工资');
    });

    it('recognizes_refund_as_income', 0, () => {
      const intent = LocalIntentParser.parse('网购退款 45.5 元');

      expect(intent === null).assertEqual(false);
      if (intent === null) {
        return;
      }
      expect(intent.fields['type']).assertEqual('income');
      expect(intent.fields['amount']).assertEqual(45.5);
    });

    it('defaults_simple_monetary_entry_to_expense', 0, () => {
      const intent = LocalIntentParser.parse('地铁 3元');

      expect(intent === null).assertEqual(false);
      if (intent === null) {
        return;
      }
      expect(intent.fields['type']).assertEqual('expense');
      expect(intent.fields['comment']).assertEqual('地铁');
    });

    it('does_not_match_text_without_amount', 0, () => {
      const intent = LocalIntentParser.parse('今天吃了午饭');

      expect(intent === null).assertEqual(true);
    });

    it('does_not_reinterpret_dangerous_command_as_create', 0, () => {
      const intent = LocalIntentParser.parse('删除午饭35元');

      expect(intent === null).assertEqual(true);
    });

    it('does_not_reinterpret_read_only_query_as_expense', 0, () => {
      const intent = LocalIntentParser.parse('查看最近30天的支出');

      expect(intent === null).assertEqual(true);
    });

    it('does_not_reinterpret_recurring_request_as_single_expense', 0, () => {
      const intent = LocalIntentParser.parse('每月房租1000元');

      expect(intent === null).assertEqual(true);
    });

    it('does_not_reinterpret_split_wording_as_single_expense', 0, () => {
      const intent = LocalIntentParser.parse('50元分成两份');

      expect(intent === null).assertEqual(true);
    });

    it('rejects_ambiguous_number_contexts_instead_of_guessing_an_expense', 0, () => {
      const texts: string[] = [
        '工资卡买菜35元',
        '设置本月预算1000元',
        '停车2小时',
        '买苹果3个'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('rejects_query_recurring_and_delete_synonyms', 0, () => {
      const texts: string[] = [
        '删了午饭35元',
        '最近30天花了多少',
        '每个月房租1000元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('rejects_units_and_context_that_local_parser_cannot_preserve', 0, () => {
      const texts: string[] = [
        '工资1万元',
        '咖啡5角',
        '昨天从现金付午饭35元',
        '午饭35美元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('rejects_negated_or_descriptionless_entries', 0, () => {
      const texts: string[] = [
        '不要记午饭35元',
        '别帮我记午饭35元',
        '我没花35元买午饭',
        '把午饭35元去掉',
        '午饭是不是35元',
        '35元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('parses_leading_decimal_without_dropping_the_decimal_point', 0, () => {
      const intent = LocalIntentParser.parse('午饭.5元');

      expect(intent === null).assertEqual(false);
      if (intent === null) {
        return;
      }
      expect(intent.fields['amount']).assertEqual(0.5);
      expect(intent.fields['comment']).assertEqual('午饭');
    });

    it('requires_money_or_bookkeeping_evidence', 0, () => {
      expect(LocalIntentParser.parse('客服电话12345') === null).assertEqual(true);
      expect(LocalIntentParser.parse('地铁 3') === null).assertEqual(true);
    });

    it('does_not_treat_reminders_or_messages_as_completed_transactions', 0, () => {
      const texts: string[] = [
        '提醒我交35元话费',
        '收到短信说本月话费100元',
        '待缴水费80元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('uses_direction_phrases_instead_of_broad_income_substrings', 0, () => {
      const salary = LocalIntentParser.parse('工资8000元');
      const sentRedPacket = LocalIntentParser.parse('发红包200元');

      expect(salary === null).assertEqual(false);
      expect(sentRedPacket === null).assertEqual(false);
      if (salary && sentRedPacket) {
        expect(salary.fields['type']).assertEqual('income');
        expect(sentRedPacket.fields['type']).assertEqual('expense');
      }
    });

    it('rejects_amounts_that_local_path_cannot_store_exactly', 0, () => {
      const texts: string[] = [
        '咖啡0.005元',
        '设备9007199254740992元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('rejects_unfinished_cancelled_question_and_relative_date_variants', 0, () => {
      const texts: string[] = [
        '无需记录午饭35元',
        '午饭35元未支付',
        '午饭35元作废',
        '移除午饭35元',
        '午饭35元对不对',
        '记得交35元话费',
        '稍后支付35元话费',
        '工资扣税500元',
        '申请退款45元',
        '下周工资8000元',
        '后天午饭35元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('rejects_unpreserved_account_currency_and_completion_context', 0, () => {
      const texts: string[] = [
        '退款还没收到35元',
        '午饭不是35元',
        '从支付宝付午饭35元',
        '午饭花了35元人民币',
        '午饭35 CNY',
        '午饭35 RMB',
        '周末午饭35元'
      ];

      for (let text of texts) {
        expect(LocalIntentParser.parse(text) === null).assertEqual(true);
      }
    });

    it('allows_single_transaction_create', 0, () => {
      const fields: Record<string, string | number> = {};
      fields['type'] = 'expense';
      fields['amount'] = 35;
      fields['comment'] = '午饭';
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: fields
      };

      expect(AiIntentValidator.validate(intent).valid).assertEqual(true);
    });

    it('allows_read_only_transaction_actions', 0, () => {
      const actions: string[] = ['query', 'filter', 'sort'];

      for (let action of actions) {
        const intent: AiIntent = {
          domain: 'transaction',
          action: action,
          targets: [],
          fields: {}
        };
        expect(AiIntentValidator.validate(intent).valid).assertEqual(true);
      }
    });

    it('rejects_dangerous_transaction_actions', 0, () => {
      const actions: string[] = ['edit', 'delete', 'split', 'export'];

      for (let action of actions) {
        const intent: AiIntent = {
          domain: 'transaction',
          action: action,
          targets: [],
          fields: {}
        };
        expect(AiIntentValidator.validate(intent).valid).assertEqual(false);
      }
    });

    it('rejects_multistep_intent', 0, () => {
      const stepFields: Record<string, string | number> = {};
      stepFields['type'] = 'expense';
      stepFields['amount'] = 20;
      const step: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: stepFields
      };
      const steps: AiIntent[] = [step];
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'query',
        targets: [],
        fields: {},
        steps: steps
      };

      expect(AiIntentValidator.validate(intent).valid).assertEqual(false);
    });

    it('requires_create_type', 0, () => {
      const fields: Record<string, string | number> = {};
      fields['amount'] = 35;
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: fields
      };

      expect(AiIntentValidator.validate(intent).valid).assertEqual(false);
    });

    it('requires_positive_create_amount', 0, () => {
      const amounts: number[] = [0, -1];

      for (let amount of amounts) {
        const fields: Record<string, string | number> = {};
        fields['type'] = 'expense';
        fields['amount'] = amount;
        const intent: AiIntent = {
          domain: 'transaction',
          action: 'create',
          targets: [],
          fields: fields
        };
        expect(AiIntentValidator.validate(intent).valid).assertEqual(false);
      }
    });

    it('rejects_transfer_create', 0, () => {
      const fields: Record<string, string | number> = {};
      fields['type'] = 'transfer';
      fields['amount'] = 100;
      const intent: AiIntent = {
        domain: 'transaction',
        action: 'create',
        targets: [],
        fields: fields
      };

      expect(AiIntentValidator.validate(intent).valid).assertEqual(false);
    });

    it('rejects_non_transaction_domain', 0, () => {
      const intent: AiIntent = {
        domain: 'account',
        action: 'query',
        targets: [],
        fields: {}
      };

      expect(AiIntentValidator.validate(intent).valid).assertEqual(false);
    });
  });
}
