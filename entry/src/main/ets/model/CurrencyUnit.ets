/**
 * 货币单位：对应 Android CurrencyUnit
 */
export class CurrencyUnit {
  code: string = '';
  symbol: string = '';
  label: string = '';
  fractionDigits: number = 2;

  constructor(code: string = '', symbol: string = '', label: string = '', fractionDigits: number = 2) {
    this.code = code;
    this.symbol = symbol;
    this.label = label;
    this.fractionDigits = fractionDigits;
  }

  static CNY(): CurrencyUnit {
    return new CurrencyUnit('CNY', '¥', '人民币', 2);
  }

  static USD(): CurrencyUnit {
    return new CurrencyUnit('USD', '$', '美元', 2);
  }

  static EUR(): CurrencyUnit {
    return new CurrencyUnit('EUR', '€', '欧元', 2);
  }

  static GBP(): CurrencyUnit {
    return new CurrencyUnit('GBP', '£', '英镑', 2);
  }

  static JPY(): CurrencyUnit {
    return new CurrencyUnit('JPY', '¥', '日元', 0);
  }
}

/**
 * 常用货币列表
 */
export const COMMON_CURRENCIES: CurrencyUnit[] = [
  CurrencyUnit.CNY(),
  CurrencyUnit.USD(),
  CurrencyUnit.EUR(),
  CurrencyUnit.GBP(),
  CurrencyUnit.JPY()
];

/**
 * 按代码查找货币
 */
export function currencyByCode(code: string): CurrencyUnit {
  for (let c of COMMON_CURRENCIES) {
    if (c.code === code) {
      return c;
    }
  }
  return new CurrencyUnit(code, code, code, 2);
}