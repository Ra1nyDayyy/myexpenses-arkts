import { Account, AccountType } from '../model/Account';
import { Repository } from '../database/Repository';
import { PageHeader } from '../components/PageHeader';
import { router, promptAction, componentUtils } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { formatMoney } from '../model/Money';
import { currencyByCode } from '../model/CurrencyUnit';
import { formatDate } from '../common/FormatUtils';
import { buildImagePdf, base64DataUrlToBytes } from '../common/PdfGenerator';

/** 图表高亮信息（对齐安卓 Triple<Boolean, Int, Long?>：是否内环/环内索引/账户id） */
interface HighlightInfo {
  inner: boolean;
  index: number;
  id: number;
}

/** 双环几何参数（绘制与命中检测共用） */
interface ChartGeom {
  cx: number;
  cy: number;
  outerR: number;
  outerInnerR: number;
  innerR: number;
  innerInnerR: number;
}

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
  /** 显示双环甜甜圈图（对齐安卓 BalanceSheetOptions 图表开关） */
  @State showChart: boolean = false;
  /** 高亮的扇区：inner=是否负债环, index=环内索引, id=账户 id（对齐安卓 highlight: Triple<Boolean, Int, Long?>） */
  @State highlight: HighlightInfo | null = null;
  /** 图表 Canvas 尺寸（onReady 后更新，用于命中检测） */
  private chartWidth: number = 0;
  private chartHeight: number = 0;
  date: number = Math.floor(Date.now() / 1000);

  private repository: Repository = Repository.getInstance();
  private chartSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private chartContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.chartSettings);
  private scroller: Scroller = new Scroller();



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
    // 图表显示期间数据变化时同步重绘双环图
    if (this.showChart) {
      this.drawChart();
    }
  }

  /** 主货币（对齐安卓 homeCurrencyUnit，鸿蒙无汇率换算，取首个账户货币） */
  private homeCurrency(): string {
    return this.accounts.length > 0 ? this.accounts[0].currency : 'CNY';
  }

  // ==================== 双环甜甜圈图（对齐安卓 BalanceSheetViewInner + RenderChart） ====================
  // 外环：资产账户（按账户自身 color 着色）；内环：负债账户。
  // 角度分配：资产/负债按总额比例分摊 360°，总额大者占满 360°（对齐安卓 angle/ratio 计算）。

  /** 图表用账户：排除 excludeFromTotals，按 showHidden 过滤 sealed，余额不为 0（对齐安卓 effectiveBalance != 0） */
  private chartAccounts(isAsset: boolean): Account[] {
    const types = isAsset
      ? [AccountType.BANK, AccountType.CASH, AccountType.ASSET]
      : [AccountType.CCARD, AccountType.LIABILITY];
    return this.accounts.filter((a: Account) =>
      types.indexOf(a.type) >= 0 &&
      !a.excludeFromTotals &&
      (this.showHidden || !a.sealed) &&
      a.currentBalance !== 0);
  }

  /** 总资产（图表用：正数）；对齐安卓 totalAssets */
  private chartTotalAssets(): number {
    return this.chartAccounts(true).reduce((s: number, a: Account) => s + Math.abs(a.currentBalance), 0);
  }

  /** 总负债绝对值（图表用）；对齐安卓 totalLiabilities（负数）取绝对值 */
  private chartTotalLiabilities(): number {
    return this.chartAccounts(false).reduce((s: number, a: Account) => s + Math.abs(a.currentBalance), 0);
  }

  /** 双环角度：返回 [资产环角度, 负债环角度]，对齐安卓 angle 计算 */
  private chartAngles(): [number, number] {
    const totalAssets = this.chartTotalAssets();
    const totalLiabilities = this.chartTotalLiabilities();
    if (totalAssets > 0 && totalLiabilities > 0) {
      const ratio = totalAssets / totalLiabilities;
      if (ratio > 1) {
        return [360, 360 / ratio];
      } else {
        return [360 * ratio, 360];
      }
    } else if (totalLiabilities <= 0) {
      return [360, 0];
    } else {
      return [0, 360];
    }
  }

  private deg2rad(deg: number): number {
    return deg * Math.PI / 180;
  }

  /** 账户颜色 0xAARRGGBB → '#RRGGBB' */
  private colorHex(color: number): string {
    const rgb = color & 0xFFFFFF;
    return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
  }

  /** 环的几何参数（中心/内外半径），绘制与命中检测共用，保证一致性 */
  private ringGeom(cx: number, cy: number, size: number): ChartGeom {
    const outerR = size * 0.42;
    const outerInnerR = size * 0.28;
    const innerR = size * 0.24;
    const innerInnerR = size * 0.10;
    return {
      cx: cx, cy: cy,
      outerR: outerR, outerInnerR: outerInnerR,
      innerR: innerR, innerInnerR: innerInnerR
    } as ChartGeom;
  }

  /** 绘制一个甜甜圈环（外环资产/内环负债），从顶部 -90° 顺时针分配。
   *  高亮扇区加白描边 + 该扇区颜色加深，环中心显示 label+百分比（对齐安卓 setCenterText）。 */
  private drawDonutRing(ctx: CanvasRenderingContext2D,
    cx: number, cy: number, outerR: number, innerR: number,
    accounts: Account[], totalAngle: number, isAsset: boolean, centerLabel: string, centerValue: string): void {
    const accounts2 = accounts.filter((a: Account) => a.currentBalance !== 0);
    const total = accounts2.reduce((s: number, a: Account) => s + Math.abs(a.currentBalance), 0);
    let highlighted: number = -1;
    if (this.highlight !== null && this.highlight.inner === !isAsset) {
      highlighted = this.highlight.index;
    }
    if (total <= 0) {
      // 无数据环：整环灰色占位
      ctx.beginPath();
      ctx.arc(cx, cy, outerR, 0, Math.PI * 2);
      ctx.arc(cx, cy, innerR, Math.PI * 2, 0, true);
      ctx.closePath();
      ctx.fillStyle = isAsset ? '#E0E0E0' : '#F0F0F0';
      ctx.fill();
      return;
    }
    let start = -90;
    let index = 0;
    for (const acc of accounts2) {
      const sweep = (Math.abs(acc.currentBalance) / total) * totalAngle;
      if (sweep <= 0) {
        continue;
      }
      const isSel = index === highlighted;
      ctx.beginPath();
      ctx.arc(cx, cy, outerR, this.deg2rad(start), this.deg2rad(start + sweep));
      ctx.arc(cx, cy, innerR, this.deg2rad(start + sweep), this.deg2rad(start), true);
      ctx.closePath();
      ctx.fillStyle = isSel ? this.darkenColor(acc.color) : this.colorHex(acc.color);
      ctx.fill();
      // 高亮扇区白描边（对齐安卓 PieChart 选中高亮）
      if (isSel) {
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.arc(cx, cy, outerR, this.deg2rad(start), this.deg2rad(start + sweep));
        ctx.arc(cx, cy, innerR, this.deg2rad(start + sweep), this.deg2rad(start), true);
        ctx.closePath();
        ctx.stroke();
      }
      // 中心文字（对齐安卓 setCenterText：label + 百分比）
      if (isSel) {
        ctx.fillStyle = '#000000';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.font = 'bold 16px sans-serif';
        ctx.fillText(centerLabel.length > 0 ? centerLabel : acc.label, cx, cy - 8);
        ctx.font = '13px sans-serif';
        ctx.fillStyle = '#666666';
        ctx.fillText(centerValue.length > 0 ? centerValue : `${(Math.abs(acc.currentBalance) / total * 100).toFixed(1)}%`,
          cx, cy + 14);
      }
      start += sweep;
      index++;
    }
  }

  /** 颜色加深（高亮扇区，对齐安卓 PieChart 选中态视觉） */
  private darkenColor(color: number): string {
    const r = Math.max(0, ((color >> 16) & 0xFF) - 40);
    const g = Math.max(0, ((color >> 8) & 0xFF) - 40);
    const b = Math.max(0, (color & 0xFF) - 40);
    return '#' + ((r << 16) | (g << 8) | b).toString(16).padStart(6, '0').toUpperCase();
  }

  /** 获取当前高亮账户（null 则无） */
  private highlightAccount(): Account | null {
    if (this.highlight === null) {
      return null;
    }
    const list = this.chartAccounts(!this.highlight.inner);
    const acc = list[this.highlight.index];
    return acc === undefined ? null : acc;
  }

  /** 主绘制入口（Canvas onReady / 数据变化 / 高亮变化时调用） */
  private drawChart(): void {
    const ctx = this.chartContext;
    if (this.chartWidth <= 0 || this.chartHeight <= 0) {
      return;
    }
    const w = this.chartWidth;
    const h = this.chartHeight;
    ctx.clearRect(0, 0, w, h);
    const cx = w / 2;
    const cy = h / 2;
    const size = Math.min(w, h);
    const geom = this.ringGeom(cx, cy, size);
    const angles = this.chartAngles();
    // 中心文字：仅当该环被选中时显示（对齐安卓：另一环保留空白）
    let assetLabel = '';
    let assetValue = '';
    let liabLabel = '';
    let liabValue = '';
    const selAcc = this.highlightAccount();
    if (selAcc !== null && this.highlight !== null) {
      const h = this.highlight;
      const list = this.chartAccounts(!h.inner);
      const total = list.reduce((s: number, a: Account) => s + Math.abs(a.currentBalance), 0);
      const pct = `${(Math.abs(selAcc.currentBalance) / total * 100).toFixed(1)}%`;
      if (h.inner) {
        liabLabel = selAcc.label;
        liabValue = pct;
      } else {
        assetLabel = selAcc.label;
        assetValue = pct;
      }
    }
    this.drawDonutRing(ctx, cx, cy, geom.outerR, geom.outerInnerR, this.chartAccounts(true), angles[0], true,
      assetLabel, assetValue);
    this.drawDonutRing(ctx, cx, cy, geom.innerR, geom.innerInnerR, this.chartAccounts(false), angles[1], false,
      liabLabel, liabValue);
  }

  /** Canvas 点击命中检测：落在哪个环的哪个扇区（对齐安卓 onValueSelected/onNothingSelected） */
  private onChartClick(event: ClickEvent): void {
    if (this.chartWidth <= 0 || this.chartHeight <= 0) {
      return;
    }
    const w = this.chartWidth;
    const h = this.chartHeight;
    const cx = w / 2;
    const cy = h / 2;
    const size = Math.min(w, h);
    const geom = this.ringGeom(cx, cy, size);
    const dx = event.x - cx;
    const dy = event.y - cy;
    const dist = Math.sqrt(dx * dx + dy * dy);
    // 命中检测：优先内环（负债），其次外环（资产），中心/外部视为空白
    const angles = this.chartAngles();
    let hit: HighlightInfo | null = null;
    // 内环范围
    if (dist >= geom.innerInnerR && dist <= geom.innerR) {
      const idx = this.hitSectorIndex(dx, dy, this.chartAccounts(false), angles[1]);
      if (idx >= 0) {
        const acc = this.chartAccounts(false)[idx];
        hit = { inner: true, index: idx, id: acc.id } as HighlightInfo;
      }
    } else if (dist >= geom.outerInnerR && dist <= geom.outerR) {
      const idx = this.hitSectorIndex(dx, dy, this.chartAccounts(true), angles[0]);
      if (idx >= 0) {
        const acc = this.chartAccounts(true)[idx];
        hit = { inner: false, index: idx, id: acc.id } as HighlightInfo;
      }
    }
    if (hit === null) {
      // 点击空白：取消高亮（对齐安卓 onNothingSelected）
      this.highlight = null;
      this.drawChart();
      return;
    }
    // 点击同一扇区：再次点击取消（对齐安卓 PieChart 再次点击取消高亮）
    if (this.highlight !== null && this.highlight.inner === hit.inner && this.highlight.id === hit.id) {
      this.highlight = null;
      this.drawChart();
      return;
    }
    this.highlight = hit;
    this.drawChart();
    // 滚动到对应账户行（对齐安卓 LaunchedEffect animateScrollToItem）
    this.scrollToAccount(hit.id);
  }

  /** 计算点击角度落在某环的哪个扇区索引（从顶部 -90° 顺时针）；返回 -1 表示无效 */
  private hitSectorIndex(dx: number, dy: number, accounts: Account[], totalAngle: number): number {
    const list = accounts.filter((a: Account) => a.currentBalance !== 0);
    const total = list.reduce((s: number, a: Account) => s + Math.abs(a.currentBalance), 0);
    if (total <= 0 || totalAngle <= 0) {
      return -1;
    }
    // 点击角度（deg，0 指向右、90 指向下），映射为从顶部 -90° 顺时针的偏移
    let angle = Math.atan2(dy, dx) * 180 / Math.PI;
    if (angle < 0) {
      angle += 360;
    }
    let offset = angle + 90; // 从顶部顺时针
    if (offset >= 360) {
      offset -= 360;
    }
    if (offset > totalAngle) {
      return -1;
    }
    let acc = 0;
    for (let i = 0; i < list.length; i++) {
      acc += (Math.abs(list[i].currentBalance) / total) * totalAngle;
      if (offset <= acc) {
        return i;
      }
    }
    return list.length - 1;
  }

  /** 滚动到账户行（对齐安卓 highlight LaunchedEffect animateScrollToItem） */
  private scrollToAccount(id: number): void {
    const acc = this.accounts.find((a: Account) => a.id === id);
    if (!acc) {
      return;
    }
    const rectId = `bs_acc_${acc.id}`;
    const info = componentUtils.getRectangleById(rectId);
    if (info && info.windowOffset) {
      // 滚动到目标行接近顶部（减标题栏+安全区偏移），带动画
      const y = info.windowOffset.y - 150;
      this.scroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, y), animation: { duration: 300 } });
    }
  }

  /** 切换图表显示（对齐安卓 showChartState.value 开关，关闭时清空高亮） */
  private toggleChart(): void {
    this.showChart = !this.showChart;
    if (!this.showChart) {
      this.highlight = null;
    } else {
      // Canvas 挂载后 onReady 会绘制；若已就绪立即绘制
      this.drawChart();
    }
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
          this.highlight = null;
          if (this.showChart) {
            this.drawChart();
          }
        }
      } as SheetInfo);
    }
    if (this.hasZeroAccounts()) {
      sheets.push({
        title: (this.showZero ? '✓ ' : '') + '显示零余额账户',
        action: () => {
          this.showZero = !this.showZero;
          this.highlight = null;
          if (this.showChart) {
            this.drawChart();
          }
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
        showChart: true,
        onBack: () => {
          router.back();
        },
        onMore: () => {
          this.showOptionsMenu();
        },
        onChart: () => {
          this.toggleChart();
        }
      })

      Scroll(this.scroller) {
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

          // 双环甜甜圈图（对齐安卓 showChart 时图表在上、明细在下；Canvas 可点击扇区）
          if (this.showChart) {
            Column() {
              Text('资产 / 负债分布')
                .fontSize(14)
                .fontColor($r('app.color.textSecondary'))
                .margin({ top: 8, bottom: 8 })
              Canvas(this.chartContext)
                .width('70%')
                .aspectRatio(1)
                .onReady(() => {
                  this.chartWidth = this.chartContext.width;
                  this.chartHeight = this.chartContext.height;
                  this.drawChart();
                })
                .onClick((event: ClickEvent) => {
                  this.onChartClick(event);
                })
                .margin({ bottom: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }

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
      // 内容不足一屏时默认居中，显式置顶对齐安卓（内容紧贴标题栏下方）
      .align(Alignment.Top)
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
        .id(`bs_acc_${acc.id}`)
        .backgroundColor(this.highlight !== null && this.highlight.id === acc.id
          ? $r('app.color.primaryContainer') : Color.Transparent)
      }, (acc: Account) => `acc_${type}_${acc.id}`)
    }
    .width('100%')
  }
}
