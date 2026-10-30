# Linux 内核优化设计文档 v2（RPi4 armv7l，6.12.80）

版本：v2（2026-10-30；同日修订，补入上一轮 Claude Code 完整评审中初稿遗漏的内容）。仓库：`lhmax2010/linux_kernel_enhancement`，本文件位于 `docs/10_design_v2.md`，文中证据链接均相对本目录。v1（`10_design_v1.md`）保留作历史记录，以本文为准。

**相对 v1 的主要变化**：

- 写明验收口径：用哪些指标判回退、分母是什么、怎样做统计判定。
- 新增低端内存（LowMem）章节，这是本板最紧的内存约束。
- 按 perf 实测结果重写采样优化一节。
- BTF 裁剪改为“先完成依赖清单再决定”。
- zram 实验改为逐个因素做对照，并补齐成本账本。
- 栈保护探测修复提前到建立基线之前。
- 新增五项有依据的方案（链接期死代码消除、低端内存保护参数、用户态主动归还内存、zsmalloc 碎片整理、小尺寸透明大页），以及“后续研发储备”一章。

## 0. 文档说明

**目的**：按 2027 年度计划落地 Linux 内核优化，目标是提高性能、降低内存。本文给出现状基线、候选方案、测量方法、实验顺序和通过门槛，作为后续实现的依据。设计冻结前不开始实现。

**范围**：

- 开发和验证平台：RPi4（Tizen 11，armv7l，内核 6.12.80），它是 TV 产品的替身板。凡涉及产品取舍（功能裁剪、调试能力保留、地址空间划分）的结论，都需要在产品级开发板上复核。
- 产品板主要是 armv7l，目前没有 aarch64 产品板，因此本项目以 armv7l 为主。aarch64 的工作（包括内核 BOLT）放到 armv7l 之后，只在 RPi4 的 aarch64 镜像上做可行性验证。
- 基于机器学习的页面置换和内存回收由另一位同事负责，不在本文范围内。本文涉及回收的方案都不改变页面置换（victim 选择）机制。
- 改动对象可以是内核、LLVM/GCC 工具链、glibc/musl、resourced 等用户态组件。v2 起，与应用生命周期相关的用户态内存管理也纳入评估（见 3.6）。
- 内存收益分三个口径报告：全机物理占用、低端内存压力、内核虚拟地址空间占用。不能用全局 MemAvailable 代替低端内存的验收。

**基线代码**：Gerrit 分支 `sandbox/lhmax2025/kernel_optimization`，提交 `0fac5de6`。相对 tizen 主线 `42aeefac` 只多两个提交：force_reclaim 修复、启用 ARM_PMUV3。本项目所有内核改动只推送到这个分支。

## 1. 目标与约束

### 1.1 总体约束

| 项目 | 内容 |
| --- | --- |
| 总目标 | 在不损失产品功能的前提下降低内存占用、提升性能 |
| 不回退容差 | 性能 2%，内存 3%（与年度计划一致）。指标和分母见 1.2，判定方法见 1.3 |
| 改动粒度 | 每项单独分支、单独补丁、单独报告；组合后重新验收 |
| 证据要求 | 每个结论附 文件:行号、命令输出或日志；估算值必须标明“估算” |
| 板上操作 | 按 RULES.md：三项身份断言；不改根文件系统、不 remount、不安装 RPM；重启由用户执行。`/tmp` 挂载为 noexec，需要执行的临时程序放在 `/opt/usr` 下的任务专用目录，用完删除（任务 5c 的做法）。两项常规授权（用户已同意，不需要逐次申请）：一是按任务 5c 的方式临时推送 perf 及其缺少的库；二是实验中直接修改运行时参数（`/proc/sys`、`/sys` 下的可写项）。修改前记录原值，实验结束后恢复并回读确认，全部记入实验报告。zram 的运行时重配（swapoff、reset、设算法、设 disksize、mkswap、swapon）按运行时参数处理。实验期间独占板子。resourced 和内核的改动一律通过 QB 镜像，由用户烧写。标准场景需要安装测试应用（写 /opt 分区），是否纳入常规授权待用户确认 |

### 1.2 回退判定的指标与分母

每项实验开始前，在实验计划中写定使用下表的哪些指标；不在表中的指标只作解释，不参与判定。

| 类别 | 指标 | 分母（基线值） | 容差 |
| --- | --- | --- | --- |
| 性能（延迟类） | 每个关键场景的应用切换耗时、冷启动耗时（中位数与最慢 1%）；换入延迟（最慢 1%） | 同一场景下基线内核的同一指标 | 候选/基线比值的单侧 95% 置信上界 ≤ 1.02 |
| 性能（吞吐类） | 固定负载下的完成量、cycles/指令数 | 同上 | 比值的单侧 95% 置信下界 ≥ 0.98 |
| 内存（全机） | 标准场景结束时的已用内存（MemTotal − MemAvailable）及场景中的峰值 | 同一场景、同一存活应用集合下的基线值 | 比值的单侧 95% 置信上界 ≤ 1.03 |
| 内存（低端） | 同一时刻的低端内存已用量（LowTotal − LowFree）；低端内存分配失败次数；DMA 区的直接回收次数（allocstall_dma） | 同上 | 已用量比值上界 ≤ 1.03；失败次数不增加；直接回收次数不超出噪声范围 |
| 内存（内核静态） | 常驻段大小、启动日志 `Memory:` 行 | 基线构建 | 不设容差；任何增长都要说明原因 |

功能、安全性、崩溃和数据完整性不适用上述容差，出现问题即判失败。

### 1.3 统计判定

- **统计单元**：一次独立的场景轮次（独立启动或独立的一轮固定场景）。同一轮内的大量事件不当作独立样本；分位数按轮次计算后再求置信区间。
- **样本量**：先做 A/A 小规模试跑，用测得的方差估算正式轮次（目标是能分辨 1% 的差异），不少于 10 轮。置信区间按轮次做 bootstrap 求得。
- **低噪声佐证**：代码生成和体积类变体，同时报告标准场景下内核态的 instructions 和 cycles（perf stat 计数）。它们比墙钟时间稳定得多，用来佐证墙钟指标的结论。
- **执行顺序**：A/B 随机交错执行，避免温度、时间漂移带来的偏差。
- **判定**：置信区间跨越容差边界时判为“证据不足”，增加轮次后再判，不按通过处理。每个关键场景单独过门槛，多个场景的平均值不能掩盖单个场景的回退。
- **频率**：每个变体跑两组。一组锁定 CPU 频率（performance 调频策略），用于判定；一组用默认 schedutil，作为真实场景参考。调频策略按 1.1 的常规授权直接修改，实验结束后恢复。
- **训练与验收分离**：凡是用场景数据做优化的方案（采样驱动优化、预换入等），训练用的场景和验收用的场景必须分开。

## 2. 现状基线

### 2.1 构建产物（任务 2、3）

本表是 `f240c280` 的历史构建产物对比。当前 `0fac5de6` 相对它只多了 ARM_PMUV3 配置，但不能把旧体积当作当前镜像的精确体积。两组构建还存在编译器能力探测、链接器和构建依赖上的差异（见 03），表中差值是产物差异，不是编译器的独立贡献。

| 项目 | GCC 14.2 | Clang/LLD 22.1.8 | 差值 |
| --- | ---: | ---: | ---: |
| 常驻已分配段合计（普通版） | 32,930,806 B | 35,600,410 B | +2,669,604 B（+8.11%） |
| 其中 .text | 17,808,156 B | 19,862,536 B | +2,054,380 B（+11.54%） |
| .ARM.unwind_tab | 13,152 B | 522,312 B | +509,160 B |
| .ARM.unwind_idx | 391,416 B | 515,568 B | +124,152 B |
| .BTF（常驻） | 6,440,894 B | 6,475,431 B | — |
| 构建墙钟时间 | 58:44 | 36:50 | — |

构建墙钟时间是两次完整 GBS 命令的耗时，不能据此说明 Clang 编译速度快了同样比例。

**内核静态常驻都占用低端内存**（见 2.3），因此本表中的每一字节节省都是低端内存节省。

证据：[03 构建基线](03_baseline_build.md)、[06 静态内存构成](06_static_footprint.md)、[07 代码体积增长](07_llvm_text_growth.md)。

### 2.2 运行时（任务 5、5b、5c，sandbox 镜像，LLVM 构建）

