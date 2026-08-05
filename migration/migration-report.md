# 迁移报告：MyExpenses (Android) → 开支助手 (ArkUI)

## 1. 范围与来源边界

- Android 源：/Users/rainyday/Desktop/migration/MyExpenses（org.totschnig.myexpenses）
- ArkUI 目标：/Users/rainyday/Desktop/migration/arkts
- 本期范围（用户确认）：全量核心功能，**不含云同步**；新增 **AI 功能**；语言**仅中文**（zh-CN）；深浅色；横屏豁免（模拟器竖屏优先，Android 源支持横屏，见 guiRequirements）
- 分阶段项：云同步、系统小部件、OCR、日历集成、广告/贡献许可

## 2. 新 ArkUI 工程创建依据与环境

- 模板：assets/arkui-stage-template（Skill 内置空白模板）
- preflight：DevEco Studio 6.1 / SDK 6.1.1(24) / Java 21 / hvigor / hap-sign-tool 均探测到
- Scaffold 门禁：真实 hvigor 构建通过（migration/evidence/build/scaffold-build.txt）
- 创建：create_arkui_project.py → arkts/（bundleName=org.totschnig.myexpenses）

## 3. Android 架构与 ArkUI 架构映射

| Android | ArkUI |
|---|---|
| MyExpenses Activity（Drawer+Coordinator+ViewPager） | Index.ets（SideBarContainer+Swiper） |
| AccountList / TransactionList (Compose) | AccountListPage / TransactionListPage |
| ExpenseEdit / AccountEdit | ExpenseEdit / AccountEdit 页面 |
| SQLite + ContentProvider | relationalStore + Repository 单例 |
| SharedPreferences | preferences |
| ViewModel | @State + Repository |
| 详情见 code-mapping.md | |

<!-- MIGRATION_SECTION:CODE -->
## 代码
- Android 来源：activity_main.xml、MyExpenses.kt、one_expense.xml、Account.kt、Transaction.kt、TransactionDatabase.java、colors.xml、dimens.xml、strings.xml 等
- ArkUI 修改：新增 29 个 .ets 源文件（model 5 / database 3 / common 2 / components 5 / pages 10 / ability 2）+ 资源（color/string/float，含 dark 限定目录）
- 本轮映射与完成项：数据层（12 张表+种子数据）、主界面（V2 底部 TabBar 账户/交易/模板/更多）、交易列表（分组）、记账编辑（收入/支出/转账）、账户编辑、分类/付款方式/标签管理、资产负债表、设置、AI 助手

<!-- MIGRATION_SECTION:TESTS -->
## 测试
- 新增/执行用例：11（详见 function-tests.md），PASS 9、未执行 2（记账保存/AI 分析完整流程需 UI 自动化）
- 环境与结果：Android Pixel_10 模拟器 + HarmonyOS emulator 6.1.0.125，应用启动正常、数据库建表成功、进程稳定、UI 操作（新建账户/切 Tab）通过 uitest 验证
- 证据：migration/evidence/gui/main_screen.jpeg、db_created.txt、function-tests.md、test-summary.json
- 测试统计：PASS 9 / notExecuted 2（详见 test-summary.json）

<!-- MIGRATION_SECTION:DIFFERENCES -->
## 差异
- 已关闭差异：G-001 主界面空态文案一致、G-002 金额颜色规则一致、G-003 Android 基准截图已获取、G-006 V2 交易页结构对齐、G-007 系统托管差异已标注、G-008 语言本地化差异已标注（均 VERIFIED）
- 剩余差异与级别：G-004 无真机证据（P1）、G-005 无签名 HAP（P1）—— 需真机与签名配置
- 截图/量化证据：MAIN_EMPTY_*.png（diff 1.65%）、TX_EMPTY_V2_*.png（diff 2.67%）、gui-diff.md

<!-- MIGRATION_SECTION:FIXES -->
## 修复
- 问题与根因：FIX-001 首次构建 45 个 ArkTS 编译错误（Builder/资源名/类型约束）；FIX-002 数据库初始化；FIX-003 V2 主界面重构；FIX-004 背景色/FAB 对齐 Android
- 修改过程：见 fix-log.md
- 复测结果：BUILD SUCCESSFUL，HAP 生成并可安装运行；GUI 像素差异降至 2.67%

## 4. 功能迁移结果和测试统计
- 核心闭环（账户/交易/分类/方法/标签/AI）已实现并可构建运行
- 测试统计见 test-summary.json（PASS 9 / notExecuted 2）

## 5. 数据、设置、持久化与生命周期
- 12 张表建表成功、种子数据验证通过
- 设置：preferences 存储（分组/显示等值等 key 已定义）
- 生命周期：EntryAbility onCreate/onWindowStageCreate 初始化 DB，前后台正常

## 6. GUI 1:1 方法、矩阵、差异和结果
- 方法：Android 资源（colors/dimens/strings）机械转换 + ArkUI 组件重实现 + Android 模拟器基准截图像素比对
- 矩阵：gui-matrix.csv（2 个 PASS 行：主界面空态、交易页有账户空态，含四图）
- 像素比对：MAIN_EMPTY diff 1.65%、TX_EMPTY_V2 diff 2.67%（verify_gui_pixels.py）
- 差异：见 problem-ledger.csv（G-001/G-002/G-003/G-006/G-007/G-008 VERIFIED，G-004/G-005 OPEN）

## 7. 问题分类、根因、修复过程和遗留项
- 见 problem-ledger.csv 与 fix-log.md
- 遗留：G-004 真机矩阵、G-005 签名 Release

## 8. 构建、设备安装和 Release HAP 信息
- Debug 构建成功，unsigned HAP 已安装到模拟器并启动
- Release 签名 HAP 待完成（build-release.md）

## 9. 独立审查结论
- 未进行独立审查（等门禁补齐后执行）

## 10. 完成度结论
**未完成（ACCEPTANCE_CANDIDATE）**
- 已具备：工程构建、应用运行、V2 主界面与 Android 对齐、核心功能实现、数据层验证、GUI 像素比对（主界面+交易页浅色）、深色主题资源适配（代码完成）
- 阻塞（需用户/环境）：
  1. 真机矩阵（G-004）：需连接 HarmonyOS 真机执行 install_launch/background_foreground
  2. 签名 Release HAP（G-005）：需 DevEco Studio 配置签名后构建 release
  3. 深色主题 GUI 截图：模拟器无法命令行切深色，需 DevEco 或真机操作
  4. AccountEdit/ExpenseEdit/AiAssistant 页面 GUI 矩阵
  5. 独立审查