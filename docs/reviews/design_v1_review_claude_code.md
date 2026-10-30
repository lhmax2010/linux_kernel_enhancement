# 设计文档 v1 评审意见（10_design_v1.md）

评审日期：2026-10-30。评审对象：`docs/10_design_v1.md`（SHA256 `80ecded8…9249`，与 STATUS 记录一致）。

**核对基准**：

- 结果仓库 `lhmax2010/linux_kernel_enhancement@df92075`，本地与 origin/main 一致；
- 内核源码 `linux-rpi@0fac5de6a630`（即 sandbox 基线），板上最终配置用 `evidence/task5b/qb_arm-rpi4.config`（与任务 4 LLVM 普通版逐字节相同）；
- LLVM 源码 `llvmorg-22.1.8` 以及 `main`，内核主线 `torvalds/linux@master`（7.3 开发周期）；
- 评审要求中给出的三条补充事实，评审时以它们为准。

**约定**：行号未注明出处的，都指 `linux-rpi@0fac5de`。“估算”表示推理得出、尚未实测的数值；“无法核实”表示本次评审拿不到可靠证据，并不代表原文有错。

---

## 一、逐节意见

严重度分为：**阻断**（不改就无法据此判定实验结论）、**重要**（会导致结论偏差或漏掉主要收益或风险）、**一般**（事实或表述需要修正）、**建议**（可以改进的地方）。

### §0 文档说明

**R0-1【一般】范围过窄，与已有授权不一致**

- 位置：§0“范围”第 4 点。
- 问题：团队对 LLVM/GCC、glibc/musl、resourced 都有修改权，但 v1 把用户态限制在“resourced 的 zram 配置”。至少有两件事必须改用户态才能做成：一是 BTF 的取舍，需要改写网络插件的 BPF 挂载方式（见 R3.2-1）；二是 zram 的空闲标记和重压缩调度，需要 resourced 负责（见 R3.3.1-3）。
- 依据：评审背景说明；09 B 节（插件链接 libbpf、内嵌 fentry 程序）。
- 修改方案：
  - 原文：“本文 v1 以内核和工具链为主，用户态只涉及与内核接口直接相关的部分（resourced 的 zram 配置）。”
  - 新文字：“本文 v1 以内核和工具链为主。用户态只涉及与内核接口直接相关的部分：resourced 的 zram 算法、空闲标记与重压缩调度，以及 resource-monitor 网络插件的 BPF 挂载方式和 BTF 来源（决定能否在 armv7l 上关闭内核 BTF）。”

### §1 目标与约束

**R1-1【阻断】容差的分母和指标没有定义，无法判定任何实验是否回退**

- 位置：§1 表格“不回退容差”“判定方式”两行。
- 问题：
  1. “内存增加不超过 3%”没有说明分母。如果按 MemTotal（3,976,476 KiB）计算，3% 约为 116 MiB，比本文所有单项收益都大一个数量级（最大的一项 BTF 只有 6.48 MB），任何内存回退都会被这个容差吸收。
  2. “性能下降不超过 2%”没有说明适用于哪些指标：周期数、应用启动的 P50 或 P90、换入延迟 P99，还是开机时间。
  3. 没有单独约束低端内存（lowmem）。本板 lowmem 是瓶颈，见 R2-2。
- 依据：09 A 节（MemTotal、LowTotal）；本文 §3 的各项收益都在 MB 量级。
- 修改方案：
  - 原文：“性能下降不超过 2%，内存增加不超过 3%（与年度计划一致）；超出即判为回退”
  - 新文字：“性能下降不超过 2%，内存增加不超过 3%（与年度计划一致），超出即判为回退。口径如下：
    - **内存**：分别按 ① 启动后静置 5 分钟、② 标准场景结束后两个时点，取 `MemTotal − MemAvailable` 的中位数，相对基线计算变化率；另设一条独立门槛，**非 CMA 低端内存的空闲量**（`LowFree − DMA 区 CmaFree`）下降不得超过 3%。
    - **性能**：逐项列出指标（应用冷启动和切换耗时的 P50 与 P90、换入延迟 P99、开机到桌面时间、标准场景内核态 cycles），每项单独判定。
    - 任何一项超出容差即判为回退。”

### §2 现状基线

**R2-1【重要】两行事实已过期**

- 位置：§2.2 表格的“内核”“PMU”两行。
- 问题：补充事实 1 和 3 已经闭合，但正文仍写“待闭合”“硬件计数尚未实测”。§5 阶段 0 和 §6 的风险项也以这两点为前提。
- 依据：09 A 节、G 节“任务5c”；`evidence/task5c/10_perf_stat`、`12_perf_evlist`（type 0）、`13_perf_branch`（退出码 255）；`evidence/task5b/config_comparison_summary.txt`。
- 修改方案：
  - 原文：“来源（QB 1211696 与 SHA 的对应）待闭合”
  - 新文字：“来源已闭合：QB 1211696 的 BUILD_PKG_LIST 固定为 `0fac5de6`；公开 devel 包中的 .config 与本地 LLVM 普通版逐字节相同（diffconfig 为空）”
  - 原文：“驱动已注册（armv8_cortex_a72，7 个计数器）；镜像里没有 perf，硬件计数尚未实测”
  - 新文字：“驱动已注册（armv8_cortex_a72，7 个计数器，**没有使用 NMI**）。perf 6.12.80 实测：cycles、instructions、branch-misses 都能计数；cycles 采样的事件类型为 PERF_TYPE_HARDWARE，没有退回软件事件；`perf record -b` 返回“不支持分支栈采样”；没有 CoreSight/ETM 设备”

**R2-2【重要】缺少低端内存结构，这是本平台最关键的约束**

- 位置：§2.2 表格“内存”“CMA”两行之后。
- 问题：设计文档没有提到以下事实，而它们会改变 §3 的收益排序和 §4 的测量口径：
  1. ZONE_NORMAL 为空，**全部 lowmem 都落在 ZONE_DMA**（present 196,608 页，managed 177,991 页，`LowTotal` 为 711,964 kB）。原因是 bcm2711 的机器描述设置了 `.dma_zone_size = SZ_1G`（`arch/arm/mach-bcm/bcm2711.c:21`），在 VMSPLIT_3G 下 lowmem 不到 1 GiB，于是整段 lowmem 都划入 ZONE_DMA。
  2. CMA 池位于物理地址 `0x1ac00000..0x2ebfffff`（428–748 MiB），**整个 320 MiB 都在 lowmem 内**。扣除 CMA 后，内核可用于不可迁移分配（slab、内核栈、模块、网络缓冲等）的 lowmem 约 711,964 − 327,680 = **384,284 KiB（约 375 MiB）**。采集时非 CMA 的 lowmem 空闲量为 576,092 − 268,452 = 307,640 KiB。
  3. 内核静态映像（.text、.rodata、.BTF、kallsyms 等）全部占用 lowmem，所以 §3.1、§3.2 的每一 MB 静态收益都是 lowmem 收益。以 BTF 为例，它约占非 CMA lowmem 的 1.7%。
  4. `lowmem_reserve_ratio` 为 `256 32 0 0`。因为 lowmem 在 ZONE_DMA，实际生效的是 DMA 那一档的 256，而不是内核为“lowmem 对 highmem”设计的 32。由此算出 lowmem 对可用 highmem 的分配只保留 816,128 / 256 ≈ 3,188 页（12.5 MiB）；如果按设计意图的 32 计算，应为 25,504 页（99.6 MiB）。计算依据是 `mm/page_alloc.c:276-288` 和 `6090-6117`。
- 依据：`evidence/task5/A_identity_memory.txt:37-40,64-65,69-86`；`evidence/task5/F_memory_runtime.txt:70-71`；VmallocTotal 为 245,760 kB。
- 修改方案：在“CMA”行之后插入一行。
  - 新文字：“| 低端内存 | LowTotal 711,964 kB，全部位于 ZONE_DMA（ZONE_NORMAL 为空，`dma_zone_size=SZ_1G`）；CMA 320 MiB 整体位于 lowmem（428–748 MiB）。非 CMA 的 lowmem 约 375 MiB，静置时空闲约 300 MiB。HighMem 3,264,512 kB。lowmem_reserve_ratio 为 `256 32 0 0`，lowmem 对 highmem 分配的保护约 12.5 MiB（计算值）。内核静态映像、slab、内核栈都占用 lowmem；HIGHPTE=y，页表可以放在 highmem |”

**R2-3【一般】“没有 cpuidle 状态”的根因写错**

- 位置：§2.2“调度与时钟”。
- 问题：没有 cpuidle 状态是因为最终配置里 `# CONFIG_CPU_IDLE is not set`，属于配置事实，不是硬件事实。
- 依据：`qb_arm-rpi4.config` 中 CPU_IDLE 未设置。
- 修改方案：
  - 原文：“没有 cpuidle 状态”
  - 新文字：“CONFIG_CPU_IDLE 未启用（因此没有 cpuidle 目录）”

**R2-4【一般】BTF/BPF 一行表述过强**

- 位置：§2.2“BTF/BPF”。
- 问题：“采集时没有运行中的 BPF”超出了证据范围。板上没有 bpftool，只能证明用户态进程没有持有 BPF 的 FD 或 pin。另外 `bpf_jit_enable=0`（ARM32 没有选 ARCH_WANT_DEFAULT_BPF_JIT），没有写进表里。
- 依据：09 B 节“扫描是顺序快照…不排除内核独立持有的 attach”；09 B 节任务5b 表格中 bpf_jit_enable 为 0。
- 修改方案：
  - 原文：“采集时没有运行中的 BPF”
  - 新文字：“采集时未发现用户态持有的 BPF FD 或 pin（没有 bpftool，不能排除只由内核持有的程序）；bpf_jit_enable=0，BPF 程序如果加载，会走解释器”

**R2-5【一般】zram 快照不能代表工作负载**

