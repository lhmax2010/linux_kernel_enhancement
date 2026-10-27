# 项目状态

更新：2026-10-27（Asia/Shanghai）。新Session先读本文件和 [RULES.md](RULES.md)。

**任务2未完成：步骤4已中止，未启动LLVM；本次提交是阶段性交付，不是成功构建基线。**

## 计划

PM任务2顺序：建立lko/base → SSH查询与02修订 → 串行armv7l GCC/LLVM构建 → 实际编译器及最终.config → 体积/开销 → zram静态准备与LZ4合入检查 → AutoFDO/BOLT静态前提。遇构建失败或凭据要求停止，保留证据；本次触发停止条件，后续执行待PM决定。

## 进度

- 步骤1完成：lko/base@563c53c427bff4d685d18544a8f4f6db14be9368，来自tizen@42aeefac58ed；只拆入a9cc39b8dd1d的mm/memcontrol-v1.c（+22/-7），保留He Fangyu作者、Hao Lin提交者；完整diff与函数前后各20行快照已保存。
- 步骤2完成：SSH open=0、merged -age:6mon=17，其中相关12条；moreChanges=false，无需翻页。完整JSONL在temp/，文本摘要在evidence/task2/。
- 步骤3完成：silent-reclaim-fix归属明确、memcontrol已拆入、zram由本项目另评估；MLGO是用户本人分支、不重叠；cache-ext不重叠、不再跟踪；补充85fcc6edce0b删除DEBUG_INFO_BTF。
- 步骤4中止：GCC主命令2026-10-27 14:14:17开始、14:19:54退出143；time墙钟5:37.12，是失败尝试耗时，不是完整内核编译耗时。LLVM未启动。
- 步骤5–9未执行：未取得vmlinux/zImage/最终.config，无编译器、体积差、符号修正数、actime开销、LZ4合入、AutoFDO/BOLT能力结论。03记录失败；04/05只记录未完成范围。
- linux-rpi当前在lko/base且干净，tizen保持原SHA；没有向Gerrit推送，未建lko/tmp-lz4，未构建aarch64，未触碰开发板。

## 中止原因与当前残留状态

1. 虽已export TMPDIR且在两个项目conf显式配置tmpdir=$WS/temp，depanneur嵌套调用gbs export没有传递-c；源码导出仍写到 `/var/tmp/.gbs_export_4d01tubn/linux-kernel-6.12.80.tar.xz`。**本次发生过目录越界，不声称全程合规。** 检测后立即发送SIGINT；后台进程未及时退出，随后以SIGTERM终止主命令与可控子进程。未修改spec、内核代码或已安装GBS工具进行重试。
2. 在终止期间GBS进入root依赖初始化。残留root进程普通kill无权限；仅一次非交互清理sudo -n返回“a password is required”，此后停止全部sudo尝试，不索要密码、不绕过凭据。
3. 后续只读复查：2026-10-27 14:24:16，PGID116650已无活跃进程；残留进程自行结束初始化，无需PM再终止。工具正常导出结束时已自行移除上述/var/tmp目录，本任务没有清理工作区外文件。
4. `$WS/temp/build_gcc.log`保留主命令与残留子进程全部输出，并已封存；最终末行BUILD-END的时间/退出码对应原主命令。LLVM无日志，因为未启动。GBS buildroot与下载依赖全部留在temp，不上传。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| base仅改memcontrol；作者/提交者符合PM指定 | [base_diff.txt](../evidence/task2/base_diff.txt)、[base_commit.txt](../evidence/task2/base_commit.txt)、[快照索引](../code_snapshots/INDEX.md) |
| tizen未变，lko/base干净；没有额外实验分支 | [final_kernel_state.txt](../evidence/task2/final_kernel_state.txt) |
| SSH成功取得0条open/17条merged，相关12条 | [gerrit_ssh_queries.txt](../evidence/task2/gerrit_ssh_queries.txt)、[gerrit_ssh_summary.txt](../evidence/task2/gerrit_ssh_summary.txt)、[02第2节](02_gerrit_overlap.md) |
| 85fcc6edce0b还删除DEBUG_INFO_BTF=y | [zram_branch_config_diff.txt](../evidence/task2/zram_branch_config_diff.txt) |
| GBS导出子进程未继承-c，独立采用/var/tmp默认值 | [gbs_export_root_cause.txt](../evidence/task2/gbs_export_root_cause.txt)、[build_stop_reason.txt](../evidence/task2/build_stop_reason.txt) |
| GCC主命令143；无完整内核构建结果；残留已无活跃进程 | [build_gcc_result.json](../evidence/task2/build_gcc_result.json)、[build_gcc_log.txt](../evidence/task2/build_gcc_log.txt)、[residual_state.txt](../evidence/task2/residual_state.txt) |
| 日志未伪装成功；time输出Exit status:0不覆盖实际SIGTERM/143 | [03_baseline_build.md](03_baseline_build.md)、[log_integrity.txt](../evidence/task2/log_integrity.txt) |

## 需要人工裁决的前提

- 下次如何向嵌套gbs export可靠传递工作区内tmpdir配置，且不违反“基线代码不改”“不写工作区外”的限制。本次只定位根因，没有自动修改工具或放宽规则。
- 下次如何保证后台构建的root子进程树可在触发停止条件时安全终止；本次sudo清理曾要求密码，后续不得直接假定可无凭据清理。
- 是否安排恢复任务2。获得新指令前，不重试GCC、不启动LLVM、不补做步骤5–9。

## 挂账事项

- GCC/LLVM两个成功构建；实际LINUX_COMPILER、CC/LD/LLVM日志、vmlinux.comment及平台编译器RPM版本。
- 四份最终.config和diffconfig；01逐符号对照及关键项实测。01表仍为tizen@42aeefac的任务1静态推导；**符号改正数未得，不解释成0错误**。
- zImage/vmlinux/模块/符号表/追踪段体积、bloat-o-meter前30项、正常wall/RSS/buildroot/RPM比较。不得用失败初始化产物或宿主工具冒充。
- 04所有能力接口、armv7l结构元数据计算、每GB actime增量、LZ4三提交合入、两个字典脚本和zram相关源码片段。
- 05的Kconfig、DTS/PMU/CoreSight、perf/OpenCSD、平台create_llvm_prof/llvm-profgen/llvm-bolt版本与架构证据。
- 板上所有参数和实测均未采集；本任务不碰板。cache-ext和用户MLGO不再作为重叠待确认项。

交付索引：[evidence/task2/README.md](../evidence/task2/README.md)。STATUS与全部本次产出同一提交，普通git push至GitHub main；最终成果仓库commit以交付回复为准，勿与本地内核base commit混淆。
