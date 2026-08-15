# MyExpenses (Android) → arkts_new (HarmonyOS) 全方位测试计划

**版本**: 1.0
**制定日期**: 2026-08-14
**迁移状态**: ACCEPTANCE_CANDIDATE（验收候选）
**测试阶段**: 验收候选阶段——全量回归 + 未覆盖项补充 + 待验证差异项复验

---

## 1. 测试目标与范围

### 1.1 测试目标

1. **验收回归**：复验已 PASS 的 18 项功能/界面测试（function-tests.md 两轮），确认在最新代码上仍然通过。
2. **未覆盖项补测**：补齐此前受工具限制无法自动化的项（转账"选目标账户"完整 UI 流程等）。
3. **差异项复验**：针对 `UI功能差异报告.md`（2026-08-14）列出的差异项逐一验证真实状态（已实现 / 已知缺失 / 与报告不符），澄清报告与当前代码不一致之处。
4. **维度扩展**：在既有"功能 + GUI 像素"基础上，补齐**主题（深/浅）、生命周期（前后台/常驻/重启）、数据持久化（重启后数据保留、增删改落库）**三个维度的证据。
5. **为 Complete 门禁做准备**：产出 unit_tests / device_tests / release / review 之外的模拟器侧可完成证据，识别必须真机/签名才能完成的项。

### 1.2 本期验证范围（参照 sources.json guiRequirements + scope.md）

**GUI 像素验收（guiRequirements 声明组合）**：

| 页面 | 状态 | 方向 | 主题 | 语言 |
|---|---|---|---|---|
| Main（empty / account_list） | 双状态 | PORTRAIT | LIGHT + DARK | zh-CN |
| AccountEdit（default） | 单状态 | PORTRAIT | LIGHT + DARK | zh-CN |
| ExpenseEdit（default） | 单状态 | PORTRAIT | LIGHT + DARK | zh-CN |
| AiAssistant（default） | 单状态 | PORTRAIT | LIGHT + DARK | zh-CN |

**功能验证范围**：
- 账户管理（列表 / 展开操作 / 分组 / 类型累计 / 搜索）
- 交易记录（列表 / 汇总卡片 / 点击编辑 / 多选删除 / FAB 菜单 / 长按）
- 记账编辑（支出 / 收入 / 转账 / 拆分 / 模板 / 原始金额 / 标签 / 收款人）
- 模板与周期计划
- 分类 / 标签 / 支付方式管理
- 预算 / 债务管理
- 资产负债表
- 搜索
- 设置（数据 / 界面 / 导入导出 / 备份恢复等入口）
- AI 助手

### 1.3 本期不验证（范围外，参照 scope.md 分阶段项）

| 项 | 状态 |
|---|---|
| 云同步（WebDAV / Dropbox / OneDrive / 同步后端） | 不在本期验收 |
| 系统小部件（AccountWidget / TemplateWidget / BudgetWidget） | 分阶段项 |
| OCR 识别 / Tesseract / ML Kit | 分阶段项 |
| 日历集成 / 桌面快捷方式 | 分阶段项 |
| 广告与贡献许可（Contrib 内购） | 分阶段项 |
| 附件（图片/PDF 上传）、位置(GPS)、重复计划的完整生态 | 报告标注缺失，本期仅验证入口/提示状态，不验收实现 |

---

## 2. 测试环境

| 项 | 值 |
|---|---|
| **Android 模拟器** | adb 连接：`emulator-5554`；已装 `org.totschnig.myexpenses.debug`；分辨率基准 Pixel_10 1080x2424 |
| **HarmonyOS 模拟器** | hdc 连接：`127.0.0.1:5557`；已装 `org.totschnig.myexpenses`；当前有运行任务 |
| **Android 包名** | `org.totschnig.myexpenses.debug` |
| **HarmonyOS bundle** | `org.totschnig.myexpenses` |
| **HAP 产物** | `entry/build/default/outputs/default/entry-default-unsigned.hap`（debug unsigned，约 774KB） |
| **应用版本** | 两端均以当前已安装实例为准，测试前记录版本号 |

