# 第 2 轮 WALKTHROUGH 走查指令

> 生成: 2026-08-18T06:03 | 轮次: iter2 | 方案: TIME_SLICE
> 子代理: Simulator-2a / Simulator-2b | 设备令牌: 串行

## 1. 设备信息（隔离合规，只用专用实例）

```
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
KEY=127.0.0.1:16555
APP=org.totschnig.myexpenses
EVID_ROOT=/Users/rainyday/Desktop/migration/arkts_new/docs/ux-optimization/evidence/iter2
```

**所有命令必须带 `-t 127.0.0.1:16555`。绝不连接 5555/5557/5559/15558。**

## 2. 命令模板（已验证可用）

```bash
# 点击
$HDC -t $KEY shell uitest uiInput click <x> <y>
# 滑动
$HDC -t $KEY shell uitest uiInput swipe <x1> <y1> <x2> <y2>
# 输入文本（需先 click 聚焦 TextInput）
$HDC -t $KEY shell uitest uiInput text '<文本>'
# 返回键
$HDC -t $KEY shell uitest uiInput keyEvent Back
# dumpLayout（指定路径）
$HDC -t $KEY shell uitest dumpLayout -p /data/local/tmp/<name>.json
# 截图
$HDC -t $KEY shell uitest screenCap -p /data/local/tmp/<name>.jpeg
# 拉回文件
$HDC -t $KEY file recv /data/local/tmp/<name>.xxx $EVID_ROOT/<Page>/<name>.xxx
# 启动应用
$HDC -t $KEY shell aa start -a EntryAbility -b $APP
# 停止应用
$HDC -t $KEY shell aa force-stop $APP
```

## 3. 走查页面与旅程

### 批次A: 设置入口 P1 页面（Simulator-2a）

#### 组1: CategoryManage（旅程 J5 设置漫游）
1. 首页 → 更多菜单(右上角三点) → 设置 → 找"分类管理"入口
2. 进入 CategoryManage → 截图+dump（01_list_ui.jpeg + _dump.json）
3. 检查分类列表：收入/支出分类、层级、图标
4. 点击"新建分类"按钮 → 截图+dump（02_add_form_ui.jpeg）
5. 输入分类名称"测试分类" → 截图+dump（03_add_input_ui.jpeg）
6. 保存 → 截图+dump（04_add_save_ui.jpeg）
7. 点击已有分类编辑 → 截图+dump（05_edit_form_ui.jpeg）
8. 修改名称 → 保存 → 截图+dump（06_edit_save_ui.jpeg）
9. 删除分类 → 确认对话框 → 截图+dump（07_delete_confirm_ui.jpeg）
10. 返回设置页

#### 组2: MethodManage（旅程 J5）
1. 设置 → 找"付款方式"入口
2. 进入 MethodManage → 截图+dump（01_list_ui.jpeg）
3. 检查付款方式列表
4. 新建付款方式 → 截图+dump（02_add_form_ui.jpeg）
5. 保存 → 截图+dump（03_add_save_ui.jpeg）
6. 编辑 → 截图+dump（04_edit_ui.jpeg）
7. 删除 → 确认 → 截图+dump（05_delete_ui.jpeg）
8. 返回设置页

#### 组3: TagManage（旅程 J5）
1. 设置 → 找"标签"入口
2. 进入 TagManage → 截图+dump（01_list_ui.jpeg）
3. 检查标签列表
4. 新建标签 → 截图+dump（02_add_form_ui.jpeg）
5. 保存 → 截图+dump（03_add_save_ui.jpeg）
6. 编辑/删除 → 截图+dump
7. 返回设置页

#### 组4: TagSelect（记账选标签）
1. 首页 → 新增交易 → ExpenseEdit
2. 找标签选择入口 → 截图+dump（01_tag_entry_ui.jpeg）
3. 进入 TagSelect → 截图+dump（02_list_ui.jpeg）
4. 多选标签 → 截图+dump（03_multi_select_ui.jpeg）
5. 搜索标签（如有搜索框）→ 截图+dump（04_search_ui.jpeg）
6. 确认选择 → 返回 ExpenseEdit → 截图+dump（05_confirm_ui.jpeg）
7. 返回

#### 组5: SearchPage（旅程 J6 搜索与筛选）
1. 首页 → 找搜索入口（放大镜图标或搜索Tab）
2. 进入 SearchPage → 截图+dump（01_search_entry_ui.jpeg）
3. 输入关键字"餐" → 截图+dump（02_search_input_ui.jpeg）
4. 查看搜索结果 → 截图+dump（03_search_results_ui.jpeg）
5. 空结果测试：输入"xyz不存在的关键字" → 截图+dump（04_empty_results_ui.jpeg）
6. 筛选功能（如有）→ 截图+dump（05_filter_ui.jpeg）
7. 点击搜索结果跳转详情 → 截图+dump（06_detail_ui.jpeg）
8. 返回

### 批次B: 首页入口 P1 页面 + AiAssistant 补走查（Simulator-2b）

