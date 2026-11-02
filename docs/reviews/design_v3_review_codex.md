**Linux 内核优化设计 v3 评审（2026-10-30）**

总体结论：**修改后冻结**。主要优化方向成立；需要先修正统计验收、冷函数识别和开机测量，再把若干探索项补成可实施的协议。没有证据要求推翻整份方案。

评审对象是 `docs/10_design_v3.md`，SHA-256 为 `793c0762d48d9dc46a7af7ccc4c55a0aeb212b967c58184a8052f4db68d435cb`，与用户给出的 raw 文件一致。源码依据为工作区 `linux-rpi@0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`；下文源码行号均按这份树，不把上游相近版本的行号冒充本树行号。

已打开原始配置、task5 内存/运行参数、task5c perf 输出，并核对 LLVM 22.1.8、libbpf 1.6.2、相关上游提交与在审系列。另用现有平台 Clang、平台 Kconfig 工具在隔离目录验证新增配置和 `-meabi gnu` 小程序；**没有完整编译、启动实验内核，没有操作开发板**。“配置有效”仅指最终 Kconfig 结果确实保留，不表示性能或正确性已通过板测。验证记录见 [design_v3_review_codex_verification.txt](/home/linhao/Toolchain/development/linux_kernel_optimization/docs/reviews/design_v3_review_codex_verification.txt)。

以下按 v3 已设定的性能/开机 2%、内存 3% 容差评审；这表示“在该容差下证明非劣”，不等于证明严格零回退。

**一、逐章评审**

**第 0 章：范围和基线**

范围清楚，排除 ML 页面置换/回收合理。接受来源已闭合的 sandbox 内核与最终配置，不再重复追问 v1 的来源问题。RPi4 的收益只能用于筛选机制，产品 SoC、设备和业务仍须复验。

**第 1 章：指标、统计与副作用**

**R01｜阻断｜1.3：少量事件的二次抽样不能修复 p99 的证据不足。**

- **问题**：前文按完整轮次重抽样，后文却因每轮少于 200 个事件而再独立抽轮内事件。固定流程中的连续切换、换入有相关性，这会改变统计模型；200 不是有效性的分界。普通 bootstrap 也不能生成样本中从未出现的尾部事件。样本量公式的 12.4 系数对应近似独立、等方差两组均值，不能直接指导配对 p99。
- **依据**：1.3 两条抽样规则相互冲突；独立两组近似系数为 `2×(1.645+0.842)²≈12.37`，配对设计应使用配对差异的方差。p99 的方差还依赖尾部分布，不能仅由轮间 CV 推出。
- **原文**：“单轮事件少于 200 个的指标……改用分层 bootstrap（先抽轮次，再抽轮内事件）。”
- **替换为**：“所有 p99 的主分析保留完整轮次及轮内事件顺序，按预定义的 A/B 配对块重抽样。只有验证了轮内抽样模型后才采用二级或连续块抽样，不以 200 个事件为切换阈值。先用 A/A 的相关结构、尾部事件数和模拟覆盖率确定轮次数及每轮事件数；尾部证据不足时报告无法判定。12.4×(CV/δ)²仅作为独立两组均值的粗略工时估计，不用于配对指标或 p99。”
- **需增加的测试**：模拟相关突发、相同中位数但 p99 恶化、少数坏轮次、离散/并列延迟和同日配对效应；检查置信区间覆盖率及误判通过率。无需内核 diff。

**R02｜重要｜1.3：`cycles/cpu-clock` 不能直接作为整机锁频有效性判据。**