- 位置：§2.2“zram”。
- 问题：mm_stat 显示 orig_data 约 2.4 MiB，说明快照取自静置状态。zram 的压缩率和换入频度必须在标准场景中采集。表中应注明这一点，以免后续拿静置值当基线。
- 修改方案：在该行末尾追加：“（静置快照：orig_data_size 约 2.4 MiB，不代表场景负载）”。

### §3.1.1 -pg 强制帧指针

**R3.1.1-1【重要】收益估算把与帧指针无关的 unwind_idx 增量也算了进去**

- 位置：§3.1.1“预期收益”。
- 问题：unwind 表约 0.63 MB 是 `.ARM.unwind_tab` 增加的 509,160 B 加上 `.ARM.unwind_idx` 增加的 124,152 B。其中 idx 的增量来自 exidx 条目数从 48,927 增加到 64,446（每条 8 B），也就是两种编译器产生的函数或分片数量不同，与帧指针无关。只有 extab 那部分可以归因于帧指针：43,495 条 vsp=r11 记录，每条 12 B，约 0.52 MB。另外，去掉帧指针后 r11 可以作为通用寄存器使用，还会有额外的 .text 和性能收益，但目前没有量化。
- 依据：07 §4 表格（exidx 条目数、model 1 条目数、vsp=r11 条目数）以及“每个外部记录12 B”。
- 修改方案：
  - 原文：“帧指针相关代码约 0.23 MB 以上，unwind 表约 0.63 MB；如果连 `-pg` 一起去掉，再加约 0.43 MB。”
  - 新文字：“帧指针建立指令约 0.23 MB 以上；`.ARM.unwind_tab` 预计回落约 0.5 MB（43,495 条 r11 外部记录，每条 12 B）；`.ARM.unwind_idx` 的 0.12 MB 增量来自函数数量差异，不归入本项。r11 释放为通用寄存器后带来的 .text 和性能变化另行测量。如果连 `-pg` 一起去掉，再加约 0.43 MB（与 3.2 的“追踪设施与 -pg 插桩”重叠，不能相加）。”

**R3.1.1-2【重要】改法建议：用“允许显式组合”代替“改默认值”或“新增选项”**

- 位置：§3.1.1“方案”第 1 点。
- 问题：原文的两种改法都有缺点。“改驱动默认值”会影响平台上所有 `-pg` 用户；“新增一个选项”需要维护新的公共接口。更小的改法是保持默认行为不变，只取消 ARM GNU EABI 下 `-pg` 与 `-fomit-frame-pointer` 同时出现时的报错，再由内核显式传入 `-fomit-frame-pointer`。这样改动对现有构建零影响：原来同时写这两个选项会直接报错，所以不可能有人依赖这种组合。
- 依据：
  - `CommonArgs.cpp:73-74`（22.1.8）：`-pg` 且没有 `-mfentry` 时默认强制帧指针。LLVM main 的 `CommonArgs.cpp:87` 仍然一样，**上游没有修改**。
  - `Clang.cpp:8069-8072`：显式写 `-fomit-frame-pointer` 时报错。
  - 内核侧不依赖帧指针：
    - `arch/arm/kernel/ftrace.c:238-265`：UNWINDER_ARM 下，function_graph 用 EHABI 的 `unwind_frame()` 找到返回地址所在的栈位置，不读 fp；
    - `entry-ftrace.S:119,169`：非帧指针展开器下，parent 地址取自 sp 偏移；
    - 提交 953f534a7ed6：FP_TEST 改为比较入口和出口的 SP；`fgraph.c:714` 做这项检查；
    - `perf_callchain.c:96-97`：内核调用栈走 `walk_stackframe`，也就是 EHABI；
    - 最终配置为 UNWINDER_ARM=y、UNWINDER_FRAME_POINTER 未设置。
  - Kbuild 侧：`Makefile:847-861` 在有 FUNCTION_TRACER 时不加 `-fomit-frame-pointer`。
- 修改方案：替换方案第 1 点为下文，并附两份 diff。
  - 新文字：“**编译器侧**：不改 `-pg` 的默认行为，只在 ARM/Thumb 且使用 GNU EABI（mcount 为 `__gnu_mcount_nc`）时，允许显式的 `-fomit-frame-pointer` 与 `-pg` 共存。**内核侧**：用 Kconfig 探测编译器是否接受这一组合，接受时在 arch/arm/Makefile 中为 Clang 加上 `-fomit-frame-pointer`。对其他 `-pg` 用户没有任何影响。在正式修改编译器之前，可以先用 `KCFLAGS='-Xclang -mframe-pointer=none'` 构建一次实验内核，测量体积和性能收益（这只是实验手段，不进入产品；需要确认 cc1 取最后一个值）。”

LLVM diff（示意，基于 22.1.8 `clang/lib/Driver/ToolChains/Clang.cpp:8069`，位于 `Clang::ConstructJob`，`Triple` 即该函数开头的 `TC.getEffectiveTriple()`）：

```diff
-  if (Arg *A = Args.getLastArg(options::OPT_pg))
-    if (FPKeepKind == CodeGenOptions::FramePointerKind::None &&
-        !Args.hasArg(options::OPT_mfentry))
+  // On ARM/Thumb with the GNU EABI, -pg calls __gnu_mcount_nc, which gets the
+  // caller's LR pushed on the stack and never walks the frame chain, so an
+  // explicit -fomit-frame-pointer is compatible with -pg there.
+  bool ARMGnuMcount = (Triple.isARM() || Triple.isThumb()) &&
+                      (Triple.isGNUEnvironment() ||
+                       Args.getLastArgValue(options::OPT_meabi) == "gnu");
+  if (Arg *A = Args.getLastArg(options::OPT_pg))
+    if (FPKeepKind == CodeGenOptions::FramePointerKind::None &&
+        !Args.hasArg(options::OPT_mfentry) && !ARMGnuMcount)
       D.Diag(diag::err_drv_argument_not_allowed_with) << "-fomit-frame-pointer"
                                                       << A->getAsString(Args);
```

内核 diff：

```diff
--- a/arch/arm/Kconfig
+++ b/arch/arm/Kconfig
@@ config CC_HAVE_STACKPROTECTOR_TLS 之前
+config CC_CAN_OMIT_FRAME_POINTER_WITH_PG
+	def_bool CC_IS_CLANG && $(cc-option,-pg -fomit-frame-pointer)
+
--- a/arch/arm/Makefile
+++ b/arch/arm/Makefile
@@ KBUILD_CFLAGS += -mtp=cp15 之后
+ifeq ($(CONFIG_FUNCTION_TRACER)$(CONFIG_CC_CAN_OMIT_FRAME_POINTER_WITH_PG),yy)
+ifndef CONFIG_FRAME_POINTER
+# Clang keeps a frame pointer in every function when -pg is used, but
+# __gnu_mcount_nc and the EHABI unwinder (UNWINDER_ARM) do not need one.
+KBUILD_CFLAGS	+= -fomit-frame-pointer
+endif
+endif
```

- 副作用：
  - 显式要求帧指针的文件不受影响，例如 `kernel/sched/Makefile` 中的 `-fno-omit-frame-pointer` 追加在后面，仍然生效；
  - 使用 `__builtin_frame_address(0)` 的函数，编译器会自动为它保留帧指针；
  - 含变长数组或 alloca 的函数，编译器同样会保留帧指针；
  - EHABI 条目会从 r11 相对编码变为 sp 相对编码，内核展开器两种都支持；
  - GCC 构建不变，因为该选项只对 Clang 生效；
  - 用旧版 Clang 构建时探测失败，行为与现在相同。
- 需要增加的测试：
  - LLVM lit 测试：`--target=arm-linux-gnueabi -meabi gnu -pg -fomit-frame-pointer -###` 不报错，并带 `-mframe-pointer=none`；x86_64 和 aarch64 仍然报错。CodeGen 测试分 ARM 和 Thumb2 两种，函数入口有 `push {lr}; bl __gnu_mcount_nc`，没有 `add r11, sp`。
  - 内核静态检查：`readelf -u` 中 vsp=r11 的 extab 条目从 43,495 降到 GCC 的量级（935）；`.ARM.unwind_tab` 和 `.text` 的大小。
  - 功能测试（实验镜像）：开启 `CONFIG_FTRACE_STARTUP_TEST` 自检 function 和 function_graph；在负载下运行 `function_graph` 10 分钟，确认没有 fgraph 的“Bad frame pointer”告警（`fgraph.c:714`）；`perf record -g` 的内核调用栈深度分布与基线对比；`echo t > /proc/sysrq-trigger` 打印全部任务栈，确认没有展开失败；用 lkdtm 的 WARNING 和 BUG 检查回溯是否完整；kprobe、kretprobe 冒烟测试。
  - 性能测试：hackbench、lmbench 的 lat_syscall 和 lat_ctx，以及标准场景内核态 cycles。

### §3.1.2 Clang 下每任务栈保护失效

**R3.1.2-1【一般】行号有误**

- 位置：§3.1.2“依据”。
- 问题：`arch/arm/Kconfig:1373–1374` 应为 **1376–1377**（07 §6 写的就是 1376–1377）。
- 修改方案：
  - 原文：“`arch/arm/Kconfig:1373–1374`”
  - 新文字：“`arch/arm/Kconfig:1376–1377`（主线 master 为 1371–1372，内容相同）”

**R3.1.2-2【一般】上游状态和修复方案需要写实**

- 位置：§3.1.2“方案”。
- 问题与依据：
  - 主线 master 的 `arch/arm/Kconfig:1371-1372` 仍是不带 `-march` 的同一条探测，**上游没有修复**。是否有 LKML 讨论无法核实。
  - 探测失败的后果：`STACKPROTECTOR_PER_TASK` 依赖 `GCC_PLUGINS || CC_HAVE_STACKPROTECTOR_TLS`（`arch/arm/Kconfig:1382`），Clang 构建两者都为假，所以所有 Clang 的 ARM32 SMP 构建都只有一个全局 canary。
  - 正确的 `-march` 来自 `arch/arm/Makefile:63-70`：v7 用 armv7-a；v6 和 v6K 混合配置用 armv6k。
  - 提交 d9b9ebb 的具体内容无法核实。07 的对照实验已经证明加上 `-march=armv7-a` 后探测通过，修复方案不依赖这一提交。
