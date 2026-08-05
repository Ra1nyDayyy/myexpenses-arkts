# GUI 差异文档

## 对比环境
- Android 基准：Pixel_10 模拟器（1080x2424, Android 17, 英文界面）
- ArkUI 实际：HarmonyOS 模拟器 emulator 6.1.0.125（1320x2856）
- 语言：Android 应用内英文（系统 locale 无法强制切换），ArkUI 中文（用户要求仅中文）

## 1. 主界面空态（Main / empty）

| 项 | 值 |
|---|---|
| Android 截图 | MAIN_EMPTY_android.png |
| ArkUI 截图 | MAIN_EMPTY_arkui.png |
| 叠加图 | MAIN_EMPTY_overlay.png |
| 差异图 | MAIN_EMPTY_diff.png |
| 像素差异率 | 1.65% |
| pHash | 28（系统托管差异影响） |
| 差异来源 | 状态栏时间/电池、底部 Android 三键导航条、工具栏按钮样式 |
| 结论 | 应用内容区一致（背景 #FAF8FE 已对齐、空态文案按钮一致），系统托管差异已标注 |

## 2. 交易页空态（Main / account_list，有账户状态）

| 项 | 值 |
|---|---|
| Android 截图 | TX_EMPTY_V2_android.png |
| ArkUI 截图 | TX_EMPTY_V2_arkui.png |
| 叠加图 | TX_EMPTY_V2_overlay.png |
| 差异图 | TX_EMPTY_V2_diff.png |
| 像素差异率 | 2.67% |
| pHash | 29（系统托管差异影响） |
| 差异来源 | 状态栏、Android 三键导航条（98%）、语言本地化（英文 No Expenses Yet! vs 中文 未有开支!）、FAB 位置微差 |
| 结论 | 应用内容区一致（Budget Book 账户、4 Tab 底部导航、teal FAB 已对齐），系统托管与语言差异已标注 |

## 3. 修复过程
- 背景色对齐：Android Material3 surface #FAF8FE → ArkUI 全部页面根背景
- V2 结构对齐：抽屉式 → 底部 4 TabBar（账户/交易/模板/更多）
- FAB 对齐：新增 teal 色 FAB（支出/收入），位置迭代对齐 Android
- 详见 fix-log.md