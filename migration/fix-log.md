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

## FIX-017: 差异文档待优化项修复（第十轮）

- 按 ui-difference-analysis.md 待优化项逐项处理：
  1. **UI-001（P2）**：更多页菜单 Emoji 图标 → 6 个 SVG 图标资源（ic_ai_robot/ic_category/ic_method/ic_tag/ic_balance/ic_settings），Image 组件加载 + fillColor 着色
  2. **UI-002（P3）**：记账编辑页新增 CalculatorDialog 组件（数字键 + 四则运算 + 正负/百分号 + 确定按钮），金额行右侧加计算器入口
  3. **UI-003（P3）**：拖拽排序待实现（递归树结构与 List.onItemMove 冲突，需重构）
  4. **UI-004（P3）**：保存按钮样式差异标记可接受
- 复测：BUILD SUCCESSFUL，模拟器验证更多页 SVG 图标、记账编辑页计算器弹出均正常

## FIX-018: 功能缺失补齐（第十一轮，F-001~F-008 全部完成）

- 按 ui-function-comparison-full.md 14.2 功能缺失清单逐项实现：
  1. **F-001 账户拖拽排序**：扁平 List + editMode + onItemMove，reorderAccounts 内存重排
  2. **F-002 金额计算器**：CalculatorDialog（数字键 + 四则运算 + 正负/百分号 + 确定）
  3. **F-003 附件添加**：DocumentViewPicker 选附件 + 附件计数（📎入口）
  4. **F-004 拆分交易**：拆分 Tab + 拆分款项列表 + 添加拆分项，saveSplitTransaction 父交易+子交易均摊
  5. **F-005 重复交易（模板体系）**：templates 表 + 模板 Tab 列表 + 新建模板 + "用于交易"实例化
  6. **F-006 分类拖拽排序**：根分类 List + editMode + onItemMove
  7. **F-007 账户标签**：accounts_tags 表 + Repository 方法 + 标签多选 UI
  8. **F-008 保存并新建**：保存后清空金额/备注/类别，保留账户/类型/日期
- 复测：BUILD SUCCESSFUL，模拟器逐项验证通过（模板创建/用于交易、拆分项添加等）

## FIX-019: 门禁收尾（第十二轮）

- 补齐 AccountEdit LIGHT GUI 对比：Android Edit Account 页 → ArkUI 账户编辑页，像素差异 4.41%（低于 5% 阈值 PASS），四图生成（ACC_EDIT_V2_*）
- 更新 gui-matrix（G-AE-01）、problem-ledger（G-010）
- 剩余阻塞（环境性）：DARK 主题截图（模拟器无法命令行切深色）、AiAssistant（Android 无对应页面）、真机矩阵 G-004、签名 HAP G-005、独立审查

## FIX-020: 差异清单收尾（第十三轮）

- 处理剩余差异清单：
  1. **字符/Emoji 违规（7 处）**：TransactionRow 图标（⇄/☰/↑/↓/−）→ ic_transfer/ic_split/ic_income/ic_expense/ic_neutral；AccountRow ∑ → ic_exclude；EmptyState 默认 📋 → 空
  2. **分类拖拽持久化**：categories 表加 sort_order + Repository updateCategoryOrders + getCategories 按 sort_order 排序
  3. **拆分子项独立编辑**：ActionSheet（编辑金额/选择分类/删除）+ 分类选择回传 onPageShow
  4. **附件来源扩展**：相册（PhotoViewPicker）+ 文件（DocumentViewPicker）；**附件缩略图预览**（横排缩略图 + 删除角标）
  5. **计划补齐**：自动执行开关（auto_execute）+ 提前执行天数（advance_days 0-30）+ 设置下次执行日期（DatePickerDialog）
  6. **FAB 圆角矩形**：圆形 → 胶囊形 + 收入/支出箭头图标（对齐 Material3）
  7. **移除账户 Tab 重复 FAB**：只保留交易页 FAB
- 新增 SVG：ic_split/ic_neutral/ic_exclude（累计 24 个）
- 新增数据字段：templates 表 auto_execute/advance_days
- 保留（按策略）：账户 headerBar（#18）、输入框圆角填充（#21）、深色 SVG 用 fillColor 适配（#8）
- 受限：拍照入口（需完整 CameraManager 会话 + CAMERA 权限 + 模拟器无相机硬件）
- 复测：BUILD SUCCESSFUL（HAP 1.08MB），模拟器验证 FAB 胶囊形 + 交易页正常

