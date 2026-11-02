# PB1：产品板只读探测（2026-11-02）

## 设计 v4 待产品板复核项 → 本次实测值

| 设计位置 / 复核项 | 产品板实测值及边界 | 证据（均为脱敏文本） |
|---|---|---|
| 2.3 / 3.3：低端内存与分区 | LowTotal 563,132 KiB（549.934 MiB）；Normal managed 140,783 页，另有 HighMem、独立 CMA 区；不能套用 RPi4 的 DMA/CMA 关系 | [meminfo](../evidence/pb1/03_meminfo.txt)、[zoneinfo](../evidence/pb1/03_zoneinfo.txt) |
| 2.3 / 3.3.6：CMA | 304 MiB，CmaFree 6,220 KiB；CmaUsed-DMA 2,724 KiB、CmaUsed-USER 302,352 KiB；仅一次快照，未测播放/切台峰值 | [meminfo](../evidence/pb1/03_meminfo.txt)、[启动摘录](../evidence/pb1/03_dmesg.txt) |
| 3.3.1：跨区保护 | ratio 为 `32 2147483647 2147483647 2147483647`；Normal protection 为 `(0, 3840, 3840, 3840)` 页；min_free_kbytes=3000 | [VM参数](../evidence/pb1/04_vm_params.txt)、[zoneinfo](../evidence/pb1/03_zoneinfo.txt) |
| 3.3.2：vmalloc 余量 | cmdline `vmalloc=300M`；自定义 VmallocUsedVirt 122,944 KiB；空洞总计205,188 KiB，最大179,304 KiB；ioremap占47,548 KiB | [cmdline](../evidence/pb1/01_cmdline.txt)、[vmalloc汇总](../evidence/pb1/03_vmallocinfo.txt) |
| 3.3.3：VMSPLIT / LPAE / 大进程映射 | 没有最终配置，无法确认 VMSPLIT、PAGE_OFFSET、ARM_LPAE；CPU features 含 lpae 不等于内核配置已启用；本轮未采全部映射 | [配置缺口](../evidence/pb1/02_config_comparison.txt)、[cpuinfo](../evidence/pb1/08_cpuinfo.txt) |
| 3.3.4：SWIOTLB | 当前cmdline未见显式`swiotlb=`；池大小、动态扩展和回弹高水位未取得，不能据此断言未使用 | [cmdline](../evidence/pb1/01_cmdline.txt) |
| 3.3.5：slab | Slab 82,536 KiB、SUnreclaim 53,304 KiB；已汇总103个cache及前30名；没有调整partial或shrink | [meminfo](../evidence/pb1/03_meminfo.txt)、[slab前30](../evidence/pb1/03_slabinfo.txt) |
| 3.3.7：主动整理 | compaction_proactiveness=85；THP enabled接口不存在；本轮不改变参数，不推断THP配置 | [VM参数](../evidence/pb1/04_vm_params.txt)、[MM接口](../evidence/pb1/04_mm_state.txt) |
| 3.4.1–2：zram算法和重压缩 | 主算法`lz4 [zstd]`；重压缩`#1: lz4 [zstd]`；当前确为zstd；不能据此认定后台重压缩已实际执行 | [zram](../evidence/pb1/04_zram.txt) |
| 3.4.3：zram成本 | disksize 1,065,132,032 B；mm_stat前3值为2,191,360 / 546,821 / 2,916,352 B；槽表、ACTIME、字典、工作区的实际布局及物理分区未知 | [zram](../evidence/pb1/04_zram.txt)、[meminfo](../evidence/pb1/03_meminfo.txt) |
| 3.5：MGLRU / TTL / 压力 | enabled=0x0001、min_ttl_ms=0；PSI存在，厂商字段为avg2/avg6/avg10；回收补丁、MMU walks配置未取得 | [MM接口](../evidence/pb1/04_mm_state.txt)、[PSI](../evidence/pb1/04_pressure.txt)、[vmstat](../evidence/pb1/04_vmstat.txt) |
| 第6章：BTF与训练能力 | `/sys/kernel/btf`不存在；tracefs已挂载、available_tracers仅nop，function profiler接口不存在；未尝试加载程序或开启追踪 | [BTF](../evidence/pb1/05_btf.txt)、[tracing](../evidence/pb1/07_tracing.txt)、[profiler](../evidence/pb1/07_profiler_presence.txt) |
| 第6章：CPU / PMU / CoreSight | 4核，implementer0x41 / part0xd03，armv7l；事件源目录包含armv7_cortex_a7；CoreSight设备目录不存在；未运行perf，不能确认硬件计数/分支采样是否可用 | [cpuinfo](../evidence/pb1/08_cpuinfo.txt)、[事件源](../evidence/pb1/08_pmu_coresight.txt) |
| 第6章：产品裁剪和文件系统适用性 | 根底层EROFS+overlay，/opt为VDFS，另有SquashFS；不能照搬RPi4 F2FS相关裁剪结论；BOM、恢复/升级依赖未知 | [挂载](../evidence/pb1/06_mounts.txt)、[文件系统](../evidence/pb1/06_filesystems.txt) |
| 第6章：标准场景、并行任务与启动时间 | 不是已确认的空闲基线；344进程/1253线程，采集约在开机100–110秒；multi-user/graphical约34.053秒。未做重启或场景实验 | [进程汇总](../evidence/pb1/09_process_status.txt)、[uptime](../evidence/pb1/10_end_uptime.txt)、[targets](../evidence/pb1/10_units.txt) |

