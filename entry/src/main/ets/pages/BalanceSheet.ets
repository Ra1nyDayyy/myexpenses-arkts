import { Account, AccountType } from '../model/Account';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';
import { buildImagePdf, base64DataUrlToBytes } from '../common/PdfGenerator';

/**
 * 资产负债表：对齐 Android activity/BalanceSheet.kt
 * - 章节头：资产 / 负债 / 净资产（大标题加粗 + 总额，颜色随正负 income/expense）
 * - 类型小节：按账户类型分组（类型名 + 该类型总额，titleMedium 加粗）
 * - 账户行：账户名 + 余额（显示绝对值，资产绿色/负债红色，对齐安卓 ColoredAmountText）
 * - 日期右上角带下划线，点击弹出日期选择器
 * - 右上角设置菜单（对齐安卓 BalanceSheetOptions）：导出 PDF / 显示隐藏账户 / 显示零余额账户
 */
@Entry
@Component
struct BalanceSheet {
  @State accounts: Account[] = [];
  @State assets: number = 0;
  @State liabilities: number = 0;
  @State netWorth: number = 0;
  @State showHidden: boolean = false;
  @State showZero: boolean = false;
  @State exporting: boolean = false;
  date: number = Math.floor(Date.now() / 1000);

  private repository: Repository = Repository.getInstance();

  aboutToAppear(): void {
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.accounts = await this.repository.getAccounts();
    let assets = 0;
    let liabilities = 0;
    for (let acc of this.accounts) {
      if (acc.excludeFromTotals) {
        continue;
      }
      if (acc.type === AccountType.CCARD || acc.type === AccountType.LIABILITY) {
        liabilities += acc.currentBalance;
      } else {
        assets += acc.currentBalance;
      }
    }
    this.assets = assets;
    this.liabilities = liabilities;
    this.netWorth = assets + liabilities;

  }

  /** 主货币（对齐安卓 homeCurrencyUnit，鸿蒙无汇率换算，取首个账户货币） */
  private homeCurrency(): string {
    return this.accounts.length > 0 ? this.accounts[0].currency : 'CNY';
  }

  private symbol(): string {
    return currencyByCode(this.homeCurrency()).symbol;
  }

  /** 资产类型小节顺序（固定顺序保证展示稳定，对齐安卓 partitionByAccountType） */
  private assetSections(): AccountType[] {
    return [AccountType.BANK, AccountType.CASH, AccountType.ASSET]
      .filter((t: AccountType) => this.sectionAccounts(t).length > 0);
  }

  private liabilitySections(): AccountType[] {
    return [AccountType.CCARD, AccountType.LIABILITY]
      .filter((t: AccountType) => this.sectionAccounts(t).length > 0);
  }

  /** 某类型的可见账户（对齐安卓 showHidden/showZero 过滤 + excludeFromTotals） */
  private sectionAccounts(type: AccountType): Account[] {
    return this.accounts.filter((a: Account) =>
      a.type === type &&
      !a.excludeFromTotals &&
      (this.showHidden || !a.sealed) &&
      (this.showZero || a.currentBalance !== 0));
  }

  private sectionTotal(type: AccountType): number {
    let sum = 0;
    for (let a of this.sectionAccounts(type)) {
      sum += a.currentBalance;
    }
    return sum;
  }

  private hasHiddenAccounts(): boolean {
    return this.accounts.some((a: Account) => a.sealed);
  }

  private hasZeroAccounts(): boolean {
    return this.accounts.some((a: Account) => a.currentBalance === 0 && !a.excludeFromTotals);
  }

  /** 金额显示：absolute=true 时显示绝对值（资产绿/负债红）；false 显示实际值（净资产可负） */
  private amountText(amount: number, absolute: boolean): string {
    const v = absolute ? Math.abs(amount) : amount;
    const sign = v < 0 ? '-' : '';
    return `${sign}${this.symbol()}${formatMoney(Math.abs(v), 2)}`;
  }

  private showDatePicker(): void {
    const current = new Date(this.date * 1000);
    const pickerOptions: DatePickerDialogOptions = {
      start: new Date(current.getFullYear() - 10, 0, 1),
      end: new Date(current.getFullYear() + 10, 11, 31),
      selected: current,
      onDateAccept: (value: Date) => {
        this.date = Math.floor(value.getTime() / 1000 / 86400) * 86400;
      }
    };
    this.getUIContext().showDatePickerDialog(pickerOptions);
  }

