# 项目状态

更新：2026-10-30（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务5b续：来源与最终配置已闭合；BPF源码/板上只读核实已完成；perf功能实测因获准目录`/tmp`挂载noexec而未完成。** perf version即Permission denied、退出126，未继续stat/record/evlist，不能给出硬件计数或分支采样能力结论。板上本轮临时目录已删除并确认；未改挂载、sysctl/sysfs、服务或BPF状态。

## 计划与进度

本轮计划：记录PM来源裁决 → 只读远端分支contains佐证 → 指定公开目录获取两个RPM → 平台最终.config比较 → 一次性perf尝试与BPF只读核实 → 更新09/RULES/STATUS和文本证据，同commit推main。

- 设计文档10前轮已从Downloads移动入库，本轮保持原字节，21,880 B、SHA256 `80ecded8314071d8781c7329b37210613d8c788e819fba9a13c6d76c25909249`；未开始设计实现。
- **PM裁决已接受**：QB1211696的BUILD_PKG_LIST明确为`platform/kernel/linux-rpi@0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`，SHA唯一确定源码内容，不再要求包级分支字段。PROJECT_BRANCH=tizen是Tizen-Unified-Toolchain项目级变量，USE_BRANCH_POLICY=false；产物目录与板上BUILD_ID一致。
- QB开始10月28日10:58:35，时长6:15:43，推算结束17:14:18；**按PM要求将开始时间理解为UTC，这是推断，页面未明示时区**。内核12:18:25 UTC在开始后1:19:50、结束前4:55:53，落在该时间窗内。
- `git branch -r --contains 0fac5de6…`只返回`origin/sandbox/lhmax2025/kernel_optimization`。结论范围为本地已获取的远端跟踪refs，本轮没有fetch、改源码或推Gerrit。
- 没有再次登录QB。仅从指定公开根的`repos/standard/packages/armv7l/`下载devel/perf RPM（115,630,580 / 1,109,156 B），URL、大小、SHA256均留证。两个RPM未安装，RPM/CPIO/ELF仅留temp；RPM BUILDTIME均为epoch0，不能用于实际时间证明。
- 用LLVM GBS root的平台rpm2cpio/readelf/rpm/Python经qemu-arm分析；平台scripts/diffconfig退出0且无输出。devel包arm-rpi4最终.config与任务4LLVM普通版全文相同，194,980 B、SHA256均为`62e3b8512d8bd4a336410a9468afd8c1ed338b9030dc69c754dbccf888617ba5`。
- 板上三项身份断言通过，BUILD_ID与/proc/version复核一致。perf的16项DT_NEEDED中仅缺libLLVM.so.22.1；只推perf及工作区既有LLVM GBS root的该库，共34,480,560 B，板上哈希一致、du33,676 KiB。
- perf version执行失败126；只读确认`tmpfs /tmp tmpfs rw,nosuid,nodev,noexec 0 0`，没有进一步运行perf事件命令。清理后两次确认目录不存在。SDB进入时已uid0，本轮不切换root状态；paranoid=2、bpf_jit_enable=0均未修改。
- BPF：ARM32缺少trampoline实现，正常前置条件下挂载先从弱size实现返回-ENOTSUPP(524)；libbpf错误传播已核对。当前未发现resource-monitor进程或插件映射；dlog命中仅SDB命令回显，journal仅一般systemd提示。**是否曾尝试加载、是否失败、实际失败原因均无法判断**，未启动服务或手动加载BPF。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| PM来源裁决覆盖此前包级分支停止条件；时间UTC解释明确标推断 | [裁决及时间差](../evidence/task5b/pm_adjudication_20261030.txt)、[QB页面](../evidence/task5b/qb_1211696_page.txt)、[09 A节](09_board_rpi4_readonly.md) |
| 本地已获取远端跟踪分支中只有授权sandbox包含0fac5de6 | [contains原文](../evidence/task5b/remote_contains_0fac5de6.txt) |
| 指定公开来源两包已下载，最终配置无差异且字节一致 | [RPM清单](../evidence/task5b/rpm_manifest.json)、[配置摘要](../evidence/task5b/config_comparison_summary.txt)、[平台diffconfig](../evidence/task5b/final_config_diff.txt) |
| perf可执行入口被/tmp noexec阻塞，未获得硬件事件结果 | [version原文](../evidence/task5b/11_perf_version.transport.txt)、[挂载证据](../evidence/task5b/18_exec_restriction.transport.txt)、[尝试摘要](../evidence/task5b/perf_attempt_summary.txt) |
| 板上临时目录已删除，paranoid/JIT未变，保留开始/结束进程快照 | [清理记录](../evidence/task5b/17_cleanup_end.transport.txt)、[全部SDB命令](../evidence/task5b/board_commands.jsonl) |
| ARM32 trampoline静态缺口与“插件实际失败未知”分别有证据 | [源码错误链](../evidence/task5b/bpf_source_error_chain.txt)、[运行摘要](../evidence/task5b/bpf_runtime_summary.txt) |
| 设计10原文不变；前轮浏览器登录会话已清理，本轮无浏览器 | [设计](10_design_v1.md)、[移动记录](../evidence/task5b/design_move.txt)、[历史浏览器清理](../evidence/task5b/browser_cleanup.txt) |