## FIX-021: 拍照入口实现（第十四轮）

- 实现拍照入口：附件 ActionSheet 增加"拍照"选项（相册/文件/拍照）
- module.json5 添加 CAMERA 权限（reason + usedScene，string.json 加 permission_camera_reason）
- takePhoto 流程：申请相机权限 → 检测相机设备 → 完整相机会话（PhotoSession）拍摄
- 说明：完整 PhotoSession.capture 因 SDK 类型定义与 ArkTS 严格类型不兼容（createPhotoOutput 不在 PhotoSession 接口），降级为能力检测 + 提示真机使用；权限申请已实测弹出正确对话框
- 复测：BUILD SUCCESSFUL，模拟器实测点击"拍照"弹出相机权限对话框"允许'开支助手'访问你的相机？用于拍照添加附件"

## FIX-022: 代码规范修复（第十五轮）

- 处理代码规范性问题：
  1. **硬编码颜色（中）**：账户默认色 #009688 → defaultAccountColor 资源；标签默认色 #0050A7 → defaultTagColor 资源（base+dark）
  2. **硬编码字符串（中）**：19 处 showToast 文案 → string.json 资源（toast_* key），涉及 AccountEdit/CategoryManage/ExpenseEdit/Index
  3. **硬编码尺寸（低）**：fontSize/height/width 字面量（287 处）——ArkUI 常见做法，文档标低严重度，保留
- 保留说明：阴影色 #40000000、FAB 分隔线 #66FFFFFF 为透明色深浅色通用，保留字面量合理
- 复测：BUILD SUCCESSFUL，模拟器应用稳定

## FIX-023: BUG-C 修复（全流程测试发现）

- 问题：模板行周期标签不刷新（周期保存成功 recurrence=4，但 UI 副信息不显示周期标签）
- 根因：ForEach keyGenerator 用 `tpl_${tpl.id}`（id 不变），周期变化后 item 组件被复用且不重建，闭包内 tpl.recurrence 未重新渲染
- 修复：keyGenerator 改为 `tpl_${tpl.id}_${tpl.recurrence}_${tpl.advanceDays}_${tpl.autoExecute}`，周期/提前天数/自动执行变化时 key 变 → item 重建 → 标签刷新
- 复测：BUILD SUCCESSFUL，模拟器验证"每月"→设"每周"后标签实时刷新为"每周"，数据库 recurrence=3

## FIX-024: BUG-002 修复（账户菜单删除/Flag）

- 问题：账户管理页更多菜单缺少"删除"和"Flag"操作（Android 有）
- 处理：
  1. **删除**：AccountRow 展开操作区加"删除"按钮（红色），回调 onDelete 已贯通（Index.deleteAccount + 确认对话框）
  2. **Flag**：accounts 表加 flag_id 列 + account_flags 种子数据（默认/常用/重要/隐藏）+ Repository getAccountFlags/setAccountFlag + 账户展开区"标记"按钮弹 ActionSheet 选标记
  3. **迁移逻辑真正加入**：修复之前迁移代码未保存成功的问题，DbHelper init 添加 MIGRATIONS 数组（accounts.flag_id/categories.sort_order/templates 各列），容错 ALTER TABLE
- 复测：BUILD SUCCESSFUL，模拟器验证：账户展开菜单显示"编辑/标记/不计入总数/关闭账户/删除"；点"标记"弹出默认/常用/重要/隐藏选择；设"重要"后数据库 flag_id=3

## FIX-025: 底部导航改为悬浮页签栏（用户要求）

- 需求：底栏用鸿蒙原生悬浮页签栏（TabBar）实现
- 处理：
  1. build 从标准 Tabs（barPosition.End）重构为 **Stack 布局 + 悬浮 TabBar**
  2. 内容区按 selectedTab 用 if/else 切换（accountsTab/transactionsTab/templatesTab/moreTab）
  3. 悬浮 TabBar：圆角胶囊（88% 宽、64 高、borderRadius 32）+ 阴影 + position 悬浮于内容之上（y 88%）
  4. 选中项：浅蓝背景胶囊高亮（floatTabItemActive）+ 蓝色图标/文字；未选中灰色
  5. 新增资源：floatTabBarBackground（base #F2F2F7 / dark #2C2C2E）、floatTabItemActive（base #1A0050A7 / dark #330050A7）
- 复测：BUILD SUCCESSFUL，模拟器验证悬浮胶囊 TabBar（圆角+阴影+选中高亮）显示正常，Tab 切换正常

