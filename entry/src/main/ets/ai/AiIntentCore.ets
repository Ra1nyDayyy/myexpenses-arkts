/**
 * AI 意图的统一结构。字段值保持为 ArkTS 已支持的基础类型，方便 UI、
 * 校验器和执行器共享，避免在各层重复定义不兼容的对象形状。
 */
export interface AiIntent {
  domain: string;
  action: string;
  targets: string[];
  fields: Record<string, string | number>;
  subItems?: Array<Record<string, string | number>>;
  steps?: AiIntent[];
}

/** 安全校验结果；error 为空表示校验通过。 */
export interface AiIntentValidationResult {
  valid: boolean;
  error: string;
}