## 范围、身份与数据完整性

三项断言通过：`uname -m=armv7l`、`/etc/os-release`为Tizen 10.0.0、`uname -r=6.12.60`且不含rpi4。产品板替代相同IP上的RPi4；**RPi4常规授权不适用于产品板**。全程仅读取现有接口，未推送文件、写板上文件、修改参数、启动/停止服务、安装包、重启、remount或向板上进程发信号；没有创建板上临时目录。

`/proc/version`明确给出 **clang version 22.1.8、LLD 22.1.8**，因此本次运行内核是LLVM/Clang构建。不能据此把所有用户态包也判为Clang构建。内核编译时间2026-10-30 16:39:29 UTC；构建信息文件Type=eng、Variant=NONE、Date=20261030_220834。机型、项目标识、构建标识、主机名、序列号均不入库。两份构建信息文件都存在，脱敏后保存。[版本](../evidence/pb1/01_version.txt)、[镜像信息](../evidence/pb1/01_buildfiles.txt)、[系统身份](../evidence/pb1/r2_identity_os_release.txt)。

先按授权disconnect/connect流程清除旧连接：连续3轮失败且TCP可连、设备列表无其他设备后，执行一次宿主SDB kill-server/start-server；第5轮连接成功。首次批量读取随后遇到transport=1，未取得数据；保留失败原文后重新连接，r2第1轮成功。总共仅一次宿主SDB服务重启，没有操作板上服务。主要采集窗口为宿主2026-11-02 23:15:41–23:15:52 +0800；补充接口检查至23:32。宿主时间与板上墙钟没有校准，不混用。初始root可用，读取需要权限的内存接口成功；最终再次root off，回读uid=5001。[连接及逐命令记录](../evidence/pb1/00_connection_and_commands.json)、[最终身份](../evidence/pb1/99_owner_final.txt)。

每个宿主原文在`temp/pb1/`或`temp/pb1/r2/`，不提交。入库证据含命令、宿主时间、transport退出码、远端退出码及原文SHA-256。循环内每个读取另有CMD/RC；外层REMOTE_EXIT=0并不代表其中所有文件都可读。动态进程读取原文和名称对照仅留temp。输出均未超过2MB，仍只提交必要的脱敏文本/摘要。

## 与 RPi4 的主要差异

产品`/proc/config.gz`不存在（ls退出2、可读测试退出1），`/boot`目录可列出但为空，未找到config文件。因此**无法运行最终.config的全文diff，也无法给出经配置证实的“差异最大前10项”**。没有从接口缺失推导CONFIG=n。已将所需符号展开为149行，产品列均写UNKNOWN_CONFIG_UNAVAILABLE，RPi列取自QB1211696的最终配置；USB只给RPi的=y/=m类别统计，产品配置未知。[选项对照](../evidence/pb1/02_config_options.tsv)、[缺口及USB类别](../evidence/pb1/02_config_comparison.txt)、[RPi配置](../evidence/task5b/qb_arm-rpi4.config)。产品特有而RPi未列出的符号也无法从缺失配置中枚举。

以下是对设计影响较大的**10项版本/运行时/布局差异，不冒充Kconfig差异排名**。RPi数字来自任务5静置样本和设计v4，不是与产品同负载的A/B性能比较。