- 修改方案：
  - 原文：“需要先查上游主线是否已经修复：修了就回移植，并在提交说明里写明上游提交；没修就在本地修复，同时考虑向上游提交。”
  - 新文字：“上游主线（master，arch/arm/Kconfig:1371–1372）未修复。在本地修复，并向 linux-arm-kernel 和 ClangBuiltLinux 提交：探测时带上与 arch/arm/Makefile:63–70 一致的 `-march`。”

```diff
--- a/arch/arm/Kconfig
+++ b/arch/arm/Kconfig
@@ -1376,2 +1376,9 @@
 config CC_HAVE_STACKPROTECTOR_TLS
-	def_bool $(cc-option,-mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0)
+	bool
+	# Probe with the -march used for the actual build (arch/arm/Makefile):
+	# Clang's default arm-linux-gnueabi CPU is ARMv4T, which rejects -mtp=cp15.
+	default $(cc-option,-march=armv7-a -mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0) if CPU_32v7 && !CPU_32v6
+	default $(cc-option,-march=armv6k -mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0) if CPU_32v6K && CPU_32v6
+	default $(cc-option,-mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0)
```

（Kconfig 取第一个条件成立的 default，所以无条件的那一行必须放在最后。）

- 副作用：
  - 每个受保护函数的 canary 读取从“字面池地址 + ldr”变为 `mrc p15,0,rX,c13,c0,3` 加 `ldr [rX,#TSK_STACK_CANARY]`，体积大致相当，需要实测；
  - GCC 构建的结果不变，因为 GCC 默认就是 armv7，探测本来就通过；
  - `-mtp=cp15` 已经由 `arch/arm/Makefile:126-128` 加入。
- 需要增加的测试：
  - 最终配置中 `STACKPROTECTOR_PER_TASK=y`；任意 .cmd 中出现 `-mstack-protector-guard=tls -mstack-protector-guard-offset=<TSK_STACK_CANARY>`；
  - 反汇编抽查 20 个受保护函数；
  - 用测试模块打印两个线程的 `current->stack_canary`，确认值不同；
  - 在实验镜像上用 lkdtm 的 `CORRUPT_STACK_STRONG` 触发检测；
  - 用 hackbench 和 stress-ng 做上下文切换压力测试 30 分钟；用 lat_ctx 和 lat_syscall 测性能；记录 .text 的变化。

### §3.1.3 局部内联膨胀

**R3.1.3-1【建议】把“按目录 -Os”升级为由采样热度驱动的冷代码体积优化**

- 位置：§3.1.3“方案”。
- 问题：rt2800lib 和 r8152 在 RPi4 上没有绑定设备，配置裁剪就能解决。真正值得做的是全内核范围：在 Clang 构建的 .text 增量中，69.65% 无法归因到具体对象（07 §3），这部分只能靠整体策略处理。指令地址采样足以区分函数的冷热（见 R3.4-1），可以让冷函数按体积优化。
- 修改方案：在原方案末尾追加：“对全内核，评估由采样热度驱动的冷代码体积优化（见评审 C1）；按目录 -Os 只作为没有 profile 时的退路。”

### §3.1.4 ARM32 LTO

**R3.1.4-1【一般】漏掉已有的内部尝试，也漏掉了更便宜的中间步骤**

- 问题：
  1. 内部分支 `sandbox/sebuns2/use_lto`（a4fe97e13a49，2020 年）曾为 arm64 接入过 LTO（修改了 init/Kconfig、scripts/gcc-ld、link-vmlinux.sh），可以作为调研起点。
  2. ARM32 已经支持 `LD_DEAD_CODE_DATA_ELIMINATION`（上游提交 ed0f94102251，v6.11；本树已带后续修复 0d437918fb64、9f7ae45f0c61、6ed79cf1183a），能拿到 LTO 的一部分体积收益，而且风险低得多（见 B2）。
- 依据：`evidence/task1/sandbox__sebuns2__use_lto_summary.txt`；`git show --stat a4fe97e13a49`；`arch/arm/Kconfig:122`；最终配置中 `# CONFIG_LD_DEAD_CODE_DATA_ELIMINATION is not set`（选项可见但未启用）。
- 修改方案：
  - 原文：“只做可行性调研，不进入本轮实验。”
  - 新文字：“只做可行性调研，不进入本轮实验；调研以内部 sandbox/sebuns2/use_lto（a4fe97e1，arm64）为起点。本轮先做 LD_DEAD_CODE_DATA_ELIMINATION（ARM32 上游自 v6.11 起支持），作为 LTO 体积收益的下限参照。”

### §3.2 配置裁剪

**R3.2-1【重要】BTF 的判断成立，但其他依赖场景和替代路径不完整**

- 位置：§3.2“BTF 的特殊情况”。
- 问题与依据：
  1. **判断成立**：`kernel/bpf/trampoline.c:1079-1085`（弱 prepare 函数）和 `:1115-1118`（弱 size 函数）都返回 -ENOTSUPP；`arch/arm/` 没有覆盖实现。按 09 的错误链分析，失败会先发生在 size 函数（返回 -524），而不是 prepare 函数。板上没有加载失败的日志（补充事实 2），所以这只能写作“源码确定无法挂载”，不能写作“实测失败”。
  2. **漏列的 BTF 用途**：
     - ARM32 上**仍然可用**、但依赖内核 BTF 的功能：tp_btf（走 raw tracepoint，`kernel/bpf/syscall.c:3837/3960`，不经过 trampoline）、bpf_iter，以及 bpftool 的类型化输出；
     - 用户态 CO-RE 只在加载时需要一份 vmlinux BTF，可以来自文件，不一定来自内核；
     - ARM32 上**本来就不可用**的功能：fentry、fexit、fmod_ret、struct_ops、BPF LSM（需要 trampoline；BPF_LSM 也未启用）；kfunc 调用（ARM32 JIT 没有实现 `bpf_jit_supports_kfunc_call`，而 arm64 和 x86 都实现了）。
  3. **DEBUG_INFO_BTF_MODULES=y** 必须一起关闭，否则每个模块还会带 .BTF（不过 BTF 关闭后该选项会自动消失）。
  4. **替代路径**：插件把 fentry 改成 kprobe（ARM32 可用）；CO-RE 所需的 BTF 由文件提供：
     - 完整的 detached BTF 放在闪存上，libbpf 会在若干标准路径查找，具体路径列表需要对照 libbpf 1.6.2；
     - 或者用 bpftool 的 BTFGen（`bpftool gen min_core_btf`）只为该程序生成最小 BTF，通过 `bpf_object_open_opts.btf_custom_path` 传入。
     - 这样内核 BTF 的 6.48 MB lowmem 可以全部省下，同时保留插件功能。
  5. **spec 调整**：关闭 BTF 后，`packaging/linux-rpi.spec:225-226` 对 vmlinux 做的 `bpftool btf dump` 会失败。改为用 pahole 从 DWARF 生成 detached BTF 即可（`CONFIG_PAHOLE_VERSION=129`）。
- 修改方案：
  - 原文：“因此在 armv7l 上这些 fentry 程序无法挂载，插件的 BPF 部分大概率本来就不能工作。如果板上日志证实这一点，那么在 armv7l 产品内核上关闭 BTF 不会损失现有功能；aarch64 内核则必须保留。需要同时调整 spec 中依赖 BTF 的 btf-devel 和 vmlinux.h 导出。”
  - 新文字：“因此按源码，这些 fentry 程序在 armv7l 上无法挂载（第一处失败在 `arch_bpf_trampoline_size` 弱实现，返回 -ENOTSUPP，即 524）；板上没有找到加载失败日志，所以是源码结论，不是实测结论。ARM32 上依赖内核 BTF 且仍然可用的只有 tp_btf、bpf_iter 和类型化输出；kfunc、struct_ops、fentry、fexit、LSM 本来就不可用。建议：① 插件改用 kprobe 挂载，CO-RE 所需的 BTF 由 BTFGen 生成的最小 BTF 或闪存上的 detached BTF 提供；② armv7l 产品内核关闭 DEBUG_INFO_BTF（DEBUG_INFO_BTF_MODULES 随之关闭）；③ spec 改为用 pahole 从 DWARF 生成 detached BTF，再导出 vmlinux.h，btf-devel 包保持不变；④ aarch64 内核保留 BTF。”

```diff
--- a/arch/arm/configs/tizen_bcm2711_defconfig
+++ b/arch/arm/configs/tizen_bcm2711_defconfig
@@ -532 +532 @@
-CONFIG_DEBUG_INFO_BTF=y
+# CONFIG_DEBUG_INFO_BTF is not set
--- a/packaging/linux-rpi.spec
+++ b/packaging/linux-rpi.spec
@@ -225,2 +225,4 @@
-       # Generate vmlinux.h from vmlinux binary
-       ./build/${target}/bpftool btf dump file build/${target}/vmlinux format c > build/${target}/btf/vmlinux.h
+       # Kernel BTF is not embedded on armv7l; encode a detached copy from DWARF
+       pahole -J --btf_encode_detached=build/${target}/btf/vmlinux.btf build/${target}/vmlinux
+       ./build/${target}/bpftool btf dump file build/${target}/btf/vmlinux.btf format c > build/${target}/btf/vmlinux.h
```

（defconfig 是 armv7l 专用的，arm64 使用自己的 defconfig，不受影响。pahole 的 `--btf_encode_detached` 选项需要在 buildroot 的 pahole 1.29 上确认。）