| 项目 | 实测值 |
| --- | --- |
| 内核 | 6.12.80-arm-rpi4-v7l，clang 22.1.8 / LLD 22.1.8，2026-10-28 构建。来源已闭合：QB 1211696 按 SHA `0fac5de6` 构建，公开 devel 包中的最终 .config 与本地生成的逐字节一致 |
| 内存 | MemTotal 3,976,476 KiB；启动日志：kernel code 20480K、rodata 11884K、rwdata 1867K、bss 575K、reserved 91372K、cma-reserved 327680K |
| CMA | 实际 320 MiB（defconfig 写 256 MiB，DTS 写 64 MiB，固件配置未读到）；静置时空闲 268,452 KiB |
| zram | 单设备 zram0，算法 lzo-rle，disksize 1,628,766,208 B（MemTotal × 0.4，共 397,648 个槽）；没有二次压缩、写回接口。静置快照中 orig_data_size 约 2.40 MiB、mem_used_total 约 1.43 MiB，只能证明接口和配置状态，不能说明 zram 是当前瓶颈 |
| resourced 配置 | `optimizer.conf` 写的是 `CompAlgorithm=zstd`，但内核只编了 LZO 后端（`ZRAM_BACKEND_FORCE_LZO=y`），实际算法与配置不一致。本次采集没有找到能说明设置失败或回退原因的日志，历史行为无法确定 |
| MGLRU | 已启用（0x0001），`min_ttl_ms=0` |
| 回收参数 | 全局 swappiness 60；resourced 配置中 BackgroundLruSwappiness=80（该 memcg 的 `memory.swappiness` 实际值尚未读取）；watermark_scale_factor 10；min_free_kbytes 3334；lowmem_reserve_ratio `256 32 0 0` |
| memcg | 只有 v1；67 个 memcg 都有 `memory.force_reclaim` |
| 调度与时钟 | PREEMPT_VOLUNTARY；HZ 实测约 100；cpufreq schedutil，600–1500 MHz；CONFIG_CPU_IDLE 未启用（所以没有 cpuidle 状态） |
| PMU 与 perf | 驱动已注册（armv8_cortex_a72，7 个计数器）。镜像不带 perf；按任务 5c 方式临时推送同版本 perf 后实测：硬件计数和 cycles 采样可用，事件类型为 PERF_TYPE_HARDWARE，没有退回软件事件；分支栈采样（`record -b`）不支持；没有 CoreSight/ETM 设备。这个 perf 构建关闭了 libtraceevent，不能直接解析 tracepoint 事件 |
| 追踪与调试 | tracefs 已挂载，current_tracer=nop，事件全关；FUNCTION_TRACER、FUNCTION_GRAPH_TRACER、KPROBES、KPROBE_EVENTS 均已编入；function profiler、stack tracer、latencytop 运行时都是 0；cmdline 没有 kgdboc |
| 文件系统 | F2FS 在用（/opt/usr）；ext4 在用；Btrfs、NFS 没有挂载 |
| USB 外设 | 只有 Hub；rt2800usb、r8152、lan78xx、smsc95xx、net1080、snd-usb-audio 都没有绑定设备 |
| BTF/BPF | `resource-monitor-plugin-network` 内嵌 3 个 fentry 程序（tcp_v4_rcv 等），带 CO-RE 重定位。在本次扫描范围内（进程 FD、映射、bpffs）没有发现用户态持有的 BPF；板上没有 bpftool，不能排除只由内核持有的程序。bpf_jit_enable=0，BPF 程序如果加载会走解释器 |
| 其他相关配置 | TRANSPARENT_HUGEPAGE=n（ARM_LPAE=y，架构支持）；IDLE_PAGE_TRACKING=n；HIGHPTE=y；LD_DEAD_CODE_DATA_ELIMINATION=n（架构支持）；VMSPLIT_3G；CONFIG_EXPERT=y；TASK_DELAY_ACCT=y；HIST_TRIGGERS=n、SYNTH_EVENTS=n（不能在内核内做直方图）；KERNEL_GZIP=y；LZ4_COMPRESS、ZSTD_COMPRESS 已内建 |

证据：[09 板上只读采集](09_board_rpi4_readonly.md)、[任务 5c perf 实测](../evidence/task5c/README.md)、[QB 最终配置](../evidence/task5b/qb_arm-rpi4.config)。

### 2.3 低端内存结构（v2 新增）

| 项目 | 实测值 | 说明 |
| --- | --- | --- |
| DMA 区 | present 196,608 页，managed 177,991 页（约 695 MiB） | 全部低端内存都在 DMA 区：RPi 内核为 BCM2711 设置了 `dma_zone_size = SZ_1G`（`arch/arm/mach-bcm/board_bcm2835.c`），而低端内存不到 1 GiB |
| Normal 区 | 0 页 | 空 |
| HighMem 区 | 816,128 页（约 3,188 MiB） | — |
| LowTotal / LowFree | 711,964 KiB / 576,092 KiB（静置） | — |
| CMA | 320 MiB，物理地址 0x1ac00000–0x2ebfffff（428–748 MiB），整体位于低端内存，占低端内存约 46% | 非 CMA 的低端内存约 711,964 − 327,680 = 384,284 KiB（约 375 MiB）；静置时非 CMA 部分空闲约 576,092 − 268,452 = 307,640 KiB（约 300 MiB） |
| Vmalloc | VmallocTotal 245,760 KiB，VmallocUsed 21,208 KiB | vmalloc 地址空间位于内核虚拟地址区，32 位下总量有限 |

**低端内存保护参数实际很弱**：`lowmem_reserve_ratio` 中 DMA 档是 256、Normal 档是 32（`mm/page_alloc.c` 的默认值）。由于本板的低端内存全部在 DMA 区，实际生效的是 256：

- 为 HighMem 请求保留的低端内存 = 816,128 / 256 ≈ 3,188 页 ≈ **12.5 MiB**；
- 如果按内核对 Normal 区的设计意图（32），应为 816,128 / 32 ≈ 25,504 页 ≈ **99.6 MiB**。

同时 `min_free_kbytes` 只有 3,334 KiB，它只按低端内存大小计算。

**这对优先级的影响**：内核静态映像、slab、内核栈、网络缓冲等内核分配都在低端内存中（HIGHPTE=y，页表可以放在 HighMem），非 CMA 的低端内存只有约 375 MiB。以 BTF 为例，它约占非 CMA 低端内存的 1.7%。因此 1 MB 的内核静态节省，比 1 MB 的 zram 载荷节省更有价值；zram 的压缩载荷带 `__GFP_HIGHMEM`，主要位于 HighMem。第 3 节的排序已经考虑了这一点。

证据：[板上内存原始输出](../evidence/task5/A_identity_memory.txt)（含启动日志中 CMA 池地址）、[运行时参数](../evidence/task5/F_memory_runtime.txt)。

### 2.4 采样能力边界（v2 新增）

| 能力 | 结论 | 对方案的影响 |
| --- | --- | --- |
| 硬件计数、cycles 采样 | 可用 | 能拿到“哪些函数热”，可以做函数级热度分析 |
| 分支栈 | 不支持（Cortex-A72 在 32 位下没有可供 perf 使用的分支记录） | 拿不到跳转边和基本块计数 |
| ETM/CoreSight | 板上没有设备；perf 也没有编入 libopencsd | 无法用指令追踪替代 |
| PMU 中断 | 走普通 GIC 中断，ARM32 没有 NMI | 关中断区间内的代码采不到样本，样本会落到开中断之后的位置。“没采到”不等于“冷” |
| llvm-profgen 22.1.8 | 读 perf script 时只接受带 LBR 的输入，只有指令地址的样本报 “Unsupported perfscript!” | 现有流程不能直接用 |

证据：[llvm-profgen 源码（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/llvm/tools/llvm-profgen/PerfReader.cpp) 的 `PerfReaderBase::create()` 与 `checkPerfScriptType()`。

## 3. 候选方案

分组：编译器与代码体积（3.1）、配置裁剪（3.2）、低端内存（3.3）、zram（3.4）、MGLRU（3.5）、用户态协同（3.6）、采样驱动优化（3.7）、不做的项（3.8）。探索性方案见第 7 章。收益都是估算，以实测为准。

### 3.1 编译器与代码体积

#### 3.1.1 ARM 上 -pg 强制帧指针

**依据**：

- Kbuild 在启用 FUNCTION_TRACER 时不加 `-fomit-frame-pointer`（顶层 `Makefile:847–861`），并给所有文件加 `-pg`。
- Clang 22.1.8 在有 `-pg` 且没有 `-mfentry` 时默认保留帧指针（`clang/lib/Driver/ToolChains/CommonArgs.cpp:73`）；显式写 `-fomit-frame-pointer` 时，`getFramePointerKind()` 会得到“不保留”，随后 `Clang.cpp:8069–8072` 报错。ARM 没有 `-mfentry`。
- GCC 在 ARM 上用 `-pg` 时不强制帧指针，GCC 版内核建立帧指针的指令只有 1,741 处。
- 实测：LLVM 内核建立帧指针的指令有 59,969 处（约 232,912 B）；外部展开记录从 1,096 条增加到 43,526 条，其中 43,495 条用 r11 恢复栈，这是 unwind_tab 增长约 0.5 MB 的直接原因。unwind_idx 的 +0.12 MB 与函数数量有关，不一定随帧指针消失。

**安全性**：当前配置是 ARM_UNWIND=y、UNWINDER_FRAME_POINTER=n。ftrace 插桩序列 `push {lr}; bl __gnu_mcount_nc` 不使用 r11；function_graph 的 `prepare_ftrace_return()` 在这个配置下通过 EHABI 的 `unwind_frame()` 找返回地址槽（`arch/arm/kernel/ftrace.c:227–270`）；oops 回溯和 perf 内核调用栈也用 EHABI 表。只要编译器为新的栈布局生成正确的展开记录，省略帧指针在机制上可行。但这仍须实测验证，不能直接宣布安全。perf 的用户态调用栈与内核调用栈机制不同，要分开验收。

**方案（决策顺序）**：

1. 如果产品内核可以不要函数追踪，关闭 FUNCTION_TRACER（3.2），本项随之消失，不需要编译器改动，还能再省 `-pg` 插桩约 0.43 MB。
2. 如果产品需要保留函数追踪，就需要编译器和内核两边配合，改动范围限定为“只有内核显式选择才生效”：
   - **编译器**：Clang 只取消“ARM Linux 目标上 `-pg` 与显式 `-fomit-frame-pointer` 同时出现”时的报错，`-pg` 的默认行为不变。示意（以实际源码为准）：

     ```diff
     --- a/clang/lib/Driver/ToolChains/Clang.cpp
     +++ b/clang/lib/Driver/ToolChains/Clang.cpp
       if (Arg *A = Args.getLastArg(options::OPT_pg))
         if (FPKeepKind == CodeGenOptions::FramePointerKind::None &&
     -        !Args.hasArg(options::OPT_mfentry))
     +        !Args.hasArg(options::OPT_mfentry) &&
     +        !(Triple.getArch() == llvm::Triple::arm && Triple.isOSLinux()))
           D.Diag(diag::err_drv_argument_not_allowed_with) << "-fomit-frame-pointer"
                                                           << A->getAsString(Args);
     ```

   - **内核**：在 `arch/arm/Kconfig` 中新增一个探测符号，用 `-pg -fomit-frame-pointer` 一起探测编译器是否接受；只有在 CC_IS_CLANG、ARM_UNWIND=y、THUMB2_KERNEL=n、探测通过时，才在 FUNCTION_TRACER 打开的情况下追加 `-fomit-frame-pointer`。这样旧编译器、GCC 构建和其他架构都不受影响。
   - 这是平台 PoC 形态，不是可直接上游的通用修复。上游版本需要另外处理 Thumb、其他 profiling 运行时和 ABI 说明，届时再考虑与 GCC 的默认行为对齐。

**先做快速实验**：改编译器之前，先用 `-Xclang -mframe-pointer=none` 构建一次实验内核（直接给编译器前端传参，绕过驱动的报错，不改 Clang），测出真实的体积和性能收益，再决定是否值得修改 Clang。