| # | 项目 | 产品板 | RPi4 | 依据/限制 |
|---|---|---|---|---|
| 1 | 内核版本 | 6.12.60，Clang/LLD22.1.8 | 6.12.80，Clang22.1.8 | 两者源码补丁集合未比较 |
| 2 | 总量/低端内存 | MemTotal1,600,700 / LowTotal563,132 KiB | 3,976,476 / 711,964 KiB | 产品LowTotal少148,832 KiB（145.344 MiB） |
| 3 | 低端区与CMA | Normal低端；独立CMA区；CmaTotal304MiB | 低端全在DMA；CMA320MiB包含在其中 | 不可移植LowTotal−CMA公式 |
| 4 | vmalloc | 参数300M；UsedVirt122,944 KiB，ioremap47,548 KiB | VmallocTotal240MiB、VmallocUsed21,208 KiB | UsedVirt与VmallocUsed口径不同，不能直接算增量 |
| 5 | 跨区/水位 | ratio32/INT_MAX/INT_MAX/INT_MAX；minfree3000 | ratio256/32/0/0；minfree3334 | 区序/厂商算法不同，不能直接比较保护倍数 |
| 6 | zram | zstd，1015.789MiB，有recomp_algorithm | lzo-rle，1553.3125MiB，无该接口 | 产品未证明后台重压缩活动 |
| 7 | 回收/整理参数 | swappiness100、compaction_proactiveness85 | 60、20 | 仅记录，不改参数、不判收益 |
| 8 | BTF | 无/sys/kernel/btf | vmlinux BTF 6,478,350 B，DEBUG_INFO_BTF=y | 产品CONFIG值仍未知 |
| 9 | function profiler | tracefs可读但接口缺失，tracer仅nop | 最终配置FUNCTION_PROFILER=y | 不能把RPi训练机制视为产品已有能力 |
| 10 | 文件系统 | EROFS+overlay、/opt VDFS、另有SquashFS | /opt/usr F2FS | 未注册的文件系统不等于未编入 |

