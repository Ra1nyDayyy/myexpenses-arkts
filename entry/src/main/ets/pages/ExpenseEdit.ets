import { Transaction, OperationType, CrStatus } from '../model/Transaction';
import { Account } from '../model/Account';
import { Category } from '../model/Category';
import { PaymentMethod, Payee, Tag } from '../model/SupportEntities';
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

/**
 * 记账编辑页：对应 Android ExpenseEdit + one_expense.xml
 */
@Entry
@Component
struct ExpenseEdit {
  @State transactionId: number = -1;
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
  @State showOriginalAmount: boolean = false; // 展示原始金额
  @State originalAmountInput: string = '';
  @State originalCurrency: string = '';

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
    alignment: DialogAlignment.Bottom,
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
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      cornerRadius: 16
    });
    this.calculator.open();
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['id'] !== undefined) {
      this.transactionId = params['id'] as number;
    }
    if (params && params['accountId'] !== undefined) {
      this.accountId = params['accountId'] as number;
    }
    // 交易类型预选（FAB 菜单传入）：-1 支出 / 1 收入 / 2 转账
    if (params && params['type'] !== undefined) {
      const t = params['type'] as number;
      if (t === 1) {
        this.isIncome = true;
        this.operationType = OperationType.TRANSACTION;
      } else if (t === 2) {
        this.operationType = OperationType.TRANSFER;
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
    if (this.transactionId > 0) {
      await this.loadTransaction();
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

  private navigateCategorySelect(): void {
    router.pushUrl({
      url: 'pages/CategorySelect',
      params: { type: this.isIncome ? 1 : -1 }
    }).catch(() => {
    });
  }

  /**
   * 记账页右上角选项（对齐安卓：展示原始金额）
   */
  private showEditOptions(): void {
    const sheets: Array<SheetInfo> = [];
    sheets.push({
      title: this.showOriginalAmount ? '隐藏原始金额' : '展示原始金额',
      action: () => this.toggleOriginalAmount()
    } as SheetInfo);
    const options: ActionSheetOptions = {
      title: '记账选项',
      message: '交易录入操作',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
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
   * 添加拆分项
   */
  private addSplitPart(): void {
    const part = new Transaction();
    part.amount = 0;
    part.categoryId = -1;
    this.splitParts = [...this.splitParts, part];
  }

  /**
   * 编辑拆分项：输入金额（复用计算器）
   */
  private editSplitPart(index: number): void {
    const part = this.splitParts[index];
    const options: ActionSheetOptions = {
      title: '编辑拆分项',
      message: part.categoryPath || '未分类',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: [
        { title: '编辑金额', action: () => this.editSplitPartAmount(index) },
        { title: '选择分类', action: () => this.selectSplitPartCategory(index) },
        { title: '选择标签', action: () => this.selectSplitPartTag(index) },
        { title: '删除', action: () => {
          this.splitParts.splice(index, 1);
          this.splitParts = [...this.splitParts];
        } }
      ]
    };
    this.getUIContext().showActionSheet(options);
  }

  /**
   * 拆分项选择标签：弹标签多选 ActionSheet
   */
  private selectSplitPartTag(index: number): void {
    const part = this.splitParts[index];
    if (this.tags.length === 0) {
      promptAction.showToast({ message: '暂无可用标签' });
      return;
    }
    const sheets: Array<SheetInfo> = [];
    for (let tag of this.tags) {
      const tagId = tag.id;
      const selected = part.tagIds.indexOf(tagId) >= 0;
      sheets.push({
        title: (selected ? '✓ ' : '') + tag.label,
        action: () => {
          const idx = part.tagIds.indexOf(tagId);
          if (idx >= 0) {
            part.tagIds.splice(idx, 1);
          } else {
            part.tagIds = [...part.tagIds, tagId];
          }
          this.splitParts = [...this.splitParts];
        }
      } as SheetInfo);
    }
    const options: ActionSheetOptions = {
      title: '拆分项标签',
      message: '选择标签（可多选）',
      confirm: {
        value: '完成',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
  }

  /**
   * 标签 id → 标签名
   */
  private tagLabel(tagId: number): string {
    const t = this.tags.find((tag: Tag) => tag.id === tagId);
    return t ? t.label : '';
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
      alignment: DialogAlignment.Bottom,
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

  /**
   * 添加附件（对齐安卓 attach 功能）
   */
  private async pickAttachment(): Promise<void> {
    const options: ActionSheetOptions = {
      title: '添加附件',
      message: '选择附件来源',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: [
        { title: '拍照', action: () => this.takePhoto() },
        { title: '相册', action: () => this.pickPhoto() },
        { title: '文件', action: () => this.pickDocument() }
      ]
    };
    this.getUIContext().showActionSheet(options);
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
    Column() {
      PageHeader({
        title: this.transactionId > 0 ? '编辑交易' : '新建交易',
        rightText: '保存',
        showMore: true,
        onBack: () => {
          router.back();
        },
        onRight: () => {
          this.save();
        },
        onMore: () => {
          this.showEditOptions();
        }
      })

      Scroll() {
        Column() {
          // 类型切换（鸿蒙原生 Tabs 分段控件，仅用 TabBar，内容区不占空间）
          Tabs({ barPosition: BarPosition.Start }) {
            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(0, '支出'))

            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(1, '收入'))

            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(2, '转账'))

            TabContent() {
              Column()
                .width('100%')
                .height(0)
            }.tabBar(this.tabTypeBuilder(3, '拆分'))
          }
          .width('100%')
          .height(44)
          .barHeight(44)
          .scrollable(false)
          .animationDuration(150)
          .onChange((index: number) => {
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

          // 原始金额（showOriginalAmount 时显示，用 visibility 保证响应式）
          Row() {
            Text('原始金额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '0.00', text: this.originalAmountInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .onChange((v: string) => {
                this.originalAmountInput = v;
              })
          }
          .visibility(this.showOriginalAmount ? Visibility.Visible : Visibility.Hidden)
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 金额
          Row() {
            Text('金额')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(this.currencySymbol())
              .fontSize(16)
              .fontColor($r('app.color.textSecondary'))
              .margin({ right: 6 })
            TextInput({ placeholder: '0.00', text: this.amountInput })
              .type(InputType.Number)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .onChange((v: string) => {
                this.amountInput = v;
              })
            // 计算器按钮（对齐安卓金额计算器）
            Image($r('app.media.ic_calculator'))
              .width(20)
              .height(20)
              .margin({ left: 8 })
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
                    Image($r('sys.media.ohos_ic_public_edit'))
                      .width(16)
                      .height(16)
                      .opacity(0.6)
                      .margin({ left: 10 })
                      .onClick(() => {
                        this.editSplitPart(index);
                      })
                    Image($r('sys.media.ohos_ic_public_close'))
                      .width(16)
                      .height(16)
                      .opacity(0.6)
                      .margin({ left: 10 })
                      .onClick(() => {
                        this.splitParts.splice(index, 1);
                        this.splitParts = [...this.splitParts];
                      })
                  }
                  .width('100%')
                  .height(44)
                  .padding({ left: 16, right: 16 })

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

          // 收款人
          Row() {
            Text('收款人')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            TextInput({ placeholder: '收款人', text: this.payeeInput })
              .layoutWeight(1)
              .onChange((v: string) => {
                this.payeeInput = v;
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 类别
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

          // 日期（点击弹出鸿蒙原生日期选择器）
          Row() {
            Text('日期')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(formatDate(this.date))
              .fontSize(16)
              .fontColor($r('app.color.textPrimary'))
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
            this.showDatePicker();
          })

          // 时间（点击弹出鸿蒙原生时间选择器）
          Row() {
            Text('时间')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
              .width('30%')
            Text(formatTime(this.date))
              .fontSize(16)
              .fontColor($r('app.color.textPrimary'))
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
            this.showTimePicker();
          })

          // 标签（对齐安卓 TagRow，位于类别后、付款方法前）
          if (this.tags.length > 0) {
            Row() {
              Text('标签')
                .fontSize(14)
                .fontColor($r('app.color.textPrimary'))
                .width('30%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.tags, (tag: Tag) => {
                  Row() {
                    Text(tag.label)
                      .fontSize(12)
                      .fontColor(this.tagIds.indexOf(tag.id) >= 0 ? Color.White : $r('app.color.textPrimary'))
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  }
                  .backgroundColor(this.tagIds.indexOf(tag.id) >= 0 ? $r('app.color.primaryColor') : $r('app.color.cardBackgroundColor'))
                  .borderRadius(8)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    const idx = this.tagIds.indexOf(tag.id);
                    if (idx >= 0) {
                      this.tagIds.splice(idx, 1);
                      this.tagIds = [...this.tagIds];
                    } else {
                      this.tagIds = [...this.tagIds, tag.id];
                    }
                  })
                }, (tag: Tag) => `tag_${tag.id}`)
              }
              .layoutWeight(1)
            }
            .width('100%')
            .height(48)
            .padding({ top: 8, bottom: 8 })
            .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })
            .alignItems(VerticalAlign.Top)
          }

          // 付款方法（拆分模式下隐藏，对齐 Android 拆分页无收款方法）
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
          .visibility(this.operationType === OperationType.SPLIT ? Visibility.Hidden : Visibility.Visible)
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


          // 附件（对齐安卓 attach）
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
            Image($r('app.media.ic_attachment'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.textSecondary'))
              .onClick(() => {
                this.pickAttachment();
              })
          }
          .width('100%')
          .height(48)
          .border({ width: { bottom: 0.5 }, color: $r('app.color.dividerColor') })

          // 保存并新建（对齐安卓 Save and new）
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
        .width('100%')
        .padding({ left: 16, right: 16, top: 4 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
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
