# 设计文档 v2 评审意见（10_design_v2.md）

评审日期：2026-10-30。评审对象：`docs/10_design_v2.md`（仓库 `9bc07f7`，同日修订版，75,639 B）。

**核对基准**：

- 内核源码：`linux-rpi@0fac5de6a630`；
- 平台配置：`evidence/task5b/qb_arm-rpi4.config`（下文简称“平台配置”）；
- LLVM：`llvmorg-22.1.8`；
- libbpf：`v1.6.2`；
- 内核主线：`torvalds/linux` master。

**约定**：行号未注明出处的，都指 `linux-rpi@0fac5de`。“估算”表示推理所得，尚未实测；“无法核实”表示本次评审拿不到证据，并不代表原文有错。

上一轮评审中已被 v2 采纳的意见不再重复。少数地方在 v2 的写法里出现了新问题，下文会单独指出。

**严重度定义**：

- 阻断：不改就无法据此判定实验结论；
- 重要：会导致结论偏差，或漏掉主要收益或风险；
- 一般：事实或表述需要修正；
- 建议：可以改进的地方。

---

## 一、逐节意见

### §1 目标与约束

**V1-1【阻断】低端内存这一行的三个判定指标都测不到想测的东西**

- 位置：1.2 表格“内存（低端）”一行；3.3.1 的“验证”。
- 问题：
  1. **“LowTotal − LowFree”看不到内核静态变化。** 内核映像属于 reserved，不在 LowTotal 里。映像缩小 6.5 MB 时，LowTotal 和 LowFree 同时增加 6.5 MB，两者之差不变；映像变大时也一样。这个指标还把 CMA 中被可移动页借用的部分、低端内存里可回收的页缓存和匿名页都算作“已用”，噪声大，而且这些并不是内核压力。
  2. **`allocstall_dma` 基本恒为 0。** 直接回收计数按请求的最高可用 zone 归类：`__count_zid_vm_events(ALLOCSTALL, sc->reclaim_idx, 1)`（`mm/vmscan.c:6282`），其中 `.reclaim_idx = gfp_zone(gfp_mask)`（`:6511`）。GFP_KERNEL 的 `gfp_zone` 是 ZONE_NORMAL。所以虽然本板 Normal 区为空，内核分配引起的直接回收仍记在 **`allocstall_normal`** 上；用户页（HIGHMEM 加 MOVABLE）记在 `allocstall_movable` 上；`allocstall_dma` 只统计显式带 GFP_DMA 的请求。另外，3.3.1 中写的 `allocstall_highmem` 这个名字不存在，HighMem 的后缀是 `_high`（`mm/vmstat.c:1177`）。
  3. **“低端内存分配失败次数”没有数据来源。** vmstat 没有这类计数；dmesg 中的 `page allocation failure` 会限速，也会被 `__GFP_NOWARN` 屏蔽。
- 修改方案：

  原文：

  > | 内存（低端） | 同一时刻的低端内存已用量（LowTotal − LowFree）；低端内存分配失败次数；DMA 区的直接回收次数（allocstall_dma） | 同上 | 已用量比值上界 ≤ 1.03；失败次数不增加；直接回收次数不超出噪声范围 |

  新文字：

  > | 内存（低端） | ① 非 CMA 低端可用量：`/proc/zoneinfo` 中 DMA 区的 `nr_free_pages − nr_free_cma`，取场景中的最小值和结束值；② 内核不可回收的低端占用：`SUnreclaim` + 启动日志 Memory 行中的 reserved 与 kernel 各项；③ 内核分配引起的直接回收次数：`allocstall_normal`（GFP_KERNEL 记在 Normal 档，本板 Normal 区虽为空也一样）；④ 低端分配失败：实验内核用 kretprobe 记录 `__alloc_pages_noprof` 返回 NULL、且 gfp 的最高 zone ≤ NORMAL 的次数 | 同上 | ① 的最小值比值下界 ≥ 0.97；② 比值上界 ≤ 1.03；③ 不超出 A/A 噪声；④ 不增加 |

  3.3.1“验证”中的 `allocstall_dma、allocstall_highmem` 改为 `allocstall_normal、allocstall_movable、allocstall_high`。
- 需要增加的测试：
  - 在阶段 0 做一次“已知扰动”校验：构造一个只增加 slab 的负载（例如反复打开大量 socket），确认 ①③ 有反应；
  - 换一个只改内核映像大小的构建（例如关闭一个 4 KB 的选项），确认 ② 能分辨出来。

**V1-2【重要】统计方案在单板上的轮次和时长没有核算**

- 位置：1.3“样本量”“频率”。
- 问题：
  1. **样本量**：做单侧非劣效检验时，如果真实差异为 0，取 α=0.05、检出力 80%、门槛 δ=2%，每组需要的轮次约为 n ≈ 2(1.645 + 0.84)² · CV²/δ² ≈ 12.4 · (CV/δ)²。轮次间变异系数（CV）为 3% 时约需 28 轮，5% 时约需 77 轮。“不少于 10 轮”只够 CV 不超过 1.8% 的指标。
  2. **单轮内的 P99**：单轮的切换次数很少（通常十来次），在单轮里算 P99 没有意义。只有单轮事件数足够多的指标（例如微基准中的逐页换入）才能这样算。
  3. **板时间预算**：每个变体要跑两组调频策略，乘以轮次和单轮时长（标准场景约 10–20 分钟），一个变体就要几十小时。第 5 节有几十个变体，单板排不下。
  4. **降频**：RPi4 的过热和欠压降频由固件执行，cpufreq 不一定能反映出来。本树的 hwmon 只导出欠压粘滞位（`drivers/hwmon/raspberrypi-hwmon.c:45-80`），不导出降频位。
- 修改方案：在 1.3 末尾追加：
  > - **分层验收**：先用低噪声指标筛选（内核态 instructions、cycles，静态段），未通过就停止；只有入围的变体才跑完整的墙钟轮次。
  > - **轮次**：按 A/A 测得的 CV，用 n ≈ 12.4·(CV/δ)² 求每组轮次，并写明上限（例如 40 轮）；达到上限仍判“证据不足”的，记为“无法证明不回退”，不再加跑。
  > - **分位数**：单轮事件少于 200 的指标，不在单轮内计算 P99，改用分层 bootstrap（先抽轮次，再抽轮内事件）。
  > - **降频检查**：每轮用 `perf stat -a -e cycles,cpu-clock` 计算有效频率，同时读取 `thermal_zone0/temp`；有效频率低于锁频值 98% 的轮次作废并重跑。
  > - **两组频率**：schedutil 组只对入围变体执行。

**V1-3【一般】zram 重配不在已登记的常规授权范围内**

- 位置：1.1“板上操作”。
- 问题：
  - RULES.md 的常规授权第 2 条只覆盖“/proc/sys 和 /sys 下的可写参数”。swapoff、mkswap、swapon 是对块设备和 swap 子系统的操作，文字上不在授权范围内。
  - 在负载下执行 swapoff，会把 1.5 GiB 设备里的页全部换入，可能引发 OOM。
- 依据：`docs/RULES.md` 中的“板上常规授权（2026-10-30，PM裁决）”。
- 修改方案：
  - 原文：“zram 的运行时重配（swapoff、reset、设算法、设 disksize、mkswap、swapon）按运行时参数处理。”
  - 新文字：“zram 的运行时重配（swapoff、reset、设算法、设 disksize、mkswap、swapon）需要 PM 在 RULES.md 中显式登记为常规授权之后才执行；执行时机限定在开机静置、zram 占用低于 64 MiB 时，并在报告中记录执行前的 mm_stat。”

### §2 现状基线

**V2-1【一般】DMA 区覆盖全部低端内存的原因写错了文件，并影响 3.3.2 的推论**

