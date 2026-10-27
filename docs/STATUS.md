# 项目状态

更新：2026-10-27（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务2续二部分完成：步骤1源码核对、步骤2准备、步骤6不依赖产物的静态部分已完成；步骤3–5未执行。不是成功构建基线。**

## 计划

PM指定顺序：源码核对 → 工作区用户目录配置 → 指定HOME/GIT_CONFIG_NOSYSTEM的strace导出 → 串行GCC/LLVM与外部写入监测 → 产物核对；静态部分允许独立开展。PM已排除修改源码.gbs.conf/exclude及上轮两个替代工具/隔离方案，不再请求这些方案裁决。

## 进度

- PM裁决已原文置于RULES最前两条硬要求后，明确系统运行时例外和所有GBS必带两个环境变量。
- 源码核对：expanduser遵循HOME；无配置自动生成路径也遵循HOME；导出fork/exec链未发现重设两项环境；其他HOME路径逐项列出。该结论不替代strace文件访问证据，也不扩大到sudo/chroot全部后代。
- 步骤2完成：temp/gbs-home/.gbs.conf为指定两行普通文件。没有重设实际HOME，没有运行GBS。已受跟踪linux-rpi/.gbs.conf和exclude保持原样。
- 步骤3–5未执行：**当前代理执行环境禁止重设HOME**，不能执行PM命令，也不运行缺少该变量的GBS或变通绕过。这是执行限制，不是源码方案冲突或构建失败。
- 步骤6：zram接口已核对；ARM32普通无锁调试/4KiB页条件下ACTIME使表项12→24 B，每GiB增3 MiB；RT相同锁调试前提下24→32 B，每GiB增2 MiB。均为静态推导，非最终配置sizeof实测。
- LZ4三提交1051099cb8da、7b64cf4f1065、7459b2911b52依次cherry-pick均无冲突；lko/tmp-lz4已删除，未改base。两份字典脚本原文及zram源码片段已归档，未执行脚本。
- ARM32本树无LTO架构选择路径；AUTOFDO/PROPELLER及对应ARCH_SUPPORTS符号在Kconfig/Makefile无匹配；BCM2711有cortex-a72-pmu节点，主板递归include链未找到CoreSight组件节点；perf spec未显式传CORESIGHT=1/OpenCSD。
- 平台LLVM版本/BOLT后端、最终CORESIGHT*值未取得；未使用宿主工具替代。没有构建日志、外部写入监测结果或板上数据。
- 当前内核lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a，tizen@42aeefac58edeb081aff440f0b60be71cbe49755，工作树干净。未向Gerrit推送，未构建aarch64，未碰板或其他任务进程。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| HOME配置定位/环境继承及其他用户路径 | [home_source_audit.md](../evidence/task2/home_source_audit.md)、[源码行号](../evidence/task2/home_source_lines.txt)、[检索命令输出](../evidence/task2/home_source_search.txt) |
| 两行工作区配置已准备，源码配置保持原样 | [home_preparation.txt](../evidence/task2/home_preparation.txt) |
| zram接口、普通/RT布局条件及计算 | [04](04_zram_static.md)、[源码证据](../evidence/task2/static_source_lines.txt) |
| LZ4三提交干净合入，检查后删除临时分支 | [lz4_merge_check.txt](../evidence/task2/lz4_merge_check.txt) |
| 字典脚本全文与相关源码片段 | [快照索引](../code_snapshots/INDEX.md) |
| FDO符号缺失、PMU/CoreSight/perf静态状态 | [05](05_kernel_fdo_static.md)、[符号检索](../evidence/task2/fdo_symbol_search.txt)、[DTS扫描](../evidence/task2/bcm2711_dts_scan.txt) |
| 无平台LLVM工具版本证据 | [platform_tools_pending.txt](../evidence/task2/platform_tools_pending.txt) |

## 需要人工裁决的前提

PM关于HOME方案及保留源码配置的裁决已闭合，不再重复请求许可。恢复步骤3–5需要能够执行PM所指定HOME环境的执行端；当前代理受执行限制，不能通过用户重复批准解除，也不会另选已排除方案。对平台工具/硬件能力的缺口按05列项供后续设计评审，本任务未自行实施优化。

## 挂账事项

- 指定环境下strace的a/b/c全部路径及通过判定；当前没有运行，不填写虚构成功摘要。
- 两轮GCC/LLVM成功构建、进程组前后与残留等待、marker/find外部写入及无法归属项；无r2耗时/大小/监测结果。
- 实际编译器四类证据、是否确为Clang；四份最终.config和diffconfig；01改正符号数未知，不记为0。
- vmlinux/zImage差值、模块/符号/追踪段、bloat-o-meter、wall/RSS/buildroot/RPM大小。
- 元数据布局需用最终普通/RT配置核验；无锁调试前提变更则重新计算。
- 平台create_llvm_prof/llvm-profgen版本、llvm-bolt支持架构、最终CORESIGHT*配置；板上采样与性能另发任务。

历史结果保留：最初GCC尝试人为中断exit143、5:37.12，不是本轮构建耗时；残留已自行退出。SSH open0、近6个月merged17/相关12及重叠修订见02。base只改memcontrol，后仅改标题，历史证据不重写。

## 发布状态

本次文件与STATUS已在本地同一提交；普通git push origin main失败，退出128：禁用系统及工作区外全局Git配置后，无可用GitHub认证（交互提示已禁用）。未索要密码、未恢复外部配置、未绕过认证或force push，见[发布记录](../evidence/task2/publication_home_attempt.txt)。远端main/raw链接尚未更新，本轮交付以工作区文件及本地commit为准。发布还需要工作区规则允许的认证来源；当前没有该来源的证据。

交付索引：[evidence/task2/README.md](../evidence/task2/README.md)。
