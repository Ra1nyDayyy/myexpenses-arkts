# 修复日志

## FIX-001: ArkTS 编译错误修复（首次构建）

- 问题：45 个 ArkTS 编译错误
- 定位过程：
  - `@Builder` 中 `CustomBuilder` 参数使用方式错误（formRow 模式）→ 改为内联 Row 结构
  - 系统图标资源名不存在（ohos_ic_public_back/delete/menu/highlight）→ 查证 sysResource.js 后替换为 arrow_left/close/drawer_open/scan
  - `Select` options 需要 `SelectOption` 类型 → 增加辅助方法返回类型化数组
  - `Map` 索引访问（`data[k]`）、`Transaction['crStatus']` 索引类型访问 → 改为迭代/枚举
  - `as const` 不支持 → 改为 `static readonly` 类常量
  - 字符串索引 `hex[i]` → 改用 `charAt()`
  - `Stack`/`Flex`/`Row` 的属性支持差异（justifyContent/alignItems/minHeight/onLongPress）→ 按 ArkUI API 修正
  - 递归 ListItem 多子组件 → 改为 Scroll+Column 递归
- 修改文件：全部 .ets 源文件
- 复测：BUILD SUCCESSFUL，HAP 757KB 生成

## FIX-002: 数据库验证

- 问题：无（首次实现即成功）
- 验证：myexpenses.db 创建，种子数据 account_types=5、categories=10
- 证据：migration/evidence/gui/db_created.txt

## FIX-003: V2 主界面重构

- 问题：Android 默认启动 MyExpensesV2（底部 4 TabBar），ArkUI 最初实现 V1 抽屉式
- 处理：重构 Index.ets 为 V2 底部 TabBar（账户/交易/模板/更多）+ FAB + 更多菜单
- 复测：构建成功，uitest 验证 4 Tab 切换正常

## FIX-004: 背景色与 FAB 对齐 Android

- 问题：Android Material3 surface #FAF8FE vs ArkUI 纯白背景；Android teal FAB 缺失
- 处理：全部页面根背景改为 #FAF8FE；新增 teal (#009688) FAB（支出/收入），位置迭代对齐
- 复测：GUI 像素差异从 1.65%（主界面）降至 2.67%（交易页），差异主要来自系统托管区域与语言本地化

## FIX-005: 深色主题适配

- 问题：页面背景/文本硬编码浅色值，深色模式不生效
- 处理：资源文件增加 surfaceBackground/pageBackground/cardBackgroundColor/textPrimary/textSecondary/dividerColor/tabBarBackground（base 浅色 + dark 深色），页面背景/文本/分割线改为资源引用（`$r('app.color.xxx')`），自动跟随系统主题
- 验证：资源 key 已编译进 ResourceTable（pageBackground/surfaceBackground/tabBarBackground/textPrimary）
- 说明：HarmonyOS 模拟器无法通过命令行切换深色模式，深色 GUI 截图需 DevEco Studio 或真机操作

## FIX-006: 迁移证据文件补齐

- 问题：source-provenance.csv 路径错误、problem-ledger.csv 含裸逗号导致解析错位、migration-report.md 缺 MIGRATION_SECTION 标记
- 处理：修正 android_source 路径（myExpenses/ 前缀）、移除字段内裸逗号、补充四个机器可读标记
- 复测：Complete 门禁错误大幅减少，仅剩真机/签名/深色截图等环境性阻塞

## FIX-007: UI 原生鸿蒙化（用户策略：以安卓为基础，优先鸿蒙原生）