### 2.1 工具与命令速查

| 用途 | Android（adb） | HarmonyOS（hdc） |
|---|---|---|
| 启动应用 | `adb shell monkey -p org.totschnig.myexpenses.debug 1` | `hdc shell aa start -a EntryAbility -b org.totschnig.myexpenses` |
| 停止应用 | `adb shell am force-stop org.totschnig.myexpenses.debug` | `hdc shell aa force-stop org.totschnig.myexpenses` |
| 截图 | `adb exec-out screencap -p > shot.png` | `hdc shell snapshot_display -f /data/local/tmp/s.png && hdc file recv /data/local/tmp/s.png shot.png` |
| UI dump | `adb shell uiautomator dump /sdcard/ui.xml && adb pull` | `hdc shell uitest dumpLayout -p /data/local/tmp/ui.json && hdc file recv` |
| 点击/输入 | `adb shell input tap X Y` / `adb shell input text` | `hdc shell uitest uiInput click X Y`（文本输入见注 1） |
| 滑动 | `adb shell input swipe X1 Y1 X2 Y2 D` | `hdc shell uitest uiInput swipe X1 Y1 X2 Y2` |
| 深色切换 | 模拟器系统设置切换 | 见注 2（应用内主题设置） |
| 数据库校验 | `adb exec-out run-as org.totschnig.myexpenses.debug cat databases/myexpenses.db > db.sqlite` | 见注 3（hdc 拉取应用沙箱数据库） |

> **注 1**：HarmonyOS 模拟器 `uitest uiInput inputText` 在部分版本不可用；输入框文本建议通过 `uitest uiInput click` 聚焦后模拟逐字符输入，或记录为"输入受限"项。
> **注 2**：深色切换以**应用内设置 → 界面 → 主题**为准（function-tests 曾记录"模拟器无命令行切深色"，但应用内主题设置可切换，需实测确认）。
> **注 3**：HarmonyOS 应用数据沙箱路径需确认（`/data/app/el2/100/base/org.totschnig.myexpenses/haps/...`），测试前先执行一次 `hdc shell find /data/app -name '*.db' 2>/dev/null` 定位 myexpenses.db 实际路径并记录。

### 2.2 证据存放约定

- GUI 对比图：`migration/evidence/gui/round3/`（Android 原图 / ArkUI 实际图 / overlay / diff）
- UI dump：`migration/evidence/dump/round3/`
- 数据库快照：`migration/evidence/db/round3/`
- 运行日志（含命令、时间戳、退出码）：`migration/evidence/logs/round3/`

---

## 3. 测试矩阵（核心）

> 编号规则：FT-功能 / GUI-界面一致性 / TH-主题 / LC-生命周期 / DP-数据持久化。
> P0=验收门禁相关，优先执行；P1=重要功能/维度；P2=增强与边缘。
> "验证方式"：`自动化`=uitest/adb 脚本可重复执行；`手动`=需人工点击与目检；`混合`=自动化触发+人工确认。

### 3.1 P0（验收门禁，15 项）