**预期收益**（LLVM 普通版，估算）：帧指针建立指令约 0.23 MB，unwind_tab 约 0.5 MB；r11 释放为通用寄存器后，还可能带来额外的 .text 和性能变化，另行测量；实际能收回多少由消融构建决定，不承诺全部收回。关闭 FUNCTION_TRACER 的收益不能与本项直接相加。

**风险**：展开记录错误会导致回溯失败或 function_graph 崩溃；使用独立版本的工具链做实验，不影响平台其他包。

**验证**：

- Clang 驱动的正负用例：默认 `-pg` 行为不变；显式省略只在 ARM Linux 生效；x86、Thumb 没有被意外放开。
- 叶函数、非叶函数、栈重对齐、尾调用、不同寄存器保存集合的展开。
- ftrace 普通模式、带寄存器模式、function_graph；模块加载卸载；SMP、中断和异常返回。
- 同一已知调用链的 perf 内核栈；人为触发的 oops 回溯（只在实验镜像上做，由用户安排）。
- 对比 `.text`、exidx/extab、栈峰值和运行性能。

#### 3.1.2 Clang 构建下每任务栈保护失效（提前到阶段 0）

**依据**：本树 `arch/arm/Kconfig:1376–1377`（上游 v6.12.80 中为 1373–1374）的 CC_HAVE_STACKPROTECTOR_TLS 探测不带 `-march`。Clang 对 `arm-linux-gnueabi` 默认 armv4t，报 "hardware TLS register is not supported for the armv4t sub-architecture"，探测失败；补上 `-march=armv7-a` 后通过。Tizen GCC 默认就是 armv7，不受影响。上游主线截至评审时仍是同样的探测，没有可回移植的修复。

**影响**：Clang 编出的 SMP 内核只有一个全局 canary，任务之间的栈保护隔离弱于 GCC 版。这是安全对齐问题。它会改变每个函数的序言代码和体积，所以必须在建立性能基线之前修复，否则后续所有 GCC/Clang 对比和体积数字都会混入这个变量。

**方案**：让探测使用与实际构建相同的目标架构参数。实际的 `-march` 由 `arch/arm/Makefile:63–73` 决定：选了 CPU_32v6 时用 armv6 或 armv6k，只有 CPU_32v7 时用 armv7-a。注意 CPU_V7 会 select CPU_32v6K（`arch/arm/mm/Kconfig`），本配置中 CPU_32v6K=y，所以条件不能写成“非 CPU_32v6K”，否则补丁在本平台不生效。示意：

```diff
--- a/arch/arm/Kconfig
+++ b/arch/arm/Kconfig
 config CC_HAVE_STACKPROTECTOR_TLS
-	def_bool $(cc-option,-mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0)
+	bool
+	default $(cc-option,-march=armv7-a -mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0) if CPU_32v7 && !CPU_32v6
+	default $(cc-option,-march=armv6k -mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0) if CPU_32v6 && CPU_32v6K
+	default $(cc-option,-mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0)
```

本地修复后向上游提交，上游版本需要覆盖 ARMv6、ARMv7、Thumb2 和多平台组合。不要手工把这个隐藏的能力符号强写成 y。

**验证**：

- GCC/Clang 两边 olddefconfig 后的配置比较；最终 STACKPROTECTOR_PER_TASK=y。
- 反汇编确认 canary 通过 `mrc p15, 0, …, c13, c0, 3`（TPIDRURO）按 task 偏移读取，不再读 `__stack_chk_guard`。
- 用测试模块打印两个线程的 `stack_canary`，确认值不同；实验镜像临时启用 LKDTM 跑栈保护用例；SMP 下的任务切换压力测试。
- 体积变化记录在案，作为新基线的一部分。

#### 3.1.3 局部内联膨胀

**依据**：rt2800lib 一个对象就比 GCC 多 332,772 B，r8152 多 43,216 B，主要是寄存器读写辅助函数被大量内联，外加自动初始化的存储。这些驱动在 RPi4 上都没有绑定设备。四个已分析对象只占 `.text` 净增量的约 19%，“与内联相关”也不等于纯内联贡献。

**方案**：优先用 3.2 的配置裁剪（改成模块或关闭）。对确实要保留的驱动，先按对象比较 O2 与 Os（例如 `CFLAGS_REMOVE_rt2800lib.o += -O2`、`CFLAGS_rt2800lib.o += -Os`），检查具体辅助函数的内联收益，通过功能和性能测试后再扩大范围。MLGO 内联体积模型（用户分支 `sandbox/lhmax2025/mlgo` 已有内核接入）作为后续实验，记录模型、目标架构和实际启用参数。自动初始化和栈保护不变。

**验证**：确认 `.cmd` 文件中的最终编译参数；对象和全内核体积；保留的驱动在对应设备上测连接、恢复、吞吐、CPU 和栈峰值（RPi4 没有绑定设备，不能代替这项测试）。

#### 3.1.4 链接期死代码消除（v2 新增）

**依据**：ARM32 已支持 LD_DEAD_CODE_DATA_ELIMINATION（本树 `arch/arm/Kconfig:121`，要求 LLD 或新版 GNU ld，并要求 LD_CAN_USE_KEEP_IN_OVERLAY）。QB 最终配置中 HAVE_LD_DEAD_CODE_DATA_ELIMINATION=y、LD_CAN_USE_KEEP_IN_OVERLAY=y、EXPERT=y，但 LD_DEAD_CODE_DATA_ELIMINATION 没有打开。评审方引用上游提交说明称 zImage 减少 2%–3.2%，需要 Codex 在本树核对该提交及其数据。

**方案**：打开该选项。它会给所有文件加 `-ffunction-sections -fdata-sections`，链接时 `--gc-sections`。

**预期收益**（估算）：按上游数据的量级，常驻段可能减少数百 KB 到 1 MB，全部是低端内存。另外它带来的按函数分段，也是 3.7 中按热度重排函数的前提。

**风险**：Kconfig 帮助文本标明为实验性，缺少 KEEP 标注的段会被静默丢弃，导致功能缺失但能启动。需要逐项核对 initcall、`__ksymtab`、ftrace 记录、`.ARM.exidx` 等段在最终镜像中完整。

**验证**：段表和符号对比（被丢弃的符号逐一归类）；启动、模块加载、ftrace、kprobe、oops 回溯；完整功能冒烟测试。

#### 3.1.5 ARM32 内核 LTO（PoC，低优先级）

本树 ARM32 没有 LTO 的接入路径（arch/arm 没有 select ARCH_SUPPORTS_LTO_CLANG）。本轮不实施。调研以内部分支 `sandbox/sebuns2/use_lto`（a4fe97e1，2020 年，arm64）为起点；3.1.4 的链接期死代码消除作为 LTO 体积收益的下限参照。后续 PoC 先验证链接、启动、模块、汇编引用和 EHABI/ftrace 兼容性，这些不通过就不做收益测试。3.7 的采样驱动优化不以 LTO 为前提。

#### 3.1.6 内核映像改用 LZ4 压缩（开机时间，低优先级）

当前 KERNEL_GZIP=y。改为 KERNEL_LZ4 可以加快开机时的解压，预计开机时间减少几十到一两百毫秒（估算），对运行时内存没有影响；代价是映像变大约 10%–20%，需要确认 boot 分区（64 MiB）的余量。内部分支 `sandbox/sebuns2/kernel_compression`（624d6479，arm64）可作参考。验证：开机到桌面时间、引导加载器读取时间和解压时间。

### 3.2 配置裁剪（常驻内存，全部是低端内存）

下表是 LLVM 普通版的估算（来自 06），各项有重叠，不能直接相加。“RPi4 现状”一列只代表 RPi4 镜像，产品是否需要由用户决定，并需要在产品级开发板上复核。

| 候选 | 估算节省 | RPi4 现状 | 建议 |
| --- | ---: | --- | --- |
| 内核 BTF（DEBUG_INFO_BTF，连带 BTF_MODULES） | 约 6.48 MB | 有静态使用者（网络监控插件的 fentry 程序） | 先完成依赖清单，见下文 |
| KALLSYMS_ALL（由 LATENCYTOP 带出） | 约 1.36 MB | latencytop 运行时为 0 | 关闭 LATENCYTOP 和 KALLSYMS_ALL，保留 KALLSYMS。后果：perf/BPF 对内核数据符号的解析退化，函数符号不受影响；需检查有没有其他选项 select 它 |
| Btrfs | 约 1.33 MB | 没有挂载，但装了 btrfs-progs | 改为模块 |
| NFS + SUNRPC | 约 1.02 MB | 没有挂载 | 改为模块；需确认没有其他 RPC 使用者 |
| 未绑定的 USB 网卡/声卡驱动 | 约 0.97 MB（rt2800usb 0.50、snd-usb-audio 0.29、r8152 0.12，其余合计约 0.06） | 都没有绑定设备 | 改为模块 |
| 追踪设施与 -pg 插桩 | 约 0.90 MB（不含 3.1.1 的帧指针和 unwind） | 运行时都处于关闭状态 | 产品取舍。注意第 4 节的换入延迟测量依赖 function_graph 或 kprobe，实验内核必须保留这些设施 |
| KGDB/KDB | 约 0.12 MB | cmdline 没有 kgdboc | 产品取舍 |
| IRQSOFF_TRACER | 体积很小（约 4 KB） | 当前 tracer 为 nop | 关键在运行开销：每次开关中断都多走 trace_hardirqs_on/off。这段代码在关中断状态下执行，采样看不到，只能用关闭 IRQSOFF_TRACER 和 TRACE_IRQFLAGS 的 A/B 构建，比较内核态 instructions 和 cycles |
| F2FS | — | **在用** | 保留 |

模块化只在模块不加载时节省常驻内存；加载后可能还多出对齐和管理开销。Btrfs、NFS、USB 驱动还涉及恢复模式、升级、网络启动和热插拔，不只是当前有没有挂载。

**BTF 的特殊情况**：

