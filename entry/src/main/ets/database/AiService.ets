/**
 * AI 记账服务：全程调用大模型（OpenAI 兼容接口）识别意图
 * 结果经过 AiIntentValidator 严格白名单校验，双重保障安全
 */
import { http } from '@kit.NetworkKit';
import { AiIntent } from '../ai/AiIntentCore';
import { AiIntentValidator } from '../ai/AiIntentValidator';

export { AiIntent } from '../ai/AiIntentCore';

/** 大模型服务配置（阿里云百炼专属实例，OpenAI 兼容接口） */
export interface AiConfig {
  baseUrl: string;
  apiKey: string;
  model: string;
}

export const AI_CONFIG: AiConfig = {
  baseUrl: 'https://ws-ekca14gzhgflx9ro.cn-beijing.maas.aliyuncs.com/compatible-mode/v1',
  apiKey: 'sk-ws-H.EEXHLMM.SJGz.MEUCIQCEfR0oZwBjQPpU4eeYZzYZEWx2Mizd406mhlF0wgzu9QIgLli0luIE9XvEhAGzBMszq6c9jD4qXSZGZ8rQSBA0mv4',
  model: 'qwen3.8-max'
};

export const AI_CAPABILITY_BOUNDARY_MESSAGE: string =
  '暂时没能理解这句话，请说得更清楚一些（例如"午饭35元"或"这个月花了多少"）。';

/**
 * 严格意图识别 Prompt：
 * 1. 只输出 JSON
 * 2. domain 仅允许 transaction
 * 3. action 仅允许 create/query/filter/sort
 * 4. create 必须提供 type+amount，字段严格白名单
 * 5. 金额必须为正数（元）
 */
const SYSTEM_PROMPT = `你是一个记账应用意图识别器。用户输入可能是中文或英文。根据用户输入，只输出一个 JSON，不要输出任何其他文字、解释或 markdown。

JSON 格式（必须严格遵守）：
{"domain":"transaction|account","action":"create|query|filter|sort|refuse","targets":[],"fields":{}}

【domain 判断】
- 涉及记账/消费/收入/支出/转账/金额 → "transaction"
- 涉及创建账户/开户/新建账户/账户（"create a new account"/"new account"/"open account"）→ "account"
- 其他 → 按下方"领域边界"处理

【action 判断】
- "create"：记账（有金额数字，如"午饭35元"/"salary 8000"）或创建账户（"create a new account called test"）
- "query"：查询/查看（如"这个月花了多少"/"account balance"）
- "filter"：筛选（如"这个月的支出"）
- "sort"：排序（如"按金额排序"）
- "refuse"：与记账完全无关（见领域边界）

【记账 create（transaction）字段】
- "type"："expense"或"income"，二选一
- "amount"：数字（元），必须大于 0
- 可选：comment、accountId、categoryId、date（白名单，禁止其他字段）

【创建账户（account create）字段】
- "name"：账户名（必填）
- 可选："currency"（货币，默认"CNY"）、"accountType"（"bank"或"cash"）

【query/filter/sort 字段】
允许为空，或仅含：dateRange（"本月"/"上月"/"本周"/"今天"）、sortBy（"date"/"amount"）、sortDirection（"asc"/"desc"）

【领域边界：只处理记账相关】
你只处理记账和记账分析相关请求。与记账完全无关的请求（例如：写代码、编程、写文章、翻译、闲聊、数学题、新闻、天气、其他领域问题，中英文都包括）必须拒绝，统一输出：
{"domain":"transaction","action":"refuse","targets":[],"fields":{}}
判断标准：输入中没有任何记账/金额/收支/消费/账单/账户语义，即视为无关。

【示例】
"午饭35元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":35,"comment":"午饭"}}
"打车18.5元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":18.5,"comment":"打车"}}
"工资到账8000元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"income","amount":8000,"comment":"工资"}}
"create a new account called test" → {"domain":"account","action":"create","targets":[],"fields":{"name":"test"}}
"这个月花了多少" → {"domain":"transaction","action":"query","targets":[],"fields":{}}
"这个月的支出" → {"domain":"transaction","action":"filter","targets":[],"fields":{"dateRange":"本月"}}
"按金额排序" → {"domain":"transaction","action":"sort","targets":[],"fields":{"sortBy":"amount","sortDirection":"desc"}}
"帮我写一段Python代码" → {"domain":"transaction","action":"refuse","targets":[],"fields":{}}
"write a python function" → {"domain":"transaction","action":"refuse","targets":[],"fields":{}}
"今天天气怎么样" → {"domain":"transaction","action":"refuse","targets":[],"fields":{}}
"讲个笑话" → {"domain":"transaction","action":"refuse","targets":[],"fields":{}}
"translate this text" → {"domain":"transaction","action":"refuse","targets":[],"fields":{}}
"1+1等于几" → {"domain":"transaction","action":"refuse","targets":[],"fields":{}}

【再次强调】
- 输入只要没有记账/金额/收支/消费/账单/账户/创建账户 相关语义，一律 action="refuse"
- 写代码、编程、翻译、聊天、数学、天气、新闻、笑话、其他领域问题 → 必须 refuse
- 不要尝试把无关输入理解成记账或查询`;

export class AiService {
  private static instance: AiService;

  static getInstance(): AiService {
    if (!AiService.instance) {
      AiService.instance = new AiService();
    }
    return AiService.instance;
  }

  /** 全程调用大模型识别意图，并经过严格白名单校验 */
  async understand(text: string): Promise<AiIntent> {
    const intent = await this.callLlm(text);
    const validation = AiIntentValidator.validate(intent);
    if (!validation.valid) {
      throw new Error(validation.error);
    }
    return intent;
  }

  private async callLlm(text: string): Promise<AiIntent> {
    interface ChatMessage {
      role: string;
      content: string;
    }
    interface ChatRequestBody {
      model: string;
      messages: ChatMessage[];
      max_tokens: number;
      temperature: number;
    }
    const body: ChatRequestBody = {
      model: AI_CONFIG.model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: text }
      ],
      max_tokens: 600,
      temperature: 0.1
    };
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(
        `${AI_CONFIG.baseUrl}/chat/completions`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${AI_CONFIG.apiKey}`
          },
          extraData: JSON.stringify(body),
          connectTimeout: 30000,
          readTimeout: 60000
        }
      );
      if (response.responseCode !== 200) {
        throw new Error(`大模型接口错误 HTTP ${response.responseCode}`);
      }
      const data = JSON.parse(response.result as string) as Record<string, Object>;
      const choices = data['choices'] as Array<Record<string, Object>>;
      if (!choices || choices.length === 0) {
        throw new Error('大模型返回为空');
      }
      const message = choices[0]['message'] as Record<string, Object>;
      const content = message['content'] as string;
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('大模型返回非 JSON');
      }
      return JSON.parse(jsonMatch[0]) as AiIntent;
    } finally {
      httpRequest.destroy();
    }
  }
}