- 位置：2.3 表格 DMA 区一行的说明。
- 问题：
  - 本树中有三个机器描述的 `dt_compat` 都包含 `"brcm,bcm2711"`：
    - `board_bcm2835.c:105-122` 的 BCM2835 描述，**没有设置 dma_zone_size**；
    - `board_bcm2835.c:124-139` 的 BCM2711 描述，仅在 ZONE_DMA 和 ARM_LPAE 同时启用时设置 SZ_1G；
    - `bcm2711.c:12-25` 的 BCM2711 描述。
  - `of_flat_dt_match_machine()` 遇到同分时，取链接顺序中的第一个（`drivers/of/fdt.c:719-727`，比较条件是严格的 `<`）。`mach-bcm/Makefile:40-41` 中 board_bcm2835.o 排在前面，所以**按推理，实际匹配的是没有设置 dma_zone_size 的 BCM2835 描述**。
  - 但无论匹配哪一个，结果都一样：`arch/arm/mm/init.c:100-116` 在 dma_zone_size 为 0 时取 `arm_dma_limit = 0xffffffff`，再令 `ZONE_DMA = min(限制, max_low)`。所以“全部低端内存在 DMA 区”的根因是 `CONFIG_ZONE_DMA=y` 加上 DMA 上限不低于低端内存的大小。
  - 由此推出：改成 VMSPLIT_2G 后，如果实际匹配的是 BCM2835 描述，DMA 区会继续覆盖全部约 1.76 GiB 低端内存，**Normal 区仍然为空**，lowmem_reserve 也不会“恢复到设计意图”。
  - 低端内存的大小应为 768 MiB：present 196,608 页；计算式 `0xff800000 − 240 MiB − 8 MiB − 0xC0000000 = 0x30000000`，依据 `arch/arm/mm/mmu.c:1164,1209`。原文写的“不到 760 MiB”不准确。
- 修改方案：
  - 原文：“全部低端内存都在 DMA 区：RPi 内核为 BCM2711 设置了 `dma_zone_size = SZ_1G`（`arch/arm/mach-bcm/board_bcm2835.c`），而低端内存不到 1 GiB”
  - 新文字：“全部低端内存（768 MiB）都在 DMA 区：ARM 上 ZONE_DMA 取 `min(arm_dma_limit, max_low)`（`arch/arm/mm/init.c:100-116`）。三个匹配 `brcm,bcm2711` 的机器描述中，按链接顺序推断实际生效的是不带 dma_zone_size 的 BCM2835 描述（此时 arm_dma_limit=4 GiB）；若生效的是 BCM2711 描述，上限为 1 GiB，结果相同。实际生效的是哪一个，在阶段 0 用 `/proc/cpuinfo` 的 Hardware 行确认”
  - 在阶段 0 的“补采”中加入：`/proc/cpuinfo` 的 Hardware 行，以及 dmesg 中的 `Zone ranges`。

**V2-2【重要】CMA 平衡和下游阈值使 lowmem_reserve 的实际保护量只有名义值的约四分之一；内核栈也不在低端内存**

- 位置：2.3“低端内存保护参数实际很弱”和“这对优先级的影响”；3.3.1“方案”“预期收益”。
- 问题：
  1. 可移动分配（用户页，带 ALLOC_CMA）在 DMA 区做水位检查时，**空闲的 CMA 页也计入可用**（`mm/page_alloc.c:3196-3199`，只有不带 ALLOC_CMA 时才扣除）。
  2. 本树带有树莓派的下游提交 e640262c2f69（David Plowman，2022），新增启动参数 `alloc_in_cma_threshold`，默认值为 12（`mm/page_alloc.c:236-256、2319-2322`）。它的含义是：只有当 CMA 空闲超过区内空闲的 12/16 时，可移动分配才优先从 CMA 取页（上游的阈值是 1/2）。
  3. 推论（推理，需实测）：可移动分配会先吃掉非 CMA 的低端页，直到非 CMA 空闲约为 CMA 空闲的 1/3。设非 CMA 空闲为 N，CMA 空闲约为 3N，水位检查通过的条件近似为 N + 3N > min + reserve，即 **N 的下限约为 (min + reserve)/4**。
     - 现状（ratio 256）：非 CMA 低端只保留约 (3.3 + 12.5)/4 ≈ **4 MiB**。
     - 改为 ratio 32 后：约 (3.3 + 99.6)/4 ≈ **26 MiB**，而不是 3.3.1 写的“约保护 100 MiB”。
  4. kswapd 判断是否平衡时，只要**任意一个**符合条件的区达到水位就认为平衡（`mm/vmscan.c:6695-6706`），而且用的是不含 CMA 的空闲量（alloc_flags=0）。所以 reserve 越大，kswapd 在 HighMem 紧张时持续工作的时间越长。这个副作用需要单独测 kswapd 的 CPU。
  5. 平台配置 `VMAP_STACK=y`：内核栈通过 `__vmalloc_node_range` 分配（`kernel/fork.c:315-317`），而 vmalloc 会自动加上 `__GFP_HIGHMEM`（`mm/vmalloc.c:3652`）。所以**内核栈位于 HighMem**，只占用 vmalloc 地址空间。2.3 中“内核栈……都在低端内存中”不成立。
  6. 低端内存紧张时，GFP_KERNEL 引起的回收 `reclaim_idx` 为 NORMAL。MGLRU 的 `scan_folios()` 会遍历所有 zone 的链表（`mm/vmscan.c:4427-4430`），而 `sort_folio()` 会把不符合条件的 HighMem folio **提升一代**（`:4355-4357`）。低端压力因此会扭曲 HighMem 页的老化顺序。这一点属于置换机制，不在本文范围内，但它说明“少发生低端定向回收”本身就有价值，应该告知负责 ML 回收的同事，并在实验中记录 allocstall_normal 的次数。
- 修改方案：
  - 2.3 中把“内核静态映像、slab、内核栈、网络缓冲等内核分配都在低端内存中”改为：“内核静态映像、slab（包括 zsmalloc 的 handle 和 zspage 元数据缓存）、网络缓冲、内核页表的上层等都在低端内存中；内核栈（VMAP_STACK=y）、用户 PTE 页（HIGHPTE=y）、zram 槽表和 zsmalloc 载荷（经 vmalloc 或带 `__GFP_HIGHMEM`）位于 HighMem，只占用 vmalloc 地址空间”。
  - 3.3.1“方案”的原文：“运行时把 `lowmem_reserve_ratio` 的 DMA 档从 256 调到 32（约保护 100 MiB）”
  - 新文字：“运行时把 `lowmem_reserve_ratio` 的 DMA 档从 256 调到 32（名义保留约 100 MiB；由于 CMA 空闲计入可移动分配的水位，加上下游 `alloc_in_cma_threshold=12`，对非 CMA 低端的实际保护估算只有约 26 MiB），并与 B2（调整 alloc_in_cma_threshold）分别做对照、再做组合”
  - 3.3.1“验证”中增加：kswapd CPU 和 pgscan_kswapd；DMA 区 `nr_free_pages − nr_free_cma` 的时间序列；`cma_alloc_success` 和 `cma_alloc_fail`（vmstat）。

**V2-3【一般】2.4 中有两处表述不准确**

- 位置：2.4 表格中“分支栈”和“llvm-profgen 22.1.8”两行。
- 问题：
  - Cortex-A72 是 ARMv8.0，在 AArch32 和 AArch64 两种状态下都没有分支记录硬件（BRBE 是 ARMv9.2 才有的特性）。“在 32 位下”这个限定会误导人以为 aarch64 镜像可以拿到分支数据，与 3.7 BOLT 一节的结论矛盾。
  - 只有指令地址的输入，在 `checkPerfScriptType()` 里会直接以 **“Invalid perf script input!”** 退出（`PerfReader.cpp:1215`），根本到不了 `:374` 的“Unsupported perfscript!”。
- 修改方案：
  - 原文：“不支持（Cortex-A72 在 32 位下没有可供 perf 使用的分支记录）”
  - 新文字：“不支持（Cortex-A72 是 ARMv8.0，在 AArch32 和 AArch64 下都没有分支记录硬件）”
  - 原文：“只有指令地址的样本报 “Unsupported perfscript!””
  - 新文字：“只有指令地址的样本在类型检测阶段报 “Invalid perf script input!” 退出”

### §3.1 编译器与代码体积

**V3.1.1-1【重要】编译器补丁的放开条件过宽，会让用户态 `-pg` 程序崩溃；内核探测也需要随之调整**

- 位置：3.1.1“方案”第 2 点的 diff 和“内核”说明。
- 问题：
  - Clang 只有在 `EABIVersion == GNU` 时才把 mcount 设为 `llvm.arm.gnu.eabi.mcount`（也就是 `__gnu_mcount_nc`），否则用 `"\01mcount"`（`clang/lib/Basic/Targets/ARM.cpp:326-330`）。而 EABIVersion 只来自显式的 `-meabi` 选项：驱动只在用户给出 `-meabi` 时才转发（`Clang.cpp:5601-5604`）。
  - 因此用户态的 `clang --target=arm-linux-gnueabihf -pg` 调用的是旧式 `mcount`。glibc ARM 的旧式 `_mcount` 会从 `fp` 和 `[fp,#-4]` 读取调用者的返回地址（glibc `sysdeps/arm/arm-mcount.S`，具体版本无法核实）。
  - v2 的条件 `arch == arm && isOSLinux()` 会对这类构建也放开 `-fomit-frame-pointer`。届时 fp 中是任意值，`_mcount` 解引用后会得到错误的调用图或者段错误。所以“只有内核显式选择才生效”这个说法并不成立。
  - 内核侧要配合修改：编译器条件改成依赖 `-meabi gnu` 之后，Kconfig 的探测也必须带上 `-meabi gnu`。原因是 `cc-option` 只包含 CLANG_FLAGS，而内核的 `-meabi gnu` 来自 `arch/arm/Makefile:122-124` 的 CFLAGS_ABI，不在 CLANG_FLAGS 里。
