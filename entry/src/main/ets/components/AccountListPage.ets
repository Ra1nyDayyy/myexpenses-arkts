import { Account, AccountGrouping } from '../model/Account';
import { Repository } from '../database/Repository';
import { AccountRow } from './AccountRow';
import { EmptyState } from './EmptyState';
import { intToColor } from '../common/Theme';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';

/**
 * 账户列表组件：对应 Android AccountList
 * 用于主界面抽屉
 */
@Component
export struct AccountListPage {
  accounts: Account[] = [];
  @Prop grouping: AccountGrouping = AccountGrouping.NONE;
  @Prop selectedAccountId: number = -1;
  @Prop showEquivalent: boolean = false;
  onSelect: (id: number) => void = () => {
  };
  onEdit: (id: number) => void = () => {
  };
  onDelete: (id: number) => void = () => {
  };
  onToggleSealed: (id: number) => void = () => {
  };
  onToggleExclude: (id: number) => void = () => {
  };
  onCreateAccount: () => void = () => {
  };
  onReorder: (from: number, to: number) => void = () => {
  };
  @State expandedId: number = -1;
  @State dragEditMode: boolean = false;

  /**
   * 长按任一账户行进入拖拽排序模式（对齐安卓 ItemTouchHelper）
   */
  private enableDrag(): void {
    this.dragEditMode = true;
  }

  private groups(): Map<string, Account[]> {
    const map = new Map<string, Account[]>();
    for (let acc of this.accounts) {
      let key = '';
      switch (this.grouping) {
        case AccountGrouping.TYPE:
          key = Account.typeName(acc.type);
          break;
        case AccountGrouping.CURRENCY:
          key = acc.currency;
          break;
        default:
          key = '所有账户';
      }
      let list = map.get(key);
      if (!list) {
        list = [];
        map.set(key, list);
      }
      list.push(acc);
    }
    return map;
  }

  private groupSum(list: Account[]): number {
    let sum = 0;
    for (let acc of list) {
      if (!acc.excludeFromTotals) {
        sum += acc.currentBalance;
      }
    }
    return sum;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('管理账户')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
        Blank()
        Image($r('sys.media.ohos_ic_public_add'))
          .width(20)
          .height(20)
          .onClick(() => {
            this.onCreateAccount();
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      if (this.accounts.length === 0) {
        EmptyState({
          iconResource: $r('app.media.ic_empty_account'),
          title: '没有账户。',
          subtitle: '创建第一个账户开始记账',
          actionText: '新建账户',
          onAction: () => {
            this.onCreateAccount();
          }
        })
        .width('100%')
        .layoutWeight(1)
      } else if (this.grouping === AccountGrouping.NONE && this.groupSingle()) {
        // 扁平 List：支持拖拽排序（对齐安卓 ItemTouchHelper）
        List({ space: 0 }) {
          ForEach(this.accounts, (acc: Account) => {
            ListItem() {
              AccountRow({
                account: acc,
                selected: acc.id === this.selectedAccountId,
                expanded: acc.id === this.expandedId,
                showEquivalent: this.showEquivalent,
                onToggle: (id: number) => {
                  animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
                    this.expandedId = this.expandedId === id ? -1 : id;
                  });
                },
                onNavigate: (id: number) => {
                  this.onSelect(id);
                },
                onEdit: (id: number) => {
                  this.onEdit(id);
                },
                onDelete: (id: number) => {
                  this.onDelete(id);
                },
                onToggleSealed: (id: number) => {
                  this.onToggleSealed(id);
                },
                onToggleExclude: (id: number) => {
                  this.onToggleExclude(id);
                }
              })
            }
          }, (acc: Account) => `account_${acc.id}`)
        }
        .layoutWeight(1)
        .width('100%')
        .editMode(this.dragEditMode)
        .onItemMove((from: number, to: number) => {
          this.onReorder(from, to);
          return true;
        })
      } else {
        List({ space: 0 }) {
          // 分组渲染
          ForEach(Array.from(this.groups().keys()), (groupKey: string) => {
            ListItem() {
              Column() {
                // 组头
                Row() {
                  Text(groupKey)
                    .fontSize(13)
                    .fontColor($r('app.color.textSecondary'))
                    .fontWeight(FontWeight.Medium)
                  Blank()
                  Text(this.groupSumLabel(this.groups().get(groupKey)!))
                    .fontSize(13)
                    .fontColor($r('app.color.textSecondary'))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 6 })

                ForEach(this.groups().get(groupKey)!, (acc: Account) => {
                  AccountRow({
                    account: acc,
                    selected: acc.id === this.selectedAccountId,
                    expanded: acc.id === this.expandedId,
                    showEquivalent: this.showEquivalent,
                    onToggle: (id: number) => {
                      animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
                        this.expandedId = this.expandedId === id ? -1 : id;
                      });
                    },
                    onNavigate: (id: number) => {
                      this.onSelect(id);
                    },
                    onEdit: (id: number) => {
                      this.onEdit(id);
                    },
                    onDelete: (id: number) => {
                      this.onDelete(id);
                    },
                    onToggleSealed: (id: number) => {
                      this.onToggleSealed(id);
                    },
                    onToggleExclude: (id: number) => {
                      this.onToggleExclude(id);
                    }
                  })
                }, (acc: Account) => `account_${acc.id}`)

                Divider()
                  .color($r('app.color.dividerColor'))
                  .strokeWidth(0.5)
              }
            }
          }, (groupKey: string) => `group_${groupKey}`)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.drawerBackground'))
  }

  private groupSingle(): boolean {
    return this.groups().size <= 1;
  }

  private groupSumLabel(list: Account[]): string {
    let sum = 0;
    for (let acc of list) {
      if (!acc.excludeFromTotals) {
        sum += acc.currentBalance;
      }
    }
    const symbol = list.length > 0 ? currencyByCode(list[0].currency).symbol : '¥';
    return `${symbol}${formatMoney(sum, 2)}`;
  }
}