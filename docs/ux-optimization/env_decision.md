# env_decision.md — M0 环境决策与模拟器隔离清单

> 生成时间: 2026-08-18T03:52+08:00 | 完成时间: 2026-08-18T04:06+08:00
> 依据: Runbook Part 2.3（模拟器隔离 P0 硬约束）/ Part 3.7（资源治理）
> 状态: M0 完成

## 1. 禁用实例清单（forbiddenInstances）— 全程不得连接/操作/读写

> 枚举命令: `$EMU -list -details` + `$HDC list targets`
> 枚举时间: 2026-08-18T03:51+08:00

| 实例名 | 类型 | API | 运行中 | 在线端口 | 禁用原因 |
|---|---|---|---|---|---|
| Mate X7 | foldable | 24 | 是 | 5555/5557/5559 之一 | 其他项目在用 |
| Pura 90 | phone | 24 | 是 | 5555/5557/5559 之一 | 其他项目在用 |
| Pura 90 test | phone | 24 | 是 | 5555/5557/5559 之一 | 其他项目在用 |
| MateBook Pro | 2in1 | 24 | 否 | — | 其他项目实例 |
| MatePad Pro 13 | tablet | 24 | 否 | — | 其他项目实例 |

**禁用端口集合**: {5555, 5557, 5559, 15558}

## 2. 设备方案决策

- 总内存: 32 GB | 可用内存(free+inactive+spec): ≈ 9.9 GB（2026-08-18T03:52 实测）
- **决策: TIME_SLICE**（单专用实例，Simulator 按分片排队，前台令牌串行）
- 理由: 可用 9.9 GB < 16 GB 阈值；本机已有 3 个实例运行，内存紧张

## 3. 专用实例（dedicatedInstance）— 本任务唯一可用

```json
"dedicatedInstance": {
  "name": "MyExpensesUX_20260818",
  "type": "phone",
  "api": 24,
  "osVersion": "HarmonyOS 6.1.1(24)",
  "port": 16555,
  "connectKey": "127.0.0.1:16555",
  "createCmd": "$EMU -create MyExpensesUX_20260818 -deviceType phone -osVersion 'HarmonyOS 6.1.1(24)'",
  "startCmd": "$EMU -start MyExpensesUX_20260818 -hdcPort 16555",
  "createdAt": "2026-08-18T03:54+08:00",
  "onlineAt": "2026-08-18T03:55+08:00"
}
```

端口避让确认: 16555 ∉ {5555,5557,5559,15558}，nc 探测 FREE，在 hdc 端口范围 10000~16555 内。
**所有设备命令必须使用 `-t 127.0.0.1:16555`**。

## 4. 隔离确认项（confirmations）— 全部已勾选

- [x] 已枚举全部既有实例并记录到 forbiddenInstances（5 个实例）
- [x] 已创建专用实例且端口无冲突（MyExpensesUX_20260818:16555）
- [x] 已用 -t 127.0.0.1:16555 指定专用端口完成首次连接
- [x] 未触碰任何禁用实例（全程所有设备命令带 -t 127.0.0.1:16555）

## 5. 探针结果

### 5.1 输入探针（M0 步骤 5）
- 路径: AccountEdit → 点击账户名称 TextInput → uiInput text '测试账户'
- 前置: 首次使用需启用"小艺输入法"（同意声明 → 选择26键布局 → 选择经典布局 → 完成）
- 结果: ✅ 中文输入成功，TextInput text="测试账户"
- 命令: `$HDC -t 127.0.0.1:16555 shell uitest uiInput text '<中文>'`（需先 click 聚焦）
- 证据: evidence/m0/input_probe3_dump.json

### 5.2 深色探针（M0 步骤 6）
- 路径: 应用内 Settings → 界面 → 主题 → 深色（非系统 settings 命令，`settings` 命令不存在）
- `param set persist.ace.dark.mode 1` 无效（非正确参数）
- 正确方式: 应用内主题设置（跟随系统/浅色/深色三选一）
- 切换后需重启应用才生效
- 浅色背景: #FFFAF8FE | 深色背景: #FF121212
- 结果: ✅ 深色可通过应用内设置切换，重启后生效
- 证据: evidence/m0/probe_dark_home.jpeg, probe_light_final_dump.json

### 5.3 DB 路径探针（M0 步骤 7）
- 当前空态（无账户），files/preferences 目录无 .db 文件
- haps/entry 目录: cache, files, preferences, temp（无 database 目录）
- 结论: 数据库将在创建账户/交易后生成；HarmonyOS relationalStore 默认存储路径待数据创建后精确定位
- 证据: evidence/m0/（空态）

### 5.4 构建（M0 步骤 4）
- 构建命令: `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon`
- 产物: entry/build/default/outputs/default/entry-default-unsigned.hap
- 大小: 3,177,315 bytes (3.18 MB)
- sha256: 2719e53ebc8c65865cbe7dc87d005dc0b9ab1c9d2da4a96af28f40ff5318e284
- 构建耗时: 6.775s
- 警告: showToast/showDialog/back 弃用警告（不影响功能）；debug 签名跳过（符合预期）

## 6. 设备交互命令格式（已验证）

| 操作 | 正确命令 |
|---|---|
| 点击 | `$HDC -t 127.0.0.1:16555 shell uitest uiInput click <x> <y>` |
| 滑动 | `$HDC -t 127.0.0.1:16555 shell uitest uiInput swipe <x1> <y1> <x2> <y2>` |
| 输入文本 | `$HDC -t 127.0.0.1:16555 shell uitest uiInput text '<文本>'`（需先 click 聚焦） |
| 返回键 | `$HDC -t 127.0.0.1:16555 shell uitest uiInput keyEvent Back` |
| dumpLayout | `$HDC -t 127.0.0.1:16555 shell uitest dumpLayout -p /data/local/tmp/<name>.json` |
| 截图 | `$HDC -t 127.0.0.1:16555 shell uitest screenCap -p /data/local/tmp/<name>.jpeg` |
| 拉回文件 | `$HDC -t 127.0.0.1:16555 file recv <dev_path> <local_path>` |
| 安装 | `$HDC -t 127.0.0.1:16555 install -r <hap>` |
| 启动 | `$HDC -t 127.0.0.1:16555 shell aa start -a EntryAbility -b org.totschnig.myexpenses` |

## 7. 首页控件坐标（空态，1256×2760，会随状态变化需重新 dump）

- 新建账户按钮: [439,1697][818,1865] → 中心(628,1781)
- 底部 Tab: 账户[0-251] | 交易[251-502] | AI[502-754] | 模板[754-1005] | 更多[1005-1256]，y≈2439-2662
- 更多菜单: 预算编制/交易对手债务/设置
