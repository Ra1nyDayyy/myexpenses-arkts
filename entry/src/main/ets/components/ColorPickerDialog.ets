/**
 * 颜色选择对话框（对齐安卓 SimpleColorDialog）
 * - 预设 Material 色板（20 色，最后一个为调色板图标入口）
 * - 点击调色板打开圆形 HSV 色盘：外环色相 + 内部 SV 三角形 + HEX 输入
 */
@CustomDialog
export struct AccountColorDialog {
  controller?: CustomDialogController;
  /** 当前颜色（0xRRGGBB） */
  @State color: number = 0x009688;
  onResult: (color: number) => void = () => {
  };

  // ============ 预设色板（Material 20 色，末位调色板图标） ============
  private palette: number[] = [
    0xFFF44336, 0xE91E63, 0x9C27B0, 0x673AB7, 0x3F51B5, // red magenta purple deepPurple indigo
    0x2196F3, 0x03A9F4, 0x00BCD4, 0x009688, 0x4CAF50, // blue lightBlue cyan teal green
    0x8BC34A, 0xCDDC39, 0xFFEB3B, 0xFFC107, 0xFF9800, // lightGreen lime yellow amber orange
    0xFF5722, 0x795548, 0x9E9E9E, 0x607D8B, 0x000000  // deepOrange brown gray blueGray black
  ];

  // ============ HSV 色盘状态 ============
  @State showPalette: boolean = false;
  @State hue: number = 175;
  @State saturation: number = 0.85;
  @State value: number = 0.6;
  @State hexInput: string = '009688';

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private paletteContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private ringR: number = 0;   // 外环半径（px）
  private innerR: number = 0;  // 三角形内切半径（px）
  private centerX: number = 0;
  private centerY: number = 0;
  /** vp -> px 换算比例（Canvas 布局 280vp，ctx.width 为实际像素） */
  private canvasScale: number = 1;
  /** Canvas 布局尺寸（vp） */
  private canvasVp: number = 280;