- **已确定的部分**：网络监控插件内嵌的 3 个程序都是 fentry 类型。fentry 依赖 BPF trampoline，而 6.12 的 ARM32 BPF JIT 没有实现：挂载路径首先在 `arch_bpf_trampoline_size()` 的弱符号默认实现处失败（`kernel/bpf/trampoline.c`，返回 -ENOTSUPP，即 -524），`arch/arm/net/bpf_jit_32.c` 没有覆盖它。所以这些程序在 armv7l 上必然无法挂载。这是源码层面的结论，不需要再以找到板上失败日志为前提；板上没有日志只说明没有证据表明它运行过。
- **不能推出的部分**：“fentry 不能用”不等于“关闭 BTF 没有功能损失”。还要考虑：
  1. CO-RE 重定位与挂载类型无关。插件即使改用 kprobe 或 tracepoint（这两种在 ARM32 可用），只要还做 CO-RE 字段重定位，就仍然需要内核 BTF；
  2. ARM32 上不依赖 trampoline、但依赖内核 BTF 的功能仍然可用，例如 tp_btf、bpf_iter；
  3. 静态链接的程序、按需加载的组件、诊断工具不一定出现在当前扫描结果中；
  4. 构建侧的 btf-devel 包和 vmlinux.h 导出。
- **可行的替代路径**：插件改用 kprobe/tracepoint；用 BTFGen（`bpftool gen min_core_btf`）从完整 vmlinux 的 BTF 中只提取插件实际用到的类型，随插件一起发布，通过 libbpf 的 `btf_custom_path` 加载；或者用 pahole 生成独立的 BTF 文件放在文件系统中。外置 BTF 能满足用户程序的 CO-RE 重定位，但不能恢复内核自身依赖 BTF 的能力（tp_btf、bpf_iter、bpftool 的类型化输出）；kfunc、struct_ops、fentry/fexit、BPF LSM 在 ARM32 上本来就不可用。外置 BTF 必须与内核的 build-id 绑定，并测试版本不匹配时会被拒绝。
- **构建侧**：BTF 关闭后 DEBUG_INFO_BTF_MODULES 自动消失；spec 中由 vmlinux 导出 vmlinux.h 的步骤会失败，改为先用 pahole 从 DWARF 生成独立 BTF（`--btf_encode_detached`，需确认 buildroot 中 pahole 1.29 支持），再用 bpftool 导出 vmlinux.h，btf-devel 包保持不变。
- **如果产品必须保留内核 BTF**：见 7.8 的压缩存储方案。
- **决策**：BTF 暂时保留，其他裁剪项照常推进。阶段 2 完成产品的 BPF/CO-RE 依赖清单，并决定网络监控功能的保留方式（改写插件，或登记为功能缺口）之后，再决定是否关闭。armv7l 和 aarch64 分别按依赖清单决定，不按架构一刀切。

**做法**：

1. 先在同一基线上分别测量每个独立裁剪项；
2. 再构建组合变体，测量净收益；
3. 组合后逐项恢复只用来检查项与项之间的相互影响，得到的是“在其他项已裁剪前提下的贡献”，不能当作该项的独立收益。

每次保存最终 diffconfig，核对反向 select、共享库、模块打包和加载行为。Gerrit 上按项拆成独立提交，便于产品方逐项取舍。

**验证**：除静态段外，还要测运行时的低端内存占用：内建的 Btrfs、NFS、SUNRPC 启动后会创建 slab cache、workqueue 和内核线程，所以对比 `/proc/slabinfo` 各 cache 大小、内核线程数和非 CMA 部分的 LowFree。另外检查 RPM 模块文件清单、依赖加载、自动加载、外设热插拔、恢复和升级流程、模块卸载后的内存；perf 内核函数符号解析。

### 3.3 低端内存（v2 新增）

#### 3.3.1 低端内存保护参数

**依据**：见 2.3。默认参数的设计意图是让 Normal 区按 1/32 的比例保护，但本板低端内存全部在 DMA 区，实际只按 1/256 保护（约 12.5 MiB）。HighMem 请求在 HighMem 不足时会退到低端内存，挤占内核自己的分配。

**方案**：运行时把 `lowmem_reserve_ratio` 的 DMA 档从 256 调到 32（约保护 100 MiB），可随时恢复原值。同时记录 `min_free_kbytes`、`watermark_scale_factor` 下各区的水位，必要时作为第二步单独调整。确认有效后再决定落在 resourced 的启动配置，还是内核默认值的平台补丁。

**预期收益**（估算）：高压力场景下，低端内存分配失败和 DMA 区直接回收次数下降。代价是 HighMem 请求更早在 HighMem 内回收。

**风险**：HighMem 回收提前，可能影响后台存活数；需要与 3.4 的 zram 实验分开测。

**验证**：在内存压力场景下比较各区空闲页、`allocstall_dma`、`allocstall_highmem`、低端内存分配失败、后台存活数、切换耗时。

#### 3.3.2 用户/内核地址空间划分（评估，产品决策）

**依据**：当前 VMSPLIT_3G（PAGE_OFFSET 0xC0000000），低端内存不到 760 MiB。VMSPLIT_3G_OPT 可以多出约 256 MiB 低端内存，VMSPLIT_2G 可以多出约 1 GiB，代价是每个进程的用户地址空间从 3 GiB 降到 2.75 GiB 或 2 GiB。改成 2G 后低端内存超过 1 GiB，Normal 区会出现，lowmem_reserve 也会恢复到设计意图。

**方案**：第一步不改内核，只在标准场景中采集所有进程的 VmPeak 和 VmSize 峰值。如果最大值离 2 GiB 有足够余量，再构建 VMSPLIT_3G_OPT 和 VMSPLIT_2G 两个实验变体。

**风险**：浏览器引擎、.NET 运行时等大地址空间进程可能超过 2 GiB；部分程序可能使用固定的高地址映射。这是产品级决策，结论必须在产品板上复核。

#### 3.3.3 CMA

本轮不修改 CMA 容量。记录播放、切台、图形合成和峰值并发时的 CMA 使用量、分配失败和回收延迟，并确认 CMA 在物理内存中的位置。CMA 空闲时可被可移动页借用，不是全部浪费。证明容量冗余或放置不当后，再作为产品配置和驱动问题单独评估。

### 3.4 zram

#### 3.4.1 算法可用性与配置闭环（先做）

**现状问题**：resourced 配置的是 zstd，内核只有 LZO 后端，实际是 lzo-rle。没有日志说明设置失败的原因。

**内核配置要点**：

- `ZRAM_BACKEND_FORCE_LZO` 是自动计算的符号：只要编入任何其他后端，它就变成 n。
- `ZRAM_BACKEND_LZO` 的默认值等于 FORCE_LZO。如果只加 LZ4/ZSTD 而不显式保留 LZO，LZO 后端会消失，默认算法 lzo-rle 也会跟着失效（`drivers/block/zram/Kconfig`）。

LZ4_COMPRESS、ZSTD_COMPRESS 已经内建（lib/zstd 约 0.54 MB 已在镜像中），增加后端只多出胶合代码，体积代价很小。实验内核的配置是：

```diff
+CONFIG_ZRAM_BACKEND_LZO=y
+CONFIG_ZRAM_BACKEND_LZ4=y
+CONFIG_ZRAM_BACKEND_ZSTD=y
+CONFIG_ZRAM_MULTI_COMP=y
+# CONFIG_ZRAM_TRACK_ENTRY_ACTIME is not set
+# CONFIG_ZRAM_MEMORY_TRACKING is not set
```

**基线漂移**：一旦编入 ZSTD 后端，resourced 现有的 `CompAlgorithm=zstd` 会自动生效，基线会在不知不觉中改变。所有 zram 实验都必须显式设定算法，并在每轮开始时回读 `/sys/block/zram0/comp_algorithm`，不能依赖 resourced 当前的配置。

**resourced 侧**：补齐算法可用性检查、写入错误处理和设置后回读；不可用时按明确配置的回退算法处理并记录日志，不再静默回退。算法必须在设置 disksize、swapon 之前设定，不能在已有数据的设备上直接改算法或 reset。实验时按运行时重配处理（swapoff、reset、设算法、设 disksize、mkswap、swapon），不修改板上的 resourced 配置文件。

**验证**：不可用算法、sysfs 写失败、回读不符、字典缺失或损坏、分配失败、CPU 热插拔、重复初始化；每轮做数据往返校验。

#### 3.4.2 算法对比（逐个因素对照）

候选方案：

| 方案 | 主压缩 | 二次压缩 |
| --- | --- | --- |
| 现状 | lzo-rle | 无 |
| zstd | zstd | 无 |
| 同事 Jaehoon 的方案 | zstd（带字典） | 开，并开启访问时间跟踪（ACTIME） |
| 新方案 | lz4（带 armv7 快速解压补丁） | 只对空闲页用 zstd 重压缩 |
| 新方案变体 | 同上 | 用“全部标记空闲、观察一段时间后对仍然空闲的页重压缩”的方式，不开 ACTIME |
| 现状加重压缩 | lzo-rle | 只对空闲页用 zstd 重压缩（把重压缩的收益与 lz4 补丁的收益、风险分开） |
| zstd 低级别 | zstd level=1，无字典 | 无 |

为了能解释结果，按下面的顺序逐个因素对照，不一次混入多个变化：

| 对照 | 目的 |
| --- | --- |
| 原内核 lzo-rle 与新实验内核 lzo-rle | 新增后端和框架本身的成本 |
| lzo-rle、原版 lz4、zstd，都不开二次压缩 | 主算法差异 |
| 原版 lz4 与打了三个补丁的 lz4 | 升级和快速解压的独立价值 |
| 同一主算法，二次压缩关/开 | 二次压缩的价值 |
| 同一算法和级别，字典关/开 | 字典的价值 |
| 同一筛选策略，ACTIME 关/开 | 访问时间跟踪的成本 |

Jaehoon 的 lz4 三个补丁能干净合入，但还没有编译和验证，不能当作已验证正确。

**先做离线预筛**：编内核之前，先离线转储几个后台应用的匿名页，在板上用用户态的 lz4、zstd、lzo 工具测压缩率和速度，一天之内就能排除明显较差的组合，再挑 2–3 个变体编内核。

#### 3.4.3 成本账本

`mm_stat` 的 `mem_used_total` 只统计 zsmalloc 的页，不是 zram 的全部成本。每个方案分项报告：

- zsmalloc 物理页（`mem_used_total`）；
- 槽表：当前 397,648 个槽 × 12 B ≈ 4.55 MiB；开 ACTIME 后约翻倍（每 GiB 约多 3 MiB）；
- 每 CPU 压缩/解压上下文（zstd 的工作区随级别增大）；
- 字典常驻内存；
- zsmalloc 管理对象、临时缓冲和峰值。