| 编号 | 测试项 | 页面/入口 | 操作步骤 | 预期结果 | 证据要求 | 验证方式 |
|---|---|---|---|---|---|---|
| LC-01 | 安装与启动 | 整机 | ①hdc install -r HAP ②hdc shell aa start ③观察 10s | 安装成功、启动进入主界面、无崩溃无黑屏 | 安装日志 + 启动截图 + hdc pidof 日志 | 自动化 |
| LC-02 | 前后台切换（background_foreground） | 主界面 | ①启动应用 ②按 Home ③等 5s ④切回 | 回到原页面，账户/交易列表状态保持，无重建闪烁 | 切换前后截图对比 + 运行日志 | 混合 |
| LC-03 | 进程常驻稳定 | 整机 | ①启动 ②等 60s ③重复前后台 3 次 ④检查 pid | PID 稳定、无崩溃（对照 D-002 已 PASS 基线） | hdc shell ps 日志（时间戳）+ 运行日志 | 自动化 |
| LC-04 | 二次冷启动 | 整机 | ①force-stop ②重新 aa start | 正常进入，之前数据仍在 | 启动日志 + 主界面截图 | 自动化 |
| DP-01 | 记账保存→重启数据保留 | ExpenseEdit | ①FAB→支出→输入 66→保存 ②force-stop ③重启 | 重启后交易页仍显示该支出，余额正确 | 前后 DB 快照 + 重启后截图 | 混合 |
| DP-02 | 新建账户→重启数据保留 | AccountEdit | ①账户Tab→选项菜单→新建账户→填名保存 ②force-stop ③重启 | 重启后账户列表含新账户 | DB accounts 计数前后对比 + 截图 | 混合 |
| FT-10 | 记账保存→余额更新（回归） | ExpenseEdit | ①交易Tab→FAB→支出→金额 50→保存 | 交易出现、余额减少，交易行显示日期/分类/金额 | DB transactions 新行 + 交易页截图 | 自动化 |
| FT-11 | 新建账户（回归） | AccountEdit | ①账户Tab→FAB/选项→新建→输入名称→保存 | 账户列表新增账户 | DB accounts + UI dump | 自动化 |
| FT-12 | 转账完整 UI 流程（此前未覆盖） | ExpenseEdit | ①FAB→转账 ②选转出账户 ③选转入账户 ④输金额 ⑤保存 | 保存成功，双方余额正确变动，DB 生成双边记录 | UI dump（确认 Select 可选目标）+ DB 校验 + 截图 | 混合 |
| FT-13 | 拆分交易（回归） | ExpenseEdit | ①FAB→支出→拆分Tab→添加拆分项→分配金额→保存 | 拆分款项显示、子项保存正确 | UI dump + DB 校验 + 截图 | 混合 |
| FT-14 | 模板/周期计划（回归） | 模板Tab | ①模板Tab→新建→设每月周期→生成 | 模板带周期标签，可实例化交易 | DB recurrence 校验 + UI dump | 混合 |
| GUI-01 | 账户页浅色像素对比（回归） | 账户Tab | ①两端切浅色+中文 ②同状态截图 ③比对 | 内容区像素差异 <5%（参照 G-002 基线） | Android 原图 / ArkUI 图 / overlay / diff | 混合 |
| GUI-02 | 账户页深色像素对比 | 账户Tab | ①两端切深色 ②同状态截图 ③比对 | 深色下差异 <5%（参照 G-011 基线） | 同上（深色组） | 混合 |
| GUI-03 | 交易页浅色像素对比 | 交易Tab | ①两端浅色 ②有账户+交易状态截图 ③比对 | 差异 <5%（参照 G-006 基线） | 同上 | 混合 |
| GUI-04 | 记账编辑页浅色像素对比 | ExpenseEdit | ①两端浅色 ②编辑页同字段状态截图 ③比对 | 差异 <5%（参照 G-009 基线） | 同上 | 混合 |

### 3.2 P1（重要功能/维度，21 项）