## FIX-026: 悬浮 TabBar 增加原生滑动指示器动画（用户要求）

- 需求：悬浮 TabBar 要有原生 Tabs 的选中指示器滑动动画（非静态高亮）
- 处理：
  1. 恢复原生 `Tabs` 组件承载内容（TabContent 自带 300ms 内容切换动画，barHeight=0 隐藏原生 bar）
  2. 悬浮胶囊 TabBar 用 Stack 双层：底层 4 个 tab 项（透明）+ 上层**绝对定位选中胶囊**（position 由 `indicatorOffset` 驱动）
  3. 点击/切换时 `animateTo({ duration: 250, curve: Curve.EaseInOut })` 平滑滑动胶囊到选中项，模拟原生指示器滑动
  4. 选中项图标/文字变白色（胶囊高亮），未选中灰色
  5. `tabItemWidth()` = 88% 屏宽 / 4，精确计算胶囊落点
- 复测：BUILD SUCCESSFUL，模拟器验证悬浮胶囊 + Tab 切换（账户→交易）正常，指示器随切换滑动

## FIX-027: 修复悬浮 TabBar 遮挡内容（用户反馈）

- 问题：底部内容被悬浮 TabBar 遮挡，列表底部显示不全
- 处理：Tabs 内容区加 `.padding({ bottom: 110 })`，预留悬浮 TabBar 空间，列表可滚动到 TabBar 上方
- 复测：BUILD SUCCESSFUL，模拟器验证内容底部与 TabBar 之间有充足间距（账户列表最后项 y785 到 TabBar y2588），内容不再被遮挡

## FIX-028: 底部导航改为方案A（贴底白色 TabBar，用户确认）

- 需求：按方案 A 修改——去掉悬浮胶囊，改贴底纯白 TabBar + 清晰选中态
- 处理：
  1. build 从悬浮胶囊 Stack 改为原生 `Tabs({ barPosition: BarPosition.End })` + `.barHeight(56)` 贴底 + `.barBackgroundColor(tabBarBackground)` 白底
  2. tabBar 自定义 builder：选中项图标/文字 `primaryColor`（蓝色），未选中 `#999999`（浅灰），高对比度
  3. 选中项加底部蓝色指示线（24×3 圆角横线，translate 居中）
  4. 删除悬浮胶囊相关代码（floatTabItem/tabItemWidth/indicatorOffset/floatTabBarBackground/floatTabItemActive）
- 复测：BUILD SUCCESSFUL，模拟器验证：TabBar 贴底白底、选中"账户"蓝色+指示线、未选中浅灰、对比度 AA 级、Tab 切换正常

## FIX-029: BUG-003 修复（关闭账户未显示锁定图标）

- 问题：关闭账户后账户条目右侧未显示锁形图标
- 根因（两个）：
  1. `ic_locked.svg` 外层 `fill="none"` 且 path 未设 fill，Image 未设 fillColor → 图标渲染不可见
  2. AccountListPage ForEach keyGenerator 用 `account_${acc.id}`（id 不变），sealed 变化后 item 不重建 → 关闭后 UI 不刷新
- 处理：
  1. ic_locked.svg path 加 `fill="#666666"`，AccountRow 锁定/排除图标加 `.fillColor(textSecondary)`（深浅色适配）
  2. AccountListPage ForEach key 改为 `account_${id}_${sealed}_${excludeFromTotals}_${flagId}`，状态变化强制重建
- 复测：BUILD SUCCESSFUL，模拟器验证：Budget Book 关闭后名称右侧清晰显示灰色锁图标，现金账户无锁图标，对比正确

## FIX-030: BUG-004 修复（账户标题旁缺资产负债表切换入口）

- 问题：账户标题旁缺少箭头，无法切换到资产负债表（Android 有）
- 处理：headerBar 在账户 Tab 时，标题"账户"右侧加下拉箭头（ohos_ic_public_arrow_down），点击 navigateToBalanceSheet 跳转资产负债表页
- 复测：BUILD SUCCESSFUL，模拟器验证：账户标题右侧清晰显示下拉箭头，点击成功跳转资产负债表（净资产/资产/负债）

## FIX-031: BUG-005 修复（账户页右上角缺选项图标）

- 问题：账户管理页右上角缺少选项图标（Android accounts.xml 有菜单）
- 处理：
  1. headerBar 账户 Tab 时，添加图标右侧加更多选项图标（ohos_ic_public_more）
  2. 点击弹"账户选项"ActionSheet：账户类型/账户标记/显示等值/资产负债表（对齐 Android accounts.xml 菜单）
  3. 显示等值切换持久化（preferences）
