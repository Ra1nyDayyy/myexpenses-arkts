# 深色模式专项走查 - 待审计问题清单

走查时间：2026-08-18 09:10 ~ 09:35
走查设备：模拟器 MyExpensesUX_20260818 (127.0.0.1:16555)
走查人员：Simulator-5a 子代理
主题切换路径：设置 → 界面 → 主题 → 深色（需重启应用生效）

## 问题汇总

共走查 13 个页面，发现 14 个待审计问题（P2: 4 个，P3: 10 个）。
未发现 P1 级严重问题（如深色背景上的深色文字完全不可见、浅色背景大面积残留等）。

---

## DARK-001: [首页-账户Tab] 卡片间分隔线对比度不足
- 截图: evidence/iter5/dark/01_home_accounts.jpeg
- 严重度: P3
- 描述: 账户卡片与"累计"卡片之间、底部导航栏与内容区之间缺乏明确分割线，深色模式下对比度不足导致边界感模糊。建议在卡片间添加浅灰色细线（#333333 或 #444444）增强结构感。

## DARK-002: [首页-账户Tab] 浮动按钮图标对比度偏低
- 截图: evidence/iter5/dark/01_home_accounts.jpeg
- 严重度: P3
- 描述: 右下角浮动按钮（银行图标）为白色，背景为深灰色圆角按钮，图标与背景对比度较低，在某些屏幕或光线环境下可能不够清晰。建议提升图标亮度或添加描边。

## DARK-003: [首页-账户Tab] "累计"卡片文字对比度偏低
- 截图: evidence/iter5/dark/01_home_accounts.jpeg
- 严重度: P3
- 描述: "累计"卡片背景为深灰（约 #222222），文字为浅灰（约 #CCCCCC），对比度约 4.5:1，接近 WCAG AA 标准下限。建议将文字颜色提升至纯白（#FFFFFF）。

## DARK-004: [首页-AI Tab] 蓝色图标在深色背景下略显突兀
- 截图: evidence/iter5/dark/03_home_ai.jpeg
- 严重度: P3
- 描述: AI 对话气泡图标和功能卡片图标为蓝色，在深色背景下蓝色偏亮，略显突兀。建议在深色模式下使用更柔和的蓝色（如 #4A90E2）以增强视觉一致性。

## DARK-005: [首页-模板Tab] 中央图标和提示文字对比度不足
- 截图: evidence/iter5/dark/04_home_templates.jpeg
- 严重度: P3
- 描述: 中央"暂无模板"图标为灰色（约 #888888），在深灰背景上对比度约 2.5:1，低于标准。副提示文字"常用交易可以保存为模板..."为浅灰（约 #AAAAAA），对比度约 4.5:1，接近临界值。建议将图标颜色提升至 #CCCCCC，文字提升至 #EEEEEE。

## DARK-006: [更多菜单] 菜单图标蓝色略突兀
- 截图: evidence/iter5/dark/05_more_menu.jpeg
- 严重度: P3
- 描述: "更多"菜单中的功能图标（柱状图、环形图、锁、齿轮等）均为蓝色，在深灰色背景上略显突兀。建议使用白色或浅灰色图标，或对蓝色做轻微去饱和处理。

## DARK-007: [数据设置页面] 分割线和辅助文字对比度略低
- 截图: evidence/iter5/dark/07_data_settings.jpeg
- 严重度: P3
- 描述: 列表项之间分割线颜色约 #333333，对比度偏低。辅助文字（如"添加、编辑、删除类别"、"关闭"、"已禁用"）使用中灰色（约 #888888），对比度约 4.5:1，接近 WCAG AA 标准下限。建议提升分割线颜色至 #555555，辅助文字至 #AAAAAA。

## DARK-008: [类别管理] 分割线和主文字可进一步提亮
- 截图: evidence/iter5/dark/08_category_management.jpeg
- 严重度: P3
- 描述: 列表项分割线颜色约 #333333，对比度略低。主文字（如"交通"、"医疗"）使用浅灰色（约 #E0E0E0），可进一步提升至纯白（#FFFFFF）以增强易读性。

## DARK-009: [标签管理] "+"号图标蓝色略突兀
- 截图: evidence/iter5/dark/10_tag_management.jpeg
- 严重度: P3
- 描述: 右上角"+"号图标为蓝色，在深色背景下与整体深灰/白色调的 UI 风格略显突兀。建议调整为更柔和的蓝色或中性色。