#### 组6: BalanceSheet（旅程 J3 报表查看）
1. 首页 → 找"报表"入口（Tab或菜单）
2. 进入 BalanceSheet → 截图+dump（01_entry_ui.jpeg）
3. Tab 切换（收支/分类/账户等）→ 每步截图+dump
4. 图表交互（点击柱状/饼图）→ 截图+dump（02_chart_interact_ui.jpeg）
5. 导出功能（如有入口）→ 截图+dump
6. 空数据态检查 → 截图+dump
7. 返回

#### 组7: Distribution（分布）
1. 首页 → 找"分布"入口
2. 进入 Distribution → 截图+dump（01_entry_ui.jpeg）
3. 检查分布图表（饼图/柱状）
4. 时间范围切换（如有）→ 截图+dump
5. 分类点击 → 截图+dump（02_category_click_ui.jpeg）
6. 返回

#### 组8: History（历史）
1. 首页 → 找"历史"入口
2. 进入 History → 截图+dump（01_entry_ui.jpeg）
3. 列表加载 → 截图+dump
4. 筛选（日期/分类/金额）→ 截图+dump（02_filter_ui.jpeg）
5. 滚动加载更多 → 截图+dump（03_scroll_ui.jpeg）
6. 点击条目 → 截图+dump（04_detail_ui.jpeg）
7. 返回

#### 组9: BudgetManage + BudgetEdit（预算管理）
1. 首页 → 找"预算"入口（NavDestination pageMap，可能在更多菜单或设置）
2. 进入 BudgetManage → 截图+dump（01_list_ui.jpeg）
3. 新建预算 → BudgetEdit → 截图+dump（02_add_form_ui.jpeg）
4. 设置预算金额/分类/周期 → 截图+dump（03_config_ui.jpeg）
5. 保存 → 截图+dump（04_save_ui.jpeg）
6. 编辑预算 → 截图+dump（05_edit_ui.jpeg）
7. 删除预算 → 确认 → 截图+dump（06_delete_ui.jpeg）
8. 返回

#### 组10: DebtManage（债务管理）
1. 首页 → 找"债务"入口（NavDestination pageMap）
2. 进入 DebtManage → 截图+dump（01_list_ui.jpeg）
3. 新建债务 → 截图+dump（02_add_form_ui.jpeg）
4. 保存 → 截图+dump（03_save_ui.jpeg）
5. 编辑/删除 → 截图+dump
6. 返回

#### 组11: AiAssistant 补走查（旅程 J4，BLK-001 补完）
1. 首页 → 点"AI"Tab → AiAssistant → 截图+dump（01_main_ui.jpeg）
2. 输入中文自然语言"记一笔午餐支出30元" → 截图+dump（02_input_ui.jpeg）
3. 等待 AI 响应（2~5秒）→ 截图+dump（03_response_ui.jpeg）
4. 检查确认气泡/候选选择 → 截图+dump（04_confirm_ui.jpeg）
5. 若 LLM 不可用：标注 LLM-DEPENDENT，只走查界面/输入流程
6. 清空对话/新对话（如有）→ 截图+dump
7. 深色态截图（08_dark_ui.jpeg）

## 4. 证据命名规范

```
evidence/iter2/<Page>/<seq>_<action>_ui.jpeg   # 截图
evidence/iter2/<Page>/<seq>_<action>_dump.json # 布局
```
- seq: 01, 02, 03... 递增
- action: list, form, input, save, edit, delete, search, filter, chart, dark 等

## 5. 待审计队列上报格式

发现疑似问题时，写入：
```
evidence/iter2/_pending/<page>_<seq>.json
```
内容：
```json
{
  "page": "CategoryManage",
  "dimension": "D1",
  "severity": "P1",
  "summary": "新建分类保存后列表未刷新",
  "repro": "CategoryManage → 新建 → 输入名称 → 保存 → 列表无新项",
  "evidence": ["evidence/iter2/CategoryManage/03_add_save_ui.jpeg", "..._dump.json"],
  "foundAt": "2026-08-18T06:10"
}
```

## 6. 九维度判定参考（发现问题时标注）

- D1 可用性 | D2 视觉还原 | D3 反馈与状态 | D4 输入体验 | D5 导航与可达
- D6 动效与性能感知 | D7 深色主题 | D8 无障碍 | D9 文案与本地化

## 7. 注意事项

- 输入法已启用（小艺输入法），无需再次设置
- 深色切换：应用内 Settings→界面→主题→深色，需重启应用生效
- 每次操作后重新 dumpLayout 取最新坐标，禁止复用旧坐标
- 截图/dump 先落盘再分析，不贴进对话
- 发现疑似问题立即写入 _pending，不直接改 ledger
- 入口找不到时记录为可达性问题（D5），截图+dump 留证
- NavDestination pageMap 页面（Budget/Debt）入口可能在更多菜单或设置中，仔细查找
- 完成后写 simulator_2a.log / simulator_2b.log 到 logs/

## 8. 输出要求（结构化）

完成后只回结构化摘要（不吐长文）：
```json
{
  "batch": "A",
  "pagesWalked": ["CategoryManage", "MethodManage", "TagManage", "TagSelect", "SearchPage"],
  "evidenceCount": <截图+dump总数>,
  "pendingIssues": <待审计条目数>,
  "pendingIssuesList": ["<page>_<seq>", ...],
  "notes": "<≤3条关键发现>",
  "completedAt": "<时间>"
}
```