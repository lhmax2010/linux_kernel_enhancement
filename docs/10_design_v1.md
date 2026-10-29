# Linux 内核优化设计文档 v1（RPi4 armv7l，6.12.80）

版本：v1，2026-10-30。仓库：`lhmax2010/linux_kernel_enhancement`，本文件位于 `docs/10_design_v1.md`，文中证据链接均相对本目录。

## 0. 文档说明

**目的**：按 2027 年度计划落地 Linux 内核优化，目标是提高性能、降低内存。本文给出现状基线、候选方案、测量方法、实验顺序和通过门槛，作为后续实现的依据。设计冻结前不开始实现。

**范围**：

- 当前开发和验证平台是 RPi4（Tizen 11，armv7l，内核 6.12.80）。它是 TV 产品的替身板；凡涉及产品取舍（功能裁剪、调试能力保留）的结论，都还需要在产品级开发板上复核。
- 先做 armv7l。aarch64 的工作（包括内核 BOLT）放到 armv7l 完成之后。
- 基于机器学习的页面置换和内存回收由另一位同事负责，不在本文范围内。
- 改动对象可以是内核、LLVM/GCC 工具链、glibc/musl、resourced 等用户态组件。本文 v1 以内核和工具链为主，用户态只涉及与内核接口直接相关的部分（resourced 的 zram 配置）。

**基线代码**：Gerrit 分支 `sandbox/lhmax2025/kernel_optimization`，提交 `0fac5de6`。相对 tizen 主线 `42aeefac` 只多两个提交：force_reclaim 修复、启用 ARM_PMUV3。本项目所有内核改动只推送到这个分支。

## 1. 目标与约束

| 项目 | 内容 |
| --- | --- |
| 总目标 | 在不损失产品功能的前提下降低内存占用、提升性能 |
| 不回退容差 | 性能下降不超过 2%，内存增加不超过 3%（与年度计划一致）；超出即判为回退 |
| 判定方式 | 每个方案单独做 A/B，通过条件在实验前写定；同配置两次运行（A/A）测出的波动作为噪声下限，收益必须明显大于噪声才算数 |
| 改动粒度 | 一次只改一项，每项单独分支、单独补丁、单独报告 |
| 证据要求 | 每个结论附 文件:行号、命令输出或日志；估算值必须标明是估算 |
| 板上操作 | 按 RULES.md 的板上规则：三项身份断言、只在 /tmp 下写临时文件、不改根文件系统；重启由用户执行 |

## 2. 现状基线

### 2.1 构建产物（任务 2、3）

两份构建均基于 `f240c280`（不含 PMU 驱动，与当前基线只差一行配置）。

| 项目 | GCC 14.2 | Clang/LLD 22.1.8 | 差值 |
| --- | ---: | ---: | ---: |
| 常驻已分配段合计（普通版） | 32,930,806 B | 35,600,410 B | +2,669,604 B（+8.11%） |
| 其中 .text | 17,808,156 B | 19,862,536 B | +2,054,380 B（+11.54%） |
| .ARM.unwind_tab | 13,152 B | 522,312 B | +509,160 B |
| .ARM.unwind_idx | 391,416 B | 515,568 B | +124,152 B |
| .BTF（常驻） | 6,440,894 B | 6,475,431 B | — |
| 构建耗时 | 58:44 | 36:50 | — |

证据：[06 静态内存构成](06_static_footprint.md)、[07 代码体积增长](07_llvm_text_growth.md)。

### 2.2 运行时（任务 5，sandbox 镜像，LLVM 构建）