- 修改方案：用以下两份 diff 替换 v2 的示意。

```diff
--- a/clang/lib/Driver/ToolChains/Clang.cpp   (llvmorg-22.1.8, Clang::ConstructJob)
+++ b/clang/lib/Driver/ToolChains/Clang.cpp
@@ -8069,4 +8069,13 @@
+  // Only __gnu_mcount_nc (selected by -meabi gnu, see Targets/ARM.cpp
+  // MCountName) takes the caller's LR from the stack.  The legacy "mcount"
+  // reads the frame pointer, so -fomit-frame-pointer stays rejected there.
+  bool UsesGnuMcountNC =
+      (Triple.getArch() == llvm::Triple::arm ||
+       Triple.getArch() == llvm::Triple::armeb) &&
+      (Triple.isOSLinux() || Triple.getOS() == llvm::Triple::UnknownOS) &&
+      Args.getLastArgValue(options::OPT_meabi) == "gnu";
   if (Arg *A = Args.getLastArg(options::OPT_pg))
     if (FPKeepKind == CodeGenOptions::FramePointerKind::None &&
-        !Args.hasArg(options::OPT_mfentry))
+        !Args.hasArg(options::OPT_mfentry) && !UsesGnuMcountNC)
       D.Diag(diag::err_drv_argument_not_allowed_with) << "-fomit-frame-pointer"
                                                       << A->getAsString(Args);
```

```diff
--- a/arch/arm/Kconfig
+++ b/arch/arm/Kconfig
@@ config CC_HAVE_STACKPROTECTOR_TLS 之前
+config CC_CAN_OMIT_FRAME_POINTER_WITH_PG
+	def_bool CC_IS_CLANG && $(cc-option,-meabi gnu -pg -fomit-frame-pointer)
+
--- a/arch/arm/Makefile
+++ b/arch/arm/Makefile
@@ ifeq ($(CONFIG_CC_IS_CLANG),y) CFLAGS_ABI += -meabi gnu endif 之后
+ifeq ($(CONFIG_FUNCTION_TRACER)$(CONFIG_ARM_UNWIND)$(CONFIG_CC_CAN_OMIT_FRAME_POINTER_WITH_PG),yyy)
+ifndef CONFIG_THUMB2_KERNEL
+# __gnu_mcount_nc and the EHABI unwinder do not need a frame pointer
+KBUILD_CFLAGS	+= -fomit-frame-pointer
+endif
+endif
```

- 在平台配置下是否生效：CC_IS_CLANG=y、FUNCTION_TRACER=y、ARM_UNWIND=y、THUMB2_KERNEL 未设置、FRAME_POINTER 不存在（UNWINDER_FRAME_POINTER 未设置）。用未打补丁的 Clang 22.1.8 构建时，探测失败，构建结果与现在完全一样；用打了补丁的 Clang 构建时，探测通过，选项生效。
- 副作用：
  - 不传 `-meabi gnu` 的用户态构建行为不变；
  - `kernel/sched/Makefile` 等处显式追加的 `-fno-omit-frame-pointer` 在命令行中位于后面，仍然生效。
- 需要增加的测试：
  - lit 测试，对 `--target=arm-linux-gnueabihf -pg -fomit-frame-pointer` 分别验证：
    - 不带 `-meabi gnu`：**仍然报错**；
    - 带 `-meabi gnu`：不报错，并生成 `-mframe-pointer=none`；
    - thumb、x86_64、aarch64：仍然报错。
  - IR 测试：`-meabi gnu` 下函数属性中的 instrument 名称为 `llvm.arm.gnu.eabi.mcount`。
  - 内核：检查 `.config` 中出现 `CC_CAN_OMIT_FRAME_POINTER_WITH_PG=y`，并抽查 `.cmd` 文件中含有 `-fomit-frame-pointer`。
- 补充：v2 的 `-Xclang -mframe-pointer=none` 快速实验在顺序上可行：驱动在 `Clang.cpp:5775-5792` 生成帧指针参数，在 `:7669` 才追加 `-Xclang` 的参数，后者排在后面。cc1 是否取最后一个值，仍以第一次构建的 `.cmd` 和反汇编为准。

**V3.1.2-1【建议】探测补丁在本平台确实生效，只需补一项检查**

- 依据：
  - 平台配置中 CPU_32v7=y，CPU_32v6 未出现，所以第一条 `default`（`-march=armv7-a`）生效。上一轮在 LLVM buildroot 上的对照实验已经证明这条探测能通过（`evidence/task3/kconfig_probe_armv7.txt`）。
  - STACKPROTECTOR_PER_TASK 的默认值为 y，依赖的 CURRENT_POINTER_IN_TPIDRURO=y。
  - “本树 1376–1377，上游 v6.12.80 中为 1373–1374”已核对无误。
- 修改方案：在“验证”中加一句：“olddefconfig 后的 diffconfig 应当只出现 `CC_HAVE_STACKPROTECTOR_TLS n→y` 和 `STACKPROTECTOR_PER_TASK 新增 y` 两项；出现其他差异即停止。”

**V3.1.4-1【重要】FUNCTION_TRACER 打开时，链接期死代码消除几乎删不掉函数；6.12 的链接脚本还会打乱冷代码分组**

- 位置：3.1.4“依据”“预期收益”。
- 问题与依据：
  1. **上游数据已核实**：提交 ed0f94102251（“ARM: 9404/1: arm32: enable HAVE_LD_DEAD_CODE_DATA_ELIMINATION”）在本地仓库中，提交说明给出 zImage 缩小 2.0%（defconfig）、2.7%（vexpress）、29.7%（tinyconfig）、3.2%（a15eb）。不过这几个配置都没有打开函数追踪，例如本树的 `multi_v7_defconfig` 中没有 FUNCTION_TRACER。
  2. **ftrace 会把函数全部保住**：
     - 平台配置 `FTRACE_MCOUNT_USE_RECORDMCOUNT=y`。recordmcount 为每个插桩点在 `__mcount_loc` 中生成一条指向所在函数段的重定位；
     - 链接脚本用 `KEEP(*(__mcount_loc))` 保留整个表（`include/asm-generic/vmlinux.lds.h:174-177`）；
     - 被保留的段通过重定位引用的段也会被保留，所以**所有带 `-pg` 插桩的函数都不会被 `--gc-sections` 回收**。
     - 能删掉的只剩：未被引用的数据和只读数据、notrace 或去掉了 `-pg` 的对象中的函数、未被引用的汇编。
     - 因此，在保留函数追踪的前提下，收益很可能远小于“数百 KB 到 1 MB”（推理，需构建验证）。
     - 如果产品关闭 FUNCTION_TRACER（3.1.1 的方案 1），这一限制随之消失。两者是交互关系，不能分别估算后相加。
  3. **冷代码分组失效**：
     - 开启死代码消除后，`TEXT_MAIN` 变成 `.text .text.[0-9a-zA-Z_]*`（`vmlinux.lds.h:102`）。在 `TEXT_TEXT` 中它排在 `.text.unlikely` 之前（`:561-566`），会把 `.text.unlikely.*` 吞进主段。
     - 结果是 3.7 依赖的“冷函数集中放在 .text.unlikely”在 6.12 上不成立，只有排在最前的 `.text.hot.*` 能正确归组。
     - 上游 v6.13 的提交 **0043ecea2399**（“vmlinux.lds.h: Adjust symbol ordering in text output section”）把顺序改为 unlikely、hot、main，正是为了修这个问题。ARM 也通过 `ARM_TEXT` 使用 `TEXT_TEXT`（`arch/arm/include/asm/vmlinux.lds.h:103`）。
  4. 行号：本树中 select 位于 `arch/arm/Kconfig:122`，121 是上游 v6.12.80 中的行号。