  /** HSV -> RGB 整数 */
  private hsvToRgb(h: number, s: number, v: number): number {
    const c = v * s;
    const x = c * (1 - Math.abs((h / 60) % 2 - 1));
    const m = v - c;
    let r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; b = 0; }
    else if (h < 120) { r = x; g = c; b = 0; }
    else if (h < 180) { r = 0; g = c; b = x; }
    else if (h < 240) { r = 0; g = x; b = c; }
    else if (h < 300) { r = x; g = 0; b = c; }
    else { r = c; g = 0; b = x; }
    const ri = Math.round((r + m) * 255);
    const gi = Math.round((g + m) * 255);
    const bi = Math.round((b + m) * 255);
    return (0xFF << 24) | (ri << 16) | (gi << 8) | bi;
  }

  /** RGB -> HSV */
  private rgbToHsv(c: number): void {
    const r = ((c >> 16) & 0xFF) / 255;
    const g = ((c >> 8) & 0xFF) / 255;
    const b = (c & 0xFF) / 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const d = max - min;
    let h = 0;
    if (d !== 0) {
      if (max === r) h = ((g - b) / d) % 6;
      else if (max === g) h = (b - r) / d + 2;
      else h = (r - g) / d + 4;
      h *= 60;
      if (h < 0) h += 360;
    }
    this.hue = h;
    this.saturation = max === 0 ? 0 : d / max;
    this.value = max;
  }

  private hexColor(c: number): string {
    const rgb = c & 0xFFFFFF;
    return '#' + rgb.toString(16).padStart(6, '0').toUpperCase();
  }

  /** 当前 HSV 转整数色 */
  private currentColor(): number {
    return this.hsvToRgb(this.hue, this.saturation, this.value);
  }

  // ============ Canvas 绘制色相环 + SV 三角形 ============
  private drawPalette(): void {
    const ctx = this.paletteContext;
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    const cx = this.centerX;
    const cy = this.centerY;
    const R = this.ringR;

    // 外环：按角度渐变绘制色相环（每 3° 一段）
    for (let a = 0; a < 360; a += 3) {
      const rad0 = (a - 90) * Math.PI / 180;
      const rad1 = (a + 3 - 90) * Math.PI / 180;
      const c = this.hsvToRgb(a, 1, 1);
      ctx.beginPath();
      ctx.moveTo(cx + (R - 14) * Math.cos(rad0), cy + (R - 14) * Math.sin(rad0));
      ctx.arc(cx, cy, R - 14, rad0, rad1);
      ctx.arc(cx, cy, R - 26, rad1, rad0, true);
      ctx.closePath();
      ctx.fillStyle = this.rgbString(c);
      ctx.fill();
    }
    // 选中色相标记（白色小圆）
    const hrad = (this.hue - 90) * Math.PI / 180;
    const mx = cx + (R - 20) * Math.cos(hrad);
    const my = cy + (R - 20) * Math.sin(hrad);
    ctx.beginPath();
    ctx.arc(mx, my, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#00000066';
    ctx.stroke();

    // 内部三角形顶点（对齐安卓 SimpleColorDialog 的 SV 三角形）
    const tR = R - 40;
    const vx = cx;                 // 顶点（纯色）
    const vy = cy - tR * 0.85;
    const bx1 = cx - tR * 0.9;     // 底边左（灰）
    const by1 = cy + tR * 0.6;
    const bx2 = cx + tR * 0.9;     // 底边右（黑）
    const by2 = cy + tR * 0.6;

    // 用逐点绘制填充三角形（简单方案：填充三条渐变边）
    // 顶点颜色 = 当前色相纯色
    const top = this.hsvToRgb(this.hue, 1, 1);
    // 底边从左(白)到右(黑)渐变，结合饱和度
    ctx.beginPath();
    ctx.moveTo(vx, vy);
    ctx.lineTo(bx1, by1);
    ctx.lineTo(bx2, by2);
    ctx.closePath();
    // 三角形渐变：用 Canvas 渐变模拟（linear gradient 顶点→底边中心）
    const grad = ctx.createLinearGradient(vx, vy, (bx1 + bx2) / 2, (by1 + by2) / 2);
    grad.addColorStop(0, this.rgbString(top));
    grad.addColorStop(1, '#000000');
    ctx.fillStyle = grad;
    ctx.fill();
    // 底边从左到右 白→黑 叠加（用半透明白渐变覆盖左侧）
    const grad2 = ctx.createLinearGradient(bx1, by1, bx2, by2);
    grad2.addColorStop(0, '#FFFFFF');
    grad2.addColorStop(1, '#00000000');
    ctx.fillStyle = grad2;
    ctx.fill();

    // SV 选择点
    const sx = this.svPointX(vx, bx1, bx2, by1, by2);
    const sy = this.svPointY(vx, vy, by1, by2);
    ctx.beginPath();
    ctx.arc(sx, sy, 6, 0, Math.PI * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.fill();
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#00000088';
    ctx.stroke();
  }

  /** 计算 SV 点在三角形内的坐标（按 saturation/value 插值） */
  private svPointX(vx: number, bx1: number, bx2: number, by1: number, by2: number): number {
    // 简单三角插值：saturation 0-1 从底边左(白)到右(黑)，value 从底边到顶点
    // 用重心坐标近似：点在底边位置 = saturation，距底边比例 = 1 - value
    const bottomX = bx1 + (bx2 - bx1) * this.saturation;
    const t = 1 - this.value; // 0=顶 1=底
    return vx + (bottomX - vx) * t;
  }

  private svPointY(vx: number, vy: number, by1: number, by2: number): number {
    const bottomY = (by1 + by2) / 2;
    const t = 1 - this.value;
    return vy + (bottomY - vy) * t;
  }

  private rgbString(c: number): string {
    return this.hexColor(c);
  }

  /** 触摸色盘：判断命中色相环或三角形（vp 坐标换算为 px） */
  private onPaletteTouch(e: GestureEvent): void {
    if (e.fingerList.length === 0) return;
    const x = e.fingerList[0].localX * this.canvasScale;
    const y = e.fingerList[0].localY * this.canvasScale;
    const dx = x - this.centerX;
    const dy = y - this.centerY;
    const dist = Math.sqrt(dx * dx + dy * dy);

    // 命中色相环（外环区域）
    if (dist > this.ringR - 34 && dist < this.ringR) {
      let ang = Math.atan2(dy, dx) * 180 / Math.PI + 90;
      if (ang < 0) ang += 360;
      this.hue = ang;
      this.color = this.currentColor();
      this.updateHex();
      this.drawPalette();
      return;
    }
    // 命中三角形内部（简单判定：在环内）
    if (dist < this.ringR - 34) {
      // 计算 value（距离顶点比例）与 saturation（横向比例）
      const tR = this.ringR - 40;
      const vx = this.centerX;
      const vy = this.centerY - tR * 0.85;
      const by1 = this.centerY + tR * 0.6;
      const t = Math.min(1, Math.max(0, (y - vy) / (by1 - vy)));
      this.value = 1 - t;
      // 横向：底边从 白(左) 到 黑(右)
      const bx1 = this.centerX - tR * 0.9;
      const bx2 = this.centerX + tR * 0.9;
      const bottomX = bx1 + (bx2 - bx1) * this.saturation;
      // 当前点所在水平线的左右边界
      const edgeL = vx + (bx1 - vx) * t;
      const edgeR = vx + (bx2 - vx) * t;
      this.saturation = Math.min(1, Math.max(0, (x - edgeL) / (edgeR - edgeL)));
      this.color = this.currentColor();
      this.updateHex();
      this.drawPalette();
    }
  }

  /** HEX 输入变化 */
  private updateHex(): void {
    this.hexInput = (this.currentColor() & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase();
  }

  private onHexChange(v: string): void {
    this.hexInput = v.replace(/[^0-9a-fA-F]/g, '').toUpperCase().slice(0, 6);
    if (this.hexInput.length === 6) {
      this.color = 0xFF000000 | parseInt(this.hexInput, 16);
      this.rgbToHsv(this.color);
      this.drawPalette();
    }
  }

  /** 打开色盘 */
  private openPalette(): void {
    this.showPalette = true;
    this.rgbToHsv(this.color);
    this.updateHex();
  }

  /** 预设色板是否选中 */
  private isSelected(row: number, col: number): boolean {
    const idx = row * 5 + col;
    return idx < this.palette.length && this.color === this.palette[idx];
  }

  /** 预设色板颜色 */
  private paletteColor(row: number, col: number): string {
    const idx = row * 5 + col;
    if (idx >= this.palette.length) {
      return '#FFFFFF';
    }
    return this.hexColor(this.palette[idx]);
  }

  private confirm(): void {
    this.onResult(this.color);
    this.controller?.close();
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('选择颜色')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text('取消')
          .fontSize(15)
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')
      .padding({ bottom: 12 })

      if (!this.showPalette) {
        // ===== 预设色板（20 色，末位调色板图标） =====
        Column({ space: 8 }) {
          ForEach([0, 1, 2, 3], (row: number) => {
            Row({ space: 10 }) {
              ForEach([0, 1, 2, 3, 4], (col: number) => {
                Stack() {
                  Circle()
                    .width(this.isSelected(row, col) ? 36 : 32)
                    .height(this.isSelected(row, col) ? 36 : 32)
                    .fill(this.paletteColor(row, col))
                    .stroke(this.isSelected(row, col) ? $r('app.color.primaryColor') : $r('app.color.dividerColor'))
                    .strokeWidth(this.isSelected(row, col) ? 3 : 1)
                }
                .width(44)
                .height(44)
                .alignContent(Alignment.Center)
                .onClick(() => {
                  const idx = row * 5 + col;
                  if (idx < this.palette.length) {
                    this.color = this.palette[idx];
                    this.rgbToHsv(this.color);
                    this.updateHex();
                  }
                })
              }, (c: number) => `pc_${row}_${c}`)
            }
            .justifyContent(FlexAlign.Center)
          }, (r: number) => `prow_${r}`)

          // 调色板图标（打开自定义色盘）
          Row({ space: 8 }) {
            Circle()
              .width(36)
              .height(36)
              .linearGradient({
                angle: 45,
                colors: [['#FF0000', 0], ['#FFFF00', 0.25], ['#00FF00', 0.5], ['#00FFFF', 0.75], ['#0000FF', 1]]
              })
            Text('自定义颜色')
              .fontSize(14)
              .fontColor($r('app.color.primaryColor'))
          }
          .padding({ top: 10, bottom: 4 })
          .onClick(() => {
            this.openPalette();
          })
        }
        .width('100%')
        .padding({ top: 4 })
      } else {
        // ===== 圆形 HSV 色盘（对齐安卓 SimpleColorDialog 自定义色盘） =====
        Column() {
          Canvas(this.paletteContext)
            .width(280)
            .height(280)
            .onReady(() => {
              const w = this.paletteContext.width;
              const h = this.paletteContext.height;
              this.canvasScale = w / this.canvasVp;
              this.centerX = w / 2;
              this.centerY = h / 2;
              this.ringR = Math.min(w, h) / 2 - 4;
              this.drawPalette();
            })
            .onClick((e: ClickEvent) => {
              // 点击定位色盘（vp 坐标 -> px）
              this.onPaletteClick(e.x * this.canvasScale, e.y * this.canvasScale);
            })
            .gesture(
              PanGesture({ fingers: 1 })
                .onActionStart((e: GestureEvent) => {
                  this.onPaletteTouch(e);
                })
                .onActionUpdate((e: GestureEvent) => {
                  this.onPaletteTouch(e);
                })
            )

          // HEX 输入 + 预览
          Row({ space: 10 }) {
            Text('HEX:')
              .fontSize(14)
              .fontColor($r('app.color.textPrimary'))
            TextInput({ placeholder: '009688', text: this.hexInput })
              .type(InputType.Normal)
              .layoutWeight(1)
              .onChange((v: string) => {
                this.onHexChange(v);
              })
            Circle()
              .width(32)
              .height(32)
              .fill(this.hexColor(this.color))
              .stroke($r('app.color.dividerColor'))
              .strokeWidth(1)
          }
          .width('100%')
          .padding({ top: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      // 确定按钮（固定在底部）
      Button('确定')
        .width('100%')
        .height(44)
        .backgroundColor($r('app.color.primaryColor'))
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          this.confirm();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surfaceElevated'))
    .borderRadius(16)
  }

  /** 点击色盘定位（ClickEvent 版） */
  private onPaletteClick(x: number, y: number): void {
    const dx = x - this.centerX;
    const dy = y - this.centerY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > this.ringR - 34 && dist < this.ringR) {
      let ang = Math.atan2(dy, dx) * 180 / Math.PI + 90;
      if (ang < 0) ang += 360;
      this.hue = ang;
      this.color = this.currentColor();
      this.updateHex();
      this.drawPalette();
      return;
    }
    if (dist < this.ringR - 34) {
      const tR = this.ringR - 40;
      const vx = this.centerX;
      const vy = this.centerY - tR * 0.85;
      const by1 = this.centerY + tR * 0.6;
      const t = Math.min(1, Math.max(0, (y - vy) / (by1 - vy)));
      this.value = 1 - t;
      const bx1 = this.centerX - tR * 0.9;
      const bx2 = this.centerX + tR * 0.9;
      const edgeL = vx + (bx1 - vx) * t;
      const edgeR = vx + (bx2 - vx) * t;
      this.saturation = Math.min(1, Math.max(0, (x - edgeL) / (edgeR - edgeL)));
      this.color = this.currentColor();
      this.updateHex();
      this.drawPalette();
    }
  }
}