| 项目 | 实测值 |
| --- | --- |
| 内核 | 6.12.80-arm-rpi4-v7l，clang 22.1.8 / LLD 22.1.8，2026-10-28 构建；来源（QB 1211696 与 SHA 的对应）待闭合 |
| 内存 | MemTotal 3,976,476 KiB；启动日志：kernel code 20480K、rodata 11884K、rwdata 1867K、bss 575K、reserved 91372K、cma-reserved 327680K |
| CMA | 实际 320 MiB（defconfig 写的是 256 MiB；DTS 是 64 MiB；固件配置未读到） |
| zram | 单设备 zram0，算法 **lzo-rle**，disksize 1,628,766,208 B（MemTotal × 0.4）；没有二次压缩、写回接口 |
| resourced 配置 | `optimizer.conf` 写的是 `CompAlgorithm=zstd`，但内核只编了 LZO 后端，**配置的 zstd 实际没有生效** |
| MGLRU | 已启用（0x0001），`min_ttl_ms=0` |
| 回收参数 | swappiness 60；BackgroundLru 组 swappiness 80；watermark_scale_factor 10；min_free_kbytes 3334 |
| memcg | 只有 v1；67 个 memcg 都有 `memory.force_reclaim` |
| 调度与时钟 | PREEMPT_VOLUNTARY；HZ 实测约 100；cpufreq schedutil，600–1500 MHz；没有 cpuidle 状态 |
| PMU | 驱动已注册（armv8_cortex_a72，7 个计数器）；镜像里没有 perf，硬件计数尚未实测 |
| 追踪与调试 | tracefs 已挂载但 current_tracer=nop、事件全关；function profiler、stack tracer、latencytop 都是 0；cmdline 没有 kgdboc |
| 文件系统 | F2FS 在用（/opt/usr）；ext4 在用；Btrfs、NFS 没有挂载 |
| USB 外设 | 只有 Hub；rt2800usb、r8152、lan78xx、smsc95xx、net1080、snd-usb-audio 都没有绑定设备 |
| BTF/BPF | `resource-monitor-plugin-network` 内嵌 3 个 fentry 程序（tcp_v4_rcv 等），带 CO-RE 重定位；采集时没有运行中的 BPF |

证据：[09 板上只读采集](09_board_rpi4_readonly.md)。

## 3. 候选方案

按来源分四组：编译器与代码体积、配置裁剪、内存回收与 zram、上游方案跟踪。每项给出依据、预期收益、风险和验证方法。收益都是估算，以实测为准。

### 3.1 编译器与代码体积

#### 3.1.1 ARM 上 -pg 强制帧指针（Clang 侧）

**依据**：

- Kbuild 在启用 FUNCTION_TRACER 时不加 `-fomit-frame-pointer`（Makefile:847–861），并给所有文件加 `-pg`。
- Clang 22.1.8 的驱动在有 `-pg` 且没有 `-mfentry` 时默认保留全部帧指针（`clang/lib/Driver/ToolChains/CommonArgs.cpp:73`）；同时显式写 `-fomit-frame-pointer` 会报错（`Clang.cpp:8069–8072`）。ARM 没有 `-mfentry`。
- GCC 在 ARM 上用 `-pg` 时不强制帧指针。
- 实测：除去四个已分析的对象外，LLVM 内核建立帧指针的指令从 1,741 处增加到 59,969 处（约 232,912 B）；外部展开记录从 1,096 条增加到 43,526 条，其中 43,495 条用 r11 恢复栈，这就是 unwind_tab 增长约 0.5 MB 的直接原因。

**方案**（二选一，或者都做）：

1. **编译器侧**：修改 Clang 驱动，让 ARM 目标在 `-pg` 时不强制帧指针。ARM 的 `__gnu_mcount_nc` 约定是调用前把 lr 压栈，不依赖 fp。需要核对：ftrace 函数图追踪（function_graph）在 ARM 上改写的是栈上的返回地址，不依赖 fp；内核用 EHABI 展开（ARM_UNWIND=y），也不依赖 fp。这个改动对平台上所有用 `-pg` 的程序都生效，影响面要单独评估，只对内核生效的方式（例如由内核构建显式传入一个新选项）优先。
2. **内核配置侧**：产品内核如果不需要函数追踪，关闭 FUNCTION_TRACER（同时去掉 `-pg` 插桩）。这属于产品取舍，见 3.2。

**预期收益**（LLVM 普通版，估算）：帧指针相关代码约 0.23 MB 以上，unwind 表约 0.63 MB；如果连 `-pg` 一起去掉，再加约 0.43 MB。

**风险**：编译器改动影响所有 `-pg` 用户；需要验证 ftrace、function_graph、perf 调用栈、oops 回溯都正常。

**验证**：常驻段大小；extab 条目数；ftrace/function_graph 功能测试；perf 调用栈；人为触发的 oops 回溯完整性（只在实验镜像上做，由用户安排）。

#### 3.1.2 Clang 构建下每任务栈保护失效（内核侧）