不把 `orig_data_size` 或 `compr_data_size` 再加到物理占用上。槽表由 `vzalloc()` 分配，同时报告它占用的 vmalloc 地址空间。对比表中变体的“额外元数据为 0”只表示不增加 ACTIME 的槽表开销，不表示二次压缩没有成本。

上游 zram 重构系列 v7（2026-10-25，15 个补丁）中，第 6 个（zstd 不分配空字典）和第 10 个（zstd 分配不用 kvzalloc）是独立的小改动，与锁模型重构无关，可以单独评估回移植；第 15 个（二次压缩使用单实例上下文）依赖第 11 个的读写流拆分，不单独回移植。

#### 3.4.4 “全部标记空闲”变体的语义和代价

**可行性**：`idle_store()` 只有按秒数标记时才需要 ACTIME，`all` 直接全量标记；zram 读写会清除空闲标记（`zram_accessed()`）。

**语义差别**：这种方法得到的是“从本轮标记到重压缩期间，没有发生 zram 读写的页”，不是按最后访问时间的回看：

- 全表标记不是原子操作；
- 新写入的页、复用的槽、并发访问都会影响候选集合；
- 标记之后才换出的页不带标记，本轮不会被处理，所以方案天然是周期性的，每轮重压缩前都要重新标记；
- 它只反映 zram 的读写活动，不反映页面在用户态的热度；
- 只有“是否被碰过”这一位信息，不能做多级冷度。如果 Jaehoon 的方案需要多级冷度，这个变体不能替代它；
- 空闲标记与写回（writeback）共用同一个标志位。当前不用写回，没有冲突，记录在案。

**代价**：

- `mark_idle()` 的全表循环中没有 `cond_resched()`（`zram_drv.c:291` 起），而本内核是 PREEMPT_VOLUNTARY，标记一次 39.8 万个槽会连续占用 CPU，估算 10–40 ms，同一 CPU 上的 UI 线程会错过帧。补丁（单独提交，提交前查上游是否已有相同修复）：

  ```diff
  --- a/drivers/block/zram/zram_drv.c
  +++ b/drivers/block/zram/zram_drv.c
  @@ static void mark_idle(struct zram *zram, ktime_t cutoff)
   	for (index = 0; index < nr_pages; index++) {
  +		/* idle_store() runs from sysfs with only init_lock held for read */
  +		if (!(index & 1023))
  +			cond_resched();
  ```

  调用方只持有 init_lock 的读锁，可以睡眠，没有功能变化。验证：写满约 1.5 GiB 后执行 `echo all > idle`，用 tracefs 的调度事件比较改前改后的最大调度延迟（perf 没有 libtraceevent，不能用 perf sched）；改后执行 `recompress type=idle`，结果与改前一致。
- 共享的换出页（引用计数大于 1，例如 launchpad 派生进程共享的匿名页）换入时会走 swap cache 预读，预读到的页也会被清掉空闲标记，冷页被当成热页。结果是少重压缩一些，方向保守，但收益偏低。
- 重压缩在槽锁内完成解压和压缩，期间对同一槽的换入要等待；锁在两页之间释放，影响有限，但要分批执行。
- `recompress` 每次调用都从槽 0 开始扫描（`zram_drv.c` 中 recompress_store 的循环），`max_pages` 只限制实际重压缩的次数，不限制扫描长度和墙钟时间。
- 重压缩时原对象和新对象会短暂共存；被 zstd 压缩的冷页如果重新变热，解压长尾会变长。

**调度流程**：

1. resourced 是空闲标记和重压缩的唯一管理者，其他组件不能写 idle。触发时机有两种，实验中都评估：屏灭或待机时；或者按应用生命周期，应用进入后台 T 分钟后标记，再过 T 分钟重压缩；
2. 标记 `idle=all`，等待预先定义的观察窗口；
3. 确认仍允许后台工作；
4. 以较小的 `max_pages` 分批提交 `type=idle` 的重压缩；
5. 每批检查实际耗时和净物理页收益；
6. 收到前台切换事件后，停止提交新批次。

`nice` 不能保证短的不可抢占区间不干扰前台。更严格的可取消机制见第 7 章。

#### 3.4.5 指标与通过条件

**指标**：

- 压缩率和 3.4.3 的分项成本；
- 每页压缩、解压的 CPU 时间；
- 换入延迟分布（最慢 1% 和最大值）；
- 应用切换耗时，包括后台停留 10、30、60 分钟后再切回前台的场景（被 zstd 重压缩过的页正是这时要读回的）；
- kswapd 的 CPU 占用；
- `debug_stat` 中的 writestall（内存紧张时 zsmalloc 分配失败、重新压缩的次数）和 miss_free；
- 一次标记和一次重压缩的 CPU 总量、耗时，以及这期间的换入延迟和切换耗时；
- 后台应用存活数。

**通过条件**：按 1.2 的容差，换入延迟最慢 1%、应用切换耗时（包括长时间后台后切回）、kswapd CPU 都不回退，writestall 不增加，重压缩期间的前台指标也不回退；在此前提下，选同等负载下 zram 总成本最低的方案。

### 3.5 MGLRU

#### 3.5.1 min_ttl_ms

当前 `min_ttl_ms=0` 表示没有启用最小时间窗口的防抖动保护；MGLRU 的代际、分层和 refault 相关机制仍在运行。设置非零值后，如果在这个时间窗口内的工作集无法被保护，内核会直接触发 OOM（`mm/vmscan.c` 中 `lru_gen_age_node()` 调用 `out_of_memory()`），这会绕过 resourced 的查杀策略。

**方案**：先保持 0，完成 zram 算法对比；之后单独测试 100、500、1000 ms 三档，不与算法或 swappiness 同时改变。同时覆盖全局回收和 memcg `force_reclaim` 两条路径。

另外，ARM32 没有硬件维护的访问位（没有 ARCH_HAS_HW_PTE_YOUNG，LRU_GEN_WALKS_MMU 也关闭），老化时每清一次访问位，下次访问就要多一次缺页，老化越激进缺页越多。

**验证**：后台存活数；vmstat 的 oom_kill、被杀进程及其类别（前台、后台、系统）、杀进程的来源（内核 OOM 还是 resourced）；minor fault 次数；前台切换耗时、内存突增。出现内核 OOM 杀掉前台或系统进程，就判定该档不可用。读取各 memcg 实际的 `memory.swappiness`，不用 resourced 配置值代替。

#### 3.5.2 MGLRU-FG（上游在审系列，回移植评估）

**上游现状**：Kairui Song（腾讯）2026 年 5 月发出 RFC；2026-10-16 发出 v4，共 17 个补丁，已经移出 RFC 阶段，基于 mm-new。作者在 Pixel 9 Pro 上做过非正式的 6.1 GKI 回移植（结果噪声较大）。尚未确认进入主线。作者报告的 Chromium 与 Node.js 负载请求数比原 MGLRU 多 75%，但这是服务器环境的数据，不能作为本平台的收益承诺。

**方案**：针对 v4 的 17 个补丁建立依赖清单，参考作者的 6.1 回移植分支估算工作量；重点检查 ARM32 页标志位、memcg v1、HighMem 路径，以及本平台没有 LRU_GEN_WALKS_MMU 的情况。放在阶段 5，以 3.4、3.5.1 的结果作为对照基线；与其他同事负责的 ML 回收方案分开测试。

**验证**：代际计数、迁移与回收竞态、PSI 口径变化、memcg 销毁、长时间压力。

### 3.6 用户态协同（v2 新增）

#### 3.6.1 转入后台前主动归还已无用途的内存

**依据**：应用转入后台后，回收会把它的匿名页压缩进 zram；其中一部分是分配器缓存的空闲块或可重建的缓存，压缩它们既占 zram 也耗 CPU。glibc 的 `malloc_trim()` 和 Linux 的 `madvise(MADV_DONTNEED)` 都是现成机制；Android 官方指南也建议在生命周期转换时归还不需要的匿名页。

**方案**：resourced 在把应用移入后台组之前，先通知可控的应用和服务在安全点释放：可重建的缓存、工作缓冲、分配器的空闲页（glibc 进程先试 `malloc_trim(0)`；musl 或自有分配器走各自接口）。resourced 不对未知地址直接做破坏性的 madvise。

**预期收益**（估算）：如果 4 个后台进程各有 8–20 MiB 可安全归还，可减少 32–80 MiB 驻留；按 2.5:1 的压缩比，相当于少压缩 13–32 MiB 的载荷。这两种收益不能重复相加。

**风险**：前提是确实有可归还的空闲页；`malloc_trim` 不保证清空线程缓存；有锁停顿和随后重新缺页的代价；错误丢弃活对象会造成数据损坏。

**验证**：先挑一两个常驻内存高的进程试验；比较 PSS、SwapPss、zram 实际物理页、切回前台的首帧时间和最慢 1%；反复前后台切换、多线程并发和数据校验。

#### 3.6.2 zsmalloc 碎片与压缩率分开评估

**依据**：本板 `ZSMALLOC_CHAIN_SIZE=8` 已启用；本树已有 `zs_compact()` 和 shrinker。

**方案**：实验镜像打开 `ZSMALLOC_STAT`，读取各 size class 的分布和可释放页数（freeable）。只有在重压缩之后确实存在可释放的碎片时，才评估主动触发 compact，并扣除原生 shrinker 已经释放的部分，避免重复计算收益。

**预期收益**（估算）：上限约为 freeable × 页大小。假设 300 MiB 的池中有 5%–10% 的可整理空洞，上限约 15–30 MiB；没有空洞时收益接近零。静置时只有 1.43 MiB 的池，不支持“可省几十 MiB”的判断。

**风险**：迁移时的锁争用、对象搬运的 CPU、前台解压长尾。

**验证**：同样的匿名内容和存活数，算法固定，compact 关/开；测每毫秒释放的字节数、最慢 1% 延迟、多轮稳态碎片。

### 3.7 采样驱动优化（按 perf 实测结果重写）

**能力边界**：见 2.4。armv7l 上只有指令地址采样，没有分支数据。

**armv7l 内核 AutoFDO**：