- 副作用：
  - `/sys/kernel/btf/vmlinux` 消失；bpftrace 等依赖内核 BTF 的工具降级；
  - 插件需要发布新版本；
  - 需要确认 vmlinux.h 生成前后逐字节一致，或者 diff 只在预期范围内；
  - .BTF_ids 段约 1.9 KB 仍会保留。
- 需要增加的测试：
  - 静态：最终配置中 BTF 相关选项全部为 n；启动日志 `Memory:` 行中 rodata 减少约 6.3 MB；vmlinux.h 与旧版对比。
  - 板上：改造后的插件能加载并挂载，采集到的 TCP 指标与预期一致；libbpf 能找到 BTF（strace 或 libbpf 调试日志）。
  - 内存：非 CMA 的 LowFree 增量。

**R3.2-2【一般】只算了静态段，漏掉了运行时 lowmem 占用**

- 位置：§3.2“做法”。
- 问题：Btrfs、NFS、SUNRPC 内建时，启动后还会创建 kmem cache、workqueue 和 kthread（例如 rpciod），占用 slab 和内核栈，也都是 lowmem。只测“常驻段 + MemAvailable”会漏掉这一块，并且掩盖 lowmem 的收益。
- 修改方案：
  - 原文：“测量常驻段、启动日志的 Memory 行和启动后的 MemAvailable，”
  - 新文字：“测量常驻段、启动日志的 Memory 行、启动后的 MemAvailable 和非 CMA 的 LowFree，并对比 /proc/slabinfo 中各 cache 的大小和内核线程数，”

**R3.2-3【一般】IRQSOFF_TRACER 的开销不能用采样测，需要说明**

- 位置：§3.2 表格 IRQSOFF_TRACER 一行，“需要实测这部分开销”。
- 问题：`trace_hardirqs_on/off` 都在关中断状态下执行。而本板的 PMU 溢出中断是普通 GIC-400 SPI，不能以 NMI 方式送达，所以这段代码在采样里看不到（见 R3.4-1）。只能用 A/B 构建，配合 PMU 计数来测。
- 修改方案：把“需要实测这部分开销”改为“需要实测这部分开销：用关闭 IRQSOFF_TRACER 和 TRACE_IRQFLAGS 的 A/B 构建，比较标准场景的内核态 instructions 和 cycles（采样看不到关中断区，不能用热点占比来估）”。

### §3.3.1 zram 压缩算法

**R3.3.1-1【重要】打开 ZSTD 后端会让 resourced 的现有配置自动生效，基线会悄悄改变**

- 位置：§3.3.1“对比方案”，以及“前提”。
- 问题：
  - `optimizer.conf` 里写的是 `CompAlgorithm=zstd`。一旦内核编入 ZSTD 后端，resourced 就会实际使用 zstd，这个变化是**静默**的，所有后续变体都会被它影响。每个变体都必须显式固定算法，并在实验后读回 `comp_algorithm` 确认。
  - 修改 /etc/resourced 属于写根文件系统，现行板上规则禁止。这件事需要 PM 授权，或者使用专门的测试镜像，应写进 §6。
  - 补充一个事实：最终配置已经有 `LZ4_COMPRESS`、`ZSTD_COMPRESS`、`CRYPTO_LZ4`、`CRYPTO_ZSTD=y`（lib/zstd 已经链接，06 中约 0.54 MB）。所以增加后端只多出 `backend_lz4.c`、`backend_zstd.c` 的胶合代码，体积代价很小。
- 修改方案：
  - 原文：“**前提**：Jaehoon 的 lz4 三个补丁已确认能干净合入；需要编入 LZ4、ZSTD 后端和 ZRAM_MULTI_COMP。”
  - 新文字：“**前提**：Jaehoon 的 lz4 三个补丁已确认能以文本方式干净合入（未编译、未测试）；需要编入 LZ4、ZSTD 后端和 ZRAM_MULTI_COMP（相应的压缩库已经内建，增量只有后端胶合代码）。**注意**：编入 ZSTD 后，resourced 现有的 `CompAlgorithm=zstd` 会自动生效，所以每个变体都必须显式固定算法，并读回 `/sys/block/zram0/comp_algorithm` 记录在案；修改 resourced 配置需要 PM 授权或测试镜像。”

```diff
--- a/arch/arm/configs/tizen_bcm2711_defconfig
+++ b/arch/arm/configs/tizen_bcm2711_defconfig
+CONFIG_ZRAM_BACKEND_LZ4=y
+CONFIG_ZRAM_BACKEND_ZSTD=y
+CONFIG_ZRAM_MULTI_COMP=y
```

（ZRAM_BACKEND_FORCE_LZO 是“没有选任何后端”时自动选上的，加了以上选项后会自动消失；LZO 后端保留，用于对照。）

**R3.3.1-2【重要】对比矩阵和通过条件不完整**

- 位置：§3.3.1 表格、“指标”“通过条件”。
- 问题：
  1. 缺 **lzo-rle 主压缩 + zstd 重压缩**一组。有了这一组，才能把“重压缩的收益”和“lz4 补丁的收益与风险”分开。
  2. 缺 **单一 zstd 的低压缩级别**（`algorithm_params level=1`，以及不带字典的情况）。
  3. “额外元数据”一列只算了 ACTIME 带来的槽位增量，漏掉了每个 CPU、每个优先级的压缩流工作区（zstd 的 cctx 和 dctx，估算总计在 1 MiB 量级，用 vmalloc 分配，可以落在 highmem），以及字典本身。
  4. 被 zstd 重压缩过的页，正好是“后台很久的应用切回前台”时要读回的页。指标中缺少这个场景的换入延迟。
  5. 6.12 在内存紧张时会走“压缩两次”的回退路径（`zram_drv.c:1547-1592`，计数器是 debug_stat 中的 writestall，见 `:1584`），主压缩用 zstd 时这条路径的代价会翻倍，但指标里没有。
- 修改方案：
  - 在表格中增加两行：“| lzo-rle（现状） | 只对空闲页用 zstd 重压缩 | 0 |” 和 “| zstd level=1（无字典） | 无 | 0 |”。
  - 把列名“额外元数据”改为“额外常驻内存（ACTIME 槽位 + 压缩流 + 字典，后两项实测 vmallocinfo）”。
  - 在“指标”末尾追加：“`debug_stat` 中的 writestall 与 miss_free；后台超过 T 分钟（T 取 10、30、60）的应用切回前台的耗时和换入延迟。”
  - 通过条件原文：“在换入延迟最慢 1% 和应用切换耗时不变差（不超过 2%）的前提下，选同等负载下 zram 总占用最低的方案。”
  - 改为：“在换入延迟 P99、应用切换耗时（包括长时间后台后切回）、kswapd CPU 都不变差（各自不超过 2%），且 writestall 不增加的前提下，选同等负载下 zram 总占用（含压缩流和字典）最低的方案。”

**R3.3.1-3【重要】“全部标记为空闲”的扫描不可抢占，会造成延迟毛刺**

- 位置：§3.3.1“关于变体”。
- 问题：`mark_idle()`（`zram_drv.c:291-327`）逐槽位加锁和解锁，循环里**没有 `cond_resched()`**；而 recompress 的循环里有（`:1990` 附近）。当前内核是 PREEMPT_VOLUNTARY，disksize 1.517 GiB 对应 397,648 个槽位。resourced 写一次 `all`，就会在一个 CPU 上连续占用约 10–40 ms（估算：每个槽位 25–100 ns，表大小 4.6 MB，超过 L2），同一 CPU 上的 UI 线程会错过帧。上游后来是否已补 cond_resched 无法核实。
- 修改方案：在“关于变体”末尾追加：“`mark_idle()` 在 6.12 中没有 cond_resched，在 PREEMPT_VOLUNTARY 下整个扫描不可抢占（估算 10–40 ms），需要随该方案一起合入下面的补丁，并测量写 idle 时的调度延迟。”

```diff
--- a/drivers/block/zram/zram_drv.c
+++ b/drivers/block/zram/zram_drv.c
@@ static void mark_idle(struct zram *zram, ktime_t cutoff)
 	for (index = 0; index < nr_pages; index++) {
+		/* idle_store() runs from sysfs with only init_lock held for read */
+		if (!(index & 1023))
+			cond_resched();
 		/*
```

- 副作用：没有功能变化。调用方只持有 init_lock 的读锁（rwsem），可以睡眠。
- 需要增加的测试：
  - disksize 写满约 1.5 GiB 后执行 `echo all > idle`；
  - 用 `perf sched record` 和 `perf sched latency` 对比改前改后的最大调度延迟；
  - 改后执行 `recompress type=idle`，确认结果与改前一致（成功页数、mm_stat）。

### §3.3.2 MGLRU 参数

**R3.3.2-1【重要】min_ttl_ms 会直接触发内核 OOM，绕过 resourced 的查杀策略**

- 位置：§3.3.2。
- 问题：
  - min_ttl_ms 的语义是：在设定时间内的工作集无法保留在内存中时，**由 kswapd 调用 `out_of_memory()`**（`mm/vmscan.c:4045-4050`；`Documentation/admin-guide/mm/multigen_lru.rst:71-75`）。在 TV 上，这等于把查杀决策从 resourced（limiter.conf 的分级阈值，以及 MemoryLimitTrigger=oom）交给内核 OOM 的打分，可能杀掉前台或系统进程。
  - 另外，ARM32 没有硬件维护的 young 位（没有选 ARCH_HAS_HW_PTE_YOUNG，LRU_GEN_WALKS_MMU 也关闭，见 05 §1）。老化时每清一次 young 位，下次访问就要多一次访问标志缺页，所以老化越激进，缺页越多。
- 修改方案：
  - 原文：“可以评估设置一个非零值（例如 1000 ms）对前台卡顿和 OOM/后台查杀的影响。”
  - 新文字：“可以评估设置一个非零值（例如 1000 ms）的影响。注意 min_ttl_ms 在保不住工作集时会由 kswapd 直接调用内核 OOM，绕过 resourced 的查杀策略，所以必须同时记录 vmstat 的 oom_kill、被杀进程及其类别（前台、后台、系统）、resourced 的查杀次数，以及 minor fault 次数（ARM32 没有硬件 young 位，老化会带来额外的访问标志缺页）。如果出现内核 OOM 杀掉前台或系统进程，就判定该值不可用。”