| 编号 | 测试项 | 页面/入口 | 操作步骤 | 预期结果 | 证据要求 | 验证方式 |
|---|---|---|---|---|---|---|
| FT-15 | AI 助手分析（回归） | 更多→AI 助手（Index 338 行入口） | ①进入 AI 助手 ②查看收支概览/趋势/建议 | 展示支出/结余/趋势/建议 | AI 页 UI dump + 截图 | 混合 |
| FT-16 | 分类管理（回归） | 分类管理入口（按实际 UI dump 定位） | ①进入分类列表 ②查看 10 个分类 ③可新增/编辑 | 10 分类显示，增删改生效 | DB categories 校验 + UI dump | 混合 |
| FT-17 | 标签管理（回归） | 标签管理入口（AccountEdit 543 行 TagManage 入口） | ①进入标签页 ②新建"工作" ③列表出现 | 标签 CRUD 生效 | DB tags/accounts_tags + UI dump | 混合 |
| FT-18 | 支付方式管理（回归） | 支付方式入口 | ①进入付款方法列表 ②核对 6 方法 | 列表正确 | UI dump + DB 校验 | 混合 |
| FT-19 | 搜索功能 | 交易页右上角搜索图标 | ①输入金额/关键词/日期条件 ②执行搜索 | 搜索结果列表与数量正确 | UI dump + DB 查询对比 | 混合 |
| FT-20 | 预算管理 | 更多→预算编制（Index 668 行） | ①进入预算页 ②新建/查看预算 | 预算显示与 CRUD 生效 | UI dump + DB budgets 校验 | 混合 |
| FT-21 | 债务管理 | 更多→交易对手/债务（Index 672 行） | ①进入债务页 ②查看/新建债务 | 债务列表与 CRUD 生效 | UI dump + DB 校验 | 混合 |
| FT-22 | 资产负债表 | 账户页标题切换（Index 693 行账户/资产负债表） | ①切到资产负债表 ②核对资产/负债分类汇总 ③切日期 | 汇总正确、日期可选、打印/导出入口存在 | UI dump + 截图 | 混合 |
| FT-23 | 设置导航与页面 | 更多→设置（SettingsMain） | ①进入设置 ②逐一进入数据/界面/导入导出/备份恢复 ③记录"开发中"占位 | 页面可达；占位页如实记录"开发中" | 各页 UI dump + 截图 | 混合 |
| FT-24 | 账户展开操作 | 账户Tab→点击账户卡片展开 | ①展开账户 ②核对操作项（编辑/删除/关闭/计入总数） ③执行删除一个测试账户 | 操作项齐全（BUG-002 已修复），删除后列表更新 | UI dump + DB accounts 校验 | 混合 |
| FT-25 | 多选删除 | 交易Tab→长按交易行 | ①长按进入多选 ②全选 ③删除 | 多选工具栏显示数量，删除生效，余额回滚 | UI dump + DB transactions 校验 | 混合 |
| FT-26 | 点击交易编辑 | 交易Tab→点击交易行 | ①点某条交易 ②进入编辑页 ③改金额 ④保存 | 编辑生效，列表与余额刷新 | UI dump + DB 校验 | 自动化 |
| FT-27 | 汇总卡片显示 | 交易Tab | ①有收入/支出数据时查看汇总区 | 显示收入/支出/转账三类（记录是否缺"总计"，对齐 BUG/差异项） | 截图 + UI dump | 手动 |
| TH-01 | 深/浅主题切换 | 设置→界面→主题 | ①切深色 ②回主界面/交易/编辑各页查看 ③切回浅色 | 各页面颜色正确响应，无黑屏区域（复验差异报告 8.x） | 每页深浅两套截图 | 混合 |
| TH-02 | 深色下金额颜色 | 交易Tab（深色） | ①深色下查看收入/支出金额 | 收入绿/支出红在深色下对比度正确 | 截图 | 手动 |
| GUI-05 | 账户编辑页浅色像素对比 | AccountEdit | ①两端浅色 ②账户编辑页同字段截图 ③比对 | 差异 <5%（参照 G-010 基线） | 三件套对比图 | 混合 |
| GUI-06 | 账户编辑页深色像素对比 | AccountEdit | ①两端深色 ②截图 ③比对 | 差异 <5%（参照 G-012 基线） | 同上 | 混合 |
| GUI-07 | 记账编辑页深色像素对比 | ExpenseEdit | ①两端深色 ②截图 ③比对 | 差异 <5%（参照 G-013 基线） | 同上 | 混合 |
| GUI-08 | AI 助手浅色像素对比 | AiAssistant | ①两端浅色 ②同数据状态截图 ③比对 | 内容区一致（验收范围含 AiAssistant） | 三件套对比图 | 混合 |
| GUI-09 | AI 助手深色像素对比 | AiAssistant | ①两端深色 ②截图 ③比对 | 内容区一致 | 同上 | 混合 |
| GUI-10 | 黑屏问题复验 | 交易/编辑各页 | ①浅色+深色下逐页目检 ②确认无黑色异常区域 | 无黑屏（复验差异报告 8.x 结论） | 各页深浅截图 | 手动 |

