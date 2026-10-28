# 任务2：armv7l 构建基线与实际配置核对

日期：2026-10-28（Asia/Shanghai）。本报告只记录本任务实际执行的结果；未获得的构建产物指标不以源码推导替代。所有体积与构建开销数字均为构建产物/开发机数据，不代表板上运行时内存。

## 最新：用户启动的e028a072构建完成，产物核对（2026-10-28）

**两轮构建均exit=0，LLVM产物确由Clang编译。** 用户启动脚本；代理仅每10分钟只读监控并追加monitor.log，结束后分析产物，没有运行gbs、sudo、发送信号、修改内核或操作开发板。平台缺失的llvm-bolt/create_llvm_prof，以及不可读目录导致的磁盘统计下界，保留为明确限制，不用宿主工具补成“实测”。

### 完成状态与导出审计

[状态原文](../evidence/task2/completed_run_baseline_build.status)记录ALL-END 2026-10-28T14:55:09+08:00 OK。本次supervisor为518408，export/GCC/LLVM PGID依次518419/525954/1214867；15:04:08检查均已退出，没有沿用旧尝试PID。12次监控见[monitor.log](../evidence/task2/completed_monitor.log)。本次run_baseline_build.log为空，原样保留并记空文件SHA；PID核验结合本次pgid文件及进程快照，不以空日志推断失败。

| 阶段 | 开始（+08:00） | 结束（+08:00） | 结果 |
| --- | --- | --- | --- |
| export | 13:13:07 | 13:18:57 | OK / exit=0 |
| GCC | 13:18:57 | 14:18:01 | OK / exit=0 |
| LLVM | 14:18:01 | 14:55:09 | OK / exit=0 |

导出审计a：4个配置路径均在WS，含隔离.gbs.conf/.gbp.conf；b：307个外部路径+标志组合均命中运行时白名单或PM裁决例外，拒绝0；c：5798个成功创建目录均在WS。/dev/null带写标志99次，首次trace:323，均精确返回字符设备1:3，按PM裁决放行。AUDIT-EXIT=0、Issues为空。完整小于1 MB的[导出摘要](../evidence/task2/completed_export_check_home.txt)已封存；本次成功解析opens=107173，与旧离线trace总数不同，不能混用旧计数。