### §3.3.3 MGLRU-FG

**R3.3.3-1【建议】上游状态无法核实**

- 问题：RFC（2026-05）和 v4（2026-10）的时间、补丁数，以及 LevelDB、MongoDB 的数据，本次评审都无法核实。结论“只调研，不实现”是合理的。
- 修改方案：保持原文，在上游现状一句后加“（以 lore 原帖为准）”。

### §3.3.4 不做的项

**R3.3.4-1【一般】可抢占 zram 系列：理由不完整**

- 问题：6.12 的问题不只是优先级反转。压缩在 `local_lock`（非 RT 下即关抢占）内进行（`zcomp.c:110-119`）；如果 zsmalloc 不带直接回收的分配失败，就会释放流、换成可睡眠的分配，然后**重新压缩**一次（`zram_drv.c:1547-1592`）。可抢占系列消除了这次重复压缩。是否回移植应该看 writestall 的实测值，而不是直接排除。
- 修改方案：
  - 原文：“只在 3.3.1 的实验中记录换入延迟长尾，留作内核升级时的对照。”
  - 新文字：“在 3.3.1 的实验中记录换入延迟长尾和 debug_stat 中的 writestall（6.12 分配失败时会重压缩一次，见 zram_drv.c:1547–1592）。如果 zstd 主压缩下 writestall 明显，就重新评估是否回移植其中的“单次压缩”部分。”

**R3.3.4-2【一般】CMA 不应只记录**

- 问题：CMA 的 320 MiB 占 lowmem 的 46%（见 R2-2）。CMA 只能承接可迁移分配，所以 lowmem 越紧，CMA 越“贵”。即使大小属于产品配置，也应该在标准场景（包括视频播放）中测出 CmaFree 的最小值，为产品板的 CMA 取值提供数据。
- 修改方案：
  - 原文：“属于产品配置，本文只记录。”
  - 新文字：“属于产品配置，本文不修改；但在标准场景中记录 CmaFree 的最小值和 CMA 分配失败次数，为产品板评估 CMA 大小提供数据（CMA 位于 lowmem，占 lowmem 的 46%）。”

### §3.4 采样优化（AutoFDO/BOLT），按补充事实 3 重新评估

**R3.4-1【重要】收益预期和实施路径都需要重写**

新的事实链：

1. PMU 计数和 cycles 采样可用，事件类型为 PERF_TYPE_HARDWARE；分支栈不可用；没有 ETM（补充事实 3）。
2. **工具链不直接支持只有指令地址的采样**：llvm-profgen 22.1.8 读 perf script 时，只接受 LBR 或“LBR + 调用栈”两种内容（`PerfReader.cpp:366-375`、`1190-1217`）；只有指令地址的输入会报“Invalid perf script input”。可行的转换路径有三条：
   - (a) 把每个 IP 样本写成长度为零的区间，构造 `--unsymbolized-profile` 输入，让 llvm-profgen 只生成函数体计数。这条路需要实测验证。
   - (b) create_llvm_prof 的不使用 LBR 模式。平台没有提供该工具，相应选项也无法核实。
   - (c) 自己写转换器：用 llvm-symbolizer 把每个 IP 映射到（函数、行偏移、内联栈），直接输出文本格式的 sample profile。
3. **样本有系统性盲区**：BCM2711 是 GIC-400。arm_pmu 只有在中断控制器支持 NMI 时才会用 NMI（`drivers/perf/arm_pmu.c:639-660`），而 ARM32 的 GICv2 不支持，启动日志里也没有“using NMIs”。所以 PMU 溢出中断在关中断区间内无法送达，样本会堆积到 `local_irq_restore`、`spin_unlock_irqrestore` 等开中断点上。硬中断处理、持 rq 锁的调度代码、带 irqsave 的自旋锁临界区，在 profile 中都会表现为偏冷。再加上 A72 采样有 skid，基本块级别的计数并不可靠。
4. **能得到和得不到的**：
   - 得不到：间接调用目标（ICP 不可用），以及真实的边权重；基本块布局只能依靠 profi 从块计数推断，而块计数又受第 3 条影响。
   - 可靠的：**函数级冷热**，以及内联实例的粗略热度。
5. **收益重估（估算）**：
   - 在 x86 上，有 LBR 的内核 AutoFDO 公开收益多为个位数百分比（主线 v6.13 的 AUTOFDO_CLANG 提交说明，具体数值以原文为准）。
   - 本平台缺少边信息，加上关中断盲区，性能收益预计只有其中的一部分；再乘上 TV 场景中内核态 CPU 占比，**系统级性能收益很可能落在 2% 的噪声门槛内**。
   - 相比之下，函数级冷热足以支撑**冷代码按体积优化**和**冷热分区**，收益落在内存一侧，可以测量（见 C1）。
6. **更好的替代**：如果确实需要精确的边信息，用插桩 PGO：
   - GCC 路线：`CONFIG_GCOV_KERNEL`（ARM32 支持 ARCH_HAS_GCOV_PROFILE_ALL）配合 `-fprofile-use`，内部已有先例 `sandbox/sebuns2/pgo_applied_kernel`（8423391f，arm64）；
   - Clang 路线：需要移植 2021 年 LKML 上的 PGO_CLANG 系列（未进入主线），工作量较大。

- 修改方案：用下面的文字替换 3.4 第一条。
  - 原文：“**armv7l 内核 AutoFDO**：本树没有 AUTOFDO_CLANG 接入；Cortex-A72 在 32 位下没有可用的分支记录，RPi4 也没有暴露 ETM。只能用不带分支信息的周期采样，精度有限。等板上 perf 可用后，先做一次可行性评估，并与 AutoFDO/BOLT Agent 那条线的结果对照。”
  - 新文字：“**armv7l 内核采样引导优化**：板上已实测，只能做指令地址采样（不支持 -b，没有 ETM），PMU 中断也不是 NMI，关中断区在采样中不可见。llvm-profgen 22.1.8 的 perf script 路径只接受 LBR 输入，需要自建转换（零长度区间形式的 unsymbolized profile，或直接输出文本 profile）。因此不以性能为主要目标，而是：① 先用现有 perf 做标准场景的函数热度集中度分析（成本低）；② 如果热度高度集中，用 `-fprofile-sample-use -fprofile-sample-accurate` 让冷函数按体积优化，并把冷热代码分区（.text.hot 和 .text.unlikely 已经由链接脚本归组）；关中断路径（入口代码、中断、调度核心、锁）列入强制热名单；③ 只有在需要精确边信息时，才评估插桩 PGO（参考内部 GCC gcov 先例）。与 AutoFDO/BOLT Agent 那条线的结果对照。”
  - 第二条“内核 BOLT”保持不变。

---

## 二、第 4 节（测量方法）

**R4-1【重要】缺少 lowmem 和逐 zone 指标**

- 修改方案：在 4.2 表格“内存”一行的“指标”中追加：“LowFree、HighFree、/proc/zoneinfo 中 DMA 区的 nr_free_pages 与 nr_free_cma、protection、各 cache 的 slab 大小（/proc/slabinfo）、VmallocUsed 与 vmallocinfo、CmaFree 的最小值”。

**R4-2【重要】换入延迟测量方法（对应第 7 节问题 6）**

用以下四个方法分层替换“测量方法在第一阶段由 Codex 设计”：

1. **合成微基准**（主要方法，确定性好）：
   - 在一个 memcg v1 中分配 N MB 匿名内存，填入真实应用的页面内容；内容来自后台应用的匿名页离线转储，保证压缩率具有代表性；
   - 用 `memory.force_reclaim`（板上 67 个 memcg 都有这个接口，f240c280 修复的就是它）把这些页压进 zram；
   - 然后逐页访问，用 `clock_gettime` 记录每页的缺页耗时，直接得到 P50、P99、最大值的分布。
2. **任务级延迟统计**：CONFIG_TASK_DELAY_ACCT=y，换入路径在 `mm/page_io.c:629-655` 记录 swapin 延迟。运行时用 sysctl `kernel.task_delayacct=1` 打开，通过 taskstats（getdelays）读取每个任务的总换入延迟和次数，用来看真实应用。这种方法给出的是均值，不是分布。
3. **kprobe 事件**（KPROBE_EVENTS=y）：只用于抽查。HIST_TRIGGERS 和 SYNTH_EVENTS 都未启用，不能在内核内做直方图；开销需要先单独测量。
4. **测量专用内核**（可选）：在 `swap_read_folio` 中加一个 log2 直方图（两次 `sched_clock` 读取），通过 debugfs 导出。只用于测量变体，不进入产品。

- 修改方案：
  - 原文：“测量方法在第一阶段由 Codex 设计、经评审后使用”
  - 新文字：“换入延迟：合成微基准（memcg v1 force_reclaim 加真实页面内容，逐页计时，得到分布）为主，taskstats 的 swapin 延迟（task_delayacct）用于真实应用；kprobe 只做抽查；必要时使用带直方图的测量专用内核。应用启动和切换耗时的方法在第一阶段设计、经评审后使用”

**R4-3【重要】统计方法与低噪声代理指标**

- 问题：
  - 每个变体只跑 5 次，不足以判定 2% 量级的差异，尤其是长尾指标。
  - “大于噪声范围的两倍”这个判据没有统计含义。
  - 没有使用 PMU：本板已经能计数，每个场景的内核态 instructions（`instructions:k`）比墙钟时间稳定得多，适合作为体积和代码生成类变体的低噪声代理指标。
