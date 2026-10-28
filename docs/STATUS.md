# 项目状态

更新：2026-10-28（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务4完成：Gerrit `sandbox/lhmax2025/kernel_optimization` 已建立，远端及本地lko/base均为 `0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`。四组合配置仅ARM_PMUV3从n变y；原四份配置实际明确记录n，并非未输出。** 本轮没有完整内核/GBS构建、sudo或上板。

## 计划

本轮执行：补丁下载/hash核对 → git am及仅删指定正文句 → GCC/LLVM普通/RT配置检查 → 确认目标不存在后普通推送 → 08、旧报告基线标注与证据同commit推GitHub。以上完成。后续QB构建由用户执行，以sandbox构建作为新的A/B基线；本轮未启动QB。

## 进度

- PMU补丁SHA-256匹配620c35409023bfcf881cafb8a91c20d84a26d625e6d14dc8aba644a32a4ca55e，无冲突合入；相对f240c280只新增defconfig一行CONFIG_ARM_PMUV3=y。
- 仅删除指定跨项目报告引用句；其余正文、作者Hao Lin、作者日期、Signed-off-by、Change-Id保持。新提交0fac5de6a63091d141ad1cd3ed9d9e92b8dde708。
- 在各自GBS root中通过无sudo的bwrap namespace与平台qemu-arm运行merge_config.sh和make olddefconfig；复用既有Kconfig工具，无内核编译目标。四份diffconfig全部只有ARM_PMUV3 n→y。
- Gerrit目标推前不存在，普通push成功，推后SHA与lko/base逐字相同。唯一warning是既有f240c28标题>50字符，未改写提交。lko/base已跟踪origin/sandbox/lhmax2025/kernel_optimization，ahead/behind 0/0。
- tizen仍为42aeefac58edeb081aff440f0b60be71cbe49755，内核工作树干净；21645b17在本地且为祖先，额外4提交。
- 已在03/06/07说明旧体积来自未启用PMU的f240c280。RULES改为唯一授权sandbox，后续本地基线与其保持一致。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| 新sandbox及QB填写信息 | [08](08_sandbox_baseline.md)、[推前](../evidence/task4/sandbox_before.txt)、[推送](../evidence/task4/sandbox_push.txt)、[推后](../evidence/task4/sandbox_after.txt) |
| 相对42aeefac恰为force_reclaim+PMU两提交；PMU差异仅一行 | [提交和diff](../evidence/task4/commits_and_diff.txt)、[消息验证](../evidence/task4/message_verification.txt)、[补丁SHA](../evidence/task4/patch_verification.txt) |
| 四配置仅ARM_PMUV3 n→y，无其他差异 | [汇总/哈希](../evidence/task4/config_check_summary.txt)、[证据索引](../evidence/task4/README.md) |
| 无sudo平台配置生成、未编译内核 | [环境检查](../evidence/task4/no_sudo_environment_check.txt)、[GCC日志](../evidence/task4/generation_gcc_arm-rpi4.txt)、[LLVM日志](../evidence/task4/generation_llvm_arm-rpi4.txt) |
| 与21645b17相比4提交 | [log原文](../evidence/task4/board_baseline_commits.txt) |
| lko/base/远端一致、tizen不变、工作树干净 | [最终状态](../evidence/task4/final_kernel_state.txt) |

## 需要人工裁决的前提

- 当前没有待执行授权请求。用户QB构建应选择platform/kernel/linux-rpi、sandbox/lhmax2025/kernel_optimization、0fac5de6a63091d141ad1cd3ed9d9e92b8dde708；实际PMU驱动绑定和hardware perf events仍需后续上板核实。
- 任务3裁剪候选仍待产品BOM/分区/附件、现场诊断需求及Tizen CO-RE/typed BPF依赖确认；没有因为PMU合入而关闭其他功能。
- TLS探测的ARMv4t/CP15问题已定位但未修复；四配置只有PMU变化，未夹带探测/优化修正。

## 任务3回看与挂账

- 任务3文档与证据已在GitHub commit3f26e8d2f7806751034b4a15259edf39d9ae0a3c交付，任务4没有中断尚未完成的正式报告。两个可选nm -l扫描PID1636046/1636318在任务4收尾回看仍自然运行；未发信号，不用其未完成输出。正式目录统计采用已完成vmlinux.a数据，见[回看快照](../evidence/task4/task3_scan_followup.txt)。
- 任务3旧f240c280产物：普通LLVM常驻+2,669,604 B（8.11%）、RT+2,516,690 B（7.58%）；.debug_*非加载，.BTF计常驻；完整ELF文件缩小不能称为内存下降。详细四类大小、估算与限制保留在[06](06_static_footprint.md)，不当作新sandbox体积。
- 六类代码增长的独立贡献仍未因果分离；19.01%为四对象混合净增范围，11.34%为其外新增帧指针建立指令，余69.65%未分离。需要另行受控实验，见[07](07_llvm_text_growth.md)。
- rpmdb更新仍无法归属本次或其他构建，事后mtime不足以锁定写入者；未修改外部文件。
- 任务2遗留：buildroot磁盘只有普通权限下界；平台缺llvm-bolt/create_llvm_prof；ARM32 AutoFDO缺内核配置/Kbuild与采样转换消费链，CoreSight=n、perf无OpenCSD。PMU配置合入只补驱动选择，不代表这些前提已经全部具备。

## 保留的旧基线测量

任务2e028a072脚本运行ALL-END 2026-10-28T14:55:09+08:00 OK；GCC/Clang14.2.0/22.1.8，墙钟58:44.70/36:50.38。原4配置核对、01补全7符号；MGLRU启用，zram内建lzo-rle且MULTI_COMP/WRITEBACK/ACTIME=n。ACTIME布局普通12→24 B、RT24→32 B，每GiB增3/2 MiB；LZ4三补丁此前合入检查干净、临时分支已删。[03](03_baseline_build.md)、[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)。

## 发布状态

RULES、STATUS、08、03/06/07基线标注及evidence/task4同一GitHub提交，正常Git环境，以Hao Lin <hao.lin@samsung.com>署名普通push main。内核提交已独立普通推送唯一授权Gerrit sandbox；两仓库SHA不可混用。GitHub最终commit见本轮回复。[task4证据索引](../evidence/task4/README.md)。
