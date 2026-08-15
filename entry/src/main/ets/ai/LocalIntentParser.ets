import { AiIntent } from './AiIntentCore';

/**
 * 高频单笔收支的本地解析器。
 *
 * 这里只识别一个阿拉伯数字金额和一段用途。带查询、编辑、删除、周期、
 * 数量/时长、账户/日期或本地无法完整保留的币种单位时，交给更严格的
 * 后端能力边界处理，避免把“看见一个数字”误解释为一笔新支出。
 */
export class LocalIntentParser {
  static parse(text: string): AiIntent | null {
    const normalized = text.trim();
    if (normalized.length === 0 || LocalIntentParser.hasUnsupportedMarker(normalized) ||
      !LocalIntentParser.hasTransactionEvidence(normalized)) {
      return null;
    }

    const amountMatches = normalized.match(/-?(?:\d+(?:\.\d+)?|\.\d+)/g);
    if (!amountMatches || amountMatches.length !== 1) {
      return null;
    }

    const amountText = amountMatches[0];
    if (!LocalIntentParser.isLocallySafeAmount(amountText)) {
      return null;
    }
    const amount = Number(amountText);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 99999999.99) {
      return null;
    }

    const fields: Record<string, string | number> = {};
    fields['type'] = LocalIntentParser.isIncome(normalized) ? 'income' : 'expense';
    fields['amount'] = amount;
    const comment = LocalIntentParser.cleanComment(normalized);
    if (comment.length === 0) {
      return null;
    }
    fields['comment'] = comment;

    const intent: AiIntent = {
      domain: 'transaction',
      action: 'create',
      targets: [],
      fields: fields
    };
    return intent;
  }

  private static hasUnsupportedMarker(text: string): boolean {
    const markers: string[] = [
      '删除', '删掉', '删了', '删', '修改', '编辑', '改成', '改为', '拆分', '导出',
      '转账', '查询', '查看', '筛选', '排序', '余额', '模板', '账户',
      '然后', '并且', '再记', '以及', '分成', '分摊', '定期', '周期', '每',
      '最近', '多少', '几笔', '统计', '汇总', '合计', '预算', '设置', '目标', '限额',
      '不要', '不用', '无需', '不需', '不是', '别', '取消', '不记', '没花', '没有花',
      '没付', '没有付', '未支付', '未付款', '未付', '未消费', '未发生', '未完成',
      '尚未', '还没', '没收到', '未收到', '去掉', '移除', '撤掉', '作废', '撤销',
      '是不是', '是否', '对不对', '吗',
      '提醒', '记得', '稍后', '待会', '等会', '以后', '下次', '准备', '打算',
      '预计', '估计', '大概', '可能', '申请', '短信', '待缴', '应缴', '未缴',
      '账单', '计划', '预约', '扣税', '扣款',
      '失败', '未到账', '没到账',
      '昨天', '昨晚', '前天', '明天', '后天', '大后天', '上周', '下周', '本周',
      '周末', '周中', '上月', '下月', '本月', '这个月', '月初', '月底',
      '前年', '去年', '今年', '明年', '年初', '年底', '日期',
      '从', '工资卡', '现金', '银行卡', '信用卡', '储蓄卡', '支付宝', '微信',
      '云闪付', '分类',
      '人民币', '美元', '美金', '日元', '欧元', '英镑', '港币',
      'CNY', 'RMB', 'USD', 'JPY', 'EUR', 'cny', 'rmb', 'usd', 'jpy', 'eur',
      '?', '？'
    ];
    for (let marker of markers) {
      if (text.includes(marker)) {
        return true;
      }
    }
    // “2小时”“3个”等数字描述的是时长/数量，不是金额。
    if (/-?(?:\d+(?:\.\d+)?|\.\d+)\s*(?:小时|分钟|天|个月|月|年|次|个|人|公里|km|kg|斤|张|件|瓶|杯)/i.test(text)) {
      return true;
    }
    // 万、千、角、分需要单位换算；本地 MVP 不猜测，避免 1 万被记成 1 元。
    if (/-?(?:\d+(?:\.\d+)?|\.\d+)\s*(?:万|千|角|分)(?:元)?/.test(text)) {
      return true;
    }
    if (/(?:本|这|上|下)(?:周|星期|礼拜|月|年)|(?:周|星期|礼拜)[一二三四五六日天]/.test(text)) {
      return true;
    }
    return false;
  }

  /**
   * 本地路径必须看到明确的金额单位/符号，或明确的记账方向词。
   * 这样“客服电话12345”“地铁 3”不会只因出现一个数字就生成写意图。
   */
  private static hasTransactionEvidence(text: string): boolean {
    const amountPattern = '-?(?:\\d+(?:\\.\\d+)?|\\.\\d+)';
    const hasUnitAfter = new RegExp(amountPattern + '\\s*(?:元|块钱|块)').test(text);
    const hasSymbolBefore = new RegExp('(?:￥|¥)\\s*' + amountPattern).test(text);
    if (hasUnitAfter || hasSymbolBefore) {
      return true;
    }
    const verbs: string[] = [
      '记一笔', '记账', '记录', '花了', '花费', '消费', '支付', '付款', '付了',
      '买了', '购买', '收入', '工资', '薪资', '奖金', '退款', '到账', '入账',
      '收款', '赚了', '赚到'
    ];
    for (let verb of verbs) {
      if (text.includes(verb)) {
        return true;
      }
    }
    return false;
  }

  private static isLocallySafeAmount(amountText: string): boolean {
    if (amountText.startsWith('-')) {
      return false;
    }
    const normalized = amountText.startsWith('.') ? '0' + amountText : amountText;
    const parts = normalized.split('.');
    if (parts.length > 1 && parts[1].length > 2) {
      return false;
    }
    return true;
  }

  private static isIncome(text: string): boolean {
    const expenseDirections: string[] = ['发红包', '给红包', '付红包', '发奖金'];
    for (let marker of expenseDirections) {
      if (text.includes(marker)) {
        return false;
      }
    }
    const markers: string[] = [
      '收入', '工资', '薪资', '奖金', '报销到账', '退款', '收红包', '领红包',
      '红包到账', '到账', '入账', '收到工资', '收到报销', '收到退款',
      '收到款', '收款', '赚了', '赚到'
    ];
    for (let marker of markers) {
      if (text.includes(marker)) {
        return true;
      }
    }
    return false;
  }

  private static cleanComment(text: string): string {
    let comment = text.replace(/-?(?:\d+(?:\.\d+)?|\.\d+)\s*(?:元|块钱|块|￥|¥)?/, ' ');
    const fillerPhrases: string[] = [
      '记一笔', '记账', '记录', '买了', '购买', '花了', '花费',
      '消费了', '消费', '支出', '付款', '付了', '收入', '到账',
      '入账', '收到', '收款', '赚了', '赚到'
    ];
    for (let phrase of fillerPhrases) {
      comment = comment.replace(new RegExp(phrase, 'g'), ' ');
    }
    return comment.replace(/[，,。.!！?？；;：:]/g, ' ').replace(/\s+/g, ' ').trim();
  }
}
