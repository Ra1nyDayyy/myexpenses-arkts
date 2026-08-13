/**
 * 复杂搜索页面（对齐安卓 SearchRequest 复杂搜索）
 * - 顶栏：×关闭 + "复杂搜索"标题▼ + ≡条件列表 + ✓确认执行
 * - 5 个搜索条件：金额/备注/状态/日期/账户
 * - 条件设置对话框 + 搜索结果列表
 * - AI 语音输入按钮
 */
import { Transaction, CrStatus } from '../model/Transaction';
import { Repository } from '../database/Repository';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { SearchCriterionDialog } from '../components/SearchCriterionDialog';
import { Account } from '../model/Account';
import { router } from '@kit.ArkUI';

/** 搜索条件接口 */
export interface SearchCriterion {
  type: string;       // amount/comment/status/date/account
  op: string;         // 等于/大于/小于/包含...
  value: string;
  extra?: string;     // 支出/收入等
}

@Entry
@Component
export struct SearchPage {
  @State criteria: SearchCriterion[] = [];
  @State results: Transaction[] = [];
  @State searched: boolean = false;
  /** 搜索模式：0=快速搜索（简单），1=复杂搜索（对齐安卓 preferredSearchType） */
  @State searchType: number = 1;
  private repository: Repository = Repository.getInstance();
  /** 账户列表缓存（账户搜索条件用） */
  @State accountList: Account[] = [];

  aboutToAppear(): void {
    this.repository.getAccounts().then((list: Account[]) => {
      this.accountList = list;
    }).catch(() => {
      this.accountList = [];
    });
  }

  private addCriterion(c: SearchCriterion): void {
    const list = this.criteria.filter((item: SearchCriterion) => item.type !== c.type);
    list.push(c);
    this.criteria = list;
  }

  // ============ 执行搜索 ============
  private async executeSearch(): Promise<void> {
    this.results = await this.repository.searchTransactions(this.criteria);
    this.searched = true;
  }

  // ============ 清除所有筛选条件（对齐安卓 clear_all_filters） ============
  private clearCriteria(): void {
    this.criteria = [];
    this.results = [];
    this.searched = false;
  }