- 策略：信息架构/布局以 Android 为基准，组件呈现优先鸿蒙原生，无原生组件才模仿 Android
- 处理：
  1. 底部导航：手写 Row 模拟 TabBar → 原生 `Tabs`（选中态动画、图标文字、深浅色适配）
  2. FAB：Android 风格 teal 横条 → 鸿蒙圆形 FAB + 长按原生 ActionSheet（支出/收入/转账）
  3. 管理页弹窗：`.position` 模拟对话框 → 原生 `CustomDialogController`（CategoryManage/MethodManage/TagManage）
  4. 更多页/设置页：手写 Row+border 列表 → 原生 `List` + `ListItem` + `divider`
  5. 颜色：全工程硬编码色 → 资源引用（primaryColor/pageBackground/cardBackgroundColor/textPrimary/textSecondary/dividerColor，base+dark）
- 复测：BUILD SUCCESSFUL，模拟器验证原生 TabBar/圆形 FAB/原生对话框/原生 List 均正常

## FIX-008: 功能测试发现的 Bug 修复（双模拟器实测）

- FIX-008a: ExpenseEdit 账户/分类/方法等数据数组非 @State，异步加载后 UI 不刷新，账户显示"选择"
  - 处理：`accounts/categories/methods/payees/tags` 改为 `@State`
  - 复测：账户默认选中 "Budget Book" 生效
- FIX-008b: Repository.fillAccountSums 用 `equalTo('parent_id', -1)` + `isNull('parent_id')` 矛盾条件（-1 存成 NULL），余额计算漏掉所有交易
  - 处理：只保留 `isNull('parent_id')`
  - 复测：保存 -88 支出后，余额正确显示 ¥-88.00（账户页+交易页）
- FIX-008c: 转账模式未选目标账户时，保存走了普通交易分支，误存 0 元交易
  - 处理：save 增加转账校验（未选目标提示"请选择目标账户"）+ 金额非零校验
  - 复测：未选目标保存被拦截，数据库无误存交易

## FIX-009: 编辑页组件原生鸿蒙化（第二轮）

- 处理：
  1. 记账编辑页类型切换：手写 Row+按钮 → 原生 `Tabs` 分段控件（选中态蓝色下划线、切换动画）
  2. 记账编辑页日期字段：纯文本显示 → 原生 `DatePickerDialog`（点击弹出年/月/日滚轮选择器，取消/确定按钮）
  3. 修复：Tabs 嵌入 Scroll 后占满高度挤掉表单 → Tabs 设固定高度 44，TabContent 内容高 0
- 复测：BUILD SUCCESSFUL，模拟器验证类型切换分段控件、原生日期选择器均正常，表单字段完整显示

## FIX-010: 列表与交互原生鸿蒙化（第三轮）

- 处理：
  1. 交易列表分组：平铺 ListItem → 原生 `ListItemGroup` + `List.sticky(StickyStyle.Header)`（分组头自动吸顶）
  2. 分类选择/管理页展开收起：无动画 → `animateTo` 200ms EaseInOut 过渡动画
  3. 分类行加 `.clip(true)` 防止展开内容溢出
- 复测：BUILD SUCCESSFUL，模拟器验证分组头"2026年8月"吸顶、交易行完整显示、分类展开动画正常

## FIX-011: 空态与资源统一（第四轮）

- 处理：
  1. 空态统一：Index/AccountListPage/TransactionListPage 三处手写空态 → 统一 `EmptyState` 组件（圆形底图标 + 标题 + 副文案 + 操作按钮）
  2. 选中态：AccountRow/TransactionRow 半透明黑硬编码 → `rowSelectedBackground` 资源（base 半透明黑、dark 半透明白，深浅色自适应）
  3. 卡片圆角：AiAssistant/BalanceSheet/AccountEdit 硬编码 8 → `card_radius` 资源常量
- 复测：BUILD SUCCESSFUL，模拟器验证模板页空态组件（圆形底📋图标+标题+副文案）规范显示，账户页正常

## FIX-012: 统一页面顶部栏（第五轮）

