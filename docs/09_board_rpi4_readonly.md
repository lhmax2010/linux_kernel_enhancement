# 任务5：RPi4 sandbox 镜像只读采集

采集日期：2026-10-29。对象：`192.168.108.26:26101`，仅用 SDB。宿主操作记录时间为 **20:32:05–20:40:31（Asia/Shanghai）**；板钟显示 `+0900`，换算后另有约17秒偏差，未校时。原始输出、两份候选ELF及本地解析产物在 `temp/task5/`；本文链接均为可上传的小体积文本摘要。

**任务5b补充（2026-10-30）**：用户在隔离浏览器登录后，QB1211696已确认源码SHA等于0fac5de6、构建Successful。但页面`PROJECT_BRANCH=tizen`是项目级变量，未提供包级sandbox分支证明；未满足本轮“分支必须相等”的条件，已停止。浏览器及登录会话目录已删除；没有下载RPM或再次上板。详见A节和[停止证据](../evidence/task5b/provenance_gate.txt)。

## 产品取舍所需的 B–E 结论

| 问题 | 本次事实 | 证据与边界 |
| --- | --- | --- |
| **B：是否有 BTF/BPF 依赖** | **有静态 CO-RE/BTF 依赖路径**：`resource-monitor-plugin-network` 链接 libbpf，内嵌BPF对象含 `.BTF`、`.BTF.ext` 及140 B CO-RE重定位数据。当前未观测到运行：202个进程FD目录中BPF FD命中0，未见libbpf映射、bpffs为空。 | [ELF核对](../evidence/task5/B_elf_btf_analysis.txt)、[运行快照](../evidence/task5/B_bpf_runtime.txt)。没有bpftool，不能排除只由内核持有的程序；不能把“当前未发现”解释为“可以删除BTF”。 |
| **C：哪些调试能力正在使用** | tracefs已挂载，`tracing_on=1`、`ftrace_enabled=1`，但`current_tracer=nop`、`events/enable=0`、无实例；function profiler、stack tracer、latencytop均为0，kgdboc为空。hung-task超时为120秒且有khungtaskd。 | [追踪状态](../evidence/task5/C_debug_usage.txt)。全局开关为1不代表正在记录函数/事件；此次只读观察，没有验证曾经或未来的使用。 |
| **D：Btrfs/F2FS/NFS是否在用** | **F2FS在用**：`mmcblk0p5`挂载于`/opt/usr`及owner/media；`opt-usr.mount`以`LABEL=user`自动挂载。Btrfs、NFS均无当前挂载、未发现相应自动挂载配置。 | [文件系统](../evidence/task5/D_filesystem_usage.txt)。Btrfs工具已安装，三个文件系统均在`/proc/filesystems`中；无当前挂载不代表产品不需要。 |
| **E：外设驱动是否在用** | USB只见xHCI根Hub及VIA `2109:3431` Hub；eth0用`bcmgenet`，音频为bcm2835/VC4 HDMI。`rt2800usb/r8152/lan78xx/smsc95xx/net1080/snd-usb-audio`六个驱动均注册但**没有绑定设备**。 | [USB/网口/音频](../evidence/task5/E_usb_usage.txt)。仅反映此时接入的外设，不替代产品BOM或附件需求。 |

产品上保留哪些功能由PM决定；本轮没有修改内核或用户态配置。

## A：身份、镜像来源与内存

### 身份和来源核对

三项断言全部通过：`uname -r=6.12.80-arm-rpi4-v7l`；`uname -m=armv7l`；`/etc/os-release`的`ID=tizen`、版本11.0.0。先以owner读取身份，再由`sdb root on`取得uid=0；收尾恢复owner。见[会话与清理](../evidence/task5/session_and_cleanup.txt)、[身份/内存](../evidence/task5/A_identity_memory.txt)。

