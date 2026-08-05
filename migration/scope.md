# Migration Scope

- Android source: /Users/rainyday/Desktop/migration/MyExpenses
- Blank ArkUI template: /Users/rainyday/Desktop/migration/.codeartsdoer/skills/android-to-arkui-full-migration/assets/arkui-stage-template
- New ArkUI target: /Users/rainyday/Desktop/migration/arkts
- Forbidden source roots: (none)
- Current status: SCAFFOLDED

## 本期验收范围（用户确认）

- 范围：**全量功能迁移**（MyExpenses 核心功能），**不含云同步**（WebDAV / Dropbox / OneDrive / 泛云同步），云同步相关页面与后台任务不在本期验收。
- 新增：**AI 功能**（用户明确要求开发，功能定义见 `code-mapping.md` 与后续切片）。
- 语言：**仅中文（zh-CN）**，不迁移其他 90+ 语言资源。
- 主题：浅色 + 深色（Android 有 `values-night`）。
- 方向：Android 源含 `layout-land`，支持横屏；未豁免页面要求 PORTRAIT + LANDSCAPE 双证据。
- 设备规格：目标手机（HarmonyOS 真机），模拟器仅用于开发阶段验收。
- 完成定义：全量核心功能迁移 + 1:1 UI 对齐 + AI 功能 + 真实测试/GUI/真机证据 + 独立审查。

## 分阶段项（不在本期验收范围）

- 云同步（WebDAV / Dropbox / OneDrive / 同步后端管理）。
- 系统小部件（AccountWidget / TemplateWidget / BudgetWidget）。
- OCR 识别、Tesseract、ML Kit。
- 日历集成、桌面快捷方式。
- 广告与贡献许可（Contrib 内购体系）。

## 验收门槛

- `verify_migration_gates.py --gate Complete` 通过（含 strict-pixels）。
- P0/P1/P2 问题全部 VERIFIED。
- 真机矩阵 PHYSiCAL_DEVICE 记录齐全。
