# 项目状态

更新：2026-10-30（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务5b已按PM停止条件停在QB来源核对，未完成后续配置/perf/BPF核实。** 设计文档已移动入库；用户浏览器登录成功，QB1211696明确使用预期源码SHA且状态Successful，但页面`PROJECT_BRANCH=tizen`为项目级字段，未证明要求的包级sandbox分支。本轮不以SHA相同自行替代分支条件。浏览器已关闭、登录会话目录已删除；未下载RPM、未上板。

## 计划与进度

原计划：移动10设计文档 → 隔离有界面浏览器读取QB并下载devel/perf RPM → 来源/最终.config核对 → 一次性临时perf实测 → BPF源码/板上日志只读核实 → 09/10/RULES/STATUS/证据同commit推main。

- 步骤1完成：`~/Downloads/10_design_v1.md`移动到`docs/10_design_v1.md`，Downloads无副本，21,880 B、SHA256不变；未修改设计文本或开始优化实现。
- 步骤2部分完成：Google Chrome有界面窗口，用户自行登录；脚本检测到返回QB构建页，未超时。Overview与Variables均读到linux-rpi预期SHA，状态Successful，已有公开产物根链接。
- 停止原因：`PROJECT_BRANCH=tizen`，`PROJECT_NAME=Tizen-Unified-Toolchain`，`USE_BRANCH_POLICY=false`。它不能独立证明内核实际分支错误，但不满足本轮要求页面分支为`sandbox/lhmax2025/kernel_optimization`，也没有包级分支证据；遵照PM步骤2/3停止，不自行接受替代。
- 时间：QB页面Begin Date=2026-10-28 10:58:35，Duration=6:15:43，页面摘录未标时区；计算同一时区结束17:14:18。只有假设QB时间为UTC，才能得到内核版本时间在开始后1:19:50、结束前4:55:53；没有把条件计算当作时间闭合。
- 截图只留temp/task5b；其他变量行在截图前隐藏，未读取或记录凭据值。浏览器/下载/缓存/用户目录已删除，正常Browser.close退出0，没有操作其他浏览器进程。
- 未执行：RPM下载/解包、平台diffconfig、依赖库核对、板上perf、BPF trampoline及板上加载日志核实。此次没有SDB命令，未创建板上临时目录。
- 一次性perf授权已写入RULES，尚未使用；不能当作以后任务的永久授权。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| PM设计文档已移动，内容未改、Downloads不留副本 | [10设计文档](10_design_v1.md)、[移动记录](../evidence/task5b/design_move.txt) |
| QB1211696使用linux-rpi@0fac5de6a63091d141ad1cd3ed9d9e92b8dde708，状态Successful | [页面选段](../evidence/task5b/qb_1211696_page.txt) |
| 分支条件未通过，QB时间时区未核实，后续操作停止 | [停止判断](../evidence/task5b/provenance_gate.txt)、[09 A节及补充](09_board_rpi4_readonly.md) |
| 浏览器关闭、登录会话目录删除 | [清理记录](../evidence/task5b/browser_cleanup.txt) |
| 原始本地文本/截图哈希，截图不上传 | [清单](../evidence/task5b/local_manifest.tsv) |

## 需要人工裁决的前提

- 请PM裁决是否接受“QB明确按0fac5de6固定源码+已知sandbox该SHA”为包级来源证明，或提供QB包级sandbox分支记录。不能仅凭全局PROJECT_BRANCH=tizen就说内核源码错误，也不能忽略明确的停止条件。
- QB时间时区尚待明确；完整来源/最终.config核对尚未完成。后续恢复时，重新登录所需流程仍应保持会话隔离与清理。
- 硬件计数、分支采样、软件事件回退尚无任务5b结果；BPF是否实际尝试加载及失败原因也没有新证据，不猜测ENOTSUPP已经发生。
- 设计v1本轮原样入库；设计冻结前不开始实现，其历史“待闭合/未实测”内容保留为PM提交原文。

## 保留的任务5现场结论

2026-10-29三项身份断言通过，Clang22.1.8/LLD22.1.8、内核构建时间2026-10-28 12:18:25 UTC。板上没有/proc/config.gz及perf，模块build链接失效；当时的配置比较未完成。PMU驱动armv8_cortex_a72已绑定、报告7 counters，但没有实际perf硬件事件结果。[09](09_board_rpi4_readonly.md)、[任务5证据](../evidence/task5/README.md)。

BTF为6,478,350 B，resource-monitor-plugin-network有内嵌fentry/CO-RE静态依赖；当时FD/maps/pins未见运行证据，不能判断该插件是否曾经失败。tracefs开关开着但nop/events=0，F2FS在用，Btrfs/NFS无挂载，指定六个USB网卡/声卡驱动未绑定。MGLRU=0x0001；zram=lzo-rle、1,628,766,208 B，而resourced写zstd；实际CMA320MiB。旧板上目录/tmp/lko_task5已删、SDB已恢复owner。

任务5首次交付GitHub `34fccb5713bac3a3bbe61cd9aa1a788d6a9f1dce`；匿名QB访问限制补充为`d6d2c80ecebe083e57dc7f7bd44872e56be8bb51`。后者的“无法登录访问”已由本轮用户交互登录解决，但分支/时区/配置及实际perf/BPF测试仍未闭合。

## 内核基线与历史挂账

- Gerrit唯一授权目标`sandbox/lhmax2025/kernel_optimization`与本地lko/base为`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`，相对tizen@42aeefac为force_reclaim与PMU两提交；相对21645b17多4提交。四组合配置只ARM_PMUV3 n→y。[08](08_sandbox_baseline.md)。本轮未改内核树或推Gerrit。
- 任务2/3体积来自不含PMU的f240c280：普通LLVM常驻+2,669,604 B（8.11%）、RT+2,516,690 B（7.58%）。不是本次QB镜像体积。[06](06_static_footprint.md)、[07](07_llvm_text_growth.md)。
- 代码增长的六类独立贡献未分离；rpmdb归属不明；ARMv4t/CP15 TLS探测问题未修复。可选nm扫描只保留旧状态，不将旧快照当当前运行情况。
- 平台缺llvm-bolt/create_llvm_prof，ARM32 AutoFDO消费链未接入。任务2 GCC/LLVM墙钟58:44.70/36:50.38；ACTIME普通12→24B、RT24→32B，每GiB增3/2MiB。[03](03_baseline_build.md)、[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)。
- 产品BOM、现场调试取舍、网络监控插件需求及BTF替代、zstd回退执行链、CMA固件来源仍需后续核实；不由当前未使用直接推定可裁剪。

## 发布状态

本次停止收尾将09、10、RULES、STATUS及evidence/task5b在同一commit普通推送GitHub main，署名Hao Lin <hao.lin@samsung.com>，不改全局Git/认证配置。没有上传RPM、截图、浏览器会话或凭据。最终commit见本轮回复。
