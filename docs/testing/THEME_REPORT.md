# myexpenses-arkts 浅色/深色模式验证报告（Theme Verification）

- 验证角色：Deep Theme Verification Agent
- 验证环境：模拟器 B（127.0.0.1:15558），鸿蒙 API 6.1.1(24)，屏幕 1320×2856
- 被测应用：org.totschnig.myexpenses（myexpenses-arkts），HAP 为最新已安装版本
- 数据：标准数据（5 账户 / 8 交易 / 10 分类）
- 验证方式：hdc + uitest dumpLayout + snapshot_display(jpeg) + sqlite3 + 像素直方图核验
- 证据目录：`docs/testing/evidence/theme/`（共 22 张截图）
- 验证范围：浅色 + 深色双模式；账户页 / 交易页 / AI 页 / 模板页 / 更多页 / 交易编辑页 / 关键交互（长按菜单、日期弹窗、FAB）
- 代码变更：无（仅验证与记录，未修改任何业务代码与资源）
- 日期：2026-08-16

---

## 1. 深色切换方法（结果：成功）

| 尝试方法 | 命令 | 结果 |
|---|---|---|
| 方法1（设置应用） | `aa start -a com.huawei.hmos.settings.MainAbility -b com.huawei.hmos.settings` → 点击"显示和亮度"(406,1482) → 点击"深色"tab(955,1150) | ✅ 成功 |
| 方法2（settings 命令） | `settings put global dark_mode 1` | ❌ 模拟器无 `settings` 命令 |
| 方法3（param） | `param get/set persist.sys.dark_mode` | ❌ param 无该键 |

**实际生效方法**：通过系统"设置 → 显示和亮度 → 显示模式"，点击"深色"选项卡。
**验证证据**：`settings_dark_check.jpeg`——设置页背景变为深色（主背景约 #121212），"深色"tab 选中，状态栏文字变白。
**切回浅色**：同一页面点击"浅色"tab，`light_check.jpeg` 确认页面变浅色且"深色模式"显示"已关闭"。

> 说明：模拟器为纯深/浅双态切换（无跟随系统时间），切换后系统级 UI 与应用同步刷新，无需重启应用。

---

## 2. 页面验证结果矩阵

| 页面 | 浅色 | 深色 | 深色主要问题 |
|---|---|---|---|
| 账户页（账户列表/卡片/分组头/累计） | ✅ PASS | ⚠️ FAIL | 账户卡片白底、累计卡片浅灰、浅蓝卡片 |
| 交易页（交易行/汇总卡片/FAB/筛选） | ✅ PASS | ⚠️ FAIL | Total 卡片纯白、交易行白底、月分组头浅灰 |
| AI 页（对话气泡/输入栏） | ✅ PASS | ✅ PASS | 无 |
| 模板页（模板列表/空状态） | ✅ PASS | ✅ PASS | 无 |
| 更多页（菜单列表/设置入口） | ✅ PASS | ✅ PASS | 无（弹出菜单深灰，正常） |
| 交易编辑/新建交易页（表单/按钮） | ✅ PASS | ⚠️ FAIL | 表单卡片白底、支出/收入切换白底 |
| 长按交易行菜单（多选模式） | ✅ PASS | ⚠️ FAIL | Total 卡片白色（其余工具栏/选中态正常） |
| 日期选择弹窗 | ✅ PASS | ✅ PASS | 无 |
| FAB（新增交易入口） | ✅ PASS | ✅ PASS | 红色 FAB 醒目，正常 |

---

## 3. 深色问题详细列表

问题总数：**5 个独立问题**（涉及 4 个页面/交互，同一根因）。