- 本树没有 AUTOFDO_CLANG 接入；上游的接入从 6.13 开始，而且不包含 ARM32。
- 上游流程以分支数据为输入。本平台只有指令地址样本，现有 llvm-profgen 不能直接使用。
- Clang 文档给出了不依赖分支数据的转换方式：`create_llvm_prof --use_lbr=false`，但它能否处理 ARM32 内核映像（地址重定位、模块地址）还没有验证。
- 没有分支数据时，profile 只能提供函数级和行级热度，可用的优化主要是冷热分离和保守的内联提示，预期收益很可能落在 2% 的噪声范围内。
- **结论**：本轮不做完整 AutoFDO 接入，降为跟踪项，与 AutoFDO/BOLT Agent 那条线的结果对照。没有本平台数据之前，收益预算按 0 计。armv7l 产品板到位后，如果它的 SoC 开放 CoreSight ETM/PTM 追踪，armv7l 也能拿到分支数据，届时重新评估这一结论。

**本轮做的事：函数级热度驱动的布局与体积优化**（阶段 4）：

1. 在标准场景下做系统范围、只看内核的 cycles 采样（任务 5c 的 32 个样本只是能力测试）；在开发机上离线把样本按函数聚合，使用与镜像 build-id 一致的 vmlinux 和模块。
2. **热函数重排**：在 3.1.4 打开按函数分段的前提下，用 LLD 的 `--symbol-ordering-file` 把热函数集中排列，改善指令缓存和 TLB 局部性。
3. **冷代码体积优化**：对长时间、多场景都没有样本的函数，评估用 `-Os` 或标记为冷代码以减小体积。
   - 这里必须扣除关中断区间：中断处理函数和关中断的代码采不到样本，但不一定是冷的，要先排除，不能直接判为冷。
   - 评审方估算可省 1.3–2.7 MB，这是估算，需要实测。
4. **关中断修正**：对样本落在 `local_irq_restore`、`spin_unlock_irqrestore` 等开中断点附近的函数，把它在关中断区间内直接调用的函数（沿静态调用图展开一层）一并标为热；入口代码、中断处理、调度核心、锁、hrtimer 列入强制热名单。间接调用无法用这种方法修正。
5. **profile 生成与消费**：把函数级热度转成只含函数体计数的 sample profile，编译时用 `-fprofile-sample-use -fprofile-sample-accurate`，让 profile 中没有出现的函数按冷函数处理（按体积优化，并放入 .text.unlikely；链接脚本已经把 .text.hot 和 .text.unlikely 分别归组）。转换路径按成本从低到高依次尝试，前一条可行就不做后一条：
   - `create_llvm_prof --use_lbr=false`（Clang 文档给出的方式，平台没有提供该工具，需要验证能否处理 ARM32 内核映像）；
   - 把每个指令地址样本写成长度为零的区间，构造 llvm-profgen 的 unsymbolized profile 输入，只生成函数体计数；
   - 自写转换器：用 llvm-symbolizer 把指令地址映射到函数、行偏移和内联栈，直接输出文本格式的 sample profile。
6. **最小实验**（成本低，可放在阶段 0）：
   - 在 2–3 分钟的标准场景上采样，统计前 N% 函数占的样本比例，以及被采到的函数占 .text 的比例（一天）；
   - 构建一次全内核 `CONFIG_CC_OPTIMIZE_FOR_SIZE=y`，得到体积节省和性能损失的上限（一次构建加一次 A/B）；
   - 热度高度集中、且全内核按体积优化能省 1.5 MB 以上时，才进入 profile 构建。
7. **需要精确边信息时**：用插桩 PGO 而不是采样。GCC 路线是 `CONFIG_GCOV_KERNEL`（本配置 ARCH_HAS_GCOV_PROFILE_ALL=y）配合 `-fprofile-use`，内部有先例 `sandbox/sebuns2/pgo_applied_kernel`（8423391f，arm64）；Clang 路线需要移植 2021 年 LKML 上未合入主线的 PGO_CLANG 系列，工作量较大。

**风险**：采样偏移（skid）造成边界函数被误判；场景代表性决定收益；对单一流程过拟合。训练场景和验收场景分开（1.3）。

**内核 BOLT**：

- LLVM 22.1.8 的 BOLT 只支持 x86-64 和 AArch64 的 ELF，不支持 ARM32，本轮排除。
- aarch64 上 BOLT 也主要依靠分支数据；RPi4 的 aarch64 镜像同样是 Cortex-A72，同样没有分支记录，只能用不依赖分支记录的模式，效果有限。
- 产品板主要是 armv7l，目前没有 aarch64 产品板，内核 BOLT 只在 RPi4 的 aarch64 镜像上做可行性验证，不作为本项目可交付的优化。

### 3.8 不做的项

- **整组回移植 zram 读写流拆分、可抢占 zram 系列**：当前非 RT 的 local_lock 不存在新版可抢占 zram 所解决的可睡眠流锁优先级反转，不直接套用它的延迟收益。6.12 中 zsmalloc 不带直接回收的分配失败时，会释放压缩流、换用可睡眠的分配，然后重新压缩一次（`zram_drv.c:1547–1592`），可抢占系列消除了这次重复压缩；如果 zstd 主压缩下 writestall 明显，就重新评估回移植其中的“单次压缩”部分。系列中与锁模型无关的内存优化按 3.4.3 单独评估；读写流拆分、共享解压流、单实例二次压缩上下文需要另做依赖和正确性评估，不整组 cherry-pick。上游的 24 CPU 数据不能搬到 RPi4。
- **换入预读参数 page-cluster**：zram 设备带 SWP_SYNCHRONOUS_IO 标志，引用计数为 1 的换入会跳过 swap cache 和预读（`mm/memory.c:4279–4280`），page-cluster 只影响少数共享的换出页，不作为独立方案；只在 3.4 实验中记录共享换出页的比例。
- **CRAM**：需要硬件压缩内存。TV 产品硬件是否有同类能力，没有产品资料，无法核实，不由 RPi4 外推。只跟踪。
- **Kbuild 并行化**：收益集中在增量构建，GBS 全量构建收益有限。不回移植。
- **页缓存读免引用计数**：针对多线程争用，RPi4/TV 核数少；先用 perf 看是否存在相关热点，没有热点就不做。

## 4. 测量方法

### 4.1 静态测量

每个变体分别报告以下各项，不互相替代：

- 静态段字节（按 06 的分类口径）、zImage 大小、模块大小；
- 启动日志 `Memory:` 行的各项和启动后释放的页数；
- 模块驻留；
- 运行期动态分配。

同时记录完整配置、build-id 和模块集合。代码和表项的变化不直接换算成同等的 MemAvailable 收益。

### 4.2 运行时测量

| 类别 | 指标 | 方法要求 |
| --- | --- | --- |
| 内存 | 1.2 中的全机、低端指标；非 CMA 部分的 LowFree；`/proc/zoneinfo` 中 DMA 区的 nr_free_pages、nr_free_cma、protection；CmaFree 最小值；vmallocinfo；应用 PSS 与 SwapPss；memcg v1 的 usage、memsw、stat；3.4.3 的 zram 分项成本；DMA/HighMem/CMA 各区水位；Slab、SUnreclaim、KernelStack、PageTables、VmallocUsed；直接回收次数和 PSI | 按层级统计，不累加父子 memcg；共享页不重复计算 |
| 回收 | refault（文件/匿名）、pswpin/pswpout、kswapd CPU、PSI memory、后台存活应用数、杀进程来源 | 从 /proc/vmstat、/proc/pressure 取差值 |
| zram | mm_stat、io_stat、debug_stat（writestall）、每页压缩/解压耗时、标记和重压缩的耗时 | 测量本身的开销要先单独测出 |
| 延迟 | 见 4.3 | — |
| CPU | cycles、instructions、热点函数 | 按任务 5c 的方式临时推送 perf；perf 不能解析 tracepoint，tracepoint 一律直接用 tracefs |

### 4.3 换入延迟和切换耗时

分四层测量，各层不互相替代：

1. **换入缺页的墙钟时间**：`do_swap_page()` 的进入到返回，包括分配、memcg 计费、页表处理和并发等待。
2. **同步读路径**：`swap_read_folio()`（zram 同步路径会走到 `swap_read_folio_bdev_sync()`）。
3. **zram 内部**：槽锁等待、映射、解压。
4. **应用切换**：从切换请求到第一个满足完成条件的画面。

**换入延迟分布的主要方法：合成微基准**（确定性最好）。在一个 memcg v1 中分配 N MB 匿名内存，填入从后台应用离线转储的真实页面内容（保证压缩率有代表性），用 `memory.force_reclaim` 把它们压进 zram，再逐页访问，用 `clock_gettime` 记录每页的缺页耗时，直接得到分布。

**真实应用**：用 taskstats 的 swapin 延迟（本配置 TASK_DELAY_ACCT=y，运行时打开 `kernel.task_delayacct`），得到每个任务的换入总延迟和次数（只有均值，没有分布）。

**真实应用的单次调用耗时**：用 tracefs 的 function_graph，通过 `set_graph_function` 只跟踪 `do_swap_page` 和 `swap_read_folio`，直接得到每次调用的耗时。它不需要 BTF，也不需要 perf 解析 tracepoint，并且能在开和关之间切换。

本内核没有 HIST_TRIGGERS 和 SYNTH_EVENTS，不能在内核内做直方图；如果确实需要，可以做一个测量专用内核，在 `swap_read_folio` 中加 log2 直方图通过 debugfs 导出，只用于测量，不进入产品。

**抽查方法**：在 `kprobe_events` 中定义 `do_swap_page` 的入口和返回探针，按线程配对；需要检查 `kprobe_profile` 中的 missed 次数和缓冲丢失。

**注意**：

- function_graph 测得的耗时包含睡眠和被抢占的时间，调度延迟可以用 sched 事件解释，但不能从用户可见的墙钟时间中扣除；
- zram 不走通常的块请求调度路径，不能只看 `block_rq_issue/complete`；
- 内存介质的换入缺页不能只按 major fault 的次数筛选；
- 追踪开关本身要做 A/A，用已知人为等待做计时校验，并检查跨 CPU 迁移和缓冲丢失；
- 如果追踪开销影响 2% 门槛的判定，就改用受 static key 控制的窄 tracepoint 或直方图采集，而不是增加全量日志。

### 4.4 标准场景

