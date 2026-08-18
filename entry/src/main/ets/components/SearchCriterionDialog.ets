/**
 * 复杂搜索条件设置对话框（对齐安卓 SearchRequest 各条件对话框）
 * - 金额：支出/收入切换 + 等于/大于/小于 + 金额输入框
 * - 备注：关键词输入框
 * - 状态：下拉选择
 * - 日期：范围选择（简化：今天/本周/本月/自定义）
 * - 账户：账户列表选择
 */
import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag } from '../model/SupportEntities';

interface CriterionOption {
  key: string;
  label: string;
}

@CustomDialog
export struct SearchCriterionDialog {
  controller?: CustomDialogController;
  /** 条件类型：amount/comment/payee/category/status/date/account/method/tag */
  @Prop criterionType: string = 'amount';
  @Prop accountList: Account[] = [];
  @Prop categoryList: Category[] = [];
  @Prop methodList: PaymentMethod[] = [];
  @Prop tagList: Tag[] = [];
  @Prop payeeList: Payee[] = [];
  onResult: (op: string, value: string, extra?: string) => void = () => {
  };
  /** 关闭回调（父级 controller 关闭） */
  onClose: () => void = () => {
  };

  @State op: string = '等于';
  @State value: string = '';
  @State extra: string = '支出';
  @State selectedAccountId: number = -1;
  @State selectedCategoryId: number = -1;
  @State selectedMethodId: number = -1;
  @State selectedTagId: number = -1;
  @State selectedPayeeId: number = -1;

  private ops: Array<CriterionOption> = [
    { key: '等于', label: '等于' } as CriterionOption,
    { key: '大于', label: '大于' } as CriterionOption,
    { key: '小于', label: '小于' } as CriterionOption
  ];
  private statuses: Array<CriterionOption> = [
    { key: '未结算', label: '未结算' } as CriterionOption,
    { key: '已结算', label: '已结算' } as CriterionOption
  ];
  private dateRanges: Array<CriterionOption> = [
    { key: '今天', label: '今天' } as CriterionOption,
    { key: '本周', label: '本周' } as CriterionOption,
    { key: '本月', label: '本月' } as CriterionOption,
    { key: '今年', label: '今年' } as CriterionOption
  ];

  private typeLabel(): string {
    switch (this.criterionType) {
      case 'amount': return '金额';
      case 'comment': return '备注';
      case 'payee': return '收款人';
      case 'category': return '分类';
      case 'status': return '状态';
      case 'date': return '日期';
      case 'account': return '账户';
      case 'method': return '付款方式';
      case 'tag': return '标签';
      default: return '';
    }
  }

  private confirm(): void {
    let resultValue = this.value;
    let resultOp = this.op;
    if (this.criterionType === 'account' && this.selectedAccountId > 0) {
      const acc = this.accountList.find((a: Account) => a.id === this.selectedAccountId);
      resultValue = acc ? acc.label : '';
      resultOp = '等于';
    } else if (this.criterionType === 'category' && this.selectedCategoryId >= 0) {
      const cat = this.categoryList.find((c: Category) => c.id === this.selectedCategoryId);
      resultValue = cat ? cat.label : '';
      resultOp = '等于';
    } else if (this.criterionType === 'method' && this.selectedMethodId >= 0) {
      const m = this.methodList.find((mm: PaymentMethod) => mm.id === this.selectedMethodId);
      resultValue = m ? m.label : '';
      resultOp = '等于';
    } else if (this.criterionType === 'tag' && this.selectedTagId >= 0) {
      const t = this.tagList.find((tg: Tag) => tg.id === this.selectedTagId);
      resultValue = t ? t.label : '';
      resultOp = '等于';
    } else if (this.criterionType === 'payee' && this.selectedPayeeId >= 0) {
      const p = this.payeeList.find((pp: Payee) => pp.id === this.selectedPayeeId);
      resultValue = p ? p.name : '';
      resultOp = '等于';
    }
    // comment 类型没有支出/收入切换，不传 extra
    if (this.criterionType === 'comment') {
      this.onResult(resultOp, resultValue, undefined);
    } else {
      this.onResult(resultOp, resultValue, this.extra);
    }
    this.onClose();
  }

  @Builder
  opSelect() {
    Row() {
      Text('条件')
        .fontSize(14)
        .fontColor($r('app.color.textSecondary'))
        .width(60)
      Select(this.ops.map((o: CriterionOption) => ({ value: o.label }) as SelectOption))
        .selected(this.ops.findIndex((o: CriterionOption) => o.key === this.op))
        .value(this.op)
        .layoutWeight(1)
        .onSelect((index: number) => {
          this.op = this.ops[index].key;
        })
    }
    .width('100%')
    .height(44)
  }

