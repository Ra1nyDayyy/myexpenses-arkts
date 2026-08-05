/**
 * 主题与常量工具
 */

// 金额颜色规则（与 Android 一致，通过资源引用）
export const COLOR_INCOME = $r('app.color.colorIncome');
export const COLOR_EXPENSE = $r('app.color.colorExpense');
export const COLOR_TRANSFER = $r('app.color.colorTransfer');

// 账户默认颜色（0xAARRGGBB）
export const DEFAULT_ACCOUNT_COLOR = 0xFFC107;
export const COLOR_AGGREGATE = $r('app.color.colorAggregate');

// 状态色
export const STATUS_UNRECONCILED = $r('app.color.UNRECONCILED');
export const STATUS_CLEARED = $r('app.color.CLEARED');
export const STATUS_RECONCILED = $r('app.color.RECONCILED');
export const STATUS_VOID = $r('app.color.VOID');

export const DRAWER_BACKGROUND = $r('app.color.drawerBackground');
export const CARD_BACKGROUND = $r('app.color.cardBackground');
export const ACTIVATED_BACKGROUND = $r('app.color.activatedBackground');
export const FUTURE_BACKGROUND = $r('app.color.futureBackground');

// Android Material3 浅色 surface 背景色（DynamicColors 采样 #FAF8FE）
export const SURFACE_BACKGROUND = '#FAF8FE';

/**
 * 根据金额符号返回颜色
 */
export function amountColor(amount: number): ResourceColor {
  if (amount > 0) {
    return COLOR_INCOME;
  }
  if (amount < 0) {
    return COLOR_EXPENSE;
  }
  return '#808080';
}

/**
 * 根据交易类型返回颜色
 * type: -1 支出 / 1 收入 / 0 中性
 */
export function typeColor(type: number): ResourceColor {
  if (type === 1) {
    return COLOR_INCOME;
  }
  if (type === -1) {
    return COLOR_EXPENSE;
  }
  return '#808080';
}

/**
 * ARGB int 转 #RRGGBB
 */
export function intToColor(argb: number): string {
  const rgb = argb & 0xFFFFFF;
  return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
}