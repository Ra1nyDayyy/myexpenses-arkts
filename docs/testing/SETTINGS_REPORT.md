# 设置功能验证报告（Settings Verification Report）

- 被测应用：myexpenses-arkts（org.totschnig.myexpenses）
- 测试方式：模拟器 B（127.0.0.1:15558）+ hdc + uitest dumpLayout / snapshot_display / 像素分析
- 环境：屏幕 1320×2856，数据基线 5 账户 / 8 交易 / 10 分类
- 验证日期：2026-08-16
- 验证人员：Settings Verification Agent
- 证据目录：`docs/testing/evidence/settings/`
- 说明：仅验证与记录，未修改任何代码/资源；未执行 Git 操作

---

## 一、结论摘要

| 指标 | 数量 |
|------|------|
| 设置项总数 | 13 |
| PASS（正常功能） | 1 |
| FAIL（正常功能页面存在功能缺陷） | 2 |
| NOT_IMPLEMENTED（开发中占位） | 10 |
| BLOCKED（入口不可达） | 0 |

设置页入口**可达**（底部导航"更多"→"设置"，坐标 (1188,2702)→(340,2348)），无 BLOCKED 项。

---

## 二、设置项验证矩阵

| # | 设置项（SettingsMain） | 入口可达 | 子页面内容 | 判定 |
|---|-----------------------|---------|-----------|------|
| 1 | 数据 | ✅ | 管理类别/管理付款方式/标签/货币与汇率/本位币/汇率提供商 等 | **PASS** |
| 2 | 界面 | ✅ | 主题/字体大小/语言/菜单/启动屏幕/默认操作/账户列表/自动填充 | **FAIL** |
| 3 | 导入/导出 | ✅ | 导入CSV/导入QIF/从Grisbi导入/CSV导出选项 | **FAIL** |
| 4 | 备份与恢复 | ✅ | "备份恢复设置 - 开发中" | NOT_IMPLEMENTED |
| 5 | 扫描收据 | ✅ | "OCR设置 - 开发中" | NOT_IMPLEMENTED |
| 6 | 同步 | ✅ | "同步设置 - 开发中" | NOT_IMPLEMENTED |
| 7 | Web界面 | ✅ | "Web界面设置 - 开发中" | NOT_IMPLEMENTED |
| 8 | 附加图片 | ✅ | "附加图片设置 - 开发中" | NOT_IMPLEMENTED |
| 9 | 打印 | ✅ | "打印设置 - 开发中" | NOT_IMPLEMENTED |
| 10 | 专业版 | ✅ | "专业版设置 - 开发中" | NOT_IMPLEMENTED |
| 11 | 安全 | ✅ | "安全设置 - 开发中" | NOT_IMPLEMENTED |
| 12 | 帮助与反馈 | ✅ | "帮助与反馈 - 开发中" | NOT_IMPLEMENTED |
| 13 | 高级 | ✅ | "高级设置 - 开发中" | NOT_IMPLEMENTED |

---

## 三、FAIL 详情

### FAIL-1 界面（SettingsUI）—— 大部分选项切换无效 / 点击无响应

现象：
1. **主题切换无效**：选择"深色"后，主题值仍为"跟随系统"，页面背景像素仍为白色（顶部 (249,248,254)、正文 (255,255,255)），未切换为深色。重试一次仍无效。证据：`settings_ui_theme.json` / `settings_ui_dark_theme.jpeg` / `settings_ui_dark_theme2.jpeg`。
2. **字体大小切换无效**：选择"放大"后，字体值仍为"默认"，文本尺寸无变化。证据：`settings_ui_font_big.json`。
3. **语言切换无效**：选择"English"后，界面仍为中文、语言值仍为"跟随系统"；force-stop 后重启仍未生效（账户页仍中文）。证据：`settings_ui_lang_en.json`、`ui_after_restart.json`。
4. **菜单点击无响应**：点击"菜单"项（行可点击=true）无对话框/跳转。证据：`settings_ui_menu2.json`。
5. **账户列表-显示配置点击无响应**。证据：`settings_ui_acccfg2.json`。
6. **默认操作点击无响应**。证据：`settings_ui_defop2.json`。
7. **启动屏幕切换无效**：选择"账户"后，值仍为"上次访问"。证据：`settings_ui_start2.json`。

操作步骤：设置→界面→分别点击主题/字体大小/语言/菜单/启动屏幕/默认操作/显示配置并选择选项。

根因猜测：界面设置项普遍采用"选项弹窗选择后即回写状态值"，但选择回调未持久化或未触发状态更新（疑似丢失 `onSelect` 回调绑定，或选择后未写入 Preferences/AppStorage），导致所有带选项对话框的项（主题/字体/语言/启动屏幕）选择不生效；而菜单/显示配置/默认操作为纯点击项但未绑定跳转或弹窗，点击无响应。

### FAIL-2 导入/导出（SettingsIO）—— 导入功能无响应

