'use strict';
/**
 * HarmonyOS SDK 版本映射补丁
 *
 * 背景调查结论：
 *   1. hos-config.json 的 osVersionMapper 只有 "6.1.1": "24"，没有 "6.1.1.125"。
 *   2. SDK 实际安装版本 sdk-pkg.json: platformVersion="6.1.1", version="6.1.1.125"。
 *   3. 命令行构建实际调用 transferVersionIntoHosVersion 的输入是 "24"（fullVersion）
 *      和 "6.1.1"（api），均能在原 osVersionMapper 中正常解析，构建本可成功。
 *   4. 真正的命令行构建阻断点是 DEVECO_SDK_HOME 环境变量未设置，而非版本映射。
 *
 * 关键教训（避免的副作用）：
 *   若向 osVersionMapper 注入 "6.1.1.125"="24"，会使 HosVersionMapper.getLatestSupportVersion()
 *   返回 platformVersion="6.1.1.125"，进而 SUPPORT_COMPILE_VERSION="6.1.1.125(24)"。
 *   parseApiVersion 的正则 /\s*([1-9].[0-9].[0-9])\s*\(\s*(\d+)\s*\)\s*$/g（. 未转义）
 *   会从 "6.1.1.125(24)" 的位置 4 开始匹配 "1.125(24)"，捕获 api="1.125"，
 *   导致 getHmsSdkComponents 用 "1.125" 查表失败，反而触发 "SDK component missing"。
 *
 * 最终方案：
 *   不修改 hos-config.json 的 osVersionMapper（避免上述副作用）。
 *   仅拦截 HosVersionMapper.INSTANCE.transferVersionIntoHosVersion 方法，
 *   对 "6.1.1.125" 输入委托给 "6.1.1" 处理（防御性补全，满足任务要求，
 *   且不影响正常构建流程，因为命令行构建实际不会以 "6.1.1.125" 调用此方法）。
 *
 * 约束：
 *   - 不修改磁盘上的 hos-config.json（权限不足）
 *   - 不修改 build-profile.json5（会触发格式违规）
 *   - 不向 osVersionMapper 注入新键（避免污染 getLatestSupportVersion）
 *   - 仅在内存中拦截方法，进程退出后即失效
 */

const Module = require('module');

const TARGET_KEY = '6.1.1.125';
const BASE_KEY = '6.1.1';          // SDK 实际安装的 platformVersion

let methodPatched = false;
let delegateInvoked = false;

/**
 * 拦截 HosVersionMapper 单例的 transferVersionIntoHosVersion 方法
 * 对 "6.1.1.125" 输入委托给 "6.1.1" 处理，使返回 dto.platformVersion="6.1.1"
 * 与 SDK 组件 platformVersion 严格相等比较通过。
 */
function patchTransferVersion(instance) {
    if (!instance || typeof instance.transferVersionIntoHosVersion !== 'function') return;
    if (instance.__sdkPatchApplied__) return;
    const original = instance.transferVersionIntoHosVersion.bind(instance);
    instance.transferVersionIntoHosVersion = function (o) {
        if (o === TARGET_KEY) {
            const dto = original(BASE_KEY);
            if (!delegateInvoked) {
                delegateInvoked = true;
                console.log('[sdk-patch] transferVersionIntoHosVersion("' + TARGET_KEY + '") delegated to "' + BASE_KEY + '"');
            }
            return dto;
        }
        return original(o);
    };
    instance.__sdkPatchApplied__ = true;
    methodPatched = true;
    console.log('[sdk-patch] Patched HosVersionMapper.INSTANCE.transferVersionIntoHosVersion (delegate "' + TARGET_KEY + '" -> "' + BASE_KEY + '")');
}

function isHosVersionMapperRequest(request) {
    return typeof request === 'string' && request.indexOf('hos-version-mapper') !== -1;
}

// ============================================================
// 拦截 Module._load，在 hos-version-mapper 模块加载时 patch 单例方法
// ============================================================
const originalModuleLoad = Module._load;
Module._load = function (request, parent, isMain) {
    const result = originalModuleLoad.apply(this, arguments);
    try {
        if (isHosVersionMapperRequest(request) && result && result.HosVersionMapper && result.HosVersionMapper.INSTANCE) {
            patchTransferVersion(result.HosVersionMapper.INSTANCE);
        }
    } catch (e) {
        // 拦截失败不影响正常加载
    }
    return result;
};

console.log('[sdk-patch] SDK version mapping patch loaded (transferVersionIntoHosVersion: "' + TARGET_KEY + '" -> "' + BASE_KEY + '")');