## 需要人工裁决的前提与挂账

- **perf实测未闭合**：本次唯一授权执行位置/tmp/lko_task5b所在挂载noexec；现有规则禁止remount和根文件系统写入。恢复需要PM明确可执行临时位置或镜像内置perf方案，不能自行改变边界。硬件计数是否type=0、-b是否可用、是否软件回退均仍待实测。
- BPF插件没有实际load/attach日志；历史尝试/失败与原因无法判断。是否需要后续受控触发由PM决定，本次不触发；静态架构缺口不能自动视为删除BTF的产品批准。
- QB页面时区没有独立证明；来源已按PM指定的UTC推断接受，不再作为来源停止条件。
- 设计v1原样保存，其历史“待闭合/未实测”描述保留为PM提交原文；当前执行状态以09与本文件为准。

## 保留的任务5现场结论

2026-10-29三项身份断言通过，Clang22.1.8/LLD22.1.8、内核构建时间2026-10-28 12:18:25 UTC。板上没有/proc/config.gz及perf，模块build链接失效；最终配置本轮已通过QB devel包闭合。PMU驱动armv8_cortex_a72已绑定、报告7 counters，仍无本任务实际perf硬件事件结果。[09](09_board_rpi4_readonly.md)、[任务5证据](../evidence/task5/README.md)。

BTF为6,478,350 B，resource-monitor-plugin-network有内嵌fentry/CO-RE静态依赖；没有插件运行/失败证据。tracefs开关开着但nop/events=0，F2FS在用，Btrfs/NFS无挂载，指定六个USB网卡/声卡驱动未绑定。MGLRU=0x0001；zram=lzo-rle、1,628,766,208 B，而resourced写zstd；实际CMA320MiB。这些项目未在本轮重复测量。任务5旧/tmp/lko_task5已清理，当轮SDB恢复owner；本轮开始时已为root，保持该状态。

任务5首次交付`34fccb5713bac3a3bbe61cd9aa1a788d6a9f1dce`；匿名QB限制记录`d6d2c80ecebe083e57dc7f7bd44872e56be8bb51`；任务5b首次分支停止与设计入库为`c8847a8856768bcc3be525dbca98f1ff728182db`。旧停止原始证据保留，已由本轮PM裁决和新配置证据覆盖，不再表示当前待办。

## 内核基线与历史挂账

- Gerrit唯一授权目标`sandbox/lhmax2025/kernel_optimization`与本地lko/base为`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`，相对tizen@42aeefac为force_reclaim与PMU两提交；相对21645b17多4提交。四组合配置只ARM_PMUV3 n→y。[08](08_sandbox_baseline.md)。本轮未改内核树或推Gerrit。
- 任务2/3体积来自不含PMU的f240c280：普通LLVM常驻+2,669,604 B（8.11%）、RT+2,516,690 B（7.58%）。不是本次QB镜像体积。[06](06_static_footprint.md)、[07](07_llvm_text_growth.md)。
- 代码增长的六类独立贡献未分离；rpmdb归属不明；ARMv4t/CP15 TLS探测问题未修复。可选nm扫描只保留旧状态，不将旧快照当当前运行情况。
- 平台缺llvm-bolt/create_llvm_prof，ARM32 AutoFDO消费链未接入。任务2 GCC/LLVM墙钟58:44.70/36:50.38；ACTIME普通12→24B、RT24→32B，每GiB增3/2MiB。[03](03_baseline_build.md)、[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)。
- 产品BOM、现场调试取舍、网络监控插件需求及BTF替代、zstd回退执行链、CMA固件来源仍需后续核实；不由当前未使用直接推定可裁剪。

## 发布状态

本次将09、RULES、STATUS与evidence/task5b在同一commit普通推送GitHub main，署名Hao Lin <hao.lin@samsung.com>，沿用现有认证。设计10已在此前提交入库，本次不修改。没有上传RPM、CPIO、ELF、截图、浏览器会话或凭据。最终commit见本轮回复；perf功能验证明确保留未完成。