- **问题**：`perf stat -a` 的软件 cpu-clock 是 CPU 墙钟时间，PMU cycles 在 WFI/时钟停止时不保证同样计数；低占用场景可能被误判为降频。`CPU_IDLE=n` 也不代表不执行 WFI。另外，若候选导致更多发热，删除其降频轮次会隐藏真实副作用。
- **依据**：[events/core.c:11467–11490][clocksrc]；[ARM process.c:71–80][idle]; [Arm PMCCNTR 定义](https://support.arm.com/documentation/ddi0601/2026-06/AArch32-Registers/PMCCNTR--Performance-Monitors-Cycle-Count-Register)。task5c 的硬件事件证据只证明事件可用，未校准这个频率估计器。
- **原文**：“每轮用 `perf stat -a -e cycles,cpu-clock` 计算有效频率……低于锁定值 98% 的轮次作废重跑。”
- **替换为**：“系统范围 cycles/cpu-clock 仅作活动度相关的辅助量。受控组另用短时、绑核、连续运行的校准负载，核对同作用域 cycles 与运行时间、温度和可获得的固件限频/欠压状态；不把校准负载混入业务计时。预登记环境异常排除规则及最大重试次数。由候选自身引起的持续发热或限频保留为实验结果，默认 schedutil 验收不得删除此类轮次。”
- **副作用/测试**：校准会升温，需固定间隔和冷却条件；覆盖空闲、单核忙、全核忙、欠压和热限频，确认不把空闲误判为降频。

1.2 把 MemAvailable 与物理占用分开、以 `LowFree−CmaFree` 观察非 CMA 低端空闲、使用 `allocstall_normal`，这些修改正确。1.4 的补充见 R13。

**第 2 章：现状与能力边界**

**R03｜一般｜2.3、3.3.1：CMA 平衡比例不是非 CMA 空闲的保证下限。**

- **问题**：12.5/49.8/99.6 MiB 名义 protection 计算成立；“实际保护约 4/26 MiB”只在特定近似平衡状态下有意义。阈值作用于允许 CMA 的 buddy 分配，不能保证不可移动分配、PCP、不同阶数与持续 CMA 消费下都有同样保护。
- **依据**：[page_alloc.c:2319–2349、3197、3413][pa]：阈值决定 CMA 优先尝试；它不是独立的非 CMA watermark。
- **原文**：“所以对非 CMA 低端内存的实际保护明显小于名义值。评审方推算现在约 4 MiB、改为 32 后约 26 MiB，以实测为准。”
- **替换为**：“CMA 空闲计入可移动请求可用水位，名义 protection 不能保证等量非 CMA 空闲。4/26 MiB 仅为特定平衡假设下的示意估算，不是保护下限；报告应同时给出该假设及实测分布。调低 alloc_in_cma_threshold 只改变取页偏好，不保证非 CMA 保护按比例增加。”
- **测试**：在同一用户页压力下分别加入不可移动分配、CMA 连续分配和高阶分配，记录每区/迁移类型的结果。无需新补丁。

BCM2835/BCM2711 描述存在匹配重叠的源码事实成立；但实际选择哪个描述尚无板上 Hardware 证据，保持“待确认”，不判为错误。240 MiB vmalloc、320 MiB CMA、非 CMA 低端约 375 MiB 与原始输出一致。

**R04｜重要｜2.4、3.7、1.4 冷代码行、7.12：function profiler 不是全函数的精确零调用证明。**

- **问题**：本配置 `FUNCTION_GRAPH_TRACER=y`，profiler 注册的是 graph 回调，既计数也累计时间，“只有次数没有耗时”错误。它继承全局 ftrace 过滤器；记录分配失败、graph 栈/递归限制、启用前执行、未加载模块、notrace 和内联都会造成覆盖缺口。输出没有为每个 ELF 函数预先建立零记录。若沿用 4.3 的两函数过滤器，其他函数尤其不能判零。用户态打开 profiler 也覆盖不到早期内核启动。
- **依据**：[ftrace.c:473、612–665、750–807、820–904][ftrace]；[fgraph.c][fgraph]。这不是重复“采样缺失不等于冷”，而是 v3 新换用的计数来源仍须定义覆盖域。
- **原文**：“能在训练镜像上得到每个函数的精确调用次数，没有关中断盲区；只有次数没有耗时”；以及“调用次数为 0 的函数才进入候选”。
- **替换为**：“function profiler 对已插桩、已启用且实际覆盖的函数提供观测调用计数；本配置还会收集 graph 时间。它不依赖 PMU 溢出 IRQ，因此可补充部分关中断路径的观测，但不能证明全内核零调用。训练前保存并清理过滤器，记录可追踪函数全集、模块生命周期、启停窗口、各 CPU 数据及丢失条件。输出缺席的函数默认未知；仅在覆盖条件成立后列为该训练集中的未观测候选，再人工审阅。未覆盖的早期启动和恢复路径保持原优化等级。”
- **7.12 原文**：“上界由全局 `-Os` 对照点给出……两者相乘即估算值。”
- **替换为**：“全局 Os 是对照点，不是混合优化的上界。候选占比按最终符号/段字节统计，不按函数个数统计；先测候选对象的实际缩减率，再给出粗估。cold/minsize 与 Os 不等价，minsize 更偏向最小尺寸；PGSO 与整函数 Os 的体积也不存在保证的大小关系。”
- **副作用/测试**：profiling 自身改变调度与覆盖，不能只从验收中移除开销就认为训练无扰动。增加残留过滤器、模块晚加载、深调用、同名 static、早期 init 和已知次数用例；先做目录级白名单，不新增全量自动判冷补丁。调用链/静态调用图只能作保护热名单的保守线索，不能恢复已经返回的关中断函数的真实样本归属。

**第 3.1 节：编译器与代码体积**

3.1.1 的 `arm && Linux && -meabi gnu` 限定和保留默认行为，作为本平台 PoC 条件正确。本轮小程序确认 GNU EABI mcount 标识保持不变，`-Xclang -mframe-pointer=none` 消除了 frame-pointer 属性；旧 Clang 对显式 `-pg -fomit-frame-pointer` 仍报错。该结果支持进入 PoC，不证明 EHABI/ftrace 已安全。3.1.2 的 CPU_32v7 探测修复、先固定安全基线的顺序正确；3.1.3、3.1.5、3.1.6、3.1.7 的主要限制与验证方向均可保留。

**R05｜一般｜3.1.4：链接脚本描述需修正，并补齐上游补丁的对齐成本。**

- **问题**：本树 `.text.hot*` 已排在 TEXT_MAIN 前，不会被后者先吞掉；主要受影响的是后面的 unlikely/unknown 等。0043ecea2399 已核实存在，除改顺序还增加页对齐，不能当作零成本修正。
- **依据**：[本树 vmlinux.lds.h:553 起][lds]；[上游提交 0043ecea2399](https://github.com/torvalds/linux/commit/0043ecea2399ffc8bfd99ed9dbbe766e7c79293c)。本轮已对其公共头文件补丁执行 `git apply --check`，通过。
- **原文**：“会把 `.text.unlikely.*`、`.text.hot.*` 一起并入普通 `.text`……需要核对后回移植”。
- **替换为**：“TEXT_MAIN 会先匹配后置的 unlikely/unknown 等输入段；hot 已在它之前匹配。回移植已核实的 0043ecea2399 公共头文件修改，保留其完整顺序和页对齐，并单独记录对齐填充及最终地址变化。”
- **候选 diff**（原提交公共头文件部分，已通过本树 apply-check）：

```diff
diff --git a/include/asm-generic/vmlinux.lds.h b/include/asm-generic/vmlinux.lds.h
--- a/include/asm-generic/vmlinux.lds.h
+++ b/include/asm-generic/vmlinux.lds.h
@@ -553,19 +553,24 @@
  * .text section. Map to function alignment to avoid address changes
  * during second ld run in second ld pass when generating System.map
  *
- * TEXT_MAIN here will match .text.fixup and .text.unlikely if dead
- * code elimination is enabled, so these sections should be converted
- * to use ".." first.
+ * TEXT_MAIN here will match symbols with a fixed pattern (for example,
+ * .text.hot or .text.unlikely) if dead code elimination or
+ * function-section is enabled. Match these symbols first before
+ * TEXT_MAIN to ensure they are grouped together.
+ *
+ * Also placing .text.hot section at the beginning of a page, this
+ * would help the TLB performance.
  */
 #define TEXT_TEXT							\
 		ALIGN_FUNCTION();					\
+		*(.text.asan.* .text.tsan.*)				\
+		*(.text.unknown .text.unknown.*)			\
+		*(.text.unlikely .text.unlikely.*)			\
+		. = ALIGN(PAGE_SIZE);					\
 		*(.text.hot .text.hot.*)				\
 		*(TEXT_MAIN .text.fixup)				\
-		*(.text.unlikely .text.unlikely.*)			\
-		*(.text.unknown .text.unknown.*)			\
 		NOINSTR_TEXT						\
-		*(.ref.text)						\
-		*(.text.asan.* .text.tsan.*)
+		*(.ref.text)
 
 
 /* sched.text is aling to function alignment to secure we have same
```

ARM 链接脚本使用该宏，本配置可生效；本轮仅验证补丁适用性，未重链接内核。新增页对齐的单个填充上限小于一页，但重排还可能改变整体布局。增加 map 分组、填充字节、EHABI、ftrace、启动和 DCE 开/关对照；不删除 `KEEP(__mcount_loc)`。

**第 3.2 节：裁剪与 BTF**

**R06｜一般｜BTF 依赖清单、4.6：区分内核驻留 BTF 与用户程序自带 BTF，并落实运行时配套校验。**

- **问题**：“仍需要内核 BTF”容易被理解为必须编入内核；普通 CO-RE 可使用外置目标 BTF。程序自身的 BTF、基于 map 自有 BTF 的类型化输出，不一概依赖 vmlinux BTF。v3 已正确指出 libbpf 不自动校验，但“同包发布”与后面的只替换内核流程仍需衔接。
- **依据**：[libbpf.c:3443–3510](https://github.com/libbpf/libbpf/blob/v1.6.2/src/libbpf.c#L3443)、[btf.c:5361 起](https://github.com/libbpf/libbpf/blob/v1.6.2/src/btf.c#L5361)；本树 Makefile:1045–1046 对内核和模块生成 build-id。
- **原文**：“只要还做 CO-RE 字段重定位，就仍然需要内核 BTF”；“程序自身的 BTF”；“bpftool 的类型化输出”。
- **替换为**：“普通 CO-RE 需要与目标内核布局匹配的目标 BTF，可由用户态外置文件提供；程序/map 自带 BTF 单独列入依赖清单，不等同于依赖内核驻留 BTF。逐项区分目标类型重定位、内核 attach BTF ID、typed ksym/kfunc 和工具对 vmlinux 类型的查询。每个内核变体携带其 BTF、模块及哈希清单；加载前比对实际运行内核的 build-id，不能只比 uname/config 或包版本。”
- **测试**：故意部署同 release、同 config、不同源码布局的内核与错误 BTF，必须拒绝；外置 BTF 缺失、模块替换、普通 CO-RE 和 map 自带 BTF 分开验证。未核实产品依赖前继续保留 BTF，v3 的这一决策正确。

**第 3.3 节：低端内存**

**R07｜重要｜3.3.2：缩 vmalloc 要按地址保留量和最大空洞验收。**

- **问题**：VmallocUsed 主要反映已分配页，不是可用虚拟地址跨度；ioremap、保留区间、guard 和碎片都会影响连续映射。简单地让峰值翻倍小于 128 MiB，仍可能失败。112 MiB 是线性映射上界移动的候选值，不是新增物理 RAM。
- **依据**：[ARM mmu.c:1163–1245][mmu] 的 `vmalloc_limit`；[vmalloc.c:4998 起][vmalloc] 输出地址范围、页数和 ioremap 分类；本板 `VMAP_STACK=y`。
- **原文**：“如果峰值离 128 MiB 有足够余量……按计算可多出约 112 MiB 低端内存……余量至少保留峰值的两倍。”
- **替换为**：“统计 vmalloc/vmap/ioremap 的地址区间、guard/保留空间、最大单次请求和最大连续空洞，同时记录物理页数。依据压力、热插拔和长时间运行的地址高水位选择 192M/160M/128M 等候选；不能用 VmallocUsed 两倍作为充分条件。112 MiB 仅为当前边界差，实际 LowTotal 增量由内存洞、对齐和保留区决定；总 RAM 不增加，HighMem 容量相应转移。”
- **候选启动参数差异**（首次只试一档，保留其他参数；实际 boot 文件路径尚待部署调研）：

```diff
+vmalloc=192M
```

源码确有 ARM `early_param("vmalloc", ...)`，本配置会解析；本轮未改板上 cmdline。副作用是 VA 更紧及回退分配分布变化。增加线程风暴、GPU/多媒体映射、模块热插拔、最大连续请求、长期碎片和故障恢复测试。

3.3.3 保持 LPAE、排除 3G_OPT、检查真实映射需求，正确。3.3.4 先查实际 SWIOTLB 池和高水位再缩小，正确；须覆盖恢复后及 DMA 并发峰值，动态扩展也不能保证紧急分配成功。3.3.5 方案可执行，但 cache 合并问题见 R08。3.3.6 暂不改变 CMA 容量合理。

**第 3.4 节：zram**

**R08｜重要｜3.4.3、3.3.5、7.11：内存区域与 slab 归因仍有错误。**

- **问题**：zsmalloc 载荷和 vzalloc 页允许 HighMem，不保证在 HighMem；当前 lzo-rle 工作区明确使用 `kzalloc`，不是 vmalloc。另有 `SLAB_MERGE_DEFAULT=y`，按 cache 名读取/相加可能漏计或重复计数；`zs_handle` 字段虽为 ARM32 的 4 B，对象分配还受最小 8 B 对齐影响。
- **依据**：[backend_lzorle.c:19–31][lzorle]；[zsmalloc.c:294–355][zs]；[ARM cache.h:24][cache]；[slab_common.c:124–213][slab]；实际配置第 818 行。
- **原文**：“**HighMem**：zsmalloc 载荷页；槽表（vzalloc）；每 CPU 的压缩上下文（vmalloc）。”
- **替换为**：“按实际分配器和物理区域分类：载荷页和槽表底层页允许来自 HighMem，也可能来自低端/CMA；各后端上下文逐项列出，当前 lzo-rle 工作区由 kzalloc 分配，计入低端内存。vmalloc 另计地址占用。slab 统计解析 /sys/kernel/slab 的别名，按实际 cache 去重；混合 cache 不能全归 zram，需按对象来源计数。handle 的节省按真实对象步长和 slab 页测量，不按 4 B 字段宽度计算。”
- **副作用/测试**：该修正不改运行代码；增加各后端初始化/销毁、CPU 热插拔、混合 cache、分配失败时的成本账本。满 397,648 个槽若都有非同值对象，单按 8 B 步长约 3.03 MiB，尚未加其他元数据，不能将合计 2–4 MB 当作已验证预算。

3.4.1 的后端可用性闭环、保留 LZO 和回读实际算法，正确。3.4.2 的逐因素矩阵、4 KiB 离线样本、zsmalloc size class 归一，正确。3.4.4 的设备级轮次和槽锁外 `cond_resched` 方向正确；剩余持锁/取消边界见 R14/C1。3.4.5 的前台门槛合理。

**第 3.5 节：MGLRU**

**R09｜一般｜3.5.1：不能只靠 oom_score_adj 预判牺牲进程。**

- **依据/问题**：[oom_kill.c:203–241][oom] 的 badness 包含 RSS、swap、页表、调整值及可杀资格；还受 OOM 作用域影响。v3 对 min_ttl 位于 kswapd 路径、不能代替 force_reclaim 测试的修正成立，但后面的 victim 推断过强。
- **原文**：“内核 OOM 按 oom_score_adj 选择被杀进程……预判内核 OOM 会选中谁。”
- **替换为**：“读取 oom_score_adj，并结合 RSS、Swap、页表、可杀资格及 OOM 作用域评估风险；静态快照不能保证最终 victim。以实际 OOM 日志和进程角色验证，前台/系统进程被杀或存活数退化即失败。”
- **测试**：同 adj 不同 RSS/Swap、全局与 memcg OOM、多个候选同时增长。无需内核 diff。

3.5.2 的 v4、17 补丁、移出 RFC 的描述与[原始系列](https://patchew.org/linux/20261016-mglru-fg-v4-0-2106750c0bfa@tencent.com/)一致；其 ARM32、memcg v1、HighMem 收益仍**无法核实**，继续只列 PoC，不移植服务器收益。

**第 3.6 节：用户态协同**

**R10｜重要｜3.6.1：归还对象识别与异步协议还不够具体。**

- **问题**：smaps 无法可靠区分所有 glibc arena 与托管分配；“.NET 进程主要是托管堆”不能由进程名推出。GC 压缩也不等于向 OS 归还。现有低内存事件是否携带序号、截止时间、ACK、取消语义尚无接口证据，不能一面要求这些字段，一面保证无需协议扩展。
- **依据**：本仓库的 [F_resourced_config.txt](/home/linhao/Toolchain/development/linux_kernel_optimization/evidence/task5/F_resourced_config.txt) 是配置证据，不是框架 IPC/运行时堆布局证据；这些平台接口的确切能力标为**无法核实**。smaps 记录映射及内存计量，不记录每个对象的分配器所有权。
- **原文**：“用 smaps 区分 [heap]、glibc arena、匿名 mmap 和托管堆区域……要靠 GC 压缩……不新增私有 IPC”。
- **替换为**：“smaps 只做映射/PSS/SwapPss 盘点；结合分配器统计和运行时堆诊断识别可安全归还页，不按进程名推断。先清理可重建缓存，再分别评估 native trim、托管回收及向 OS 释放；不默认强制 compacting GC。先核对现有事件是否支持异步完成和版本扩展；不足时在应用框架扩展最小请求/应答协议，不假设现有回调已具备这些语义。”
- **建议追加原文**：“请求键为进程实例身份与生命周期代次，重复请求幂等；ACK 包含代次和完成状态，超时代次的 ACK 不再阻挡回收；resourced 重启、进程退出、PID 复用和回前台均使旧代次失效。截止时间仅限制等待和后续工作，不声称能中断已进入的 malloc_trim/GC。”
- **副作用/测试**：GC/trim 可能触碰已换出页、争锁并增加峰值；增加迟到 ACK、PID 复用、服务重启、后台即前台、GC 正在执行及内存紧急用例。完整代码 diff 应在核对实际框架接口后给出，当前不能编造接口补丁。

3.6.2 按 freeable 评估 zsmalloc 碎片、扣除原生 shrinker 已有收益，成立。

**第 3.7、3.8 节：采样优化与排除项**

3.7 的 AutoFDO 收益预算为零、先做函数热度与布局、排除 ARM32 BOLT，符合实际能力。R04 修正后可以继续。

3.8 不整组回移植 zram 重构的理由合理；已核对 [v7 原始系列](https://patchew.org/linux/20261025021839.1542805-1-senozhatsky@chromium.org/)。共享 swap、shmem 和预换入等非独占路径的实际比例仍**无法核实**。

**第 4 章：测量与部署**

**R11｜重要｜4.3：两函数过滤器配 max_graph_depth=1 会漏内层。**

- **依据/问题**：[trace.h:1056–1065][traceh] 在 depth 达到上限时忽略该调用。`swap_read_folio` 嵌套在 `do_swap_page` 内，不能指望这组配置同时给出两层完整分布。log2 直方图本身也不能分辨 2% 的尾延迟变化。
- **原文**：“只给 do_swap_page、swap_read_folio 插桩，并设 max_graph_depth=1”。
- **替换为**：“首选两个独立测量轮次，每次只过滤一个目标函数且 depth=1；需要同轮关联时同时过滤二者并设 depth=2，先验证实际嵌套和入口/返回配对完整。log2 直方图只用于定位数量级；2% 门槛使用原始时长或在判定区间有足够细分辨率的统计。”
- **同轮方案 diff**（本配置 FUNCTION_GRAPH_TRACER=y，接口路径可达；未上板执行）：

```diff
-echo 1 > /sys/kernel/tracing/max_graph_depth
+echo 2 > /sys/kernel/tracing/max_graph_depth
```

- **副作用/测试**：多记一层会增加记录量；用已知嵌套/等待程序检查两层计数、sleep-time、跨 CPU 时钟及丢失，再测 A/A 开销。4.3 其他关于 taskstats、同步 zram、预热控制页的修改正确。

**R12｜一般｜4.2：MEM_ALLOC_PROFILING 不直接给出低端归属，且自身要记账。**

- **依据/问题**：[lib/Kconfig.debug:993 起][kdebug] 选择 PAGE_EXTENSION/SLAB_OBJ_EXT；[alloc_tag.h:18–30][atag] 的计数是调用点总量，不含 zone 维度。本轮 olddefconfig 确认该选项能开启，但不能直接把输出排行当作低端内存排行。
- **原文**：“需要按调用点找出低端内存的主要占用者时，构建一个打开 MEM_ALLOC_PROFILING 的测量内核”。
- **替换为**：“MEM_ALLOC_PROFILING 用于定位分配调用点；低端归属另结合分配器类别和 PFN/zone 采集。单列 page extension、对象扩展及计数器成本，并与未插桩镜像比较压力分布；结论回到正式镜像复验。”
- **测试**：已知 LowMem 与 HighMem 分配用例，验证归属而非只核对总字节；该测量内核不得提供正式收益数。配置可用，暂无必要追加产品代码。

**R13｜阻断｜1.4、4.6：重启与冷启动混用，分段边界尚不能支撑开机验收。**

- **问题**：sdb reboot 是重启，不保证电源冷启动条件；串口第一条日志也不是严格的解压结束。串口传输、缓冲和早期汇编都会影响时间。没有启动器实际标记证据时，不能把两条日志之差直接称为读取+解压。只查 uname/config 不能区分同配置的代码变体。用户态方案还不能沿用“A/B 只差内核”。
- **依据**：4.6 的方法自相矛盾；原始启动参数确有 earlycon，但没有提供可识别读取开始/结束和解压结束的串口样本；这些边界目前**无法核实**。本树构建有 build-id，见 R06。
- **原文**：“多次冷启动由 Codex 通过 sdb 重启”；“以引导加载器开始读取和内核第一条日志……得到读取+解压段”。
- **替换为**：“分别定义软件重启和断电冷启动，两组不得混合；sdb 自动化只提供重启组。冷启动组由现有人工或已授权电源控制流程提供。先保存带实际边界标记的串口样本，校验缓冲和传输误差；标记不足时只报告可观测区间及端到端耗时，不命名为精确读取/解压时间。定位阶段可以增加统一的早期标记，正式 A/B 保持标记、串口和日志量一致。启动完成以同一桌面可交互标记定义，systemd-analyze 作辅助。”
- **另替换部署段**：“内核实验固定用户态；用户态实验固定内核及其他用户态组件，只改变目标组件。每次核对实际运行 build-id、内核/DTB/模块/BTF 配套清单。改变布局的实验同时保存 cmdline 和实际内存边界。”
- **1.4 原文**：“性能、内存……文件大小三项”；“变大约 10%–20%（机制必然）”。
- **替换为**：“副作用表显式列性能、内存、开机时间、文件大小四类；开机按可验证边界报告。LZ4 的映像变化和净开机效果以实际产物及启动链测量，不预设 10%–20% 增幅。”
- **测试**：重复重启与真实冷启动分组；同 release 的两个变体身份校验；日志量变化；网络服务启动并发；计时缺段、桌面标记缺失均不得判通过。

**第 5、6 章：实施依赖与风险**

**R14｜重要｜第 5 章、3.4.4 及 7.3：先建立部署/场景设施，再冻结板上基线；现有重压缩接口不提供硬取消预算。**

- **问题**：0a 要完成修复后的板上基线和标准场景采集，部署与场景脚本却在依赖它的 0b；并行帧指针实验写“前提无”，与 3.1.1 的安全基线要求冲突。0a 的“profiler 能否打开”也不是只读。7.3 仅凭现有接口不能取消已经进入的 sysfs 重压缩调用。
- **依据**：第 5 章依赖表；[zram_drv.c:1944–1995][zram] 同步扫描；当前 [RULES.md](/home/linhao/Toolchain/development/linux_kernel_optimization/docs/RULES.md) 已授权 zram 重配，第 6 章“需补登记”已过时。
- **原文**：“0b……前提 0a”；“0（并行）……前提 无”；7.3“全部使用现有……接口，不改内核”。
- **替换为**：“0a 分成只读盘点/离线安全修复构建；0b 的部署回退调研、场景脚本及统计设施可并行准备。完成部署设施后启动安全修复基线，再做标准场景、A/A 和基线冻结。帧指针的运行及收益比较依赖同一安全基线，只有离线命令/对象验证可先行。profiler 启停列为有记录、可恢复的测量动作。7.3 使用现有接口时只能停止提交后续批次；若要求当前调用的扫描/时间/取消上界，依赖 7.1 或 C1 原型。”
- **3.4.4 原文**：“锁在两页之间释放，影响有限”。**替换为**：“单页处理仍决定一次持锁/不可抢占延迟的上界，须测量压缩、分配及等待各段；分批不能代替单页上界验证。”
- **测试/风险**：冷启动设施不可用时不能宣称某方案已通过全部门槛；验证参数恢复、超时、服务重启和旧任务 ACK。第 6 章直接引用现行 RULES 授权，保留 cmdline、首次部署回退方案的实际限制，不重复申请已经授予的权限。

**第 7 章：逐项核对**

| 项目 | 结论 |
|---|---|
| 7.1 游标与取消 | 方向成立；扫描/尝试/时间三预算必要。取消仍受当前页上界约束；可用 C1 缩小持锁区间。 |
| 7.2 净收益回收 | 归因限定与并发说明正确；先只统计，不能把窗口净变化当成精确逐请求归因。 |
| 7.3 编排 | 状态机合理；当前调用不可取消的问题按 R14 修正。 |
| 7.4 预换入 | MADV_WILLNEED、剩余 minor fault、调用方解压成本的说明正确；不沿用其他平台 50% 的承诺。 |
| 7.5 局部插桩/EHABI | 合理；保持少数对象、正式镜像去插桩和收益去重。 |
| 7.6 mTHP | 可进入受控 PoC；需修正线程成本描述，见 R16。 |
| 7.7 指令集与调度 CPU 分离 | 设计方向正确，最终调优产品 CPU；GCC 对象实验只用于筛选潜力，不证明 Clang 会获得同等收益。 |
| 7.8 BTF 转存 | 已正确限定为低端转移，并计启动副本峰值；保留早期使用者、页归属和只读属性验证。 |
| 7.9 共享只读数据 | 收益推理成立；重复率尚无实测，不预先记入预算。 |
| 7.10 低端压力感知 | 先日志后动作合理；采集应为有时间戳的同轮快照，避免不同时间的 LowFree/CmaFree 拼接。 |
| 7.11 handle 合并 | 当前一句话设计不够，见 R15/C3。 |
| 7.12 冷函数选项 | 可以作为编译器 PoC，但覆盖域和收益公式必须按 R04 改。 |

**R15｜重要｜7.11：槽表已经保存的是 handle 地址，不能直接删除间接层。**

- **问题**：zsmalloc 的 handle 是稳定可寻址单元，内容会因 compaction/迁移改变；对象中还反向保存它。重压缩先分配新对象，再释放旧对象，单个槽不能未经协议同时充当两个对象的 handle。仅查 slab 大小不足以验证可行性。
- **依据**：[zsmalloc.c:352、785、1367、1817–1821][zs]；[zram_drv.c:1812–1829][zram]。cache 合并/对齐还影响节省估算，见 R08。
- **原文**：“把 handle 直接存在 zram 槽表里，去掉 zs_handle slab。”
- **替换为**：“探索由调用方提供稳定 handle 存储单元的新接口，并保留现有用户兼容路径。必须定义对象反向引用、迁移更新、释放及新旧对象切换协议；重压缩的新对象先使用独立临时 handle，提交时在规定锁序下完成重绑定。通过并发正确性实验后，才评估能否移除 zram 的常驻 handle slab。”
- **副作用/测试**：槽表可能变大、VA/页表和临时对象有成本；覆盖压缩整理、物理迁移、重压缩失败、槽复用、同值页、reset、CPU 热插拔及锁序检查。机制细化见 C3，不提供未经实现验证的 zs_malloc_at 伪补丁冒充可用代码。

**R16｜一般｜7.6：只启用小尺寸 mTHP 不必然启动 khugepaged。**

- **依据/问题**：[khugepaged.c:2635–2660][kh] 仅在 `hugepage_pmd_enabled()` 时启动线程。所设计的 PMD 大页关闭、仅 16/32 KiB madvise，不能断言必然增加该线程。
- **原文**：“打开 THP……并增加一个内核线程”。
- **替换为**：“打开 THP 会增加静态代码；khugepaged 线程取决于 PMD 大页是否启用。仅启用小尺寸 madvise 时检查实际线程和水位，不预计该线程必然存在。ARM32 THP_SWAP 关闭与同步 swap-in 的大 folio 路径分别验证，不能互相推导。”
- **测试**：记录各尺寸 sysfs、线程、水位、首次触页、拆分失败以及 zram 每次缺页实际解压页数。这里是成本口径修正，不构成优先推动 mTHP 的理由。

**第 8 章问题的逐条回答**

0. **副作用表尚不完整。** 增加 R13 的显式开机列；R04 的训练扰动、R07 的地址碎片、R08 的低端工作区、R10 的 GC 触页峰值、R15 的临时双对象和 R16 的条件性线程成本。删掉 LZ4 增幅必然为 10%–20% 的断言。四类门槛独立，组合后重验，方向正确。
1. **指标主口径正确，统计程序尚不能冻结。** 物理占用/容量估计已分开，低端指标基本正确；R01 修复 p99 抽样与样本量口径，R02 修复轮次排除。尾部不足就明确无法判定。
2. **区域数据和名义 protection 正确，实际保护估算不能当保证。** 按 R03 修正。vmalloc 补连续地址和碎片；SWIOTLB 补并发 DMA/恢复峰值；SLUB 补合并别名、真实对象步长与前台锁开销。
3. **`-meabi gnu` 条件作为 ARM 模式 PoC 正确。** Kconfig 探测必须带完全相同的关键参数；小程序已验证旧编译器行为及快速实验路径，但新编译器补丁、EHABI 和完整内核仍待验证。DCE 的 mcount KEEP/内建对象限制成立；冷热分组文字按 R05 修正，0043ecea2399 已核实。
4. **不使用 `-fprofile-sample-accurate` 正确；“精确零调用”不可靠。** 按 R04 建立覆盖域，profile 用于热名单和人工候选；缺席保持未知。先用少量可审阅对象验证，收益用最终字节而非函数数估算。
5. **设备级轮次基本完整，异步归还尚缺协议落地。** 当前轮只允许一个 owner，不重置观察窗口的设计正确；明确已进入调用不可硬取消。归还协议补进程实例、代次、迟到 ACK、重启和超时，且不假设能中断 GC/trim，见 R10/R14。
6. **阶段顺序和大多数探索项站得住，需局部修正。** 按 R14 消除 0a/0b 依赖环和帧指针基线冲突；7.11 补 R15/C3 的生命周期协议；7.12 补覆盖和估算规则；其他项目按本报告逐项结论推进。

**第 9 章：来源**

把已核实的 0043ecea2399 补成完整提交链接；下游 `rpi-6.12.y` 浮动链接换为实际源码快照或固定提交。MGLRU-FG/zram 系列状态保留核查日期。产品 BOM、实际机器描述、用户态事件协议、标准场景内存压力和最终优化收益，当前仍有**无法核实**项，不将其列为已经发生的错误。

**二、A 类：对已有方案的实质改进**

| 改进 | 对应问题 | 为什么更好 |
|---|---|---|
| A1：覆盖域清单＋人工 cold 白名单，使用最终符号字节评估 | R04、3.7/7.12 | 保留调用计数价值，避免把早期启动、过滤掉的函数误判为零；不需要先开发新的 profile 转换链。 |
| A2：地址跨度/最大空洞驱动的 vmalloc 逐档试验 | R07、3.3.2 | 不改变用户地址上限即可争取低端容量，但以真实映射可行性约束，成本低于直接 VMSPLIT_2G。 |
| A3：归还协议明确代次、超时和完成状态，native/managed 分开 | R10、3.6.1 | 避免旧 ACK、PID 复用和强制 GC 把前台切换拖进无界等待。 |
| A4：独立单函数测量与真实启动边界先行 | R11/R13 | 先保证门槛能测量，再比较优化；不会用遗漏内层的追踪或重启数据证明冷启动不回退。 |

**三、B 类：有上游依据的新增方案**

以下均不计入承诺收益；只在最小实验显示真实机会时实施。

**B1｜建议｜阶段 1：增加“LZ4 主压缩＋LZ4HC 次级压缩”对照。**

- **做什么/新意**：现有矩阵主要用 zstd 重压缩；增加 LZ4HC，检验能否在降低压缩载荷时保留较快的解压路径。
- **依据**：本树 [backend_lz4hc.c][lz4hc] 使用 LZ4_compress_HC，非字典解压调用 LZ4_decompress_safe；[6.12 zram 文档](https://docs.kernel.org/6.12/admin-guide/blockdev/zram.html)支持多算法重压缩。本配置 LZ4HC_COMPRESS 已为 y，缺的是 zram 胶合后端。相同解码器不保证相同 cycles，压缩流形态仍会影响速度。
- **候选修改**：在 3.4.2 表中新增一行：“LZ4HC 对照｜lz4｜空闲页用 lz4hc，先无字典”。相对实际基线的配置 diff：

```diff
-# CONFIG_ZRAM_BACKEND_LZ4 is not set
+CONFIG_ZRAM_BACKEND_LZ4=y
-# CONFIG_ZRAM_BACKEND_LZ4HC is not set
+CONFIG_ZRAM_BACKEND_LZ4HC=y
-# CONFIG_ZRAM_MULTI_COMP is not set
+CONFIG_ZRAM_MULTI_COMP=y
```

保留原来的 `CONFIG_ZRAM_BACKEND_LZO=y` 和默认 lzo-rle，实验时显式选择算法。本轮 olddefconfig 验证上述三项为 y、FORCE_LZO 自动消失，原默认算法仍保留。
- **收益与前提**：若 300 MiB 候选池经过 size class 结算减少 5%–10%，是 15–30 MiB 毛收益，再减上下文和碎片；这是条件估算，真实结果可能为零。
- **风险/测试**：HC 压缩更慢、上下文更大；比较独立 4 KiB 真页、重压缩 CPU、总物理页、同槽等待、恢复 p99 和开机。即使解压优于 zstd，只要四类门槛不通过仍淘汰。

**B2｜建议｜阶段 1 基线后：核实并抑制无收益的主动内存整理。**

- **做什么/新意**：区分 buddy 的主动 compaction 与 3.6.2 的 zsmalloc compact；后者不能替代前者的成本分析。该板 THP 关闭，但 compaction_proactiveness 实测为 20。
- **依据**：原始 `F_memory_runtime.txt` 第 44–45 行；[compaction.c:75 起、1926、2263 起][compact]；[6.12 sysctl 文档](https://docs.kernel.org/6.12/admin-guide/sysctl/vm.html#compaction-proactiveness)明确允许设 0 关闭主动整理，且提示迁移会制造延迟。
- **候选新增文字**：“只有观测到 proactive compaction 实际消耗 CPU/迁移页时，单独比较 20 与 0；保留直接整理和 CMA 连续分配机制，不全局关闭 COMPACTION。”运行参数候选 diff：

```diff
-vm.compaction_proactiveness=20
+vm.compaction_proactiveness=0
```

这是实验参数清单差异，使用已授权的运行时 sysctl 修改并恢复，不修改产品文件；CONFIG_COMPACTION=y，接口已在原始证据中存在。
- **收益与前提**：上界是实测主动整理 CPU。例如占一核 1% 时，4 核整机总 CPU 的直接上界约 0.25%，尾延迟收益另测；没有主动活动就停止，不宣传固定收益。
- **风险/测试**：可能把整理推迟到 DMA/CMA 或高阶分配关键路径；测试视频缓冲、GPU、USB、长期碎片和恢复，记录分配阶数、失败与最慢延迟；若退化则恢复 20。

**B3｜建议｜阶段 2 小样本预筛、阶段 5 才试产品：可控应用的低写入匿名区短时 KSM。**

- **做什么/新意**：针对多个进程中内容相同但仍需保留写入语义、难以直接改造成 7.9 不可变文件映射的数据，由应用 opt-in MADV_MERGEABLE；空闲窗口扫描，交互期停止扫描并保留已有共享。它不是全堆扫描，也不是 ML 置换。
- **依据**：[6.12 KSM 文档](https://docs.kernel.org/6.12/admin-guide/mm/ksm.html)、本树 [ksm.c][ksm]。KSM 支持匿名页共享和 COW；本轮 Kconfig 验证可开启。
- **候选新增文字**：“先由可控应用测量低写入候选区的重复率与写入频率；只对这些范围试 KSM，排除跨信任域数据。未达到净收益门槛不改产品。”配置 diff：

```diff
-# CONFIG_KSM is not set
+CONFIG_KSM=y
```

- **收益与前提**：200 MiB 候选区若可去重 25%，毛收益 50 MiB；减去 rmap、稳定树、页表及内核代码成本后才是净收益。rmap/slab 会吃紧缺 LowMem；不能仅以全机节省判通过。实际重复率目前无法核实。
- **风险/测试**：扫描 CPU、写时复制 p99、跨进程内容侧信道、换出/换入后的共享变化，以及共享页的 memcg v1 计费归属对 resourced 策略的影响。停止扫描不执行全量 unmerge，避免瞬时内存峰值；测试前台写入、zram 往返、进程退出及低端门槛。如果 7.9 已能用低成本共享同一数据，优先 7.9，不重复部署。

**四、C 类：探索性机制**

下列均为本平台定制 PoC；未核实存在与这里完整机制等价的上游实现，不宣称全球首创，不把估算作为承诺。只补设计，不提供尚未实现/验证的内核 diff。

**C1｜建议｜阶段 5，实质改进 7.1：重压缩“短锁快照—锁外压缩—验证提交”。**

- **问题**：游标与取消只能控制页与页之间；当前一页的解压、慢压缩和新对象分配仍持槽锁，同槽前台读取会被挡住。
- **设计**：在槽锁下取得稳定内容快照到设备工作缓冲，解锁后压缩并分配候选对象；重新加锁，确认槽代次、内容身份、idle 状态及任务代次均未变化才提交。只有一个后台任务时，可先用设备级“活动槽＋修改代次”跟踪，避免每槽新增字段；写入、释放/复用和访问标记路径都必须参与检查。不能仅比较 handle 地址，防止 ABA。取消发生后释放候选；reset 等待任务退出。先不改现有 zcomp 流锁模型。
- **收益粗估**：若实测持锁单页耗时 100 μs，其中 80 μs 为压缩/分配，理想同槽阻塞可从约 100 μs 降到约 20 μs 加提交成本；这只是示例拆账，不是 A72 实测。缓冲/候选为单任务常数成本；原实现本已有部分临时对象，要计算增量。
- **风险**：并发写导致无效压缩，生命周期与锁序复杂；现有 zcomp 仍可能禁抢占，不能声称解决了同 CPU 全部调度延迟。
- **最小实验**：先统计槽锁持有各子阶段及真正发生的前台冲突；无显著冲突就停。随后仅实现一个工作任务，测 ABA、回收/写入并发、取消、reset 和数据校验；压缩锁外仍不能满足门槛再讨论流模型。

**C2｜建议｜阶段 5，实质改进 3.3.1/7.10：对 HighMem 回退建立独立非 CMA 预算。**

- **问题**：全区 protection 混合 CMA 与普通页，阈值只控制偏好；resourced 看到压力后再行动又较迟。调大名义 reserve 可能增加回收，却仍没有明确保护非 CMA 页。
- **设计**：仅针对 HighMem 可移动请求回退 DMA 的路径增加双预算：普通页空闲低于独立保留量时，优先/限定从可迁移 CMA 取页；CMA 不能满足时回到既有 HighMem 回收/失败策略，避免继续吞普通低端页。保持普通 GFP_KERNEL 和必要紧急分配的现有语义；处理 PCP、阶数、水位并发及分配标志，不能只改一个全局 if。它不修改页面 victim 选择。
- **收益粗估**：若基线高压时非 CMA 低谷 8 MiB，目标安全预算 24 MiB，理论上可少被这类回退消耗约 16 MiB；这不是新增 RAM，代价是更多 HighMem 回收或 CMA 借用。与调 ratio 的收益不相加。
- **风险**：提前 OOM、CMA 碎片/迁移成本、分配器热路径开销及不同阶数失效；必须证明不是把故障移到另一类分配。
- **最小实验**：只加按 GFP/区域/迁移类型的观测计数和“若采用双预算会拒绝”的影子判定；若侵蚀主要来自不可移动 slab，立即停止此方案。只有 HighMem 回退占主因才做可开关原型，并与 ratio/threshold 最优组合比较。

**C3｜建议｜阶段 5，实质改进 7.11：调用方持有稳定 handle 单元，并提供事务式重绑定。**

- **问题**：常驻 handle slab 占 LowMem，但直接复用槽表字段破坏迁移和双对象生命周期。
- **设计**：给 zsmalloc 增加可选的调用方存储模式；槽内单元保存对象位置，单元地址成为稳定 handle，对象反向指向它，迁移沿用稳定引用更新。新写入/重压缩先持临时 handle；在槽锁及规定的 zsmalloc 锁序下完成旧对象释放、新对象反向引用与槽单元的原子重绑定，提交前失败保持旧对象。保留原 API 给其他用户；reset 在任务/迁移引用归零后释放槽表。不能让 zsmalloc 迁移反向获取 zram 槽锁形成锁序环。
- **收益粗估**：397,648 个非同值对象、8 B 对象步长约 3.03 MiB 常驻 slab 上界量级；混合 cache 碎片、未满载及对象分布会降低实际可释放页。临时 handle 数按并发写请求计，须扣除。若需要每槽再增加 4 B 字段，会增加约 1.52 MiB 槽表，必须重新算总内存和低端两本账。
- **风险**：跨类 compaction、物理迁移、双对象提交、同值页字段复用和错误回滚；这是协议变更，不是省一次 kmalloc 的小补丁。
- **最小实验**：先解析 slab 别名并测 zram 活对象数/实际页；然后只支持小型测试池的 alloc/map/free/compact，加入两个对象切换和失败注入，再接 zram。若真实低端节省不足 1 MiB 或需要明显扩大槽表，就停止。

**五、最终排序与结论**

**最重要的 5 个问题**：

1. **R01**：p99 的抽样与样本量模型未闭合，可能错误判定不回退。
2. **R13**：sdb 重启被当作冷启动，分段边界没有证据，开机门槛尚不可执行。
3. **R04**：function profiler 覆盖缺口被误当作精确零调用，可能误优化启动/异常路径。
4. **R08**：zram 工作区区域归属、slab 合并和对齐会歪曲紧缺低端内存的成本账本。
5. **R15**：直接删除 zs_handle 间接层没有新旧对象和迁移协议，存在数据完整性风险。

**B 类前三**：B1 LZ4HC 次级压缩；B2 只在观测到实际成本后减少主动 compaction；B3 仅对已证明重复且低写入的受控匿名区试 KSM。B3 的前提最强，不应自动进入产品计划。

**C 类前三**：C3 稳定 handle 与事务重绑定；C2 非 CMA 双预算；C1 锁外重压缩事务。三者分别以低端实际节省、回退侵蚀证据、持锁冲突证据作为进入门槛。

**总体结论：修改后冻结。** 修正 R01/R13 的验收方法，并把重要项的覆盖、归因及生命周期协议写清即可冻结；不需要等探索项获得收益。冻结的是可执行设计和判定规则，不是尚未测得的优化承诺。

[clocksrc]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/kernel/events/core.c:11467
[idle]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/arch/arm/kernel/process.c:71
[pa]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/page_alloc.c:2319
[ftrace]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/kernel/trace/ftrace.c:750
[fgraph]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/kernel/trace/fgraph.c
[lds]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/include/asm-generic/vmlinux.lds.h:553
[mmu]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/arch/arm/mm/mmu.c:1163
[vmalloc]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/vmalloc.c:4998
[lzorle]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/drivers/block/zram/backend_lzorle.c:19
[zs]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/zsmalloc.c:294
[cache]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/arch/arm/include/asm/cache.h:24
[slab]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/slab_common.c:124
[oom]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/oom_kill.c:203
[traceh]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/kernel/trace/trace.h:1056
[kdebug]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/lib/Kconfig.debug:993
[atag]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/include/linux/alloc_tag.h:18
[zram]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/drivers/block/zram/zram_drv.c:1812
[kh]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/khugepaged.c:2635
[lz4hc]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/drivers/block/zram/backend_lz4hc.c
[compact]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/compaction.c:1926
[ksm]: /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi/mm/ksm.c