构建后find检查：GCC有27条、LLVM有48条工作区外更新路径，**全部无法归属**，包括两轮都出现的/home/linhao/.rpmdb/rpmdb.sqlite-shm；名称和时间不能证明来自本次GBS。直接观察文件为空，没有能够归因到本次构建的外部写入记录；不能据此声称“没有任何外部写入”。任务3只读追查仍不能归属：隔离HOME内.rpmdb不存在，宿主_dbpath受HOME影响，真实shm最新mtime在构建结束后，日志没有写入PID证据，详见[07的rpmdb核对](07_llvm_text_growth.md#7-rpmdb只读归属核对)。两次find exit=1、权限错误按用户命令抑制，且maxdepth=3、按普通用户归属过滤，不覆盖更深目录或root所有文件。没有删除或移动任何外部文件。[GCC检查](../evidence/task2/completed_gcc_r2.external_review.txt)、[LLVM检查](../evidence/task2/completed_llvm_r2.external_review.txt)。

完整日志留在temp，封存最后100行及本次进程组摘要：[GCC日志](../evidence/task2/completed_build_gcc_last100.txt)、[LLVM日志](../evidence/task2/completed_build_llvm_last100.txt)、[export进程](../evidence/task2/completed_export_processes_summary.txt)、[GCC进程](../evidence/task2/completed_gcc_processes_summary.txt)、[LLVM进程](../evidence/task2/completed_llvm_processes_summary.txt)。完整日志行数/SHA-256见[完整性清单](../evidence/task2/completed_log_integrity.txt)。两份正式日志末行分别为BUILD-END gcc/llvm，exit均0。

### 编译器与方法

[产物与工具SHA-256、源码状态](../evidence/task2/artifact_identity_and_source_state.txt)记录本轮分析对象；[补充Kconfig/链接脚本证据](../evidence/task2/actual_config_source_lines.txt)支撑下文条件与区间解释。所有产物分析使用各自GBS buildroot的qemu-arm、readelf、size、nm、objdump、rpm、pahole；diffconfig和bloat-o-meter来自LLVM buildroot中的本次内核源码，并由该root的Python 3.14运行，nm wrapper也只调用该root的nm。未使用宿主size/readelf/nm等替代。首次宿主qemu-arm-static运行平台Python发生SIGILL，随后改用**buildroot自带qemu-arm**成功；正式证据的命令均记录绝对路径。RPM命令显式指定root内rpmrc/macros/dbpath，未用宿主RPM配置或数据库。

| 证据 | GCC构建 | LLVM构建 |
| --- | --- | --- |
| 构建日志 | 无LLVM=1/CC=/LD=字面赋值；实际zram .o.cmd以gcc开头 | 日志1988–1994、14290–14296有CC=armv7l-tizen-linux-gnueabi-clang和LLVM=1；没有LD=字面赋值 |
| 普通/RT compile.h | GCC 14.2.0，GNU ld 2.43 | Clang 22.1.8，LLD 22.1.8 |
| 两版vmlinux .comment | GCC 14.2.0 | clang version 22.1.8；Linker: LLD 22.1.8 |
| root中的RPM | gcc-14.2.0-4.30.armv7l；binutils-2.43-3.29.armv7l；clang/llvm未安装 | gcc-14.2.0-1.13.armv7l；clang和llvm均22.1.8-3.1.armv7l；binutils-2.43-1.13.armv7l |

[四类编译器原始证据](../evidence/task2/compiler_actual.txt)同时包括两版实际zram编译命令（-O2、-g、-gdwarf-4等）。LLVM root有gcc不代表内核用了gcc；compile.h、ELF .comment、.o.cmd和最终CC_IS_CLANG相互印证。两套仓库还有依赖/工具release差异，因此本对照是两条GBS构建基线，不能当作只改变编译器这一变量的实验。

### 最终配置与01修订

四份原始配置：[GCC普通](../evidence/task2/config_gcc_arm-rpi4.txt)、[GCC RT](../evidence/task2/config_gcc_arm-rpi4-rt.txt)、[LLVM普通](../evidence/task2/config_llvm_arm-rpi4.txt)、[LLVM RT](../evidence/task2/config_llvm_arm-rpi4-rt.txt)。平台diffconfig：[普通](../evidence/task2/diffconfig_arm-rpi4.txt)、[RT](../evidence/task2/diffconfig_arm-rpi4-rt.txt)。两组各32条符号差异（含删除/新增、工具版本字符串和探测能力），无静默丢弃。

最需要注意：GCC STACKPROTECTOR_PER_TASK=y，LLVM未输出（不启用）；STACKPROTECTOR/STRONG两者均y。arch/arm/Kconfig:1376–1383要求GCC_PLUGINS或CC_HAVE_STACKPROTECTOR_TLS；LLVM最终没有两项可用条件。其余差异以diffconfig原文为准，不能说四份配置完全一致。任务3已实测：Clang探测默认armv4t而-mtp=cp15不支持，补-march=armv7-a的对照通过，详见[07](07_llvm_text_growth.md)。

01原表178符号逐项核对：[完整对照](../evidence/task2/config_inventory_comparison.md)。没有发现原先明确数值发生反转；修订/澄清6个已列符号，另补1个漏列符号，合计7个符号：

| 符号 | 原推导 | 最终GCC普通版 | 修订原因 |
| --- | --- | --- | --- |
| ZSWAP_COMPRESSOR_DEFAULT | 空字符串 | 未输出 | ZSWAP关闭，不能将Kconfig字符串默认值写成最终.config实际记录 |
| ZSWAP_ZPOOL_DEFAULT | 空字符串 | 未输出 | 同上 |
| DEBUG_INFO_BTF_MODULES | y（有条件） | y，.config:6772 | pahole 1.29满足条件，条件闭合 |
| STACKPROTECTOR | y（有条件） | y，:652 | 实际GCC探测通过 |
| STACKPROTECTOR_STRONG | y（有条件） | y，:653 | 实际GCC探测通过 |
| STACKPROTECTOR_PER_TASK | y（有条件） | y，:511 | GCC TLS guard支持；LLVM不同，见上文 |
| DEBUG_ALIGN_RODATA | 原表漏列 | y，:435 | arch/arm/mm/Kconfig:1125–1128默认y；补齐所有DEBUG_*=y要求 |

[单独重点核对表](../evidence/task2/config_key_actual.md)逐项列出四配置值和行号：HZ=100；普通PREEMPT_VOLUNTARY=y/RT为PREEMPT_RT=y；KALLSYMS_ALL、DEBUG_INFO_BTF、BTF_MODULES、TRACE_IRQFLAGS、PREEMPTIRQ_TRACEPOINTS均y；LRU_GEN_WALKS_MMU未输出（依赖不满足，未启用）；CORESIGHT显式n、所有CORESIGHT子项未输出；PERF_EVENTS/HW_PERF_EVENTS均y。MGLRU仍y且默认启用，ZRAM仍内建lzo-rle，仅LZO后端，MULTI_COMP/ACTIME/WRITEBACK均n。

### 大小与开销

单位为字节；vmlinux为含DWARF/BTF的完整文件，四个核心section取size -A精确名称，不把.init.text等静默合并进.text。完整section、模块RPM清单及口径见[产物汇总](../evidence/task2/artifact_measurements.txt)、[模块清单](../evidence/task2/modules_rpm_contents.txt)。

| 指标（字节，除数量外） | GCC普通 | LLVM普通 | LLVM−GCC | GCC RT | LLVM RT | LLVM−GCC |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 附注：vmlinux完整文件 | 412,486,440 | 338,481,420 | -74,005,020 | 421,759,136 | 345,620,612 | -76,138,524 |
| zImage | 14,323,400 | 14,896,384 | +572,984 | 14,470,728 | 14,945,240 | +474,512 |
| .text | 17,808,156 | 19,862,536 | +2,054,380 | 18,128,580 | 20,005,868 | +1,877,288 |
| .rodata | 5,217,374 | 5,144,813 | -72,561 | 5,159,246 | 5,095,013 | -64,233 |
| .data | 1,874,192 | 1,870,640 | -3,552 | 1,886,416 | 1,882,896 | -3,520 |
| .bss | 589,008 | 592,912 | +3,904 | 610,768 | 614,224 | +3,456 |
| 构建目录模块数 | 52 | 52 | +0 | 52 | 52 | +0 |
| 构建目录.ko总字节（含调试） | 39,028,264 | 29,325,668 | -9,702,596 | 39,126,596 | 29,348,752 | -9,777,844 |
| RPM内模块数 | 52 | 52 | +0 | 52 | 52 | +0 |
| RPM内.ko逻辑总字节 | 2,641,484 | 2,821,812 | +180,328 | 2,648,528 | 2,821,912 | +173,384 |
| kallsyms符号数 | 129,029 | 126,768 | -2,261 | 129,068 | 127,320 | -1,748 |

**任务3按段复核：LLVM普通版常驻已分配段增加2,669,604 B（+8.11%），RT增加2,516,690 B（+7.58%）。** 常驻指SHF_ALLOC中排除.init*和.exit.text；.BTF仍计常驻，.debug_*不加载。模块分构建.ko与RPM内.ko统计。完整vmlinux文件差−74,005,020 / −76,138,524 B仅作文件体积附注，不能解释为内存下降；zImage仍分别大572,984 / 474,512 B。

| 类别/字节 | GCC普通 | LLVM普通 | Δ普通 | GCC RT | LLVM RT | ΔRT |
| --- | --- | --- | --- | --- | --- | --- |
| 调试 .debug_*（非分配） | 371,084,669 | 294,059,724 | -77,024,945 | 380,296,444 | 301,358,541 | -78,937,903 |
| 常驻：其余 SHF_ALLOC | 32,930,806 | 35,600,410 | +2,669,604 | 33,222,614 | 35,739,304 | +2,516,690 |
| 启动后释放 .init* / .exit.text | 781,896 | 854,008 | +72,112 | 738,496 | 802,148 | +63,652 |
| 构建 .ko（含调试，52个/版） | 39,028,264 | 29,325,668 | -9,702,596 | 39,126,596 | 29,348,752 | -9,777,844 |
| 打包 .ko（52个/版，RPM内逻辑字节） | 2,641,484 | 2,821,812 | +180,328 | 2,648,528 | 2,821,912 | +173,384 |

逐段、目录、裁剪条件与统计限制见[06](06_static_footprint.md)；代码与unwind增长证据见[07](07_llvm_text_growth.md)。

平台size原文：[GCC普通](../evidence/task2/size_gcc_arm-rpi4.txt)、[GCC RT](../evidence/task2/size_gcc_arm-rpi4-rt.txt)、[LLVM普通](../evidence/task2/size_llvm_arm-rpi4.txt)、[LLVM RT](../evidence/task2/size_llvm_arm-rpi4-rt.txt)。

bloat-o-meter默认符号过滤后按**绝对差值**降序前30项：[普通](../evidence/task2/bloat_arm-rpi4_top30.txt)、[RT](../evidence/task2/bloat_arm-rpi4-rt_top30.txt)。GCC→LLVM的内联、局部符号命名和合并会使函数在一侧消失/出现，这些行不是逐函数因果归因或性能测量。

kallsyms位于.rodata内部；__mcount_loc及ftrace事件/映射表合入.init.data，并非独立ELF section。由平台nm边界差、objdump读取最终kallsyms_num_syms得到下表；最后seqs数组为3×符号数，其他kallsyms子区间包含到下一label的对齐。原始命令和计算见[符号/追踪区间](../evidence/task2/kallsyms_ftrace_measurements.txt)；不要再把这些字节重复加到.rodata/.init.data总量。

| 数据区间（字节） | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | ---: | ---: | ---: | ---: |
| kallsyms_num_syms | 4 | 4 | 4 | 4 |
| kallsyms_names | 1,800,628 | 1,841,884 | 1,800,184 | 1,846,664 |
| kallsyms_markers | 2,020 | 1,984 | 2,020 | 1,992 |
| kallsyms_token_table | 932 | 928 | 932 | 928 |
| kallsyms_token_index | 512 | 512 | 512 | 512 |
| kallsyms_offsets | 516,116 | 507,072 | 516,272 | 509,280 |
| kallsyms_relative_base | 4 | 4 | 4 | 4 |
| kallsyms_seqs_of_names | 387,087 | 380,304 | 387,204 | 381,960 |
| mcount_loc | 228,600 | 223,760 | 228,208 | 223,980 |
| ftrace_events | 7,256 | 7,256 | 7,256 | 7,256 |
| ftrace_eval_maps | 6,200 | 6,200 | 6,200 | 6,200 |

| 每轮整条GBS命令（含普通+RT、perf、打包等） | GCC | LLVM |
| --- | ---: | ---: |
| time -v墙钟 | 58:44.70 | 36:50.38 |
| time -v最大单进程RSS（kbytes） | 2,604,804 | 2,607,380 |
| buildroot已可读部分磁盘分配字节，下界 | 9,583,403,008 | 11,364,896,768 |
| 15个二进制RPM+1个SRPM总字节 | 633,584,749 | 594,775,808 |

墙钟取time -v，不含脚本前后检查；stage起止包含检查，故略长。RSS为time报告的最大驻留集，不是并行编译进程总RSS峰值。GBS缓存/仓库差异、其他并发任务及一次观测使耗时不能作编译器纯性能结论。buildroot的usr/share/upgrade、var/cache/ldconfig、root三个目录不可读，du exit=1，数值是下界；没有sudo补读。[GCC磁盘输出](../evidence/task2/disk_gcc.txt)、[LLVM磁盘输出](../evidence/task2/disk_llvm.txt)。**全部数字是构建产物/开发机指标，不代表板上运行时内存或收益。**

### 静态核对闭合与剩余项

[04](04_zram_static.md)以真实最终配置、真实zram头文件和平台Clang/pahole证明ACTIME普通12→24 B、RT24→32 B；每GiB增3/2 MiB。没有重编内核或改变任何.config，只在temp编译最小布局探针。[05](05_kernel_fdo_static.md)更新实际CoreSight/perf和llvm-profgen；平台llvm-bolt/create_llvm_prof缺失，BOLT支持架构无法实测，保留查找命令与失败原因。没有用LLVM通用targets列表代替BOLT能力。

下面为历史尝试及规则演进，出现“未构建”“停止”等描述均属于对应日期，现状以本节和STATUS为准。

## 历史任务2续六：解析修复与离线验证通过（2026-10-28）

结论：完整归档trace离线审计`AUDIT-EXIT 0`、Issues为空；8个负对照及2个正对照全部符合预期，`bash -n`通过，**可以由用户重跑**。本轮没有运行gbs、sudo、构建或向任何进程发信号。原始导出成功不等于原始流程成功：用户以3ef50850启动的2026-10-27 20:41尝试，export命令exit=0，后置审计因5条拆分openat的标志解析失败而exit=91，GCC/LLVM均SKIPPED，见[原失败记录](../evidence/task2/export_attempt_2041_failure.txt)。

### 归档

确认旧监督组184075、导出组184089及本项目worker均无存活进程后，将下列12项原样移动到`$WS/temp/attempt_20261027_2041/`；没有删除，保留run_baseline_build.lock原位以及较早归档/buildroot。原始trace未修改，仍在归档目录中；每项的大小/SHA-256见[移动清单](../evidence/task2/attempt_2041_archive.txt)。

| 原temp/条目 | 归档后位置（相对temp/） |
| --- | --- |
| run_baseline_build.status | attempt_20261027_2041/run_baseline_build.status |
| run_baseline_build.log | attempt_20261027_2041/run_baseline_build.log |
| run_baseline_build.existing_processes.txt | attempt_20261027_2041/run_baseline_build.existing_processes.txt |
| export_check/ | attempt_20261027_2041/export_check/ |
| export_check.log | attempt_20261027_2041/export_check.log |
| export_check.log.raw | attempt_20261027_2041/export_check.log.raw |
| export_check.strace | attempt_20261027_2041/export_check.strace |
| export_check_home.txt | attempt_20261027_2041/export_check_home.txt |
| export_r2.observed_outside.txt | attempt_20261027_2041/export_r2.observed_outside.txt |
| export_r2.pgid | attempt_20261027_2041/export_r2.pgid |
| export_r2.processes.log | attempt_20261027_2041/export_r2.processes.log |
| monitor.log | attempt_20261027_2041/monitor.log |

### 同一份解析代码与入口

`run_baseline_build.sh:240`的标志表达式改为`([A-Z0-9_|]+)[[:space:]]*(,|\))`；:263–267在拼接前只删除unfinished前半段末尾的空白，不删除引号内空格，也不改写原始trace。PID配对、起始行号及设备1:3校验保留。

新增`--audit-only <trace路径> <新摘要路径>`，在脚本:449起分派，位于worker/前台预检、状态文件、锁和sudo逻辑之前，调用同一个`trace_audit`后立即退出。输入必须是WS内可读普通文件；输出必须是temp内的新文件，父目录已存在，不覆盖旧证据。正式worker也调用:231同一函数，没有另一套解析器。离线片段的覆盖要求是至少一个成功打开；正式export还保留配置读取和成功mkdir的非空覆盖要求（:341–348），以容纳PM指定的“仅含只读打开与/dev/null打开”的正对照。两种入口的所有路径、标志、设备、mkdir及无法解析判定相同；本次完整trace有4条配置路径和5798个创建目录，满足正式export额外覆盖要求。

离线执行命令（已执行，不调用gbs）：

```bash
/usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_baseline_build.sh --audit-only /home/linhao/Toolchain/development/linux_kernel_optimization/temp/attempt_20261027_2041/export_check.strace /home/linhao/Toolchain/development/linux_kernel_optimization/temp/export_audit_offline_r6.txt
```

完整a/b/c、恢复调用与Issues保存在temp/export_audit_offline_r6.txt；[上传摘要](../evidence/task2/offline_audit_r6_summary.txt)保留统计、五条恢复调用和校验值，不上传完整目录清单。

### 各正则的核对

源码位置为本次脚本；附加正对照10实际执行了拆分clone/chdir/mkdir/mkdirat及返回FD的重建，见[用例](../evidence/task2/audit_fixtures_r6/10_split_regex_reconstruction.trace)及[结果表](../evidence/task2/audit_fixture_results_r6.md)。

| 正则 | 拼接后的匹配行为及证据 |
| --- | --- |
| re_flags (:240) | 标志后允许任意空白再遇逗号/右括号；真实5条恢复openat全部解析，拆分外部写入负对照08仍拒绝 |
| re_fd (:239) | 在返回值部分匹配`= 空白 FD<路径`；=后的空白已允许，FD与<是strace -yy格式；真实5条及用例10拆开返回值均通过；设备例外另用完整1:3标注校验 |
| re_ok (:242) | 匹配`= 空白 0 行尾空白`，与参数分隔符不相邻；用例10的chdir/mkdir/mkdirat返回0均识别 |
| re_child (:243) | 匹配`= 空白 子PID 行尾空白`；用例10的拆分clone得到184095；随后相对chdir与relative mkdir的正确定位证明继承父进程cwd |
| re_mkdir (:244) | 只提取mkdir起始引号中的路径，不要求闭引号紧邻逗号；用例10闭引号后拆分的relative child正确定位在WS |
| re_mkdirat (:245) | 提取dirfd及其后路径，逗号后本就允许空白；用例10使用AT_FDCWD真实路径标注并在路径后拆分，at-child正确定位 |
| re_chdir (:246) | 只提取chdir起始引号中的路径，不要求闭引号后紧邻右括号；用例10拆分的相对chdir后cwd更新，后续relative mkdir证明更新生效 |

### 完整trace离线结果

| 项目 | 实测结果 |
| --- | --- |
| 审计与进程退出码 | AUDIT-EXIT 0，进程exit=0，Issues为空 |
| a 配置 | 4个路径全部位于WS；包括工作区.gbp.conf，没有成功读取外部gbp.conf |
| b 外部打开 | 307个去重的“路径+标志”组合全部按现有运行时白名单或精确/dev/null例外放行；拒绝组合0个 |
| c 成功mkdir | 5798个去重目录全部位于WS |
| /dev/null带写标志 | 99次，首次原始trace第323行，按PM裁决放行；旧审计的98次漏掉15487/15489这一对 |
| 成功解析打开总数 | 107174次；恢复打开5次，均列于摘要d段 |

| 原始trace行号 | 返回路径 | 标志 |
| --- | --- | --- |
| 470/472 | /sys/devices/system/cpu/online | O_RDONLY\|O_CLOEXEC |
| 471/473 | /sys/devices/system/cpu/online | O_RDONLY\|O_CLOEXEC |
| 15487/15489 | /dev/null（char 1:3） | O_RDWR |
| 15488/15490 | /etc/locale.alias | O_RDONLY\|O_CLOEXEC |
| 111556/111561 | /usr/lib/x86_64-linux-gnu/liblzma.so.5.4.5 | O_RDONLY\|O_CLOEXEC |

### 对照验证

用例由真实trace片段复制或定向修改得到，全部存于temp/audit_fixtures/，上传同内容文本到evidence/task2/audit_fixtures_r6/；没有实际创建用例中的外部文件/目录，没有打开那些设备或配置。[来源说明](../evidence/task2/audit_fixtures_r6/PROVENANCE.txt)、[每例完整Issues](../evidence/task2/audit_fixture_results_r6.md)。

| 用例文件 | 场景 | 预期AUDIT-EXIT | 实际AUDIT-EXIT / 进程exit | 结果 |
| --- | --- | ---: | --- | --- |
| [01_external_file_write.trace](../evidence/task2/audit_fixtures_r6/01_external_file_write.trace) | 外部普通文件O_WRONLY\|O_CREAT | 1 | 1 / 1 | 符合 |
| [02_dev_zero_write.trace](../evidence/task2/audit_fixtures_r6/02_dev_zero_write.trace) | /dev/zero O_RDWR | 1 | 1 / 1 | 符合 |
| [03_dev_null_wrong_device.trace](../evidence/task2/audit_fixtures_r6/03_dev_null_wrong_device.trace) | /dev/null但char 1:5 | 1 | 1 / 1 | 符合 |
| [04_external_gbp_config.trace](../evidence/task2/audit_fixtures_r6/04_external_gbp_config.trace) | 读取外部gbp.conf | 1 | 1 / 1 | 符合 |
| [05_external_mkdir_success.trace](../evidence/task2/audit_fixtures_r6/05_external_mkdir_success.trace) | 外部mkdir成功 | 1 | 1 / 1 | 符合 |
| [06_external_mkdir_eexist.trace](../evidence/task2/audit_fixtures_r6/06_external_mkdir_eexist.trace) | 外部mkdir返回EEXIST | 1 | 1 / 1 | 符合 |
| [07_tmp_readwrite.trace](../evidence/task2/audit_fixtures_r6/07_tmp_readwrite.trace) | /tmp O_RDWR | 1 | 1 / 1 | 符合 |
| [08_split_external_write.trace](../evidence/task2/audit_fixtures_r6/08_split_external_write.trace) | 拆分的外部O_WRONLY | 1 | 1 / 1 | 符合 |
| [09_split_allowed.trace](../evidence/task2/audit_fixtures_r6/09_split_allowed.trace) | 仅拆分合法只读调用与/dev/null读写 | 0 | 0 / 0 | 符合 |
| [10_split_regex_reconstruction.trace](../evidence/task2/audit_fixtures_r6/10_split_regex_reconstruction.trace) | 附加：拆分clone/chdir/mkdir/mkdirat与FD | 0 | 0 / 0 | 符合 |

未改变路径白名单来使测试通过。脚本修改结束后的`bash -n`退出0，[验证记录](../evidence/task2/audit_validation_r6.txt)。这些结果证明本次保存trace与对照片段的解析和判定符合要求，不代表下一次运行已经成功，也不是构建产物验证。

建议用户在tmux/screen中执行原命令（代理不执行）：

```bash
cd /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi && /usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_baseline_build.sh
```

启动后按任务2续四用本次实际PID/PGID只读监控；异常即停，ALL-END OK后再做编译器、配置、体积、05及ACTIME布局核对。

## 历史任务2续五：GBP隔离与导出审计修正（裁决已落实，等待用户重跑）

用户在commit `24707cadc26a322bbee18545617064c21dd50c49`启动的流程，export命令于2026-10-27 18:01:13返回0，审计于18:01:43以91失败；status已含ALL-END，GCC/LLVM均SKIPPED。监督组148694及导出组148705均已退出。代理没有重试、发信号或调用sudo。完整状态、日志、摘要统计及SHA-256见[上次审计摘要](../evidence/task2/export_attempt_1801_summary.txt)。

### 三类审计结论

1. **配置读取**：旧a段只列3个工作区内.gbs.conf，却漏分了`/etc/git-buildpackage/gbp.conf`。它在trace:15132、15252确实被只读打开。该系统文件的9个空section及remote-config pkg-libvirt下两个远端模板设置完整列入[配置证据](../evidence/task2/gbp_system_config.txt)；这两个设置不参与本次导出解析器的section合并，未改变此次导出参数。仅凭当前文件不能证明更早历史时刻内容相同。[GBP来源核对](../evidence/task2/gbp_audit.md)逐项给出源码位置、查找顺序、缺失文件处理及环境传递依据。
2. **运行时读取**：旧b段共15个外部路径，其中7项被拒绝。除gbp.conf外的6项是PM本轮明确允许的TLS/GSSAPI/LDAP运行时配置、DNS解析实际文件和两个只读目录。`/etc/resolv.conf`在trace:119、14859解析到`/run/systemd/resolve/stub-resolv.conf`，旧白名单只认符号链接名，因此拒绝真实目标。
3. **目录创建/写入标志**：旧c段5798个成功创建目录全部在WS。完整trace扫描107229个成功open/openat、4027个失败打开，unfinished/resumed按PID合并后无未解析项；工作区外带O_WRONLY/O_RDWR/O_CREAT的成功打开有101次，**全部是/dev/null的O_RDWR**，不能写成“任何工作区外写标志都不存在”。除此之外没有此类打开；不等于覆盖write/rename/unlink或继承FD上的写入。[全部命中与trace行号](../evidence/task2/export_trace_open_analysis.txt)。

`/tmp`、`/var/tmp`的调用者均为PID148710（进程日志:453，`/usr/bin/python3 /usr/bin/gbs export ...`），trace:280–281分别为`openat(AT_FDCWD<WS/linux-rpi>, "/tmp", O_RDONLY)`及`"/var/tmp", O_RDONLY`，返回FD3。没有O_DIRECTORY，不能伪写成带此标志；当前stat确认两者均为目录。trace未跟踪调用栈/read/fstat，不能恢复精确C源码行或证明当时读取了目录内容。

来源进一步核对：`gbp/rpm/lib_rpm.py:26`按policy.py:28导入rpm_tizen，后者`__init__.py:39`加载原生RPM扩展；trace:236–265记录RPM与NSS/freebl库加载。已安装`/usr/lib/x86_64-linux-gnu/libfreeblpriv3.so`的只读反汇编中，0xc9620路径表依次包含/etc/passwd、/etc/utmp、/tmp、/var/tmp、/usr/tmp；0x9f93–0x9fbc循环送入0x9d20，0x9d7b取stat、0x9d9f以`"r"`调用fopen，再尝试read。**推测**这是RPM初始化触发NSS随机数初始化、采集文件状态等系统噪声；路径顺序和调用方式与trace一致，但没有调用栈不能把该函数确定为本次调用点，也没有该库原始C源码行号。保留[反汇编、只读标志与目录类型证据](../evidence/task2/tmp_directory_library_analysis.txt)，不为定位它重跑导出。

### 本轮脚本变更与判定

- 导出、GCC、LLVM均通过命令级env传入`HOME=$WS/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=$WS/temp/gbs-home/.gbp.conf`；不修改用户shell环境，成果仓库Git仍使用正常环境认证。
- GBP_CONF_FILES支持冒号分隔的非空列表并完全替换默认列表；GBS库调用GBP、depanneur fork/exec链继承变量。已创建普通文件temp/gbs-home/.gbp.conf，仅含一行注释：`# Restrict git-buildpackage to workspace configuration only.`。预检要求普通非符号链接、非空可读、每行仅注释。
- 配置分类新增gbp.conf；每个外部成功打开都记录flags与命中的白名单条目/理由或拒绝原因。新增四条运行时路径；/tmp和/var/tmp仅允许O_RDONLY且目录检查通过，不允许其子路径自动继承豁免。
- 外部成功打开先检查O_WRONLY/O_RDWR/O_CREAT/O_TRUNC（仅下述精确/dev/null例外），再检查运行时白名单；外部mkdir/mkdirat包括失败的尝试也拒绝。审计在当前导出自然结束后运行，不发信号。读取目录的类型检查在审计时进行，不能替代原trace没有记录的fstat历史证据。
- 保留原umask、完整系统PATH、一次前台sudo -v、进程组残留等待、ALL-END与失败跳过后续逻辑。建议在tmux/screen中运行，保持控制终端以供depanneur每3分钟的sudo认证维持（depanneur:3164–3174）。

**PM裁决已落实**：只对返回路径精确为`/dev/null`、且strace -yy返回FD完整标注为`</dev/null<char 1:3>>`的成功打开豁免写标志。路径不同、设备号不同、不是字符设备或缺少设备标注均不豁免，包括/dev下其他设备；不使用调用参数名或事后stat代替设备证明。b段逐路径记录“按 PM 裁决放行”，另单列放行次数和首次原始trace行号。unfinished/resumed调用只计一次，行号取调用开始行；并发恢复顺序不同取最小起始行。零次显示count=0、first_trace_line=none。历史101次/首次323行只是上次trace记录，新一轮统计由脚本重新计算。

本轮只做源码/trace读取、文本改动、文件归档及`bash -n`（[本次验证记录](../evidence/task2/script_static_validation_null_exception.txt)），未运行新脚本、未导出或构建。新隔离及审计是否实际通过，必须以用户重跑结果为准。

### 归档移动清单

归档目录`$WS/temp/attempt_20261027_1801/`；下列12项保持名称整体移动，没有删除。移动前确认两个旧进程组无存活进程，保留`temp/run_baseline_build.lock`原inode、gbs-home和更早任务的文件/buildroot。逐项字节数/SHA-256（含export_check目录中文件）见[归档清单](../evidence/task2/attempt_1801_archive.txt)。

| 原temp/条目 | 归档后位置（相对temp/） |
| --- | --- |
| run_baseline_build.status | attempt_20261027_1801/run_baseline_build.status |
| run_baseline_build.log | attempt_20261027_1801/run_baseline_build.log |
| run_baseline_build.existing_processes.txt | attempt_20261027_1801/run_baseline_build.existing_processes.txt |
| export_check/ | attempt_20261027_1801/export_check/ |
| export_check.log | attempt_20261027_1801/export_check.log |
| export_check.log.raw | attempt_20261027_1801/export_check.log.raw |
| export_check.strace | attempt_20261027_1801/export_check.strace |
| export_check_home.txt | attempt_20261027_1801/export_check_home.txt |
| export_r2.observed_outside.txt | attempt_20261027_1801/export_r2.observed_outside.txt |
| export_r2.pgid | attempt_20261027_1801/export_r2.pgid |
| export_r2.processes.log | attempt_20261027_1801/export_r2.processes.log |
| monitor.log | attempt_20261027_1801/monitor.log |

用户执行命令不变（代理不执行）：

```bash
cd /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi && /usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_baseline_build.sh
```

用户重跑后，按任务2续四每10分钟只读检查status、两类日志尾部和本次实际PGID，只追加monitor.log；export通过时报a/b/c，异常即停，ALL-END OK后才做编译器、最终配置、体积、ACTIME布局与LLVM平台工具核对。

## 历史任务2续三：用户执行脚本（仅编写，未运行）

脚本：[scripts/run_baseline_build.sh](../scripts/run_baseline_build.sh)。本轮只做源码阅读、静态检查和 `bash -n`，没有执行脚本、sudo、导出、GBS构建或板上操作。正常环境推送已成功补发b33992f0及规则修订，见[publication_r3_initial.txt](../evidence/task2/publication_r3_initial.txt)。旧文中的认证失败是历史记录，不是当前发布状态。

用户在自己的终端执行这一整行：

```bash
cd /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi && /usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_baseline_build.sh
```

所有工作区路径已写死。脚本是Bash，使用已安装系统工具，不依赖工作区外的辅助脚本。PATH固定为 `/usr/bin:/bin:/usr/sbin:/sbin`。脚本不设置umask，沿用用户终端默认值，避免额外收紧经sudo生成的RPM和仓库文件权限，并保持与用户平时运行GBS的条件一致。HOME和GIT_CONFIG_NOSYSTEM仅由env传给strace/gbs及其后代，脚本不会修改调用者的HOME或Git配置；结果仓库commit/push使用正常环境与已有GitHub认证。

### 前台与sudo依据

预检必须从linux-rpi运行，确认lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a、干净工作树、tizen保持42aeefac；检查两行普通temp/gbs-home/.gbs.conf、/etc/gbs.conf不存在、所需系统工具、-j10不超过nproc一半。拒绝未经核验的Git/XDG/buildroot环境覆盖；打印现有gbs/depanneur/build进程但不操作。独占文件锁防止重复启动；已有r2日志或status时失败退出，保留现场，不自动覆盖、重试或清理buildroot。

sudo源码证据见[sudo_call_audit.txt](../evidence/task2/sudo_call_audit.txt)：

- /usr/bin/depanneur:2048拼出 `sudo /usr/bin/build`，没有-n/-S/-A；397–422的my_system用fork/exec调用并等待。
- :3164–3174启动认证维持逻辑，执行 `sudo /bin/echo -n`；:84的周期是3*60秒。这里是GBS工具自身的行为，不是本脚本额外sudo保活。
- :2247等还存在工具自身的复制/挂载/chroot调用；不能把本脚本“只有sudo -v”误读成整套GBS只会调用一次sudo。

因为工具使用普通sudo，非root用户在后台前执行**一次 `/usr/bin/sudo -v`**：缓存有效或策略免密时不提示；需要认证时由用户在前台输入密码。root跳过。脚本不另用sudo -n/-l等探测、不强制重新输入、不索要/记录密码，也没有其他sudo命令。缓存是否有效无法在“不调用其他sudo”的约束下提前可靠判定，交由这一次-v按本机策略决定是否需要交互。

后台采用Bash job control创建独立进程组，保留前台sudo验证所在的登录session/控制终端，没有使用setsid。depanneur自带的sudo认证维持（3分钟周期，/usr/bin/depanneur:3164–3174，周期常量见:84）依赖启动时的控制终端；建议用户在 **tmux或screen** 中运行，避免SSH断开导致后续sudo失败。认证缓存的时效、sudo策略和导出耗时仍可能影响后续调用；没有通过修改sudoers、askpass或凭据文件保证后台认证。如果后台进程进入停止态（例如需要读终端），脚本只记录并等待5分钟，仍未退出则失败报告，不发信号。

### 后台阶段及判定

| 阶段 | 动作 | 失败/停止条件 |
| --- | --- | --- |
| export | 指定HOME环境执行gbs export，用strace保存open/openat/mkdir/mkdirat；附加-yy、长字符串以及chdir/fchdir/fork/clone跟踪，供解析FD真实路径、相对mkdir的cwd继承 | 命令非零、残留不退出、直接观察到越界输出，或a/b/c审计不通过，跳过两个构建 |
| export审计 | temp/export_check_home.txt逐项列a配置路径、b其他外部成功打开路径、c成功创建目录，均去重；原始调用留在export_check.strace | a全部在WS；c全部在WS；b只允许脚本明确列举的系统运行时文件（加载器、NSS、locale、时区、主机解析、TLS证书、PAM/sudo运行时等）。无法解析、截断/转义不明、缺少覆盖证据均失败，不猜路径 |
| export清理 | 仅在导出和审计通过、路径验证后删除本次temp/export_check | 不删除/移动任何工作区外文件；不清理其他任务的产物 |
| gcc | touch标记；指定HOME环境、time -v、GCC conf、armv7l、threads1、-j10 | 构建非零、已证实越界、残留超过5分钟或脚本收到中断，跳过LLVM |
| llvm | GCC阶段完全通过后，使用LLVM conf执行相同流程 | 同上；完成构建不等于已确认内核确实由Clang编译 |
| 收尾 | 汇总每阶段结果/退出码/起止时间；EXIT/INT/TERM/HUP trap尽力维护状态 | 最后一行ALL-END带OK或FAILED at阶段；未开始阶段标SKIPPED，时间/退出码为- |

导出审计只统计成功open和成功mkdir；失败的访问尝试仍留在原始strace。配置分类包含文件名中的gbs.conf/gitconfig/rpmmacros；真实FD路径靠-yy解析，包含设备附加信息时取路径部分。新增进程/cwd系统调用仅用于准确归属路径，不改变GBS参数或源码。审计通过仅覆盖此次导出，不能外推后续sudo/chroot内所有文件访问。

每个受管命令启动前记录进程表，启动后记录独立PGID，结束后只查同一组；有残留先等待最多300秒，仍存在则停止报告。脚本没有kill/pkill或sudo清理。运行中每15秒尽力读取该组stdout/stderr的/proc FD路径；已观察到的工作区外普通文件输出路径只记录，不中断当前命令，自然结束后判失败。无权限读取的root FD不能据此证明没有越界。

两次构建结束后均运行PM指定find命令（真实/home/linhao、maxdepth3、当前用户、newer标记），原始路径写入 `<gcc|llvm>_r2.external_paths.txt`，分类写入external_review.txt。并行任务无法只凭名字与时间区分，名称类似gbs/depanneur/GBS-ROOT的也标“疑似构建相关，无法归属”；不会把它们武断归为本任务或删除。只有本进程组直接输出路径证据才作为已证实越界判失败。find的退出码也记录；权限过滤、扫描深度及已删除文件限制意味着空结果不是全机无越界证明。

### 日志、状态与中断

- 总日志：temp/run_baseline_build.log；状态：temp/run_baseline_build.status。前台预检失败通常写正式status；重复启动/已有日志的失败另写preflight.<PID>.status，避免覆盖既有任务。temp不可写等极早失败会把ALL-END打印到终端，无法保证写文件。
- 实时子进程输出：temp/export_check.log.raw、temp/build_gcc_r2.log.raw、temp/build_llvm_r2.log.raw。正式export_check.log/build_*_r2.log在阶段收尾时汇入raw内容；正常完成时是完整命令输出及time -v。用户应tail实时raw文件，脚本末尾给出完整命令。
- 正式build_*_r2.log末行为 `BUILD-END <gcc|llvm> <时间> exit=<退出码>`。若仍有残留，先注明INCOMPLETE，此码是监督程序失败码（125），不是伪造的命令退出码；raw保留给残留继续输出，正式日志仍以BUILD-END结束。此时不能声称原始输出已经封存。
- 状态采用同目录临时文件+mv更新；末行 `ALL-END <时间> <OK|FAILED at 阶段名>`，表示监督流程结束。若有残留，另外标ACTIVE-OR-RESIDUAL PGID，ALL-END不是全部后代进程退出的证明。
- 收到可捕获中断时不向子进程转发信号，等待在跑命令自然结束，再失败收尾并跳过后续阶段；停止态/残留按5分钟规则处理。SIGKILL、断电或磁盘不可写无法由trap保证落盘。脚本本轮仅通过bash -n与静态检查，运行效果尚未实测。

预计总耗时**粗估2–8小时**：两轮依赖初始化按上次约4分钟/轮，另加源码导出，以及GCC/LLVM各普通版和RT版共4次内核构建。没有成功完整构建的实测基线，这不是承诺或测量值；其他编译任务、网络与缓存会改变耗时。

用户执行完成并告知后，再核验编译器、四份.config、体积/开销，复核04的布局条件，并补齐05的平台llvm-bolt支持架构。当前不填写这些未取得结果。

## 最新任务2续二：源码核对、准备与静态成果

PM已明确采用工作区HOME方案，并排除修改源码.gbs.conf/exclude、独立工具副本及专属隔离环境；这些旧方案不再是待决事项。裁决已原文写入RULES两条硬要求之后。

- 源码核对确认用户配置由expanduser定位；已安装Python有HOME时优先使用HOME。gbs build→os.system→depanneur fork/exec→gbs export链未发现清空或重设HOME/GIT_CONFIG_NOSYSTEM。新方案能修正此前的用户配置来源，但这只是源码判断，尚无strace通过结果。完整路径清单与行号见[home_source_audit.md](../evidence/task2/home_source_audit.md)。
- 步骤2已完成：temp/gbs-home/.gbs.conf为两行普通文件；linux-rpi/.gbs.conf未改，base仍为f240c280、tizen仍42aeefac，工作树干净。见[准备记录](../evidence/task2/home_preparation.txt)。
- **导出/构建未执行：当前代理执行环境禁止重设HOME，无法执行PM规定命令。** 没有运行不带指定变量的GBS，也没有用替代方式绕过。此限制不是GBS或源码方案失败，不向PM重复请求已完成的方案裁决。
- 没有export_check_home.txt或r2日志、没有marker/find监测，没有实际打开配置路径清单；未发生本轮构建中断，未发送信号或调用sudo。不能声称“未检测到工作区外写入”或“导出通过”。
- 已继续独立步骤6：zram接口与ARM32布局推导、三条LZ4无冲突合入检查及临时分支删除、字典脚本全文与源码片段、Kconfig/DTS/perf静态核对。详见[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)。
- LLVM是否确为Clang、四份最终.config、01修正符号数、两次完整耗时及vmlinux/zImage差值仍未取得。旧GCC的5:37.12/exit143是前轮人为中断尝试，不移用为本轮数据。平台LLVM工具版本和BOLT支持架构未确认。

以下保留上一轮与最初任务的历史记录，不能据此启动已被PM排除的方案。

## 本轮续任务：步骤A完成，步骤B停止（2026-10-27）

- 已按要求仅修改base标题为 `mm: restore vendor reclaim semantics for force_reclaim`；新SHA `f240c28093027707f5e09f8a9cbbed16a43ebb1a`。原tree、parent、作者/日期、提交者/日期、正文均逐字验证相同，`git diff 563c53c4 f240c2809302`为空，tizen未变且工作树干净。证据：[base_amend_r2.txt](../evidence/task2/base_amend_r2.txt)。初次amend被已有hook追加Change-Id，验证发现后用命令级工作区空hooks目录重新amend，最终正文严格保持原样；没有改全局配置或原hook。
- **项目.gbs.conf静态可见，但原GBS不能仅通过-c/项目键禁用外部配置文件加载。** `/etc/gbs.conf`不存在，`~/.gbs.conf`存在；只有5个键，无凭据键。当前build使用的profile/buildroot已有本项目覆盖，外部仓库节不选用；export不使用这些构建键。两个项目conf本轮新增覆盖0个键。
- `conf.py:318–321`仍逐个读取自动发现的文件，`add_conf`只插入更高优先层。按最前面的“不使用工作目录以外的文件”要求，不能把“当前外部值未影响构建”视为“没有使用外部配置文件”。因此停在B，未执行C/D/E；这是文件级隔离问题，不是未覆盖键或tmpdir不可见问题。
- 完整查找顺序、合并规则、depanneur的cwd和根目录补读、逐键影响与替代方案均见[配置审计](../evidence/task2/gbs_config_audit_r2.md)，原始工具行号见[源码证据](../evidence/task2/gbs_config_source_r2.txt)。替代方案只列供PM裁决，未自行采用。
- 未改写既有受跟踪linux-rpi/.gbs.conf或添加exclude项，未运行独立导出或strace，未生成export_check.txt，未开始r2 GCC/LLVM。因此没有本轮外部写入监测、编译器、体积、耗时、最终.config或符号修正数，不将这些写成0或通过。
- 步骤C另有前提：linux-rpi/.gbs.conf已受Git跟踪，包含3个导出键；改成两行后无法靠exclude保持干净。本轮保持原样，未使用assume-unchanged/skip-worktree掩盖差异。见[existing_project_gbs_r2.txt](../evidence/task2/existing_project_gbs_r2.txt)。
- 前轮日志/结果原样保留。以下第1–5节为原 `563c53c4` 的历史执行记录，不代表新SHA已构建。新增处置规则已写到RULES最前及末尾：越界写入发现后等待自然结束，不发信号；残留先等5分钟，不sudo、不操作其他任务。

## 1. lko/base

- 起点：tizen@42aeefac58edeb081aff440f0b60be71cbe49755。
- 本地基线：lko/base@563c53c427bff4d685d18544a8f4f6db14be9368。
- 按PM指定执行 `cherry-pick -n a9cc39b8dd1d`，随后 restore 两个架构的 tizen_bcm2711_defconfig，只提交 mm/memcontrol-v1.c。
- 作者保留 He Fangyu <fangyu.he@samsung.com>，作者日期2026-10-19；提交者 Hao Lin <hao.lin@samsung.com>，使用命令级 git -c user.name/user.email。
- 提交正文保留原文并删除 zram backend 段，末尾追加PM指定拆分说明。标题按“保留原文”仍含 zram 字样，**实际 diff 不含任何 zram 配置或驱动文件**。
- `git diff 42aeefac lko/base --stat`：仅 mm/memcontrol-v1.c，22 insertions、7 deletions。完整 [base_diff.txt](../evidence/task2/base_diff.txt)、[base_commit.txt](../evidence/task2/base_commit.txt)。
- 已上传函数前后各20行：[快照索引](../code_snapshots/INDEX.md)，原始文件2405–2486行。

## 2. 构建命令与环境

仅构建已提交的lko/base，不使用 --include-all；普通和RT由spec自身的两个target循环产生。nproc=20；GBS包级threads=1，包内make并行-j10；GCC与LLVM串行，遇任一失败停止，不自动修改spec/代码或重试。不构建aarch64，不碰开发板。

```bash
export TMPDIR=/home/linhao/Toolchain/development/linux_kernel_optimization/temp
cd /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi
/usr/bin/time -v gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_gcc.conf build -A armv7l --threads 1 --define '_smp_mflags -j10'
/usr/bin/time -v gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -A armv7l --threads 1 --define '_smp_mflags -j10'
```

两个命令以上述顺序按停止条件执行，命令列出不代表都已运行。后台管理进程将完整输出和time -v写到 `$WS/temp/build_<gcc|llvm>.log`，最后一行为 `BUILD-END <kind> <Asia/Shanghai时间> exit=<退出码>`。后台无交互stdin；日志监视器遇凭据请求停止，不输入密码、不配置askpass、不绕过sudo。

必要的项目配置调整：两个gbs.conf在[general]新增 `tmpdir=$WS/temp`。原因：已安装的GBS `gitbuildsys/conf.py:196`默认tmpdir为/var/tmp，`cmd_build.py:814`使用自身配置值，不读取环境TMPDIR覆盖；只有export TMPDIR不够。未改变repo URL、buildroot或工具链选择，未改spec。证据：[gbs_tempdir_adjustment.txt](../evidence/task2/gbs_tempdir_adjustment.txt)。

## 3. 构建结果

**本次停止于 GCC 源码准备/依赖初始化阶段；未完成任何内核构建。LLVM未启动。**

| 项目 | GCC | LLVM |
| --- | --- | --- |
| 主命令开始 | 2026-10-27 14:14:17 +08:00 | 未启动 |
| 主命令结束 | 2026-10-27 14:19:54 +08:00 | 未启动 |
| 退出码 | **143（SIGTERM）** | 不适用 |
| time -v 墙钟 | **5:37.12**（失败尝试，不是完整构建耗时） | 无 |
| time -v Maximum RSS | **100088 KiB**；中途杀父/子进程，子进程统计不完整，不能用作正常构建峰值比较 | 无 |
| 是否进入内核编译 | 没有；日志只到源码导出与依赖下载/初始化 | 没有 |
| sudo/凭据 | GBS此前已启动root初始化子进程；残留进程清理时sudo -n返回“a password is required”，此后停止所有sudo尝试 | 未启动 |

原始build_gcc_result.json的credential_stop=false仅表示后台runner结束前未匹配凭据提示；sudo清理要求密码发生在runner结束后，另记录于build_stop_reason.txt，不能把false解释为全程未遇凭据要求。

GNU time同时打印 `Command terminated by signal 15` 与 `Exit status: 0`；这里采用实际子进程返回码143及信号记录，**不能把后者误读为构建成功**。原始结果见 [build_gcc_result.json](../evidence/task2/build_gcc_result.json)，完整封存日志见 [build_gcc_log.txt](../evidence/task2/build_gcc_log.txt)（含主进程结束后残留初始化输出，最终末行重写为原主命令的BUILD-END；不是新的构建尝试）。中止原因见 [build_stop_reason.txt](../evidence/task2/build_stop_reason.txt)。

### 3.1 中止原因与已发生的目录越界

预检发现GBS自己的tmpdir默认/var/tmp，因此两个项目conf加了tmpdir。但这只修正了顶层gbs build的仓库缓存位置，**没有解决嵌套gbs export**。本次仍实际发生越界临时写入，不能声称全程满足目录约束。

2026-10-27 14:18:55，读取压缩进程 `/proc/116876/fd/1` 得到 `/var/tmp/.gbs_export_4d01tubn/linux-kernel-6.12.80.tar.xz`，立即对构建进程组116650发送SIGINT。后台进程继承了忽略SIGINT的行为，首次信号没有及时终止；在确认仍运行后发送SIGTERM终止可控子进程和gbs主进程。在此期间GBS完成导出并进入了root依赖初始化。

残留root初始化/下载进程拒绝普通kill；为结束本任务创建的残留进程，仅尝试一次 `sudo -n /bin/kill -KILL -- <该进程组的残留PID>`，返回 `sudo: a password is required`。按PM硬规则立即停止一切sudo尝试，未提供凭据、未使用askpass、未换方式绕过。已通知PM需要本机处理该组残留进程。随后于2026-10-27 14:24:16只读复查确认PGID 116650已无活跃进程；残留进程自行完成了依赖初始化，没有进入内核编译，不再需要PM终止。本任务未因此恢复构建。实际PID/状态见 [residual_state.txt](../evidence/task2/residual_state.txt)，停止尝试完整记录见 [build_stop_reason.txt](../evidence/task2/build_stop_reason.txt)。

只读复查发现上述/var/tmp导出目录已由工具正常导出结束时自行移除；本任务没有删除/移动工作区外文件。源tar等随后已放入WS/temp的GBS路径。目录曾存在的事实保留，不因已消失而抹去。

### 3.2 静态根因证据

1. `/usr/bin/depanneur:788–824` 拼出 `gbs export ... --commit=HEAD ...`，**没有传入顶层的 `-c config/gbs_gcc.conf`**。
2. 实际进程命令也为 `gbs export <linux-rpi> -o <WS/temp/...> --outdir-directly --spec linux-rpi.spec --commit=HEAD ...`，没有-c。输出目录-o在temp，不等于导出中间目录也在temp。
3. `gitbuildsys/cmd_export.py:298–300` 从 `configmgr.get('tmpdir','general')` 构造 `.gbs_export_`，没有以环境TMPDIR替代；`gitbuildsys/conf.py:196` 的默认值就是/var/tmp。

带行号工具代码见 [gbs_export_root_cause.txt](../evidence/task2/gbs_export_root_cause.txt)。这是本次外层配置没有传递到导出子进程的可证链条；未修改已安装GBS/depanneur、未向源码加.gbs.conf、未重试构建。下一次执行前须由PM确定配置传播方案；残留进程按PM新规则等待5分钟，仍存在则停止报告，不尝试sudo、不操作其他任务进程。

### 3.3 PM后续确认：退出归因与完整日志封存

**归因：本次主构建命令被执行者主动中断，不是GBS正常完成，也不是已发现的内核编译错误。** 触发中断的是3.1节所述导出中间文件写入工作区外。SIGINT未及时奏效后，执行者向本任务gbs/depanneur等进程发送SIGTERM；[停止记录](../evidence/task2/build_stop_reason.txt)列出目标PID及结果。完整日志第63行是 `Command terminated by signal 15`，第91行已记录 `BUILD-END gcc 2026-10-27T14:19:54+08:00 exit=143`，与[runner结果](../evidence/task2/build_gcc_result.json)一致。143对应128+SIGTERM(15)。

主命令退出时，部分root子进程未能被普通信号操作终止，仍持有同一日志输出文件并继续下载/安装依赖，因此其输出出现在首次BUILD-END之后。主命令被信号终止不等于所有后代进程同步退出；这解释了两者结束时间不同，不能将此现象解释成GBS构建成功后正常后台下载。日志最后50行仅能证明依赖初始化到了 `now finalizing build dir...`；退出原因必须结合第63行、runner返回码和信号操作记录判断。

PM随后确认：PGID116650已无任何进程，用户没有执行kill，残留自行退出，temp下无残留挂载。2026-10-27 14:44:40 +08:00再次只读核验也未发现该PGID进程或当前挂载命名空间内temp下的挂载，见[封存复核](../evidence/task2/build_closure_recheck.txt)。本次跟进未发送信号、未调用sudo、未启动任何构建，也未影响其他编译任务。

完整日志仍为532行、48259字节，本地与上传副本字节一致，SHA-256为 `3157116b9e9b5f8d6822103ff5adf4d4e1b6f2f8fa13ff2dae277bc82bfc401a`；没有截掉主命令退出后输出，也没有再次改写已封存日志。末行的时间表示原主命令退出时间，封存时间另由前一行TASK2-LOG-SEAL说明。以下逐字引用[最后50行](../evidence/task2/build_gcc_last50.txt)，对应完整日志第483–532行：

```text
[  220s] pkg-config-0.29.2-3.27                ########################################
[  220s] sed-4.1c-5.24                         ########################################
[  221s] util-linux-2.41.2-2.19                ########################################
[  221s] libatomic-14.2.0-4.30                 ########################################
[  221s] libunwind-devel-1.6.2-2.5             ########################################
[  221s] build-20120927-2.1                    ########################################
[  221s] python3-3.14.2-5.34                   ########################################
[  221s] libtool-2.5.4-4.4                     ########################################
[  221s] kmod-compat-34.2-2.1                  ########################################
[  221s] libncurses-6.6-4.5                    ########################################
[  221s] libdw-devel-0.189-1.101               ########################################
[  221s] binutils-devel-2.43-3.29              ########################################
[  221s] libopenssl3-devel-3.5.9-1.6           ########################################
[  222s] libstdc++-devel-14.2.0-4.30           ########################################
[  222s] app-rootstrap-checker-1.0.0-4.1       ########################################
[  222s] build-compare-2023.06.18-1.42         ########################################
[  222s] hal-rootstrap-checker-1.0.0-11.1      ########################################
[  223s] qemu-linux-user-x86_64-cross-9.2.3.1-4########################################
[  223s] gcc-14.2.0-4.30                       ########################################
[  227s] qemu-accel-x86_64-armv7l-0.4-6.4      ########################################
[  228s] util-linux-su-2.41.2-2.19             ########################################
[  228s] rpm-build-4.14.1.1-7.3                ########################################
[  228s] grep-2.5.2-4.2                        ########################################
[  228s] tar-1.17-5.1                          ########################################
[  228s] rsync-3.4.1-1                         ########################################
[  228s] elfutils-0.189-1.101                  ########################################
[  228s] dwarves-1.29-1                        ########################################
[  228s] bc-1.06-2.1                           ########################################
[  228s] less-685-2.1                          ########################################
[  228s] tzdata-2026d-1.1                      ########################################
[  228s] glibc-locale-2.40-16.8                ########################################
[  228s] which-2.17-11.1                       ########################################
[  228s] smack-1.3.1-2.21                      ########################################
[  228s] flex-2.6.4-1.89                       ########################################
[  228s] bison-3.0.5-2.69                      ########################################
[  228s] file-5.46-1.73                        ########################################
[  228s] cpp-14.2.0-4.30                       ########################################
[  228s] gcc-c++-14.2.0-4.30                   ########################################
[  228s] dash-0.5.13.4-1.2                     ########################################
[  228s] gawk-3.1.5-3.1                        ########################################
[  228s] cpio-2.8-2.2                          ########################################
[  228s] diffutils-3.10-2.1                    ########################################
[  228s] hostname-3.23-1.3                     ########################################
[  228s] net-tools-2.0_20121208git-1.62        ########################################
[  228s] update-alternatives-1.22.21-2.1       ########################################
[  229s] removing nis flags from /home/linhao/Toolchain/development/linux_kernel_optimization/temp/GBS-ROOT-TOOLCHAIN-GCC-CODES/local/BUILD-ROOTS/scratch.armv7l.0/etc/nsswitch.conf...
[  229s] now finalizing build dir...

TASK2-LOG-SEAL: 2026-10-27T14:24:16+08:00 read-only check found no live PGID 116650 processes. Orphan initialization output after the earlier BUILD-END was retained. No kernel compilation and no retry.
BUILD-END gcc 2026-10-27T14:19:54+08:00 exit=143
```

**处置：按未成功构建停止，LLVM及后续依赖成功产物的步骤均不继续。** 后续每次构建前后核对本次进程组；如有残留，先等待5分钟，仍存在则停止报告，禁止sudo清理或操作其他任务进程。规则已写入RULES.md。

## 4. 实际编译器与最终 .config：未取得

- GCC的LLVM=1/CC=/LD=编译调用、include/generated/compile.h、vmlinux .comment均未产生可用证据。未将依赖下载URL里的gcc包名冒充已安装编译器RPM清单。
- **gbs_llvm.conf未执行，因此不能确认内核由Clang编译，也不能断言它实际上使用GCC。**
- 没有4份最终.config；没有运行scripts/diffconfig；01第3节逐符号实测对照未执行，**改正符号数未得，不记为“0个错误”**。
- HZ、PREEMPT*、KALLSYMS_ALL、DEBUG_INFO_BTF*、STACKPROTECTOR*、TRACE_IRQFLAGS、PREEMPTIRQ_TRACEPOINTS、LRU_GEN_WALKS_MMU、CORESIGHT*、PERF_EVENTS、HW_PERF_EVENTS都尚无本轮最终.config核验值。

## 5. 体积与开销：不可比较

| 请求指标 | 本轮结果 |
| --- | --- |
| GCC/LLVM zImage字节数及差值 | 未产生，不能计算 |
| vmlinux text/rodata/data/bss与差值 | 未产生，未调用宿主size/readelf等替代 |
| 模块数量/总大小、kallsyms符号数 | 未产生 |
| bloat-o-meter前30项 | 没有成对vmlinux，未运行 |
| kallsyms、__mcount_loc/ftrace段占用 | 没有vmlinux，未运行 |
| 完整构建时间/RSS对照 | 没有；只有上表失败主命令的wall/RSS，且RSS统计不完整 |
| buildroot磁盘占用、产出RPM总大小 | 主命令中止后残留依赖初始化自行结束；只有不完整buildroot/下载依赖，不是成功内核产物，未给出误导性完整构建数值 |

以上待办只能在PM安排恢复任务、成功完成两次串行构建并核验工具链后继续；构建产物分析只用GBS buildroot平台工具。
