/**
 * 金额计算器对话框（对齐安卓 CalculatorInput.kt）
 * 栈式状态机：数字键 + 四则运算 + 正负切换 + 百分号 + 确定/取消
 * 关键行为与安卓一致：
 *  - 点"确定"时若存在未完成的运算，先自动计算再返回结果
 *  - 百分比在加减运算中按"前一操作数 × 当前值 ÷ 100"处理并自动完成计算
 */
@CustomDialog
export struct CalculatorDialog {
  controller?: CustomDialogController;
  @State display: string = '0';
  @State opLabel: string = ''; // 当前运算符显示（对齐安卓 result_pane.op）
  private stack: string[] = [];
  private lastOp: string = ''; // '' | '+' | '−' | '×' | '÷'
  private isRestart: boolean = true;
  private isInEquals: boolean = false;
  onResult: (value: string) => void = () => {
  };

  /**
   * 数字格式化：对齐 BigDecimal.toPlainString，消除浮点误差并去除尾零
   */
  private fmt(n: number): string {
    if (!isFinite(n)) {
      return '0';
    }
    let s = (Math.round(n * 1000000) / 1000000).toString();
    if (s.indexOf('e') >= 0 || s.indexOf('E') >= 0) {
      s = n.toFixed(6);
    }
    if (s.indexOf('.') >= 0) {
      s = s.replace(/0+$/, '').replace(/\.$/, '');
    }
    if (s === '-0' || s === '') {
      s = '0';
    }
    return s;
  }

  private setDisplay(s: string): void {
    if (s !== '') {
      this.display = s.replace(',', '.');
    }
  }

  private addChar(c: string): void {
    let s = this.display;
    if (c === '.' && s.indexOf('.') !== -1 && !this.isRestart) {
      return;
    }
    if (this.isRestart) {
      this.setDisplay(c === '.' ? '0.' : c);
      this.isRestart = false;
    } else {
      if (s === '0' && c !== '.') {
        s = c;
      } else {
        s += c;
      }
      this.setDisplay(s);
    }
  }

  private doOpChar(op: string): void {
    if (this.isInEquals) {
      this.stack = [];
      this.isInEquals = false;
    }
    this.stack.push(this.display);
    if (!this.isRestart) {
      this.doLastOp();
    }
    this.lastOp = op;
    this.opLabel = op;
  }

  private doLastOp(): void {
    this.isRestart = true;
    if (this.lastOp === '' || this.stack.length === 1) {
      return;
    }
    const valTwo = this.stack.pop() as string;
    const valOne = this.stack.pop() as string;
    const a = parseFloat(valOne);
    const b = parseFloat(valTwo);
    let r = 0;
    switch (this.lastOp) {
      case '+':
        r = a + b;
        break;
      case '−':
        r = a - b;
        break;
      case '×':
        r = a * b;
        break;
      case '÷':
        r = b === 0 ? 0 : a / b;
        break;
      default:
        break;
    }
    const res = this.fmt(r);
    this.stack.push(res);
    this.setDisplay(res);
    if (this.isInEquals) {
      this.stack.push(valTwo);
    }
  }

  private doEqualsChar(): void {
    if (this.lastOp === '' || this.isRestart) {
      return;
    }
    if (!this.isInEquals) {
      this.isInEquals = true;
      this.stack.push(this.display);
    }
    this.doLastOp();
    this.opLabel = '';
  }

  private doPercentChar(): void {
    const cur = parseFloat(this.display);
    let val = cur;
    if ((this.lastOp === '+' || this.lastOp === '−') && this.stack.length > 0) {
      // 加减：百分比是"前一操作数的百分比"
      val = cur * parseFloat(this.stack[this.stack.length - 1]);
    }
    this.setDisplay(this.fmt(val / 100));
    this.doEqualsChar();
  }

  private doBackspace(): void {
    const s = this.display;
    if (s === '0' || this.isRestart) {
      return;
    }
    let newDisplay = s.length > 1 ? s.substring(0, s.length - 1) : '0';
    if (newDisplay === '-') {
      newDisplay = '0';
    }
    this.setDisplay(newDisplay);
  }

  private resetAll(): void {
    this.setDisplay('0');
    this.opLabel = '';
    this.lastOp = '';
    this.isRestart = true;
    this.stack = [];
    this.isInEquals = false;
  }

  private toggleSign(): void {
    const v = parseFloat(this.display);
    this.setDisplay(this.fmt(-v));
  }

  private confirm(): void {
    if (!this.isInEquals) {
      this.doEqualsChar();
    }
    this.onResult(this.display);
    this.controller?.close();
  }

  private cancel(): void {
    this.controller?.close();
  }

  @Builder
  calcKey(text: string, onClick: () => void, textColor: ResourceColor = $r('app.color.textPrimary'),
    bold: boolean = false) {
    Button(text)
      .layoutWeight(1)
      .height(46)
      .fontSize(18)
      .fontWeight(bold ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(textColor)
      .backgroundColor($r('app.color.cardBackgroundColor'))
      .border({ width: 1, color: $r('app.color.dividerColor') })
      .borderRadius(8)
      .margin({ left: 3, right: 3, top: 3, bottom: 3 })
      .onClick(() => {
        onClick();
      })
  }

  build() {
    Column() {
      // 结果面板（对齐安卓 calculator_result.xml：op 右上 + result 下方右对齐）
      Column() {
        Text(this.opLabel)
          .fontSize(20)
          .fontColor(Color.Black)
          .width('100%')
          .textAlign(TextAlign.End)
          .height(26)
          .margin({ bottom: -4 })
        Text(this.display)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Black)
          .width('100%')
          .textAlign(TextAlign.End)
          .maxLines(1)
          .height(44)
      }
      .width('100%')
      .backgroundColor($r('app.color.cardBackgroundColor'))
      .border({ width: 1, color: $r('app.color.dividerColor') })
      .borderRadius(8)
      .padding({ left: 15, right: 15, top: 6, bottom: 6 })

      // 键盘（对齐安卓 calculator.xml 6 列布局）
      Row() {
        this.calcKey('7', () => this.addChar('7'))
        this.calcKey('8', () => this.addChar('8'))
        this.calcKey('9', () => this.addChar('9'))
        this.calcKey('0', () => this.addChar('0'))
        this.calcKey('+', () => this.doOpChar('+'))
        this.calcKey('C', () => this.resetAll(), '#f26522', true)
      }
      .width('100%')

      Row() {
        this.calcKey('4', () => this.addChar('4'))
        this.calcKey('5', () => this.addChar('5'))
        this.calcKey('6', () => this.addChar('6'))
        this.calcKey('±', () => this.toggleSign())
        this.calcKey('−', () => this.doOpChar('−'))
        this.calcKey('⌫', () => this.doBackspace())
      }
      .width('100%')

      Row() {
        this.calcKey('1', () => this.addChar('1'))
        this.calcKey('2', () => this.addChar('2'))
        this.calcKey('3', () => this.addChar('3'))
        this.calcKey('.', () => this.addChar('.'))
        this.calcKey('×', () => this.doOpChar('×'))
        this.calcKey('%', () => this.doPercentChar())
      }
      .width('100%')

      Row() {
        this.calcKey('取消', () => this.cancel())
        this.calcKey('确定', () => this.confirm())
        this.calcKey('÷', () => this.doOpChar('÷'))
        this.calcKey('=', () => this.doEqualsChar(), '#39b54a', true)
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
    .width('100%')
  }
}