### 3.3 P2（增强/边缘，11 项）

| 编号 | 测试项 | 页面/入口 | 操作步骤 | 预期结果 | 证据要求 | 验证方式 |
|---|---|---|---|---|---|---|
| DP-03 | 删除交易→重启后删除生效 | 交易Tab | ①删除一条交易 ②force-stop ③重启 | 删除持久化，余额正确 | DB 前后对比 | 混合 |
| DP-04 | 模板周期持久化 | 模板Tab | ①改周期 ②重启 ③查看 | 周期设置保留（复验 BUG-C） | DB recurrence + UI dump | 混合 |
| DP-05 | 设置项持久化 | 设置→界面 | ①改主题/分组方式 ②重启 ③查看 | 设置保留 | Preferences 校验 + UI dump | 混合 |
| DP-06 | 数据库完整性 | DbHelper 初始化 | ①导出 DB ②核对 schema/种子数据（account_types=5/categories=10） | 结构与种子数据正确（复验 D-001） | DB dump | 自动化 |
| FT-28 | 导出 CSV/QIF | 设置→导入导出 | ①执行导出 ②检查导出结果/提示 | 导出入口可用，产物存在或如实记录限制 | 日志 + UI dump | 手动 |
| FT-29 | 分布图入口验证 | Index 348 行 navigateToDistribution | ①进入分布图（若入口可达） ②查看 | 记录入口可达性与页面状态（报告标缺失，代码存在，需澄清） | UI dump + 截图 | 手动 |
| FT-30 | 历史记录入口验证 | Index 353 行 navigateToHistory | ①进入历史记录 ②查看 | 同上，记录真实状态 | UI dump + 截图 | 手动 |
| FT-31 | FAB 菜单项核对 | 交易Tab→FAB | ①长按 FAB ②核对支出/收入/转账/拆分/扫描 | 菜单结构与 Android 一致，扫描项提示"开发中"（差异 3.5） | UI dump + 截图 | 手动 |
| FT-32 | 编辑页字段顺序核对 | ExpenseEdit | ①进入编辑 ②核对字段顺序 | 收款人→类别→标签→付款方法→备注（复验 BUG-008） | UI dump + 截图 | 手动 |
| FT-33 | 搜索详情（收款人/附件）差异 | 搜索页 | ①打开搜索条件 ②核对条件项 | 记录收款人/附件条件是否缺失（差异 6.1） | UI dump + 截图 | 手动 |
| GUI-11 | 更多菜单与 Android NavigationView 对比 | 更多按钮 dialog（Index 2578 行） | ①两端弹更多菜单 ②逐项对比 | 记录菜单项差异（预算编制/债务/设置 vs Android 14 项） | 两端截图 + 清单表 | 手动 |

> 说明：P2 中"报告标缺失但代码存在入口"的项（分布图/历史记录等），结论可能为"报告过时/已实现"，以实测为准并回写差异项清单（第 4 节）。

---

## 4. UI 一致性差异项清单

> 来源：`UI功能差异报告.md`（2026-08-14）。状态标注：**已实现**（含证据）/ **待验证**（本轮复验）/ **已知缺失**（确认缺失）/ **不在本期范围**。
> 注意：报告中部分"缺失"项（分布图/历史记录/设置多入口）在 arkts_new 代码中已存在对应页面，需以模拟器实测为准，故标"待验证"。

