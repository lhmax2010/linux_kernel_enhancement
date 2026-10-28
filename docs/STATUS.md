# 项目状态

更新：2026-10-28（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**用户以e028a072启动的基线构建成功，GCC/LLVM均exit=0，ALL-END 2026-10-28T14:55:09+08:00 OK。已完成可用产物核对及ACTIME实际布局验证；平台缺少llvm-bolt/create_llvm_prof，BOLT支持架构无法实测，明确挂账。**

## 计划

本轮按任务2续四：每10分钟只读监控 → 正常结束后封存日志 → 实际编译器/四配置/体积与开销 → ACTIME实际布局 → 05平台前提 → 同commit发布。以上可执行核对已完成；没有重跑gbs、sudo、向进程发信号、改内核或碰开发板。下一阶段优化/上板由PM另发任务。

## 进度

- 本次supervisor PGID518408；export/GCC/LLVM组518419/525954/1214867；最终检查全已退出。12次监控记录原样封存，没有沿用旧PID。
- export a=4工作区配置、b=307允许的外部路径+标志组合、c=5798工作区目录；AUDIT-EXIT0、Issues为空；/dev/null99次，首次trace:323，设备1:3按PM裁决放行。
- GCC/LLVM完整日志各14840/15621行；最后均BUILD-END exit=0，日志尾、SHA-256及流程状态已封存。GCC time墙钟58:44.70、LLVM36:50.38。
- 两轮分别由GCC14.2.0/GNU ld2.43和Clang22.1.8/LLD22.1.8编译；四份compile.h、.comment、日志/命令及RPM版本互相印证。
- 四份最终.config、两组diffconfig各32条差异、01原表178符号全量核对完成。原明确值反转0；4条件项闭合、2字符串改标未输出、补1遗漏DEBUG_ALIGN_RODATA，01共补全/澄清7个符号。Clang未启用STACKPROTECTOR_PER_TASK，GCC为y，不能视为完全同配置实验。
- 大小、模块、kallsyms、追踪数据、bloat-o-meter前30、wall/RSS/buildroot/RPM已记录。buildroot磁盘为普通权限可读部分下界（3目录拒读）。所有数字是构建产物指标，不是板上运行内存。
- 四份原zram对象均用平台pahole验证；真实头文件+最终LLVM普通/RT配置的最小探针证明ACTIME 12→24 / 24→32 B，每GiB增3/2 MiB。没有修改.config或重编内核。
- 05已更新llvm-profgen22.1.8、四配置CORESIGHT=n、perf实际libopencsd OFF；llvm-bolt/create_llvm_prof缺失，架构/版本无法实测，保留尝试命令及权限边界。
- 内核保持lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a，tizen@42aeefac58edeb081aff440f0b60be71cbe49755。LZ4三补丁之前干净合入后临时分支已删除；未对Gerrit推送。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| 导出a/b/c通过、两构建成功、进程退出 | [状态](../evidence/task2/completed_run_baseline_build.status)、[导出审计](../evidence/task2/completed_export_check_home.txt)、[监控](../evidence/task2/completed_monitor.log)、[03](03_baseline_build.md) |
| 日志行数/SHA和BUILD-END封存 | [完整性清单](../evidence/task2/completed_log_integrity.txt)、[GCC尾](../evidence/task2/completed_build_gcc_last100.txt)、[LLVM尾](../evidence/task2/completed_build_llvm_last100.txt) |
| 实际Clang、四配置及01更正口径 | [编译器](../evidence/task2/compiler_actual.txt)、[178符号核对](../evidence/task2/config_inventory_comparison.md)、[重点符号](../evidence/task2/config_key_actual.md)、[01](01_kernel_inventory.md) |
| 产物大小/符号/模块/追踪及成本 | [汇总](../evidence/task2/artifact_measurements.txt)、[符号区间](../evidence/task2/kallsyms_ftrace_measurements.txt)、[03](03_baseline_build.md) |
| ACTIME每GiB增3/2 MiB的真实布局 | [原产物](../evidence/task2/zram_layout_baseline.txt)、[探针输出](../evidence/task2/zram_layout_probe.txt)、[04](04_zram_static.md) |
| FDO平台工具、CoreSight/perf能力与缺项 | [工具输出](../evidence/task2/fdo_platform_actual.txt)、[05](05_kernel_fdo_static.md) |
| 两轮外部路径更新不能归属 | [GCC](../evidence/task2/completed_gcc_r2.external_review.txt)、[LLVM](../evidence/task2/completed_llvm_r2.external_review.txt) |
| LZ4三提交干净合入及字典脚本 | [合入检查](../evidence/task2/lz4_merge_check.txt)、[快照索引](../code_snapshots/INDEX.md) |

## 需要人工裁决的前提

- 没有新增执行许可请求，本轮不安装软件、不改认证或配置。若后续仍要求平台llvm-bolt支持架构/create_llvm_prof版本实测，需要PM指定平台工具包或可核对源码范围；当前root没有这两个工具，不能猜架构列表。
- 两套仓库、依赖release、探测配置和缓存不同，耗时与体积是本次基线；若要把差异归因于编译器，需另行设计受控实验。

## 挂账事项

- 外部更新GCC27项/LLVM48项均无法归属，包含.rpmdb/rpmdb.sqlite-shm；未取得属于本次构建的外部写入证据，也不能证明零外部写入。find权限/深度/所有者限制见03。未删除、移动或打开这些外部文件内容。
- buildroot磁盘精确总量因3目录权限不足未取得，仅报告下界；不sudo补读。
- llvm-bolt支持架构、create_llvm_prof版本缺少平台可执行工具；未使用宿主LLVM或通用targets冒充BOLT支持。
- ARM32内核AutoFDO缺Kconfig/Kbuild profile接入和采样转换消费链验证；CoreSight最终关闭且perf无OpenCSD。PMU/ETM及性能、内存数据需另发上板任务；未构建aarch64。

## 发布状态

本轮01、03、04、05、STATUS及evidence/task2同一提交，使用正常Git环境、Hao Lin <hao.lin@samsung.com>署名，普通push main；最终commit见交付回复。RULES及构建脚本保持e028a072规则/内容，不重跑脚本。历史失败尝试在03及temp/attempt_*中保留，不与本次成功耗时混用。

交付索引：[evidence/task2/README.md](../evidence/task2/README.md)。
