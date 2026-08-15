/**
 * 页面内展开状态的纯函数约束。
 * 只计算下一显示状态，不持久化，也不触发业务回调。
 */
export class InlineExpansionState {
  static toggle(current: boolean): boolean {
    return !current;
  }

  static toggleExclusive(currentId: number, targetId: number): number {
    return currentId === targetId ? -1 : targetId;
  }
}
