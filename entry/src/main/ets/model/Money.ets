import { CurrencyUnit } from './CurrencyUnit';

/**
 * 金额：以最小货币单位存储（如分），对应 Android Money
 */
export class Money {
  currency: CurrencyUnit;
  amountMinor: number = 0;

  constructor(currency: CurrencyUnit, amountMinor: number = 0) {
    this.currency = currency;
    this.amountMinor = amountMinor;
  }

  negate(): Money {
    return new Money(this.currency, -this.amountMinor);
  }

  absolute(): Money {
    return this.amountMinor < 0 ? this.negate() : new Money(this.currency, this.amountMinor);
  }

  isNegative(): boolean {
    return this.amountMinor < 0;
  }

  isZero(): boolean {
    return this.amountMinor === 0;
  }

  /**
   * 显示字符串：如 12.34
   */
  getDisplayString(): string {
    return formatMoney(this.amountMinor, this.currency.fractionDigits);
  }

  /**
   * 显示字符串带符号：+12.34 / -12.34
   */
  getSignedDisplayString(): string {
    if (this.amountMinor > 0) {
      return '+' + this.getDisplayString();
    }
    return this.getDisplayString();
  }
}

/**
 * 格式化金额为字符串
 * @param amountMinor 最小货币单位金额
 * @param fractionDigits 小数位
 */
export function formatMoney(amountMinor: number, fractionDigits: number = 2): string {
  const sign = amountMinor < 0 ? '-' : '';
  const abs = Math.abs(amountMinor);
  const factor = Math.pow(10, fractionDigits);
  const major = Math.floor(abs / factor);
  let minor = (abs % factor).toString();
  while (minor.length < fractionDigits) {
    minor = '0' + minor;
  }
  if (fractionDigits <= 0) {
    return sign + major.toString();
  }
  return sign + major.toString() + '.' + minor;
}

/**
 * 从用户输入字符串解析金额到最小单位
 */
export function parseMoney(input: string, fractionDigits: number = 2): number {
  let text = input.replace(/[,\s]/g, '');
  if (!text) {
    return 0;
  }
  let negative = false;
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1);
  } else if (text.startsWith('+')) {
    text = text.substring(1);
  }
  const factor = Math.pow(10, fractionDigits);
  const value = parseFloat(text);
  if (isNaN(value)) {
    return 0;
  }
  const minor = Math.round(value * factor);
  return negative ? -minor : minor;
}