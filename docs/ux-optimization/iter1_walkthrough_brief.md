# 第 1 轮 WALKTHROUGH 走查指令

> 生成: 2026-08-18T04:06 | 轮次: iter1 | 方案: TIME_SLICE
> 子代理: Simulator | 设备令牌: 串行

## 1. 设备信息（隔离合规，只用专用实例）

```
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
KEY=127.0.0.1:16555
APP=org.totschnig.myexpenses
EVID_ROOT=/Users/rainyday/Desktop/migration/arkts_new/docs/ux-optimization/evidence/iter1
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

## 3. 走查页面与旅程（P0 优先）

### 组1: Index + AccountEdit（旅程 J1 新用户首启 + J7 深色）
1. 确保应用在前台（aa start）
2. 首页空态截图+dump（evidence/iter1/Index/01_empty_ui.jpeg + _dump.json）
3. 点击"新建账户"→ AccountEdit 截图+dump
4. 输入账户名称"测试账户1"→ 截图+dump
5. 设置起始余额 1000 → 截图+dump
6. 保存 → 回到首页截图+dump（应有账户显示）
7. 首页有数据态：检查账户列表、汇总数字、Tab 切换
8. 切深色（Settings→界面→主题→深色→重启）→ 首页深色截图+dump
9. 切回浅色

### 组2: ExpenseEdit（旅程 J2 日常记账）
1. 首页点"交易"Tab → 找记账入口
2. 进入 ExpenseEdit → 截图+dump
3. 输入金额、选分类、选日期 → 每步截图+dump
4. 保存 → 回首页截图+dump（应有交易记录）
5. 再记 2 笔（交通/转账类）→ 截图+dump
6. 改一笔金额 → 截图+dump
7. 删一笔 → 截图+dump（确认删除反馈）
8. 深色态重复关键步骤截图

### 组3: Settings（旅程 J5 设置漫游）
1. 更多→设置 → 截图+dump
2. 遍历各设置分组：数据/界面/导入导出/备份/功能/同步/Web界面/附加图片/打印
3. 每个分组进入截图+dump，检查文案/布局/返回
4. 界面设置：主题/字体大小/语言/菜单/启动屏幕/默认操作/显示配置/自动填充
5. 深色态设置页截图

### 组4: AiAssistant（旅程 J4 AI 对话）
1. 首页点"AI"Tab → AiAssistant 截图+dump
2. 输入中文自然语言"记一笔午餐支出30元" → 截图+dump
3. 等待 AI 响应（2~5秒）→ 截图+dump
4. 检查确认气泡/候选选择 → 截图+dump
5. 若 LLM 不可用：标注 LLM-DEPENDENT，只走查界面/输入流程
6. 深色态截图

## 4. 证据命名规范

```
evidence/iter1/<Page>/<seq>_<action>_ui.jpeg   # 截图
evidence/iter1/<Page>/<seq>_<action>_dump.json # 布局
```
- seq: 01, 02, 03... 递增
- action: empty, form, input, save, list, dark, error 等

## 5. 待审计队列上报格式

发现疑似问题时，写入：
```
evidence/iter1/_pending/<page>_<seq>.json
```
内容：
```json
{
  "page": "ExpenseEdit",
  "dimension": "D3",
  "severity": "P1",
  "summary": "保存成功后无反馈",
  "repro": "ExpenseEdit → 填金额 → 保存",
  "evidence": ["evidence/iter1/ExpenseEdit/03_save_ui.jpeg", "..._dump.json"],
  "foundAt": "2026-08-18T04:10"
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
- 完成后写 simulator_1.log 到 logs/

## 8. 输出要求（结构化）

完成后只回结构化摘要（不吐长文）：
```json
{
  "pagesWalked": ["Index", "AccountEdit", "ExpenseEdit", "Settings", "AiAssistant"],
  "evidenceCount": <截图+dump总数>,
  "pendingIssues": <待审计条目数>,
  "pendingIssuesList": ["<page>_<seq>", ...],
  "notes": "<≤3条关键发现>",
  "completedAt": "<时间>"
}
```