- 复测：BUILD SUCCESSFUL，模拟器验证：账户标题右侧图标顺序"搜索→添加→选项"；点选项弹菜单；点资产负债表跳转成功

## FIX-032: BUG-006 修复（账户页加号含义不明确）

- 问题：账户页右上角加号图标含义不明确（与页面操作不匹配），选项图标需更规范
- 处理：
  1. 移除账户页右上角加号图标（新建账户入口不明确）
  2. 新建账户入口移入账户选项菜单（对齐 Android CREATE_ACCOUNT_COMMAND）
  3. 账户页顶部右侧保留：搜索 + 选项（⋮）两个明确图标
- 复测：BUILD SUCCESSFUL，模拟器验证：账户页顶部标题区仅"搜索+选项"，无加号；选项菜单含"新建账户/账户类型/账户标记/显示等值/资产负债表"

## FIX-033: BUG-007 修复（交易页功能重复按钮）

- 问题：FAB 菜单"支出/收入/转账"三个选项执行相同功能（都打开默认新建交易页，不区分类型）
- 处理：
  1. navigateToExpenseEdit 增加 type 参数
  2. FAB 菜单三个选项传不同 type：支出(-1)/收入(1)/转账(2)
  3. ExpenseEdit aboutToAppear 读取 type 参数预选类型（收入→isIncome=true，转账→operationType=TRANSFER，支出→默认）
- 复测：BUILD SUCCESSFUL，模拟器验证：FAB 菜单选"收入"→编辑页"收入"类型蓝色高亮（预选正确），三入口各自独立

## FIX-034: BUG-008 修复（新建支出页标签缺失/布局不一致）

- 问题：新建支出页"标签"功能被认为缺失（实际在表单底部需滚动），且字段顺序与 Android 不一致
- 处理：
  1. 字段顺序调整对齐 Android：账户→金额→收款人→类别→日期→时间→标签→付款方法→备注（原类别在收款人前、标签在备注后）
  2. 标签行提前到付款方法前（对齐 Android TagRow 位于类别后），更早可见
- 复测：BUILD SUCCESSFUL，模拟器验证：新建支出页字段顺序正确，标签行（"工作"气泡）在付款方法前可见，布局完整

## FIX-035: BUG-009 修复（交易记录左侧缺查看按钮）

- 问题：交易记录缺少明确的查看入口（Android 有）
- 处理：TransactionRow 金额/日期右侧加查看箭头（ohos_ic_public_arrow_right），整行点击已可查看详情（onItemClick → 编辑页）
- 复测：BUILD SUCCESSFUL，模拟器验证：每笔交易行最右侧显示">"查看箭头，交易行结构完整（状态图标/类别/文本/金额/日期/查看入口）

## FIX-036: BUG-010 修复（新建收入页缺"展示原始金额"）

- 问题：记账编辑页右上角缺选项入口，无法展示原始金额（Android 有 menu_original_amount）
- 处理：
  1. PageHeader 加 showMore/onMore 支持右侧更多图标（⋮）
  2. ExpenseEdit PageHeader 加更多图标，点击弹"记账选项"菜单（展示/隐藏原始金额）
  3. 新增 showOriginalAmount/originalAmountInput/originalCurrency 状态 + toggleOriginalAmount
  4. 原始金额输入行：因 if 条件渲染不响应 ActionSheet 回调后的 @State，改用 visibility 控制显隐（可靠响应式）
- 复测：BUILD SUCCESSFUL，模拟器验证：编辑页右上角"保存+⋮"；点选项"展示原始金额"→原始金额输入行显示（金额行上方）

## FIX-037: BUG-011 修复（拆分页少标签多收款方法）

- 问题：拆分页无标签字段（拆分项无标签选择），且显示收款方法字段（Android 拆分页无）
- 处理：
  1. 拆分项编辑菜单加"选择标签"选项（selectSplitPartTag 弹标签多选 ActionSheet，可多选）
  2. 拆分项行显示已选标签（标签气泡 + tagLabel 方法），标签变化时 key 重建
  3. 付款方法行在拆分模式隐藏（visibility），对齐 Android 拆分页无收款方法
- 复测：BUILD SUCCESSFUL，模拟器验证：拆分模式无付款方法字段，拆分款项区域+添加拆分项正常，拆分项编辑含标签选择

## FIX-038: BUG-012 修复（更多页缺预算编制和债务）

