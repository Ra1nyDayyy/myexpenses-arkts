import { Account, AccountGrouping, AccountType } from '../model/Account';
import { Repository } from '../database/Repository';
import { AccountRow } from './AccountRow';
import { EmptyState } from './EmptyState';
import { intToColor } from '../common/Theme';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { Tag } from '../model/SupportEntities';

/**
 * 账户列表组件：对应 Android AccountList
 * 用于主界面抽屉
 */
@Component
export struct AccountListPage {
  // @Prop 单向响应式：父组件（Index）更新 accounts 后本组件立即重渲染
  @Prop accounts: Account[] = [];
  @Prop grouping: AccountGrouping = AccountGrouping.NONE;
  @Prop selectedAccountId: number = -1;
  @Prop showEquivalent: boolean = false;
  @Prop accountFlags: Tag[] = [];
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
  onApplyFlag: (id: number, flagId: number) => void = () => {
  };
  // 动态汇率开关回调（透传给 AccountRow）
  onToggleDynamicExchangeRate: (id: number) => void = () => {
  };
  onCreateAccount: () => void = () => {
  };
  onReorder: (from: number, to: number) => void = () => {
  };
  // 点击"累计"行跳转到交易页全部账户聚合视图（对齐安卓 onGroupSelected(null)）
  onGrandTotal: () => void = () => {
  };
  // 点击分组头箭头跳转到交易页该账户类型（对齐安卓 onGroupSelected(groupKey)）
  onGroupSelected: (type: AccountType) => void = () => {
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
        case AccountGrouping.NONE:
          // 账户列表默认按类型分组（对齐安卓 AccountGrouping.TYPE）
          key = `${Account.typeName(acc.type)} (Σ)`;
          break;
        case AccountGrouping.CURRENCY:
          key = `${acc.currency} (Σ)`;
          break;
        case AccountGrouping.FLAG:
          key = `${acc.flagLabel} (Σ)`;
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

  /**
   * 全部账户合计（排除不计入总数的账户），对齐安卓 equivalentEffectiveBalance 总计
   */
  private grandTotal(): number {
    let sum = 0;
    for (let acc of this.accounts) {
      if (!acc.excludeFromTotals) {
        sum += acc.currentBalance;
      }
    }
    return sum;
  }

  private grandTotalLabel(): string {
    const symbol = this.accounts.length > 0 ? currencyByCode(this.accounts[0].currency).symbol : '¥';
    return `${symbol}${formatMoney(this.grandTotal(), 2)}`;
  }

  build() {
    Column() {

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
      } else if (this.groupSingle()) {
        // 单分组时用扁平 List（支持拖拽排序）
        // 顶部显示"累计"加粗行（对齐安卓 grand total，放 List 外避免影响拖拽索引）
        Column() {
          this.grandTotalHeader()
          List({ space: 0 }) {
            ForEach(this.accounts, (acc: Account) => {
              ListItem() {
                AccountRow({
                  account: acc,
                  selected: acc.id === this.selectedAccountId,
                  expanded: acc.id === this.expandedId,
                  showEquivalent: this.showEquivalent,
                  accountFlags: this.accountFlags,
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
                  },
                  onApplyFlag: (id: number, flagId: number) => {
                    this.onApplyFlag(id, flagId);
                  },
                  onToggleDynamicExchangeRate: (id: number) => {
                    this.onToggleDynamicExchangeRate(id);
                  }
                })
              }
            }, (acc: Account) => `account_${acc.id}_${acc.sealed}_${acc.excludeFromTotals}_${acc.flagId}`)
          }
          .layoutWeight(1)
          .width('100%')
          .editMode(this.dragEditMode)
          .onItemMove((from: number, to: number) => {
            this.onReorder(from, to);
            return true;
          })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 0 }) {
          // 分组渲染
          ForEach(Array.from(this.groups().keys()), (groupKey: string) => {
            ListItem() {
              Column() {
                // 组头
                Row() {
                  Text(groupKey)
                    .fontSize(14)
                    .fontColor($r('app.color.textSecondary'))
                    .fontWeight(FontWeight.Bold)
                  Blank()
                  Text(this.groupSumLabel(this.groups().get(groupKey)!))
                    .fontSize(13)
                    .fontColor($r('app.color.textSecondary'))
                  // 分组下账户超过一个时显示箭头（对齐安卓 HeaderV2 的 ChevronRight：group.size >= 2）
                  // 点击跳转交易页该账户类型（对齐安卓 onGroupSelected(groupKey)）
                  if (this.groups().get(groupKey)!.length > 1) {
                    Image($r('sys.media.ohos_ic_public_arrow_right'))
                      .width(14)
                      .height(14)
                      .objectFit(ImageFit.Contain)
                      .opacity(0.4)
                      .margin({ left: 4 })
                      .onClick(() => {
                        this.onGroupSelected(this.groups().get(groupKey)![0].type);
                      })
                  }
                }
                .width('100%')
                .height(44)
                .padding({ left: 16, right: 16 })

                ForEach(this.groups().get(groupKey)!, (acc: Account) => {
                  AccountRow({
                    account: acc,
                    selected: acc.id === this.selectedAccountId,
                    expanded: acc.id === this.expandedId,
                    showEquivalent: this.showEquivalent,
                    accountFlags: this.accountFlags,
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
                    },
                    onApplyFlag: (id: number, flagId: number) => {
                      this.onApplyFlag(id, flagId);
                    },
                    onToggleDynamicExchangeRate: (id: number) => {
                      this.onToggleDynamicExchangeRate(id);
                    }
                  })
                }, (acc: Account) => `account_${acc.id}_${acc.sealed}_${acc.excludeFromTotals}_${acc.flagId}`)

              }
            }
          }, (groupKey: string) => `group_${groupKey}`)

          // 底部"累计"总计行（对齐安卓 grouped.size > 1 时的 Grand total）
          ListItem() {
            this.grandTotalHeader()
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
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

  /**
   * 累计行：对应安卓 HeaderV2（isGrandTotal = true）
   * 标题加粗，右侧显示全部账户等效余额合计
   * 点击跳转到交易页全部账户累计（对齐安卓 onNavigate = onGroupSelected(null)）
   */
  @Builder
  grandTotalHeader() {
    Row() {
      Text('累计')
        .fontSize(14)
        .fontColor($r('app.color.textSecondary'))
        .fontWeight(FontWeight.Bold)
      Blank()
      Text(this.grandTotalLabel())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
      // 右侧箭头：对齐安卓 HeaderV2 的 ChevronRight IconButton，点击跳转交易页累计
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
        .opacity(0.5)
        .margin({ left: 4 })
        .onClick(() => {
          this.onGrandTotal();
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 12 })
    .margin({ left: 12, right: 12, bottom: 8 })
    .borderRadius($r('app.float.native_card_radius'))
    .backgroundColor($r('app.color.surfaceSecondary'))
    .onClick(() => {
      this.onGrandTotal();
    })
  }
}
