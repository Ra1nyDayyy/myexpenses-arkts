# iter5 批次B 未覆盖功能走查 - 待审计问题清单

走查时间：2026-08-18 21:51 ~ 22:25
走查设备：127.0.0.1:16555（MyExpensesUX_20260818）
走查代理：Simulator-5b
任务ID：31

---

## FEAT-001: [模板Tab] 单击模板项无法快速创建交易
- 截图: evidence/iter5/templates/tpl_08_use_template.jpeg
- dump: evidence/iter5/templates/tpl_08_use_template_dump.json
- 严重度: P1
- 维度: D1 功能完整性 / D5 功能可达性
- 描述: 在模板列表页单击已有模板"测试模板A"后，无任何反应，未进入交易编辑页面也未创建交易。Android原版中，单击模板应直接基于该模板快速创建一笔交易（模板的核心功能即"一键记账"）。当前实现中只有长按展开详情→编辑的路径，缺失了模板最核心的"快速使用"交互入口。
- 复现步骤: 模板Tab → 单击模板项 → 无反应
- 预期行为: 单击模板项应直接跳转到新建交易页面，且各字段已预填模板值（标题、金额、类别等）
- 实际行为: 无任何反应，停留在模板列表页

---

## FEAT-002: [账户编辑] 起始余额被放大100倍保存
- 截图: evidence/iter5/account_edit/acct_03_edit.jpeg（编辑前）
- 截图: evidence/iter5/account_edit/acct_05_saved.jpeg（保存后）
- dump: evidence/iter5/account_edit/acct_03_edit_dump.json
- dump: evidence/iter5/account_edit/acct_05_saved_dump.json
- 严重度: P1
- 维度: D4 数据正确性
- 描述: 账户"测试账户1"原起始余额为1000.00元（内部存储100000分）。进入编辑页面时，起始余额字段显示为"100000"（分值，未除以100转换为元）。保存后，起始余额被当作100000元存入数据库，导致累计余额从¥820.00暴涨至¥99820.00。这是严重的金额单位转换Bug——编辑页面读取起始余额时未将"分"转换为"元"，保存时又将其作为"元"存储。
- 复现步骤: 账户Tab → 点击账户 → 编辑 → 不修改起始余额 → 保存 → 起始余额从1000.00变为100000.00
- 预期行为: 编辑页面起始余额应显示为"1000.00"（元），保存后保持不变
- 实际行为: 编辑页面显示"100000"（分），保存后起始余额变为100000.00元，余额错误增长99000元

---

## FEAT-003: [设置-功能] 扫描收据/OCR设置显示"开发中"
- 截图: evidence/iter5/settings/set_07_function.jpeg
- dump: evidence/iter5/settings/set_07_function_dump.json
- 严重度: P2
- 维度: D1 功能完整性
- 描述: 设置→功能（扫描收据）子页面仅显示"OCR设置 - 开发中"，功能未实现。Android原版中该页面有OCR引擎选择、API密钥配置等完整设置项。
- 预期行为: 显示OCR识别相关设置项（引擎选择、API Key输入等）
- 实际行为: 仅显示"OCR设置 - 开发中"占位文字

---

## FEAT-004: [设置-同步] 同步设置显示"开发中"
- 截图: evidence/iter5/settings/set_08_sync.jpeg
- dump: evidence/iter5/settings/set_08_sync_dump.json
- 严重度: P2
- 维度: D1 功能完整性
- 描述: 设置→同步子页面仅显示"同步设置 - 开发中"，功能未实现。Android原版支持WebDAV/Drive/Dropbox等多种同步方式配置。
- 预期行为: 显示云端同步配置选项（WebDAV、Google Drive、Dropbox等）
- 实际行为: 仅显示"同步设置 - 开发中"占位文字

---

## FEAT-005: [设置-Web界面] Web界面设置显示"开发中"
- 截图: evidence/iter5/settings/set_09_web.jpeg
- dump: evidence/iter5/settings/set_09_web_dump.json
- 严重度: P2
- 维度: D1 功能完整性
- 描述: 设置→Web界面子页面仅显示"Web界面设置 - 开发中"，功能未实现。
- 预期行为: 显示Web服务器端口、密码等配置项
- 实际行为: 仅显示"Web界面设置 - 开发中"占位文字

---