- 处理：
  1. 新建统一 `PageHeader` 组件（返回箭头 + 标题 + 右侧文本按钮），替换 9 个页面手写返回栏（Settings/MethodManage/TagManage/CategoryManage/CategorySelect/BalanceSheet/AiAssistant/AccountEdit/ExpenseEdit）
  2. 右侧操作统一为 rightText/onRight（保存/+/重新分析），消除各处手写 Image+Button
- 问题与修复：
  - PageHeader 初版用 @BuilderParam rightContent + 内联闭包 → ArkUI 渲染闭包内 Button 属性链崩溃（Cannot read property height of undefined）
  - 改用简单属性 rightText/onRight（文本按钮），避免 @BuilderParam 内联 builder 的闭包陷阱
  - 动态 `$r()` 资源引用不被支持 → 弃用 rightIcon
- 复测：BUILD SUCCESSFUL，模拟器验证 AI 助手页（返回+标题+重新分析）、分类管理页（返回+标题+）均正常，崩溃修复

## FIX-013: 颜色体系收尾（第六轮）

- 处理：
  1. 新增 `primaryContainer` 资源（base #E6F0FF / dark 半透明主色），替换交易页分组按钮半透明黑背景
  2. 新增 `textTertiary` 资源（base #808080 / dark #8A8A8E），替换 5 处金额中性色硬编码（AccountRow/ColoredAmountText/TransactionRow/Index）
  3. 替换 AccountRow 展开分隔线 `#999999` → `dividerColor` 资源
- 结果：全工程 UI 颜色全部资源化（无散落硬编码），深浅色自适应
- 复测：BUILD SUCCESSFUL，模拟器运行稳定，交易页像素差异率 2.92%（与此前相当，差异为系统托管+语言）

## FIX-014: 交互动画与菜单图标（第七轮）

- 处理：
  1. 交易行状态切换：点击加 150ms EaseOut 缩放动画（对齐安卓 StatusToggle 点击反馈）
  2. 账户行展开：`animateTo` 200ms EaseInOut 展开动画
  3. 更多页菜单：6 个菜单项加业务图标（🤖 AI/🏷️ 类别/💳 付款方法/🔖 标签/📊 资产负债表/⚙️ 设置），对齐安卓抽屉图标
- 复测：BUILD SUCCESSFUL，模拟器验证更多页"图标+文字+右箭头"菜单规范显示，应用稳定

## FIX-015: 账户展开操作与颜色收尾（第八轮）

- 处理：
  1. 账户行展开区加操作按钮行：编辑 / 不计入总数 / 关闭账户（对齐安卓账户操作入口）
  2. 清理剩余硬编码颜色：ExpenseEdit 分类选中色、标签色；CategorySelect 树文字色；AccountRow sumRow 默认色 → 全部资源引用
- 结果：全工程 UI 颜色 100% 资源化（深浅色自适应）
- 复测：BUILD SUCCESSFUL，模拟器验证账户展开显示汇总+操作按钮（编辑/不计入总数/关闭账户）正常，应用稳定

## FIX-016: 系统性 UI 还原对齐（第九轮，重点）

- 背景：通过 uiautomator 控件树逐页反解安卓 V2 真实结构，发现 ArkUI 与安卓存在结构性差距（账户/交易 Tab 布局完全不同）
- 对齐内容：
  1. **交易 Tab**：新增汇总卡片（Total + ⊕收入 + ⊖支出 + ⇄转账，背景 #FEF7FF 对齐安卓 surfaceContainer），顶部加账户切换箭头 + 搜索图标，对齐安卓 Search/Actions 按钮区
  2. **账户 Tab**：headerBar 加搜索图标（对齐安卓 Accounts 搜索框 + Options/Data）
  3. **模板 Tab**：结构对齐（标题 + 空态 + FAB）
- 新增资源：summaryCardBackground（base #FEF7FF / dark #211A26）
- 复测：BUILD SUCCESSFUL，模拟器验证交易页"账户名+余额+汇总卡片+分组列表+FAB+4Tab"结构与安卓高度对齐