产品列证据见首表。RPi比较依据：[内存](../evidence/task5/A_identity_memory.txt)、[运行参数](../evidence/task5/F_memory_runtime.txt)、[配置](../evidence/task5b/qb_arm-rpi4.config)、[任务5报告](09_board_rpi4_readonly.md)、[设计v4 2.3](10_design_v4.md#23-低端内存结构)。

## 内存布局与统计口径

页大小4096 B（getconf退出0）。zoneinfo如下；present和managed分别记录，不用包含地址空洞的spanned估计容量。

| zone | present页 | managed页 | managed KiB |
|---|---:|---:|---:|
| Normal | 148480 | 140783 | 563132 |
| HighMem | 181568 | 181568 | 726272 |
| Movable | 0 | 0 | 0 |
| CMA | 77824 | 77824 | 311296 |
| 合计 | 407872 | 400175 | 1600700 |

Normal managed×4等于LowTotal；HighMem与CMA managed合计×4等于HighTotal1,037,568 KiB。这是本次接口账目的对应关系，不能仅凭它认定所有CMA页的物理位置或分配约束。LowFree209,652 KiB；CmaFree6,220 KiB。CMA自定义分项满足6,220+2,724+302,352=311,296 KiB。RPi上的“CMA都在低端”前提不成立于这份统计口径；产品不能简单得出563,132−311,296的非CMA低端预算。[页大小](../evidence/pb1/03_pagesize.txt)、[zoneinfo](../evidence/pb1/03_zoneinfo.txt)、[meminfo](../evidence/pb1/03_meminfo.txt)。

System RAM三段为`04000000–2ef3ffff`、`80000000–989fffff`、`a0000000–bfffffff`。cmdline有`mem=703744K@64M mem=394M@2048M mem=512M@2560M vmalloc=300M`。iomem过滤未返回reserved行，不等于没有保留内存；CMA启动摘录另有厂商reserved-memory节点和地址。Machine model、Zone ranges及标准开机Memory总量摘要在取得的dmesg中未见；唯一匹配memory:的是释放initmem440K，不能用它代替内存布局摘要。现有dmesg最早/最晚时间戳0.094053/101.316799秒；不能把其范围当完整开机耗时或证明日志为何缺失。[iomem](../evidence/pb1/03_iomem.txt)、[启动摘录含原文行号](../evidence/pb1/03_dmesg.txt)。

vmalloc原文2046行含2035个范围，按每行size字段相加126,803,968 B；按原文调用者地址/符号分组144项、取前20名。没有产品vmlinux符号表，原文数字地址不臆测成函数名。自定义UsedVirt=122,944 KiB；范围相加=123,832 KiB，两者不强行归一，原文含overlapped=8,236 KiB等分类，底层实现未取得。它们都是虚拟范围统计，包含映射/guard等影响，**不是可直接回收的物理内存**；空洞总计与最大值也不能单独证明可安全缩小vmalloc。[前20及原文头](../evidence/pb1/03_vmallocinfo.txt)。

slabinfo为厂商10列格式，末列明确为memory_usage KB；用该列排序，不套用上游字段位置。103个cache合计72,268 KiB，前5为proc_inode_cache8,100、vm_area_struct4,448、kmalloc-64 4,328、task_struct3,504、skbuff_small_head3,436 KiB。与另一次meminfo的82,536 KiB不一致，时间并非原子一致且厂商统计实现未知，具体差额原因无法确定。未统计partial合并组、未把对象空闲当整页节省。[前30](../evidence/pb1/03_slabinfo.txt)、[buddyinfo](../evidence/pb1/03_buddyinfo.txt)、[pagetypeinfo](../evidence/pb1/03_pagetypeinfo.txt)。

## zram、回收、文件系统与可观察能力

- 唯一swap条目为/dev/zram0，Size1,040,164 KiB、Used2,304 KiB、Priority−2。disksize1,065,132,032 B（1015.7890625 MiB），不把swap头造成的容量差当数据异常。主算法是方括号中的zstd，可列出的另一算法为lz4；重压缩接口也显示zstd。mm_stat共12字段，前3字段与meminfo的OrigDataSize/ComprDataSize/MemUsedTotal互相对应，依次约2140/534/2848 KiB；其余厂商扩展字段原样保存、未猜语义。BG_Recompress和BG_Merge当前均0；bd_stat缺失，不能据此证明全部写回相关CONFIG=n。[swaps](../evidence/pb1/04_swaps.txt)、[zram](../evidence/pb1/04_zram.txt)、[meminfo](../evidence/pb1/03_meminfo.txt)。
- MGLRU enabled0x0001、TTL0与RPi一致；是否相同下游回收语义、是否包含FG/访问次数策略未知。PSI显示avg2/avg6/avg10，memory当次各窗口0但累计stall非零；这不是标准场景无压力的证明。vmstat全文、全部可读VM参数已保存；compact_memory/drop_caches读取均Permission denied（RC1），未写入。[MM状态](../evidence/pb1/04_mm_state.txt)、[PSI](../evidence/pb1/04_pressure.txt)、[vmstat](../evidence/pb1/04_vmstat.txt)、[VM参数](../evidence/pb1/04_vm_params.txt)。
- /proc/modules有74项；版本目录6.12.60的du为20,572 KiB，在/usr/lib/modules与/lib/modules两处观察到相同数字，不将两者相加作为两个独立副本。只读到版本目录层级的大小；没有卸载模块或查询全部磁盘。[模块](../evidence/pb1/05_modules.txt)、[目录大小](../evidence/pb1/05_module_dirs.txt)。
- 根底层EROFS只读，上层overlay可写；/opt为VDFS，另有SquashFS。完整挂载、注册文件系统、df、分区列表和USB idVendor/idProduct/bDeviceClass分别留证；没有读USB产品名/序列号，未探测或改变外设状态。[挂载](../evidence/pb1/06_mounts.txt)、[文件系统](../evidence/pb1/06_filesystems.txt)、[df](../evidence/pb1/06_df.txt)、[USB](../evidence/pb1/06_usb.txt)、[分区](../evidence/pb1/06_partitions.txt)。
- perf_event_paranoid=2、kptr_restrict=1、dmesg_restrict=0；ftrace_enabled、bpf_jit_enable、kprobes/enabled均未暴露。没有运行perf或写tracefs。CPU四核各为performance、1,350,000 kHz，可选500,000/1,350,000 kHz；cpuidle目录不存在。PMU目录名与CPU part分别原样记录，不按目录名推断实际CPU型号或采样能力。[限制](../evidence/pb1/07_restrictions.txt)、[tracing](../evidence/pb1/07_tracing.txt)、[频率](../evidence/pb1/08_cpufreq.txt)、[cpuidle](../evidence/pb1/08_cpuidle.txt)。

## 进程和开机时间线：不是空闲基线

顺序读取/proc/[0-9]*/status共347项：344项退出0、3项退出2（读取期间目标已不存在），得到344个有效进程、1253线程；VmRSS合计1,374,420 KiB，VmSwap合计80,504 KiB。按RSS排序前20名已用P01–P20记录VmRSS、VmSwap、RssAnon、RssFile和Threads。共享页/共享swap可能跨进程重复计数，进程RSS合计不是系统已用物理内存，进程Swap合计也不能与/proc/swaps的唯一槽占用直接对等。原始名称与PID/代号对应仅留`temp/pb1/process_name_map.json`；日志中的短暂进程代号映射仅留`temp/pb1/privacy_terms.json`。[进程汇总](../evidence/pb1/09_process_status.txt)。

主采集约开机100–110秒，uptime的load average为31.23/11.93/4.35；稍后开机13分钟仍28.18/26.92/17.40。两次/proc/stat间隔270.320秒，按所有CPU的user/nice/system/idle/iowait/irq/softirq/steal差值算，排除idle和iowait后的平均忙碌比例20.908%。load不能单独当CPU利用率，也不能由这组数据证明用户场景已空闲。**本次没有取得经确认的空闲场景样本**，不干预任何进程以强行制造空闲；这份快照只用于现状记录。[初始uptime](../evidence/pb1/01_uptime.txt)、[稍后uptime](../evidence/pb1/09_later_uptime.txt)、[CPU统计口径](../evidence/pb1/09_cpu_activity_summary.json)。

| target | ActiveEnterTimestampMonotonic / 秒 |
|---|---:|
| sysinit.target | 13.689043 |
| basic.target | 15.278295 |
| multi-user.target | 34.052645 |
| graphical.target | 34.052705 |

上述四项LoadState=loaded；只是本次开机已有状态，不是重启试验或端到端可交互时间。journalctl --list-boots返回“No journal files were found.”（退出0），未取得历史开机列表。[targets](../evidence/pb1/10_units.txt)、[journal](../evidence/pb1/10_journal_boots.txt)。

## 未取得、无权限及后续前提

1. **最终内核配置未取得**：/proc/config.gz不存在，/boot为空；149项不能逐项判产品值，也不能给真实配置diff或前10排名。需同镜像可信.config再做宿主比较，不擅自下载其他镜像替代。
2. **无权限/接口不可读**：以root读compact_memory和drop_caches均Permission denied。两项未执行写操作。
3. **接口不存在**：BTF、function profiler/trace_stat、THP enabled、zram bd_stat、kprobes enabled、ftrace_enabled、bpf_jit_enable、cpuidle和CoreSight设备目录；分别保留ENOENT。不存在不等于配置必为n。journal历史列表未提供；标准早期启动摘要也未取得。
4. **需要进一步资料或另行授权**：产品内核源码/最终.config/符号表、CMA与vmalloc厂商统计实现、BOM与硬件压缩能力、SWIOTLB高水位和回弹、用户态算法回退执行链、配置裁剪与恢复依赖、ACTIME真实结构体布局及内存归属、产品PMU实际采样能力。产品禁止未签名程序；本次没有将RPi的perf/测量程序授权套用过来。
5. 标准场景/空闲快照、持续压力与OOM、长时间vmalloc峰值/碎片、CMA消费、zram算法收益都未验证；本次不做性能或节省量承诺。产品参数写入、重启、服务变更继续禁止。

## 脱敏与收尾

证据目录提交前扫描：以私有进程名称集合做完整名称token匹配（避免把短名称误匹配到sha256等单词内部），另扫描已知机型/主机/构建标识/序列号、MAC格式、ANSI转义；**真实进程名、已知私有标识/序列号、MAC均零命中**。包含同名技术路径/命令的部分也按代号替换；这类替换不用于推导配置值。额外人工核对了镜像信息、cmdline、dmesg摘录、挂载及CPU字段。私有对照表、原始日志不入库；扫描结果及文件清单见[脱敏扫描](../evidence/pb1/99_privacy_scan.json)。这不声称自动识别未知格式的所有隐私，只陈述已知字段、已知名称与人工检查范围。

最终sdb root off退出0，id回读uid5001；未创建任何板上临时文件，因此没有板上删除动作。宿主temp原文保留供PM核验，evidence均为小于1MB文本。RPi4当前下线，任务8的板上部分待RPi4接回后补做；不把产品板当作任务8的替代实验平台。[最终root off](../evidence/pb1/99_root_off_final.txt)、[owner回读](../evidence/pb1/99_owner_final.txt)。
