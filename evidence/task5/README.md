# 任务5证据索引

2026-10-29经SDB采集RPi4。报告见[09](../../docs/09_board_rpi4_readonly.md)。原始输出保留在`temp/task5/`；这里是带原始行号的选段、汇总表及解析方法，全部为UTF-8文本、单个文件小于1MB。ELF仅留本地。

| 文件 | 内容 |
| --- | --- |
| [commands.txt](commands.txt) | 全部44个记录的SDB调用及此前connect/devices；shell命令包含完整循环和条件分支，没有推送脚本 |
| [session_and_cleanup.txt](session_and_cleanup.txt) | 身份/root、前后uptime与精简进程表、临时目录删除及owner恢复 |
| [A_identity_memory.txt](A_identity_memory.txt) | uname/compiler、OS、cmdline、meminfo、zone、dmesg及iomem |
| [QB_1211696_access.txt](QB_1211696_access.txt) | PM补充构建号/链接；匿名访问302到登录页，源码SHA、构建时间及配置仍未核实 |
| [A_config_comparison.txt](A_config_comparison.txt) | 配置核对未完成的确切原因、失败输出、应比较的LLVM基准哈希；没有执行diffconfig |
| [B_bpf_runtime.txt](B_bpf_runtime.txt) | BTF大小、bpffs、FD与maps快照、resourced搜索 |
| [B_elf_btf_analysis.txt](B_elf_btf_analysis.txt) | RPM依赖、平台readelf的父ARM及内嵌BPF ELF结果，CO-RE静态依赖 |
| [B_embedded_method.txt](B_embedded_method.txt) | 平台objcopy命令、原字节定位、BTF.ext头及带行号的格式/机制参考 |
| [C_debug_usage.txt](C_debug_usage.txt) | 追踪开关、过滤器、实例、latencytop、kgdboc、启动文件搜索 |
| [D_filesystem_usage.txt](D_filesystem_usage.txt) | mounts/filesystems、相关mount单元、分区、无缓存blkid、工具包 |
| [E_usb_usage.txt](E_usb_usage.txt) | USB设备与绑定、lsmod、网口、声卡；不将module链接计为设备 |
| [F_memory_runtime.txt](F_memory_runtime.txt) | MGLRU、zram、swap、全部可读vm sysctl、PSI及部分vmstat |
| [F_resourced_config.txt](F_resourced_config.txt) | 请求的配置全文、service/socket和受限日志；zstd配置与lzo-rle运行差异 |
| [F_memcg_table.txt](F_memcg_table.txt) | v1层级、67个目录的limit/usage/force_reclaim存在性 |
| [F_top30_processes.tsv](F_top30_processes.tsv) | VmRSS排序前30进程及Anon/File/Swap，单位KiB |
| [G_pmu_perf.txt](G_pmu_perf.txt) | PMU驱动正向证据；perf四命令退出127；无CoreSight/ETM节点 |
| [H_scheduler_clock.txt](H_scheduler_clock.txt) | cpufreq、cpuidle缺失、全部sched sysctl、jiffies时间差 |
| [raw_manifest.tsv](raw_manifest.tsv) | 全部本地原始输出与解析产物的字节数、行数、SHA-256；二进制明确标local-only |
| [manifest.sha256](manifest.sha256) | 本目录最终发布文本的SHA-256（不含清单自身） |

注意：传输退出0仅证明SDB请求成功；命令块的COLLECT-END仅为最后命令退出码，不能覆盖中间缺失文件、grep或perf错误。所有失败都按事实报告，没有用空输出伪装“配置相同”或“硬件事件成功”。