- 修改方案：
  - “依据”原文：“评审方引用上游提交说明称 zImage 减少 2%–3.2%，需要 Codex 在本树核对该提交及其数据。”
  - 新文字：“上游提交 ed0f94102251（本地仓库可查）给出 zImage 缩小 2.0%–3.2%（defconfig、vexpress、a15eb）；这些配置都没有打开 FUNCTION_TRACER。本平台使用 recordmcount，`__mcount_loc` 会以 KEEP 方式保住全部插桩函数，所以保留函数追踪时，收益主要来自数据、只读数据和未插桩的代码。”
  - “预期收益”原文：“按上游数据的量级，常驻段可能减少数百 KB 到 1 MB，全部是低端内存。”
  - 新文字：“分两种构建测量：保留 FUNCTION_TRACER，以及关闭 FUNCTION_TRACER。两者都用 `-Wl,--print-gc-sections` 统计被回收的段，按函数、数据、只读数据分类。不预先承诺数值。”
  - 在“方案”末尾追加：“同时回移植上游 0043ecea2399（vmlinux.lds.h 的段顺序调整），否则 3.7 的冷代码分组不生效。”
- 回移植的副作用：
  - 函数排列顺序变化，会影响 System.map、kallsyms 的顺序以及 `.text` 的布局，性能需要重新取基线；
  - sparc 的同名改动与本平台无关。
- 需要增加的测试：
  - 回移植后，用 `readelf -S` 和 `nm -n` 确认 `.text.unlikely.*` 中的函数位于 `.text.hot.*` 之前；
  - `_stext`、`_etext` 和 `__entry_text_*` 的相对顺序不变；
  - ftrace 和 kprobe 冒烟测试。

**V3.1.6-1【建议】**：同意按低优先级执行，另外补一项验证：确认 boot 分区中的 `config.txt` 加载的是同一个 zImage，并且没有被固件的 `kernel=` 配置改成别的文件。

### §3.2 BTF

**V3.2-1【重要】外置 BTF 的路径和“版本校验”写得不对；libbpf 本身就能找到外置 BTF，不需要改插件**

- 位置：3.2“BTF 的特殊情况”第二点的第 1 项，以及“可行的替代路径”。
- 问题与依据：
  1. 第 1 项写“只要还做 CO-RE 字段重定位，就仍然需要内核 BTF”，与下文“外置 BTF 能满足 CO-RE”自相矛盾。CO-RE 需要的是**与运行内核一致的 vmlinux BTF**，它可以来自文件。
  2. libbpf 1.6.2 的 `btf__load_vmlinux_btf()` 在 `/sys/kernel/btf/vmlinux` 不存在时，会依次尝试一组后备路径，例如 `/boot/vmlinux-<release>`、`/lib/modules/<release>/vmlinux-<release>`、`/usr/lib/debug/boot/vmlinux-<release>`（libbpf `src/btf.c:5363-5412`），并用 `btf__parse()` 解析；该函数先按裸 BTF 格式解析，失败再按 ELF 解析（`:1409-1424`）。所以**只要把 detached BTF 装到 `/lib/modules/<release>/vmlinux-<release>`，插件不需要设置 `btf_custom_path`**，只需要把挂载方式从 fentry 改成 kprobe。
  3. **libbpf 不会做版本或 build-id 校验**：后备路径只按 `uname -r` 拼接文件名。而同一版本号的每次 QB 构建，`uname -r` 都是 `6.12.80-arm-rpi4-v7l`。v2 写的“测试版本不匹配时会被拒绝”并不会发生：版本不匹配时，CO-RE 会静默使用错误的偏移。正确性只能靠打包保证：BTF 与 vmlinux 在同一次构建中生成，并装进同一个 RPM。
  4. `/usr/lib/modules` 在板上是独立的 ext4 挂载（09 D 节）。外置 BTF 约 6.5 MB，需要确认这个分区的余量；这些是闪存空间，只在加载 BPF 时才读入内存。
- 修改方案：
  - 第 1 项原文：“插件即使改用 kprobe 或 tracepoint（这两种在 ARM32 可用），只要还做 CO-RE 字段重定位，就仍然需要内核 BTF；”
  - 新文字：“插件即使改用 kprobe 或 tracepoint（这两种在 ARM32 可用），只要还做 CO-RE 字段重定位，就仍然需要一份与运行内核完全一致的 vmlinux BTF；这份 BTF 可以来自内核（/sys/kernel/btf），也可以来自文件；”
  - 原文：“外置 BTF 必须与内核的 build-id 绑定，并测试版本不匹配时会被拒绝。”
  - 新文字：“libbpf 不校验外置 BTF 的版本，只按 `uname -r` 查找后备路径（libbpf 1.6.2 `btf.c:5363-5412`）。因此由 spec 在同一次构建中生成 BTF，并装到 `/lib/modules/<release>/vmlinux-<release>`，随模块包一起发布；另外由测试脚本比对 `/sys/kernel/notes` 中的 build-id 与随包发布的 build-id 记录，作为发布检查，而不是期待 libbpf 拒绝。”

```diff
--- a/packaging/linux-rpi.spec
+++ b/packaging/linux-rpi.spec
@@ -225,2 +225,4 @@
-       # Generate vmlinux.h from vmlinux binary
-       ./build/${target}/bpftool btf dump file build/${target}/vmlinux format c > build/${target}/btf/vmlinux.h
+       # Kernel BTF may be disabled; always encode a detached copy from DWARF
+       pahole -J --btf_encode_detached=build/${target}/btf/vmlinux.btf build/${target}/vmlinux
+       ./build/${target}/bpftool btf dump file build/${target}/btf/vmlinux.btf format c > build/${target}/btf/vmlinux.h
@@ -300 +302,6 @@
     make O=build/${target} INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=%{buildroot} modules_install
+    if [ "${target}" = "%{variant}" ]; then
+        # libbpf fallback path for user-space CO-RE when /sys/kernel/btf is absent
+        KREL=$(make -s O=build/${target} kernelrelease)
+        install -m 644 build/${target}/btf/vmlinux.btf %{buildroot}/lib/modules/${KREL}/vmlinux-${KREL}
+    fi
```

  （该文件落在已有的 `/lib/modules/*%{variant}-v7l/` 通配路径下，会随模块包一起打包，不需要修改 `%files`。）
- 副作用：
  - 模块包增大约 6.5 MB；
  - 内核 BTF 保留时，这份文件只是冗余；
  - 关闭内核 BTF 后，依赖 `/sys/kernel/btf` 的工具（bpftool 的类型化输出、tp_btf、bpf_iter）仍然不可用。
- 需要增加的测试：
  - 关闭内核 BTF 的镜像上，`LIBBPF_LOG_LEVEL=debug` 运行改造后的插件，日志应出现 `loading kernel BTF '/lib/modules/.../vmlinux-...': 0`；
  - 故意装一份其他构建的 BTF，确认插件采集的字段明显错误（用来证明必须依赖打包保证）；
  - 对比 vmlinux.h 与旧流程生成的版本。

### §3.3 低端内存

**V3.3.2-1【重要】VMSPLIT_3G_OPT 在本平台无法选择；VMSPLIT_2G 的“Normal 区会出现”也不成立**

- 位置：3.3.2“依据”“方案”。
- 问题：
  1. `config VMSPLIT_3G_OPT depends on !ARM_LPAE`（`arch/arm/Kconfig:1038-1039`），而平台配置是 ARM_LPAE=y。要选它就得关闭 LPAE，同时失去 THP 和 mTHP（`arch/arm/Kconfig:95`，7.6 依赖它们），页表格式也会改变。所以这不是一个可以单独构建的变体。
  2. VMSPLIT_2G 下 Normal 区能否出现，取决于 V2-1 中实际生效的是哪个机器描述。如果是 BCM2835 描述，DMA 区会覆盖全部低端内存，ratio 仍然是 256。
- 修改方案：
  - 原文：“VMSPLIT_3G_OPT 可以多出约 256 MiB 低端内存，VMSPLIT_2G 可以多出约 1 GiB，代价是每个进程的用户地址空间从 3 GiB 降到 2.75 GiB 或 2 GiB。改成 2G 后低端内存超过 1 GiB，Normal 区会出现，lowmem_reserve 也会恢复到设计意图。”
  - 新文字：“VMSPLIT_3G_OPT 依赖 !ARM_LPAE（arch/arm/Kconfig:1038–1039），本平台不可选。VMSPLIT_2G 可以多出约 1 GiB 低端内存，代价是用户地址空间降到 2 GiB。改成 2G 后是否出现 Normal 区，取决于实际匹配的机器描述（见 2.3）；如果没有出现，需要同时调整 lowmem_reserve_ratio 的 DMA 档。更小代价的替代是 B1 的 `vmalloc=` 启动参数。”
  - “方案”中删去“VMSPLIT_3G_OPT 和”。

### §3.4 zram

**V3.4.1-1【一般】给出配置 diff 的位置和预期的 diffconfig**