### 4.1 架构级差异

| # | 差异项 | 报告结论 | 状态 | 验证方法（待验证项） |
|---|---|---|---|---|
| A-1 | 导航模式：侧边栏 → 底部 TabBar | 架构改变 | 已实现（设计决策，非缺陷） | —（GUI-12 记录差异） |
| A-2 | 分栏布局：平板左右分栏 → 单页 | 架构改变 | 不在本期范围（targets 手机单栏） | — |
| A-3 | 账户切换：滑动 Pager → 下拉选择器 | 交互不同 | 待验证 | 交易Tab顶部，点击下拉选择器切换账户，对比 Android 滑动 |

### 4.2 功能级差异

| # | 差异项 | 报告结论 | 状态 | 验证方法（待验证项） |
|---|---|---|---|---|
| F-1 | 云同步（WebDAV/Drive/Dropbox/FinTS） | 完全缺失 | 不在本期范围（scope.md 明确排除） | — |
| F-2 | 备份/恢复 | 完全缺失 | 已知缺失（SettingsBackup 为"开发中"占位） | 设置→备份与恢复 截图记录 |
| F-3 | 重复计划 | 完全缺失 | 待验证（模板 Tab 已有周期，需确认"计划"实例化流程） | FT-14 |
| F-4 | 附件（图片/PDF） | 完全缺失 | 已知缺失（SettingsAttachPicture 为占位） | 编辑页验证附件入口/提示 |
| F-5 | 位置记录 GPS | 完全缺失 | 不在本期范围（分阶段项） | — |
| F-6 | OCR 扫描 | 显示"开发中" | 待验证（设置与 FAB 均有 OCR 占位） | FAB 扫描项 + 设置→扫描收据 实测记录 |
| F-7 | 分布图 | 完全缺失 | 待验证（代码含 Distribution.ets 与入口） | FT-29 |
| F-8 | 历史记录 | 完全缺失 | 待验证（代码含 History.ets 与入口） | FT-30 |
| F-9 | 批量操作（编辑/标签/拆分/链接/重映射） | 仅删除 | 待验证（确认多选模式下是否仅全选+删除） | FT-25 |
| F-10 | 模板管理 | 功能简化 | 待验证 | FT-14 |
| F-11 | 导入（CSV/QIF） | 完全缺失 | 已知缺失（导入导出页实测确认） | FT-28 |

### 4.3 UI 级差异

| # | 差异项 | 报告结论 | 状态 | 验证方法（待验证项） |
|---|---|---|---|---|
| U-1 | 账户页标题不可点击切换视图 | ❌ | 已修复（BUG-004 账户标题加箭头，VERIFIED） | GUI 对比确认 |
| U-2 | 汇总卡片缺"总计" | ⚠️ | 待验证 | FT-27 |
| U-3 | 账户操作缺导出/共享/平衡 | 缺失 | 待验证（BUG-002 已补删除/Flag，其余确认） | FT-24 |
| U-4 | FAB 缺"新建资产组合" | 缺失 | 待验证 | FT-31 |
| U-5 | 黑屏问题 | 部分区域黑 | 待验证（重点复验） | GUI-10 |
| U-6 | 编辑页附件/位置/重复计划缺失 | 缺失 | 已知缺失 / 不在本期范围 | 编辑页截图记录 |
| U-7 | 转账汇率转换缺失 | 缺失 | 待验证 | FT-12 中观察是否有汇率输入 |
| U-8 | 交易行缺查看入口 | 缺失 | 已修复（BUG-009 加查看箭头，VERIFIED） | GUI 对比确认 |

### 4.4 细节差异

