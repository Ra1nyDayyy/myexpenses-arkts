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
{"domain":"transaction|account","action":"create|query|filter|sort|edit|delete|refuse","targets":[],"fields":{}}

【多步骤任务】
如果用户一句话包含多个顺序操作（用"然后/再/最后/并且"连接，如"创建一个旅行账户，然后记一笔560元酒店，再记85元打车，最后告诉我花了多少"），
输出 {"steps":[{子意图}, {子意图}, ...]}，不输出 domain/action。
每个子意图遵循下方单步规则。

【action 判断】
- "create"：记账（有金额数字，如"午饭35元"/"salary 8000"）或创建账户（"create a new account called test"）
- "query"：查询/查看（如"这个月花了多少"/"account balance"）
- "filter"：筛选（如"这个月的支出"）
- "sort"：排序（如"按金额排序"）
- "edit"：修改（如"把咖啡改成40元"，targets=被改对象，fields=新值）
- "delete"：删除（如"删除咖啡那笔"，targets=删除对象，可含 amount 缩小范围）
- "refuse"：与记账完全无关（见领域边界）

【账户操作（account 域）】
判断：输入涉及账户本身（创建/查询余额/列表/改名/删除账户，如"创建一个旅行基金账户"、"现金余额多少"、"我有哪些账户"、"把旅行基金改名叫日本旅行"、"删除测试账户"），domain="account"。
- account/create：fields.name（账户名，必填）、currency、accountType（bank/cash）
- account/query：targets=[账户名]（如"现金余额多少"→targets=["现金"]）；查询全部账户时 targets=[]（如"我有哪些账户"）
- account/edit：targets=[账户名]，fields 含新值（name/currency/accountType）
- account/delete：targets=[账户名]（如"删除测试账户"→targets=["测试"]）

【模板操作（template 域）】
判断：输入涉及模板本身（创建模板/查看模板/修改模板/删除模板/用模板记一笔，如"创建一个早餐模板每次15元"、"查看我的模板"、"把早餐模板改成18元"、"使用早餐模板记一笔"、"删除早餐模板"），domain="template"。
- template/create：fields.title（标题）、amount（金额）、type（expense/income）、comment（备注）、recurrence（周期）
- template/query：targets=[]（"查看我的模板"）
- template/edit：targets=[模板名]，fields 含新值（title/amount）
- template/delete：targets=[模板名]
- template/use：targets=[模板名]（"使用XX模板记一笔"）

【记账 create（transaction）字段】
- "type"："expense"或"income"，二选一
- "amount"：数字（元），必须大于 0
- "account"：账户名（用户输入中提到的账户，如"现金"、"支付宝"；未提到则不填）
- "category"：分类名（如"餐饮"、"交通"；未提到则不填）
- 可选：comment（备注）、date（时间戳或"今天/昨天/前天/晚上"等相对时间）
- 禁止输出 accountId/categoryId 数字（由系统按名称匹配）

【query/filter/sort 字段】
允许为空，或含：dateRange（"本月"/"上月"/"本周"/"今天"/"昨天"）、account（账户名，如"支付宝"）、category（分类名，如"餐饮"）、amount（最小金额）、comment（备注关键字）、type（"expense"/"income"，按输入语义判断，如"支出/花了"→expense，"收入/工资"→income）、sortBy（"date"/"amount"）、sortDirection（"asc"/"desc"）

【领域边界：只处理记账相关】
你只处理记账和记账分析相关请求。与记账完全无关的请求（例如：写代码、编程、写文章、翻译、闲聊、数学题、新闻、天气、其他领域问题，中英文都包括）必须拒绝，统一输出：
{"domain":"transaction","action":"refuse","targets":[],"fields":{}}
判断标准：输入中没有任何记账/金额/收支/消费/账单/账户语义，即视为无关。

【示例】
"午饭35元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":35,"comment":"午饭"}}
"打车18.5元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":18.5,"comment":"打车","category":"交通"}}
"工资到账8000元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"income","amount":8000,"comment":"工资","category":"工资"}}
"从现金账户记一笔午饭35元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":35,"comment":"午饭","account":"现金"}}
"支付宝花了28元打车" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":28,"comment":"打车","account":"支付宝","category":"交通"}}
"昨天午饭35元" → {"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":35,"comment":"午饭","date":"昨天"}}
"create a new account called test" → {"domain":"account","action":"create","targets":[],"fields":{"name":"test"}}
"这个月花了多少" → {"domain":"transaction","action":"query","targets":[],"fields":{}}
"这个月的支出" → {"domain":"transaction","action":"filter","targets":[],"fields":{"dateRange":"本月"}}
"按金额排序" → {"domain":"transaction","action":"sort","targets":[],"fields":{"sortBy":"amount","sortDirection":"desc"}}
"删除咖啡那笔" → {"domain":"transaction","action":"delete","targets":["咖啡"],"fields":{}}
"删除昨天35元的午饭" → {"domain":"transaction","action":"delete","targets":["午饭"],"fields":{"amount":35}}
"把咖啡那笔改成40元" → {"domain":"transaction","action":"edit","targets":["咖啡"],"fields":{"amount":40}}
"创建一个旅行账户，然后记一笔560元酒店，再记85元打车，最后告诉我花了多少" → {"steps":[{"domain":"account","action":"create","targets":[],"fields":{"name":"旅行"}},{"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":560,"comment":"酒店"}},{"domain":"transaction","action":"create","targets":[],"fields":{"type":"expense","amount":85,"comment":"打车","category":"交通"}},{"domain":"transaction","action":"query","targets":[],"fields":{}}]}
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