  build() {
    Column() {
      // 标题
      Text(`搜索${this.typeLabel()}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')
        .textAlign(TextAlign.Start)

      // 金额：支出/收入切换 + 条件 + 输入框
      if (this.criterionType === 'amount') {
        Row() {
          Text('类型')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .width(60)
          Row() {
            Text(this.extra === '支出' ? '支出' : '支出')
              .fontSize(14)
              .fontColor(this.extra === '支出' ? $r('app.color.colorExpense') : $r('app.color.textSecondary'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(16)
              .backgroundColor(this.extra === '支出' ? '#22000000' : Color.Transparent)
              .onClick(() => {
                this.extra = '支出';
              })
            Text('收入')
              .fontSize(14)
              .fontColor(this.extra === '收入' ? $r('app.color.colorIncome') : $r('app.color.textSecondary'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(16)
              .backgroundColor(this.extra === '收入' ? '#22000000' : Color.Transparent)
              .onClick(() => {
                this.extra = '收入';
              })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .height(44)
        .margin({ top: 12 })

        this.opSelect()

        Row() {
          Text('金额')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .width(60)
          TextInput({ placeholder: '输入金额', text: this.value })
            .type(InputType.Number)
            .layoutWeight(1)
            .onChange((v: string) => {
              this.value = v;
            })
        }
        .width('100%')
        .height(48)
        .margin({ top: 8 })
      }

      // 备注：输入框
      if (this.criterionType === 'comment') {
        Row() {
          Text('关键词')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .width(60)
          TextInput({ placeholder: '输入备注关键词', text: this.value })
            .layoutWeight(1)
            .onChange((v: string) => {
              this.value = v;
            })
        }
        .width('100%')
        .height(48)
        .margin({ top: 12 })
      }

      // 状态：下拉选择
      if (this.criterionType === 'status') {
        Row() {
          Text('状态')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .width(60)
          Select(this.statuses.map((o: CriterionOption) => ({ value: o.label }) as SelectOption))
            .selected(this.statuses.findIndex((o: CriterionOption) => o.key === this.value))
            .value(this.value || '未结算')
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.value = this.statuses[index].key;
            })
        }
        .width('100%')
        .height(44)
        .margin({ top: 12 })
      }

      // 日期：范围选择
      if (this.criterionType === 'date') {
        Row() {
          Text('范围')
            .fontSize(14)
            .fontColor($r('app.color.textSecondary'))
            .width(60)
          Select(this.dateRanges.map((o: CriterionOption) => ({ value: o.label }) as SelectOption))
            .selected(this.dateRanges.findIndex((o: CriterionOption) => o.key === this.value))
            .value(this.value || '本月')
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.value = this.dateRanges[index].key;
            })
        }
        .width('100%')
        .height(44)
        .margin({ top: 12 })
      }

      // 账户：列表选择
      if (this.criterionType === 'account') {
        Column() {
          ForEach(this.accountList, (acc: Account) => {
            Row() {
              Text(acc.label)
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
              Radio({ value: acc.id.toString(), group: 'accountGroup' })
                .checked(this.selectedAccountId === acc.id)
                .radioStyle({
                  checkedBackgroundColor: $r('app.color.primaryColor'),
                  uncheckedBorderColor: $r('app.color.textSecondary')
                })
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.selectedAccountId = acc.id;
                  }
                })
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.selectedAccountId = acc.id;
            })
          }, (acc: Account) => `acc_${acc.id}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      // 收款人：列表选择（对齐安卓 PayeeCriterion）
      if (this.criterionType === 'payee') {
        Column() {
          ForEach(this.payeeList, (p: Payee) => {
            Row() {
              Text(p.name)
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
              Radio({ value: p.id.toString(), group: 'payeeGroup' })
                .checked(this.selectedPayeeId === p.id)
                .radioStyle({
                  checkedBackgroundColor: $r('app.color.primaryColor'),
                  uncheckedBorderColor: $r('app.color.textSecondary')
                })
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.selectedPayeeId = p.id;
                  }
                })
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.selectedPayeeId = p.id;
            })
          }, (p: Payee) => `payee_${p.id}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      // 分类：列表选择（对齐安卓 CategoryCriterion）
      if (this.criterionType === 'category') {
        Column() {
          ForEach(this.categoryList, (cat: Category) => {
            Row() {
              Text(cat.label)
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Radio({ value: cat.id.toString(), group: 'catGroup' })
                .checked(this.selectedCategoryId === cat.id)
                .radioStyle({
                  checkedBackgroundColor: $r('app.color.primaryColor'),
                  uncheckedBorderColor: $r('app.color.textSecondary')
                })
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.selectedCategoryId = cat.id;
                  }
                })
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.selectedCategoryId = cat.id;
            })
          }, (cat: Category) => `cat_${cat.id}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      // 付款方式：列表选择（对齐安卓 MethodCriterion）
      if (this.criterionType === 'method') {
        Column() {
          ForEach(this.methodList, (m: PaymentMethod) => {
            Row() {
              Text(m.label)
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
              Radio({ value: m.id.toString(), group: 'methodGroup' })
                .checked(this.selectedMethodId === m.id)
                .radioStyle({
                  checkedBackgroundColor: $r('app.color.primaryColor'),
                  uncheckedBorderColor: $r('app.color.textSecondary')
                })
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.selectedMethodId = m.id;
                  }
                })
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.selectedMethodId = m.id;
            })
          }, (m: PaymentMethod) => `method_${m.id}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      // 标签：列表选择（对齐安卓 TagCriterion）
      if (this.criterionType === 'tag') {
        Column() {
          ForEach(this.tagList, (t: Tag) => {
            Row() {
              Text(t.label)
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
              Radio({ value: t.id.toString(), group: 'tagGroup' })
                .checked(this.selectedTagId === t.id)
                .radioStyle({
                  checkedBackgroundColor: $r('app.color.primaryColor'),
                  uncheckedBorderColor: $r('app.color.textSecondary')
                })
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.selectedTagId = t.id;
                  }
                })
            }
            .width('100%')
            .height(44)
            .onClick(() => {
              this.selectedTagId = t.id;
            })
          }, (t: Tag) => `tag_${t.id}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      // 底部按钮
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.onClose();
          })
        Button('确定')
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.primaryColor'))
          .onClick(() => {
            this.confirm();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .constraintSize({ maxHeight: '70%' })
    .padding(20)
    .backgroundColor($r('app.color.surfaceElevated'))
    .borderRadius(16)
  }
}