| # | 差异项 | 状态 | 验证方法 |
|---|---|---|---|
| D-1 | 动画流畅度（Tab 切换/展开） | 待验证 | 手动操作目检，记录卡顿项 |
| D-2 | Toast/状态反馈缺失 | 待验证 | 各操作（保存/删除）后观察提示 |
| D-3 | 错误处理（转账校验等） | 已修复部分（BUG-3 校验） | 回归验证 |
| D-4 | 辅助功能（屏幕阅读器） | 不在本期范围 | — |

### 4.5 已知一致项（不重复验证，引用既有证据）

- 账户卡片/色条/展开折叠、分组显示、聚合账户（GUI-02 PASS）
- 交易卡片/金额颜色/分组/点击编辑/状态图标（GUI-01/03 PASS）
- 分类/标签/支付方式管理基础 CRUD（FT-06/07/08 PASS）
- 设置基础项（FT-10 PASS）

---

## 5. 已知限制与未覆盖项（对照 function-tests.md）

| 已知限制 | 模拟器能否覆盖 | 计划对应项 / 说明 |
|---|---|---|
| 转账"选目标账户"完整 UI 流程无法自动化 | ✅ 可覆盖 | FT-12 手动点击 Select 完成全流程（仍记录"uitest 无法触发 Select"为工具限制，但人工可完成） |
| 深色主题 GUI 截图需 DevEco/真机切换 | ⚠️ 部分可覆盖 | 若应用内"设置→界面→主题"可切换则模拟器可完成 TH-01/GUI 深色组；若仅系统级则标注"模拟器无法验证，需真机" |
| 真机矩阵（install_launch/background_foreground 真机证据） | ❌ 无法覆盖 | 模拟器证据可做前置验证，但 G-004 需真机（PHYSICAL_DEVICE）才能 VERIFIED |
| 签名 Release HAP + SHA-256 | ❌ 无法覆盖 | G-005 需配置签名后构建，模拟器安装 unsigned 仅能验证功能 |
| 横屏（LANDSCAPE） | 范围豁免 | sources.json landscapeWaived=true，不测（模拟器支持但本期豁免） |

---

## 6. 执行顺序建议

> 每批独立可验收，批内按 P0→P1→P2 顺序。每批结束即产出证据目录，回写 test-summary.json 与 problem-ledger.csv。

### 批次 1：环境就绪与核心回归（P0 骨架）
- LC-01 安装启动 → LC-03 进程稳定 → LC-04 二次冷启动
- FT-10 记账回归 → FT-11 新建账户回归 → FT-13 拆分回归 → FT-14 模板回归
- **通过标准**：LC/FT 全部 PASS；无崩溃、无黑屏；DB 校验一致。

### 批次 2：生命周期 + 数据持久化（P0）
- LC-02 前后台切换 → DP-01 记账持久化 → DP-02 账户持久化 → DP-06 数据库完整性
- **通过标准**：前后台状态保持；重启后数据/设置保留；DB schema 与种子数据正确。

### 批次 3：GUI 像素回归（P0/P1 浅色组）
- GUI-01 账户浅色 → GUI-03 交易浅色 → GUI-04 编辑浅色 → GUI-05 账户编辑浅色 → GUI-08 AI 浅色
- **通过标准**：各页面内容区像素差异 <5%（--strict-pixels 时 <1% 另行评估），overlay/diff 图齐备。

### 批次 4：主题维度（P0/P1 深色组 + TH）
- TH-01 深浅切换 → TH-02 深色金额色 → GUI-02 账户深色 → GUI-06/07 编辑深色 → GUI-09 AI 深色 → GUI-10 黑屏复验
- **通过标准**：深浅切换各页颜色正确、无黑屏；深色像素对比 <5%。

### 批次 5：未覆盖功能补测（P1）
- FT-12 转账全流程 → FT-15 AI → FT-19 搜索 → FT-24 账户展开 → FT-25 多选删除 → FT-20/21 预算债务 → FT-22 资产负债表 → FT-23 设置导航
- **通过标准**：全部 PASS 或如实记录限制项；转账完整流程成功保存双边记录。