## FEAT-006: [设置-附加图片] 附加图片设置显示"开发中"
- 截图: evidence/iter5/settings/set_10_attachment.jpeg
- dump: evidence/iter5/settings/set_10_attachment_dump.json
- 严重度: P2
- 维度: D1 功能完整性
- 描述: 设置→附加图片子页面仅显示"附加图片设置 - 开发中"，功能未实现。
- 预期行为: 显示交易附件相关设置（图片压缩、存储路径等）
- 实际行为: 仅显示"附加图片设置 - 开发中"占位文字

---

## FEAT-007: [设置-打印] 打印设置显示"开发中"
- 截图: evidence/iter5/settings/set_11_print.jpeg
- dump: evidence/iter5/settings/set_11_print_dump.json
- 严重度: P2
- 维度: D1 功能完整性
- 描述: 设置→打印子页面仅显示"打印设置 - 开发中"，功能未实现。
- 预期行为: 显示打印相关设置选项
- 实际行为: 仅显示"打印设置 - 开发中"占位文字

---

## FEAT-008: [交易编辑] 付款方法字段点击无反应
- 截图: evidence/iter5/edge_cases/edge_10_payment_method.jpeg
- dump: evidence/iter5/edge_cases/edge_10_payment_method_dump.json
- 严重度: P2
- 维度: D1 功能完整性 / D5 功能可达性
- 描述: 在新建交易编辑页面，点击"付款方法"字段（标签或值"现金"）均无反应，未弹出付款方式选择页面。当前仅有默认值"现金"无法切换为其他付款方式（如信用卡、支付宝等）。
- 复现步骤: 交易Tab → FAB → 支出 → 点击"付款方法"行 → 无反应
- 预期行为: 弹出付款方式选择列表，可切换为其他已配置的付款方式
- 实际行为: 无任何反应，无法切换付款方式

---

## FEAT-009: [交易编辑] 标签字段点击无反应
- 截图: evidence/iter5/edge_cases/edge_11_tag_select.jpeg
- dump: evidence/iter5/edge_cases/edge_11_tag_select_dump.json
- 严重度: P2
- 维度: D1 功能完整性 / D5 功能可达性
- 描述: 在新建交易编辑页面，点击"标签"字段（标签或"选择标签"值）均无反应，未弹出标签选择页面。无法为交易添加标签。
- 复现步骤: 交易Tab → FAB → 支出 → 点击"选择标签"行 → 无反应
- 预期行为: 弹出标签选择页面，可选择或新建标签
- 实际行为: 无任何反应，无法选择标签

---

## 走查覆盖总结

### 已覆盖页面/场景（共22个场景）
1. 模板Tab列表页（空状态）- tpl_01
2. 模板新建页面 - tpl_02
3. 模板标题输入 - tpl_03
4. 模板金额输入 - tpl_04
5. 模板分类选择页 - tpl_05
6. 模板分类已选 - tpl_06
7. 模板保存后列表 - tpl_07
8. 模板单击（无反应）- tpl_08
9. 模板长按展开详情 - tpl_08b
10. 模板编辑已有 - tpl_09
11. 更多Tab抽屉菜单 - set_01
12. 设置主页面 - set_02
13. 设置-数据子页面 - set_03
14. 设置-界面子页面 - set_04
15. 设置-导入/导出子页面 - set_05
16. 设置-备份与恢复子页面 - set_06
17. 设置-功能（扫描收据）子页面 - set_07
18. 设置-同步子页面 - set_08
19. 设置-Web界面子页面 - set_09
20. 设置-附加图片子页面 - set_10
21. 设置-打印子页面 - set_11
22. 账户详情展开 - acct_02
23. 账户编辑页面 - acct_03
24. 账户保存后验证 - acct_05
25. 交易列表页 - edge_01
26. 复杂搜索页 - edge_02
27. 搜索备注弹窗 - edge_03
28. 空搜索结果 - edge_04
29. 新建交易FAB菜单 - edge_06
30. 新建支出交易页 - edge_07
31. 日期选择器 - edge_08
32. 分类选择页 - edge_09
33. 付款方法（无反应）- edge_10
34. 标签选择（无反应）- edge_11

### 证据统计
- 截图：40+ 张 JPEG
- dumpLayout：40+ 份 JSON
- 覆盖类别：templates / settings / account_edit / edge_cases

### 问题统计
- P1 严重问题：2个（FEAT-001, FEAT-002）
- P2 功能缺失：7个（FEAT-003 ~ FEAT-009）
- P3 次要问题：0个
- 总计：9个待审计问题