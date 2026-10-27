# 项目状态

更新：2026-10-27（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务2续未完成：步骤A完成；步骤B审计已完成并因文件级配置隔离限制停止；C/D/E未执行。** 本次是阶段性交付，不是成功构建基线。

## 计划

按PM续任务：A修正标题 → B配置来源审计 → C两行项目配置与独立strace导出 → D构建前后工作区外写入监测 → E恢复原步骤4–9。最前面的两条硬要求优先；B发现外部配置文件加载无法通过项目键覆盖禁用，已停止并列替代方案，不自行实施。

## 进度

- A完成：lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a；标题 `mm: restore vendor reclaim semantics for force_reclaim`。与563c53c427bf代码、tree、parent、作者/日期、提交者/日期和正文完全相同，tizen仍是42aeefac58edeb081aff440f0b60be71cbe49755。初次amend的hook追加Change-Id已在最终amend中去除，未修改原hook。
- B完成审计：/etc/gbs.conf不存在，~/.gbs.conf存在，5节5键；只有section/键名入证据，不上传外部键值。没有凭据键。两个项目conf本轮新增覆盖0键：build的profile/buildroot已覆盖，其余外部仓库节未选用；export不消费这些键。
- B阻点：项目.gbs.conf可被export读取（源码证据），但-c和项目文件不能禁止ConfigMgr解析~/.gbs.conf；这违反“不使用工作目录以外的文件”的文件级要求。不是发现未覆盖的当前构建键，也不是项目配置不可读。
- C/D/E未执行：未改写既有受跟踪项目.gbs.conf或添加exclude项，未运行export/strace或r2构建，未创建构建marker、未执行外部写入find；无r2日志、耗时或外部写入监测结论。
- 历史任务2：只拆入mm/memcontrol-v1.c（+22/-7）；SSH open=0、merged=17/相关12；02归属修订已完成。前轮GCC人为中断exit143（5:37.12），LLVM未启动，完整日志保留；PGID116650此前已自行退出、用户未kill。详见03及历史证据。
- RULES已把PM两条硬要求原文置顶，并加入不改共享工具/外部conf、越界等自然结束不发信号、残留等5分钟后报告不sudo不碰其他进程。
- 本轮没有改内核代码/spec、没有编译或碰开发板、没有向Gerrit推送。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| base只修标题、内容和提交身份不变 | [base_amend_r2.txt](../evidence/task2/base_amend_r2.txt) |
| 自动发现顺序、逐键合并、-c/项目配置加载时序 | [gbs_config_audit_r2.md](../evidence/task2/gbs_config_audit_r2.md)、[带行号源码](../evidence/task2/gbs_config_source_r2.txt) |
| 外部配置存在性、所有节/键及逐项影响 | [external_gbs_keys_r2.txt](../evidence/task2/external_gbs_keys_r2.txt)、[审计第3节](../evidence/task2/gbs_config_audit_r2.md#3-外部配置逐键审计) |
| 项目tmpdir理论可生效，但不能禁止外部文件解析 | [审计第2/4节](../evidence/task2/gbs_config_audit_r2.md)、[03](03_baseline_build.md) |
| 新SHA与现有memcontrol快照内容一致 | [快照索引](../code_snapshots/INDEX.md) |
| 旧失败日志完整、末行143，残留自行退出 | [build_gcc_log.txt](../evidence/task2/build_gcc_log.txt)、[build_closure_recheck.txt](../evidence/task2/build_closure_recheck.txt) |

## 需要人工裁决的前提

B停止条件要求不自行选择替代方案。[审计第5节](../evidence/task2/gbs_config_audit_r2.md#5-可行的替代设计及影响面未选择未实施)列出：工作区独立GBS副本并限制配置来源；本任务专属文件系统隔离环境；或PM明确放宽为允许解析外部文件但不采纳行为值（该选项不满足当前硬规则）。前两项需评审工具差异或隔离/权限影响，均未实施。

步骤C另需裁决：现有linux-rpi/.gbs.conf已受跟踪，不能既改成两行又仅靠exclude保持干净。是否允许独立配置提交，或改用不改该文件的注入方案，见[现有项目配置证据](../evidence/task2/existing_project_gbs_r2.txt)。本轮保持原样，未隐藏修改。

## 挂账事项

- C导出strace目录核验、D前后监测与归属分析、E两次成功构建；当前没有“未检测到越界”结论。
- LLVM是否确实Clang、四份最终.config、01逐符号核对和改正数、平台编译器RPM与工具版本。
- vmlinux/zImage差值、模块/符号/追踪段、bloat-o-meter、两轮耗时/RSS/buildroot/RPM大小。
- 04能力接口、armv7l entry/ACTIME每GB元数据增量、LZ4三补丁合入检查、两个字典脚本和zram源码片段。
- 05的AutoFDO/PMU/CoreSight/perf/OpenCSD/create_llvm_prof/llvm-profgen/llvm-bolt核验；aarch64只做Kconfig，板测另发任务。
- 上述未知值不写成0或通过；历史任务1静态表不替代最终.config。

交付索引：[evidence/task2/README.md](../evidence/task2/README.md)。本次产出与STATUS同一提交，普通git push至GitHub main。

发布复核：证据索引的raw链接已逐项按仓库相对路径校验，文件大小及SHA-256全部匹配；本轮所有上传文件为小于1 MB的文本。