**依据**：`arch/arm/Kconfig:1373–1374` 的 CC_HAVE_STACKPROTECTOR_TLS 探测命令不带 `-march`。Clang 对 `arm-linux-gnueabi` 默认 armv4t，于是报 "hardware TLS register is not supported for the armv4t sub-architecture"，探测失败；补上 `-march=armv7-a` 后通过。Tizen GCC 默认就是 armv7，不受影响。Clang 自 2021 年起已允许在 ARM 模式的 ARMv6 及以上使用 `-mtp=cp15`（上游提交 d9b9ebb）。

**影响**：Clang 编出的 SMP 内核只有一个全局 canary，任务之间的栈保护隔离弱于 GCC 版。这是安全对齐问题，不是性能项。

**方案**：修改内核的探测，让它带上与实际构建一致的目标架构参数（例如在 CPU_32v7 等条件下附加对应的 `-march`）。需要先查上游主线是否已经修复：修了就回移植，并在提交说明里写明上游提交；没修就在本地修复，同时考虑向上游提交。

**验证**：最终配置中 STACKPROTECTOR_PER_TASK=y；反汇编确认 canary 从 task 偏移读取；任务切换和 SMP 压力下的稳定性；体积变化记录在案。

#### 3.1.3 局部内联膨胀

**依据**：rt2800lib 一个对象就比 GCC 多 332,772 B，r8152 多 43,216 B，主要是寄存器读写辅助函数被大量内联、外加自动初始化的存储。这些驱动在 RPi4 上都没有绑定设备。

**方案**：优先用 3.2 的配置裁剪（改成模块或关闭），这样对常驻内存的收益最直接。对确实要保留的驱动，再考虑按目录使用 `-Os`，或者使用 MLGO 内联体积模型（用户分支 `sandbox/lhmax2025/mlgo` 已有内核接入）。

**验证**：对象和常驻段大小；如果保留驱动，测相应设备的吞吐和 CPU 占用。

#### 3.1.4 ARM32 内核 LTO（PoC，低优先级）

本树 ARM32 没有 LTO 的接入路径（arch/arm 没有 select ARCH_SUPPORTS_LTO_CLANG）。只做可行性调研，不进入本轮实验。

### 3.2 配置裁剪（常驻内存）

下表是 LLVM 普通版的估算（来自 06），各项有重叠，不能直接相加。"RPi4 现状"一列来自任务 5 的板上采集，只代表 RPi4 镜像，产品是否需要由用户决定，并需要在产品级开发板上复核。

| 候选 | 估算节省 | RPi4 现状 | 建议 |
| --- | ---: | --- | --- |
| 内核 BTF（DEBUG_INFO_BTF） | 约 6.48 MB | 有静态使用者（网络监控插件的 fentry 程序），运行时没有观测到 | 见下文"BTF 的特殊情况" |
| KALLSYMS_ALL（由 LATENCYTOP 带出） | 约 1.36 MB | latencytop 运行时为 0 | 关闭 LATENCYTOP，保留 KALLSYMS；需确认 perf/ftrace 对数据符号的需求 |
| Btrfs | 约 1.33 MB | 没有挂载，但装了 btrfs-progs | 改为模块 |
| NFS + SUNRPC | 约 1.02 MB | 没有挂载 | 改为模块；需确认没有其他 RPC 使用者 |
| 未绑定的 USB 网卡/声卡驱动 | 约 0.97 MB（rt2800usb 0.50、snd-usb-audio 0.29、r8152 0.12，其余合计约 0.06） | 都没有绑定设备 | 改为模块 |
| 追踪设施与 -pg 插桩 | 约 0.90 MB（不含 3.1.1 的帧指针和 unwind） | 运行时都处于关闭状态 | 产品取舍；先测量开销 |
| KGDB/KDB | 约 0.12 MB | cmdline 没有 kgdboc | 产品取舍 |
| IRQSOFF_TRACER | 体积很小（约 4 KB） | 当前 tracer 为 nop | 关键在运行开销：每次开关中断都多走 trace_hardirqs_on/off；需要实测这部分开销 |
| F2FS | — | **在用** | 保留 |