### P1. 账户页账户卡片背景为白色 / 浅蓝（深色下）
- **区域**：账户页各账户行卡片（信用卡/支付宝/银行卡/旅行基金/现金）
- **现象**：深色模式下账户卡片为纯白（#FFFFFF）或浅蓝（#E9F3FF），与深色背景（#121212）形成强烈对比，视觉刺眼
- **像素证据**：`dark_accounts.jpeg` 直方图含 #FFFFFF x2812、#E9F3FF x636（卡片区）；账户行中心点 (300,600) = (231,241,251)
- **截图文件**：`dark_accounts.jpeg`
- **疑似原因**：`AccountRow.ets:211` 使用 `$r('app.color.surfacePrimary')` / `$r('app.color.surfaceBrandSoft')`，而 **dark 资源目录未定义这两个键**，深色模式下回退到 base 的浅色值（surfacePrimary=#FFFFFF、surfaceBrandSoft=#E9F2FF）

### P2. 账户页累计汇总卡片为浅灰（深色下）
- **区域**：账户页底部"累计 ¥6757.00"卡片
- **现象**：深色下卡片背景为浅灰 #F3F4F6
- **像素证据**：`dark_accounts.jpeg` 直方图含 #F3F4F6 x527；累计卡片点 (700,2215) = (243,244,246)
- **截图文件**：`dark_accounts.jpeg`
- **疑似原因**：`AccountListPage.ets:322` 使用 `$r('app.color.surfaceSecondary')`，dark 目录未定义该键，回退 base 值 #F3F4F6

### P3. 交易页 Total 汇总卡片纯白、交易行白底、月分组头浅灰（深色下）
- **区域**：交易页"Total/收入/支出/转帐"汇总卡片、交易列表行、月分组头（如"2026年8月"）
- **现象**：深色下 Total 卡片纯白（#FFFFFF）、交易行纯白（#FFFFFF）、月分组头浅灰（#F3F4F6），与深色背景 #121212 对比强烈
- **像素证据**：`dark_tx_cash.jpeg` 直方图 #FFFFFF x4302（最大色块）、#F3F4F6 x1058；Total 卡片点 (700,600)=(255,255,255)、交易行点 (700,1100)=(255,255,255)、月分组头点 (700,930)=(243,244,246)
- **截图文件**：`dark_tx_cash.jpeg`、`dark_transactions.jpeg`（信用卡账户空状态下 Total 卡片同样白色）、`dark_tx_menu.jpeg`（长按多选模式下 Total 卡片仍白色）
- **疑似原因**：
  - Total 卡片：`Index.ets:2474` `summaryCard()` 使用 `$r('app.color.surfacePrimary')`（dark 缺失 → 白）
  - 交易行/月分组头：交易列表相关组件使用 `surfacePrimary` / `surfaceSecondary`（dark 缺失 → 白/浅灰）

### P4. 交易编辑/新建交易页表单卡片纯白、支出/收入切换白底（深色下）
- **区域**：新建交易页表单区（账户/金额/日期/付款人/类别/备注等字段）、支出/收入/转账/拆分切换栏、保存按钮区
- **现象**：深色下表单卡片纯白（#FFFFFF）、切换栏纯白（#FFFFFF），仅"日期/时间"字段为深灰（#333333），风格割裂；页面右上角无深色适配
- **像素证据**：`dark_new_tx.jpeg` 直方图 #FFFFFF x2687（最大色块）；金额字段点 (700,950)=(255,255,255)、切换栏点 (700,440)=(255,255,255)；标题栏点 (200,300)=(18,18,18) 为深色（仅状态栏/标题正常）
- **截图文件**：`dark_new_tx.jpeg`、`dark_tx_edit.jpeg`（同页面）
- **疑似原因**：`ExpenseEdit.ets:1483` 表单容器 `surfacePrimary`、`:648/656` `surfaceSecondary`、`:708/763` `surfaceBrandSoft`；`Index.ets:2154` 交易操作弹层 `.backgroundColor(Color.White)` 硬编码；均未随深色切换