- 问题：defconfig 中目前只有 `CONFIG_ZRAM=y`（`arch/arm/configs/tizen_bcm2711_defconfig:209`）。v2 的 diff 没有写目标文件，也没有写预期结果。另外，`# ... is not set` 这两行与默认值相同，不需要写。
- 已核对：v2 关于 `ZRAM_BACKEND_LZO` 的默认值等于 `FORCE_LZO` 的说法正确（`drivers/block/zram/Kconfig:47-56`）。默认算法 `ZRAM_DEF_COMP_LZORLE` 依赖 LZO 后端，显式保留 LZO 后仍是默认选项。
- 修改方案：

```diff
--- a/arch/arm/configs/tizen_bcm2711_defconfig
+++ b/arch/arm/configs/tizen_bcm2711_defconfig
@@ -209 +209,5 @@
 CONFIG_ZRAM=y
+CONFIG_ZRAM_BACKEND_LZO=y
+CONFIG_ZRAM_BACKEND_LZ4=y
+CONFIG_ZRAM_BACKEND_ZSTD=y
+CONFIG_ZRAM_MULTI_COMP=y
```

  验证：用平台 diffconfig 比较，结果应当恰好是 `ZRAM_BACKEND_FORCE_LZO y→n`、`ZRAM_BACKEND_LZ4 n→y`、`ZRAM_BACKEND_ZSTD n→y`、`ZRAM_MULTI_COMP n→y`；`ZRAM_DEF_COMP` 仍为 `"lzo-rle"`。

**V3.4.3-1【重要】成本账本没有区分低端内存和 HighMem**

- 位置：3.4.3。
- 问题：v2 已经把低端内存定为首要约束，但 zram 的各项成本落在不同的内存区：
  - **低端内存**：zsmalloc 每个对象一个 handle，来自 `zs_handle-zram0` slab，分配时去掉了 HIGHMEM 标志（`mm/zsmalloc.c:329-333`）；每个 zspage 一个描述结构，来自 `zspage-zram0` slab（`:340-344`）。估算：满载约 40 万个对象时，handle 约 1.6 MB，加上 zspage 结构和 slab 开销，合计约 2–4 MB，全部在低端内存。
  - **HighMem**：zsmalloc 载荷页（带 `__GFP_HIGHMEM | __GFP_MOVABLE`）；槽表通过 `vzalloc` 分配（`zram_drv.c:1345`），vmalloc 会加上 `__GFP_HIGHMEM`（`mm/vmalloc.c:3652`）；每 CPU 的 zstd 工作区同样通过 vmalloc 分配。
  - **vmalloc 地址空间**：槽表和工作区占用 vmalloc 地址，而它的总量只有 240 MiB。
- 修改方案：在 3.4.3 列表前插入：“各项分别标注所在内存区：低端内存（`/proc/slabinfo` 中的 `zs_handle-zram0`、`zspage-zram0`）、HighMem（zsmalloc 载荷、槽表、压缩上下文）、vmalloc 地址（槽表、压缩上下文）。低端内存部分计入 1.2 的低端门槛。”

**V3.4.4-1【一般】调度延迟的测量方法可以更直接**

- 位置：3.4.4 中 `cond_resched` 补丁的“验证”。
- 问题：平台配置有 `SCHED_TRACER=y`，tracefs 中有 `wakeup_rt` tracer，它会直接给出最大唤醒延迟（`tracing_max_latency`）以及对应的调用栈。用它比解析调度事件更简单，也更准确。
- 修改方案：
  - 原文：“用 tracefs 的调度事件比较改前改后的最大调度延迟”
  - 新文字：“启动一个绑定到与写 idle 的进程相同 CPU、SCHED_FIFO 50、每 1 ms 唤醒一次的探针进程，用 tracefs 的 `wakeup_rt` tracer 读取 `tracing_max_latency` 和对应的追踪记录，比较改前改后的值”

### §3.5 MGLRU

**V3.5.1-1【一般】min_ttl 只在 kswapd 路径生效，“覆盖 memcg force_reclaim 路径”没有意义**

- 依据：`lru_gen_age_node()` 只由 `kswapd_age_node()` 调用（`mm/vmscan.c:6631-6637`，调用点在 `:6968`）。memcg 的 `force_reclaim` 走 `try_to_free_mem_cgroup_pages`，不会检查 min_ttl。内核 OOM 选择被杀进程时按 `oom_score_adj` 排序；resourced 是否按前后台设置 oom_score_adj，本次无法核实。
- 修改方案：
  - 原文：“同时覆盖全局回收和 memcg `force_reclaim` 两条路径。”
  - 新文字：“min_ttl 只在 kswapd 的老化路径中生效（vmscan.c:6631–6637），所以测试必须制造全局内存压力；memcg 的 force_reclaim 不受它影响。阶段 0 读取所有进程的 `oom_score_adj`，用来预判内核 OOM 会选中谁。”

### §3.6 用户态协同

**V3.6.1-1【建议】先量清可归还的是哪类内存，并复用现有的生命周期事件**

- 问题：
  - 大内存进程中有 .NET 应用（任务 5 Top30 中的 SystemUI.dll、runner）。它们的匿名内存主要是托管堆，`malloc_trim` 管不到，要靠 GC 压缩。
  - Tizen 应用框架已有低内存类的生命周期事件（例如 `APP_EVENT_LOW_MEMORY`，.NET 侧对应 `OnLowMemory`）。本镜像的 resourced 是否已经发送这类事件，无法核实。
- 修改方案：在 3.6.1“方案”前加一步：“先对候选进程拆分 RssAnon：用 smaps 区分 `[heap]`、glibc arena、匿名 mmap 和托管堆区域，估计各自可归还的上限；托管进程走 GC 压缩，原生进程走 `malloc_trim`。通知优先复用应用框架已有的低内存事件，不新增私有 IPC。”

### §3.7 采样驱动优化

**V3.7-1【重要】判断冷热应该用精确的调用计数，关中断修正应该基于调用链**

- 位置：3.7 第 1、3、4 步。
- 问题：
  1. 平台配置有 `FUNCTION_PROFILER=y`（运行时值为 0）。在训练用的镜像上打开 `function_profile_enabled`，可以得到**每个 ftrace 插桩函数的精确调用次数**（`trace_stat/function*`）。它没有关中断盲区，也没有 skid。用“多场景下调用次数为 0”来判冷，比“没有采样样本”可靠得多，正好弥补 2.4 中列出的弱点。采样样本只用来决定热函数的权重和排序。这项功能开销大，只能在训练轮次中使用；notrace 函数和被内联的函数不会被计数。
  2. 原文第 4 步说“样本落在 `local_irq_restore`…附近”。但 `local_irq_restore` 是内联函数，样本会落在调用者体内；`_raw_spin_unlock_irqrestore` 则不内联，落在其中的样本会丢失“是谁持有锁”这一信息。正确的做法是 `perf record -g`：ARM32 的内核调用链经 EHABI 可用（`arch/arm/kernel/perf_callchain.c:96-97`），把样本归给调用链上的祖先函数。被调函数在关中断期间执行完并已返回的那部分，仍然需要静态调用图补上一层。
  3. 冷代码集中依赖 V3.1.4-1 中的 0043ecea2399 回移植。
- 修改方案：
  - 第 3 步原文“对长时间、多场景都没有样本的函数，评估用 `-Os` 或标记为冷代码以减小体积。”
  - 新文字：“在训练镜像上打开 ftrace function profiler，取得每个函数的精确调用次数；多场景合计调用次数为 0 的函数作为冷候选（notrace 和内联函数另行处理）。采样样本只用来给热函数定权重。评估对冷候选用 `-Os` 或标记为冷代码以减小体积。”
  - 第 4 步原文“对样本落在 `local_irq_restore`、`spin_unlock_irqrestore` 等开中断点附近的函数，……”
  - 新文字：“用 `perf record -g`（内核调用链经 EHABI 可用），对落在 `_raw_spin_unlock_irqrestore` 和中断返回路径等开中断点上的样本，把热度归给调用链上的祖先函数；关中断期间执行完的被调函数，用静态调用图补上一层；入口代码、中断、调度核心、锁和 hrtimer 列入强制热名单。”

**V3.7-2【一般】PGSO 不等于 -Os，需要用上限构建来校准**

- 问题：`-fprofile-sample-accurate` 让没有出现在 profile 中的函数按冷函数处理，但这只在部分 pass 中触发按体积优化（PGSO），体积收益会小于整函数 `-Os`。所以第 6 步“全内核 -Os 的上限”只能作为上界。
- 修改方案：在第 5 步末尾追加：“PGSO 只在部分 pass 中按体积优化，实际体积收益以构建结果为准，不能直接引用全内核 -Os 的上限；如果收益不足，用评审 A3 的编译器冷函数清单方式。”

