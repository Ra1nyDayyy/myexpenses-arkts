/**
 * AI 语音输入对话框（录音采集验证版）
 * 点击麦克风：请求 MICROPHONE 权限 → AudioCapturer 采集 2 秒 → 统计采集数据验证
 * 验证通过后再接入语音识别
 */
import { promptAction } from '@kit.ArkUI';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

@CustomDialog
export struct VoiceInputDialog {
  controller?: CustomDialogController;
  onResult: (text: string) => void = () => {
  };

  @State recording: boolean = false;
  @State recognizedText: string = '';
  @State statusText: string = '点击麦克风开始录音采集验证（2 秒）';

  /** 开始录音采集：请求权限 → AudioCapturer 采集 2 秒 → 统计验证 */
  private async toggleRecording(): Promise<void> {
    if (this.recording) {
      this.recording = false;
      this.statusText = '已停止';
      return;
    }
    this.recording = true;
    this.statusText = '正在请求麦克风权限...';
    try {
      // 1. 请求 MICROPHONE 权限
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(
        context, ['ohos.permission.MICROPHONE'] as Permissions[]
      );
      const granted = result.authResults && result.authResults.length > 0 && result.authResults[0] === 0;
      if (!granted) {
        this.statusText = '麦克风权限被拒绝';
        this.recording = false;
        return;
      }
      this.statusText = '权限已授予，正在创建采集器...';

      // 2. 创建 AudioCapturer（16kHz 单声道 S16LE，MIC 输入——语音采集常用格式）
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };
      const options: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      };
      this.statusText = '正在创建 AudioCapturer...';
      const capturer = await audio.createAudioCapturer(options);
      this.statusText = '创建成功，正在 start...';
      await capturer.start();
      this.statusText = 'start 成功，正在采集 2 秒...';

      // 3. 采集 2 秒，统计数据
      const bufferSize: number = await capturer.getBufferSize();
      const totalBytes = new Array<number>();
      let totalRead = 0;
      let nonZeroSamples = 0;
      let sampleCount = 0;
      const startMs = Date.now();
      while (Date.now() - startMs < 2000) {
        const buffer = await capturer.read(bufferSize, true);
        if (buffer && buffer.byteLength > 0) {
          totalRead += buffer.byteLength;
          totalBytes.push(buffer.byteLength);
          // 统计非零采样（判断是否采到真实声音）
          const view = new DataView(buffer);
          const sampleNum = Math.floor(buffer.byteLength / 2);
          sampleCount += sampleNum;
          for (let i = 0; i < sampleNum; i += 50) {
            const s = view.getInt16(i * 2, true);
            if (s !== 0) {
              nonZeroSamples++;
            }
          }
        }
      }
      await capturer.stop();
      await capturer.release();

      // 4. 报告结果
      const bytes = totalRead;
      const validRatio = sampleCount > 0 ? (nonZeroSamples / Math.ceil(sampleCount / 50)) : 0;
      this.recording = false;
      if (bytes > 0 && validRatio > 0.01) {
        this.statusText = `采集成功：${bytes} 字节，2 秒，非零比例 ${(validRatio * 100).toFixed(1)}%（麦克风可用）`;
        this.recognizedText = '✓ 模拟器麦克风采集验证通过，可接入语音识别';
        promptAction.showToast({ message: `录音验证通过：${bytes} 字节` });
      } else {
        this.statusText = `采集异常：${bytes} 字节，非零比例 ${(validRatio * 100).toFixed(1)}%（可能无真实声音输入）`;
        this.recognizedText = '✗ 未采集到有效音频（请检查宿主机麦克风）';
      }
    } catch (e) {
      this.recording = false;
      this.statusText = '录音失败';
      this.recognizedText = '错误: ' + JSON.stringify(e);
      promptAction.showToast({ message: '录音失败: ' + JSON.stringify(e) });
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
        .textAlign(TextAlign.Center)

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

      // 识别/验证结果
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
        Button('关闭')
          .layoutWeight(1)
          .height(44)
          .backgroundColor($r('app.color.primaryColor'))
          .fontColor(Color.White)
          .onClick(() => {
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.surfaceElevated'))
    .borderRadius(16)
  }
}