- 修改方案：
  - 原文：“收益必须大于噪声范围的两倍，否则判为“无显著差异””
  - 新文字：“用 A/A 数据估计方差，据此确定每个指标所需的运行次数（目标是能检出 1% 的差异），并且不少于 10 次。用 bootstrap 求中位数差的 95% 置信区间：区间不含 0 且下界超过容差，才判为有收益；区间上界超过容差，判为回退。对代码生成类变体，同时报告标准场景的 `instructions:k` 和 `cycles:k`（perf stat -a），作为低噪声佐证。”

**R4-4【一般】板上测试需要写根文件系统，与现行规则冲突**

- 问题：标准场景需要安装应用、修改 resourced 配置、反复重启，都与 RULES 中“只在 /tmp 下写临时文件、不改根文件系统、重启由用户执行”的规则冲突。
- 修改方案：在 §6 增加一行：“| 板上规则与实验需要冲突 | 标准场景、zram 配置、反复重启无法在只读规则下进行 | 由 PM 授权专用测试镜像或可写分区，并写入 RULES |”

---

## 三、第 5 节（实验计划）

**R5-1【重要】排序调整**

- 问题：
  - 阶段 0 的前提已过期（perf 已经可用）。
  - 配置裁剪中的 BTF 和 LD_DCE 是收益确定性最高的 lowmem 项，性能风险最低，不需要等阶段 0 的全部设施，就可以先测静态部分。
  - 3.4 需要按 R3.4-1 拆分，其中热度分析很便宜，可以提前。
  - 帧指针的快速实验（-Xclang）不改编译器，可以提前，用来决定是否值得修改 Clang。
- 修改方案：用下表替换 §5 的表格。

| 阶段 | 内容 | 前提 | 产出 |
| --- | --- | --- | --- |
| 0 | 标准场景脚本；换入微基准；lowmem 和逐 zone 采集；A/A 噪声测量（含 instructions:k）；用现有 perf 做函数热度集中度分析 | 测试镜像或可写分区的授权 | 测量设施报告、噪声基线、热度分布 |
| 1 | zram 算法矩阵（3.3.1，含 lzo-rle + zstd 重压缩、mark_idle 补丁）；MGLRU 参数（3.3.2，含 OOM 记录）；lowmem_reserve_ratio（C2）；page-cluster（B4） | 阶段 0 | zram 与回收参数结论 |
| 2 | 配置裁剪变体（3.2，BTF 按 R3.2-1 处理，插件改造并行）；LD_DCE（B2）。静态测量可以在阶段 0 完成前开始 | 插件改造方案（用户态） | 每项的实际节省（含 lowmem 和 slab）和产品取舍表 |
| 3 | -pg 帧指针：先用 -Xclang 快速测量，再决定是否修改 Clang 并加 Kconfig 探测（3.1.1）；栈保护探测修复（3.1.2）；GCC 与 Clang 内核运行时对比 | 阶段 0 | 补丁和对比报告 |
| 4 | 冷代码体积优化（C1，替代原 AutoFDO 可行性）；内联膨胀（3.1.3） | 阶段 0 的热度分布、阶段 2、阶段 3 | 评估报告 |
| 5（PoC） | MGLRU-FG 回移植评估；ARM32 LTO（以 sebuns2/use_lto 为起点）；VMSPLIT_2G（B3）；换入预取（C3） | 阶段 1 | 可行性报告 |

---

## 四、第 6 节（风险）

**R6-1【一般】补充以下风险**

| 事项 | 影响 | 处理 |
| --- | --- | --- |
| lowmem 是瓶颈（非 CMA 约 375 MiB） | 只看 MemAvailable 会掩盖 lowmem 回退 | 每个实验都报告非 CMA 的 LowFree，设独立门槛 |
| 编入 ZSTD 后 resourced 静默切换到 zstd | 基线漂移，A/B 失效 | 每个变体显式固定算法，并读回确认 |
| min_ttl_ms 触发内核 OOM | 前台或系统进程被杀 | 记录 oom_kill 和被杀进程类别，出现即判不可用 |
| mark_idle 扫描不可抢占 | UI 掉帧 | 随方案合入 cond_resched 补丁并测量 |
| 采样有盲区（PMU 中断不是 NMI） | 热点分析低估关中断路径 | 关中断相关的项只用 A/B 构建加 PMU 计数评估 |
| 板子与其他工作线共用 | 噪声，以及测试相互干扰 | 实验时独占板子，记录其他进程（已有 PID 3708 这类串口 shell） |

---

## 五、第 8 节（来源）

**R8-1【建议】**

- 已复核：`CommonArgs.cpp` 第 73 行、`Clang.cpp` 第 8069–8072 行与 llvmorg-22.1.8 一致。
- MGLRU-FG、ZRAM 重构、swap table、CRAM 的外部链接本次都无法核实，建议标注访问日期。

---

## 六、对第 7 节问题的逐条答复

**问题 1：第 2 节的基线事实是否有误读，证据是否足以支撑结论？**

数值本身与证据一致，包括 MemTotal、启动日志 Memory 行、CMA 320 MiB、zram 参数、HZ 约 100、各项 BTF 和段大小。问题有三类：

- 有两行已经过期（R2-1）；
- 有两处表述超出了证据（R2-3 的 cpuidle、R2-4 的 BPF）；
- **漏掉了最关键的 lowmem 结构**（R2-2）：lowmem 全部在 ZONE_DMA，CMA 整体位于 lowmem，非 CMA 的 lowmem 约 375 MiB，lowmem_reserve 实际约 12.5 MiB。这一点会改变 §3 的收益排序和 §4 的口径。

**问题 2：ARM 内核在 -pg 下不保留帧指针是否安全？编译器侧和内核侧哪种改法更合适？**

**安全，前提是继续使用 UNWINDER_ARM（EHABI），而当前配置正是如此。** 逐项依据如下：

- ftrace：`__gnu_mcount_nc` 从栈上取得调用者压入的 lr（`entry-ftrace.S` 中 mcount_enter 和 mcount_get_lr）。
- function_graph：在 UNWINDER_ARM 下，用 `unwind_frame()` 定位返回地址所在的栈位置（`ftrace.c:238-265`），FP_TEST 比较的是 SP（提交 953f534a7ed6，`fgraph.c:714`）。
- oops 回溯和 perf 内核调用栈：都走 EHABI（`perf_callchain.c:96-97`）。
- 只有切换到 UNWINDER_FRAME_POINTER 才会依赖 fp（`entry-ftrace.S:117,167`），而该选项会自动 select FRAME_POINTER，不会与本方案冲突。

改法上，推荐 R3.1.1-2 的组合：Clang 只放开 ARM GNU EABI 下“显式 `-fomit-frame-pointer` 加 `-pg`”的报错，默认行为不变；内核用 Kconfig 探测后，只对 Clang 加 `-fomit-frame-pointer`。这比改 Clang 默认值的影响面小，也比新增选项少一个公共接口。LLVM main 至今仍然强制帧指针，这个补丁可以提交上游。实施前先用 `-Xclang -mframe-pointer=none` 的实验构建测出真实收益。注意收益中 unwind 部分应按约 0.5 MB 计，而不是 0.63 MB（R3.1.1-1）。

**问题 3：3.1.2 的修复方向是否正确，上游是否已经修复？**

方向正确，应该修内核的探测，而不是改编译器。主线 master 的 `arch/arm/Kconfig:1371-1372` 仍然没有带 `-march`，**没有修复**。是否有相关的 LKML 讨论无法核实。diff 见 R3.1.2-2，按 arch/arm/Makefile 的 `-march` 分 v7 和 v6K 两种情况探测。另外，文中行号应为 1376–1377。

**问题 4：BTF 的判断是否成立？还有没有漏掉的依赖内核 BTF 的场景？**

判断成立：ARM32 没有 trampoline，第一处失败在 size 弱实现，返回 -ENOTSUPP（524）。但这是源码结论，板上没有加载失败的日志。漏掉的场景有：

- ARM32 上**仍然可用**、依赖内核 BTF 的：tp_btf、bpf_iter、bpftool 的类型化输出；
- 用户态 CO-RE 需要一份 vmlinux BTF，但可以来自文件；
- spec 中的 vmlinux.h 导出；
- DEBUG_INFO_BTF_MODULES；
- ARM32 上**本来就不可用**的：kfunc（ARM32 JIT 没有 `bpf_jit_supports_kfunc_call`）、struct_ops、fentry、fexit、LSM。

建议的路径见 R3.2-1：插件改成 kprobe，配合 BTFGen 或 detached BTF；内核关闭 BTF；spec 改用 pahole 生成 detached BTF。

**问题 5：3.3.1 的 zram 方案对比是否完整？“全部标记空闲、再重压缩仍然空闲的页”是否可行，有没有遗漏的副作用？**

对比不完整，缺两组：lzo-rle 加 zstd 重压缩，以及 zstd 低压缩级别；“额外元数据”的口径也偏窄（R3.3.1-2）。

“全部标记空闲”的做法**可行**，依据如下：

- `idle_store` 中 `all` 不需要 ACTIME（`zram_drv.c:336`），`mark_idle` 在 `cutoff=0` 时直接置位（`:317-322`）；
- 读和写都会调用 `zram_accessed()` 清除 IDLE 标志（`:178-184`，调用点在 `:2059`、`:2089`）；
- 标记之后新写入的页本身就不带 IDLE；
- `recompress type=idle` 只处理仍然带 IDLE 的页。

遗漏的副作用：

1. `mark_idle` 没有 cond_resched，扫描一次估算 10–40 ms 不可抢占（R3.3.1-3，附补丁）。
2. 对共享换出项（count 大于 1，例如 launchpad 派生进程共享的匿名页），换入会经过 swap cache 预读（page-cluster=3），预读读到的页也会被清除 IDLE。冷页因此被误判为热页，结果是少重压缩一些，属于保守方向，没有害处，但收益会偏低。对 count 等于 1 的页，同步 IO 会绕过 swap cache，不受影响（`mm/memory.c:4279`）。
3. 只能有一种“年龄”。没有 ACTIME，就无法在重压缩时按不同年龄筛选；要做多级策略，只能缩短标记周期。
4. idle 是全局状态。resourced 之外的任何组件写 idle，都会干扰判断，所以必须只由一个组件负责。
5. 被重压缩的页解压更慢，而它们正是长时间后台的应用切回前台时要读的页，必须单独测这个场景。
6. 重压缩在每个槽位的锁内完成解压和压缩，期间对同一槽位的换入会自旋等待；锁在每页之间释放，影响有限，但应分批执行（设置 max_pages）。