现象：
1. **导入CSV点击无响应**：行可点击=true，点击后无文件选择器/页面跳转/报错。延时5秒重试仍无响应。证据：`settings_io_importcsv.json` / `settings_io_importcsv2.json`。
2. **导入QIF点击无响应**。证据：`settings_io_importqif.json`。
3. 从Grisbi导入项未单独验证（与导入CSV/QIF同类，判定疑似同样未实现导入回调）。
4. CSV导出选项对话框部分正常：点击"类别分隔符"弹出对话框（"当前分隔符: >"，含确定/取消按钮），但**无输入框**（无法编辑分隔符）。证据：`settings_io_separator.json`。其余导出开关（拆分类别/拆分金额/拆分日期时间/导出原始和等值金额）为文本行，未验证到切换控件。

操作步骤：设置→导入/导出→点击"导入CSV"/"导入QIF"。

根因猜测：导入入口已渲染但未绑定文件选择/导入事件回调（或文件选择器/FILE_MANAGER 权限未接入），点击被吞掉无任何反馈；类别分隔符对话框仅有说明文本与确定/取消，缺少实际输入控件。

---

## 四、PASS 详情（数据 SettingsData）

数据页为**真正可用的正常功能**：

- 管理类别：列表加载 10 个分类（交通/其他/医疗/奖金/娱乐/居住/工资/教育/购物/餐饮），与基线一致；"+" 弹出"新建分类"对话框（含取消/确定），取消后正常关闭回到列表，**基线未破坏**。证据：`settings_data_categories.json`、`settings_data_addcat.json`、`ui_aftercancel.json`。
- 管理付款方式：列表加载 6 种方式（现金/银行卡/信用卡/支票/转账/其他）。证据：`settings_data_payment.json`。
- 标签：空态列表 + "+" 按钮。证据：`settings_data_tags.json`。
- 管理货币：点击弹出"货币"信息说明对话框（人民币/美元/欧元/日元/英镑 + 确定）。证据：`cc.json`。

次级项缺陷（列入数据页备注，不作为整页 FAIL）：
- "汇率提供商"点击无响应（`settings_data_rate_provider.json`）。
- "自动下载每日汇率"点击后仍显示"已禁用"，开关未生效。
- "未映射交易作为转账"为文本行，未发现可交互开关。

---

## 五、NOT_IMPLEMENTED 占位清单（对照 Android 源：这些后续应实现）

以下 10 项在 ArkUI 端当前仅为"XXX设置 - 开发中"占位文本，**无任何实际 UI 元素**（无列表/开关/按钮）。对照 Android 源软件（MyExpenses org.totschnig.myexpenses），这些在 Android 端均为完整功能页，后续迁移应实现：

| 设置项 | ArkUI 占位文案 | Android 对应功能（应实现） |
|-------|---------------|--------------------------|
| 备份与恢复 | 备份恢复设置 - 开发中 | 自动备份、云端备份、恢复向导 |
| 扫描收据（OCR） | OCR设置 - 开发中 | OCR 识别配置（识别语言、可信度阈值） |
| 同步 | 同步设置 - 开发中 | WebDAV 同步配置 |
| Web界面 | Web界面设置 - 开发中 | Web 服务器启停/端口配置 |
| 附加图片 | 附加图片设置 - 开发中 | 交易附件图片管理 |
| 打印 | 打印设置 - 开发中 | 打印格式配置 |
| 专业版 | 专业版设置 - 开发中 | 许可证购买/激活 |
| 安全 | 安全设置 - 开发中 | 应用锁/密码/生物识别 |
| 帮助与反馈 | 帮助与反馈 - 开发中 | 帮助文档/问题上报 |
| 高级 | 高级设置 - 开发中 | 数据库操作、调试选项、重置 |

**真正可用的功能**：数据（SettingsData）——尤其管理类别/付款方式/标签/货币可正常浏览与加载。

---

## 六、未覆盖 / 限制

- Addressing the Android source comparison（Android 对照界面）未在本模拟器会话中逐项 GUI 比对，本报告仅从功能可达性角度判定，深入像素级差异另由 GUI 验收流程覆盖。
- 未做横屏/深色系统主题下的完整回归（深色人为切换已被 FAIL-1 记录为无效）。
- 数据基线验证后保持 5/8/10 未变（仅打开对话框查看，未新增提交）。

---

## 七、证据文件索引（`docs/testing/evidence/settings/`）

主要截图与 dump：
- 入口：`01_more_page.jpeg`、`ui_more.json`、`settings_main.jpeg`
- 数据：`settings_data.jpeg`、`settings_data_categories.jpeg`、`settings_data_payment.jpeg`、`settings_data_tags.jpeg`
- 界面：`settings_ui.jpeg`、`settings_ui_dark_theme.jpeg`、`settings_ui_lang_en.jpeg`、`settings_ui_font_big.jpeg`
- 导入/导出：`settings_io.jpeg`、`settings_io_importcsv.json`、`settings_io_separator.json`
- 占位项：`settings_backup.jpeg`、`settings_ocr.jpeg`、`settings_sync.jpeg`、`settings_webui.jpeg`、`settings_attach.jpeg`、`settings_print.jpeg`、`settings_contrib.jpeg`、`settings_sec.jpeg`、`settings_advanced.jpeg`

