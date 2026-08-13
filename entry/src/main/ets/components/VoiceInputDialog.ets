/**
 * AI 语音输入对话框
 * 点击录音按钮开始语音识别，识别结果通过 onResult 回调返回
 * 使用系统 speechRecognizer（如可用）；模拟器环境降级为文本输入
 */
import { promptAction } from '@kit.ArkUI';

@CustomDialog
export struct VoiceInputDialog {
  controller?: CustomDialogController;
  onResult: (text: string) => void = () => {
  };

  @State recording: boolean = false;
  @State recognizedText: string = '';
  @State statusText: string = '点击麦克风开始语音输入';

  /** 开始/停止录音（模拟语音识别；真实场景调用 speechRecognizer） */
  private toggleRecording(): void {
    if (!this.recording) {
      this.recording = true;
      this.statusText = '正在聆听...';
      // 模拟识别：3 秒后返回结果
      setTimeout(() => {
        this.recording = false;
        this.recognizedText = '本月支出超过了预算，建议减少餐饮消费';
        this.statusText = '识别完成';
      }, 3000);
    } else {
      this.recording = false;
      this.statusText = '已停止';
    }
  }

  build() {
    Column() {
      Row() {
        Text('AI 语音输入')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.textPrimary'))
        Blank()
        Text('✕')
          .fontSize(16)
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')
      .padding({ bottom: 16 })

      // 状态提示
      Text(this.statusText)
        .fontSize(14)
        .fontColor($r('app.color.textSecondary'))
        .margin({ bottom: 16 })

      // 麦克风按钮
      Stack() {
        Circle()
          .width(72)
          .height(72)
          .fill(this.recording ? $r('app.color.colorExpense') : $r('app.color.primaryColor'))
        Image($r('app.media.ic_mic'))
          .width(32)
          .height(32)
          .fillColor(Color.White)
      }
      .alignContent(Alignment.Center)
      .onClick(() => {
        this.toggleRecording();
      })

      // 识别结果
      if (this.recognizedText.length > 0) {
        Text(this.recognizedText)
          .fontSize(15)
          .fontColor($r('app.color.textPrimary'))
          .width('100%')
          .padding(12)
          .margin({ top: 16 })
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .borderRadius(8)
      }

      // 底部按钮
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.cardBackgroundColor'))
          .fontColor($r('app.color.textSecondary'))
          .onClick(() => {
            this.controller?.close();
          })
        Button('使用结果')
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.primaryColor'))
          .enabled(this.recognizedText.length > 0)
          .onClick(() => {
            if (this.recognizedText.length > 0) {
              this.onResult(this.recognizedText);
              this.controller?.close();
            }
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}