**问题 6：第 4 节的测量方法和通过门槛是否足以支持结论？有没有更合适的换入延迟测量方法？**

不够。门槛口径没有定义（R1-1，阻断）；缺少 lowmem 指标（R4-1）；运行次数和统计方法不足（R4-3）。换入延迟建议以合成微基准为主（memcg v1 force_reclaim 加真实页面内容，逐页计时），真实应用用 taskstats 的 swapin 延迟，kprobe 只做抽查（R4-2）。

**问题 7：第 5 节的优先级排序是否合理？有没有遗漏的高收益方案？**

大体合理，调整见 R5-1：静态配置裁剪（BTF、LD_DCE）和帧指针快速实验应该提前；3.4 要重新定位。遗漏的高收益方案见下一部分：

- B2：LD_DCE；
- B1：BTF 改用 BTFGen；
- B3：VMSPLIT_2G；
- C2：lowmem_reserve_ratio；
- C1：冷代码体积优化。

---

## 七、更好的方案

### A. 对已有方案的改进

| 编号 | 对应章节 | 替代做法 | 为什么更好 |
| --- | --- | --- | --- |
| A1 | 3.1.1 | 只放开 ARM GNU EABI 下 `-pg` 与显式 `-fomit-frame-pointer` 共存，内核用 Kconfig 探测后再加该选项；先用 `-Xclang -mframe-pointer=none` 量化收益 | 不改变任何现有构建的行为，也不新增公共选项；可以提交上游；在修改编译器之前就能拿到实测收益 |
| A2 | 3.1.2 | Kconfig 探测时带上与 arch/arm/Makefile 一致的 `-march` | 修复根因，GCC 不受影响，同一份 diff 可以提交上游 |
| A3 | 3.3.1 | 先在板上用用户态的 lz4、zstd、lzo 工具，对后台应用的匿名页离线转储做压缩率和速度的预筛，再选 2–3 个变体编内核；矩阵中加入 lzo-rle + zstd 重压缩 | 预筛不需要编内核，一天之内就能排除明显较差的组合；把 lz4 补丁的风险与重压缩的收益分开 |
| A4 | 3.3.1 变体 | 由 resourced 按应用生命周期驱动“标记加重压缩”：应用进入后台 T 分钟后执行一次 `idle all`，再过 T 分钟执行 `recompress type=idle max_pages=…`，加上 cond_resched 补丁 | 与 TV 固定的前后台流程对齐，CPU 开销可控，不需要 ACTIME |
| A5 | 3.4 | 从“AutoFDO 提升性能”改为“函数级热度驱动冷代码体积优化和冷热分区”；需要边信息时用插桩 PGO（参考内部 GCC gcov 先例） | 只依赖指令地址采样中可靠的部分（函数级冷热），避开分支信息缺失和关中断盲区；收益落在内存一侧，可以测量 |
| A6 | §4 | 合成换入微基准；taskstats 的 swapin 延迟；以 instructions:k 作为低噪声指标；用 bootstrap 求置信区间 | 能给出换入延迟分布；在相同的板子时间内能检出更小的差异 |
| A7 | 3.2 BTF | 插件改用 kprobe，配合 BTFGen 或 detached BTF，内核关闭 BTF | 拿到 BTF 的全部 6.48 MB lowmem，同时保住插件功能，比“等日志证明插件不工作”更确定 |

### B. 有依据的新方案

**B1. 关闭内核 BTF，用户态改用 BTFGen 或 detached BTF**（详见 R3.2-1 和 A7）

- 做什么：armv7l 关闭 DEBUG_INFO_BTF；插件把 fentry 改为 kprobe，用 `bpftool gen min_core_btf` 为插件生成最小 BTF，通过 `btf_custom_path` 传入。
- 依据：bpftool 上游的 `gen min_core_btf`（BTFGen）；libbpf 的 `bpf_object_open_opts.btf_custom_path`；本树 `trampoline.c:1079-1085,1115-1118`。
- 预期收益：lowmem 减少约 6.48 MB（.BTF 段），模块也不再带 .BTF。适用前提是插件需求得到 PM 确认。
- 风险：插件改造工作量；依赖 /sys/kernel/btf 的调试工具会失效。
- 验证：插件在板上能加载和挂载，数据与预期一致；非 CMA 的 LowFree 增量。
- 阶段：2。

**B2. 启用 LD_DEAD_CODE_DATA_ELIMINATION**

- 做什么：打开 `CONFIG_LD_DEAD_CODE_DATA_ELIMINATION`（会加上 `-ffunction-sections -fdata-sections` 和 `--gc-sections`）。
- 依据：上游 ed0f94102251（“ARM: 9404/1: arm32: enable HAVE_LD_DEAD_CODE_DATA_ELIMINATION”，v6.11）的提交说明给出 zImage 缩小 2.0%（defconfig）、2.7%（vexpress）、3.2%（一款商用 A15 单板）；本树已带后续修复 0d437918fb64（9414/1）、9f7ae45f0c61（9444/1，向量表 KEEP）、6ed79cf1183a（9450/1）；本树和配置都满足 LD_IS_LLD 条件（`arch/arm/Kconfig:122`）。
- 预期收益（估算）：常驻 text、rodata、data 减少 1.5–3%，约 0.5–0.9 MB lowmem。这一步还会给每个函数单独成段，C1 的冷热分区和函数排序需要这一点。
- 风险：RPi 下游驱动或 vendor 代码自定义的链接段如果缺少 KEEP，会被误删，后果可能是启动挂起（参考 9444/1）；构建时间增加。
- 验证：对比前后 `nm` 的差集，确认被删的都是未引用符号，并逐类检查 initcall、`__setup`、`of_device_id` 和 ftrace 表；启动加功能冒烟测试；`available_filter_functions` 计数对比；常驻段和 LowFree。
- 阶段：2。

**B3. 评估 VMSPLIT_2G，扩大 lowmem**

- 做什么：把 3G/1G 改为 2G/2G 划分。
- 依据：`arch/arm/Kconfig:1029-1052`（VMSPLIT 选项）；LWN“An end to high memory?”（2020）讨论了 highmem 的成本和弃用方向（链接请检索确认）；本板非 CMA 的 lowmem 只有约 375 MiB（R2-2）。
- 预期收益（估算）：lowmem 从约 695 MiB 增加到约 1.7 GiB（扣除 vmalloc 区），非 CMA 的 lowmem 增加约 1 GiB。slab、页缓存、zsmalloc 对 highmem 的 kmap 次数会下降，带来性能收益，大小需要实测。
- 适用前提：所有进程的虚拟地址峰值（VmPeak）都低于约 1.8 GiB。Web 引擎和 .NET 运行时（runner、SystemUI.dll）的地址空间是主要风险。
- 风险：应用 mmap 失败；ASLR 熵下降；产品 SoC 的 DMA 区限制不同。
- 验证：先只读采集标准场景中所有进程的 VmPeak，这一步不需要改内核；全部满足前提后，再构建 VMSPLIT_2G 变体，跑全部场景。
- 阶段：5（PoC），其中 VmPeak 采集可以并入阶段 0。

**B4. 把 vm.page-cluster 设为 0**

- 做什么：关闭 zram 的换入预读。
- 依据：Android 的 init.rc 把 page-cluster 设为 0（公开实践）；本板当前为 3。对 count 等于 1 的换出项，同步 IO 本来就不预读（`mm/memory.c:4279`），所以影响只限于共享换出项（launchpad 派生进程）和 shmem。
- 预期收益：小，包括减少无用解压和 IDLE 误清（与 R3.3.1 问题 5 的第 2 点有关），但成本几乎为零，修改可回滚。
- 风险：如果顺序访问共享页多，延迟可能上升。
- 验证：与 3.3.1 共用负载，对比 pswpin、换入延迟和 zram 读取次数。
- 阶段：1。

**B5. 内核映像改用 LZ4 压缩（开机时间）**

- 做什么：把 KERNEL_GZIP 改为 KERNEL_LZ4。
- 依据：上游 Kconfig 的 KERNEL_LZ4 说明（解压更快，映像更大）；内部分支 `sandbox/sebuns2/kernel_compression`（624d6479，arm64）。
- 预期收益（估算）：开机时间减少几十到一两百毫秒，对运行时内存没有影响。
- 风险：映像变大约 10–20%，需要确认 boot 分区（64 MiB）的余量。
- 验证：记录开机到桌面时间、引导加载器读取时间和解压时间。
- 阶段：2。优先级低。

### C. 探索性方案

**C1. 用指令地址采样驱动冷代码体积优化，并修正关中断盲区**

- 要解决的问题：Clang 内核的 .text 比 GCC 多 2.05 MB（+11.5%），其中约 70% 无法归因到具体对象（07 §3），逐个对象调整做不完；而全局 `-Os` 会拖慢热路径。指令地址采样给不出分支信息，传统 AutoFDO 无法发挥。
- 设计思路：
  1. 在标准场景中运行 `perf record -a -c <period>`（内核态加用户态），用 vmlinux 和 llvm-symbolizer 把每个 IP 映射到函数，得到函数级热度。
  2. **关中断修正**：PMU 中断不是 NMI，所以样本会落在开中断点上。对“样本落在 irq_restore 或 unlock_irqrestore 附近”的函数，把它在关中断区间内直接调用的被调函数（从静态调用图沿一层展开）一并标记为热；再把入口代码、中断、调度核心、锁、hrtimer 列入强制热名单。
  3. 生成只有函数体计数的 sample profile（零长度区间的 unsymbolized profile，或文本格式），编译时加 `-fprofile-sample-use -fprofile-sample-accurate`。LLVM 会把 profile 中没有出现的函数视为冷函数，按体积优化（PGSO），并放入 .text.unlikely；`vmlinux.lds.h` 的 TEXT_TEXT 已经把 .text.hot 和 .text.unlikely 分别归组。
  4. 配合 B2 的 `-ffunction-sections`，用 LLD 的 `--symbol-ordering-file` 把热函数集中排列，改善 L1I（48 KB）和 iTLB 的局部性。
