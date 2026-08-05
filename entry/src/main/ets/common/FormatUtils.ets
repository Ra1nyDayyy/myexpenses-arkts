import { formatMoney } from '../model/Money';

/**
 * 日期工具
 */
export function formatDate(epochSeconds: number): string {
  const d = new Date(epochSeconds * 1000);
  const y = d.getFullYear();
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function formatDateTime(epochSeconds: number): string {
  const d = new Date(epochSeconds * 1000);
  const h = d.getHours().toString().padStart(2, '0');
  const min = d.getMinutes().toString().padStart(2, '0');
  return `${formatDate(epochSeconds)} ${h}:${min}`;
}

export function formatTime(epochSeconds: number): string {
  const d = new Date(epochSeconds * 1000);
  const h = d.getHours().toString().padStart(2, '0');
  const min = d.getMinutes().toString().padStart(2, '0');
  return `${h}:${min}`;
}

/**
 * 生成 UUID
 */
export function generateUuid(): string {
  const s: string[] = [];
  const hex = '0123456789abcdef';
  for (let i = 0; i < 36; i++) {
    if (i === 8 || i === 13 || i === 18 || i === 23) {
      s.push('-');
    } else if (i === 14) {
      s.push('4');
    } else if (i === 19) {
      const randomNibble = (Math.random() * 4 | 0) + 8;
      s.push(hex.charAt(randomNibble));
    } else {
      const randomNibble = Math.random() * 16 | 0;
      s.push(hex.charAt(randomNibble));
    }
  }
  return s.join('');
}

export function formatMoneyWithCurrency(amountMinor: number, fractionDigits: number, symbol: string): string {
  const formatted = formatMoney(amountMinor, fractionDigits);
  return symbol ? `${symbol}${formatted}` : formatted;
}