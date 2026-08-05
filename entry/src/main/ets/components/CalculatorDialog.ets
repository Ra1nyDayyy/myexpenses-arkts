/**
 * 金额计算器对话框（对齐安卓金额计算器）
 * 支持数字键 + 四则运算 + 正负切换 + 百分号
 */
@CustomDialog
export struct CalculatorDialog {
  controller?: CustomDialogController;
  @State display: string = '0';
  private operand1: number = 0;
  private operator: string = '';
  private waitingOperand: boolean = false;
  onResult: (value: string) => void = () => {
  };

  private appendDigit(d: string): void {
    if (this.waitingOperand) {
      this.display = d === '.' ? '0.' : d;
      this.waitingOperand = false;
    } else {
      if (d === '.' && this.display.includes('.')) {
        return;
      }
      if (this.display === '0' && d !== '.') {
        this.display = d;
      } else {
        this.display = this.display.length >= 15 ? this.display : this.display + d;
      }
    }
  }

  private setOperator(op: string): void {
    const val = parseFloat(this.display);
    if (this.operator !== '' && !this.waitingOperand) {
      this.compute();
    } else {
      this.operand1 = val;
    }
    this.operator = op;
    this.waitingOperand = true;
  }

  private compute(): void {
    const val2 = parseFloat(this.display);
    let result = 0;
    switch (this.operator) {
      case '+':
        result = this.operand1 + val2;
        break;
      case '-':
        result = this.operand1 - val2;
        break;
      case '×':
        result = this.operand1 * val2;
        break;
      case '÷':
        result = val2 !== 0 ? this.operand1 / val2 : 0;
        break;
      default:
        result = val2;
    }
    this.operand1 = result;
    this.display = String(Math.round(result * 10000) / 10000);
    this.operator = '';
    this.waitingOperand = true;
  }

  private equals(): void {
    if (this.operator !== '') {
      this.compute();
    }
  }

  private clear(): void {
    this.display = '0';
    this.operand1 = 0;
    this.operator = '';
    this.waitingOperand = false;
  }

  private toggleSign(): void {
    const val = parseFloat(this.display);
    this.display = String(val > 0 ? -val : Math.abs(val));
  }

  private percent(): void {
    const val = parseFloat(this.display);
    this.display = String(val / 100);
  }

  private confirm(): void {
    this.onResult(this.display);
    this.controller?.close();
  }

  @Builder
  calcKey(text: string, onClick: () => void) {
    Button(text)
      .width('100%')
      .height(56)
      .fontSize(20)
      .fontColor($r('app.color.textPrimary'))
      .backgroundColor($r('app.color.cardBackgroundColor'))
      .onClick(() => {
        onClick();
      })
  }

  build() {
    Column() {
      // 显示区
      Text(this.display)
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.textPrimary'))
        .width('100%')
        .height(72)
        .textAlign(TextAlign.End)
        .padding({ right: 16 })
        .backgroundColor($r('app.color.pageBackground'))

      // 键盘
      Column() {
        Row() {
          this.calcKey('C', () => this.clear())
          this.calcKey('⌫', () => {
            this.display = this.display.length > 1 ? this.display.slice(0, -1) : '0';
          })
          this.calcKey('%', () => this.percent())
          this.calcKey('÷', () => this.setOperator('÷'))
        }
        Row() {
          this.calcKey('7', () => this.appendDigit('7'))
          this.calcKey('8', () => this.appendDigit('8'))
          this.calcKey('9', () => this.appendDigit('9'))
          this.calcKey('×', () => this.setOperator('×'))
        }
        Row() {
          this.calcKey('4', () => this.appendDigit('4'))
          this.calcKey('5', () => this.appendDigit('5'))
          this.calcKey('6', () => this.appendDigit('6'))
          this.calcKey('-', () => this.setOperator('-'))
        }
        Row() {
          this.calcKey('1', () => this.appendDigit('1'))
          this.calcKey('2', () => this.appendDigit('2'))
          this.calcKey('3', () => this.appendDigit('3'))
          this.calcKey('+', () => this.setOperator('+'))
        }
        Row() {
          this.calcKey('±', () => this.toggleSign())
          this.calcKey('0', () => this.appendDigit('0'))
          this.calcKey('.', () => this.appendDigit('.'))
          Button('=')
            .width('100%')
            .height(56)
            .fontSize(20)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.primaryColor'))
            .onClick(() => this.equals())
        }
      }
      .padding(8)

      // 确定
      Button('确定')
        .width('100%')
        .height(48)
        .margin({ top: 8, bottom: 16 })
        .backgroundColor($r('app.color.primaryColor'))
        .onClick(() => this.confirm())
    }
    .width('100%')
  }
}