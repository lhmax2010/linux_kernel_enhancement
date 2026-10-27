# 项目状态

更新：2026-10-27（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务2续五：已核对GBP配置来源、归档上次export审计失败现场并修正用户脚本；/dev/null例外裁决已落实，等待用户重跑。新脚本仅做bash -n，不由代理运行。**

## 当前交付

- /dev/null精确例外已按PM裁决加入RULES与脚本；单列次数/首次行号并标注“按 PM 裁决放行”。本轮仅bash -n，未运行脚本或重放审计函数。

- 上次用户启动脚本commit 24707cad，export命令exit=0，但路径审计exit=91，2026-10-27 18:01:43 ALL-END FAILED at export；GCC/LLVM均未启动。旧进程组148694/148705已无存活进程；未重试、未发信号。
- GBP_CONF_FILES非空列表完全替换系统/用户/项目默认列表，静态确认通过GBS→depanneur→export→GBP库继承。[来源与有效设置](../evidence/task2/gbp_audit.md)、[源码行号](../evidence/task2/gbp_source_lines.txt)。系统gbp.conf的两个远端模板设置不进入此次导出配置。
- 已创建temp/gbs-home/.gbp.conf一行注释文件；脚本三个阶段传入三个隔离变量，预检注释配置，审计增加gbp.conf分类、外部标志检查和逐路径放行理由。用户实际重跑结果尚未取得。
- 上次运行12项完整移入temp/attempt_20261027_1801，保留锁，未删除。[移动清单](../evidence/task2/attempt_1801_archive.txt)、[审计统计/Issues/完整日志校验值](../evidence/task2/export_attempt_1801_summary.txt)。
- 全trace中外部成功写标志打开为101次/dev/null O_RDWR；其他路径为0。/tmp与/var/tmp只读目录打开，所有5798个成功mkdir在WS。[trace核对](../evidence/task2/export_trace_open_analysis.txt)、[NSS候选调用来源与局限](03_baseline_build.md)。

## 计划

PM指定顺序：源码核对 → 工作区用户目录配置 → 指定HOME/GIT_CONFIG_NOSYSTEM/GBP_CONF_FILES的strace导出 → 串行GCC/LLVM与外部写入监测 → 产物核对；静态部分允许独立开展。PM已排除修改源码.gbs.conf/exclude及上轮两个替代工具/隔离方案，不再请求这些方案裁决。

## 进度

