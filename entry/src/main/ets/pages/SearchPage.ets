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
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag } from '../model/SupportEntities';
import { router } from '@kit.ArkUI';
import { EmptyState } from '../components/EmptyState';

  /** 搜索条件接口 */
  export interface SearchCriterion {
    type: string;       // amount/comment/status/date/account/payee/category/method/tag
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
    /** 分类列表缓存（分类搜索条件用） */
    @State categoryList: Category[] = [];
    /** 付款方式列表缓存（付款方式搜索条件用） */
    @State methodList: PaymentMethod[] = [];
    /** 标签列表缓存（标签搜索条件用） */
    @State tagList: Tag[] = [];
    /** 收款人列表缓存（收款人搜索条件用） */
    @State payeeList: Payee[] = [];

    aboutToAppear(): void {
      this.repository.getAccounts().then((list: Account[]) => {
        this.accountList = list;
      }).catch(() => {
        this.accountList = [];
      });
      this.repository.getCategories().then((list: Category[]) => {
        this.categoryList = list;
      }).catch(() => {
        this.categoryList = [];
      });
      this.repository.getPaymentMethods().then((list: PaymentMethod[]) => {
        this.methodList = list;
      }).catch(() => {
        this.methodList = [];
      });
      this.repository.getTags().then((list: Tag[]) => {
        this.tagList = list;
      }).catch(() => {
        this.tagList = [];
      });
      this.repository.getPayees().then((list: Payee[]) => {
        this.payeeList = list;
      }).catch(() => {
        this.payeeList = [];
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
    const typeLabel: string = this.typeLabelOf(c.type);
    let label = `${typeLabel} ${c.op} ${c.value}`;
    if (c.extra) {
      label = `${typeLabel}(${c.extra}) ${c.op} ${c.value}`;
    }
    return label;
  }

  private typeLabelOf(type: string): string {
    if (type === 'amount') { return '金额'; }
    if (type === 'comment') { return '备注'; }
    if (type === 'payee') { return '收款人'; }
    if (type === 'category') { return '分类'; }
    if (type === 'status') { return '状态'; }
    if (type === 'date') { return '日期'; }
    if (type === 'account') { return '账户'; }
    if (type === 'method') { return '付款方式'; }
    if (type === 'tag') { return '标签'; }
    return type;
  }

  private removeCriterion(type: string): void {
    this.criteria = this.criteria.filter((c: SearchCriterion) => c.type !== type);
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.textPrimary'))
        }
          .type(ButtonType.Circle)
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .accessibilityText('返回')
          .onClick(() => {
            router.back();
          })
        Row() {
          Text(this.searchType === 0 ? '快速搜索' : '复杂搜索')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.textPrimary'))
          Image($r('sys.media.ohos_ic_public_arrow_down'))
            .width(14)
            .height(14)
            .margin({ left: 4 })
        }
        .height(48)
        .bindMenu(this.searchTypeMenu())
        Blank()
        Button() {
          Image($r('app.media.ic_clear_all'))
            .width(22)
            .height(22)
            .fillColor(this.criteria.length > 0 || this.searched ? $r('app.color.iconSecondary') : $r('app.color.interactiveDisabled'))
        }
          .type(ButtonType.Circle)
          .width(48)
          .height(48)
          .backgroundColor(Color.Transparent)
          .enabled(this.criteria.length > 0 || this.searched)
          .accessibilityText('清除搜索条件')
          .onClick(() => {
            this.clearCriteria();
          })
        Button('搜索')
          .height($r('app.float.native_touch_target'))
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.surfaceBrandSoft'))
          .borderRadius(24)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primaryColor'))
          .stateEffect(true)
          .onClick(() => {
            this.executeSearch();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 8 })
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
              EmptyState({
                iconResource: $r('app.media.ic_filter_list'),
                title: '尚未添加条件',
                subtitle: '点击上方选项定义查询条件'
              })
              .width('100%')
              .height(240)
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
      this.quickRow('收款人', $r('app.media.ic_payee'), 'payee')
      this.quickRow('分类', $r('app.media.ic_category'), 'category')
      this.quickRow('状态', $r('app.media.ic_status'), 'status')
      this.quickRow('日期', $r('app.media.ic_date'), 'date')
      this.quickRow('账户', $r('app.media.ic_account_balance'), 'account')
      this.quickRow('付款方式', $r('app.media.ic_method'), 'method')
      this.quickRow('标签', $r('app.media.ic_tag'), 'tag')
    }
    .width('100%')
  }

  /** 复杂搜索条件按钮（对齐安卓：图标文字扁平样式，两行排列覆盖全部条件） */
  @Builder
  complexCriteriaButtons() {
    Flex({ wrap: FlexWrap.Wrap }) {
      this.criterionChip('金额', $r('app.media.ic_amount'), 'amount')
      this.criterionChip('备注', $r('app.media.ic_comment'), 'comment')
      this.criterionChip('收款人', $r('app.media.ic_payee'), 'payee')
      this.criterionChip('分类', $r('app.media.ic_category'), 'category')
      this.criterionChip('状态', $r('app.media.ic_status'), 'status')
      this.criterionChip('日期', $r('app.media.ic_date'), 'date')
      this.criterionChip('账户', $r('app.media.ic_account_balance'), 'account')
      this.criterionChip('付款方式', $r('app.media.ic_method'), 'method')
      this.criterionChip('标签', $r('app.media.ic_tag'), 'tag')
    }
    .width('100%')
    .padding({ left: 12, right: 4, bottom: 4 })
  }

  @Builder
  criterionChip(label: string, icon: Resource, type: string) {
    Button() {
      Row({ space: 4 }) {
        Image(icon)
          .width(16)
          .height(16)
          .fillColor($r('app.color.primaryColor'))
        Text(label)
          .fontSize(14)
          .fontColor($r('app.color.primaryColor'))
      }
    }
    .height($r('app.float.native_touch_target'))
    .padding({ left: 10, right: 10 })
    .margin({ right: 8, bottom: 8 })
    .borderRadius(24)
    .backgroundColor($r('app.color.surfaceBrandSoft'))
    .stateEffect(true)
    .accessibilityText(`添加${label}搜索条件`)
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
        categoryList: this.categoryList,
        methodList: this.methodList,
        tagList: this.tagList,
        payeeList: this.payeeList,
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
    .height(60)
    .padding({ left: 14, right: 12 })
    .margin({ bottom: 8 })
    .borderRadius($r('app.float.native_card_radius'))
    .backgroundColor($r('app.color.surfacePrimary'))
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
        EmptyState({
          iconResource: $r('app.media.ic_filter_list'),
          title: '没有匹配结果',
          subtitle: '可以调整搜索条件后重试'
        })
          .width('100%')
          .height(240)
      } else {
        ForEach(this.results, (t: Transaction) => {
          Row() {
            Column() {
              Text(t.payeeName || t.categoryPath || '未分类')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.textPrimary'))
              Text(t.comment || '')
                .fontSize(12)
                .fontColor($r('app.color.textSecondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(formatMoney(t.amount, 2))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(t.amount >= 0 ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
          }
          .width('100%')
          .height(68)
          .padding({ left: 16, right: 16 })
          .margin({ top: 8 })
          .backgroundColor($r('app.color.surfacePrimary'))
          .borderRadius($r('app.float.native_card_radius'))
        }, (t: Transaction) => `t_${t.id}`)
      }
    }
    .width('100%')
  }
}
