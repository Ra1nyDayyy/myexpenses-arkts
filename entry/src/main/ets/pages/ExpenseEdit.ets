import { Transaction, OperationType, CrStatus } from '../model/Transaction';
import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag, Template } from '../model/SupportEntities';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { CalculatorDialog } from '../components/CalculatorDialog';
import { parseMoney, formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { generateUuid, formatDate, formatTime } from '../common/FormatUtils';
import { router, promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { camera } from '@kit.CameraKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { InlineExpansionState } from '../ui/InlineExpansionState';

/**
 * 记账编辑页：对应 Android ExpenseEdit + one_expense.xml
 */
@Entry
@Component
struct ExpenseEdit {
  @State transactionId: number = -1;
  @State isTemplate: boolean = false; // 模板编辑模式（新建/编辑交易模板）
  @State templateId: number = -1; // >0 编辑已有模板
  @State templateTitle: string = ''; // 模板标题
  /** 从模板创建交易（对齐安卓 ACTION_CREATE_FROM_TEMPLATE：模板预填交易表单） */
  @State fromTemplateId: number = -1;
  /** 模板选择对话框（对齐安卓 toolbar 我的模板） */
  private templateDialog: CustomDialogController | null = null;
  /** 类型 Tabs 当前索引（0支出/1收入/2转账/3拆分），标题下拉切换时同步 */
  @State typeIndex: number = 0;
  /** 模板默认操作（对齐安卓 Template.Action：0=保存 SAVE，1=编辑 EDIT） */
  @State templateDefaultAction: number = 0;
  /** 模板计划（对齐安卓 Recurrence：0=无，2=每天，3=每周，4=每月，6=每年） */
  @State templateRecurrence: number = 0;
  @State accountId: number = -1;
  @State operationType: OperationType = OperationType.TRANSACTION;
  @State isIncome: boolean = false;
  @State amountInput: string = '';
  @State comment: string = '';
  @State payeeInput: string = '';
  @State selectedCategoryId: number = -1;
  @State selectedCategoryLabel: string = '';
  @State methodId: number = -1;
  @State transferAccountId: number = -1;
  @State date: number = Math.floor(Date.now() / 1000);
  @State crStatus: CrStatus = CrStatus.UNRECONCILED;
  @State referenceNumber: string = '';
  @State tagIds: number[] = [];
  @State attachmentUris: string[] = [];
  @State splitParts: Transaction[] = [];
  @State expandedSplitPartIndex: number = -1;
  @State attachmentSourcesExpanded: boolean = false;
  @State showOriginalAmount: boolean = false; // 展示原始金额
  @State originalAmountInput: string = '';
  @State originalCurrency: string = '';
  // 位置（对齐安卓 Android 位置记录）
  @State latitude: number = 0;
  @State longitude: number = 0;

  private repository: Repository = Repository.getInstance();
  @State accounts: Account[] = [];
  @State categories: Category[] = [];
  @State methods: PaymentMethod[] = [];
  @State payees: Payee[] = [];
  @State tags: Tag[] = [];
  private currencyCode: string = 'CNY';
  private calculator: CustomDialogController = new CustomDialogController({
    builder: CalculatorDialog({
      onResult: (value: string) => {
        this.amountInput = value;
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
    cornerRadius: 16
  });

  private showCalculator(): void {
    this.calculator = new CustomDialogController({
      builder: CalculatorDialog({
        display: this.amountInput || '0',
        onResult: (value: string) => {
          this.amountInput = value;
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      cornerRadius: 16
    });
    this.calculator.open();
  }

  /**
   * 位置录入尚未接入系统定位服务。明确告知能力边界，避免写入伪造坐标。
   */
  private setLocation(): void {
    this.getUIContext().showAlertDialog({
      title: '设置位置',
      message: '位置录入暂未接入系统定位服务，本次不会修改交易位置。',
      primaryButton: {
        value: '知道了',
        action: () => {
        }
      }
    });
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id'] !== undefined) {
      this.transactionId = params['id'] as number;
    }
    if (params && params['accountId'] !== undefined) {
      this.accountId = params['accountId'] as number;
    }
    // 模板编辑模式：isTemplate=true 时本页编辑/新建模板（保存到 templates 表）
    if (params && params['isTemplate'] !== undefined && params['isTemplate'] === true) {
      this.isTemplate = true;
      if (params['templateId'] !== undefined) {
        this.templateId = params['templateId'] as number;
      }
    }
    // 从模板创建交易（对齐安卓 ACTION_CREATE_FROM_TEMPLATE：模板预填交易表单，保存时写入交易表）
    if (params && params['fromTemplateId'] !== undefined) {
      this.fromTemplateId = params['fromTemplateId'] as number;
    }
    // 交易类型预选（FAB 菜单传入）：-1 支出 / 1 收入 / 2 转账 / 3 拆分
    if (params && params['type'] !== undefined) {
      const t = params['type'] as number;
      if (t === 1) {
        this.isIncome = true;
        this.operationType = OperationType.TRANSACTION;
      } else if (t === 2) {
        this.operationType = OperationType.TRANSFER;
      } else if (t === 3) {
        this.isIncome = false;
        this.operationType = OperationType.SPLIT;
      } else {
        this.isIncome = false;
        this.operationType = OperationType.TRANSACTION;
      }
    }
    this.loadData();
  }

  onPageShow(): void {
    const selected = AppStorage.get<Record<string, Object>>('selectedCategory');
    if (selected && selected['categoryId'] !== undefined) {
      if (this.splitPartEditIndex >= 0 && this.splitPartEditIndex < this.splitParts.length) {
        // 拆分项分类回传
        this.splitParts[this.splitPartEditIndex].categoryId = selected['categoryId'] as number;
        this.splitParts[this.splitPartEditIndex].categoryPath = selected['categoryLabel'] as string;
        this.splitParts = [...this.splitParts];
        this.splitPartEditIndex = -1;
      } else {
        this.selectedCategoryId = selected['categoryId'] as number;
        this.selectedCategoryLabel = selected['categoryLabel'] as string;
      }
      AppStorage.delete('selectedCategory');
    }
    // 标签选择回传（对齐安卓 tags_create_or_select：从 TagSelect 返回后读取）
    const selectedTags = AppStorage.get<number[]>('selectedTags');
    if (selectedTags !== undefined && selectedTags !== null) {
      this.tagIds = selectedTags;
      AppStorage.delete('selectedTags');
    }
  }

  async loadData(): Promise<void> {
    this.accounts = await this.repository.getAccounts();
    // 默认选择第一个账户（保证首帧即有账户）
    if (this.accountId <= 0 && this.accounts.length > 0) {
      this.accountId = this.accounts[0].id;
      this.currencyCode = this.accounts[0].currency;
    }
    this.categories = await this.repository.getCategories();
    this.methods = await this.repository.getPaymentMethods();
    this.payees = await this.repository.getPayees();
    this.tags = await this.repository.getTags();
    if (this.methodId <= 0 && this.methods.length > 0) {
      this.methodId = this.methods[0].id;
    }
    const acc = this.accounts.find((a: Account) => a.id === this.accountId);
    if (acc) {
      this.currencyCode = acc.currency;
    }
    if (this.isTemplate && this.templateId > 0) {
      await this.loadTemplate();
    } else if (this.transactionId > 0) {
      await this.loadTransaction();
    } else if (this.fromTemplateId > 0) {
      // 从模板创建交易：加载模板数据预填表单（对齐安卓 ACTION_CREATE_FROM_TEMPLATE）
      const tpl = await this.repository.getTemplate(this.fromTemplateId);
      if (tpl) {
        this.applyTemplate(tpl);
      }
    }
    hilog.info(0x0000, 'ExpenseEdit', 'loadData done: isTemplate=%{public}s templateId=%{public}d currency=%{public}s amountInput=%{public}s',
      JSON.stringify(this.isTemplate), this.templateId, this.currencyCode, this.amountInput);
  }

  /**
   * 加载已有模板数据到编辑表单（模板编辑模式）
   */
  async loadTemplate(): Promise<void> {
    const tpl = await this.repository.getTemplate(this.templateId);
    if (tpl) {
      this.templateTitle = tpl.title;
      this.accountId = tpl.accountId;
      this.currencyCode = tpl.currency;
      this.comment = tpl.comment;
      this.payeeInput = tpl.payeeName;
      this.selectedCategoryId = tpl.categoryId;
      this.selectedCategoryLabel = tpl.categoryPath;
      this.methodId = tpl.methodId;
      this.transferAccountId = tpl.transferAccountId;
      this.tagIds = tpl.tagIds;
      this.isIncome = tpl.isIncome;
      this.templateRecurrence = tpl.recurrence;
      this.templateDefaultAction = tpl.defaultAction === 'EDIT' ? 1 : 0;
      this.amountInput = formatMoney(Math.abs(tpl.amount), this.fractionDigits());
      hilog.info(0x0000, 'ExpenseEdit', 'loadTemplate: tplAmount=%{public}d currency=%{public}s fractionDigits=%{public}d amountInput=%{public}s',
        tpl.amount, this.currencyCode, this.fractionDigits(), this.amountInput);
      if (tpl.transferAccountId >= 0) {
        this.operationType = OperationType.TRANSFER;
      } else if (tpl.isSplit()) {
        this.operationType = OperationType.SPLIT;
      } else {
        this.operationType = OperationType.TRANSACTION;
      }
    }
  }

  async loadTransaction(): Promise<void> {
    const t = await this.repository.getTransaction(this.transactionId);
    if (t) {
      this.accountId = t.accountId;
      this.comment = t.comment;
      this.payeeInput = t.payeeName;
      this.selectedCategoryId = t.categoryId;
      this.selectedCategoryLabel = t.categoryPath;
      this.methodId = t.methodId;
      this.date = t.date;
      this.crStatus = t.crStatus;
      this.referenceNumber = t.referenceNumber;
      this.tagIds = t.tagIds;
      this.attachmentUris = await this.repository.getTransactionAttachments(this.transactionId);
      this.latitude = t.latitude;
      this.longitude = t.longitude;
      this.isIncome = t.amount > 0;
      this.amountInput = formatMoney(Math.abs(t.amount), this.fractionDigits());
      if (t.transferAccountId > 0) {
        this.operationType = OperationType.TRANSFER;
        this.transferAccountId = t.transferAccountId;
      }
    }
  }

  private fractionDigits(): number {
    return currencyByCode(this.currencyCode).fractionDigits;
  }

  private currencySymbol(): string {
    return currencyByCode(this.currencyCode).symbol;
  }

  private methodName(id: number): string {
    const m = this.methods.find((item: PaymentMethod) => item.id === id);
    return m ? m.label : '选择';
  }

  private accountLabel(): string {
    const acc = this.accounts.find((a: Account) => a.id === this.accountId);
    return acc ? acc.label : '选择';
  }

  private accountIndex(): number {
    return this.accounts.findIndex((a: Account) => a.id === this.accountId);
  }

  private transferAccountLabel(): string {
    const acc = this.accounts.find((a: Account) => a.id === this.transferAccountId);
    return acc ? acc.label : '选择';
  }

  private transferAccounts(): Account[] {
    return this.accounts.filter((a: Account) => a.id !== this.accountId);
  }

  private transferAccountIndex(): number {
    const list = this.transferAccounts();
    return list.findIndex((a: Account) => a.id === this.transferAccountId);
  }

  private accountOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let a of this.accounts) {
      options.push({ value: a.label } as SelectOption);
    }
    return options;
  }

  private transferAccountOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let a of this.transferAccounts()) {
      options.push({ value: a.label } as SelectOption);
    }
    return options;
  }

  private methodOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let m of this.methods) {
      options.push({ value: m.label } as SelectOption);
    }
    return options;
  }

  private async save(): Promise<void> {
    const ok = await this.performSave();
    if (ok) {
      promptAction.showToast({ message: $r('app.string.toast_save_success') });
      router.back();
    }
  }

  /**
   * 保存并新建：保存后清空金额/备注/收款人/类别，保留账户/类型/日期
   */
  private async saveAndNew(): Promise<void> {
    const ok = await this.performSave();
    if (ok) {
      promptAction.showToast({ message: $r('app.string.toast_saved_continue') });
      this.transactionId = -1;
      this.amountInput = '';
      this.comment = '';
      this.payeeInput = '';
      this.selectedCategoryId = -1;
      this.selectedCategoryLabel = '';
      this.crStatus = CrStatus.UNRECONCILED;
      this.referenceNumber = '';
      this.tagIds = [];
    }
  }

  private async performSave(): Promise<boolean> {
    if (this.isTemplate) {
      return this.performTemplateSave();
    }
    const amount = parseMoney(this.amountInput, this.fractionDigits());
    if (this.accountId <= 0) {
      promptAction.showToast({ message: $r('app.string.toast_select_account') });
      return false;
    }
    if (this.operationType === OperationType.TRANSFER && this.transferAccountId <= 0) {
      promptAction.showToast({ message: $r('app.string.toast_select_target_account') });
      return false;
    }
    if (this.operationType !== OperationType.TRANSFER && amount === 0) {
      promptAction.showToast({ message: $r('app.string.toast_enter_amount') });
      return false;
    }
    // 拆分交易：保存父交易 + 子交易
    if (this.operationType === OperationType.SPLIT) {
      if (this.splitParts.length === 0) {
        promptAction.showToast({ message: $r('app.string.toast_add_split_part') });
        return false;
      }
      const parent = new Transaction();
      parent.id = this.transactionId;
      parent.accountId = this.accountId;
      parent.comment = this.comment.trim();
      parent.date = this.date;
      parent.valueDate = this.date;
      parent.crStatus = this.crStatus;
      parent.uuid = this.transactionId > 0 ? parent.uuid : generateUuid();
      parent.tagIds = this.tagIds;
      try {
        // 均摊输入金额到子交易
        const sign = this.isIncome ? 1 : -1;
        const perPart = Math.round(Math.abs(amount) / this.splitParts.length);
        for (let part of this.splitParts) {
          part.amount = sign * perPart;
        }
        await this.repository.saveSplitTransaction(parent, this.splitParts);
        return true;
      } catch (e) {
        promptAction.showToast({ message: '拆分保存失败: ' + JSON.stringify(e) });
        return false;
      }
    }
    const t = new Transaction();
    t.id = this.transactionId;
    t.accountId = this.accountId;
    t.amount = this.isIncome ? Math.abs(amount) : -Math.abs(amount);
    t.comment = this.comment.trim();
    t.categoryId = this.selectedCategoryId;
    t.payeeId = this.payeeInput.trim() ? await this.repository.findOrCreatePayee(this.payeeInput) : -1;
    t.methodId = this.methodId;
    t.date = this.date;
    t.valueDate = this.date;
    t.crStatus = this.crStatus;
    t.referenceNumber = this.referenceNumber;
    t.uuid = this.transactionId > 0 ? t.uuid : generateUuid();
    t.tagIds = this.tagIds;
    t.latitude = this.latitude;
    t.longitude = this.longitude;

    try {
      if (this.operationType === OperationType.TRANSFER && this.transferAccountId > 0) {
        if (this.transactionId > 0) {
          await this.repository.updateTransaction(t);
        } else {
          const sourceId = await this.repository.insertTransaction(t);
          const dest = new Transaction();
          dest.accountId = this.transferAccountId;
          dest.amount = -t.amount;
          dest.comment = t.comment;
          dest.categoryId = -1;
          dest.methodId = t.methodId;
          dest.date = t.date;
          dest.valueDate = t.valueDate;
          dest.crStatus = t.crStatus;
          dest.uuid = generateUuid();
          const destId = await this.repository.insertTransaction(dest);
          t.transferPeerId = destId;
          t.transferAccountId = this.transferAccountId;
          await this.repository.updateTransaction(t);
          dest.transferPeerId = sourceId;
          dest.transferAccountId = this.accountId;
          await this.repository.updateTransaction(dest);
        }
      } else if (this.transactionId > 0) {
        await this.repository.updateTransaction(t);
        // 保存附件
        await this.repository.setTransactionAttachments(this.transactionId, this.attachmentUris);
      } else {
        const newId = await this.repository.insertTransaction(t);
        // 保存附件
        await this.repository.setTransactionAttachments(newId, this.attachmentUris);
      }
      return true;
    } catch (e) {
      promptAction.showToast({ message: '保存失败: ' + JSON.stringify(e) });
      return false;
    }
  }

  /**
   * 模板模式保存：写入/更新 templates 表（对齐安卓 isTemplate 保存）
   */
  private async performTemplateSave(): Promise<boolean> {
    const title = this.templateTitle.trim();
    if (!title) {
      promptAction.showToast({ message: '请输入模板标题' });
      return false;
    }
    if (this.accountId <= 0) {
      promptAction.showToast({ message: $r('app.string.toast_select_account') });
      return false;
    }
    if (this.operationType === OperationType.TRANSFER && this.transferAccountId <= 0) {
      promptAction.showToast({ message: $r('app.string.toast_select_target_account') });
      return false;
    }
    const tpl = new Template();
    tpl.id = this.templateId > 0 ? this.templateId : 0;
    tpl.title = title;
    tpl.accountId = this.accountId;
    tpl.comment = this.comment.trim();
    tpl.categoryId = this.selectedCategoryId;
    tpl.payeeId = this.payeeInput.trim() ? await this.repository.findOrCreatePayee(this.payeeInput) : -1;
    tpl.methodId = this.methodId;
    tpl.transferAccountId = this.operationType === OperationType.TRANSFER ? this.transferAccountId : -1;
    tpl.isIncome = this.isIncome;
    tpl.tagIds = this.tagIds;
    tpl.currency = this.currencyCode;
    tpl.recurrence = this.templateRecurrence;
    tpl.defaultAction = this.templateDefaultAction === 1 ? 'EDIT' : 'SAVE';
    tpl.amount = this.isIncome ? Math.abs(parseMoney(this.amountInput, this.fractionDigits())) : -Math.abs(parseMoney(this.amountInput, this.fractionDigits()));
    try {
      if (tpl.id > 0) {
        await this.repository.updateTemplate(tpl);
      } else {
        await this.repository.insertTemplate(tpl);
      }
      return true;
    } catch (e) {
      promptAction.showToast({ message: '模板保存失败: ' + JSON.stringify(e) });
      return false;
    }
  }

  private navigateCategorySelect(): void {
    router.pushUrl({
      url: 'pages/CategorySelect',
      params: { type: this.isIncome ? 1 : -1 }
    }).catch(() => {
    });
  }

  /**
   * 切换展示原始金额
   */
  private toggleOriginalAmount(): void {
    animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
      this.showOriginalAmount = !this.showOriginalAmount;
      if (this.showOriginalAmount) {
        if (!this.originalAmountInput && this.amountInput) {
          this.originalAmountInput = this.amountInput;
        }
        if (!this.originalCurrency) {
          this.originalCurrency = this.currencyCode;
        }
      }
    });
  }

  /**
   * 选择模板并填充当前编辑交易（对齐安卓 toolbar 我的模板）
   */
  private async chooseTemplateAndFill(): Promise<void> {
    const templates: Template[] = await this.repository.getTemplates();
    if (templates.length === 0) {
      promptAction.showToast({ message: '暂无可用模板，请先到模板页创建' });
      return;
    }
    if (this.templateDialog === null) {
      this.templateDialog = new CustomDialogController({
        builder: TemplateSelectDialog({
          templates: templates,
          onSelect: (tpl: Template) => {
            this.applyTemplate(tpl);
            if (this.templateDialog) {
              this.templateDialog.close();
            }
          },
          onCancel: () => {
            if (this.templateDialog) {
              this.templateDialog.close();
            }
          }
        }),
        autoCancel: true,
        alignment: DialogAlignment.Bottom,
        offset: { dx: 0, dy: -40 }
      });
    }
    this.templateDialog.open();
  }

  /**
   * 应用模板数据到当前编辑表单
   */
  private applyTemplate(tpl: Template): void {
    this.isIncome = tpl.isIncome;
    if (tpl.transferAccountId > 0) {
      this.operationType = OperationType.TRANSFER;
      this.typeIndex = 2;
      this.transferAccountId = tpl.transferAccountId;
    } else if (tpl.isIncome) {
      this.operationType = OperationType.TRANSACTION;
      this.typeIndex = 1;
    } else {
      this.operationType = OperationType.TRANSACTION;
      this.typeIndex = 0;
    }
    const acc = this.accounts.find((a: Account) => a.id === tpl.accountId);
    if (acc) {
      this.accountId = tpl.accountId;
      this.currencyCode = acc.currency;
    }
    this.amountInput = tpl.amount !== 0 ? String(Math.abs(tpl.amount) / 100) : '';
    this.comment = tpl.comment;
    this.selectedCategoryId = tpl.categoryId;
    this.selectedCategoryLabel = tpl.categoryPath || '';
    this.payeeInput = tpl.payeeName || '';
    this.methodId = tpl.methodId;
    this.tagIds = [...tpl.tagIds];
    promptAction.showToast({ message: `已应用模板「${tpl.title}」` });
  }

  private formatMoneyLabel(amount: number): string {
    return formatMoney(amount, 2);
  }

  /**
   * 添加拆分项
   */
  private addSplitPart(): void {
    const part = new Transaction();
    part.amount = 0;
    part.categoryId = -1;
    this.splitParts = [...this.splitParts, part];
  }

  /** 拆分项操作就地展开，同一时间仅展开一项。 */
  private editSplitPart(index: number): void {
    this.expandedSplitPartIndex = InlineExpansionState.toggleExclusive(this.expandedSplitPartIndex, index);
  }

  /** 拆分项标签在卡片内多选，点击立即切换。 */
  private toggleSplitPartTag(index: number, tagId: number): void {
    const part = this.splitParts[index];
    const idx = part.tagIds.indexOf(tagId);
    if (idx >= 0) {
      part.tagIds.splice(idx, 1);
      part.tagIds = [...part.tagIds];
    } else {
      part.tagIds = [...part.tagIds, tagId];
    }
    this.splitParts = [...this.splitParts];
  }

  /**
   * 跳转标签选择页面（对齐安卓 tags_create_or_select：创建或选择标签）
   * 选择结果通过 onPageShow 读取 AppStorage('selectedTags') 回传
   */
  private navigateToTagSelection(): void {
    router.pushUrl({
      url: 'pages/TagSelect',
      params: {
        selectedTagIds: this.tagIds
      }
    }).catch(() => {
    });
  }

  /**
   * 标签 id → 标签名
   */
  private tagLabel(tagId: number): string {
    const t = this.tags.find((tag: Tag) => tag.id === tagId);
    return t ? t.label : '';
  }

  @Builder
  splitPartActionsPanel(part: Transaction, index: number) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button('金额')
          .layoutWeight(1)
          .height($r('app.float.native_touch_target'))
          .fontSize(13)
          .fontColor($r('app.color.textPrimary'))
          .backgroundColor($r('app.color.surfaceSecondary'))
          .borderRadius(14)
          .onClick(() => this.editSplitPartAmount(index))
        Button('分类')
          .layoutWeight(1)
          .height($r('app.float.native_touch_target'))
          .fontSize(13)
          .fontColor($r('app.color.textPrimary'))
          .backgroundColor($r('app.color.surfaceSecondary'))
          .borderRadius(14)
          .onClick(() => this.selectSplitPartCategory(index))
        Button('删除')
          .layoutWeight(1)
          .height($r('app.float.native_touch_target'))
          .fontSize(13)
          .fontColor($r('app.color.colorExpense'))
          .backgroundColor($r('app.color.surfaceExpenseSoft'))
          .borderRadius(14)
          .onClick(() => {
            this.splitParts.splice(index, 1);
            this.splitParts = [...this.splitParts];
            this.expandedSplitPartIndex = -1;
          })
      }
      .width('100%')

      if (this.tags.length > 0) {
        Column({ space: 6 }) {
          Text('标签（可多选）')
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.textSecondary'))
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.tags, (tag: Tag) => {
              Button((part.tagIds.indexOf(tag.id) >= 0 ? '✓ ' : '') + tag.label)
                .height($r('app.float.native_touch_target'))
                .margin({ right: 6, bottom: 6 })
                .padding({ left: 12, right: 12 })
                .fontSize(12)
                .fontColor(part.tagIds.indexOf(tag.id) >= 0 ? Color.White : $r('app.color.textPrimary'))
                .backgroundColor(part.tagIds.indexOf(tag.id) >= 0 ?
                  $r('app.color.primaryColor') : $r('app.color.surfaceSecondary'))
                .borderRadius(14)
                .onClick(() => this.toggleSplitPartTag(index, tag.id))
            }, (tag: Tag) => `split_tag_${index}_${tag.id}_${part.tagIds.indexOf(tag.id)}`)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else {
        Text('暂无可用标签')
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.textTertiary'))
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.surfaceBrandSoft'))
  }

  private editSplitPartAmount(index: number): void {
    const part = this.splitParts[index];
    const dialog = new CustomDialogController({
      builder: CalculatorDialog({
        display: part.amount !== 0 ? formatMoney(Math.abs(part.amount), this.fractionDigits()) : '0',
        onResult: (value: string) => {
          part.amount = parseMoney(value, this.fractionDigits());
          this.splitParts = [...this.splitParts];
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      cornerRadius: 16
    });
    dialog.open();
  }

  /**
   * 拆分项选择分类：记录 index 到临时字段，跳转分类选择
   */
  private splitPartEditIndex: number = -1;

  private selectSplitPartCategory(index: number): void {
    this.splitPartEditIndex = index;
    router.pushUrl({
      url: 'pages/CategorySelect',
      params: { type: -1 }
    }).catch(() => {
    });
  }

  private splitAmountColor(amount: number): ResourceColor {
    if (amount > 0) {
      return $r('app.color.colorIncome');
    }
    if (amount < 0) {
      return $r('app.color.colorExpense');
    }
    return $r('app.color.textTertiary');
  }

  @Builder
  attachmentSourcePanel() {
    Row({ space: 8 }) {
      this.attachmentSourceAction($r('app.media.ic_calculator'), '拍照', () => this.takePhoto())
      this.attachmentSourceAction($r('app.media.ic_attachment'), '相册', () => this.pickPhoto())
      this.attachmentSourceAction($r('app.media.ic_data_object'), '文件', () => this.pickDocument())
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.surfaceBrandSoft'))
  }

  @Builder
  attachmentSourceAction(icon: Resource, label: string, onClick: () => void) {
    Button() {
      Row({ space: 6 }) {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor($r('app.color.primaryColor'))
        Text(label)
          .fontSize(13)
          .fontColor($r('app.color.textPrimary'))
      }
    }
    .layoutWeight(1)
    .height($r('app.float.native_touch_target'))
    .backgroundColor($r('app.color.surfacePrimary'))
    .borderRadius(14)
    .accessibilityText(label)
    .onClick(() => {
      this.attachmentSourcesExpanded = false;
      onClick();
    })
  }

  /**
   * 拍照（对齐安卓 ACTION_IMAGE_CAPTURE）
   * 完整相机会话需真机支持；当前环境做能力检测 + 优雅降级
   */
  private async takePhoto(): Promise<void> {
    try {
      // 1. 申请相机权限
      const atManager = abilityAccessCtrl.createAtManager();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA'] as Permissions[]);
      const granted = result.authResults.length > 0 && result.authResults[0] === 0;
      if (!granted) {
        promptAction.showToast({ message: $r('app.string.toast_camera_permission') });
        return;
      }
      // 2. 检测相机能力
      const cameraManager = camera.getCameraManager(context);
      const cameras = cameraManager.getSupportedCameras();
      if (!cameras || cameras.length === 0) {
        promptAction.showToast({ message: $r('app.string.toast_no_camera') });
        return;
      }
      // 完整相机会话（PhotoSession + PhotoOutput.capture）需真机预览 surface 支持，
      // 模拟器无法完成拍摄验证，此处提示真机可用
      promptAction.showToast({ message: $r('app.string.toast_camera_device') });
    } catch (e) {
      promptAction.showToast({ message: '拍照不可用: ' + JSON.stringify(e) });
    }
  }

  private async pickPhoto(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 9
      });
      if (result && result.photoUris && result.photoUris.length > 0) {
        const uris: string[] = result.photoUris;
        for (let uri of uris) {
          if (this.attachmentUris.indexOf(uri) < 0) {
            this.attachmentUris = [...this.attachmentUris, uri];
          }
        }
      }
    } catch (e) {
      promptAction.showToast({ message: $r('app.string.toast_pick_image_failed') });
    }
  }

  private async pickDocument(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select({
        maxSelectNumber: 9
      });
      if (result && result.length > 0) {
        for (let uri of result) {
          if (this.attachmentUris.indexOf(uri) < 0) {
            this.attachmentUris = [...this.attachmentUris, uri];
          }
        }
      }
    } catch (e) {
      promptAction.showToast({ message: $r('app.string.toast_pick_file_failed') });
    }
  }

  private removeAttachment(index: number): void {
    this.attachmentUris.splice(index, 1);
    this.attachmentUris = [...this.attachmentUris];
  }

  /**
   * 弹出鸿蒙原生日期选择器
   */
  private showDatePicker(): void {
    const current = new Date(this.date * 1000);
    const pickerOptions: DatePickerDialogOptions = {
      start: new Date(current.getFullYear() - 10, 0, 1),
      end: new Date(current.getFullYear() + 10, 11, 31),
      selected: current,
      onDateAccept: (value: Date) => {
        const time = this.date % 86400;
        this.date = Math.floor(value.getTime() / 1000 / 86400) * 86400 + time;
      }
    };
    this.getUIContext().showDatePickerDialog(pickerOptions);
  }

  /**
   * 弹出鸿蒙原生时间选择器
   */
  private showTimePicker(): void {
    const current = new Date(this.date * 1000);
    const pickerOptions: TimePickerDialogOptions = {
      selected: current,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const day = Math.floor(this.date / 86400) * 86400;
        this.date = day + (value.hour * 3600) + (value.minute * 60);
      }
    };
    this.getUIContext().showTimePickerDialog(pickerOptions);
  }

  build() {
    Stack() {
    Column() {
      PageHeader({
        title: this.isTemplate
          ? (this.templateId > 0 ? this.getTemplateEditTitle() : this.getTemplateCreateTitle())
          : (this.transactionId > 0 ? '编辑交易' : '新建交易'),
        showMore: false,
        showTemplates: !this.isTemplate,
        titleMenu: this.isTemplate ? this.templateTypeMenu() : [],
        onBack: () => {
          router.back();
        },
        onMore: () => {
        },
        onTemplates: () => {
          this.chooseTemplateAndFill();
        }
      })

      Scroll() {
        Column() {

          // 普通交易保留支出、收入、转账、拆分四种原生类型切换；模板类型仍由标题菜单控制。
          if (!this.isTemplate) {
            Tabs({ barPosition: BarPosition.Start, index: this.typeIndex }) {
              TabContent() {
                Column().width('100%').height(0)
              }.tabBar(this.tabTypeBuilder(0, '支出'))
              TabContent() {
                Column().width('100%').height(0)
              }.tabBar(this.tabTypeBuilder(1, '收入'))
              TabContent() {
                Column().width('100%').height(0)
              }.tabBar(this.tabTypeBuilder(2, '转账'))
              TabContent() {
                Column().width('100%').height(0)
              }.tabBar(this.tabTypeBuilder(3, '拆分'))
            }
            .width('100%')
            .height($r('app.float.native_touch_target'))
            .barHeight($r('app.float.native_touch_target'))
            .scrollable(false)
            .animationDuration(150)
            .onChange((index: number) => {
              this.typeIndex = index;
              if (index === 0) {
                this.isIncome = false;
                this.operationType = OperationType.TRANSACTION;
              } else if (index === 1) {
                this.isIncome = true;
                this.operationType = OperationType.TRANSACTION;
              } else if (index === 2) {
                this.operationType = OperationType.TRANSFER;
              } else {
                this.operationType = OperationType.SPLIT;
              }
            })
          }

          // 模板标题（模板编辑模式显示，对齐安卓模板标题）
          if (this.isTemplate) {
            Row() {
              Text('标题')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              TextInput({ placeholder: '模板标题', text: this.templateTitle })
                .layoutWeight(1)
                .textAlign(TextAlign.End)
                .onChange((v: string) => {
                  this.templateTitle = v;
                })
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 账户
          Row() {
            Text('账户')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.accountLabel())
              .fontSize(16)
              .layoutWeight(1)
            Select(this.accountOptions())
              .selected(this.accountIndex())
              .onSelect((index: number) => {
                this.accountId = this.accounts[index].id;
                this.currencyCode = this.accounts[index].currency;
                this.amountInput = '';
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 转账目标账户
          if (this.operationType === OperationType.TRANSFER) {
            Row() {
              Text('至')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Text(this.transferAccountLabel())
                .fontSize(16)
                .layoutWeight(1)
              Select(this.transferAccountOptions())
                .selected(this.transferAccountIndex())
                .onSelect((index: number) => {
                  this.transferAccountId = this.transferAccounts()[index].id;
                })
            }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 单一布尔选项直接使用原生 Switch，不再放入大型操作弹窗。
          if (!this.isTemplate) {
            Row() {
              Text('原始金额')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .layoutWeight(1)
              Text(this.showOriginalAmount ? '已显示' : '已隐藏')
                .fontSize(13)
                .fontColor($r('app.color.textSecondary'))
                .margin({ right: 8 })
              Toggle({ type: ToggleType.Switch, isOn: this.showOriginalAmount })
                .selectedColor($r('app.color.primaryColor'))
                .accessibilityText(this.showOriginalAmount ? '隐藏原始金额' : '显示原始金额')
                .onChange(() => {
                  this.toggleOriginalAmount();
                })
            }
            .width('100%')
            .height($r('app.float.native_touch_target'))
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 原始金额（showOriginalAmount 时显示）
          Row() {
            Text('原始金额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '0.00', text: this.originalAmountInput })
              .type(InputType.NUMBER_DECIMAL)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .onChange((v: string) => {
                this.originalAmountInput = v;
              })
          }
          .visibility((this.showOriginalAmount && !this.isTemplate) ? Visibility.Visible : Visibility.None)
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 金额
          Row() {
            Text('金额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            // 收入/支出类型开关（对齐安卓 type_switch：支出态粉 #F75986，收入态绿）
            Toggle({ type: ToggleType.Switch, isOn: this.isIncome })
              .selectedColor(this.isIncome ? $r('app.color.colorIncome') : '#F75986')
              .switchPointColor(Color.White)
              .onChange((isOn: boolean) => {
                this.isIncome = isOn;
              })
            Text(this.isIncome ? '+' : '−')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isIncome ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
              .margin({ left: 4 })
            Text(this.currencySymbol())
              .fontSize(16)
              .fontColor($r('app.color.textSecondary'))
              .margin({ left: 6, right: 6 })
            TextInput({ placeholder: '0.00', text: this.amountInput })
              .type(InputType.NUMBER_DECIMAL)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .onChange((v: string) => {
                this.amountInput = v;
              })
            // 计算器按钮（对齐安卓金额计算器）
            Image($r('app.media.ic_calculator'))
              .width(16)
              .height(16)
              .margin({ left: 6 })
              .fillColor($r('app.color.textSecondary'))
              .onClick(() => {
                this.showCalculator();
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 拆分部分列表（拆分模式下显示）
          if (this.operationType === OperationType.SPLIT) {
            Column() {
              Text('拆分款项')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('100%')
                .padding({ left: 16, right: 16, top: 10 })

              ForEach(this.splitParts, (part: Transaction, index: number) => {
                Column() {
                  Row() {
                    Text(`${part.categoryPath || '未分类'}`)
                      .fontSize(14)
                      .layoutWeight(1)
                    Text(`${this.currencySymbol()}${formatMoney(part.amount, this.fractionDigits())}`)
                      .fontSize(14)
                      .fontColor(this.splitAmountColor(part.amount))
                    Button() {
                      Image(this.expandedSplitPartIndex === index ? $r('sys.media.ohos_ic_public_arrow_up') :
                        $r('sys.media.ohos_ic_public_edit'))
                        .width(18)
                        .height(18)
                        .fillColor(this.expandedSplitPartIndex === index ? $r('app.color.primaryColor') :
                          $r('app.color.iconSecondary'))
                    }
                      .type(ButtonType.Circle)
                      .width($r('app.float.native_touch_target'))
                      .height($r('app.float.native_touch_target'))
                      .margin({ left: 4 })
                      .backgroundColor(this.expandedSplitPartIndex === index ?
                        $r('app.color.surfaceBrandSoft') : Color.Transparent)
                      .accessibilityText(this.expandedSplitPartIndex === index ? '收起拆分项操作' : '编辑拆分项')
                      .onClick(() => {
                        this.editSplitPart(index);
                      })
                  }
                  .width('100%')
                  .height(44)
                  .padding({ left: 16, right: 16 })

                  if (this.expandedSplitPartIndex === index) {
                    this.splitPartActionsPanel(part, index)
                  }

                  // 拆分项标签（有标签时显示，点击可修改）
                  if (part.tagIds.length > 0) {
                    Row() {
                      Text('标签')
                        .fontSize(12)
                        .fontColor($r('app.color.textSecondary'))
                      ForEach(part.tagIds, (tagId: number) => {
                        Text(this.tagLabel(tagId))
                          .fontSize(12)
                          .fontColor(Color.White)
                          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                          .backgroundColor($r('app.color.primaryColor'))
                          .borderRadius(8)
                          .margin({ left: 6 })
                      }, (tagId: number) => `ptag_${index}_${tagId}`)
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, bottom: 6 })
                    .alignItems(VerticalAlign.Center)
                  }
                }
                .width('100%')
                .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
              }, (part: Transaction, index: number) => `part_${index}_${part.tagIds.join('_')}`)

              // 添加子交易
              Button('+ 添加拆分项')
                .width('100%')
                .height(44)
                .margin({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor($r('app.color.primaryContainer'))
                .fontColor($r('app.color.primaryColor'))
                .fontSize(14)
                .onClick(() => {
                  this.addSplitPart();
                })
            }
            .width('100%')
          }

          // 日期 / 时间（对齐安卓：同行两个按钮，左侧"日期 / 时间"标签；模板模式隐藏）
          Row() {
            Text('日期 / 时间')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            // 日期按钮（对齐安卓 date 按钮）
            Row() {
              Text(formatDate(this.date))
                .fontSize(16)
                .fontColor($r('app.color.textPrimary'))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            }
            .backgroundColor($r('app.color.cardBackgroundColor'))
            .borderRadius(6)
            .margin({ right: 8 })
            .onClick(() => {
              this.showDatePicker();
            })
            // 时间按钮（对齐安卓 time 按钮）
            Row() {
              Text(formatTime(this.date))
                .fontSize(16)
                .fontColor($r('app.color.textPrimary'))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            }
            .backgroundColor($r('app.color.cardBackgroundColor'))
            .borderRadius(6)
            .onClick(() => {
              this.showTimePicker();
            })
            Blank()
          }
          .visibility(this.isTemplate ? Visibility.None : Visibility.Visible)
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 收款人/付款人（转账模板隐藏；对齐安卓 PayeeLabel：收入显示"付款人"，支出显示"收款人"）
          if (this.operationType !== OperationType.TRANSFER) {
            Row() {
              Text(this.isIncome ? '付款人' : '收款人')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              TextInput({ placeholder: this.isIncome ? '付款人' : '收款人', text: this.payeeInput })
                .layoutWeight(1)
                .onChange((v: string) => {
                  this.payeeInput = v;
                })
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 类别（拆分父项/转账模板隐藏，对齐安卓：拆分固定拆分类别、转账默认隐藏类别）
          if (this.operationType !== OperationType.SPLIT && this.operationType !== OperationType.TRANSFER) {
            Row() {
              Text('类别')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Text(this.selectedCategoryLabel || '选择')
                .fontSize(16)
                .fontColor(this.selectedCategoryId >= 0 ? $r('app.color.textPrimary') : $r('app.color.textSecondary'))
                .layoutWeight(1)
              Image($r('sys.media.ohos_ic_public_arrow_right'))
                .width(16)
                .height(16)
                .opacity(0.4)
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
            .onClick(() => {
              this.navigateCategorySelect();
            })
          }



          // 标签行（对齐安卓 tag_row：左侧标签、中间ChipGroup、右侧加号，位于类别后）
          Row() {
            Text('标签')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')

            // 已选标签（对齐安卓 ChipGroup）
            if (this.tagIds.length === 0) {
              Text('选择标签')
                .fontSize(16)
                .fontColor($r('app.color.textSecondary'))
                .layoutWeight(1)
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.tagIds, (tagId: number) => {
                  this.tagChip(tagId)
                })
              }
              .layoutWeight(1)
            }

            // 加号按钮（对齐安卓 TagSelection：跳转到"创建或选择标签"）
            Image($r('sys.media.ohos_ic_public_add'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.primaryColor'))
              .onClick(() => {
                this.navigateToTagSelection();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 付款方法（转账隐藏；模板模式下仅拆分模板显示，对齐安卓：交易/转账模板无付款方法）
          Row() {
            Text('付款方法')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.methodName(this.methodId))
              .fontSize(16)
              .layoutWeight(1)
            Select(this.methodOptions())
              .selected(this.methods.findIndex((m: PaymentMethod) => m.id === this.methodId))
              .onSelect((index: number) => {
                this.methodId = this.methods[index].id;
              })
          }
          .visibility((this.operationType === OperationType.TRANSFER ||
            (this.isTemplate && this.operationType !== OperationType.SPLIT)) ? Visibility.None : Visibility.Visible)
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 备注
          Row() {
            Text('备注')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '备注', text: this.comment })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.comment = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 附件（对齐安卓 attach；模板模式隐藏）
          Row() {
            Text('附件')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            if (this.attachmentUris.length === 0) {
              Text('添加附件')
                .fontSize(16)
                .fontColor($r('app.color.textSecondary'))
                .layoutWeight(1)
            } else {
              // 附件缩略图横排（对齐安卓缩略图预览）
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.attachmentUris, (uri: string, index: number) => {
                  Stack() {
                    Image(uri)
                      .width(44)
                      .height(44)
                      .borderRadius(6)
                      .objectFit(ImageFit.Cover)
                    Image($r('sys.media.ohos_ic_public_close'))
                      .width(14)
                      .height(14)
                      .position({ x: 30, y: 0 })
                      .opacity(0.8)
                      .onClick(() => {
                        this.attachmentUris.splice(index, 1);
                        this.attachmentUris = [...this.attachmentUris];
                      })
                  }
                  .width(44)
                  .height(44)
                  .margin({ right: 6, bottom: 6 })
                }, (uri: string, index: number) => `att_${index}_${uri}`)
              }
              .layoutWeight(1)
            }
            Button() {
              Image(this.attachmentSourcesExpanded ? $r('sys.media.ohos_ic_public_arrow_up') :
                $r('app.media.ic_attachment'))
                .width(20)
                .height(20)
                .fillColor(this.attachmentSourcesExpanded ? $r('app.color.primaryColor') :
                  $r('app.color.iconSecondary'))
            }
              .type(ButtonType.Circle)
              .width($r('app.float.native_touch_target'))
              .height($r('app.float.native_touch_target'))
              .backgroundColor(this.attachmentSourcesExpanded ?
                $r('app.color.surfaceBrandSoft') : Color.Transparent)
              .accessibilityText(this.attachmentSourcesExpanded ? '收起附件来源' : '添加附件')
              .onClick(() => {
                this.attachmentSourcesExpanded = InlineExpansionState.toggle(this.attachmentSourcesExpanded);
              })
          }
          .visibility(this.isTemplate ? Visibility.None : Visibility.Visible)
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          if (!this.isTemplate && this.attachmentSourcesExpanded) {
            this.attachmentSourcePanel()
          }

          // 位置（对齐安卓 Android 位置记录；模板模式隐藏）
          Row() {
            Text('位置')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.latitude === 0 && this.longitude === 0 ? '未设置' : `${this.latitude.toFixed(4)}, ${this.longitude.toFixed(4)}`)
              .fontSize(16)
              .fontColor(this.latitude === 0 && this.longitude === 0 ? $r('app.color.textSecondary') : $r('app.color.textPrimary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('设置')
              .fontSize(14)
              .fontColor($r('app.color.primaryColor'))
              .onClick(() => {
                this.setLocation();
              })
          }
          .visibility(this.isTemplate ? Visibility.None : Visibility.Visible)
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 模板默认操作（对齐安卓 DefaultActionRow：保存/编辑；仅模板模式显示）
          if (this.isTemplate) {
            Row() {
              Text('默认操作')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Select(this.defaultActionOptions())
                .selected(this.templateDefaultAction)
                .onSelect((index: number) => {
                  this.templateDefaultAction = index;
                })
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 模板计划（对齐安卓 PlanRow：无/一次性/每天/每周/每月/每年；仅模板模式显示）
          if (this.isTemplate) {
            Row() {
              Text('计划')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Select(this.templateRecurrenceOptions())
                .selected(this.templateRecurrence)
                .onSelect((index: number) => {
                  this.templateRecurrence = this.templateRecurrenceValues()[index];
                })
            }
            .width('100%')
            .height(48)
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
          }

          // 保存并新建（对齐安卓 Save and new；模板模式/从模板创建时隐藏——模板场景类型已定无需连续新建）
          if (!this.isTemplate && this.fromTemplateId <= 0) {
            Button('保存并新建')
              .width('100%')
              .height(48)
              .margin({ top: 16, left: 16, right: 16 })
              .backgroundColor($r('app.color.primaryContainer'))
              .fontColor($r('app.color.primaryColor'))
              .fontSize(16)
              .onClick(() => {
                this.saveAndNew();
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        .borderRadius($r('app.float.native_emphasis_radius'))
        .backgroundColor($r('app.color.surfacePrimary'))
      }
      .layoutWeight(1)
      .padding({ left: 12, right: 12, bottom: 76 })
      // 内容从页面顶部开始（对齐安卓 NestedScrollView 表单贴工具栏下方）
      // Scroll 默认 align 为 Center，内容高度小于视口时会被垂直居中，需显式顶部对齐
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))

    Button() {
      Image($r('app.media.ic_check'))
        .width(24)
        .height(24)
        .fillColor(Color.White)
    }
    .type(ButtonType.Capsule)
    .width(88)
    .height(52)
    .backgroundColor($r('app.color.primaryColor'))
    .stateEffect(true)
    .shadow({ radius: 6, color: '#26000000', offsetY: 3 })
    .accessibilityText(this.isTemplate ? '保存模板' : '保存交易')
    .markAnchor({ x: '100%', y: '100%' })
    .position({ x: '92%', y: '94%' })
    .onClick(() => {
      this.save();
    })
    }
  }

  /**
   * 标签Chip（对齐安卓 Chip）
   */
  @Builder
  tagChip(tagId: number) {
    Row() {
      Text(this.getTagLabel(tagId))
        .fontSize(13)
        .fontColor($r('app.color.textPrimary'))
        .padding({ left: 10, right: 10 })
    }
    .height(28)
    .borderRadius(14)
    .backgroundColor($r('app.color.chipBackground'))
    .margin({ right: 6, bottom: 4 })
  }

  /**
   * 获取标签名称
   */
  private getTagLabel(tagId: number): string {
    const tag = this.tags.find(t => t.id === tagId);
    return tag ? tag.label : '';
  }

  /** 获取新建模板标题（根据operationType动态变化） */
  private getTemplateCreateTitle(): string {
    if (this.operationType === OperationType.TRANSFER) {
      return '新建转账模板';
    } else if (this.operationType === OperationType.SPLIT) {
      return '新建分账模板';
    } else {
      return '新建交易模板';
    }
  }

  /** 获取编辑模板标题（根据operationType动态变化） */
  private getTemplateEditTitle(): string {
    if (this.operationType === OperationType.TRANSFER) {
      return '编辑转账模板';
    } else if (this.operationType === OperationType.SPLIT) {
      return '编辑分账模板';
    } else {
      return '编辑交易模板';
    }
  }

  /** 模板类型切换菜单（对齐安卓：交易模板/转账模板/拆分模板，左上角标题下拉就近展开） */
  private templateTypeMenu(): Array<MenuElement> {
    return [
      {
        value: (this.operationType !== OperationType.TRANSFER && this.operationType !== OperationType.SPLIT ? '✓ ' : '') + '交易模板',
        action: () => {
          this.typeIndex = this.isIncome ? 1 : 0;
          this.operationType = OperationType.TRANSACTION;
        }
      } as MenuElement,
      {
        value: (this.operationType === OperationType.TRANSFER ? '✓ ' : '') + '转账模板',
        action: () => {
          this.typeIndex = 2;
          this.operationType = OperationType.TRANSFER;
        }
      } as MenuElement,
      {
        value: (this.operationType === OperationType.SPLIT ? '✓ ' : '') + '拆分模板',
        action: () => {
          this.typeIndex = 3;
          this.operationType = OperationType.SPLIT;
        }
      } as MenuElement
    ];
  }

  /** 模板默认操作选项（对齐安卓 Template.Action：保存/编辑） */
  private defaultActionOptions(): SelectOption[] {
    return [
      { value: '保存' } as SelectOption,
      { value: '编辑' } as SelectOption
    ];
  }

  /** 模板计划选项（对齐安卓 Recurrence） */
  private templateRecurrenceOptions(): SelectOption[] {
    return [
      { value: '无计划' } as SelectOption,
      { value: '一次性活动' } as SelectOption,
      { value: '每天' } as SelectOption,
      { value: '每周' } as SelectOption,
      { value: '每月' } as SelectOption,
      { value: '每年' } as SelectOption,
      { value: '自定义' } as SelectOption
    ];
  }

  /** 计划选项对应枚举值（对齐安卓 Recurrence：NONE/ONETIME/DAILY/WEEKLY/MONTHLY/YEARLY/CUSTOM） */
  private templateRecurrenceValues(): number[] {
    return [0, 1, 2, 3, 4, 6, 7];
  }

  @Builder
  tabTypeBuilder(tabIndex: number, label: string) {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.typeActive(tabIndex) ? $r('app.color.primaryColor') : $r('app.color.textSecondary'))
      .width('100%')
      .height('100%')
      .textAlign(TextAlign.Center)
  }

  private typeActive(tabIndex: number): boolean {
    if (tabIndex === 0) {
      return !this.isIncome && this.operationType !== OperationType.TRANSFER && this.operationType !== OperationType.SPLIT;
    }
    if (tabIndex === 1) {
      return this.isIncome && this.operationType !== OperationType.TRANSFER && this.operationType !== OperationType.SPLIT;
    }
    if (tabIndex === 2) {
      return this.operationType === OperationType.TRANSFER;
    }
    return this.operationType === OperationType.SPLIT;
  }
}

/**
 * 我的模板选择对话框（对齐安卓 toolbar 我的模板：选择模板填充当前交易）
 */
@CustomDialog
struct TemplateSelectDialog {
  controller?: CustomDialogController;
  templates: Template[] = [];
  onSelect: (tpl: Template) => void = () => {
  };
  onCancel: () => void = () => {
  };

  build() {
    Column() {
      Text('我的模板')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.textPrimary'))
        .margin({ bottom: 8 })

      if (this.templates.length === 0) {
        Text('暂无可用模板')
          .width('100%')
          .height(96)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontColor($r('app.color.textSecondary'))
      } else {
        List() {
          ForEach(this.templates, (tpl: Template) => {
            ListItem() {
              Row() {
                Text(tpl.title)
                  .fontSize(16)
                  .fontColor($r('app.color.textPrimary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${tpl.isIncome ? '+' : '-'}${formatMoney(Math.abs(tpl.amount), 2)} ${tpl.isIncome ? '收入' : '支出'}`)
                  .fontSize(14)
                  .fontColor($r('app.color.textSecondary'))
              }
              .width('100%')
              .height(56)
              .padding({ left: 24, right: 24 })
              .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
              .onClick(() => {
                this.onSelect(tpl);
              })
            }
          }, (tpl: Template) => `tpl_${tpl.id}`)
        }
        .width('100%')
        .height(Math.min(this.templates.length * 56, 360))
      }

      Button('取消')
      .width('100%')
      .height($r('app.float.native_touch_target'))
      .backgroundColor(Color.Transparent)
      .fontSize(16)
      .fontColor($r('app.color.textSecondary'))
      .stateEffect(true)
      .onClick(() => {
        this.onCancel();
      })
    }
    .width('100%')
    .padding({ top: 20, bottom: 12 })
    .backgroundColor($r('app.color.cardBackgroundColor'))
  }
}