- 固定应用版本、数据集和完成条件；应用从 Tizen 官方仓库安装，名单在阶段 0 确定。
- 场景覆盖：冷启动、热切换、持续播放与合成、后台积累、内存压力与恢复、后台停留很久之后切回前台。
- 每轮的应用顺序、等待时间都写进脚本。
- 分别评估“同等存活应用数下的成本”和“同等内存预算下的容量”。
- 训练场景与验收场景分离。缓存状态、频率策略和温度区间保持可比。

### 4.5 噪声控制

按 1.3 执行。另外每次实验记录板子状态：内核版本、build-id、uptime、温度、调频策略、其他进程。

## 5. 实验计划

| 阶段 | 内容 | 前提 | 产出 |
| --- | --- | --- | --- |
| 0 | 栈保护探测修复（3.1.2）并重建 LLVM 基线；标准场景脚本、换入微基准、测量工具和 perf 临时部署流程固化；追踪开销测量；A/A 试跑和样本量估算；补采：各 memcg 实际 swappiness、所有进程的 VmPeak、标准场景下的 zoneinfo；函数热度集中度分析和全内核按体积优化的上限构建（3.7 的最小实验） | 无 | 正确、可重复的基线；统计方案；测量设施报告；热度分布 |
| 1 | zram 算法可用性与配置闭环（3.4.1）；逐因素对照（3.4.2）；成本账本（3.4.3）；“全部标记空闲”变体及 `cond_resched` 补丁（3.4.4）；低端内存保护参数（3.3.1）；min_ttl_ms（3.5.1） | 阶段 0 | zram 方案结论；低端内存参数结论 |
| 2 | 独立配置裁剪及组合变体（3.2，BTF 除外）；BTF 依赖清单；链接期死代码消除（3.1.4）；用户态主动归还（3.6.1）；zsmalloc 碎片（3.6.2）；地址空间划分评估（3.3.2，先只看数据）；内核映像 LZ4 压缩（3.1.6，低优先级）。静态体积测量不需要等阶段 0 全部完成，可以先开始 | 阶段 0（运行时部分） | 每项的实际节省（含低端内存和 slab）和产品取舍表 |
| 3 | -pg 不强制帧指针（3.1.1：先用 `-Xclang` 快速实验量化收益，再决定是否做编译器 PoC 加内核探测）；安全配置对齐之后的 GCC 与 Clang 内核运行时对比 | 阶段 0 | 补丁和对比报告 |
| 4 | 局部内联膨胀（3.1.3）；函数级热度驱动的重排与冷代码优化、create_llvm_prof 可行性（3.7）；小尺寸透明大页（7.6） | 阶段 2、3 | 各项继续或停止的结论 |
| 5（PoC） | MGLRU-FG 回移植评估（3.5.2）；ARM32 LTO 可行性（3.1.5）；第 7 章中选定的探索项 | 阶段 1 | 可行性、收益上限、退出条件 |

- 每个阶段独立过门槛；配置、算法、编译器的变化组合后要重新验收。
- 高风险 PoC 不阻塞成熟方案落地，其估算收益也不计入年度承诺。
- 阶段 1、2 可以交替使用板子，但同一块板上的实验不能同时运行。阶段 3 的编译器修改在开发机上完成，最后再上板验证。

## 6. 风险与待确认事项

| 事项 | 影响 | 处理 |
| --- | --- | --- |
| RPi4 不等于 TV 产品 | 配置裁剪、zram、地址空间划分的结论能否用于产品 | 关键结论在产品级开发板上复核 |
| 产品内核由谁维护 | 改动能否进入产品 | 在 sandbox 上完成并验证后，再与相关负责人讨论是否采纳 |
| perf 每次都需要临时部署 | 阶段 0 以后频繁使用 | 已常规授权，任务 5c 的流程写入 RULES.md；下一次 QB 镜像考虑加入 perf 包 |
| 运行时参数修改 | 调频策略、lowmem_reserve_ratio、min_ttl_ms 等实验都要写 `/proc/sys`、`/sys` | 已常规授权；修改前记录原值，结束后恢复并回读确认，同一块板上不并行做两组参数实验 |
| 低端内存和内核虚拟地址空间耗尽 | 实验可能导致分配失败或内核不稳定 | 每项实验设停止条件；保留可恢复的实验镜像 |
| 重压缩与前台竞争、TTL 提前 OOM、算法初始化顺序 | 前台卡顿、后台被杀、zram 初始化失败 | 见 3.4、3.5 的验证项 |
| 模块打包与恢复路径 | 裁剪后恢复模式或升级失败 | 3.2 的验证项 |
| 采样数据过拟合、组合改动的收益重叠 | 收益被高估 | 训练与验收分离；组合后重新验收 |
| 板子与其他工作线共用 | 噪声，测试相互干扰 | 实验期间独占板子；记录其他进程（例如已有的串口 shell） |
| 标准场景需要写 /opt 分区（安装测试应用） | 与“不改系统”的规则有冲突 | 待用户确认是否纳入常规授权；resourced 和内核的改动通过 QB 镜像 |
| 编译器改动的影响面 | 平台上其他使用 `-pg` 的程序 | 只在显式选择时生效（3.1.1）；使用独立版本的工具链做实验 |
| 无法核实的事项 | — | 产品 BOM 和硬件压缩能力；CMA 的实际来源；网络监控插件在产品中的触发条件；resourced 静默回退的真实执行路径。保留为待调查，不预先认定为缺陷或可裁剪 |

**硬件需求**：高质量的采样优化需要分支数据。armv7l 产品板到位后，先只读确认它的 CPU 型号、PMU 能力，以及 SoC 是否开放 CoreSight ETM/PTM（设备节点、设备树、内核配置）。

## 7. 后续研发储备（探索性方案）

本章是基于本平台特点提出的方案，上游没有对应实现，**不是已验证的收益，不计入本轮承诺**。每项先做最小验证实验，结果不成立就停止。等第 3 节的方案实现后再排期。

### 7.1 可恢复游标、可取消的重压缩

- **问题**：`recompress` 每次从槽 0 开始扫描，`max_pages` 只限制重压缩次数，不限制扫描长度；候选稀少或对象已经处于次级算法时，多次分批提交会反复扫全表。TV 在重压缩开始后收到遥控器的切换事件，也没有任务级的取消机制。
- **设计**：每个设备增加任务编号、扫描游标和状态，不增加每槽字段。
  - 每批同时限制扫描槽数、压缩次数和墙钟时间，下一批从游标处继续；
  - resourced 收到前台事件时取消当前任务编号，内核在两页之间检查取消；
  - reset、重配算法、销毁设备都使任务编号失效；
  - 读写仍使用现有槽锁和空闲检查，避免处理已经被复用的槽。
- **粗估**：设一次全表扫描耗时为 T，分 20 批且每批从头扫时，扫描成本接近 20T；用游标后同一轮接近 T。实际收益取决于候选分布。设备级状态只有几十字节，仍然不需要 ACTIME 的约 4.55 MiB。
- **风险**：与 reset、关闭的生命周期竞态；公平性；取消后还要等当前这一页完成；旧 sysfs 接口的兼容。
- **最小实验**：先只给现有循环增加“扫描槽数、实际尝试数、耗时”统计，构造稀疏冷页和大量已重压缩的对象；重复扫描占比明显时，再实现游标原型。

### 7.2 按净物理收益和区域压力结算主动回收

- **问题**：`force_reclaim` 返回成功不代表达到了请求量；回收一页匿名页后，zram 仍保留压缩后的载荷；HighMem 占大多数时，释放 HighMem 不一定能缓解低端内存压力。resourced 只看逻辑回收页数，可能持续做低收益的工作。
- **设计**：不改 victim 选择，不引入 ML。
  - resourced 发起的回收分小批执行，记录请求页数、实际回收页数、匿名和文件来源、CPU 时间、zram 物理页变化、各区压力；
  - 实验内核增加按区域的归属计数，不能用并发系统中的 LowFree 差值冒充；
  - 按“每毫秒净释放字节”决定是否继续；低端内存紧张而本批主要释放 HighMem 时，停止无效追加；
  - 保留旧接口语义，新增统计接口。
- **粗估**：回收 128 MiB 匿名页、压缩比 2.5:1 时，忽略碎片和元数据，净收益约 128 − 128/2.5 = 76.8 MiB，而不是 128 MiB。
- **风险**：并发分配使归因困难；反馈延迟可能造成振荡；不能为了省 CPU 错过必要的应急回收。
- **最小实验**：只加统计、不改策略，跑固定前后台场景，看逻辑回收量与净收益是否稳定偏离、与低端内存压力是否相关；没有明显偏离就不做控制器。只读统计可以在阶段 1、2 先做。

### 7.3 场景驱动的内存策略编排（resourced，不用 ML）

- **问题**：TV 场景流程固定，但 swappiness、水位、zram 重压缩等参数是全局静态的；回收和重压缩的成本可能落在前台路径上。
- **设计**：利用 resourced 已有的状态钩子（屏灭、待机、前后台切换），挂接一张静态策略表。例如：
  - 待机或屏灭时：标记空闲加分批重压缩、提高后台组的 swappiness、主动回收；
  - 视频播放前：提前回收后台冷页；
  - 前台交互时：收紧后台工作。
  全部使用现有 sysctl、memcg、zram 接口，不改内核。
- **粗估**：把回收和重压缩的 CPU 成本移到空闲窗口，方向上可以降低场景切换的最慢 1% 延迟和 PSI full 时间；具体比例无依据，以实验为准。
- **风险**：策略错配导致前台 refault 抖动；每个切换点的参数都要逐个 A/B 定值。
- **最小实验**：用脚本模拟“前台交互、待机、回前台”，在待机段手工执行标记加重压缩，对比回前台时的切换耗时和 refault。不改 resourced 就能判断方向。

### 7.4 切回前台前的预换入

- **问题**：TV 的切换流程固定，切回某个应用之前往往已经能预知；切回时集中换入是切换耗时的一部分。
- **依据**：HPCA 2025 的 Ariadne 在 Pixel 7 上报告平均恢复延迟下降 50%（其他平台的整体系统结果，不是本方案的收益）。`process_madvise()` 支持 `MADV_WILLNEED`，对匿名映射会触发换入，不需要改内核。
- **设计**：resourced 在已经确定即将切回某应用时，对它稳定的关键匿名区域发 `MADV_WILLNEED`，并设严格的内存预算；不改页面置换策略。
- **粗估**：评审方估算可缩短切换关键路径 0.05–0.4 s。如果恢复耗时的 30% 来自换入、提前完成其中一半，理想情况下可隐藏约 15%，同时会增加峰值驻留。
- **风险**：预测错误会白白占内存，并可能触发回收；与 UI 争 CPU；地址空间随机化和映射生命周期问题。
- **最小实验**：先由应用自己访问已知的关键区域，作为收益上限实验；记录有用预取比例、额外驻留、最慢 1% 延迟。局部性没有被证明之前，不做内核改动。