**BTF 的特殊情况**：网络监控插件内嵌的 3 个程序都是 fentry 类型。fentry 依赖 BPF trampoline，而 6.12 的 ARM32 BPF JIT 没有实现 trampoline：`kernel/bpf/trampoline.c:1079–1085` 的弱符号默认实现直接返回 -ENOTSUPP，`arch/arm/net/bpf_jit_32.c` 没有覆盖它。因此在 armv7l 上这些 fentry 程序无法挂载，插件的 BPF 部分大概率本来就不能工作。如果板上日志证实这一点，那么在 armv7l 产品内核上关闭 BTF 不会损失现有功能；aarch64 内核则必须保留。需要同时调整 spec 中依赖 BTF 的 btf-devel 和 vmlinux.h 导出。

**做法**：所有裁剪项合成一个"配置裁剪变体"，构建一次，测量常驻段、启动日志的 Memory 行和启动后的 MemAvailable，然后逐项回退，确认每一项的实际贡献。这一组改动在 Gerrit 上按项拆成独立提交，便于产品方逐项取舍。

### 3.3 内存回收与 zram

#### 3.3.1 zram 压缩算法（最高优先级）

**现状问题**：resourced 配置的是 zstd，但内核没有编 zstd 后端，实际用的是 lzo-rle，而且没有任何报错，这个配置等于一直没有生效。

**对比方案**：

| 方案 | 主压缩 | 二次压缩 | 额外元数据（当前 disksize 1.517 GiB） |
| --- | --- | --- | ---: |
| 现状 | lzo-rle | 无 | 0 |
| 编入全部后端，让 resourced 的配置生效 | zstd（来自 resourced 配置） | 无 | 0 |
| 同事 Jaehoon 的方案 | zstd（带字典） | 开，并开启访问时间跟踪 | 普通版约 4.55 MiB |
| 新方案 | lz4（带 armv7 快速解压补丁） | 只对空闲页用 zstd 重压缩 | 见下 |
| 新方案变体 | 同上 | 用"全部标记为空闲、过一段时间再对仍然空闲的页重压缩"的方式，不开访问时间跟踪 | 0 |

关于变体：按 04 的源码核对，按秒数标记空闲才需要访问时间跟踪；"全部标记为空闲"不需要。先把所有页标记为空闲，期间被访问过的页会自动清掉空闲标记，过一段时间再对仍然空闲的页做重压缩，就能拿到相同的冷页筛选效果，而省下每 GiB 3 MiB 的元数据。重压缩由 resourced 在系统空闲时触发。

**前提**：Jaehoon 的 lz4 三个补丁已确认能干净合入；需要编入 LZ4、ZSTD 后端和 ZRAM_MULTI_COMP。

**指标**：

- 压缩率，以及 zram 总占用（含元数据）；
- 每页压缩、解压的 CPU 时间；
- 换入延迟的分布（最慢 1% 和最大值）；
- 应用切换耗时的分布；
- kswapd 的 CPU 占用；
- 重压缩一次的 CPU 开销和耗时；
- 后台应用存活数。

**通过条件**：在换入延迟最慢 1% 和应用切换耗时不变差（不超过 2%）的前提下，选同等负载下 zram 总占用最低的方案。

#### 3.3.2 MGLRU 参数

当前 `min_ttl_ms=0`，也就是关闭了 MGLRU 的工作集保护。可以评估设置一个非零值（例如 1000 ms）对前台卡顿和 OOM/后台查杀的影响。同时记录 swappiness 60 与 BackgroundLru 80 的关系。这一项只改运行时参数，成本低，可以与 3.3.1 共用同一套负载。

#### 3.3.3 MGLRU-FG（上游 RFC，PoC）

上游现状：Kairui Song（腾讯）2026 年 5 月发出 RFC（32 个补丁，基于 mm-unstable，依赖 mglru-reclaim 系列），10 月中旬发出 v4，仍在评审中，尚未进入主线。作者测试以服务器负载为主（LevelDB +41%、MongoDB +16.8%）。

从 6.12 回移植需要先带上 6.12 之后的大量 mm 改动，代价高。本轮只做调研和回移植方案评估，不进入实现；先完成 3.3.1、3.3.2，并以它们的结果作为 PoC 的对照基线。

#### 3.3.4 不做的项