  /** 右上角设置菜单（对齐安卓 BalanceSheetOptions） */
  private showOptionsMenu(): void {
    const sheets: Array<SheetInfo> = [];
    sheets.push({
      title: '导出为 PDF',
      action: () => {
        this.exportToPdf();
      }
    } as SheetInfo);
    if (this.hasHiddenAccounts()) {
      sheets.push({
        title: (this.showHidden ? '✓ ' : '') + '显示隐藏账户',
        action: () => {
          this.showHidden = !this.showHidden;
        }
      } as SheetInfo);
    }
    if (this.hasZeroAccounts()) {
      sheets.push({
        title: (this.showZero ? '✓ ' : '') + '显示零余额账户',
        action: () => {
          this.showZero = !this.showZero;
        }
      } as SheetInfo);
    }
    const options: ActionSheetOptions = {
      title: '资产负债表',
      message: '请选择操作',
      confirm: {
        value: '取消',
        action: () => {
        }
      },
      sheets: sheets
    };
    this.getUIContext().showActionSheet(options);
  }

  // ==================== PDF 导出（Canvas 渲染 + 手动构造 PDF，兼容纯 OpenHarmony） ====================
  // 说明：@kit.PDFKit 底层为 HMS 专属服务，OpenHarmony 模拟器不可用；改用 Canvas 渲染
  // 资产负债表为 JPEG，再用 PdfGenerator 构造内嵌图片的 PDF，中文字体由 Canvas 系统字体渲染。

  private dateStamp(): string {
    const d = new Date(this.date * 1000);
    const mm = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    return `${d.getFullYear()}-${mm}-${dd}`;
  }

  /** 用离屏 Canvas 渲染资产负债表为 JPEG 字节（A4 @ 150DPI = 1240x1754） */
  private renderSheetImage(): Uint8Array {
    const W = 1240;
    const H = 1754;
    const canvas = new OffscreenCanvas(W, H);
    const ctx = canvas.getContext('2d');

    // 白底
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, W, H);
    ctx.textBaseline = 'top';

    const left = 80;
    const right = 1160;
    let y = 60;

    // 标题 + 日期（居中）
    ctx.textAlign = 'center';
    ctx.fillStyle = '#000000';
    ctx.font = 'bold 44px sans-serif';
    ctx.fillText('资产负债表', 620, y);
    y += 60;
    ctx.font = '26px sans-serif';
    ctx.fillStyle = '#808080';
    ctx.fillText(formatDate(this.date), 620, y);
    y += 60;

    // 分隔线
    ctx.strokeStyle = '#CCCCCC';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(left, y);
    ctx.lineTo(right, y);
    ctx.stroke();
    y += 34;

    // 资产章节
    y = this.drawChapter(ctx, y, left, right, '资产', this.assets, true);
    for (const t of this.assetSections()) {
      y = this.drawTypeSection(ctx, y, left, right, t, true);
    }
    y = this.drawDivider(ctx, y, left, right);

    // 负债章节
    y = this.drawChapter(ctx, y, left, right, '负债', this.liabilities, false);
    for (const t of this.liabilitySections()) {
      y = this.drawTypeSection(ctx, y, left, right, t, false);
    }
    y = this.drawDivider(ctx, y, left, right);

    // 净资产（非绝对值，可为负）
    y = this.drawChapter(ctx, y, left, right, '净资产', this.netWorth, this.netWorth >= 0);