### §4 测量方法

**V4.3-1【重要】按 function_graph 现在的用法，所有内核函数都会受影响，测量会扰动结果**

- 位置：4.3“真实应用的单次调用耗时”。
- 问题：
  - `set_graph_function` 只决定从哪个函数开始记录，**不限制插桩范围**。function_graph 打开后，所有被 ftrace 插桩的函数调用都会经过 graph 入口钩子，全系统的开销会大幅上升。
  - 另外，`do_swap_page` 下面的整棵调用树都会被记录。
  - 要只测这两个函数，应当用 `set_ftrace_filter` 把插桩点限制在这两个函数上，并把 `max_graph_depth` 设为 1。两个函数都是非 static 的全局函数（`mm/memory.c:4200`、`mm/page_io.c:608`），但仍需要在 `available_filter_functions` 中确认。
- 修改方案：
  - 原文：“用 tracefs 的 function_graph，通过 `set_graph_function` 只跟踪 `do_swap_page` 和 `swap_read_folio`，直接得到每次调用的耗时。”
  - 新文字：“用 tracefs 的 function_graph：先确认这两个函数出现在 `available_filter_functions` 中，再 `echo do_swap_page > set_ftrace_filter`、`echo 1 > max_graph_depth`、`echo 0 > options/funcgraph-irqs`，然后选择 function_graph。这样只有这一个函数被插桩，每次调用只记录一条耗时。`swap_read_folio` 单独测一轮。测量开销用 A/A 对比（追踪开和关）定量。”
- 需要增加的测试：用一个已知时长的内核路径（例如 `usleep_range` 的调用者）做计时校验；检查 `trace_pipe` 有没有丢失记录（`per_cpu/cpu*/stats` 中的 overrun）。

### §5 实验计划

**V5-1【一般】阶段 0 太重，并有遗漏**

- 问题：
  - 阶段 0 同时包含重建基线、所有测量设施、热度分析和全内核按体积优化的上限构建，而且“前提：无”。按 V1-2 的轮次估算，单板排不开。
  - 遗漏的只读补采项：`/proc/cpuinfo` 的 Hardware 行、dmesg 中的 Zone ranges（V2-1）；`oom_score_adj`（V3.5.1-1）；`/proc/slabinfo` 中 zsmalloc 相关缓存（V3.4.3-1）；vmalloc 用量的峰值（B1）；function profiler 能否打开（V3.7-1）。
  - 阶段 2 中的死代码消除需要同时完成 0043ecea2399 的回移植，并分开测“保留和关闭 FUNCTION_TRACER”两种情况。
- 修改方案：
  - 阶段 0 拆成 0a 和 0b：
    - 0a：栈保护修复和基线重建，加上述只读补采；
    - 0b：测量设施、A/A 和样本量估算；热度分析与上限构建移到阶段 4 开头。
  - 阶段 2 的“链接期死代码消除（3.1.4）”改为“链接期死代码消除（3.1.4，保留和关闭 FUNCTION_TRACER 两种构建，并回移植 0043ecea2399）”。

### §6 风险

**V6-1【一般】补两行**

| 事项 | 影响 | 处理 |
| --- | --- | --- |
| 编译器 `-pg` 放开条件不当 | 用户态 `-pg` 程序的 `_mcount` 读到无效 fp，导致崩溃 | 只在 `-meabi gnu` 下放开（V3.1.1-1） |
| 外置 BTF 与内核不一致 | CO-RE 静默使用错误的偏移，数据错误 | 同一次构建生成并同包发布，由发布检查比对 build-id（V3.2-1） |

### §7 后续研发储备

**V7.7-1【重要】Clang 在 ARM 上会忽略 -mtune，第一步实验实际上什么也不改**

- 依据：`clang/lib/Driver/ToolChains/Arch/ARM.cpp:660-662`（22.1.8）写着“TODO Handle -mtune=. Suppress -Wunused-command-line-argument”，也就是只吞掉这个参数、不生效，而且**不会给出警告**。GCC 的 ARM 后端支持 `-mtune=cortex-a72`。
- 修改方案：
  - 原文：“第一步只加 `-mtune=cortex-a72`，不改变指令集，兼容性不受影响；”
  - 新文字：“Clang 22.1.8 在 ARM 上忽略 `-mtune`（Arch/ARM.cpp:660–662），而且没有警告，所以 Clang 内核不能用这种方式做实验。可选的做法有三种：① 先在 GCC 内核上用 `-mtune=cortex-a72` 估计调度收益的量级；② 让 Clang 的 ARM 驱动把 `-mtune` 转为 `tune-cpu`，这是编译器改动，需要确认 ARM 后端是否支持按 tune-cpu 选择调度模型（无法核实）；③ 直接评估 `-mcpu=cortex-a72`，即第二步。另外，调优目标应当是**产品 SoC 的 CPU**，而不是替身板的 A72。”

**V7.6-1【一般】打开 THP 本身有低端内存的静态成本**

- 问题：打开 TRANSPARENT_HUGEPAGE 会编入 huge_memory 和 khugepaged 等代码，并增加一个内核线程，这些都在低端内存中，应按 1.2 的“内核静态”一行说明原因。另外，6.12 对同步 IO 的 swap 设备支持 mTHP 换入（`mm/memory.c:4282` 的 `alloc_swap_folio`），zram 换入时会整个大页一起解压。v2 的风险项已提到“换入放大”，需要在验证中具体测量。
- 修改方案：在“风险”末尾追加：“打开 THP 增加的静态体积和 khugepaged 的低端内存开销，按 1.2 的‘内核静态’一行报告；对换入大页的情况，统计每次缺页实际解压的页数。”

---

## 二、对第 8 节问题的逐条答复

**问题 1：1.2、1.3 的口径和统计判定是否足以支持“2%/3% 不回退”？在 RPi4 上是否可执行？**

- 全机内存、性能延迟类、性能吞吐类三行的口径基本合理。
- **低端一行不成立（V1-1，阻断）**：“LowTotal − LowFree”看不到内核静态变化；`allocstall_dma` 对 GFP_KERNEL 恒为 0，应当用 `allocstall_normal`；“分配失败次数”没有数据来源。
- 统计方法在概念上正确，但轮次需要按实测 CV 计算（CV 为 3% 时每组约 28 轮）；单轮事件少时不能在单轮内算 P99；需要检测降频；单板时长需要做预算，并对变体做分层筛选（V1-2）。

**问题 2：2.3 的低端内存分析是否正确？3.3 是否有遗漏的副作用？**

数值都正确：DMA 区 present 196,608 页、CMA 地址范围、非 CMA 约 375 MiB、12.5 MiB 与 99.6 MiB 的计算。需要修正的有：

- DMA 区的原因应归到 `arch/arm/mm/init.c`，生效的机器描述未确认；低端内存应为 768 MiB（V2-1）；
- 内核栈因为 VMAP_STACK 位于 HighMem（V2-2 第 5 点）；
- **CMA 空闲计入可移动分配的水位，加上下游 `alloc_in_cma_threshold=12`，对非 CMA 低端的实际保护只有名义值的约 1/4**：现状约 4 MiB，ratio 32 时约 26 MiB（V2-2）。

3.3 遗漏的副作用：

- reserve 越大，kswapd 在 HighMem 紧张时工作得越久（pgdat_balanced 的判定方式）；
- 低端定向回收会让 MGLRU 把 HighMem folio 提升一代（V2-2 第 6 点）；
- VMSPLIT_3G_OPT 与 LPAE 互斥；VMSPLIT_2G 不一定出现 Normal 区（V3.3.2-1）。

**问题 3：3.1.1 和 3.1.2 的改法在本平台和其他 ARM 配置下是否正确？**

- 3.1.1 的编译器条件**不正确**：`arm && Linux` 会放开不带 `-meabi gnu` 的构建，而这类构建使用依赖 fp 的旧式 `mcount`，会导致用户态 `-pg` 程序崩溃。应当以 `-meabi gnu` 为条件，内核探测也要带上 `-meabi gnu`（V3.1.1-1，附 diff）。安全性分析本身（EHABI 展开、function_graph 走 `unwind_frame`）与上一轮的结论一致，仍然成立。
- 3.1.2 的补丁在本平台生效（CPU_32v7=y，CPU_32v6 未设置）。在 v6、v6K 和 v7 混合的配置下，会走第二条 default（`-march=armv6k`），与 `arch/arm/Makefile:63-70` 一致。Thumb2 内核同样满足 CURRENT_POINTER_IN_TPIDRURO 的要求；需要在上游版本中加上 `-mthumb` 的探测用例（V3.1.2-1）。