/** 大模型识别结果（含思考过程） */
export interface AiUnderstandResult {
  intent: AiIntent;
  thinking: string;
}

export class AiService {
  private static instance: AiService;

  static getInstance(): AiService {
    if (!AiService.instance) {
      AiService.instance = new AiService();
    }
    return AiService.instance;
  }

  /** 全程调用大模型识别意图，并经过严格白名单校验；images 为可选多模态图片（base64 data-url） */
  async understand(text: string, images?: string[]): Promise<AiIntent> {
    const intent = await this.callLlm(text, images);
    const validation = AiIntentValidator.validate(intent);
    if (!validation.valid) {
      throw new Error(validation.error);
    }
    return intent;
  }


  /**
   * 开启思考模式的意图识别：请求携带 enable_thinking，返回意图与思考过程（reasoning_content）。
   * onThinking 回调用于实时展示思考进度（非流式场景在完成后一次性回调）。
   */
  async understandWithThinking(text: string, images?: string[], onThinking?: (thinking: string) => void): Promise<AiUnderstandResult> {
    const result = await this.callLlmWithThinking(text, images);
    if (onThinking && result.thinking) {
      onThinking(result.thinking);
    }
    const validation = AiIntentValidator.validate(result.intent);
    if (!validation.valid) {
      throw new Error(validation.error);
    }
    return result;
  }

  private async callLlmWithThinking(text: string, images?: string[]): Promise<AiUnderstandResult> {
    interface ImageUrlPart {
      url: string;
    }
    interface ChatContentPart {
      type: string;
      text?: string;
      image_url?: ImageUrlPart;
    }
    interface ChatMessage {
      role: string;
      content: string | ChatContentPart[];
    }
    interface ChatRequestBody {
      model: string;
      messages: ChatMessage[];
      max_tokens: number;
      temperature: number;
      enable_thinking: boolean;
    }
    // 组装 user 消息：纯文本时用字符串；带图片时用多模态 content 数组
    let userContent: string | ChatContentPart[] = text;
    if (images && images.length > 0) {
      const parts: ChatContentPart[] = [{ type: 'text', text: text }];
      for (const img of images) {
        const imgUrl: ImageUrlPart = { url: img };
        const part: ChatContentPart = {
          type: 'image_url',
          image_url: imgUrl
        };
        parts.push(part);
      }
      userContent = parts;
    }
    const body: ChatRequestBody = {
      model: AI_CONFIG.model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userContent }
      ],
      max_tokens: 800,
      temperature: 0.1,
      enable_thinking: true
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
          readTimeout: 120000
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
      const thinking = (message['reasoning_content'] as string) || '';
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('大模型返回非 JSON');
      }
      const matched = jsonMatch[0];
      const intent = JSON.parse(matched) as AiIntent;
      const result: AiUnderstandResult = { intent: intent, thinking: thinking };
      return result;
    } finally {
      httpRequest.destroy();
    }
  }

  private async callLlm(text: string, images?: string[]): Promise<AiIntent> {
    interface ImageUrlPart {
      url: string;
    }
    interface ChatContentPart {
      type: string;
      text?: string;
      image_url?: ImageUrlPart;
    }
    interface ChatMessage {
      role: string;
      content: string | ChatContentPart[];
    }
    interface ChatRequestBody {
      model: string;
      messages: ChatMessage[];
      max_tokens: number;
      temperature: number;
    }
    // 组装 user 消息：纯文本时用字符串；带图片时用多模态 content 数组
    let userContent: string | ChatContentPart[] = text;
    if (images && images.length > 0) {
      const parts: ChatContentPart[] = [{ type: 'text', text: text }];
      for (const img of images) {
        const imgUrl: ImageUrlPart = { url: img };
        const part: ChatContentPart = {
          type: 'image_url',
          image_url: imgUrl
        };
        parts.push(part);
      }
      userContent = parts;
    }
    const body: ChatRequestBody = {
      model: AI_CONFIG.model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userContent }
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