### P5. 交易页右上角操作弹层菜单硬编码白底（深色下，间接影响）
- **区域**：交易页右上角"排序/分布图/历史记录/导出CSV/筛选"弹层菜单
- **现象**：菜单容器硬编码 `Color.White` 背景，深色下为白色浮层
- **截图文件**：本会话未单独截取该菜单（多选工具栏 `dark_tx_menu.jpeg` 已确认工具栏深色正常），依据代码 `Index.ets:2154` 记录为高置信疑似项
- **疑似原因**：`Index.ets:2154` `.backgroundColor(Color.White)` 硬编码

---

## 4. 重点标记（深色下需优先修复）

| 严重度 | 页面/区域 | 现象 | 截图 |
|---|---|---|---|
| 🔴 高 | 交易页 Total 汇总卡片 | 纯白 #FFFFFF，深色下最大面积白块 | dark_tx_cash.jpeg |
| 🔴 高 | 交易页交易行 | 每行白底，形成白色列表区 | dark_tx_cash.jpeg |
| 🔴 高 | 新建交易页表单区 | 整块白色表单卡，白卡最密集页面 | dark_new_tx.jpeg |
| 🔴 高 | 账户页账户卡片 | 白底卡片 + 浅蓝选中态卡 | dark_accounts.jpeg |
| 🟠 中 | 账户页累计卡片 | 浅灰 #F3F4F6 | dark_accounts.jpeg |
| 🟠 中 | 交易页月分组头 | 浅灰 #F3F4F6 | dark_tx_cash.jpeg |
| 🟠 中 | 交易页操作弹层菜单 | 硬编码 Color.White（代码确认） | — |
| 🟢 无 | AI/模板/更多/日期弹窗 | 深色正常，无白块 | dark_ai/dark_templates/dark_more/dark_date_dialog |

---

## 5. 根因分析（已通过像素直方图核验）

**根因 A（核心，覆盖 P1–P4 大部分）**：`entry/src/main/resources/dark/element/color.json` 缺失 11 个颜色键，
深色模式下这些资源**回退到 base 浅色值**，导致卡片/表单/列表全部"漂白"：

```
缺失键（dark 未定义，base 定义）：
  surfacePrimary      base=#FFFFFF
  surfaceSecondary    base=#F3F4F6
  surfaceElevated     base=#FFFFFF
  surfaceBrandSoft    base=#E9F2FF
  surfaceIncomeSoft   base=#EAF6EC
  surfaceExpenseSoft  base=#FCEBEC
  dividerSubtle       base=#12000000
  iconSecondary       base=#7A7F87
  scrimColor          base=#52000000
  interactivePressed  base=#140050A7
  interactiveDisabled base=#61000000
```

**根因 B（P5）**：硬编码 `Color.White` 背景，未走资源引用。`Index.ets:2154`（交易操作弹层）。

**涉及文件清单**（依据代码引用确认）：

| 文件 | 位置 | 使用的资源 | 深色回退值 |
|---|---|---|---|
| `resources/dark/element/color.json` | — | 缺失 11 键 | 回退 base 浅色 |
| `entry/src/main/ets/components/AccountRow.ets` | :211 | surfacePrimary / surfaceBrandSoft | #FFFFFF / #E9F2FF |
| `entry/src/main/ets/components/AccountListPage.ets` | :322 | surfaceSecondary | #F3F4F6 |
| `entry/src/main/ets/pages/Index.ets` | :2474 | surfacePrimary | #FFFFFF |
| `entry/src/main/ets/pages/Index.ets` | :2154 | **Color.White 硬编码** | — |
| `entry/src/main/ets/pages/ExpenseEdit.ets` | :648/656/708/763/1483 | surfaceSecondary / surfaceBrandSoft / surfacePrimary | #F3F4F6 / #E9F2FF / #FFFFFF |
| `entry/src/main/ets/components/AccountDetailDialog.ets` | :106 | **Color.White 硬编码** | — |

---

## 6. 汇总