**问题 4：3.2 的 BTF 依赖清单是否完整？BTFGen/外置 BTF 的路径是否可行？**

清单本身完整。替代路径可行，而且比原文写的更简单：libbpf 1.6.2 会在 `/lib/modules/<release>/vmlinux-<release>` 等后备路径中自动查找裸 BTF，插件只需要改挂载方式。需要纠正两点：

- CO-RE 需要的是“与运行内核一致的 vmlinux BTF”，不是“内核 BTF”；
- libbpf 不会因为版本不匹配而拒绝，只能靠同一次构建生成、同包发布来保证。

具体见 V3.2-1，附 spec diff。

**问题 5：3.4 的逐因素对照、成本账本和“全部标记空闲”变体的代价分析是否完整？**

- 逐因素对照完整。
- 成本账本缺少低端内存与 HighMem 的划分：zsmalloc 的 handle 和 zspage 元数据在低端内存，满载估算约 2–4 MB（V3.4.3-1）。
- 配置 diff 缺少目标文件和预期的 diffconfig（V3.4.1-1）。
- 延迟测量应改用 `wakeup_rt`（V3.4.4-1）。
- “全部标记空闲”变体的语义和代价分析是正确的，`recompress` 从槽 0 开始扫描、`max_pages` 只限制重压缩次数也已核实。

**问题 6：3.7 在只有指令地址采样的条件下是否可靠？有没有更好的利用方式？**

按现在的写法不够可靠。改进有三点：

- 用 ftrace function profiler 的精确调用次数判冷，它没有关中断盲区；采样只用来给热函数定权重；
- 关中断修正改用 `perf record -g` 的调用链；
- 冷代码分组依赖 0043ecea2399 的回移植，否则在死代码消除下不生效。

PGSO 的收益要用实际构建校准（V3.7-1、V3.7-2）。更直接的方式是由编译器读入冷函数清单（A3）。

**问题 7：第 5 节的阶段划分和第 7 章的排序是否合理？**

阶段划分基本合理，但阶段 0 过重，需要拆分并补上只读采集项（V5-1）。第 7 章的排序建议如下：

1. 7.3（场景编排，可以不改内核先验证）；
2. 7.1（重压缩游标，先只加统计）；
3. 7.4（预换入）；
4. 7.2；
5. 7.8（只在需要保留 BTF 时考虑）；
6. 7.6；
7. 7.5；
8. 7.7 降到最后：Clang 下第一步无效，第二步会改变指令集（V7.7-1）。

---

## 三、更好的方案

### A. 对已有方案的改进

| 编号 | 对应 | 改进 | 为什么更好 |
| --- | --- | --- | --- |
| A1 | 1.2 低端门槛 | 改用“DMA 区非 CMA 空闲量”“SUnreclaim 加 reserved”“allocstall_normal”和 kretprobe 失败计数 | 能检测到静态和 slab 的变化，不受 CMA 借用和页缓存的干扰（V1-1） |
| A2 | 3.2 BTF | 把 detached BTF 装到 libbpf 的后备路径，插件只改挂载方式；靠同包发布保证版本一致 | 少一处插件改动，而且不依赖一个并不存在的版本校验（V3.2-1） |
| A3 | 3.7 | 冷热判断用 function profiler 的调用次数；由编译器新增选项读入冷函数清单，直接为这些函数加上 `minsize` 和 `cold` 属性（Clang 前端或一个小的 IR pass，团队可以修改），不再经过 sample profile 和 PGSO | 去掉了 create_llvm_prof、profgen 转换和 PGSO 阈值三处不确定性；体积收益接近对冷函数整体使用 `-Os`；清单可以审阅，也便于回退 |
| A4 | 4.3 | function_graph 配合 `set_ftrace_filter` 和 `max_graph_depth=1` | 只对目标函数插桩，开销可以忽略（V4.3-1） |
| A5 | 3.4.4 | 用 `wakeup_rt` tracer 测最大延迟 | 直接给出最大值和对应的调用栈（V3.4.4-1） |
| A6 | 3.3.1 | 名义 reserve 与 `alloc_in_cma_threshold`（B2）分开对照后再组合 | 实际的低端保护由两者共同决定（V2-2） |

### B. 有依据的新方案

**B1. 用 `vmalloc=` 启动参数把低端内存扩大约 64–112 MiB**

- 做什么：在启动参数中加 `vmalloc=128M`（或 160M），缩小 vmalloc 区，把腾出的部分交给低端内存。
- 依据：
  - ARM 的 `early_vmalloc()` 支持这个参数，默认值是 240 MiB（`arch/arm/mm/mmu.c:1164-1192`）；低端上限的计算在 `:1209`；也见内核文档 kernel-parameters 中的 `vmalloc=`。这是上游已有的机制，不需要改内核。
  - 本板 VmallocUsed 在静置时为 21 MiB（09 A 节）。内核栈（VMAP_STACK）、zram 槽表、压缩上下文都在 vmalloc 区内。
- 预期收益（计算值）：
  - `vmalloc=128M` 时低端上限为 `0xff800000 − 128M − 8M − 0xC0000000` = 880 MiB，比现在多 112 MiB，非 CMA 低端从约 375 MiB 增加到约 487 MiB（+30%）；
  - `vmalloc=160M` 时多 80 MiB。
  - 新增的低端内存都位于 CMA（428–748 MiB）之上，不影响 CMA 的位置。
  - 用户地址空间不变，代价比 VMSPLIT_2G 小得多。
- 前提：标准场景（含视频播放和所有应用）中 vmalloc 峰值的两倍仍小于新的 vmalloc 大小。
- 风险：
  - vmalloc 耗尽会导致 fork 失败（VMAP_STACK）、模块或驱动的 ioremap 失败、zram 初始化失败；
  - 产品板的 ioremap 量可能不同。
- 验证：
  - 阶段 0 做只读采集：标准场景中周期读取 `/proc/vmallocinfo`，求峰值并按调用者分类；
  - 之后由用户修改 boot 分区的 cmdline 并重启，做 A/B：比较非 CMA 低端空闲量、allocstall_normal，以及 fork 和模块加载的压力测试。
- 阶段：0（只读部分）和 1。

**B2. 调整 `alloc_in_cma_threshold`，让可移动分配更早使用 CMA，以保护非 CMA 低端**

- 做什么：用启动参数 `alloc_in_cma_threshold=8`（恢复上游的 1/2 行为），或者取 10。
- 依据：树莓派下游提交 e640262c2f69（`mm/page_alloc.c:236-256、2319-2322`），默认值为 12/16，提交说明中写明了改回 8 的效果以及取 12 的理由（防止 CMA 碎片导致 `cma_alloc` 失败）。
- 预期收益（推理）：在同样的 reserve 下，非 CMA 低端的空闲下限从约 (min + reserve)/4 提高到约 /2。现状下约从 4 MiB 提高到 8 MiB；与 ratio 32 组合时，约从 26 MiB 提高到 51 MiB。
- 前提：视频和 GPU 的 CMA 分配延迟与失败率不回退。
- 风险：这正是下游当初提高阈值所防范的 CMA 碎片问题；CMA 中的可移动页需要迁移，分配延迟会上升。
- 验证：
  - vmstat 中的 `cma_alloc_success`、`cma_alloc_fail`；
  - 视频起播和切台耗时；
  - DMA 区非 CMA 空闲量的时间序列。
- 阶段：1，与 3.3.1 分开做对照，再做组合。

**B3. 用内存分配剖析（MEM_ALLOC_PROFILING）在测量内核上找出低端内存的主要占用者**

- 做什么：只在测量镜像上打开 `CONFIG_MEM_ALLOC_PROFILING`，读取 `/proc/allocinfo` 中按源码位置汇总的分配量。
- 依据：上游 v6.10 合入（Suren Baghdasaryan 和 Kent Overstreet 的分配标签系列）；本树中的依赖仅为 `PROC_FS && !DEBUG_FORCE_WEAK_PER_CPU`（`lib/Kconfig.debug:993-1000`）。平台配置中这个选项可见但未设置，说明在 ARM32 上可以选择。
- 预期收益：本身没有收益，但能把 slab 和页分配精确到调用点，用来决定 3.2 的裁剪项和 V1-1 的门槛重点。这比 slabinfo 更细，而且覆盖直接的页分配。
- 前提和风险：
  - 它会选上 PAGE_EXTENSION，按每页一项分配 page_ext，在低端内存中占用数 MB（估算）；
  - 分配路径会变慢。
  - 所以只能用于测量镜像，结论用差值表达，不能直接拿绝对值和产品镜像比较。
