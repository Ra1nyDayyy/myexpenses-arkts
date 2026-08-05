# 功能测试文档

## 测试环境
- Android 基准：Android 模拟器 Pixel_10（Android 17, 1080x2424）
- HarmonyOS 验证：HarmonyOS 模拟器 emulator 6.1.0.125（1320x2856）
- HAP：entry-default-unsigned.hap（debug 未签名）
- 测试方式：uitest UI 自动化 + 数据库校验 + GUI 像素比对
- 时间：2026-08-05

## 测试用例与结果

### UI 差异对比（Android vs ArkUI）

| 编号 | 页面 | Android 截图 | ArkUI 截图 | 像素差异率 | 差异来源 | 结论 |
|---|---|---|---|---|---|---|
| GUI-01 | 交易页（有账户空态） | TX_TAB_android.png | TX_TAB_arkui.png | 3.01% | 状态栏/底部导航/语言本地化 | PASS（内容区一致） |
| GUI-02 | 账户页 | ACCOUNTS_TAB_android.png | ACCOUNTS_TAB_arkui.png | 2.25% | 顶部结构/系统托管 | PASS（内容区一致） |
| GUI-03 | 记账编辑页 | EXPENSE_EDIT2_android.png | EXPENSE_EDIT2_arkui.png | 3.14% | 表单字段组合差异/系统托管 | PASS（核心字段一致） |

> 说明：像素差异主要来自系统托管区域（状态栏/Android 三键导航条）与语言本地化（Android 英文 vs ArkUI 中文，用户要求仅中文）。应用内容区布局一致。

### 功能测试（HarmonyOS 模拟器实测）

| 编号 | 功能 | 操作步骤 | 预期 | 实际 | 证据 | 结论 |
|---|---|---|---|---|---|---|
| FT-01 | 记账保存→余额更新 | 编辑页输金额 88→保存 | 交易出现、余额 -88 | 交易页显示"未分类 现金 ¥-88.00 8月5日"，余额 ¥-88.00 | 数据库 id=1 amount=-8800 | **PASS** |
| FT-02 | 新建账户 | 账户页+→输"现金"→保存 | 账户列表出现现金 | 账户页显示 Budget Book/-88 + 现金/0.00 | 数据库 accounts 2 条 | **PASS** |
| FT-03 | 转账校验 | 转账模式未选目标→保存 | 阻止保存并提示 | 保存被拦截，数据库无误存交易 | 数据库仅 1 条交易 | **PASS** |
| FT-04 | AI 助手分析 | 更多→AI 助手 | 收支概览+建议 | 支出 -88、结余 -88、8月趋势、AI 建议"未分类 88.00" | AI 助手页 | **PASS** |
| FT-05 | 新建交易默认账户 | 进入编辑页 | 默认选中当前账户 | 账户显示"Budget Book"（修复后） | 编辑页 dump | **PASS** |

### 发现的 Bug（已修复）

| Bug | 现象 | 根因 | 修复 |
|---|---|---|---|
| BUG-1 | 编辑页账户显示"选择"，无法选中 | 数据数组非 @State，异步加载后 UI 不刷新 | 改为 @State |
| BUG-2 | 保存交易后余额仍为 0 | fillAccountSums 用 equalTo+isNull 矛盾条件（-1 存 NULL） | 只保留 isNull |
| BUG-3 | 转账未选目标可保存 0 元交易 | 转账校验缺失 | save 增加校验 |

### 已知限制
- ArkUI Select 下拉菜单无法通过 uitest 触发，转账"选目标账户"完整流程无法 UI 自动化（逻辑已代码走查+校验验证）
- 深色主题 GUI 截图需 DevEco/真机切换（模拟器无命令行切深色）
- 真机矩阵、签名 HAP 待用户配合

## 汇总
- UI 对比：3 项 PASS（内容区一致，差异为系统托管+语言）
- 功能：5 项 PASS，0 FAIL
- Bug：3 个已修复并验证
- 未覆盖：转账完整 UI 流程（工具限制）、深色截图、真机、签名
