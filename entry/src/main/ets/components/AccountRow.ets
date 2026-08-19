import { Account } from '../model/Account';
import { intToColor } from '../common/Theme';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { Tag } from '../model/SupportEntities';

/**
 * 账户行组件：对应 Android AccountCardV2
 * 显示账户指示器（颜色圆/环形进度）、名称、描述、余额、展开汇总
 */
@Component
export struct AccountRow {
  // @Prop 建立单向响应式：父组件更新 accounts 后本组件立即重渲染
  @Prop account: Account = new Account();
  @Prop selected: boolean = false;
  @Prop expanded: boolean = false;
  @Prop showEquivalent: boolean = false;
  @Prop accountFlags: Tag[] = [];
  onToggle: (id: number) => void = () => {
  };
  onNavigate: (id: number) => void = () => {
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
  // 动态汇率开关（对齐安卓 DYNAMIC_EXCHANGE_RATE：仅外币账户显示）
  onToggleDynamicExchangeRate: (id: number) => void = () => {
  };

  private accountColor(): string {
    return intToColor(this.account.color);
  }

  private fractionDigits(): number {
    return currencyByCode(this.account.currency).fractionDigits;
  }

  private symbol(): string {
    return currencyByCode(this.account.currency).symbol;
  }

  build() {
    Column() {
      Row() {
        Stack() {
          if (this.account.criterion > 0) {
            Circle()
              .width(40)
              .height(40)
              .fill(Color.Transparent)
              .stroke(this.accountColor())
              .strokeWidth(3)
            Text(this.progressPercent())
              .fontSize(9)
              .fontColor(this.accountColor())
          } else {
            Circle()
              .width(40)
              .height(40)
              .fill(this.accountColor())
          }
        }
        .width(44)
        .height(44)

        // 名称与描述
        Column() {
          Row() {
            Text(this.account.label)
              .fontSize(17)
              .fontColor($r('app.color.textPrimary'))
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.account.sealed) {
              Image($r('app.media.ic_locked'))
                .width(14)
                .height(14)
                .fillColor($r('app.color.textSecondary'))
                .margin({ left: 4 })
            }
            if (this.account.excludeFromTotals) {
              Image($r('app.media.ic_exclude'))
                .width(14)
                .height(14)
                .fillColor($r('app.color.textSecondary'))
                .margin({ left: 4 })
            }
          }
          .width('100%')

          if (this.account.description.length > 0) {
            Text(this.account.description)
              .fontSize(13)
              .fontColor($r('app.color.textSecondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12, right: 10 })

        // 余额
        Column() {
          Text(`${this.symbol()}${formatMoney(this.account.currentBalance, this.fractionDigits())}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.balanceColor())
            .maxLines(1)
          if (this.showEquivalent && this.account.currency !== 'CNY') {
            Text(`≈ ${formatMoney(this.account.equivalentCurrentBalance, 2)}`)
              .fontSize(11)
              .fontColor($r('app.color.textSecondary'))
          }
        }
        .alignItems(HorizontalAlign.End)

        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_right'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.iconSecondary'))
        }
          .type(ButtonType.Circle)
          .width($r('app.float.native_touch_target'))
          .height($r('app.float.native_touch_target'))
          .backgroundColor(Color.Transparent)
          .stateEffect(true)
          .accessibilityText(`查看${this.account.label}的交易`)
          .onClick(() => {
            this.onNavigate(this.account.id);
          })
      }
      .width('100%')
      .height(68)
      .padding({ left: 14, right: 8 })
      .onClick(() => {
        this.onToggle(this.account.id);
      })

      // 展开的汇总
      if (this.expanded) {
        Column({ space: 4 }) {
          this.sumRow('起始余额', formatMoney(this.account.openingBalance, this.fractionDigits()))
          if (this.account.sumIncome !== 0) {
            this.sumRow('收入', formatMoney(this.account.sumIncome, this.fractionDigits()), $r('app.color.colorIncome'))
          }
          if (this.account.sumExpense !== 0) {
            this.sumRow('支出', formatMoney(this.account.sumExpense, this.fractionDigits()), $r('app.color.colorExpense'))
          }
          if (this.account.sumTransfer !== 0) {
            this.sumRow('转账', formatMoney(this.account.sumTransfer, this.fractionDigits()), $r('app.color.colorTransfer'))
          }
          Divider()
            .color($r('app.color.dividerColor'))
            .strokeWidth(1)
          this.sumRow('当前余额', formatMoney(this.account.currentBalance, this.fractionDigits()), this.balanceColor(), true)

          // 操作按钮行（对齐安卓账户操作）
          // 关闭账户后隐藏"编辑"（对齐安卓 accountMenu: if (!account.sealed) { add(edit) }，
          // sealed 账户不可编辑，需先解除关闭再编辑）
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.End }) {
            if (!this.account.sealed) {
              this.accountAction('edit', '编辑', $r('app.color.primaryColor'), '编辑账户')
            }
            this.accountFlagAction()
            this.accountAction(
              'toggleExclude',
              this.account.excludeFromTotals ? '计入总数' : '不计入总数',
              $r('app.color.primaryColor'),
              this.account.excludeFromTotals ? '将账户计入总数' : '将账户移出总数'
            )
            this.accountAction(
              'toggleSealed',
              this.account.sealed ? '解除关闭' : '关闭账户',
              $r('app.color.textTertiary'),
              this.account.sealed ? '重新打开账户' : '关闭账户'
            )
            // 动态汇率（对齐安卓 DYNAMIC_EXCHANGE_RATE：仅外币账户显示）
            if (this.account.currency !== 'CNY') {
              this.accountAction(
                'toggleDynamic',
                this.account.dynamic ? '动态汇率：开' : '动态汇率：关',
                $r('app.color.primaryColor'),
                '切换动态汇率'
              )
            }
            this.accountAction('delete', '删除', $r('app.color.colorExpense'), '删除账户', true)
          }
          .width('100%')
          .margin({ top: 6 })
        }
        .padding({ left: 70, right: 16, bottom: 14 })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .backgroundColor(this.selected ? $r('app.color.surfaceBrandSoft') : $r('app.color.surfacePrimary'))
    .borderRadius($r('app.float.native_card_radius'))
    .margin({ left: 12, right: 12, bottom: 8 })
  }

  // FIX-050: 重构 accountAction 去除函数参数（ArkTS @Builder 函数参数在条件渲染中
  // 存在调用不稳定问题），改为 action 标识符在 Builder 内部直接调用 this.onXxx 回调，
  // 确保 onClick 闭包正确绑定组件实例（修复 BUG-029 点击账户无法锁定）
  @Builder
  accountAction(action: string, label: string, color: ResourceColor, accessibilityLabel: string,
    destructive: boolean = false) {
    Button(label)
      .height($r('app.float.native_touch_target'))
      .padding({ left: 10, right: 10 })
      .margin({ right: 4, bottom: 4 })
      .borderRadius(20)
      .backgroundColor(destructive ? $r('app.color.surfaceExpenseSoft') : Color.Transparent)
      .fontSize(13)
      .fontColor(color)
      .stateEffect(true)
      .accessibilityText(accessibilityLabel)
      .onClick(() => {
        switch (action) {
          case 'edit':
            this.onEdit(this.account.id);
            break;
          case 'delete':
            this.onDelete(this.account.id);
            break;
          case 'toggleSealed':
            this.onToggleSealed(this.account.id);
            break;
          case 'toggleExclude':
            this.onToggleExclude(this.account.id);
            break;
          case 'toggleDynamic':
            this.onToggleDynamicExchangeRate(this.account.id);
            break;
          default:
            break;
        }
      })
  }

  @Builder
  accountFlagAction() {
    if (this.accountFlags.length > 0) {
      Button('标记')
        .height($r('app.float.native_touch_target'))
        .padding({ left: 12, right: 12 })
        .margin({ left: 4, bottom: 4 })
        .fontSize(13)
        .fontColor($r('app.color.primaryColor'))
        .backgroundColor($r('app.color.surfaceSecondary'))
        .borderRadius(14)
        .stateEffect(true)
        .accessibilityText('设置账户标记')
        .bindMenu(this.accountFlagMenu())
    } else {
      Button('标记')
        .height($r('app.float.native_touch_target'))
        .padding({ left: 12, right: 12 })
        .margin({ left: 4, bottom: 4 })
        .fontSize(13)
        .fontColor($r('app.color.textTertiary'))
        .backgroundColor($r('app.color.surfaceSecondary'))
        .borderRadius(14)
        .stateEffect(true)
        .accessibilityText('暂无可用账户标记')
    }
  }

  private accountFlagMenu(): Array<MenuElement> {
    const menu: Array<MenuElement> = [];
    for (let flag of this.accountFlags) {
      menu.push({
        value: (this.account.flagId === flag.id ? '✓ ' : '') + flag.label,
        action: () => this.onApplyFlag(this.account.id, flag.id)
      } as MenuElement);
    }
    return menu;
  }

  @Builder
  sumRow(label: string, value: string, color: ResourceColor = $r('app.color.textPrimary'), bold: boolean = false) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
      Blank()
      Text(value)
        .fontSize(13)
        .fontColor(color)
        .fontWeight(bold ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
  }

  private balanceColor(): ResourceColor {
    if (this.account.currentBalance > 0) {
      return $r('app.color.colorIncome');
    }
    if (this.account.currentBalance < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  private progressPercent(): string {
    if (this.account.criterion > 0) {
      const progress = Math.min(100, Math.abs(this.account.currentBalance) / this.account.criterion * 100);
      return `${Math.round(progress)}%`;
    }
    return '';
  }
}