- 问题：更多页缺少预算编制和债务入口（Android 有）
- 处理：
  1. Repository 新增 insertBudget/deleteBudget/insertDebt/deleteDebt
  2. 新建 BudgetManage 页面（预算列表 + 新建预算对话框）
  3. 新建 DebtManage 页面（债务列表 + 新建债务对话框）
  4. 更多页菜单加"预算编制"和"债务"入口（注册路由）
- 复测：BUILD SUCCESSFUL，模拟器验证：更多页菜单含预算编制/债务；预算编制页新建"餐饮预算"成功（budgets 表+1）；债务页可新建

## FIX-039: BUG-013 修复（设置页内容缺失多）

- 问题：设置页设置项较少，与 Android PreferenceActivity 不对应
- 处理：扩展 Settings.ets 分组，对齐 Android 主要设置项：
  1. 数据管理：账户/类别/付款方法/标签/**货币**（新增）
  2. 界面：**主题**（跟随系统/浅色/深色，ActionSheet 选择 + AppStorage 通知）/ **语言**（中文，只读）（新增）
  3. 显示：显示等值/**分组头显示明细**（新增）
  4. 导入导出：**CSV 导出/备份与恢复**（新增占位）
  5. 关于：**版本 1.0.0**（新增）
- SettingsService 加 THEME/LANGUAGE key
- 复测：BUILD SUCCESSFUL，模拟器验证：设置页含数据管理/界面/显示/导入导出/关于全部分组；主题选择 ActionSheet 弹出（跟随系统/浅色/深色）

## FIX-040: BUG-014 修复（资产负债表缺日期/资产分类/现金账户）

- 问题：资产负债表只显示简单总额，缺日期、资产类型分组、现金账户详情
- 处理：完善 BalanceSheet.ets：
  1. 日期栏：显示当前日期，点击弹 DatePickerDialog
  2. 资产按类型分组：现金/银行/资产账户，各分组显示账户明细
  3. 负债详情：显示各负债账户 + 类型标签
  4. 资产/负债区头部显示合计
- 复测：BUILD SUCCESSFUL，模拟器验证：资产负债表显示日期(2026-08-06)、净资产、资产分组（银行：Budget Book/现金：现金账户）、负债

## FIX-041: BUG-015 修复（交易页右上角操作按钮缺失）

- 问题：交易页右上角缺更多操作按钮（排序/导出/筛选），测试者认为搜索也缺（实际已有）
- 处理：transactionHeader 加更多操作图标（⋮），点击弹 ActionSheet：分组切换/排序（日期）/导出 CSV/筛选
- 复测：BUILD SUCCESSFUL，模拟器验证：交易页顶部含账户名/余额+搜索+分组+AI+更多操作；点更多弹"分组/排序/导出/筛选"菜单

## FIX-042: BUG-016 确认（新建账户页标签选项）

- 问题：新建账户页被认为缺标签选项（Android 有）
- 核实：账户标签功能已实现（F-007）——AccountEdit 标签多选行 + loadTags + setAccountTagIds 保存
- 验证：BUILD SUCCESSFUL，模拟器验证新建账户页显示"标签"行（储蓄目标后），标签"工作"气泡可点击多选
- 结论：功能存在（标签行在表单底部，滚动可见），无需代码改动

## FIX-043: BUG-017 修复（账户管理页不同类型账户无区分和累计）

- 问题：不同类型的账户没有区分显示和分类累计（Android AccountGrouping.TYPE）
- 处理：
  1. AccountListPage groups() 在 NONE 时也按类型分组（账户列表默认类型分组）
  2. 扁平拖拽分支条件改为 groupSingle()（仅单组时扁平）
  3. Index 默认分组改为 AccountGrouping.TYPE
- 复测：BUILD SUCCESSFUL，模拟器验证：账户列表按类型分组（银行账户/现金账户组头），每组显示累计金额（银行-50/现金0），账户行正确归组

## FIX-044: 代码规范修复（TabBar 硬编码色/管理页硬编码色）

- 处理：
  1. bug007 确认：交易页新建入口仅 FAB（主）+ 空态按钮（无交易时），无重复，无需改动
  2. TabBar 未选中态 #999999 → textSecondary 资源（2 处）
  3. BudgetManage/DebtManage 取消按钮 #EEEEEE/#333333 → cardBackgroundColor/textPrimary 资源
  4. Index #66FFFFFF（FAB 分隔线）/ #40000000（阴影）透明色深浅色通用，保留
- 复测：BUILD SUCCESSFUL，模拟器应用稳定
