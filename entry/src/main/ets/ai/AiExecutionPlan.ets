/**
 * 用户在结构化预览中确认后的单笔交易计划。
 *
 * 与原始 AiIntent 分开建模，执行器只接受这一固定 schema 的计划写入账本。
 */
export const CONFIRMED_TRANSACTION_SCHEMA: string = 'confirmed-transaction-v1';

export interface ConfirmedTransactionPlan {
  schema: string;
  fields: Record<string, string | number>;
}

export interface MinorUnitConversionResult {
  valid: boolean;
  minorUnits: number;
  error: string;
}

export interface PreparedTransactionPlan {
  valid: boolean;
  error: string;
  type: string;
  amountMinor: number;
  accountId: number;
  date: number;
  currency: string;
  fractionDigits: number;
  categoryId: number;
  comment: string;
}

export class AiExecutionPlan {
  /**
   * 用十进制字符串完成主单位到最小单位的换算，避免浮点乘法造成静默四舍五入。
   */
  static convertMajorToMinor(amountMajor: string, fractionDigits: number): MinorUnitConversionResult {
    if (!Number.isInteger(fractionDigits) || fractionDigits < 0 || fractionDigits > 6) {
      return { valid: false, minorUnits: 0, error: '账户币种的小数位配置无效' };
    }
    const normalized = amountMajor.trim();
    if (!/^(?:\d+(?:\.\d+)?|\.\d+)$/.test(normalized)) {
      return { valid: false, minorUnits: 0, error: '金额格式无效' };
    }
    // 金额上限：单笔不超过 99999999.99（约 1 亿），避免极端大额写入
    if (Number(normalized) > 99999999.99) {
      return { valid: false, minorUnits: 0, error: '单笔金额过大（超过 99999999.99），暂未执行' };
    }
    const parts: string[] = normalized.split('.');
    const whole: string = parts[0].length > 0 ? parts[0] : '0';
    const decimals: string = parts.length > 1 ? parts[1] : '';
    if (decimals.length > fractionDigits) {
      return { valid: false, minorUnits: 0, error: `金额最多支持 ${fractionDigits} 位小数` };
    }
    let paddedDecimals = decimals;
    while (paddedDecimals.length < fractionDigits) {
      paddedDecimals += '0';
    }
    const digits = `${whole}${paddedDecimals}`.replace(/^0+(?=\d)/, '');
    const minorUnits = Number(digits);
    if (!Number.isSafeInteger(minorUnits)) {
      return { valid: false, minorUnits: 0, error: '金额过大，无法安全写入账本' };
    }
    if (minorUnits <= 0) {
      return { valid: false, minorUnits: 0, error: '金额换算后必须大于 0' };
    }
    return { valid: true, minorUnits: minorUnits, error: '' };
  }

  static prepare(plan: ConfirmedTransactionPlan): PreparedTransactionPlan {
    const invalid = (error: string): PreparedTransactionPlan => ({
      valid: false,
      error: error,
      type: '',
      amountMinor: 0,
      accountId: 0,
      date: 0,
      currency: '',
      fractionDigits: 0,
      categoryId: -1,
      comment: ''
    });
    if (plan.schema !== CONFIRMED_TRANSACTION_SCHEMA) {
      return invalid('执行计划未经过当前版本的结构化预览确认');
    }
    const keys: string[] = Object.keys(plan.fields);
    for (let key of keys) {
      if (!AiExecutionPlan.isKnownField(key)) {
        return invalid(`执行计划包含未知字段「${key}」`);
      }
    }

    const type = plan.fields['type'];
    const amountMajor = plan.fields['amountMajor'];
    const accountId = plan.fields['accountId'];
    const date = plan.fields['date'];
    const currency = plan.fields['currency'];
    const fractionDigits = plan.fields['fractionDigits'];
    const categoryId = plan.fields['categoryId'];
    const comment = plan.fields['comment'];
    if (type !== 'expense' && type !== 'income') {
      return invalid('执行计划必须明确收入或支出类型');
    }
    if (typeof amountMajor !== 'string') {
      return invalid('执行计划缺少精确金额');
    }
    if (typeof accountId !== 'number' || !Number.isSafeInteger(accountId) || accountId <= 0) {
      return invalid('执行计划缺少有效的精确账户');
    }
    if (typeof date !== 'number' || !Number.isSafeInteger(date) || date <= 0) {
      return invalid('执行计划缺少有效日期');
    }
    if (typeof currency !== 'string' || currency.trim().length === 0) {
      return invalid('执行计划缺少账户币种');
    }
    if (typeof fractionDigits !== 'number' || !Number.isInteger(fractionDigits)) {
      return invalid('执行计划缺少币种小数位');
    }
    if (typeof categoryId !== 'number' || !Number.isSafeInteger(categoryId) || categoryId < -1) {
      return invalid('执行计划的分类无效');
    }
    if (typeof comment !== 'string' || comment.length > 500) {
      return invalid('执行计划的备注无效');
    }

    const conversion = AiExecutionPlan.convertMajorToMinor(amountMajor, fractionDigits);
    if (!conversion.valid) {
      return invalid(conversion.error);
    }
    return {
      valid: true,
      error: '',
      type: type,
      amountMinor: conversion.minorUnits,
      accountId: accountId,
      date: date,
      currency: currency,
      fractionDigits: fractionDigits,
      categoryId: categoryId,
      comment: comment
    };
  }

  private static isKnownField(key: string): boolean {
    return key === 'type' || key === 'amountMajor' || key === 'accountId' || key === 'date' ||
      key === 'currency' || key === 'fractionDigits' || key === 'categoryId' || key === 'comment';
  }
}