- 验证：测量镜像与基线镜像在同一场景下，对比 `/proc/allocinfo` 前 50 项与 `/proc/slabinfo` 的一致性。
- 阶段：0b（测量设施）。

**B4. 回移植上游 0043ecea2399（段顺序调整）**：详见 V3.1.4-1。它是 3.7 冷代码分组的前提，改动只涉及链接脚本，可以与 3.1.4 一起放在阶段 2。

### C. 探索性方案（第 7 章没有的）

**C1. 让 resourced 感知低端内存压力**

- 要解决的问题：
  - resourced 的分级阈值基于全机内存（limiter.conf 中的 MemoryLevelThreshold 25%、15%、10%、7%）。在本板上，非 CMA 低端内存可能已经耗尽，而 MemAvailable 仍然很高。此时 resourced 不会动作，压力完全落在内核：GFP_KERNEL 直接回收、kswapd，乃至低端定向回收扭曲 MGLRU 的老化顺序（V2-2 第 6 点）。
  - 现有机制都按全机口径工作，内核本身只能靠 lowmem_reserve 这一个静态参数。
- 设计思路：
  - resourced 周期读取 `/proc/zoneinfo` 中 DMA 区的 `nr_free_pages − nr_free_cma`，以及 `allocstall_normal` 的增量；
  - 低端可用量低于 L1 时，先做低成本的动作：回收后台组中的页缓存（`memory.force_reclaim` 只作用于后台 memcg），并通知后台应用释放内存（3.6.1）；
  - 低于 L2 时，按现有策略查杀后台应用；
  - 不改内核，也不改置换策略，只增加一个触发条件。
- 收益粗估与推理：
  - 收益体现在高压场景中 `allocstall_normal` 和内核 OOM 的次数下降，以及前台切换的长尾缩短。
  - 量级取决于低端压力实际出现的频率，所以第一步只做统计。
  - 如果标准场景中非 CMA 低端的空闲量从未低于 30 MiB，本方案就没有价值，应当停止。
- 风险：
  - 低端可用量受 CMA 借用的影响而波动，阈值需要做迟滞；
  - 与 3.3.1、B1、B2 的效果会互相重叠，需要按组合重新验收。
- 最小验证实验：
  - 不改 resourced，在阶段 1 的高压场景中，以 1 秒为周期记录 DMA 区的非 CMA 空闲量、allocstall_normal、MemAvailable；
  - 观察是否出现“低端紧张而 MemAvailable 高于 resourced 第一级阈值”的时间段，以及它与切换长尾是否相关。

**C2. 让 zsmalloc 的 handle 直接存放在 zram 槽表中，去掉 `zs_handle` slab**

- 要解决的问题：zsmalloc 为每个对象从低端内存的 slab 中分配一个 4 B 的 handle（`mm/zsmalloc.c:329-333`），用于在对象迁移时间接寻址。zram 满载时约 40 万个对象，加上 slab 开销，约占 1.6–2 MB 低端内存（估算）。而 zram 的槽表本身已经保存了 handle 的值，并且位于 HighMem 的 vmalloc 区。
- 设计思路：
  - 给 zsmalloc 增加一个接口，由调用方提供 handle 的存储位置（`zs_malloc_at(pool, size, gfp, unsigned long *slot)`），zsmalloc 迁移对象时直接改写这个位置；
  - zram 把 `&table[index].handle` 传进去。vmalloc 地址是常驻的内核线性映射，访问不需要 kmap。
  - 对象释放时的顺序和锁协议，要与现在“handle → 对象”的协议一致：zsmalloc 在 pool 锁下读写 handle，zram 在槽锁下读取。
- 收益粗估：
  - 低端内存：约 4 B × 对象数，加上 slab 开销，满载约 1.6–2 MB；
  - CPU：每次写入少一次 slab 分配和释放（微秒以下量级）。
- 风险：
  - 与上游 zsmalloc 分叉；上游 zram 重构系列 v7 也在改动这一带的代码，状态无法核实；
  - 迁移与槽释放之间存在竞态；
  - zswap 等其他使用者需要保留旧接口。
- 最小验证实验：在 3.4 的高压场景中读取 `/proc/slabinfo` 中 `zs_handle-zram0` 和 `zspage-zram0` 的峰值。合计不到 1 MB 就放弃。

**C3. 调用次数驱动的“冷函数清单”编译器选项**（即 A3 的具体做法，因为上游没有这样的选项，单列为探索项）

- 要解决的问题：3.7 的 sample profile 路线有三处不确定：工具链是否可用、PGSO 的阈值、关中断盲区；最终体积收益也难以预测。
- 设计思路：
  - 用 function profiler 在多个训练场景中取得调用次数，生成冷函数清单（调用次数为 0，并排除强制热名单）；
  - 新增一个 Clang 选项 `-fcold-function-list=<file>`，在前端或一个早期 IR pass 中，为清单内的函数加上 `cold` 和 `minsize` 属性；
  - `cold` 属性会使函数进入 `.text.unlikely`（需要 B4 的链接脚本调整），`minsize` 让整个函数按 `-Oz` 方式优化；
  - 清单随内核源码版本管理，可以审阅。
- 收益粗估：
  - 上界由 3.7 第 6 步的全内核 `-Os` 构建给出；
  - 冷函数占 `.text` 的比例由 function profiler 的覆盖率给出；
  - 两者相乘就是本方案的估算。例如冷函数占 80%、`-Oz` 比 `-O2` 小 12% 时，约为 1.9 MB（估算）。
- 风险：
  - 训练场景没有覆盖到的函数被错误地按体积优化，造成长尾回退，需要通过训练与验收分离来控制；
  - 清单与源码版本错配，会影响维护。
- 最小验证实验：
  1. 先不改编译器，用 `__attribute__((cold, minsize))` 手工标记一个目录（例如 `net/sunrpc`），测量体积变化；
  2. 再在一个 2–3 分钟的场景上打开 function profiler，统计调用次数为 0 的函数占 `.text` 的比例。
  - 两者相乘若不到 1 MB，就停止。

---

## 四、总结

**最重要的 5 个问题**

1. **V1-1【阻断】** 低端内存门槛的三个指标都测不到想测的东西：“LowTotal − LowFree”看不到静态变化；`allocstall_dma` 对 GFP_KERNEL 恒为 0，应当用 allocstall_normal；“分配失败次数”没有数据来源。
2. **V3.1.1-1【重要】** 编译器补丁按 `arm && Linux` 放开，会让不带 `-meabi gnu` 的用户态 `-pg` 程序读到无效 fp。必须以 `-meabi gnu` 为条件，内核探测也要带上它。
3. **V2-2【重要】** CMA 空闲计入可移动分配的水位，加上下游 `alloc_in_cma_threshold=12`，lowmem_reserve 对非 CMA 低端的实际保护只有名义值的约 1/4（现状约 4 MiB，ratio 32 时约 26 MiB）；内核栈因为 VMAP_STACK 位于 HighMem。
4. **V3.1.4-1【重要】** FUNCTION_TRACER 打开时，`__mcount_loc` 会以 KEEP 方式保住全部插桩函数，链接期死代码消除的收益会远小于上游数据；6.12 的链接脚本还会吞掉 `.text.unlikely.*`，需要回移植 0043ecea2399。
5. **V3.2-1 / V3.3.2-1【重要】** libbpf 不校验外置 BTF 的版本，只能靠同一次构建生成、同包发布来保证；VMSPLIT_3G_OPT 与 LPAE 互斥，VMSPLIT_2G 也不一定出现 Normal 区。

**B 类前 3**

1. B1：`vmalloc=` 启动参数，非 CMA 低端增加约 80–112 MiB，不改内核，也不牺牲用户地址空间；
2. B2：`alloc_in_cma_threshold`，下游机制，可与 3.3.1 组合；
3. B3：MEM_ALLOC_PROFILING 测量内核，按调用点找出低端内存的主要占用者。

**C 类前 3**

1. C1：让 resourced 感知低端内存压力；
2. C3：调用次数驱动的冷函数清单编译器选项；
3. C2：zsmalloc 的 handle 放进 zram 槽表。

**总体结论：修改后冻结。** v2 采纳了上一轮的大部分意见，结构和证据链都明显改善，低端内存分析的数值和 3.1.2 的补丁都核对无误。但 V1-1 的低端门槛必须先改正，否则 v2 新增的核心验收口径实际上无法判定；V3.1.1-1 的编译器条件、V2-2 的保护量估算、V3.1.4-1 的收益预期、V3.2-1 和 V3.3.2-1 的事实错误，都需要在冻结前修正。这些都是局部修改，不需要大改。
