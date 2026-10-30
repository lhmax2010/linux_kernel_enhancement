# 任务5：RPi4 sandbox 镜像只读采集

采集日期：2026-10-29。对象：`192.168.108.26:26101`，仅用 SDB。宿主操作记录时间为 **20:32:05–20:40:31（Asia/Shanghai）**；板钟显示 `+0900`，换算后另有约17秒偏差，未校时。原始输出、两份候选ELF及本地解析产物在 `temp/task5/`；本文链接均为可上传的小体积文本摘要。

**任务5c（2026-10-30）**：PM一次性授权可执行数据分区后，已在`/opt/usr/lko_task5c`完成测试：硬件计数可用，cycles采样32个样本、evlist为type=0；`record -b`明确报branch stack sampling不支持（255）；本次未观察到软件事件替换。目录已删除，df前后相同，未remount或改paranoid。任务5b的noexec阻塞保留为历史，当前perf结论见G节任务5c。

**任务5b续（2026-10-30，历史经过）**：按PM新裁决，QB1211696的固定linux-rpi SHA与产物/BUILD_ID证据已接受；公开devel包最终.config与任务4LLVM普通版**全文字节相同、平台diffconfig为空**，来源与配置闭合。临时perf已按授权推送，但`/tmp`为`noexec`，执行version即Permission denied/126，未进行计数/采样，临时文件已清理。网络插件的ARM32 fentry缺少trampoline实现；没有插件加载/失败日志，不能称其“实测加载失败”。详见A、B、G新增小节。

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
| QB分支字段 | `PROJECT_BRANCH=tizen`是Tizen-Unified-Toolchain项目级变量，`USE_BRANCH_POLICY=false`；**PM已裁决不再要求包级分支名**，接受BUILD_PKG_LIST固定SHA证明 |
| QB时间 | Begin Date=`2026-10-28 10:58:35`，Duration=`6:15:43`，推算结束17:14:18。**按PM要求将开始时间理解为UTC，这是推断，页面未显示时区**；内核12:18:25 UTC在开始后1:19:50、结束前4:55:53，位于该时间窗内 |
| 是否完成运行镜像来源核对 | **按PM裁决闭合**：固定SHA + 产物目录与BUILD_ID一致 + 编译时间处于上述推断UTC时间窗；另有本地远端分支contains佐证。不是从内核版本字符串直接读到commit |
| `.config`比较对象 | 明确使用任务4 `temp/pmu_config_check/llvm/arm-rpi4/.config`；SHA256 `62e3b8512d8bd4a336410a9468afd8c1ed338b9030dc69c754dbccf888617ba5` |
| 逐项配置比较 | **闭合，差异0**：公开devel RPM中的`boot/kernel/devel/kernel-devel-arm-rpi4/.config`为194,980 B，SHA与任务4参考相同（62e3b851…）。LLVM GBS root内qemu-arm+平台Python执行scripts/diffconfig，stdout为空、exit=0；全文字节也相同 |

10月29日缺失板上配置的原始尝试仍见[A配置核对](../evidence/task5/A_config_comparison.txt)，前轮QB分支停止经过仍保存在[历史停止证据](../evidence/task5b/provenance_gate.txt)。本次未重新登录QB，未挂载启动分区、重编或换镜像。

### PM来源裁决与公开RPM（任务5b续）

PM接受`BUILD_PKG_LIST=platform/kernel/linux-rpi@0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`为来源证明，不再要求包级分支名，理由为：

1. git SHA唯一确定源码内容；
2. PROJECT_BRANCH为Tizen-Unified-Toolchain项目级变量，USE_BRANCH_POLICY=false；
3. 产物目录`tizen-unified-toolchain_20261028.105834`与板上BUILD_ID主体一致；
4. 开始时间按UTC理解（**推断**），板上内核编译时间12:18:25 UTC落在构建时间窗内。

[裁决原意与时间差](../evidence/task5b/pm_adjudication_20261030.txt)。追加只读命令`git -C linux-rpi branch -r --contains 0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`，输出唯一一行`origin/sandbox/lhmax2025/kernel_optimization`。这是本地已获取远端跟踪分支集合的结果，本轮没有fetch或改分支；[原文](../evidence/task5b/remote_contains_0fac5de6.txt)。