    const dataUrl = ctx.toDataURL('image/jpeg', 0.92);
    return base64DataUrlToBytes(dataUrl);
  }

  /** 绘制章节头：label 左、金额右（资产绿 / 负债红） */
  private drawChapter(ctx: OffscreenCanvasRenderingContext2D, y: number, left: number, right: number,
    title: string, total: number, positive: boolean): number {
    ctx.textAlign = 'left';
    ctx.fillStyle = '#000000';
    ctx.font = 'bold 32px sans-serif';
    ctx.fillText(title, left, y);
    ctx.textAlign = 'right';
    ctx.fillStyle = positive ? '#006800' : '#800000';
    ctx.fillText(this.amountText(total, true), right, y);
    return y + 48;
  }

  /** 绘制类型小节 + 账户行 */
  private drawTypeSection(ctx: OffscreenCanvasRenderingContext2D, y: number, left: number, right: number,
    type: AccountType, isAsset: boolean): number {
    const color = isAsset ? '#006800' : '#800000';
    ctx.textAlign = 'left';
    ctx.fillStyle = '#000000';
    ctx.font = 'bold 28px sans-serif';
    ctx.fillText(Account.typeName(type), left + 80, y);
    ctx.textAlign = 'right';
    ctx.fillStyle = color;
    ctx.fillText(this.amountText(this.sectionTotal(type), true), right, y);
    y += 40;
    ctx.font = '26px sans-serif';
    for (const acc of this.sectionAccounts(type)) {
      ctx.textAlign = 'left';
      ctx.fillStyle = '#000000';
      ctx.fillText(acc.label, left + 150, y);
      ctx.textAlign = 'right';
      ctx.fillStyle = color;
      ctx.fillText(this.amountText(acc.currentBalance, true), right, y);
      y += 36;
    }
    return y;
  }

  private drawDivider(ctx: OffscreenCanvasRenderingContext2D, y: number, left: number, right: number): number {
    y += 8;
    ctx.strokeStyle = '#CCCCCC';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(left, y);
    ctx.lineTo(right, y);
    ctx.stroke();
    return y + 34;
  }

  /** 生成 PDF 并引导用户选择保存位置 */
  private async exportToPdf(): Promise<void> {
    if (this.exporting) {
      return;
    }
    this.exporting = true;
    try {
      const jpeg = this.renderSheetImage();
      const pageWidth = 595; // A4 宽（pt）
      const pageHeight = 842; // A4 高（pt）
      const pdf = buildImagePdf(jpeg, 1240, 1754, pageWidth, pageHeight);

      // 保存到应用沙箱
      const ctx = getContext(this) as common.UIAbilityContext;
      const tempPath = `${ctx.filesDir}/BalanceSheet_${this.dateStamp()}.pdf`;
      const file = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, pdf.buffer as ArrayBuffer);
      fs.closeSync(file.fd);

      // 引导用户选择保存位置（对齐安卓创建文件）
      const savePicker = new picker.DocumentViewPicker(ctx);
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [`资产负债表_${this.dateStamp()}.pdf`];
      const uris = await savePicker.save(opts);
      if (uris && uris.length > 0) {
        await fs.copyFile(tempPath, uris[0]);
        promptAction.showToast({ message: '已导出 PDF' });
      } else {
        promptAction.showToast({ message: '已取消导出' });
      }
    } catch (err) {
      console.error(`[BalanceSheet] export pdf error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '导出 PDF 失败' });
    } finally {
      this.exporting = false;
    }
  }

  // ==================== UI ====================

  build() {
    Column() {
      PageHeader({
        title: '资产负债表',
        showMore: true,
        onBack: () => {
          router.back();
        },
        onMore: () => {
          this.showOptionsMenu();
        }
      })

      Scroll() {
        Column() {
          // 日期（右上角带下划线，对齐安卓）
          Row() {
            Blank()
            Text(formatDate(this.date))
              .fontSize(14)
              .fontColor($r('app.color.primaryColor'))
              .decoration({ type: TextDecorationType.Underline, color: $r('app.color.primaryColor') })
              .padding({ right: 16 })
              .onClick(() => {
                this.showDatePicker();
              })
          }
          .width('100%')
          .padding({ top: 6, bottom: 2 })

          Column({ space: 0 }) {
            // 资产章节（对齐安卓 BalanceSheetSectionHeaderView）
            this.chapterHeader('资产', true)
            // 各资产类型小节
            ForEach(this.assetSections(), (type: AccountType) => {
              this.typeSection(type, true)
            }, (type: AccountType) => `asset_section_${type}`)

            Divider()
              .color($r('app.color.dividerColor'))
              .strokeWidth(0.5)
              .margin({ top: 6, bottom: 6 })

            // 负债章节
            this.chapterHeader('负债', false)
            ForEach(this.liabilitySections(), (type: AccountType) => {
              this.typeSection(type, false)
            }, (type: AccountType) => `liab_section_${type}`)

            Divider()
              .color($r('app.color.dividerColor'))
              .strokeWidth(0.5)
              .margin({ top: 6, bottom: 6 })

            // 净资产（非绝对值，可为负）
            this.chapterHeader('净资产', this.netWorth >= 0)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.pageBackground'))
  }

  /** 章节头：大标题加粗 + 总额（对齐安卓 BalanceSheetSectionHeaderView titleLarge Bold）
   *  注意：金额必须从 @State 直接读取（@Builder 按值传参不会随 @State 更新刷新），
   *  故不通过参数传入 total，而是在内部按 name 直接读取 this.assets/liabilities/netWorth */
  @Builder
  chapterHeader(name: string, positive: boolean) {
    Row() {
      Text(name)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(this.amountText(name === '资产' ? this.assets : (name === '负债' ? this.liabilities : this.netWorth), false))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(positive ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
    }
    .width('100%')
    .padding({ top: 10, bottom: 8 })
  }

  /** 类型小节：类型名（titleMedium 加粗）+ 该类型总额 + 账户行 */
  @Builder
  typeSection(type: AccountType, isAsset: boolean) {
    Column() {
      Row() {
        Text(Account.typeName(type))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(this.amountText(this.sectionTotal(type), true))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(isAsset ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
      }
      .width('100%')
      .padding({ top: 2, bottom: 2 })

      ForEach(this.sectionAccounts(type), (acc: Account) => {
        Row() {
          Text(acc.label)
            .fontSize(14)
            .layoutWeight(1)
          Text(this.amountText(acc.currentBalance, true))
            .fontSize(14)
            .fontColor(isAsset ? $r('app.color.colorIncome') : $r('app.color.colorExpense'))
        }
        .width('100%')
        .padding({ top: 3, bottom: 3 })
      }, (acc: Account) => `acc_${type}_${acc.id}`)
    }
    .width('100%')
  }
}