  // ============ 已添加条件 ============
  @Builder
  criteriaList() {
    Column({ space: 8 }) {
      ForEach(this.criteria, (c: SearchCriterion) => {
        Row() {
          Text(this.criterionLabel(c))
            .fontSize(13)
            .fontColor($r('app.color.textPrimary'))
            .layoutWeight(1)
          Text('✕')
            .fontSize(14)
            .fontColor($r('app.color.colorExpense'))
            .onClick(() => {
              this.removeCriterion(c.type);
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.cardBackgroundColor'))
        .borderRadius(8)
      }, (c: SearchCriterion) => `c_${c.type}`)
    }
    .width('100%')
  }

  private criterionLabel(c: SearchCriterion): string {
    const typeLabel = c.type === 'amount' ? '金额' : c.type === 'comment' ? '备注' : c.type === 'status' ? '状态' : c.type === 'date' ? '日期' : '账户';
    let label = `${typeLabel} ${c.op} ${c.value}`;
    if (c.extra) {
      label = `${typeLabel}(${c.extra}) ${c.op} ${c.value}`;
    }
    return label;
  }

  private removeCriterion(type: string): void {
    this.criteria = this.criteria.filter((c: SearchCriterion) => c.type !== type);
  }

  build() {
    Column() {
      // 顶栏（对齐安卓：×关闭 + 标题▼下拉切换模式 + ≡ + ✓确认）
      Row() {
        Text('✕')
          .fontSize(18)
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            router.back();
          })
        Blank()
        // 标题 + 下拉箭头（bindMenu 绑定在自适应小行上，确保菜单从标题正下方弹出对齐）
        Row() {
          Text(this.searchType === 0 ? '快速搜索' : '复杂搜索')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.textPrimary'))
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(14)
            .height(14)
            .margin({ left: 4 })
        }
        .bindMenu(this.searchTypeMenu())
        Blank()
        // 清除所有筛选条件（对齐安卓 Icons.Filled.ClearAll，无条件时禁用）
        Image($r('app.media.ic_clear_all'))
          .width(22)
          .height(22)
          .margin({ right: 16 })
          .fillColor(this.criteria.length > 0 || this.searched ? $r('app.color.textSecondary') : '#33000000')
          .onClick(() => {
            this.clearCriteria();
          })
        // 应用/执行搜索（对齐安卓 ✓）
        Text('✓')
          .fontSize(18)
          .fontColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.executeSearch();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.pageBackground'))

      // 主体（内容从顶部开始，不居中）
      Scroll() {
        Column() {
          // 快速搜索模式：纵向条件列表（对齐安卓：图标+字段+复选框）
          if (this.searchType === 0) {
            this.quickSearchList()
          } else {
            // 复杂搜索模式：条件按钮 + 已添加条件 + 空状态/结果
            this.complexCriteriaButtons()

            if (this.criteria.length > 0) {
              this.criteriaList()
            }

            // 空状态 / 结果列表
            if (!this.searched && this.criteria.length === 0) {
              Column() {
                Text('尚未添加任何条件')
                  .fontSize(15)
                  .fontColor($r('app.color.textSecondary'))
                Text('点击上方按钮定义查询条件')
                  .fontSize(13)
                  .fontColor($r('app.color.textTertiary'))
                  .margin({ top: 6 })
              }
              .width('100%')
              .height(160)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else if (this.searched) {
              this.resultList()
            }
          }
        }
        .width('100%')
        .padding(16)
      }
      .align(Alignment.TopStart)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  /** 搜索模式切换菜单（对齐安卓：快速搜索/复杂搜索 就近展开） */
  private searchTypeMenu(): Array<MenuElement> {
    return [
      {
        value: (this.searchType === 0 ? '✓ ' : '') + '快速搜索',
        action: () => {
          this.searchType = 0;
        }
      } as MenuElement,
      {
        value: (this.searchType === 1 ? '✓ ' : '') + '复杂搜索',
        action: () => {
          this.searchType = 1;
        }
      } as MenuElement
    ];
  }

  /** 快速搜索纵向列表（对齐安卓：图标+字段名+复选框） */
  @Builder
  quickSearchList() {
    Column() {
      this.quickRow('金额', $r('app.media.ic_amount'), 'amount')
      this.quickRow('备注', $r('app.media.ic_comment'), 'comment')
      this.quickRow('状态', $r('app.media.ic_status'), 'status')
      this.quickRow('日期', $r('app.media.ic_date'), 'date')
      this.quickRow('账户', $r('app.media.ic_account_balance'), 'account')
    }
    .width('100%')
  }

  /** 复杂搜索条件按钮（对齐安卓：一行水平排列 + 图标文字扁平样式，悬浮在内容上方） */
  @Builder
  complexCriteriaButtons() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 悬浮条件工具栏（对齐安卓：紧贴顶栏下方、一行完整展示）
      Row({ space: 18 }) {
        this.criterionChip('金额', $r('app.media.ic_amount'), 'amount')
        this.criterionChip('备注', $r('app.media.ic_comment'), 'comment')
        this.criterionChip('状态', $r('app.media.ic_status'), 'status')
        this.criterionChip('日期', $r('app.media.ic_date'), 'date')
        this.criterionChip('账户', $r('app.media.ic_account_balance'), 'account')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 12, right: 12 })
      .height(44)
    }
    .width('100%')
    .padding({ bottom: 8 })
  }

  @Builder
  criterionChip(label: string, icon: Resource, type: string) {
    Row({ space: 4 }) {
      Image(icon)
        .width(16)
        .height(16)
        .fillColor($r('app.color.primaryColor'))
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.primaryColor'))
    }
    .height(40)
    .onClick(() => {
      this.showCriterionDialog(type);
    })
  }

  /** 打开复杂搜索条件设置对话框（对齐安卓 SearchRequest 条件对话框） */
  private showCriterionDialog(type: string): void {
    const dialog = new CustomDialogController({
      builder: SearchCriterionDialog({
        criterionType: type,
        accountList: this.accountList,
        onResult: (op: string, value: string, extra?: string) => {
          this.addCriterion({ type: type, op: op, value: value, extra: extra });
        },
        onClose: () => {
          dialog.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      cornerRadius: 16
    });
    dialog.open();
  }

  @Builder
  quickRow(label: string, icon: Resource, type: string) {
    Row() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor($r('app.color.textSecondary'))
        .margin({ right: 12 })
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.textPrimary'))
        .layoutWeight(1)
      Checkbox({ name: `quick_${type}` })
        .select(this.criteria.some((c: SearchCriterion) => c.type === type))
        .selectedColor($r('app.color.primaryColor'))
        .onChange((checked: boolean) => {
          if (checked) {
            this.showQuickCriteriaDialog(type, label);
          }
        })
    }
    .width('100%')
    .height(52)
    .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
  }

  /** 快速搜索条件输入对话框 */
  private showQuickCriteriaDialog(type: string, label: string): void {
    this.getUIContext().showAlertDialog({
      title: `搜索${label}`,
      message: `输入${label}搜索条件`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          this.addCriterion({ type: type, op: '等于', value: label });
        }
      }
    });
  }

  /** 搜索结果列表 */
  @Builder
  resultList() {
    Column() {
      Text(`找到 ${this.results.length} 条结果`)
        .fontSize(13)
        .fontColor($r('app.color.textSecondary'))
        .width('100%')
      if (this.results.length === 0) {
        Text('无匹配结果')
          .fontSize(15)
          .fontColor($r('app.color.textSecondary'))
          .margin({ top: 24 })
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.results, (t: Transaction) => {
          Row() {
            Column() {
              Text(t.payeeName || t.categoryPath || '未分类')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
              Text(t.comment || '')
                .fontSize(12)
                .fontColor($r('app.color.textSecondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(formatMoney(t.amount, 2))
              .fontSize(14)
              .fontColor(t.amount >= 0 ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius(8)
        }, (t: Transaction) => `t_${t.id}`)
      }
    }
    .width('100%')
  }
}