### 批次 6：差异项复验 + 增强（P1/P2）
- FT-26 点击编辑 → FT-27 汇总卡片 → FT-28 导出 → FT-29/30 分布图历史 → FT-31 FAB → FT-32 字段顺序 → FT-33 搜索条件 → GUI-11 更多菜单 → DP-03/04/05 持久化
- **通过标准**：差异项清单 4.2/4.3 全部更新为最终状态；新增 OPEN 项进 problem-ledger。

### 批次 7：收尾（产出）
- 汇总证据 → 更新 test-summary.json → 更新 function-tests.md（追加第 3 轮）→ 输出 migration-report 增量 → 明确"无法在模拟器验证"清单
- **通过标准**：全部测试项有结论（PASS/FAIL/受限）；待真机/签名项已列清单。

---

## 7. 风险与阻断项

| # | 风险/阻断项 | 影响 | 处置 |
|---|---|---|---|
| R-1 | **ArkUI Select 下拉无法 uitest 自动化** | FT-12 转账目标选择需人工点击，自动化脚本会失败 | 转账流程用手动+UI dump 完成；工具限制如实记录 |
| R-2 | **深色切换手段不确定** | 若模拟器无法切深色，TH-01 与全部 DARK GUI 项被阻断 | 先验证"设置→界面→主题"；失败则标注"模拟器无法验证，需真机"并跳过深色组 |
| R-3 | **输入框文本注入受限** | uitest inputText 在部分版本不可用，金额/名称输入慢 | 优先用预置种子数据 + 尽量少的字符输入；必要时逐字符注入 |
| R-4 | **差异报告与当前代码不一致** | 报告标"缺失"但代码已存在（分布图/历史/设置入口），结论可能误导 | 差异项一律实测后更新状态，不采信静态结论 |
| R-5 | **黑屏问题（差异报告 8.x）** | 若复现将影响 P0 GUI 判定 | GUI-10 专项复验；复现则开 P0/P1 问题单进 problem-ledger |
| R-6 | **数据库沙箱路径未定位** | DP 系列依赖拉库校验 | 测试前先 `hdc shell find` 定位路径并固化到测试脚本 |
| R-7 | **模拟器分辨率/字号差异** | 两端设备规格不同导致像素差异率虚高 | 对比时按内容区而非整屏；记录设备规格到 gui-matrix |

### 无法在模拟器上验证的项（必须真机/签名）

| 项 | 原因 |
|---|---|
| 真机矩阵 install_launch / background_foreground（G-004） | 验收要求 environment=PHYSICAL_DEVICE |
| 签名 Release HAP 与 SHA-256（G-005） | 需配置签名证书后构建，模拟器只能装 unsigned |
| 辅助功能（屏幕阅读器）实机体验 | 需真机辅助服务验证 |
| 系统级深色切换（若应用内无主题开关） | 模拟器无命令行切深色 |
| 横屏 LANDSCAPE（landscapeWaived=true） | 本期豁免 |
| OCR / 附件 / 位置 / 云同步真实能力 | 分阶段项，本期仅验证入口与提示状态 |

---

## 8. 附录：环境核验清单（开始前执行一次）

1. `adb devices` → emulator-5554 在线；`hdc list targets` → 127.0.0.1:5557 在线。
2. 记录两端应用版本：`adb shell dumpsys package org.totschnig.myexpenses.debug | grep versionName` 与 `hdc shell bm dump -n org.totschnig.myexpenses`。
3. 定位 HarmonyOS 数据库路径：`hdc shell find /data/app -name '*.db' 2>/dev/null`。
4. 验证深色切换手段：进入 设置→界面→主题 尝试切换，记录结论。
5. 建立批次输出目录 `migration/evidence/{gui,dump,db,logs}/round3/`。