- PM裁决已原文置于RULES最前两条硬要求后，明确系统运行时例外和所有GBS必带三个环境变量。
- 源码核对：expanduser遵循HOME；无配置自动生成路径也遵循HOME；导出fork/exec链未发现重设两项环境；其他HOME路径逐项列出。该结论不替代strace文件访问证据，也不扩大到sudo/chroot全部后代。
- 步骤2完成：temp/gbs-home/.gbs.conf为指定两行普通文件。没有重设实际HOME，没有运行GBS。已受跟踪linux-rpi/.gbs.conf和exclude保持原样。
- 步骤3由用户运行，导出成功但审计失败，已保存现场并准备修正脚本；步骤4–5构建/产物核对未开展。脚本仍只由用户执行。
- 步骤6：zram接口已核对；ARM32普通无锁调试/4KiB页条件下ACTIME使表项12→24 B，每GiB增3 MiB；RT相同锁调试前提下24→32 B，每GiB增2 MiB。均为静态推导，非最终配置sizeof实测。
- LZ4三提交1051099cb8da、7b64cf4f1065、7459b2911b52依次cherry-pick均无冲突；lko/tmp-lz4已删除，未改base。两份字典脚本原文及zram源码片段已归档，未执行脚本。
- ARM32本树无LTO架构选择路径；AUTOFDO/PROPELLER及对应ARCH_SUPPORTS符号在Kconfig/Makefile无匹配；BCM2711有cortex-a72-pmu节点，主板递归include链未找到CoreSight组件节点；perf spec未显式传CORESIGHT=1/OpenCSD。
- 平台LLVM版本/BOLT后端、最终CORESIGHT*值未取得；未使用宿主工具替代。本次尚无GCC/LLVM构建日志、构建前后find结果或板上数据；已有导出trace证据。
- 当前内核lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a，tizen@42aeefac58edeb081aff440f0b60be71cbe49755，工作树干净。未向Gerrit推送，未构建aarch64，未碰板或其他任务进程。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| GBP配置隔离、上次导出失败归因及归档 | [GBP核对](../evidence/task2/gbp_audit.md)、[上次摘要](../evidence/task2/export_attempt_1801_summary.txt)、[移动清单](../evidence/task2/attempt_1801_archive.txt) |
| HOME配置定位/环境继承及其他用户路径 | [home_source_audit.md](../evidence/task2/home_source_audit.md)、[源码行号](../evidence/task2/home_source_lines.txt)、[检索命令输出](../evidence/task2/home_source_search.txt) |
| 两行工作区配置已准备，源码配置保持原样 | [home_preparation.txt](../evidence/task2/home_preparation.txt) |
| zram接口、普通/RT布局条件及计算 | [04](04_zram_static.md)、[源码证据](../evidence/task2/static_source_lines.txt) |
| LZ4三提交干净合入，检查后删除临时分支 | [lz4_merge_check.txt](../evidence/task2/lz4_merge_check.txt) |
| 字典脚本全文与相关源码片段 | [快照索引](../code_snapshots/INDEX.md) |
| FDO符号缺失、PMU/CoreSight/perf静态状态 | [05](05_kernel_fdo_static.md)、[符号检索](../evidence/task2/fdo_symbol_search.txt)、[DTS扫描](../evidence/task2/bcm2711_dts_scan.txt) |
| 无平台LLVM工具版本证据 | [platform_tools_pending.txt](../evidence/task2/platform_tools_pending.txt) |

## 需要人工裁决的前提

无新增待裁决规则。PM已明确仅放行strace -yy返回路径精确为/dev/null且设备标注为字符设备1:3的带写标志成功打开；已落实精确匹配、计数和首次trace起始行号摘要，其他工作区外路径仍拒绝。[脚本与bash -n证据](../evidence/task2/script_static_validation_null_exception.txt)。

用户重跑后继续任务2续四只读监控，成功后完成产物核对；发生异常停下报告。当前新脚本只有静态语法检查，不能宣称新导出审计已通过。

## 挂账事项

- 新三变量环境下导出a/b/c审计是否通过；上次失败原因与完整trace已有证据，不能冒充新运行成功。
- 两轮GCC/LLVM成功构建、进程组前后与残留等待、marker/find外部写入及无法归属项；无r2耗时/大小/监测结果。
- 实际编译器四类证据、是否确为Clang；四份最终.config和diffconfig；01改正符号数未知，不记为0。
- vmlinux/zImage差值、模块/符号/追踪段、bloat-o-meter、wall/RSS/buildroot/RPM大小。
- 元数据布局需用最终普通/RT配置核验；无锁调试前提变更则重新计算。
- 平台create_llvm_prof/llvm-profgen版本、llvm-bolt支持架构、最终CORESIGHT*配置；板上采样与性能另发任务。

历史结果保留：最初GCC尝试人为中断exit143、5:37.12，不是本轮构建耗时；残留已自行退出。SSH open0、近6个月merged17/相关12及重叠修订见02。base只改memcontrol，后仅改标题，历史证据不重写。

## 发布状态

前轮禁用外部Git配置导致的认证失败已由PM裁决解除：隔离变量仅用于GBS及其后代，成果仓库commit/push使用正常环境的已有GitHub认证。普通push已成功补发旧成果。本轮续五脚本、03、RULES、STATUS及证据同一提交普通推送main；最终commit见交付回复。旧publication_home_attempt.txt保留作历史证据。

交付索引：[evidence/task2/README.md](../evidence/task2/README.md)。
