/**
 * AI 记账服务：简单单笔收支优先在设备本地解析；复杂表达只发送给明确
 * 配置的可信业务后端。客户端不保存或发送模型供应商密钥。
 */
import { http } from '@kit.NetworkKit';
import { AiIntent } from '../ai/AiIntentCore';
import { LocalIntentParser } from '../ai/LocalIntentParser';
import { AiIntentValidator } from '../ai/AiIntentValidator';

export { AiIntent } from '../ai/AiIntentCore';

/** 可信业务后端的完整意图识别端点；默认不配置。 */
export interface AiConfig {
  backendUrl: string;
}

export const AI_CONFIG: AiConfig = {
  backendUrl: ''
};

export const AI_CAPABILITY_BOUNDARY_MESSAGE: string =
  '当前仅支持本地识别简单的单笔收入或支出；复杂请求需要配置可信业务后端，暂不可用。';

interface AiBackendRequestBody {
  text: string;
}

export class AiService {
  private static instance: AiService;

  static getInstance(): AiService {
    if (!AiService.instance) {
      AiService.instance = new AiService();
    }
    return AiService.instance;
  }

  /** 将文字解析为已经通过 MVP 安全白名单校验的结构化意图。 */
  async understand(text: string): Promise<AiIntent> {
    const localIntent = LocalIntentParser.parse(text);
    if (localIntent) {
      const localValidation = AiIntentValidator.validate(localIntent);
      if (!localValidation.valid) {
        throw new Error(localValidation.error);
      }
      return localIntent;
    }

    const backendUrl = AI_CONFIG.backendUrl.trim();
    if (backendUrl.length === 0) {
      throw new Error(AI_CAPABILITY_BOUNDARY_MESSAGE);
    }

    const body: AiBackendRequestBody = { text: text };
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(backendUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 30000,
        readTimeout: 60000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`AI 业务后端请求失败（HTTP ${response.responseCode}）`);
      }

      const intent = JSON.parse(response.result as string) as AiIntent;
      const validation = AiIntentValidator.validate(intent);
      if (!validation.valid) {
        throw new Error(`业务后端返回了不安全或不完整的操作：${validation.error}`);
      }
      return intent;
    } finally {
      httpRequest.destroy();
    }
  }
}