- **ZRAM 读写流拆分、可抢占 zram 系列**：依赖 6.12 之后的可抢占 zram，当前内核是 PREEMPT_VOLUNTARY，6.12 的压缩流在不可抢占的区段内使用，不存在该系列要解决的优先级反转。只在 3.3.1 的实验中记录换入延迟长尾，留作内核升级时的对照。
- **CRAM**：需要硬件压缩内存，TV 没有。只跟踪。
- **Kbuild 并行化**：收益集中在增量构建，GBS 全量构建收益有限。不回移植。
- **页缓存读免引用计数**：针对多线程争用，RPi4/TV 核数少；先用 perf 看是否存在相关热点，没有热点就不做。
- **CMA 大小**：320 MiB 由固件或 DT 决定，取决于 GPU 和编解码需求，属于产品配置，本文只记录。

### 3.4 采样优化（AutoFDO/BOLT）

- **armv7l 内核 AutoFDO**：本树没有 AUTOFDO_CLANG 接入；Cortex-A72 在 32 位下没有可用的分支记录，RPi4 也没有暴露 ETM。只能用不带分支信息的周期采样，精度有限。等板上 perf 可用后，先做一次可行性评估，并与 AutoFDO/BOLT Agent 那条线的结果对照。
- **内核 BOLT**：只支持 aarch64，放到 armv7l 之后。

## 4. 测量方法

### 4.1 静态测量

每个变体构建后：常驻段（按 06 的分类口径）、zImage 大小、模块大小，以及启动日志中 `Memory:` 一行的各项。

### 4.2 运行时测量

| 类别 | 指标 | 方法要求 |
| --- | --- | --- |
| 内存 | 启动后静置 5 分钟的 MemAvailable、MemFree、Slab、KernelStack；标准场景后的同样指标 | 每个变体至少 5 次，报告中位数和波动范围 |
| 回收 | refault（文件/匿名）、pswpin/pswpout、kswapd CPU、PSI memory、后台存活应用数 | 从 /proc/vmstat、/proc/pressure 取差值 |
| zram | mm_stat、io_stat、每页压缩/解压耗时 | 测量本身的开销要先单独测出来，并在报告中说明 |
| 延迟 | 换入延迟分布、应用启动和切换耗时、启动到桌面的时间 | 测量方法在第一阶段由 Codex 设计、经评审后使用 |
| CPU | cycles、instructions、热点函数 | 需要板上有 perf |

### 4.3 标准场景

固定负载：开机，等待静置，依次启动一组固定应用（从 Tizen 官方仓库安装，名单在第一阶段确定），让它们轮流进入后台，再按固定顺序切换回前台。每轮场景的应用顺序、等待时间都固定，并写进脚本。

### 4.4 噪声控制

- 每个变体先做 A/A（同一内核跑两组），得到噪声范围；
- A/B 交错执行，避免温度、时间漂移带来的偏差；
- 收益必须大于噪声范围的两倍，否则判为"无显著差异"；
- 每次实验都记录板子状态：内核版本、uptime、温度、其他进程。

## 5. 实验计划

| 阶段 | 内容 | 前提 | 产出 |
| --- | --- | --- | --- |
| 0 | 板上 perf 可用；标准场景脚本和测量工具；A/A 噪声测量 | QB 构建信息和 perf 包 | 测量设施报告和噪声基线 |
| 1 | zram 算法对比（3.3.1）；MGLRU 参数（3.3.2） | 阶段 0 | zram 方案结论 |
| 2 | 配置裁剪变体（3.2），先确认 BTF 插件在 armv7l 上无法工作 | 阶段 0 | 每项的实际节省和产品取舍表 |
| 3 | 编译器侧：-pg 不强制帧指针（3.1.1）；栈保护探测修复（3.1.2）；GCC 与 Clang 内核的运行时性能对比 | 阶段 0 | 补丁和对比报告 |
| 4 | 内联膨胀（3.1.3）；内核 AutoFDO 可行性（3.4） | 阶段 2、3 | 评估报告 |
| 5（PoC） | MGLRU-FG 回移植评估；ARM32 LTO 可行性 | 阶段 1 | 可行性报告 |

阶段 1、2 互不依赖，可以交替使用板子；阶段 3 的编译器修改在开发机上完成，最后再上板验证。

## 6. 风险与待确认事项