- **深色切换**：✅ 成功（系统设置 → 显示和亮度 → 显示模式 → 深色）
- **验证页面**：9 个页面/交互，浅色全部 PASS，深色 5 个页面 PASS、4 个页面 FAIL
- **深色问题总数**：5 个独立问题（P1–P5）
- **受影响的页面**：账户页、交易页、新建交易页、交易操作弹层
- **核心根因（置信度从高到低）**：
  1. **dark/element/color.json 缺失 11 个 surface/icon/scrim 系列颜色键**（P1–P4 全部由此回退浅色，像素直方图与代码引用双重印证，置信度最高）
  2. **Index.ets:2154 / AccountDetailDialog.ets:106 硬编码 Color.White**（P5 及账户详情弹窗白底）
  3. **资源体系无系统性深色审计**：深色仅定义了少量颜色，未覆盖全量 UI 语义色（surface 系列全缺），属于资源层结构性缺失

## 7. 修复建议（仅供后续参考，本会话未改动代码）

1. 在 `dark/element/color.json` 补齐 11 个缺失键，建议值：
   - `surfacePrimary=#1C1C1E`、`surfaceSecondary=#2C2C2E`、`surfaceElevated=#2C2C2E`
   - `surfaceBrandSoft=#1E3A5F`、`surfaceIncomeSoft=#14361B`、`surfaceExpenseSoft=#3D1B1C`
   - `dividerSubtle=#1AFFFFFF`、`iconSecondary=#8A8A8E`、`scrimColor=#99000000`
   - `interactivePressed=#33FFFFFF`、`interactiveDisabled=#2EFFFFFF`
2. 将 `Index.ets:2154`、`AccountDetailDialog.ets:106` 的硬编码 `Color.White` 改为 `$r('app.color.surfaceElevated')`。
3. 补充审计：全文检索 `Color.White`、`Color.Black` 硬编码，统一迁移到资源引用。

---

*本报告仅记录与验证，未修改任何业务代码或资源；未执行任何 Git 操作。证据截图全部真实采集自模拟器 B。*
---

## 8. 修复结论（2026-08-16 主 Agent 修复后复测）

### 修复内容
1. **dark/element/color.json 补齐 11 个缺失键**：
   - surfacePrimary=#1C1C1E、surfaceSecondary=#2C2C2E、surfaceElevated=#2C2C2E
   - surfaceBrandSoft=#1E3A5F、surfaceIncomeSoft=#14361B、surfaceExpenseSoft=#3D1B1C
   - dividerSubtle=#1AFFFFFF、iconSecondary=#8A8A8E、scrimColor=#99000000
   - interactivePressed=#33FFFFFF、interactiveDisabled=#2EFFFFFF
2. **硬编码 Color.White 背景 → $r('app.color.surfaceElevated')**：
   - Index.ets:2154（交易操作弹层）
   - AccountDetailDialog.ets:106（账户详情弹窗）
   - ColorPickerDialog.ets:402 / SearchCriterionDialog.ets:427 / VoiceInputDialog.ets:189 / SortDialog.ets:106
3. 全局审计：`backgroundColor(Color.White/Black)` 清零

### 修复后复测（模拟器 B，深色 + 浅色）
| 页面 | 深色复测 | 浅色复测 |
|---|---|---|
| 账户页（账户卡片/累计卡片） | ✅ 深色系，无白块 | ✅ 白底正常 |
| 交易页（Total 卡/交易行/分组头） | ✅ 深色系，无白块 | ✅ 白底正常 |
| 新建交易页（表单/切换栏） | ✅ 深色系，无白块 | — |
| 交易操作弹层 | ✅ 深灰底，文字可读 | — |
| AI/模板/更多 | ✅ 维持正常 | — |

证据：`docs/testing/evidence/theme/fixed/`（dark_accounts_fix / dark_tx_fix / dark_newtx_fix / dark_txmenu_fix / light_accounts2 / light_tx_ok）

### 结论
- 深色 5 个问题（P1-P5）全部修复，复测无白块/亮卡片/硬编码白底
- 浅色模式无回归（账户页/交易页正常）
- 根因 A（dark 缺 11 键）与根因 B（硬编码 Color.White）均已解决
