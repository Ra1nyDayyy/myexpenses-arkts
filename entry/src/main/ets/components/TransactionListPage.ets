import { Transaction, CrStatus } from '../model/Transaction';
import { Account, AccountGrouping } from '../model/Account';
import { TransactionRow } from './TransactionRow';
import { EmptyState } from './EmptyState';

import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';

/**
 * 交易列表组件：对应 Android TransactionList
 * 分组头（sticky）+ 交易行
 */
@Component
export struct TransactionListPage {
  // 父组件切换所选账户时会整体重新赋值（@State currentTransactions），
  // 必须用 @Prop 建立单向响应式同步，否则子组件不会随账户切换重渲染
  @Prop account: Account = new Account();
  @Prop transactions: Transaction[] = [];
  @Prop grouping: number = 0; // 0 none 1 day 2 week 3 month 4 year
  @Prop showSumDetails: boolean = false;
  // 多选模式（@Link 确保 List 懒加载场景下同步刷新，@Prop 不随父组件状态更新）
  @Link selectionMode: boolean;
  // 选中交易 id 列表（@Prop 使 ListItem 重建时同步选中态）
  @Prop selectedIds: number[] = [];
  // 聚合模式（全部账户累计）：交易行显示所属账户名
  @Prop showAccount: boolean = false;
  onToggleStatus: (id: number) => void = () => {
  };
  onClickTransaction: (id: number) => void = () => {
  };
  // 长按交易行：进入多选模式并选中该项（对齐安卓 startMyActionMode 长按）
  onLongPressTransaction: (id: number) => void = () => {
  };
  onMenuAction: (id: number, action: string) => void = () => {
  };
  onCreateTransaction: () => void = () => {
  };

  /**
   * 构建交易行操作菜单项（详情/编辑/删除），action 通过回调交由父页面处理
   */
  private menuItemsFor(t: Transaction): Array<MenuElement> {
    return [
      { value: '详细信息', action: () => { this.onMenuAction(t.id, 'detail'); } },
      { value: '编辑', action: () => { this.onMenuAction(t.id, 'edit'); } },
      { value: '删除', action: () => { this.onMenuAction(t.id, 'delete'); } }
    ];
  }

  private fractionDigits(): number {
    return currencyByCode(this.account.currency).fractionDigits;
  }

  private symbol(): string {
    return currencyByCode(this.account.currency).symbol;
  }

  private groupKey(t: Transaction): string {
    const d = new Date(t.date * 1000);
    switch (this.grouping) {
      case 1: // 日
        return formatDate(t.date);
      case 2: // 周
        const weekStart = new Date(d);
        weekStart.setDate(d.getDate() - d.getDay() + (d.getDay() === 0 ? -6 : 1));
        return `${weekStart.getFullYear()}-W${this.weekNumber(d)}`;
      case 4: // 年
        return `${d.getFullYear()}年`;
      case 3: // 月
      default:
        return `${d.getFullYear()}年${d.getMonth() + 1}月`;
    }
  }

  private weekNumber(d: Date): number {
    const firstDay = new Date(d.getFullYear(), 0, 1);
    const pastDays = (d.getTime() - firstDay.getTime()) / 86400000;
    return Math.ceil((pastDays + firstDay.getDay() + 1) / 7);
  }

  private grouped(): Map<string, Transaction[]> {
    const map = new Map<string, Transaction[]>();
    for (let t of this.transactions) {
      const key = this.groupKey(t);
      let list = map.get(key);
      if (!list) {
        list = [];
        map.set(key, list);
      }
      list.push(t);
    }
    return map;
  }

  private groupSum(list: Transaction[]): number {
    let sum = 0;
    for (let t of list) {
      sum += t.amount;
    }
    return sum;
  }

  build() {
    Column() {
      if (this.transactions.length === 0) {
        EmptyState({
          iconResource: $r('app.media.ic_expense'),
          title: '还没有交易',
          subtitle: '新增一笔收支后，交易记录会显示在这里'
        })
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 0 }) {
          ForEach(Array.from(this.grouped().keys()), (groupKey: string) => {
            // ListItemGroup：分组头自动 sticky 吸顶（鸿蒙原生）
            ListItemGroup({ header: this.groupHeader(groupKey) }) {
              // 交易行
              ForEach(this.grouped().get(groupKey)!, (t: Transaction) => {
                ListItem() {
                  TransactionRow({
                    transaction: t,
                    selected: this.selectedIds.indexOf(t.id) >= 0,
                    showAccount: this.showAccount,
                    selectionMode: $selectionMode,
                    // 选择模式不弹操作菜单（点击用于多选）
                    menuItems: this.selectionMode ? [] : this.menuItemsFor(t),
                    onToggleStatus: (id: number) => {
                      this.onToggleStatus(id);
                    },
                    onItemLongPress: (id: number) => {
                      this.onLongPressTransaction(id);
                    },
                    onItemClick: (id: number) => {
                      this.onClickTransaction(id);
                    }
                  })
                }
              }, (t: Transaction) => `trans_${t.id}_${this.selectionMode ? 'S' : 'N'}_${this.selectedIds.indexOf(t.id) >= 0 ? '1' : '0'}`)
            }
          }, (groupKey: string) => `header_${groupKey}`)
        }
        .layoutWeight(1)
        .width('100%')
        .sticky(StickyStyle.Header)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  @Builder
  groupHeader(groupKey: string) {
    Row() {
      Text(groupKey)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
      Blank()
      Text(this.groupSumLabel(this.grouped().get(groupKey)!))
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.surfaceSecondary'))
    .alignItems(VerticalAlign.Center)
  }

  private groupSumLabel(list: Transaction[]): string {
    const sum = this.groupSum(list);
    const prefix = sum > 0 ? '+' : '';
    return `${prefix}${this.symbol()}${formatMoney(sum, this.fractionDigits())}`;
  }
}
