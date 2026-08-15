/**
 * 交易实体：对应 Android db2/entities/Transaction.kt
 */
export enum CrStatus {
  UNRECONCILED = 'UNRECONCILED',
  CLEARED = 'CLEARED',
  RECONCILED = 'RECONCILED',
  VOID = 'VOID'
}

export enum OperationType {
  TRANSACTION = 0,
  TRANSFER = 1,
  SPLIT = 2
}

export class Transaction {
  id: number = 0;
  status: number = 0;
  comment: string = '';
  date: number = 0; // epoch 秒
  valueDate: number = 0;
  amount: number = 0; // 最小货币单位
  categoryId: number = -1;
  accountId: number = -1;
  payeeId: number = -1;
  transferPeerId: number = -1;
  transferAccountId: number = -1;
  methodId: number = -1;
  parentId: number = -1;
  crStatus: CrStatus = CrStatus.UNRECONCILED;
  referenceNumber: string = '';
  originalAmount: number = 0;
  originalCurrency: string = '';
  debtId: number = -1;
  tagIds: number[] = [];
  uuid: string = '';
  // 位置（对齐安卓 Android 交易位置记录）
  latitude: number = 0;
  longitude: number = 0;
  // 展示字段
  categoryPath: string = '';
  payeeName: string = '';
  categoryIcon: string = '';
  methodLabel: string = '';
  accountLabel: string = '';
  currency: string = 'CNY';
  color: number = 0;
  transferAccountLabel: string = '';
  year: number = 0;
  month: number = 0;
  week: number = 0;
  day: number = 0;

  isTransfer(): boolean {
    return this.transferAccountId !== -1;
  }

  isSplit(): boolean {
    return this.categoryId === -2; // SPLIT_CATID
  }

  isSplitPart(): boolean {
    return this.parentId !== -1;
  }

  isIncome(): boolean {
    return this.amount > 0;
  }
}

export const SPLIT_CATID = -2;
export const STATUS_NONE = 0;
export const STATUS_EXPORTED = 1;