| 事项 | 影响 | 处理 |
| --- | --- | --- |
| RPi4 不等于 TV 产品 | 配置裁剪、zram 结论能否用于产品 | 关键结论在产品级开发板上复核 |
| 产品内核由谁维护 | 改动能否进入产品 | 在 sandbox 上完成并验证后，再与相关负责人讨论是否采纳 |
| 当前运行镜像的来源 | QB 1211696 与 SHA 的对应还没闭合 | 用户提供 QB 构建信息和 devel 包，核对最终 .config |
| 板上没有 perf | 阶段 0 依赖 perf | 从同一次 QB 构建取 perf 包，在 /tmp 下运行，用完删除（需用户同意） |
| 编译器改动的影响面 | 影响平台上所有使用 -pg 的程序 | 优先用只对内核生效的方式；全平台改动单独评审 |
| 测量本身的开销 | 延迟指标可能被测量干扰 | 先单独测出测量开销 |

## 7. 请评审重点关注

1. 第 2 节的基线事实是否有误读，证据是否足以支撑结论。
2. 3.1.1 的判断：ARM 内核在 -pg 下不保留帧指针是否安全（ftrace、function_graph、EHABI 回溯、perf 调用栈）；编译器侧改法和内核侧改法哪种更合适。
3. 3.1.2 的修复方向是否正确，上游是否已经修复。
4. 3.2 中 BTF 的判断（ARM32 没有 BPF trampoline，fentry 无法挂载）是否成立；还有没有其他依赖内核 BTF 的场景被漏掉。
5. 3.3.1 的 zram 方案对比是否完整；"全部标记空闲、再重压缩仍然空闲的页"这个不需要访问时间跟踪的做法是否可行，有没有遗漏的副作用。
6. 第 4 节的测量方法和通过门槛是否足以支持结论；有没有更合适的换入延迟测量方法。
7. 第 5 节的优先级排序是否合理，有没有遗漏的高收益方案。

## 8. 来源

**本项目报告**：

- [01 内核盘点](01_kernel_inventory.md)、[02 Gerrit 重叠盘点](02_gerrit_overlap.md)、[03 构建基线](03_baseline_build.md)、[04 zram 静态核对](04_zram_static.md)、[05 AutoFDO/BOLT 前提](05_kernel_fdo_static.md)、[06 静态内存构成](06_static_footprint.md)、[07 LLVM 代码体积增长](07_llvm_text_growth.md)、[08 sandbox 基线](08_sandbox_baseline.md)、[09 RPi4 板上只读采集](09_board_rpi4_readonly.md)

**上游源码与提交**：

- Clang 帧指针逻辑：[CommonArgs.cpp（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/lib/Driver/ToolChains/CommonArgs.cpp)第 73 行；[Clang.cpp](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/lib/Driver/ToolChains/Clang.cpp)第 8069–8072 行
- Clang 放宽 ARM 模式 `-mtp=cp15` 限制：[d9b9ebb](https://llvm.googlesource.com/llvm-project/clang/+/d9b9ebb6a34b00507880d675708d856eda1b34f0)
- BPF trampoline 弱符号默认实现：[kernel/bpf/trampoline.c（v6.12.80）](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/kernel/bpf/trampoline.c)第 1079–1085 行；[arch/arm/net/bpf_jit_32.c（v6.12.80）](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/arch/arm/net/bpf_jit_32.c)
- PMU 驱动：[drivers/perf/Kconfig（v6.12.80）](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/drivers/perf/Kconfig)第 146–149 行

**上游方案**：

- MGLRU-FG：[RFC（2026-05）](https://lkml.iu.edu/2605.0/00922.html)、[v4 在 Liquorix 中的试用（2026-10）](https://www.linuxcompatible.org/story/liquorix-linux-kernel-7220-ships-experimental-mglrufg-server-memory-code/)、[Phoronix 报道](https://phoronix.com/news/Linux-MGLRU-FG-Patches)
- ZRAM 重构：[v2](https://github.com/linux-mm/linux-mm/pull/5204)、[可抢占 zram 系列](https://ratatoskr.run/linux-mm/2025/03/2952419/t)
- swap table：[phase II](https://patchew.org/linux/20251125-swap-table-p2-v3-0-33f54f707a5c@tencent.com)、[phase III](https://lkml.iu.edu/2602.2/02283.html)（基础设施重构，不适合回移植到 6.12，只跟踪）
- CRAM：[LPC 2026 议程](https://lpc.events/event/20/contributions/2424/)