| 项目 | 现场值 / 核对结论 |
| --- | --- |
| `/proc/version` | `Linux version 6.12.80-arm-rpi4-v7l (abuild@ip-192-168-56-168) (clang version 22.1.8, LLD 22.1.8) #1 SMP Wed Oct 28 12:18:25 UTC 2026` |
| 内核构建时间 | 2026-10-28 12:18:25 UTC，即20:18:25（Asia/Shanghai） |
| OS BUILD_ID | `tizen-unified-toolchain_20261028.105834_tizen-headed-armv7l`；这是系统镜像标识，不能替代内核commit/QB构建号 |
| PM提供的源码来源 | `sandbox/lhmax2025/kernel_optimization`，`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708` |
| QB构建记录 | [构建1211696](https://quickbuild.tizen.org/build/1211696)：10月29日匿名访问受限；10月30日用户在隔离有界面浏览器登录后已读到详情，状态Successful |
| QB源码SHA | Overview的Build Package List和Variables中的BUILD_PKG_LIST均明确为`platform/kernel/linux-rpi@0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`；SHA匹配已闭合 |
| QB分支字段 | `PROJECT_BRANCH=tizen`，`PROJECT_NAME=Tizen-Unified-Toolchain`，`USE_BRANCH_POLICY=false`；这是项目级字段，不能据此断言内核源码检出错误，但没有证明本轮要求的包级sandbox分支 |
| QB时间 | Begin Date=`2026-10-28 10:58:35`，Duration=`6 hours 15 minutes 43 seconds`；页面摘录未标时区。按同一时区计算结束17:14:18；若该时间为UTC，则内核版本时间在开始后1:19:50、结束前4:55:53。该差值只是条件计算，时区未核实 |
| 是否完成运行镜像来源核对 | **未全部闭合**：QB构建源码SHA匹配，但分支条件未满足、QB时区未核实；按PM任务5b步骤2/3停止，不用“SHA相同”自行替代分支核对。没有下载或核验RPM，未将构建记录直接当作运行镜像配置证明 |
| `.config`比较对象 | 明确使用任务4 `temp/pmu_config_check/llvm/arm-rpi4/.config`；SHA256 `62e3b8512d8bd4a336410a9468afd8c1ed338b9030dc69c754dbccf888617ba5` |
| 逐项配置比较 | **未能执行diffconfig**：`/proc/config.gz`不存在，模块`build`链接失效，已检查路径没有配置副本。不能报告“配置一致”或“无差异”。任务4基准本身为`CONFIG_IKCONFIG=n`，但不能据此代填板上最终配置 |

缺失项、实际尝试的命令和原始报错见[A配置核对](../evidence/task5/A_config_comparison.txt#L1)。10月29日匿名访问经过保留在[历史QB访问证据](../evidence/task5/QB_1211696_access.txt)。10月30日的新页面选段、变量、脱敏/会话清理记录见[任务5b证据索引](../evidence/task5b/README.md)。需要PM裁决项目级tizen字段与按SHA固定linux-rpi源码的关系，或提供包级sandbox分支证据；本轮不自行接受替代证明。devel包、最终arm-rpi4 `.config`和diffconfig尚未执行，不能改写为“配置一致”。没有为了取得配置而挂载启动分区、重编或换镜像。

### 内存、保留区域和启动参数

`MemTotal=3,976,476 KiB`，A快照`MemAvailable=3,420,220 KiB`，`HighTotal=3,264,512 KiB`，`CmaTotal=327,680 KiB`，即**实际CMA 320 MiB**。不能用之前静态配置的256 MiB代替现场值，也不能把CMA空闲量当成全部不可用内存。`/proc/iomem`没有带reserved/cma字样的条目，故另保留完整小快照；dmesg明确有CMA池及reserved描述。见[A身份/内存](../evidence/task5/A_identity_memory.txt)。

| zone | present页 | managed页 |
| --- | ---: | ---: |
| DMA | 196608 | 177991 |
| Normal | 0 | 0 |
| HighMem | 816128 | 816128 |
| Movable | 0 | 0 |

dmesg原文：`Memory: 3628300K/4050944K available (20480K kernel code, 1867K rwdata, 11884K rodata, 2048K init, 575K bss, 91372K reserved, 327680K cma-reserved, 3264512K highmem)`；CMA范围`0x1ac00000..0x2ebfffff`，另有两个nvram reserved节点；启动后释放2048K initmem。以上是启动日志口径，不与任务3的ELF段统计直接混用。证据同上。

完整cmdline已记录，包括`cgroup_enable=memory`、`swiotlb=8192`、`bootmode=normal partition_ab=a`，没有`kgdboc/kgdbwait/ftrace=/trace_event=`，也没有显式`cma=`。`boot_a`为64MiB vfat分区，**没有挂载**；`/boot`为空目录，因此未读到`config.txt/cmdline.txt`，不推测固件覆盖设置。见[A配置核对](../evidence/task5/A_config_comparison.txt)、[D分区记录](../evidence/task5/D_filesystem_usage.txt)。

## B：BTF / BPF 使用与依赖

### 运行中确实在用

未取得能证明“某程序此刻正在使用BPF/BTF”的正向证据。`/sys/kernel/btf/vmlinux`存在，实读大小 **6,478,350 B**；bpffs挂载在`/sys/fs/bpf`，内容为空。bpftool未安装/未找到，所以没有伪造`prog show`或`map show`结果。按PM允许的替代方法，以root扫描202个`/proc/*/fd`目录，`bpf-prog/bpf-map/bpf-link`命中0；`/proc/*/maps`未找到libbpf。见[B运行快照](../evidence/task5/B_bpf_runtime.txt#L1)。

扫描是顺序快照，存在进程生命周期和访问范围限制；没有FD/pin不排除内核独立持有的attach，也不说明此前从未加载过程序。没有调用任何加载/卸载BPF的操作。

### 存在静态依赖，但当前未观测到运行

`libbpf-1.6.2-1.1.armv7l`已安装。`rpm -q --whatrequires libbpf`命中WiFi_Manager构建块；查询`libbpf.so.1`命中`resource-monitor-plugin-network-1.0.0-1.armv7l`；`libbpf.so.0`无依赖。见[B ELF证据](../evidence/task5/B_elf_btf_analysis.txt#L1)。

板上无readelf，故按授权流程：顺序扫描`/usr/bin /usr/sbin /usr/lib /usr/libexec`中含`libbpf.so`字符串的文件，拉回两个候选（812,332 B网络插件、260,424 B libbpf），用**LLVM GBS root的qemu-arm+readelf/objcopy**检查；原始ELF仅留在本地。

| 检查对象 | 结果 |
| --- | --- |
| `libresource-monitor-plugin-network.so`父ARM ELF | `DT_NEEDED=libbpf.so.1`；引用`bpf_object__open/load/attach/destroy_skeleton`；父ELF本身没有`.BTF/.BTF.ext` |
| `libbpf.so.1.6.2` | 提供库，不当作另一个消费程序；无顶层`.BTF/.BTF.ext` |
| 网络插件`.rodata+0x90`的内嵌ELF | 平台readelf识别为`Linux BPF`，有`.BTF`（0x17b1f B）、`.BTF.ext`（0x3fc B） |
| 内嵌程序 | `fentry/tcp_v4_rcv`、`fentry/tcp_write_xmit`、`fentry/tcp_retransmit_skb`，另有`net_latency_map` |
| CO-RE头 | `hdr_len=32`、`core_relo_off=848`、`core_relo_len=140`，重定位数据非空 |

这给出了**实际安装程序的静态CO-RE/BTF依赖证据**，而非仅凭libbpf包名推测。ELF字段、完整工具命令、提取方法及哈希见[B ELF分析](../evidence/task5/B_elf_btf_analysis.txt#L31)、[B解析方法](../evidence/task5/B_embedded_method.txt)。树内libbpf的机制参考为`tools/lib/bpf/libbpf.c:3438–3442`（CO-RE且无custom BTF时需要kernel BTF）、`:3468–3485`及`libbpf_internal.h:465–480`（头格式）；参考源码并非声称与板上libbpf1.6.2逐字相同。

关闭内核BTF是否可接受，仍需核实此网络监控功能的产品使用场景，以及是否提供兼容的外部BTF路径。此次没有执行插件或做功能测试；不能由当前未运行推出可删BTF。

### 未发现

在指定范围未找到其他直接链接libbpf的ELF；resourced配置及服务文件未匹配到bpf。此范围不覆盖所有可能静态链接、拼接库名、其他目录或按需下载的程序。resourced与resource-monitor网络插件是两个不同组件，不混为一谈。见[B运行快照](../evidence/task5/B_bpf_runtime.txt)、[resourced配置全文](../evidence/task5/F_resourced_config.txt)。

## C：现场调试与追踪

证据：[C调试状态](../evidence/task5/C_debug_usage.txt)。

| 接口/能力 | 现场值 | 事实解释 |
| --- | --- | --- |
| 启动追踪参数 | 未出现kgdboc、kgdbwait、ftrace=、trace_event= | 没有这些cmdline启用项 |
| tracefs | `/sys/kernel/debug/tracing`已挂载；另一个`/sys/kernel/tracing`无有效控制文件 | 未挂载或改写任何实例 |
| tracing_on / ftrace_enabled | 1 / 1 | 全局允许开关仍开着 |
| current_tracer / events/enable | nop / 0 | 采样时没有选择function、irqsoff、wakeup等tracer，事件全关 |
| set_ftrace_filter | 1行：`#### all functions enabled ####` | 默认注释，不是1个函数被实际追踪 |
| instances | 空 | 无独立trace实例 |
| buffer_size_kb | `7 (expanded: 1408)` | 保留原值，不把扩容目标当实际已用大小 |
| function_profile_enabled / stack_tracer_enabled | 0 / 0 | 当前关闭 |
| latencytop / latency_stats | 0 / 只有版本表头 | 当前未记录延迟统计 |
| kgdboc参数 | 空 | 未配置kgdboc通道；不是对所有调试路径都未用的证明 |
| kprobe_events / uprobe_events | 均空 | 未见这些动态事件定义 |
| hung_task_timeout_secs | 120 | 该检测配置有效，进程快照也有khungtaskd |

`rpm -qa`未发现trace-cmd、perf、blktrace、bpftrace、latencytop。systemd单元和`/etc`中只搜到tracefs挂载相关项，没有匹配到启用上述追踪器的启动配置；扫描遇到的失效服务链接已保留原始报错。现场保留哪些诊断能力由PM决定，本轮不提出已验证的裁剪结论。

## D：文件系统和分区

完整`/proc/mounts`、`/proc/filesystems`、分区及lsblk/blkid输出保存在本地；上传摘要见[D文件系统](../evidence/task5/D_filesystem_usage.txt)。`blkid`使用`-c /dev/null`避免写缓存。

| 对象 | 当前使用 | 配置/工具 |
| --- | --- | --- |
| F2FS | `mmcblk0p5`为F2FS，挂载`/opt/usr`及owner/media | `opt-usr.mount`使用`LABEL=user`，未指定有效Type行，实际识别为F2FS；安装f2fs-tools 1.16.0及libf2fs |
| Btrfs | 没有挂载 | 内核可用、安装btrfs-progs 7.0；扫描中无相应自动挂载配置 |
| NFS/NFS4 | 没有挂载 | `/proc/filesystems`支持；未找到nfs-utils包或NFS自动挂载配置 |
| ext4 | `/`、`/opt`、`/hal`、`/usr/lib/modules`、`/mnt/inform`及两个loop模板 | 安装e2fsprogs 1.46.0 |

`/etc/fstab`不存在；检查了systemd静态mount/automount单元和现有generator目录；`/etc/auto.master*`等指定常见路径不存在，错误已记录。无当前Btrfs/NFS使用证据不等于可代表所有产品场景。

## E：USB与实际绑定

无lsusb，改读sysfs。总线中有USB2/USB3 xHCI根Hub（`1d6b:0002/0003`）和VIA USB2 Hub（`2109:3431`）；USB driver绑定表只有usb/hub设备链接。eth0的driver链接指向`bcmgenet`。ALSA卡为bcm2835 Headphones、vc4-hdmi-0、vc4-hdmi-1。见[E USB证据](../evidence/task5/E_usb_usage.txt)。

| 指定驱动 | driver目录存在 | 已绑定USB设备 |
| --- | --- | --- |
| rt2800usb | 是 | 无 |
| r8152 | 是（含额外cfgselector/ecm注册） | 无 |
| lan78xx | 是 | 无 |
| smsc95xx | 是 | 无 |
| net1080 | 是 | 无 |
| snd-usb-audio | 是 | 无 |

`module`链接不算设备绑定。这六项也不在lsmod列表，和既有基准的内建配置相符；由于没有现场.config，不把这一点扩展为全配置相同。已加载模块包括brcmfmac/brcmutil、hci_uart/btbcm、kdbus等；“模块已加载”与“外设正在提供服务”分开记录。当前没有看到wlan接口，未开启或测试无线设备。

## F：回收、zram与用户态配置

在本轮批量文件扫描和perf尝试之前取得F快照：uptime **705.21秒**，已过开机5分钟。未人为加负载，但enlightenment自身占用接近一个CPU，不能称为严格空闲基线。证据：[F内存参数](../evidence/task5/F_memory_runtime.txt)、[会话背景](../evidence/task5/session_and_cleanup.txt)。

| 项目 | 实测 |
| --- | --- |
| MGLRU | `enabled=0x0001`，主功能开启；`min_ttl_ms=0` |
| zram设备 | 只有zram0；算法列表`[lzo-rle] lzo`，当前lzo-rle |
| disksize | **1,628,766,208 B = 1553.3125 MiB ≈ 1.51691 GiB** |
| mm_stat | `2514944 406018 1499136 0 1499136 0 0 2 2`（完整原值，瞬时快照） |
| io_stat | `0 0 0 397647` |
| 二次压缩/写回接口 | recomp_algorithm、recompress、writeback、backing_dev、bd_stat均不存在；idle/mem_limit存在但不读写只写接口 |
| swap | `/dev/zram0`，1590588 KiB，已用3840 KiB，priority 0 |
| swappiness / page-cluster | 60 / 3 |
| watermark_scale_factor / min_free_kbytes | 10 / 3334 |
| vfs_cache_pressure | 100 |
| dirty_background_ratio / dirty_ratio | 10 / 20；相应bytes均0 |
| dirty_expire / writeback / dirtytime_expire | 3000 / 500 / 43200（各接口原单位） |
| PSI memory | some/full avg10/60/300均0；累计total分别1067505/1066608 |

已顺序读取全部可读`/proc/sys/vm/*`并保存cpu/io/memory PSI及完整vmstat；`compact_memory`和`drop_caches`无可读值，未向其写入。sysctl和vmstat完整原文为`temp/task5/F_runtime.txt`，摘要包含所有可读vm参数及部分vmstat计数。

### memcg

只有v1挂载，memory控制器为`/sys/fs/cgroup/memory`，没有cgroup2挂载。遍历时取得67个目录的limit和usage，67处`memory.force_reclaim`存在；只检查存在性，未触发回收。`/proc/cgroups`在自身采样时报告80个memory cgroup，与可遍历目录数不同，不据此伪造缺失目录。完整67项表见[F memcg](../evidence/task5/F_memcg_table.txt)。

关键值（B）：根limit=8796093018112、usage=671232000；BackgroundLru limit=3257528320、usage=0；BackgroundMru usage=19824640；resourced.service limit=52428800、usage=3547136。limit大值不等同物理内存，也不把层级usage相加当全机占用。

### resourced配置与算法不一致

resourced/resourced-config/resourced-bin版本均为10.0.0-1；已保存`/etc/resourced`全部`.conf`（包括VIP子目录）、服务/socket文件全文及其ISU配置，见[F配置全文](../evidence/task5/F_resourced_config.txt)。`/usr/etc/resourced`不存在，`/usr/lib/resourced`没有额外`.conf`命中。

- `/etc/resourced/optimizer.conf`：`CompAlgorithm=zstd`、`ZramRatio=0.4`、`SwapType=zram`、`ReclaimAtBoot=yes`、`BackgroundLruSwappiness=80`，另有`AfterScreenDim=yes`。
- `/etc/resourced/limiter.conf`：MemoryLevelThreshold为25%/15%/10%/7%，BackgroundLruLimit=80%，MemoryLimitTrigger=oom。
- 现场zram算法**不是配置里的zstd**，且算法列表没有zstd；disksize与`MemTotal×0.4`按4KiB向上对齐吻合。全局vm.swappiness=60与BackgroundLru配置80不是同一个控制项。
- 启动journal仅显示resourced启动，没有足以证明具体回退路径的消息。**推测**是请求的zstd不可用后保留/回退到lzo-rle；本轮没有读到完整执行链，不能将推测写成已确认原因。

配置中存在看门狗失败动作`reboot`；本轮只读取，未调用或触发这些动作。按VmRSS排序的30个进程及RssAnon/RssFile/VmSwap见[F Top30](../evidence/task5/F_top30_processes.tsv)：前三为runner 73740 KiB、SystemUI.dll 41704 KiB、enlightenment 32116 KiB；读取不是原子快照。

## G：PMU、perf与采样能力

证据：[G PMU/perf](../evidence/task5/G_pmu_perf.txt#L1)。

| 核对项 | 现场结果 |
| --- | --- |
| PMU驱动 | **已生效/注册**：sysfs有`armv8_cortex_a72`；dmesg报告`7 (8000003f) counters available` |
| PMU sysfs type | 10；这是动态PMU类型编号，不能替代perf记录的`PERF_TYPE_HARDWARE`证据 |
| `perf version --build-options` | command not found，退出127 |
| `perf stat -e cycles,instructions,branch-misses -- sleep 1` | 退出127，未实际计数 |
| `perf record -e cycles -c 100000 -o /tmp/lko_task5/p.data -- sleep 2` | 退出127，未产生p.data，因此没有运行evlist |
| `perf record -b -e cycles ... -- sleep 2` | 退出127，未产生branch.data |
| CoreSight/ETM | `/sys/bus/coresight/devices`不存在；DT compatible扫描未匹配coresight/etm/ptm/funnel/tpiu/etb/etf |
| perf_event_paranoid | 2；未修改，且工具缺失先于权限测试发生 |

三项结论：**硬件计数尚未验证可用**（PMU驱动已绑定）；**分支采样尚未验证**（没有执行到perf事件申请，不能写成硬件“不支持”）；**当前镜像未暴露可用ETM追踪路径**，也没有执行ETM采样。由于perf未启动，没有可观察的`<not supported>`或软件事件回退，不能宣称三种硬件事件全部成功。未安装perf、未推送二进制或改用别的采样程序，实际上没有施加任何perf测试负载。

## H：调度和时钟

证据：[H调度/时钟](../evidence/task5/H_scheduler_clock.txt)。

cpufreq policy0覆盖CPU0–3，driver=`cpufreq-dt`，governor=`schedutil`；可用频率600000至1500000 kHz、步长100000 kHz，当前1500000 kHz；最小/最大600000/1500000。可用governor：conservative、ondemand、userspace、powersave、performance、schedutil。CPU0–3均没有cpuidle目录，未臆造状态列表。

| `/proc/sys/kernel/`项 | 值 |
| --- | ---: |
| sched_autogroup_enabled | 1 |
| sched_deadline_period_max_us | 4194304 |
| sched_deadline_period_min_us | 100 |
| sched_rr_timeslice_ms | 100 |
| sched_rt_period_us | 1000000 |
| sched_rt_runtime_us | 950000 |
| sched_schedstats | 0 |

现场.config不可得，采用PM允许的`/proc/timer_list`只读两快照：`now at`从966552046238到967574211237 ns（增1.022164999秒），jiffies从66655到66757（增102）；约99.7882 Hz，**运行时结果与HZ=100一致**。四CPU行的jiffies相同，不把四行相加；这是计时估算，不是读取实际CONFIG_HZ的冒充值。

## 收尾、证据及待补项

全部板上命令原文（包括条件分支、循环、SDB pull、root切换、清理）在[commands.txt](../evidence/task5/commands.txt)；完整本地原始文件大小、行数及SHA-256见[raw_manifest.tsv](../evidence/task5/raw_manifest.tsv)，摘要索引见[README](../evidence/task5/README.md)。SDB传输返回0不表示其中每条子命令成功；缺失文件的ls/cat、失效链接的grep、缺perf等错误均保留。`COLLECT-END`仅记录命令块最后状态，不当作逐条验收。

开始记录uptime及进程，结束再次记录。观察到已有root交互shell PID3708及其login PID1576，未判断其归属或进行任何干预；未见按命令名可识别的其他压力/采样实验，但不能保证没有其他工作线活动。enlightenment累计CPU占比前后约96.9%/97.1%。没有发信号、sudo、重启、remount、安装包或写sysctl/sysfs，也没有启动新的GBS/内核编译。

板上只新建`/tmp/lko_task5/`，收尾只删除其中本任务创建的17个普通文本文件并rmdir；最后在恢复owner后再次确认 **`TASK5-TEMP-ABSENT-FINAL`**。最大一次板上文本输出为包清单54,126 B，结束前du记录临时目录188KiB，均远低于50MB；两份ELF直接sdb pull到工作区，没有在板上另存。见[清理原文](../evidence/task5/session_and_cleanup.txt#L424)。

待PM后续提供/决定：任务5b已读到QB详情，需裁决分支证明方式并明确QB时区；最终.config尚未下载比较；需要实际计数时另行安排带perf的镜像或授权方案；资源监控网络插件是否属于产品必需功能、何时触发、外部BTF替代是否存在；未挂载boot分区的固件CMA配置。本轮只记录这些边界，不自行补装、挂载或触发服务。


## 任务5b停止位置与未执行项（2026-10-30）

用户设计文档已从Downloads移动到[10_design_v1.md](10_design_v1.md)，原位置无副本，SHA256保持`80ecded8314071d8781c7329b37210613d8c788e819fba9a13c6d76c25909249`，未修改PM原文。一次性perf授权已写入RULES，但本轮未使用。

QB源码SHA和构建成功状态有正向证据；**并未认定QB构建了错误源码**。停止原因是页面项目分支字段不是指定sandbox，且包级sandbox分支仍未证实，触发PM的停止条件。页面已找到公开产物根URL，但未继续定位/下载两个RPM。截图只保留在`temp/task5b/qb_1211696_branch_gate.png`，截取前隐藏其他变量行，未上传截图、凭据或会话数据。浏览器目录`temp/task5b/browser/`已确认删除，证据见[浏览器清理](../evidence/task5b/browser_cleanup.txt)。

因此任务5b步骤3配置比较、步骤4硬件计数/分支采样、步骤5BPF trampoline源码与板上加载日志核对均未执行。本轮没有任何SDB命令，未创建`/tmp/lko_task5b`；上文任务5的PMU/BPF结论仍是10月29日的旧快照，没有新增实测结论。尤其不能将源码中预期的ENOTSUPP路径当作这个插件实际尝试加载并失败的证据。