### 7.5 IP 热度加局部插桩，并把 EHABI 成本纳入编译器的优化目标

- **问题**：cycles 样本混合了执行次数和停顿，没有边信息；只按热度内联可能进一步放大 ARM32 的 `.text`、栈帧和 EHABI 表。通用的内联代价模型也不反映本平台最终的常驻成本。
- **设计**：
  - 第一轮用指令地址样本筛出少数高成本函数；
  - 对确实需要边信息的函数，生成实验专用的稀疏计数插桩（每 CPU 计数，排除 noinstr、中断敏感入口和插桩运行时本身）；
  - 用局部计数校正这些函数的分支和内联决策；
  - 优化目标同时看动态耗时和最终 `.text` 加 unwind 的增量；
  - 正式镜像移除插桩。
- **粗估**：如果剩余 1.43 MB 的 `.text` 增量中有 10%–20% 能由更合适的内联和栈布局消除，约 0.14–0.29 MB，需与 3.1.1 去重。
- **风险**：插桩扰动训练行为；中断重入；计数溢出；源码与 profile 错配。
- **最小实验**：选 2–3 个已知热点对象，比较 O2、仅用指令地址热度、加局部计数三组；局部计数不优于仅用热度时停止。

### 7.6 小尺寸透明大页（仅限密集匿名区域）

- **依据**：本板 ARM_LPAE=y，架构支持 THP，但当前 THP 关闭；6.12 已包含多尺寸透明大页（mTHP）。
- **设计**：
  - 打开 THP，但默认所有尺寸为 never；
  - 只把 16 KiB 或 32 KiB 设为 madvise；
  - 由应用对选定的密集匿名区域调用 `MADV_HUGEPAGE`；
  - 关闭直接整理，分配失败时回退到普通页；
  - 不全局启用 2 MiB 大页；
  - 不假设 ARM32 能获得 arm64 连续页表项那样的 TLB 收益。
  先确认 ARM32 LPAE 下 sysfs 实际暴露哪些尺寸。
- **粗估**：如果某启动阶段 10% 的时间花在可摊销的缺页固定开销上，16 KiB 页的理想上界约为 10% × (1 − 1/4) = 7.5%，实际会更低。这是性能候选，不承诺降低内存。
- **风险**：稀疏访问导致驻留放大、压缩和换入放大、写时复制和高阶分配压力。
- **最小实验**：先做密集匿名分配的微基准，再做真实启动和切换；超过内存 3% 门槛就停止扩大范围。放在阶段 4。

### 7.7 单 SoC 定向调优

- **问题**：内核按通用 armv7-a 编译（`arch/arm/Makefile:64`），指令调度没有针对 Cortex-A72。
- **设计**：第一步只加 `-mtune=cortex-a72`，不改变指令集，兼容性不受影响；收益明确后，再评估是否值得使用 ARMv8 AArch32 指令（`-mcpu=cortex-a72`），这一步要核对 AArch32 路径上的 errata 处理和多平台兼容。
- **粗估**：指令调度带来的改善通常在 0–3% 之间（公开编译器数据的量级），可能落在噪声内，判定门槛事先写死。
- **最小实验**：改一行编译参数，构建、启动，做标准场景和微基准的 A/B，一天内可以出结论。

### 7.8 必须保留内核 BTF 时：压缩存储、按需解压

- **问题**：只有在 3.2 的依赖清单表明产品必须保留内核 BTF 时才考虑。BTF 段 6.48 MB 常驻低端内存，但只有加载 BPF 程序或读取 /sys/kernel/btf 时才用到。
- **设计**：构建时用 zstd 压缩 .BTF 并替换原段；第一次需要时（解析 vmlinux BTF、sysfs 读取）解压到 vmalloc 区，页面可以来自 HighMem。需要修改直接引用 `__start_BTF` 的代码（kernel/bpf/btf.c、sysfs_btf.c）；上游近期为 BTF 加了 mmap 支持，要求段按页对齐，需要协调（状态无法核实）。
- **粗估**：BTF 由类型记录和字符串表组成，压缩率估计 3–5 倍；不用 BPF 时约省 4.5–5 MB 低端内存，用 BPF 时改为占用约 6.5 MB HighMem。
- **风险**：与上游 BTF 代码长期分叉；第一次使用时的延迟。
- **最小实验**：用 objcopy 从现有 vmlinux 取出 .BTF，用 `zstd -19` 测压缩率；列出所有引用 `__start_BTF` 的位置。

## 8. 请评审重点关注

1. 1.2、1.3 的验收口径和统计判定是否足以支持“2%/3% 不回退”的结论，在 RPi4 上是否可执行。
2. 2.3 的低端内存分析是否正确；3.3 的保护参数调整和地址空间划分评估是否有遗漏的副作用。
3. 3.1.1 的“编译器取消报错、内核显式探测后启用”的改法，以及 3.1.2 的探测补丁，在本平台和其他 ARM 配置下是否正确。
4. 3.2 的 BTF 依赖清单是否完整，BTFGen/外置 BTF 的替代路径是否可行。
5. 3.4 的 zram 逐因素对照、成本账本、“全部标记空闲”变体的代价分析是否完整。
6. 3.7 在只有指令地址采样的条件下，热函数重排和冷代码优化的做法是否可靠；有没有更好的利用方式。
7. 第 5 节的阶段划分和第 7 章的探索方案排序是否合理。

## 9. 来源

**本项目报告与证据**：

- [01 内核盘点](01_kernel_inventory.md)、[02 Gerrit 重叠盘点](02_gerrit_overlap.md)、[03 构建基线](03_baseline_build.md)、[04 zram 静态核对](04_zram_static.md)、[05 AutoFDO/BOLT 前提](05_kernel_fdo_static.md)、[06 静态内存构成](06_static_footprint.md)、[07 LLVM 代码体积增长](07_llvm_text_growth.md)、[08 sandbox 基线](08_sandbox_baseline.md)、[09 RPi4 板上只读采集](09_board_rpi4_readonly.md)
- [任务 5 内存原始输出](../evidence/task5/A_identity_memory.txt)、[任务 5 运行时参数](../evidence/task5/F_memory_runtime.txt)、[任务 5b QB 最终配置](../evidence/task5b/qb_arm-rpi4.config)、[任务 5b BPF 错误路径](../evidence/task5b/bpf_source_error_chain.txt)、[任务 5c perf 实测](../evidence/task5c/README.md)

**上游源码（版本固定）**：

- Clang 帧指针逻辑：[CommonArgs.cpp（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/lib/Driver/ToolChains/CommonArgs.cpp) 第 73 行、第 223–275 行；[Clang.cpp](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/lib/Driver/ToolChains/Clang.cpp) 第 8069–8072 行
- llvm-profgen 输入类型：[PerfReader.cpp（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/llvm/tools/llvm-profgen/PerfReader.cpp)；`create_llvm_prof --use_lbr=false`：[Clang UsersManual（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/docs/UsersManual.rst) 约第 2905–2917 行
- BOLT 支持的目标：[bolt/README.md（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/bolt/README.md)
- Clang 放宽 ARM 模式 `-mtp=cp15` 限制：[d9b9ebb](https://llvm.googlesource.com/llvm-project/clang/+/d9b9ebb6a34b00507880d675708d856eda1b34f0)
- 内核（v6.12.80）：[顶层 Makefile](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/Makefile) 第 847–861 行；[arch/arm/Makefile](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/arch/arm/Makefile) 第 63–73 行；[arch/arm/Kconfig](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/arch/arm/Kconfig)；[arch/arm/mm/Kconfig](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/arch/arm/mm/Kconfig)（CPU_V7 select CPU_32v6K）；[drivers/block/zram/Kconfig](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/drivers/block/zram/Kconfig)；[zram_drv.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/drivers/block/zram/zram_drv.c)（mark_idle、recompress_store、writestall）；[mm/page_alloc.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/page_alloc.c)（lowmem_reserve_ratio 默认值）；[mm/memory.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/memory.c) 第 4279–4280 行；[mm/vmscan.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/vmscan.c)（min_ttl 与 OOM）；[init/Kconfig](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/init/Kconfig)（LD_DEAD_CODE_DATA_ELIMINATION）；[kernel/bpf/trampoline.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/kernel/bpf/trampoline.c)
- BCM2711 DMA 区大小：[raspberrypi/linux rpi-6.12.y arch/arm/mach-bcm/board_bcm2835.c](https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.12.y/arch/arm/mach-bcm/board_bcm2835.c)

**上游方案（标明状态，核查日期 2026-10-30）**：

- MGLRU-FG：[RFC（2026-05）](https://lkml.iu.edu/2605.0/00922.html)；[v4，17 个补丁，已移出 RFC，在审（2026-10-16）](https://patchew.org/linux/20261016-mglru-fg-v4-0-2106750c0bfa@tencent.com/)。发行版试用和新闻报道只作线索，不作依据
- zram 重构：[v7，15 个补丁，在审（2026-10-25）](https://patchew.org/linux/20261025021839.1542805-1-senozhatsky@chromium.org/)
- swap table：[phase II](https://patchew.org/linux/20251125-swap-table-p2-v3-0-33f54f707a5c@tencent.com)、[phase III](https://lkml.iu.edu/2602.2/02283.html)（基础设施重构，不适合回移植到 6.12，只跟踪）
- Ariadne（HPCA 2025）：[论文](https://arxiv.org/abs/2502.12826)
- 生命周期转换时归还内存：[Android 页面归还指南](https://developer.android.com/topic/performance/memory/guide/page-advice)
- zsmalloc 链长：[6.12 zsmalloc 文档](https://kernel.org/doc/html/v6.12/mm/zsmalloc.html)
- CRAM：[LPC 2026 议程](https://lpc.events/event/20/contributions/2424/)
