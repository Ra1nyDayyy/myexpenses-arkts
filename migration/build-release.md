# 构建与发布

## 构建环境
- 系统：macOS 15.7.7 (arm64)
- DevEco Studio：/Applications/DevEco-Studio.app (6.1)
- SDK：/Applications/DevEco-Studio.app/Contents/sdk（template targetSdk 6.1.1(24)）
- Java：OpenJDK 21.0.8
- Hvigor：/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw

## Debug 构建
- 命令：`hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon`
- 结果：BUILD SUCCESSFUL
- 产物：entry/build/default/outputs/default/entry-default-unsigned.hap（774,363 字节，unsigned）
- 证据：migration/evidence/build/scaffold-build.txt（Scaffold 门禁构建日志）

## Release / 签名 HAP
- 状态：**待完成（阻塞）**
- 原因：当前无签名配置（build-profile.json5 signingConfigs 为空），未生成签名 Release HAP 与 SHA-256
- 前置：需用户在 DevEco Studio 配置签名（自动签名或提供 .p12/.cer/.p7b 证书）后构建 release

## 安装验证
- 模拟器：emulator 6.1.0.125
- `hdc install -r entry-default-unsigned.hap` → install bundle successfully
- `hdc shell aa start -a EntryAbility -b org.totschnig.myexpenses` → start ability successfully
- 进程：org.totschnig.myexpenses PID 稳定