按指定公开根依次进入`repos/standard/packages/armv7l/`，找到并下载两个RPM，未更换来源：

| 文件 | 字节数 | SHA-256 |
|---|---:|---|
| [arm-rpi4-linux-kernel-devel-6.12.80-0.armv7l.rpm](http://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261028.105834/repos/standard/packages/armv7l/arm-rpi4-linux-kernel-devel-6.12.80-0.armv7l.rpm) | 115,630,580 | `721e2604bc3ad01077ab84416f549da091e3133e96025a38a9ef9915d25e3a28` |
| [linux-kernel-perf-6.12.80-0.armv7l.rpm](http://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261028.105834/repos/standard/packages/armv7l/linux-kernel-perf-6.12.80-0.armv7l.rpm) | 1,109,156 | `31feef6cd233061ec67d39717c8d62620dd805661814422f7be9fc79041d7909` |

两包仅保存到`temp/task5b/rpms/`，未安装。用LLVM buildroot的平台rpm2cpio解出CPIO，再在WS/temp解包；最终配置由同root平台Python比较。两包RPM BUILDTIME字段都是epoch 0，**不能用它证明实际打包时间**；时间核对依据仍是QB页面和/proc/version。证据：[目录遍历](../evidence/task5b/public_download_traversal.txt)、[下载清单](../evidence/task5b/rpm_manifest.json)、[平台diffconfig原文](../evidence/task5b/final_config_diff.txt)、[配置摘要](../evidence/task5b/config_comparison_summary.txt)、[RPM最终配置全文](../evidence/task5b/qb_arm-rpi4.config)。

本次SDB重新读取三项身份、BUILD_ID、/proc/version均与任务5一致；因此不是用旧板上快照配新RPM。[本次身份与起始进程](../evidence/task5b/02_identity_start.transport.txt)。

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

### 任务5b：ARM32 trampoline、错误返回和实际运行核对

**源码能力结论：该内核的ARM32 fentry路径缺少trampoline实现，不能正常挂载这些fentry程序；但本次无法判断网络插件是否实际尝试加载或失败。** 两者分别由源码和运行日志支持，不能混为一次实测失败。

- `arch/arm/net/bpf_jit_32.c`没有`arch_prepare_bpf_trampoline`实现；对整个`arch/arm/`搜索该符号及`arch_bpf_trampoline_size`均无匹配。`kernel/bpf/trampoline.c:1079–1085`的弱prepare实现返回`-ENOTSUPP`；`:1115–1118`的弱size实现同样返回`-ENOTSUPP`，`include/linux/errno.h:27`定义ENOTSUPP=524。
- 精确挂载路径：`kernel/bpf/syscall.c:3460`调用`bpf_trampoline_link_prog` → `trampoline.c:590`更新 → `:442–446`先取size，负值直接回传。因此正常前置条件下ARM32会**先在size弱实现返回-524**，还没有执行到prepare。不能只引用prepare而误称它一定是第一处失败。
- 内核原始`bpf()`系统调用向用户态表现为`-1, errno=524`。libbpf整数API返回负errno；`bpf_object__load_skeleton()`透传加载错误，`bpf_object__attach_skeleton()`透传挂载错误。`bpf_program__attach_trace()`这样的指针API失败时返回`NULL`并置errno；`libbpf_get_error(NULL)`返回`-errno`。所以此挂载路径对应NULL/errno524或skeleton返回-524，不把ENOTSUPP(524)混同EOPNOTSUPP(95)。加载阶段若先遇权限、BTF、验证器或其他错误，返回对应错误，并非所有fentry加载失败都必为-524。
- 版本边界：内核树内libbpf为1.5；板上包为1.6.2-1.1。上述libbpf语义另核对官方[v1.6.2 libbpf.c](https://github.com/libbpf/libbpf/blob/v1.6.2/src/libbpf.c#L12744)（加载/挂载skeleton见14075、14098行，get_error见10714行）及[libbpf_internal.h](https://github.com/libbpf/libbpf/blob/v1.6.2/src/libbpf_internal.h#L577)。没有声称官方tag与Tizen下游二进制逐字对应；源码URL、SHA与逐行片段见[错误链证据](../evidence/task5b/bpf_source_error_chain.txt)。

板上只读结果：

| 项目 | 本次结果 |
|---|---|
| resource-monitor进程 | pidof返回1，/proc/*/comm扫描未命中；`rpm -q resource-monitor`显示此精确包名未安装，不据此断言所有近似命名组件不存在 |
| 网络插件映射 | 全部可读/proc/*/maps搜索`libresource-monitor-plugin-network.so`无命中；插件包本身仍已安装 |
| dlogutil -d | 命令退出0；关键字命中仅为本次SDB命令自身的回显，无插件load/attach失败消息 |
| journalctl -b --no-pager | 命令退出0；仅一般的systemd BPF/cgroup防火墙提示和`Listening on Pass resource-monitor socket.`，都不能证明网络插件尝试加载 |
| bpf_jit_enable | 0，只读，未修改；不能据此断言历史加载行为 |
| 是否尝试、是否失败、实际失败原因 | **无法判断：没有相关插件日志**；未启动/重启服务，未手动加载BPF |

[进程/版本](../evidence/task5b/04_bpf_processes.transport.txt)、[dlog原文](../evidence/task5b/06_bpf_dlog.transport.txt)、[journal原文](../evidence/task5b/07_bpf_journal.transport.txt)、[运行结论及SDB回显排除说明](../evidence/task5b/bpf_runtime_summary.txt)。这项静态架构缺口不等于已经获得可删除BTF的产品授权。

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

当前结论以本节“任务5c：数据分区perf实测结果”为准：硬件计数/采样已验证，-b分支栈采样不支持，未观察到软件事件替换。以下先保留任务5与5b的历史经过。

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

### 历史：任务5b临时perf在执行权限处阻塞

上表是任务5（10月29日）的“工具不存在”结果。本次已经取得QB的perf并按一次性授权尝试执行，停止点更新为：**`/tmp`挂载noexec，perf尚未启动**，不是PMU事件拒绝。

LLVM buildroot的平台readelf列出16项DT_NEEDED；板上逐项ls并验证可读，只有`libLLVM.so.22.1`缺少。仅从工作区现有LLVM GBS root取该库（`libllvm-22.1.8-3.1.armv7l`，31,498,764 B），其9项依赖全部已在板上。没有换取其他perf/devel包，也没有推送已存在的库。perf为2,981,796 B，两个文件合计34,480,560 B；板上du为33,676 KiB，低于50 MiB。两者推送前后SHA一致，路径仅`/tmp/lko_task5b/`；[ELF依赖](../evidence/task5b/perf_readelf.txt)、[板上ls](../evidence/task5b/03_libraries_preflight.transport.txt)、[补充库来源](../evidence/task5b/llvm_library_package.txt)、[推送清单](../evidence/task5b/pushed_files.json)。

SDB会话开始时已经uid=0，本轮未执行root on/off，保持原状态；paranoid=2不变。perf环境的HOME/TMPDIR/LD_LIBRARY_PATH均指向任务临时目录，LD_LIBRARY_PATH没有附加其他目录。文件chmod0755后，第一条命令仍报：

```text
/bin/sh: /tmp/lko_task5b/perf: Permission denied
PERF-COMMAND-EXIT=126
```

随后只读 `/proc/mounts` 明确为：

```text
tmpfs /tmp tmpfs rw,nosuid,nodev,noexec 0 0
```

[启动原文](../evidence/task5b/11_perf_version.transport.txt)、[挂载核对](../evidence/task5b/18_exec_restriction.transport.txt)。0755和root不能取消挂载noexec约束。遵守禁止remount、仅在指定临时目录运行的边界，没有改挂载/安全策略，没有借助动态加载器绕过，也没有尝试其他执行位置。

| 要求 | 本次结果 |
|---|---|
| perf version --build-options | 失败，126；程序未执行到版本输出 |
| 1秒cycles/instructions/branch-misses stat | NOT RUN：前置可执行入口失败 |
| 2秒cycles record与evlist | NOT RUN；无type=0证据，**硬件计数尚未验证** |
| 2秒record -b | NOT RUN，**分支采样尚未验证**，不能判硬件不支持 |
| 是否替换软件事件 | 无法观察；没有打开任何perf事件，不称为成功通过“无回退”验证 |

临时目录已在finally中删除，并再次确认`TASK5B-TEMP-ABSENT-CONFIRMED`；[清理与结束进程](../evidence/task5b/17_cleanup_end.transport.txt)。只删除本轮新建目录，没有安装RPM或写根文件系统、sysctl、sysfs。起始uptime83729.49s，清理后83934.12s，权限核对时84005.07s；既有root串口shell PID3708未触碰。dmesg里uptime11755–11766s的perf采样率调整早于本次，不能归给本轮或据此宣称指定硬件事件已成功。

这次noexec停止之后，PM已在任务5c一次性授权非根数据分区的可执行专用目录；恢复后的结果见下节。原始阻塞摘要保留于[perf_attempt_summary.txt](../evidence/task5b/perf_attempt_summary.txt)。

### 任务5c：数据分区perf实测结果

2026-10-30宿主SDB窗口为20:16:01–20:17:34（Asia/Shanghai）；三项身份、BUILD_ID与/proc/version仍与A节一致。会话进入时已uid=0，保持原root状态；`perf_event_paranoid`始终为2。观察到原有串口shell PID3708与enlightenment等进程，未干预；这些短时`sleep`测试用于能力核对，不能当作产品性能基准。

只读`cat /proc/mounts`筛出**13个rw且没有noexec的挂载点**，完整列表及选择理由在[挂载清单](../evidence/task5c/mount_selection.md)、[原始挂载文本](../evidence/task5c/03_mounts.transport.txt)。选定`/opt/usr`：设备`/dev/mmcblk0p5`、F2FS，与根文件系统`/dev/mmcblk0p2`不同；`/opt/usr`不是符号链接，父目录UID:GID=0:0、权限0755，开始可用115,421,020 KiB（约110 GiB）。专用目录原先不存在；新建`/opt/usr/lko_task5c`后所有者仍为0:0，权限0777、SMACK标签User::Shell，未改安全策略。[写前df/依赖检查](../evidence/task5c/04_preflight.transport.txt)、[新建记录](../evidence/task5c/05_create_temp.transport.txt)。

只推任务5b同一perf（2,981,796 B）及板上唯一缺少的`libLLVM.so.22.1`（31,498,764 B），两文件SHA与前轮、板上推送后均一致；其他依赖只读核对存在。仅设置`HOME=TMPDIR=LD_LIBRARY_PATH=/opt/usr/lko_task5c`（三个变量各自的值都是该路径），LD_LIBRARY_PATH没有其他目录。perf为6.12.80；build-options显示auxtrace开启、libopencsd关闭，不能据auxtrace一项宣称CoreSight链已可用。[推送清单](../evidence/task5c/pushed_files.json)、[SHA复核](../evidence/task5c/08_push_hashes.transport.txt)、[版本选项](../evidence/task5c/09_perf_version.transport.txt)。

以下命令均使用专用目录内的perf，并通过SDB以root执行；输出文件也只在该目录。

| 命令（省略perf绝对路径） | 退出码 | 实测结果 | 证据 |
|---|---:|---|---|
| `version --build-options` | 0 | perf6.12.80正常执行 | [version](../evidence/task5c/09_perf_version.transport.txt) |
| `stat -e cycles,instructions,branch-misses -- sleep 1` | 0 | cycles **3,071,509**；instructions **1,042,281**；branch-misses **9,343**；elapsed1.003534166s | [stat](../evidence/task5c/10_perf_stat.transport.txt) |
| `record -e cycles -c 100000 -o /opt/usr/lko_task5c/p.data -- sleep 2` | 0 | **32 samples**；p.data文件7,060 B，已拉回temp/task5c，不上传二进制 | [record](../evidence/task5c/11_perf_record.transport.txt) |
| `evlist -v -i /opt/usr/lko_task5c/p.data` | 0 | `type: 0 (PERF_TYPE_HARDWARE)`；`config: 0 (PERF_COUNT_HW_CPU_CYCLES)`；period100000 | [evlist](../evidence/task5c/12_perf_evlist.transport.txt) |
| `record -b -e cycles -o /opt/usr/lko_task5c/b.data -- sleep 2` | **255** | `cycles: PMU Hardware or event type doesn't support branch stack sampling.`；b.data为0 B | [branch](../evidence/task5c/13_perf_branch.transport.txt) |

三项结论：

1. **硬件计数可用**：三项stat都有计数，cycles采样成功且evlist明确type=0，已闭合任务5/5b中“只有PMU驱动绑定”的不足。
2. **分支栈采样不可用（当前板子/内核/PMU/perf组合）**：`-b`直接报告不支持，未取得分支样本。branch-misses可计数不等于能够采集分支栈；不把本次结果推广到未测架构或其他采样方案。
3. **本次未观察到事件被换成软件事件**：cycles记录明确是硬件type0；stat按原三项硬件事件名输出计数，未出现cpu-clock/task-clock替换；`-b`直接失败。对应源码`tools/perf/util/parse-events.c:40–64`为硬件事件名，`tools/perf/util/evsel.c:3207–3231`显示cycles软件回退会修改type/config并清除原事件名；[源码摘录](../evidence/task5c/software_fallback_source.txt)。这不是对所有事件或未测试回退场景的保证。

清理前du最大34,440 KiB，低于50 MiB。perf自动产生的build-id `.debug`缓存因HOME设在专用目录内，也随整个目录删除；没有把缓存写入真实root HOME。`ls -ld /opt/usr/lko_task5c`返回`No such file or directory`、退出2，随后确认`TASK5C-TEMP-ABSENT`。df对照如下（单位KiB）：

| 时点 | 总量 | 已用 | 可用 |
|---|---:|---:|---:|
| 写前 | 116,404,224 | 983,204 | 115,421,020 |
| 删除后 | 116,404,224 | 983,204 | 115,421,020 |
| 差值 | 0 | 0 | 0 |

起止uptime86077.52/86169.86秒；/proc/mounts全文前后相同，paranoid仍2。未remount、安装RPM、写根文件系统、改sysctl/sysfs或启动服务；只删除本轮新建专用目录。[清理/结束进程原文](../evidence/task5c/16_cleanup_end.transport.txt)、[清理摘要](../evidence/task5c/cleanup_summary.txt)、[全部命令](../evidence/task5c/board_commands.jsonl)、[证据索引](../evidence/task5c/README.md)。此次授权随清理结束，后续板上测试需新任务授权。

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

待PM后续提供/决定：来源/配置与硬件计数已闭合，任务5c确认当前组合不支持-b分支栈采样；网络插件的产品需求/触发条件、BTF取舍和固件CMA来源仍待核实。不自行补装、remount或触发服务。


## 历史：任务5b首次停止位置（2026-10-30，已由本轮PM裁决恢复）

以下为首次停止的历史记录；当前状态以本文A/B/G的任务5b续小节为准。

用户设计文档已从Downloads移动到[10_design_v1.md](10_design_v1.md)，原位置无副本，SHA256保持`80ecded8314071d8781c7329b37210613d8c788e819fba9a13c6d76c25909249`，未修改PM原文。一次性perf授权已写入RULES，但本轮未使用。

QB源码SHA和构建成功状态有正向证据；**并未认定QB构建了错误源码**。停止原因是页面项目分支字段不是指定sandbox，且包级sandbox分支仍未证实，触发PM的停止条件。页面已找到公开产物根URL，但未继续定位/下载两个RPM。截图只保留在`temp/task5b/qb_1211696_branch_gate.png`，截取前隐藏其他变量行，未上传截图、凭据或会话数据。浏览器目录`temp/task5b/browser/`已确认删除，证据见[浏览器清理](../evidence/task5b/browser_cleanup.txt)。

因此任务5b步骤3配置比较、步骤4硬件计数/分支采样、步骤5BPF trampoline源码与板上加载日志核对均未执行。本轮没有任何SDB命令，未创建`/tmp/lko_task5b`；上文任务5的PMU/BPF结论仍是10月29日的旧快照，没有新增实测结论。尤其不能将源码中预期的ENOTSUPP路径当作这个插件实际尝试加载并失败的证据。


## 历史：任务5b续收尾（当前perf结论见G节任务5c）

来源和最终配置已闭合，BPF源码/只读运行核实已完成；perf功能测试因/tmp noexec未完成。没有将执行权限失败包装成硬件能力结论，也没有将无插件日志包装成ENOTSUPP实测。PM设计[10_design_v1.md](10_design_v1.md)内容未改、SHA仍为80ecded8314071d8781c7329b37210613d8c788e819fba9a13c6d76c25909249。本次只更新09、RULES、STATUS与[evidence/task5b](../evidence/task5b/README.md)，在同一GitHub main提交交付；不改内核源码、不构建、不推Gerrit。
