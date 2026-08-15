# 全应用原生 HarmonyOS UI 实施计划

> 设计依据：`docs/superpowers/specs/2026-08-16-native-harmony-ui-design.md`

## 原则

每个阶段先记录当前行为或补充可执行的静态约束，再修改 UI，最后运行测试和构建。业务方法、数据库方法及页面参数不参与机械重构。

## 任务一：建立 UI 语义资源

涉及文件：

- `entry/src/main/resources/base/element/color.json`
- `entry/src/main/resources/base/element/float.json`

步骤：

1. 增加页面表面、卡片、弱强调背景、交互按压、禁用态等语义色。
2. 增加页面边距、列表高度、圆角和点击目标等尺寸资源。
3. 搜索新增硬编码颜色，确保页面优先引用语义资源。
4. 构建验证资源名称和类型。

## 任务二：升级公共组件

涉及文件：

- `entry/src/main/ets/components/PageHeader.ets`
- `entry/src/main/ets/components/EmptyState.ets`
- `entry/src/main/ets/components/AccountRow.ets`
- `entry/src/main/ets/components/TransactionRow.ets`

步骤：

1. 为公共组件补充结构和触控区域约束测试或静态检查。
2. 保留全部公开属性与回调签名。
3. 统一标题栏操作按钮、状态组件和列表行视觉。
4. 运行单测和构建。

## 任务三：统一根导航和核心 Tab

涉及文件：

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/components/AccountListPage.ets`
- `entry/src/main/ets/components/TransactionListPage.ets`

步骤：

1. 保持 `selectedTab`、账户选择和页面刷新逻辑不变。
2. 抽取并统一底部 Tab 构建逻辑，移除重复 UI 代码。
3. 将“更多”展示改为原生底部交互，同时保留全部入口回调。
4. 统一账户、交易和模板的标题、摘要、列表及 FAB。
5. 在模拟器验证三 Tab 和更多入口。

## 任务四：统一编辑和选择页面

涉及文件：

- `entry/src/main/ets/pages/AccountEdit.ets`
- `entry/src/main/ets/pages/ExpenseEdit.ets`
- `entry/src/main/ets/pages/CategoryManage.ets`
- `entry/src/main/ets/pages/CategorySelect.ets`
- `entry/src/main/ets/pages/MethodManage.ets`
- `entry/src/main/ets/pages/TagManage.ets`
- `entry/src/main/ets/pages/TagSelect.ets`
- 相关对话框组件

步骤：

1. 记录各页面的入参、保存入口和返回逻辑。
2. 将字段视觉统一为原生分组表单，不移动业务校验代码。
3. 统一选择列表、输入对话框和底部操作区。
4. 模拟器检查进入、输入、取消和返回，不执行破坏性写操作。

## 任务五：统一辅助页面

涉及文件：

- `entry/src/main/ets/pages/Settings*.ets`
- `entry/src/main/ets/pages/Budget*.ets`
- `entry/src/main/ets/pages/DebtManage.ets`
- `entry/src/main/ets/pages/SearchPage.ets`
- `entry/src/main/ets/pages/Distribution.ets`
- `entry/src/main/ets/pages/History.ets`
- `entry/src/main/ets/pages/BalanceSheet.ets`

步骤：

1. 设置使用原生分组列表、开关、选择项和 `NavDestination` 标题。
2. 预算和债务使用统一卡片、进度、空态及编辑弹层。
3. 搜索、统计和历史统一摘要、条件和结果容器。
4. 保持查询、统计、保存和路由代码不变。

## 任务六：回归和交付

步骤：

1. 运行完整单元测试。
2. 运行 `assembleHap`。
3. 安装最新 HAP，在模拟器执行只读关键流程回归。
4. 采集核心页面截图并检查系统安全区、遮挡、滚动和无障碍文本。
5. 审查 diff，确认未误改数据库和业务逻辑。
6. 编写完整修改报告，列出完成项、未改行为和验证证据。