- 预期收益（估算）：
  - 推理：内核代码绝大部分在 TV 场景中是冷的。假设样本覆盖的函数只占 .text 的 10–20%，其余 80–90% 按体积优化后缩小 8–15%（Clang `-Os` 相对 `-O2` 的典型幅度，需用全内核 `-Os` 构建标定），预计 .text 减少 **1.3–2.7 MB lowmem**。
  - 性能：热路径保持 -O2，热函数集中排列后预期持平或略有提升。
- 主要风险和难点：
  - 场景覆盖不全时，冷函数被错误地按体积优化，会造成长尾回退；对策是用多个场景取并集，加上强制热名单；
  - profile 与源码版本漂移；
  - 关中断修正依赖静态调用图，对间接调用无能为力。
- 最小验证实验：
  1. 用已有的 perf，在一个 2–3 分钟的标准场景上采样，统计前 N% 函数所占的样本比例，以及被采到的函数的 .text 占比（一天）；
  2. 构建一次 `CONFIG_CC_OPTIMIZE_FOR_SIZE=y` 的全内核，得到体积节省的上限和性能损失的上限（一次构建加一次 A/B）。
  - 如果第 1 步显示热度高度集中，且第 2 步体积节省大于 1.5 MB，再进入 profile 构建。

**C2. 修正“lowmem 全在 ZONE_DMA”导致的 lowmem 保护不足**

- 要解决的问题：内核为 highmem 系统设计的 lowmem 保护，是 Normal 那一档的 `lowmem_reserve_ratio=32`。但本板 lowmem 全部在 ZONE_DMA，实际生效的是 DMA 档的 256（这一档原本是为很小的 ISA DMA 区设计的），lowmem 对 highmem 可满足的分配只保留约 12.5 MiB，而不是约 100 MiB。用户页可以把非 CMA 的 lowmem 吃到只剩约 12.5 MiB 加水位线，此后 slab 或内核栈分配就要触发只针对 DMA 区的回收。MGLRU 不按 zone 维护链表，做这类定向回收时，会扫描并跳过大量 highmem 页，效率低。
- 设计思路：
  - 运行时把 `vm.lowmem_reserve_ratio` 设为 `32 32 0 0`，或者按实测选 64，即约 50 MiB；
  - 由 resourced 在开机时写入，修改可回滚；
  - 如果效果确认，再考虑在内核侧按“lowmem 实际所在 zone”选择 ratio，并作为 RPi 或 ARM32 平台补丁提交上游讨论。
- 预期收益（估算）：
  - 推理：场景负载下，非 CMA 的 lowmem 从约 300 MiB 空闲被用户页逐步占用后，内核分配会引发 DMA 区的直接回收或 kswapd 回收。保护提高到约 100 MiB 后，这部分会被 highmem 和 CMA 吸收。
  - 收益体现在：DMA 区相关的回收次数、kswapd CPU、分配延迟的长尾下降。
  - 代价：用户页可用的 lowmem 减少约 87 MiB，占总内存约 2.2%，但这些页都可以从 highmem 和 CMA 获得。
- 主要风险和难点：
  - 如果 highmem 本身也紧张，会更早开始换出；
  - 收益取决于场景中是否真的出现 lowmem 压力，必须先测。
- 最小验证实验：
  1. 只读：在标准场景中周期采集 `/proc/zoneinfo`（DMA 区的 free、nr_free_cma、protection）和 `/proc/vmstat` 中按 zone 区分的回收计数，确认是否存在 DMA 区压力；
  2. 如果存在，运行时修改 sysctl 做 A/B（可回滚，不需要重启）。

**C3. 按 TV 固定流程预取即将恢复的应用（规则驱动，不涉及机器学习）**

- 要解决的问题：后台应用切回前台时，它的匿名页工作集要从 zram 逐页缺页、解压，耗时在关键路径上；如果 3.3.1 采用 zstd 重压缩，冷页解压更慢。内核不知道“哪个应用即将恢复”，而 TV 的流程（主页、应用列表、返回最近应用）是固定的，resourced 和窗口管理器知道。
- 设计思路：
  - 在高置信度的过渡点（例如用户打开最近应用列表并停在某个应用上，或者按下返回最近应用键），由 resourced 对目标进程调用 `process_madvise(pidfd, MADV_WILLNEED)`，覆盖它的匿名 VMA，按热度优先（例如先处理栈、堆和最近被换出的区间）；
  - 6.12 的 process_madvise 支持 WILLNEED（`mm/madvise.c:1222-1233`），对匿名映射会走换入预读路径；
  - 只在 MemAvailable 充足时执行，并设置预取量上限。
  - 这是规则驱动的预取，不涉及页面置换策略本身。
- 预期收益（估算）：
  - 推理：每页缺页加解压估计 10–20 µs（lz4 或 lzo 在 A72 1.5 GHz 上约几微秒，加上缺页路径；zstd 更慢，需要用微基准实测）；
  - 恢复工作集按 20–80 MB 计，即 5,000–20,000 页，关键路径上约 **0.05–0.4 s**；
  - 用户从打开列表到确认通常有数百毫秒，足以把这部分时间隐藏掉。
- 主要风险和难点：
  - 预测错误时会浪费 CPU 和内存，可能把别的页挤出去；
  - WILLNEED 是异步的，不保证在恢复前完成；
  - 需要窗口管理器向 resourced 提供事件。
- 最小验证实验：
  - 写一个板上测试工具（pidfd_open 加 process_madvise，需要 root，属于测试操作，需要授权）；
  - 让某个应用在后台待 10 分钟，对比“直接恢复”与“恢复前 1 秒执行 WILLNEED”两种情况下的切换耗时和 taskstats 的 swapin 延迟，各跑 10 次。

**C4. 如果产品必须保留内核 BTF：压缩存储、按需解压**（只在 B1 被否决时考虑）

- 要解决的问题：BTF 段 6.48 MB 常驻 lowmem，但只有在加载 BPF 程序或读取 /sys/kernel/btf 时才用到。
- 设计思路：
  - 构建时用 zstd 压缩 .BTF 并替换原段；
  - 首次需要时（`btf_parse_vmlinux` 和 sysfs 读取）解压到 vmalloc 区，其页面可以来自 highmem；
  - 需要修改直接引用 `__start_BTF` 的代码（kernel/bpf/btf.c、sysfs_btf.c）；
  - 上游近期为 BTF 增加了 mmap 支持，这项改动要求段按页对齐，需要协调；具体状态无法核实。
- 预期收益（估算）：BTF 由类型记录和字符串表组成，压缩率估计 3–5 倍，在不使用 BPF 时可省下约 4.5–5 MB lowmem。使用 BPF 时，改为占用约 6.5 MB highmem。
- 主要风险：与上游 BTF 代码长期分叉；首次使用时的延迟。
- 最小验证实验：用 objcopy 从现有 vmlinux 中取出 .BTF，用 `zstd -19` 测压缩率；`grep -rn __start_BTF` 列出需要修改的位置。

---

## 八、总结

**最重要的 5 个问题**

1. **R1-1【阻断】** 容差没有定义分母和指标（3% 按 MemTotal 计约 116 MiB，会吸收所有回退），也没有 lowmem 门槛。
2. **R2-2 / R4-1【重要】** 漏掉了 lowmem 结构：全部在 ZONE_DMA，CMA 320 MiB 在 lowmem 内，非 CMA 的 lowmem 约 375 MiB，lowmem_reserve 实际约 12.5 MiB。这会改变收益排序和测量口径。
3. **R3.4-1【重要】** 3.4 需要按补充事实重写：只有指令地址采样，llvm-profgen 22.1.8 不接受这种输入，PMU 中断不是 NMI 导致关中断区不可见。预期性能收益很可能落在噪声内，应改为以函数级冷热驱动体积优化为主。
4. **R3.2-1【重要】** BTF 的判断成立，但需要补上仍然可用的 BTF 用途、插件的 kprobe 加 BTFGen 改造路径，以及 spec 中的 pahole detached 方案，否则无法做出“关闭 BTF”的决定。
5. **R3.3.1-1/2/3 与 R3.3.2-1【重要】** zram 和 MGLRU 有几处会使实验结论失真：编入 ZSTD 后 resourced 静默切换算法、mark_idle 不可抢占、缺少长时间后台后切回的场景和 writestall 指标、min_ttl_ms 会直接触发内核 OOM。

**B 类中最值得做的前 3 个**：B1（关闭内核 BTF，改用 BTFGen 或 detached BTF，约 6.48 MB lowmem）；B2（LD_DEAD_CODE_DATA_ELIMINATION，上游数据为 2–3.2%）；B3（VMSPLIT_2G 可行性，先只读采集 VmPeak）。

**C 类中最值得做的前 3 个**：C2（修正 lowmem_reserve_ratio，成本最低、可回滚）；C1（采样驱动冷代码体积优化，估算 1.3–2.7 MB）；C3（按 TV 流程预取即将恢复的应用，估算缩短切换关键路径 0.05–0.4 s）。

**总体结论：修改后冻结。** 方案的方向和证据链基本可靠，第 2 节的数值都能复核，3.1.1、3.1.2 和 BTF 的核心判断在源码上都成立。但 R1-1 必须先改，否则任何实验都无法判定；R2-2、R3.4-1、R3.2-1、R3.3.1 的系列问题需要在冻结前写进文档。这些都是补充和修正，不需要推倒重来。