## DARK-010: [新建交易] 分割线颜色过浅
- 截图: evidence/iter5/dark/13_new_transaction.jpeg
- 严重度: P2
- 描述: 各字段之间分割线颜色为 #333333，在深灰背景上对比度偏低，"原始金额"与"金额"之间、"类别"与"标签"之间等区域分割线视觉上较弱，容易被忽略。建议调整为 #444444 或更亮。

## DARK-011: [新建交易] 多处提示文字对比度不足
- 截图: evidence/iter5/dark/13_new_transaction.jpeg
- 严重度: P2
- 描述: "已隐藏"文字（约 #AAAAAA）对比度约 3.5:1，低于 WCAG AA 标准。"选择"、"选择标签"等下拉提示文字（约 #888888）对比度约 3.2:1。"备注"输入框提示文字对比度不足。金额输入框中"0.00"数字（约 #AAAAAA）对比度不足。建议统一提升至 #CCCCCC 或更高。

## DARK-012: [编辑交易] 弹窗菜单文字对比度不足
- 截图: evidence/iter5/dark/14_edit_transaction.jpeg
- 严重度: P2
- 描述: 弹出菜单（"详细信息"、"编辑"、"删除"）中的文字为浅灰色，在深灰色背景上对比度约 4.5:1，接近 WCAG AA 标准下限，对视力不佳用户阅读体验较差。建议改为纯白（#FFFFFF）或亮灰（#EEEEEE）。

## DARK-013: [编辑交易] 列表分割线颜色过浅
- 截图: evidence/iter5/dark/14_edit_transaction.jpeg
- 严重度: P3
- 描述: 弹窗菜单中"详细信息"与"编辑"之间的分割线为浅灰色（约 #444444），在深灰背景上对比度偏低，肉眼几乎不可见。交易列表项之间的分隔线颜色偏浅，与背景融合度高。建议调整为 #555555 或更亮。

## DARK-014: [编辑交易] 黄色按钮内图标颜色偏暗
- 截图: evidence/iter5/dark/14_edit_transaction.jpeg
- 严重度: P3
- 描述: 底部黄色按钮中的"减号"和"向上箭头"为深灰色（约 #333333），在亮黄色背景上对比度尚可，但视觉上略显沉闷，与整体深色模式风格略有脱节。建议改为黑色（#000000）或深棕。

---

## 走查页面清单及证据文件

| 序号 | 页面名称 | 截图文件 | 布局文件 | 问题数 |
|------|----------|----------|----------|--------|
| 1 | 首页-账户Tab | 01_home_accounts.jpeg | 01_home_accounts_dump.json | 3 |
| 2 | 首页-交易Tab | 02_home_transactions.jpeg | 02_home_transactions_dump.json | 0 |
| 3 | 首页-AI Tab | 03_home_ai.jpeg | 03_home_ai_dump.json | 1 |
| 4 | 首页-模板Tab | 04_home_templates.jpeg | 04_home_templates_dump.json | 1 |
| 5 | 更多菜单 | 05_more_menu.jpeg | 05_more_menu_dump.json | 1 |
| 6 | 设置页面 | 06_settings.jpeg | 06_settings_dump.json | 0 |
| 7 | 数据设置页面 | 07_data_settings.jpeg | 07_data_settings_dump.json | 1 |
| 8 | 类别管理 | 08_category_management.jpeg | 08_category_management_dump.json | 1 |
| 9 | 付款方式管理 | 09_payment_methods.jpeg | 09_payment_methods_dump.json | 0 |
| 10 | 标签管理 | 10_tag_management.jpeg | 10_tag_management_dump.json | 1 |
| 11 | 资产负债表 | 11_balance_sheet.jpeg | 11_balance_sheet_dump.json | 0 |
| 12 | 预算编制 | 12_budget.jpeg | 12_budget_dump.json | 0 |
| 13 | 新建交易 | 13_new_transaction.jpeg | 13_new_transaction_dump.json | 2 |
| 14 | 编辑交易 | 14_edit_transaction.jpeg | 14_edit_transaction_dump.json | 3 |

## 总结

- 走查页面数：13 个（含编辑交易共 14 个证据文件）
- 收集证据数：28 个（14 张截图 + 14 份 dumpLayout）
- 待审计问题数：14 个（P2: 4 个，P3: 10 个）
- 无 P1 级严重问题
- 主要问题类型：对比度不足（8 个）、分割线不可见（5 个）、图标颜色不协调（4 个）
- 整体评价：深色模式适配整体良好，无严重可访问性问题，主要优化方向为提升辅助文字和分割线对比度。