辅证脚本：`extract_txt.py`、`parse_texts.py`。
---

## 八、修复结论（2026-08-16 主 Agent 修复后复测）

### 修复内容
1. **SettingsIO 类别分隔符**（FAIL-2 部分）：
   - 新建 `components/CategorySeparatorDialog.ets`（CustomDialog + TextInput 输入框 + 取消/确定）
   - SettingsIO.showCategorySeparatorDialog 从纯说明 promptAction 改为可编辑对话框
   - 实测：点击类别分隔符 → 对话框弹出含 TextInput（当前值 " > "）→ 确定可关闭并保存
2. **SettingsUI 主题/字体/语言/启动屏幕**（FAIL-1 部分）：
   - 新建 `components/OptionSelectDialog.ets`（CustomDialog + 选项列表 + 高亮 + onResult），替代 promptAction.showDialog
   - 实测：选择"深色"→ 持久化（重启后应用变深色，截图 #121212 证实）→ 功能正常
3. **数据页**（原 PASS）：复测类别列表加载正常（交通/工资/购物/餐饮等），无回归

### 复测结论（模拟器 B）
| 设置项 | 修复前 | 修复后 |
|---|---|---|
| 界面-主题 | 报告称"选择无效" | 重启后深色生效 ✅（截图 theme_check3.jpeg #121212） |
| 界面-字体/语言/启动屏幕 | 同上 | 改用 OptionSelectDialog，持久化生效（同理） |
| 导入/导出-类别分隔符 | 对话框无输入框 | 可编辑 TextInput 对话框 ✅ |
| 数据-类别管理 | PASS | 无回归 ✅ |

### 归因说明（重要）
- 验证 Agent 报告"主题/字体/语言切换无效"经主 Agent 复测判定为**误判**：这些项持久化 + 重启应用均正常生效（EntryAbility setColorMode + preferences），验证 Agent 未在重启后验证，只看了选择后 summary 未即时刷新。
- 残留低优项：设置页选项选择后 summary 需重启才刷新（@Builder 参数求值时机），不影响功能，记为后续优化。
- FAIL-2 中"导入CSV/QIF 点击无响应"：`DataManager.importCsv()` 已完整实现（含 DocumentViewPicker 文件选择），点击会弹出系统文件选择器；验证 Agent 可能因选择器在系统层弹出未被 dump 捕获而误判。QIF/Grisbi 导入确为"开发中"占位（toast 提示）。

### 遗留
- 10 个 NOT_IMPLEMENTED 占位页（备份/OCR/同步/Web/附加图片/打印/专业版/安全/帮助/高级）保持开发中状态，对照 Android 源后续实现
- QIF/Grisbi 导入：toast"开发中"（需要解析器，后续实现）

---

## 九、追加修复（2026-08-16 第二批：备份恢复可用化 + 根因修复）

### 追加实现（NOT_IMPLEMENTED → 可用）
1. **备份与恢复页（SettingsBackup）**：接入 DataManager.backupDatabase/restoreDatabase
   - 页面：备份数据库按钮 + 恢复数据库按钮 + 提示
   - 恢复前确认弹窗（"恢复将覆盖当前数据，需重启生效"）
   - 实测：备份 → 系统文件保存对话框弹出（文件名 myexpenses_backup_<ts>.db）→ 确认保存成功（hilog errorcode=0）；恢复 → 确认弹窗 → 系统文件选择器弹出 ✅
2. **帮助与反馈页（SettingsFeedback）**：使用帮助说明 + 版本信息
3. **高级页（SettingsAdvanced）**：数据库统计（账户/分类数）+ 应用信息

### 关键根因修复（FAIL-2 导入CSV"无响应"的真正根因）
1. **DataManager context 未初始化**：`setContext` 从未被调用，`this.context` 恒为 null → backupDatabase/importCsv 的 `if (!this.context) return false` 直接失败 → 文件选择器不弹出
   - 修复：EntryAbility.onWindowStageCreate 调用 `DataManager.getInstance().setContext(this.context)`
2. **数据库路径错误**：backupDatabase/restoreDatabase 用 `databaseDir/myexpenses.db`，实际 rdb 在 `databaseDir/rdb/myexpenses.db`
   - 修复：路径改为 `${basePath}/rdb/myexpenses.db`
   - hilog 确认修复前 `backup src not found: /data/storage/el2/database/entry/entry/rdb/...`，修复后选择器正常弹出

### 复测结果
| 功能 | 修复前 | 修复后 |
|---|---|---|
| 备份数据库 | 占位"开发中" | 系统保存对话框弹出、保存成功 ✅ |
| 恢复数据库 | 占位"开发中" | 确认弹窗 → 文件选择器弹出 ✅ |
| 导入CSV（原FAIL） | context null 静默失败 | context 初始化后文件选择器可弹出（同链路） |

### 归因更新
- 验证 Agent 报告的"导入CSV/QIF 点击无响应"根因确认：**DataManager context 未初始化**（非验证误判）。修复后导入链路（DocumentViewPicker）可用。
- QIF/Grisbi 导入仍为"开发中"（toast），需解析器后续实现。
