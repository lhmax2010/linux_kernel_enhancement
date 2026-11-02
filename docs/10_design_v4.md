# Linux 内核优化设计文档 v4（RPi4 armv7l，6.12.80）

版本：v4，2026-11-02。仓库：`lhmax2010/linux_kernel_enhancement`，本文件位于 `docs/10_design_v4.md`，文中证据链接均相对本目录。v1–v3 保留作历史记录，以本文为准。

**相对 v3 的主要变化**：

- 内存门槛改为两类：无压力场景的不可回收占用，加上压力场景的容量（存活数、换出、refault、查杀）；低端内存分配失败改用 `mm_page_alloc` tracepoint 统计，并剔除试探性失败。
- 统计方法：p99 只在事件足够多时使用；多指标同时通过时按终点数提高每个终点的检出力；加入布局噪声的 A/A；频率校验改为绑核校准循环；候选本身引起的降频在验收组中不得删除。
- 开机时间：软件重启和断电冷启动分成两组；`loglevel=4` 下串口没有内核日志，分段改用引导加载器输出、ARM 通用定时器计数器或统一的测量补丁；部署后用 build-id 核对变体。
- 平台事实修正：模块内存来自 HighMem（模块化加载后低端内存收益仍然成立）；ARM32 不能按页释放线性映射区的只读数据（BTF 转存必须经 init 区）；function profiler 覆盖不了开机阶段，也不能证明“零调用”；lzo-rle 工作区在低端内存；SWIOTLB 池在低端内存；khugepaged 只在启用 PMD 大页时启动；`.text.hot` 不会被 TEXT_MAIN 吞掉。
- 新增方案：LZ4HC 二次压缩、降低主动内存整理、KSM 重复量测量、HZ=250 和完全抢占；第 7 章新增必需但不热的子系统模块化、首次执行位图训练内核、kallsyms 转存、锁外重压缩、非 CMA 独立预算，并补全 zs_handle 的生命周期协议。
- 实验计划：阶段 0 拆为 0a（只读盘点和离线修复）、0b（部署和测量设施）、0c（建立并冻结基线），去掉循环依赖。

## 0. 文档说明

**目的**：按 2027 年度计划落地 Linux 内核优化，目标是提高性能、降低内存。本文给出现状基线、候选方案、测量方法、实验顺序和通过门槛，作为后续实现的依据。设计冻结前不开始实现。

**范围**：

- 开发和验证平台：RPi4（Tizen 11，armv7l，内核 6.12.80），它是 TV 产品的替身板。凡涉及产品取舍（功能裁剪、调试能力保留、地址空间划分）的结论，都需要在产品级开发板上复核。
- 产品板主要是 armv7l，目前没有 aarch64 产品板，因此本项目以 armv7l 为主。aarch64 的工作（包括内核 BOLT）放到 armv7l 之后，只在 RPi4 的 aarch64 镜像上做可行性验证。
- 基于机器学习的页面置换和内存回收由另一位同事负责，不在本文范围内。除单列的 MGLRU-FG 对照研究（3.5.2，非机器学习的上游回收算法）外，本文的回收协同方案不修改页面置换（victim 选择）机制；MGLRU-FG 与另一工作线分别建立基线、分别评估，组合时重新验收。
- 改动对象可以是内核、LLVM/GCC 工具链、glibc/musl、resourced 等用户态组件。与应用生命周期相关的用户态内存管理也纳入评估（见 3.6）。
- 内存收益分三个口径报告：全机物理占用、低端内存压力、内核虚拟地址空间占用。不能用全局 MemAvailable 代替低端内存的验收；MemAvailable 是容量估计，不是物理占用（见 1.2）。

**基线代码**：Gerrit 分支 `sandbox/lhmax2025/kernel_optimization`，提交 `0fac5de6`。相对 tizen 主线 `42aeefac` 只多两个提交：force_reclaim 修复、启用 ARM_PMUV3。本项目所有内核改动只推送到这个分支。

## 1. 目标与约束

### 1.1 总体约束

| 项目 | 内容 |
| --- | --- |
| 总目标 | 在不损失产品功能的前提下降低内存占用、提升性能 |
| 不回退原则 | 每个方案都必须同时保证性能、内存、开机时间不回退，不能用一项的收益抵消另一项的回退；副作用必须实测，不以推理代替。文件大小不设门槛，但任何变大都要在报告中写明。见 1.4 |
| 不回退容差 | 性能和开机时间 2%，内存 3%（与年度计划一致）。这表示“在该容差下证明不回退”，不等于证明严格零回退。指标和分母见 1.2，判定方法见 1.3 |
| 改动粒度 | 每项单独分支、单独补丁、单独报告；组合后重新验收 |
| 证据要求 | 每个结论附 文件:行号、命令输出或日志；估算值必须标明“估算” |
| 板上操作 | 按 RULES.md 执行：三项身份断言；`/tmp` 挂载为 noexec，需要执行的临时程序放在 `/opt/usr` 下的任务专用目录，用完删除。常规授权（不需要逐次申请）：临时推送 perf（第 1 项）；修改 `/proc/sys`、`/sys` 下的运行时参数，修改前记录原值、结束后恢复并回读（第 2 项）；zram 运行时重配（第 3 项）；通过 sdb 重启，超时 10 分钟就停下报告（第 4 项）；为开机配网服务做一次安装（第 5 项）；只替换内核（第 6 项）。修改启动参数（boot 分区的命令行）不在常规授权内，通过镜像或由用户执行。实验期间独占板子。resourced 等用户态组件的改动通过 QB 镜像，由用户烧写。标准场景需要安装测试应用（写 /opt 分区），是否纳入常规授权待用户确认 |

### 1.2 回退判定的指标与分母

**必验指标**：每个候选都必须验收五类指标：开机时间、关键场景延迟、无压力场景的不可回收占用、压力场景的内存容量、非 CMA 低端内存。文件大小必须测量并报告，但不作为通过条件。其他指标在实验开始前预登记，未预登记的只作解释。本文“最慢 1%”统一指 p99，计算条件见 1.3。

| 类别 | 指标 | 分母（基线值） | 容差 |
| --- | --- | --- | --- |
| 开机时间 | 开机到桌面的总时间，以及能被可靠标记的分段（方法和组别见 4.6） | 同一镜像其余部分不变时的基线 | 总时间和各可观测分段，比值的单侧 95% 置信上界 ≤ 1.02 |
| 性能（固定工作量的耗时） | 每个关键场景的应用切换耗时、冷启动耗时（中位数与 p99）；换入延迟 p99 | 同一场景下基线内核的同一指标 | 比值的单侧 95% 置信上界 ≤ 1.02 |
| 性能（固定时间的完成量） | 固定时间内的有效完成量 | 同上 | 比值的单侧 95% 置信下界 ≥ 0.98 |
| 不可回收占用（无压力场景） | 内核保留页 + SUnreclaim + KernelStack + PageTables + 驻留匿名页 + Shmem + Unevictable + zram 物理成本（3.4.3）；文件缓存和可回收 slab 单列，只用于解释 | 同一场景、同一存活应用集合下的基线值 | 比值的单侧 95% 置信上界 ≤ 1.03 |
| 内存容量（压力场景） | 固定应用轮换脚本下的后台存活应用数；pswpout 与匿名 refault 次数；resourced 和内核的查杀次数 | 同上 | 存活数比值的下界 ≥ 0.97；pswpout、refault、查杀次数比值的上界 ≤ 1.03 |
| 非 CMA 低端内存 | 场景中非 CMA 低端空闲量的低谷 = LowFree − CmaFree（本板 CMA 全在低端内存）；SUnreclaim；allocstall_normal；低端内存页分配失败次数（方法见下） | 同上 | 空闲低谷比值的单侧 95% 置信下界 ≥ 0.97；判定类分配失败不增加；allocstall_normal 不超出 A/A 噪声范围 |
| 文件大小（只报告） | zImage、vmlinux 常驻段、模块总大小、内核 RPM 包大小、boot 分区占用、启动日志 `Memory:` 行；改用户态组件或工具链时，相应包和二进制的大小 | 基线构建 | 不设容差；任何变大都要在报告中写明字节数和原因 |

**口径说明**：

- **无压力场景的定义**：场景期间 PSI memory 的 some.avg10 始终为 0，且 pgscan 增量为 0。有压力时“物理内存总量 − 空闲页”会一直贴着水位线，看不出节省；没有压力时它又包含可回收的文件缓存，减轻内存压力的改动可能因为留下更多页缓存而显示为“占用增加”。所以不用“总量 − 空闲”作判定，改用上表的两类指标。阶段 0b 用两个已知扰动校验它们：常驻分配 16 MiB 匿名内存，不可回收占用应上升；只增加文件缓存，不可回收占用应不变。
- **MemAvailable 是容量估计，不是物理占用**。它会减去内核保留页（`totalreserve_pages`），调整 lowmem_reserve_ratio、水位、vmalloc 区或地址空间划分时会直接变化。例如 ratio 从 256 改为 32，名义保护增加约 87 MiB，MemAvailable 随之下降，但这不是驻留增加。MemAvailable 单列报告，并注明口径变化。
- **不用 LowTotal − LowFree 判定低端内存**：内核静态映像变小时，LowTotal 和 LowFree 同时增加，差值不变，看不到静态收益；它还把 CMA 借用和普通内核分配混在一起。
- **不用 allocstall_dma**：GFP_KERNEL 分配的直接回收按其目标区计在 allocstall_normal 上（即使 Normal 区为空），allocstall_dma 在本板基本恒为 0。HighMem 档的计数名是 allocstall_high。
- **低端内存页分配失败的计数方法**：`__alloc_pages_noprof()` 无论成功失败都会触发 `kmem/mm_page_alloc` tracepoint（`mm/page_alloc.c:4862`），失败时 pfn 为 -1（32 位下为 4294967295），事件带 gfp_flags、order、migratetype。在 tracefs 中按 `pfn == 4294967295` 过滤即可，不需要 kprobe（ARM32 没有 HAVE_FUNCTION_ARG_ACCESS_API，返回探针里拿不到 gfp 和 order）。判定只统计不带 `__GFP_NORETRY`、`__GFP_NOWARN`、order ≤ 3、可用区最高为 Normal 的失败；其余（试探性的高阶分配、zsmalloc 第一次不带直接回收的尝试等）单列报告。这个 tracepoint 每次页分配都要做一次过滤判断，开销先用 A/A 测出，只在诊断轮次打开，不在验收轮次常开。
- **cycles、instructions 按工作量归一，只用于解释**；CPI 不单独作为通过条件。需要把某项 CPU 成本（例如 kswapd CPU）作为硬门槛时，事前写明计量对象、归一化分母和容差。

功能、安全性、崩溃和数据完整性不适用上述容差，出现问题即判失败。

### 1.3 统计判定

- **统计单元**：一次独立的场景轮次（独立启动或独立的一轮固定场景）。所有指标（包括 p99）的主分析都保留完整轮次和轮内事件的顺序，以预定义的 A/B 配对块为单位做重抽样（bootstrap），计算候选/基线比值的置信区间。固定流程中的连续事件有相关性，只有在验证过轮内抽样模型之后，才采用二级抽样或连续块抽样。
- **p99 的使用条件**：合并后的事件数不少于 1,000（超过 p99 的事件不少于 10 个）时，p99 才作为判定指标；不满足时改用 p90，并在实验计划中预登记。bootstrap 生成不了样本中从未出现过的尾部事件，尾部证据不足时报告“无法判定”。
- **多指标同时通过**：每个变体在计划中预登记必验终点数 k。全部终点都要通过时，一个真正中性的变体整体通过的概率约为每个终点检出力的 k 次方（每个终点 80%、k=10 时只有约 11%）。所以每个终点的检出力按 0.8^(1/k) 设计（k=10 时约 97.8%）。终点太多、轮次超出板时间预算时，把部分终点降为“安全监测”（点估计不超过容差、并且没有显著回退即可），在计划中写明。
- **样本量**：由 A/A 试跑决定，包括轮次数和每轮事件数：用 A/A 测得的相关结构、尾部事件数和模拟的置信区间覆盖率来定，配对指标用配对差异的方差。“每组约 12.4 ×（变异系数 / δ）² 轮”只是独立两组均值、单终点 80% 检出力下的粗略工时估计（变异系数 3% 时约 28 轮），不用于配对指标或 p99。每组预登记轮次上限（例如 40 轮），达到上限仍为“证据不足”的，记为“无法证明不回退”，不再加跑。
- **分层验收**：单板时间有限，先用低噪声指标筛选（静态段、按工作量归一的内核态 instructions 和 cycles、微基准），未通过就停止；只有入围的变体才跑完整的墙钟轮次。
- **布局噪声**：改变代码布局的方案（死代码消除、配置裁剪、链接脚本、编译器参数、栈保护修复），会因为函数对齐、缓存组映射和分支预测别名的变化，产生与改动本身无关的约 1% 量级的性能波动。A/A 中加入“布局扰动”的同功能构建（改变链接顺序或插入填充），测出布局噪声，计入判定阈值。
- **停止规则**：实验前预登记最大样本量和检查时点。需要追加时，使用预定的序贯方法，或重新做一次独立的确认实验；禁止无上限地采样直到通过。判定程序先用模拟数据检查：0%、1%、3% 回退；中位数相同但 p99 恶化；少数坏轮次；相关的突发事件；离散和并列的延迟值；吞吐下降 3%；cycles 减少而 CPI 增加；缺少一个必选场景；10 个终点都没有真实差异时的整体通过率。确认置信区间覆盖率和误判通过率符合设计。
- **低噪声佐证**：代码生成和体积类变体，同时报告按工作量归一的内核态 instructions 和 cycles（perf stat 计数），用来佐证墙钟指标的结论，不代替墙钟指标。
- **执行顺序**：A/B 随机交错执行，避免温度、时间漂移带来的偏差。
- **判定**：置信区间跨越容差边界时判为“证据不足”，按停止规则处理，不按通过处理。每个关键场景单独过门槛，多个场景的平均值不能掩盖单个场景的回退。
- **频率**：受控频率组（performance 调频策略）用于筛选和归因；默认 schedutil 组用于产品验收，只对入围变体执行，判定以 schedutil 组为准。RPi4 的过热和欠压降频由固件执行，cpufreq 不一定反映出来。系统范围的 `cycles / cpu-clock` 不是频率：cpu-clock 按墙钟计时、包含空闲时间，CPU 空闲执行 WFI 时周期计数不增加，两者之比实际是“利用率 × 频率”。所以每轮开始和结束时，在每个 CPU 上各跑一次约 100 ms 的绑核纯计算校准循环，用同一作用域的 `perf stat -e cycles,task-clock` 算出有效频率，并读取 `thermal_zone0/temp`；校准循环不计入业务计时，前后留固定的冷却间隔。校准值低于锁定频率 98% 的轮次，在受控频率组中按预登记规则作废重跑（规定最大重试次数）；但由候选本身引起的持续发热或降频是实验结果，在 schedutil 验收组中不得删除。
- **训练与验收分离**：凡是用场景数据做优化的方案（采样驱动优化、预换入等），训练用的场景和验收用的场景必须分开。每份 profile 和统计结果记录它对应的基线 build-id；基线变化（栈保护、帧指针、配置、布局）后重新核对对应关系。

### 1.4 不回退与副作用检查

- 每个方案的实验计划都要先填一张副作用表：性能、内存（不可回收占用、容量、非 CMA 低端内存、峰值）、开机时间、文件大小四类，各写出预期方向、可能的副作用机制和测量方法。实验报告逐项给出实测结果。
- 性能、内存、开机时间各自独立过门槛（1.2），一项的收益不能抵消另一项的回退；文件大小不设门槛，变大时在报告中写明。组合多个方案后重新验收。
- 机制上必然造成性能、内存或开机时间回退的方案，不进入计划，只作记录，除非用户另行决定。
- 只用于测量的内核和工具（追踪、MEM_ALLOC_PROFILING、插桩训练镜像等）不得进入产品镜像，也不提供正式收益数字。

已识别的副作用及处理：

| 方案 | 可能的副作用 | 处理 |
| --- | --- | --- |
| 所有改变代码布局的方案（死代码消除、配置裁剪、链接脚本、编译器参数、栈保护修复） | 与改动无关的约 1% 量级的布局噪声，容易被误当作收益或回退 | 按 1.3 的布局扰动 A/A 计入判定阈值 |
| 内核映像 LZ4 压缩（3.1.6） | 映像文件变大，读取时间增加可能抵消解压收益；增幅以实际产物为准 | 开机时间必须不回退；文件变大在报告中写明 |
| 小尺寸透明大页（7.6） | 驻留放大；THP 代码增加内核体积 | 内存（含峰值）必须通过，预计较难满足，最低优先级；内核体积变大在报告中写明 |
| 切回前台前的预换入（7.4） | 峰值驻留增加；与 UI 争 CPU | 内存峰值和切换延迟都必须通过；预算按通过门槛来定 |
| BTF 和 kallsyms 转存到 HighMem（7.8、7.15） | 启动时短暂多一份数据；少量映射开销；初始化时多一次复制 | 全机物理占用、启动峰值和开机时间必须通过，否则放弃 |
| 跨应用只读数据共享、KSM（7.9、3.6.3） | 映射和索引开销；KSM 的 `ksm_rmap_item` 位于低端内存的 slab；扫描 CPU；合并页写时复制 | 净物理占用必须下降，非 CMA 低端内存和延迟不回退 |
| zram 换用 zstd、LZ4HC 或二次压缩（3.4） | 解压变慢、CPU 增加；新后端增加少量内核代码；开机时多分配压缩上下文 | 换入 p99、切换耗时、kswapd CPU、开机时间必须通过；代码增量在报告中写明 |
| LZ4 库升级与快速解压补丁（3.4.2） | 修改的是共用的 lib/lz4 解压器，影响不限于 zram：F2FS 压缩（本配置 F2FS_FS_LZ4=y）、EROFS（EROFS_FS_ZIP=y）、crypto API、initramfs 的解压都会走它 | 增加文件系统读取对照；阶段 0a 确认 /opt/usr 的 F2FS 是否启用压缩 |
| 跨区保护、vmalloc 区、SWIOTLB、SLUB 保留（3.3） | 更早回收、分配失败、锁争用和 CPU 成本；提高 reserve 后 kswapd 可能运行更久 | 延迟、p99、分配失败、kswapd CPU 都必须通过 |
| vmalloc=、VMSPLIT_2G（3.3.2、3.3.3） | 低端内存变大后 min_free_kbytes 和各区水位自动重算，回收行为随之改变；VMSPLIT_2G 还会把 mmap 随机化位数上限从 16 降到 15 | 报告前后的 min_free_kbytes 和各区水位；ASLR 熵下降写入安全说明 |
| 用户态主动归还（3.6.1） | 归还后再次缺页、锁停顿；GC 或 trim 触碰已换出页造成峰值；与前台抢 CPU | 切回前台的首帧时间和 p99 必须通过；归还在后台低权重执行，推迟到前台首帧之后 |
| 链接期死代码消除及链接脚本修正（3.1.4） | 分段和对齐开销可能使体积不降反增；修正后的链接脚本在热代码前增加至多一页对齐填充 | 常驻内存必须不回退；体积变化和填充字节在报告中写明 |
| 冷代码按体积优化（3.7） | 冷函数误判导致长尾回退；开机时只执行一次的代码被当成冷代码，开机会变慢；训练用的 profiler 本身改变调度和覆盖 | 未训练场景的 p99 和开机时间必须通过；覆盖不到开机阶段时，开机路径一律保持原优化等级（3.7） |
| 改为模块的项（3.2、7.13） | 本平台模块内存来自 HighMem，加载后低端内存收益仍然成立；但模块代码用 4 KiB 页映射，热点代码改为模块会增加 iTLB 缺失；开机时加载模块会拉长开机；每个模块的段按页取整 | 热点代码不改为模块；开机时间必须通过；改为模块的冷代码单独测该子系统的性能 |
| Btrfs 改为模块（3.2） | 如果 btrfs-progs 的 udev 规则在开机时扫描设备，会自动加载 btrfs 模块，既抵消全机节省又拉长开机 | 阶段 0a 只读检查 btrfs 的 udev 规则；改为模块后确认开机后 lsmod 中没有 btrfs |
| TRIM_UNUSED_KSYMS（3.1.7） | 构建要做两遍，构建时间增加；树外模块需要白名单 | 构建时间单列报告 |
| 关闭 KALLSYMS_ALL（3.2） | perf、BPF 和崩溃分析中，内核数据符号无法解析 | 作为产品取舍，列入功能检查 |
| HZ=250、完全抢占（3.8） | 时钟中断增加，吞吐可能下降；抢占计数的开销使内核吞吐下降，可能超过 2%；驱动中隐藏的抢占假设暴露 | 吞吐类指标和开机时间必须通过；完全抢占另做一次开启 DEBUG_PREEMPT 的诊断构建 |
| 降低主动内存整理（3.3.7） | 整理工作推迟到 DMA、CMA 或高阶分配的关键路径上 | 视频缓冲、GPU、USB 的分配延迟和失败必须通过 |
| 编译器改动（帧指针、调度 CPU、栈保护） | 影响全部内核代码，包括开机路径 | 开机时间必须通过 |
| 栈保护修复（3.1.2） | canary 读取方式改变，性能可能小幅变化，体积可能变化 | 是安全修复，不是优化；性能、内存、开机时间照样测量，有回退时列出数值由用户决定；体积变化在报告中写明 |

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

### 2.3 低端内存结构

| 项目 | 实测值 | 说明 |
| --- | --- | --- |
| DMA 区 | present 196,608 页，managed 177,991 页（约 695 MiB） | 全部低端内存都在 DMA 区，原因待确认。RPi 内核的 BCM2711 机器描述设置了 `dma_zone_size = SZ_1G`；但 BCM2835 机器描述的兼容列表也包含 `brcm,bcm2711`，并且排在前面，按内核的匹配规则，实际很可能用的是 BCM2835 描述。它没有设 DMA 区大小，此时 DMA 区同样覆盖全部低端内存（`arch/arm/mach-bcm/board_bcm2835.c`）。阶段 0a 读板上 `/proc/cpuinfo` 的 Hardware 行和启动日志的 Zone ranges 确认 |
| Normal 区 | 0 页 | 空 |
| HighMem 区 | 816,128 页（约 3,188 MiB） | — |
| LowTotal / LowFree | 711,964 KiB / 576,092 KiB（静置） | — |
| CMA | 320 MiB，物理地址 0x1ac00000–0x2ebfffff（428–748 MiB），整体位于低端内存，约占低端内存的 46% | 非 CMA 的低端内存约 711,964 − 327,680 = 384,284 KiB（约 375 MiB）；静置时非 CMA 部分空闲约 576,092 − 268,452 = 307,640 KiB（约 300 MiB）。CMA 是迁移类型和保留池，不是独立的区 |
| Vmalloc | VmallocTotal 245,760 KiB，VmallocUsed 21,208 KiB | vmalloc 地址空间位于内核虚拟地址区，32 位下总量有限 |
| SWIOTLB | 启动参数 `swiotlb=8192`，每槽 2 KiB，名义数据池 16 MiB；SWIOTLB_DYNAMIC 未开 | 池由 `memblock_alloc_low()` 分配，位于低端内存（`kernel/dma/swiotlb.c:334`）；使用高水位见 debugfs 的 `io_tlb_used_hiwater`；是否有存储 I/O 经过回弹待测 |
| 物理 RAM 布局 | `/proc/iomem`：`00000000-3b3fffff` 和 `40000000-fbffffff` 两段 | 低端内存只能来自第一段（末尾在 948 MiB），这限制了 3.3.2 的可调范围 |

**跨区保护的名义值较小**：`lowmem_reserve_ratio` 为 `256 32 0 0`。由于本板低端内存全部在 DMA 区，实际生效的是 DMA 档的 256：

- 名义保护 = 816,128 / 256 ≈ 3,188 页 ≈ 12.5 MiB；改为 64 约 49.8 MiB，改为 32 约 99.6 MiB。
- 这只是名义值。空闲的 CMA 页也计入可移动分配的水位检查，本树还有树莓派下游的 `alloc_in_cma_threshold`（只决定可移动分配何时优先从 CMA 取页），所以名义保护不能保证等量的非 CMA 空闲。评审方在特定平衡假设下推算现在约 4 MiB、改为 32 后约 26 MiB，这只是示意，不是保护下限；不可移动分配、每 CPU 页缓存、不同阶数和持续的 CMA 消费下情况都不同，以实测分布为准。
- `min_free_kbytes` 只有 3,334 KiB，它只按低端内存大小计算。
- 静置时非 CMA 部分仍有约 300 MiB 空闲，尚未证明标准场景中发生了低端内存压力。需要用标准场景下的非 CMA 空闲低谷、回收次数和分配失败来证明。

**哪些分配占低端内存**：内核静态映像、slab 以及需要直接映射的分配（例如 `kzalloc`，当前 lzo-rle 的压缩工作区就是这样分配的）消耗低端内存。经 vmalloc 分配的内存（包括模块的代码和数据）允许来自 HighMem。本配置 VMAP_STACK=y，内核栈通过 vmalloc 分配，底层页允许来自 HighMem；网络缓冲要区分 skb 元数据、线性区和 page frag；HIGHPTE=y 主要放宽用户 PTE 页的分配。zram 载荷带 `__GFP_HIGHMEM`，允许使用 HighMem，也可能用到可移动的 CMA 页，实际分布要统计，不能只从 GFP 标志推定。

**对优先级的影响**：内核静态节省直接增加 LowFree，按低端内存收益计算；以 BTF 为例，它约占非 CMA 低端内存的 1.7%。运行时方案的排序以标准场景下实测的低端内存压力为准。

证据：[板上内存原始输出](../evidence/task5/A_identity_memory.txt)（含启动日志中 CMA 池地址和启动参数）、[运行时参数](../evidence/task5/F_memory_runtime.txt)。

### 2.4 采样能力边界

| 能力 | 结论 | 对方案的影响 |
| --- | --- | --- |
| 硬件计数、cycles 采样 | 可用 | 能拿到函数级的耗时热度 |
| 分支栈 | 不支持（Cortex-A72 是 ARMv8.0，在 AArch32 和 AArch64 下都没有分支记录硬件；BRBE 从 ARMv9.2 起才有） | 拿不到跳转边和基本块计数 |
| ETM/CoreSight | 板上没有设备；perf 也没有编入 libopencsd | 无法用指令追踪替代 |
| PMU 中断 | 本板 PMU 使用普通 IRQ，没有可用的 PMU NMI 路径 | 关中断期间的溢出中断会延迟交付，样本落到开中断之后的位置，采样 IP 不能代表关中断区间。“没采到”不等于“冷” |
| function profiler | FUNCTION_PROFILER=y；本配置 FUNCTION_GRAPH_TRACER=y，它注册的是 graph 回调，既计数也累计时间 | 对已插桩、已启用且实际覆盖的函数给出调用计数，不依赖 PMU 中断，能补充部分关中断路径；但只能在开机后打开（没有对应的启动参数），继承全局 ftrace 过滤器，记录分配失败、graph 栈深度限制、未加载的模块、notrace 和内联函数都会造成覆盖缺口，输出也不为没被调用的函数建立零记录。所以它不能证明“零调用”。开销大，只用于训练 |
| llvm-profgen 22.1.8 | 读 perf script 时只接受带 LBR 的输入，只有指令地址的样本报 “Invalid perf script input!” | 现有流程不能直接用 |

证据：[llvm-profgen 源码（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/llvm/tools/llvm-profgen/PerfReader.cpp) 的 `PerfReaderBase::create()` 与 `checkPerfScriptType()`；[QB 最终配置](../evidence/task5b/qb_arm-rpi4.config)。

## 3. 候选方案

分组：编译器与代码体积（3.1）、配置裁剪（3.2）、低端内存（3.3）、zram（3.4）、MGLRU（3.5）、用户态协同（3.6）、采样驱动优化（3.7）、调度参数（3.8）、不做的项（3.9）。探索性方案见第 7 章。收益都是估算，以实测为准。

### 3.1 编译器与代码体积

#### 3.1.1 ARM 上 -pg 强制帧指针

**依据**：

- Kbuild 在启用 FUNCTION_TRACER 时不加 `-fomit-frame-pointer`（顶层 `Makefile:847–861`），并给所有文件加 `-pg`。
- Clang 22.1.8 在有 `-pg` 且没有 `-mfentry` 时默认保留帧指针（`clang/lib/Driver/ToolChains/CommonArgs.cpp:73`）；显式写 `-fomit-frame-pointer` 时，`getFramePointerKind()` 会得到“不保留”，随后 `Clang.cpp:8069–8072` 报错。ARM 没有 `-mfentry`。
- GCC 在 ARM 上用 `-pg` 时不强制帧指针，GCC 版内核建立帧指针的指令只有 1,741 处。
- 实测：LLVM 内核建立帧指针的指令有 59,969 处（约 232,912 B）；外部展开记录从 1,096 条增加到 43,526 条，其中 43,495 条用 r11 恢复栈，这是 unwind_tab 增长约 0.5 MB 的直接原因。unwind_idx 的 +0.12 MB 与函数数量有关，不一定随帧指针消失。

**mcount 调用约定**：Clang 只在传了 `-meabi gnu` 时才使用 `__gnu_mcount_nc`（调用前把 lr 压栈，不依赖帧指针），否则使用旧式 `mcount`，后者靠帧指针取调用者地址（`clang/lib/Basic/Targets/ARM.cpp:326–330`）。内核在 `arch/arm/Makefile:123` 传了 `-meabi gnu`，所以下面的讨论只对带 `-meabi gnu` 的编译成立。

**安全性**：当前配置是 ARM_UNWIND=y、UNWINDER_FRAME_POINTER=n。ftrace 插桩序列 `push {lr}; bl __gnu_mcount_nc` 不使用 r11；function_graph 的 `prepare_ftrace_return()` 在这个配置下通过 EHABI 的 `unwind_frame()` 找返回地址槽（`arch/arm/kernel/ftrace.c:227–270`）；oops 回溯和 perf 内核调用栈也用 EHABI 表。只要编译器为新的栈布局生成正确的展开记录，省略帧指针在机制上可行。但这仍须实测验证，不能直接宣布安全。perf 的用户态调用栈与内核调用栈机制不同，要分开验收。

**方案（决策顺序）**：

1. 如果产品内核可以不要函数追踪，关闭 FUNCTION_TRACER（3.2），本项随之消失，不需要编译器改动，还能再省 `-pg` 插桩约 0.43 MB。
2. 如果产品需要保留函数追踪，就需要编译器和内核两边配合，改动范围限定为“只有内核显式选择才生效”：
   - **编译器**：Clang 只取消“ARM Linux 目标、带 `-meabi gnu` 时，`-pg` 与显式 `-fomit-frame-pointer` 同时出现”的报错，`-pg` 的默认行为不变；不带 `-meabi gnu` 的普通用户态 `-pg` 程序仍然报错，避免旧式 mcount 读到无效的帧指针。示意（以实际源码为准）：

     ```diff
     --- a/clang/lib/Driver/ToolChains/Clang.cpp
     +++ b/clang/lib/Driver/ToolChains/Clang.cpp
       if (Arg *A = Args.getLastArg(options::OPT_pg))
         if (FPKeepKind == CodeGenOptions::FramePointerKind::None &&
     -        !Args.hasArg(options::OPT_mfentry))
     +        !Args.hasArg(options::OPT_mfentry) &&
     +        !(Triple.getArch() == llvm::Triple::arm && Triple.isOSLinux() &&
     +          Args.getLastArgValue(options::OPT_meabi) == "gnu"))
           D.Diag(diag::err_drv_argument_not_allowed_with) << "-fomit-frame-pointer"
                                                           << A->getAsString(Args);
     ```

   - **内核**：在 `arch/arm/Kconfig` 中新增一个探测符号，用 `-meabi gnu -pg -fomit-frame-pointer` 一起探测编译器是否接受；只有在 CC_IS_CLANG、ARM_UNWIND=y、THUMB2_KERNEL=n、探测通过时，才在 FUNCTION_TRACER 打开的情况下追加 `-fomit-frame-pointer`。这样旧编译器、GCC 构建和其他架构都不受影响。
   - 这是平台 PoC 形态，不是可直接上游的通用修复。上游版本需要另外处理 Thumb、其他 profiling 运行时和 ABI 说明，届时再考虑与 GCC 的默认行为对齐。

**先做快速实验**：改编译器之前，先用 `-Xclang -mframe-pointer=none` 构建一次实验内核（直接给编译器前端传参，绕过驱动的报错，不改 Clang），测出真实的体积和性能收益，再决定是否值得修改 Clang。实验必须核对真实内核对象的最终编译命令、IR、反汇编和 EHABI，不能以“驱动接受了参数”代替运行正确性验证；先固定栈保护修复后的基线，再比较帧指针变体，避免两种序言变化混在一起。

**预期收益**（LLVM 普通版，估算）：帧指针建立指令约 0.23 MB，unwind_tab 约 0.5 MB；r11 释放为通用寄存器后，还可能带来额外的 .text 和性能变化，另行测量；实际能收回多少由消融构建决定，不承诺全部收回。关闭 FUNCTION_TRACER 的收益不能与本项直接相加。

**风险**：展开记录错误会导致回溯失败或 function_graph 崩溃；使用独立版本的工具链做实验，不影响平台其他包。

**验证**：

- Clang 驱动的正负用例：默认 `-pg` 行为不变；显式省略只在 ARM Linux 且带 `-meabi gnu` 时生效；同一命令去掉 `-meabi gnu` 后仍然报错；x86、Thumb 没有被意外放开。评审方已用平台 Clang 的小程序确认：GNU EABI 下 mcount 名称不变，`-Xclang -mframe-pointer=none` 去掉了 frame-pointer 属性，旧 Clang 对显式 `-pg -fomit-frame-pointer` 仍报错。这只支持进入 PoC，不证明 EHABI 和 ftrace 已经安全。
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

当前补丁作为平台修复（CPU_32v7=y、CPU_32v6 未启用、ARM 模式），已由评审方在本配置上核验：探测生效，最终 STACKPROTECTOR_PER_TASK=y。提交上游前，另完成 GCC/Clang、ARMv6/v6K/v7、Thumb2 和多平台组合的参数与代码生成矩阵。不要手工把这个隐藏的能力符号强写成 y。

**验证**：

- GCC/Clang 两边 olddefconfig 后的配置比较；最终 STACKPROTECTOR_PER_TASK=y。
- 反汇编确认 canary 通过 `mrc p15, 0, …, c13, c0, 3`（TPIDRURO）按 task 偏移读取，不再读 `__stack_chk_guard`。
- 用测试模块打印两个线程的 `stack_canary`，确认值不同；实验镜像临时启用 LKDTM 跑栈保护用例；SMP 下的任务切换压力测试。
- 体积变化记录在案，作为新基线的一部分。

#### 3.1.3 局部内联膨胀

**依据**：rt2800lib 一个对象就比 GCC 多 332,772 B，r8152 多 43,216 B，主要是寄存器读写辅助函数被大量内联，外加自动初始化的存储。这些驱动在 RPi4 上都没有绑定设备。四个已分析对象只占 `.text` 净增量的约 19%，“与内联相关”也不等于纯内联贡献。

**方案**：优先用 3.2 的配置裁剪（改成模块或关闭）。对确实要保留的驱动，先按对象比较 O2 与 Os（例如 `CFLAGS_REMOVE_rt2800lib.o += -O2`、`CFLAGS_rt2800lib.o += -Os`），检查具体辅助函数的内联收益，通过功能和性能测试后再扩大范围。MLGO 内联体积模型（用户分支 `sandbox/lhmax2025/mlgo` 已有内核接入）作为后续实验，记录模型、目标架构和实际启用参数。自动初始化和栈保护不变。

**验证**：确认 `.cmd` 文件中的最终编译参数；对象和全内核体积；保留的驱动在对应设备上测连接、恢复、吞吐、CPU 和栈峰值（RPi4 没有绑定设备，不能代替这项测试）。

#### 3.1.4 链接期死代码消除

**依据**：ARM32 已支持 LD_DEAD_CODE_DATA_ELIMINATION（本树 `arch/arm/Kconfig:121`，要求 LLD 或新版 GNU ld，并要求 LD_CAN_USE_KEEP_IN_OVERLAY）。QB 最终配置中 HAVE_LD_DEAD_CODE_DATA_ELIMINATION=y、LD_CAN_USE_KEEP_IN_OVERLAY=y、EXPERT=y，选项可选但没有打开。上游提交 ed0f94102251（v6.11）已核实，本树带有后续修复；它给出的 2.0%、2.7%、3.2% 是 zImage 大小（tinyconfig 为 29.7%），不是本配置的常驻段。

**本配置下的限制**：

- FUNCTION_TRACER 打开时，`__mcount_loc` 段以 KEEP 保留，它的重定位会把所有插桩函数都钉住，函数级消除可能很少。
- 分段参数只加在内建对象上（`KBUILD_CFLAGS_KERNEL`），不是所有文件。
- 6.12 的链接脚本在打开分段后，TEXT_MAIN 会把排在它后面的 `.text.unlikely.*`、`.text.unknown.*` 并入普通 `.text`，冷代码分组失效；`.text.hot.*` 排在 TEXT_MAIN 之前，不受影响（`include/asm-generic/vmlinux.lds.h:553` 起）。上游 0043ecea2399（v6.13）已核实，只修改这个公共头文件（另有 sparc 链接脚本），评审方已在本树做过 `git apply --check`，可以单独回移植。它把顺序改为 asan/tsan、unknown、unlikely、页对齐、hot、main，会在热代码前增加至多一页的对齐填充，并可能改变整体布局；回移植时保留完整的顺序和页对齐，单独记录填充字节和最终地址变化。补丁的公共头文件部分：

  ```diff
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
  ```

**方案**：打开该选项；常驻收益先不设预算。分别在“保留函数追踪”和“关闭函数追踪”两个基线上测 DCE 的增量，逐类检查保留的根（mcount 表、导出符号、initcall 等）。不能为了提高收益删除 `KEEP(__mcount_loc)`。按函数分段也是 3.7 函数重排的前提。

**风险**：Kconfig 帮助文本标明为实验性；缺少 KEEP 标注的段会被静默丢弃，可能导致功能缺失但仍能启动；分段和对齐的开销可能抵消一部分删除收益。

**验证**：链接 map 和 `--print-gc-sections`；mcount 重定位和被删符号逐类归因；仍保留的函数可以正常追踪；异常向量、initcall、`__ksymtab`、`.ARM.exidx` 完整；启动、模块加载、ftrace、kprobe、oops 回溯和功能冒烟测试。

#### 3.1.5 ARM32 内核 LTO（PoC，低优先级）

本树 ARM32 没有 LTO 的接入路径（arch/arm 没有 select ARCH_SUPPORTS_LTO_CLANG）。本轮不实施。调研以内部分支 `sandbox/sebuns2/use_lto`（a4fe97e1，2020 年，arm64）为起点；3.1.4 的链接期死代码消除作为成本较低的独立比较基线，不保证它与 LTO 的收益有单调关系。后续 PoC 先验证链接、启动、模块、汇编引用和 EHABI/ftrace 兼容性，这些不通过就不做收益测试。3.7 的采样驱动优化不以 LTO 为前提。

#### 3.1.6 内核映像改用 LZ4 压缩（开机时间，低优先级）

映像文件会变大，按 1.4 在报告中写明；通过条件是开机时间不回退。

当前 KERNEL_GZIP=y。改为 KERNEL_LZ4 能加快解压，但映像会变大，读取时间会增加，所以以“读取时间 + 解压时间”的总和判断：估算收益 = 解压节省的时间 − 新增字节数 / 实际读取带宽。没有实测前，不承诺开机收益和映像增幅。先确认启动链实际加载的是本次生成的 zImage，并确认 boot 分区（64 MiB）的余量。内部分支 `sandbox/sebuns2/kernel_compression`（624d6479，arm64）可作参考。它与 zram 的 LZ4 快速解压补丁不是同一条解压路径。

**验证**：分段记录引导加载器读取时间、解压时间和开机到桌面时间；镜像大小和解压临时空间。

#### 3.1.7 TRIM_UNUSED_KSYMS（低优先级）

**依据**：本配置关闭了 TRIM_UNUSED_KSYMS（`kernel/module/Kconfig`）。打开后，只保留产品模块集合实际用到的导出符号。

**预期收益**（估算）：导出相关段合计约 0.51 MB（06 §2 的 LLVM 普通版：`__ksymtab` 78,564 B、`__ksymtab_gpl` 85,992 B、`__kcrctab` 26,188 B、`__kcrctab_gpl` 28,664 B、`__ksymtab_strings` 287,458 B，约 13,700 个导出符号）。如果产品模块只用其中 15%，元数据上界约 0.43 MB，以 ELF 实测为准。函数本身能否被删除，取决于 3.1.4 中 mcount 等保留根。构建要做两遍，构建时间单列报告。

**前提与风险**：产品模块和第三方模块的名单必须完整，否则树外模块、升级或恢复时的模块会加载失败。它不等于关闭 KALLSYMS。

**验证**：从所有产品模块的未定义符号建立保留清单，必要时配置白名单；核对 `Module.symvers`；加载全部产品模块，覆盖升级、恢复和热插拔。

### 3.2 配置裁剪（常驻内存）

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

内建代码占低端内存。改为模块后：模块不加载时，全机和低端内存都节省；即使模块被加载，本平台的模块内存经 vmalloc 来自 HighMem（`mm/execmem.c:21–31`、`mm/vmalloc.c:3652`），低端内存的收益依然成立，全机占用略有增加（页取整和模块元数据）。代价是：热点代码改为模块会因 4 KiB 页映射增加 iTLB 缺失；开机时加载会拉长开机。所以热点代码不改为模块，开机时间按 1.4 测量。必需但不热的子系统也可以借此把代码从低端内存移到 HighMem，见 7.13。Btrfs、NFS、USB 驱动还涉及恢复模式、升级、网络启动和热插拔，不只是当前有没有挂载；btrfs-progs 的 udev 规则如果在开机时扫描设备，会自动加载 btrfs 模块，阶段 0a 只读检查。

**BTF 的特殊情况**：

- **已确定的部分**：网络监控插件内嵌的 3 个程序都是 fentry 类型。fentry 依赖 BPF trampoline，而 6.12 的 ARM32 BPF JIT 没有实现：挂载路径首先在 `arch_bpf_trampoline_size()` 的弱符号默认实现处失败（`kernel/bpf/trampoline.c`，返回 -ENOTSUPP，即 -524），`arch/arm/net/bpf_jit_32.c` 没有覆盖它。所以这些程序在 armv7l 上必然无法挂载。这是源码层面的结论，不需要再以找到板上失败日志为前提；板上没有日志只说明没有证据表明它运行过。
- **不能推出的部分**：“fentry 不能用”不等于“关闭 BTF 没有功能损失”。还要考虑：
  1. CO-RE 重定位与挂载类型无关。插件即使改用 kprobe 或 tracepoint（这两种在 ARM32 可用），只要还做 CO-RE 字段重定位，就仍然需要一份与运行内核布局完全一致的目标 BTF（可以来自内核，也可以来自外置文件，见下文替代路径）；
  2. ARM32 上不依赖 trampoline、但依赖内核 BTF 的功能仍然可用，例如 tp_btf、bpf_iter；
  3. 静态链接的程序、按需加载的组件、诊断工具不一定出现在当前扫描结果中；
  4. typed `__ksym`、模块的 CO-RE、内核 attach 用到的 BTF ID、工具对 vmlinux 类型的查询等用途；程序和 map 自带的 BTF 单独列入清单，它们不依赖内核驻留的 BTF；
  5. 构建侧的 btf-devel 包和 vmlinux.h 导出。
- **可行的替代路径**：插件改用 kprobe/tracepoint（不能只改 section 名，要按 ARM32 的 pt_regs 约定重写参数读取，并逐项核对监控语义）；用 BTFGen（`bpftool gen min_core_btf`）从完整 vmlinux 的 BTF 中只提取插件实际用到的类型，随插件一起发布，通过 libbpf 的 `btf_custom_path` 加载；或者用 pahole 生成独立的 BTF 文件放在文件系统中。外置 BTF 能满足用户程序的 CO-RE 重定位，但不能恢复内核自身依赖 BTF 的能力（tp_btf、bpf_iter、bpftool 的类型化输出）；kfunc、struct_ops、fentry/fexit、BPF LSM 在 ARM32 上本来就不可用。libbpf 1.6.2 不校验外置 BTF 是否与运行内核一致：`btf_custom_path` 原样使用传入的文件；不传时，它按 `uname -r` 依次查找 `/sys/kernel/btf/vmlinux` 和若干标准路径（如 `/boot/vmlinux-<版本>`）。同一版本号的每次构建 `uname -r` 都相同，所以“版本不匹配会被拒绝”不会自动发生。一致性只能靠同一次构建生成、与内核同包发布，并在加载前比对实际运行内核的 build-id 来保证（不能只比 uname、配置或包版本）；每个内核变体携带自己的 BTF、模块和哈希清单，只替换内核的部署（4.6）也要遵守。测试要包括：同版本号、同配置、源码布局不同的内核配错误的 BTF，必须被拒绝。好处是：只要独立 BTF 装在标准路径下，插件的 BTF 加载代码不需要改。测试要覆盖错误的 BTF、同版本不同配置的内核、模块更新和文件缺失。
- **构建侧**：BTF 关闭后 DEBUG_INFO_BTF_MODULES 自动消失；spec 中由 vmlinux 导出 vmlinux.h 的步骤会失败，改为先用 pahole 从 DWARF 生成独立 BTF（`--btf_encode_detached`，需确认 buildroot 中 pahole 1.29 支持），再用 bpftool 导出 vmlinux.h，btf-devel 包保持不变。
- **如果产品必须保留内核 BTF**：见 7.8（先在初始化时转存到 HighMem，再评估压缩存储）。
- **决策**：BTF 暂时保留，其他裁剪项照常推进。阶段 2 完成产品的 BPF/CO-RE 依赖清单，并决定网络监控功能的保留方式（改写插件，或登记为功能缺口）之后，再决定是否关闭。armv7l 和 aarch64 分别按依赖清单决定，不按架构一刀切。

**做法**：

1. 先在同一基线上分别测量每个独立裁剪项；
2. 再构建组合变体，测量净收益；
3. 组合后逐项恢复只用来检查项与项之间的相互影响，得到的是“在其他项已裁剪前提下的贡献”，不能当作该项的独立收益。

每次保存最终 diffconfig，核对反向 select、共享库、模块打包和加载行为。Gerrit 上按项拆成独立提交，便于产品方逐项取舍。

**验证**：除静态段外，还要测运行时的低端内存占用：内建的 Btrfs、NFS、SUNRPC 启动后会创建 slab cache、workqueue 和内核线程，所以对比 `/proc/slabinfo` 各 cache 大小、内核线程数和非 CMA 部分的 LowFree。另外检查 RPM 模块文件清单、依赖加载、自动加载、外设热插拔、恢复和升级流程、模块卸载后的内存；perf 内核函数符号解析。

### 3.3 低端内存

本节各项都先在标准场景下测量低端内存压力（2.3），压力被证实后再比较收益。涉及启动参数的项（vmalloc=、swiotlb=、alloc_in_cma_threshold）需要修改 boot 分区的命令行，见第 6 章。

#### 3.3.1 跨区保护参数

**依据**：见 2.3。DMA 档实际生效的 256 对应名义保护约 12.5 MiB；对非 CMA 低端内存的实际保护还要更小。

**方案**：运行时逐档测试 DMA 档 256 → 64 → 32（名义保护约 12.5、49.8、99.6 MiB），通过一档再试下一档，可随时恢复。同时评估树莓派下游的启动参数 `alloc_in_cma_threshold`（下游提交 e640262c2f69，默认 12/16）：它决定可移动分配何时优先从 CMA 取页，与 ratio 一起决定非 CMA 低端内存的实际余量。改为 8 即恢复上游的 1/2 行为，评审方推算可使非 CMA 低端的空闲下限大约翻倍；代价正是下游当初提高阈值所防范的 CMA 碎片，视频和 GPU 的 CMA 分配延迟与失败可能上升，所以同时记录 vmstat 中的 `cma_alloc_success`、`cma_alloc_fail`、视频起播和切台耗时。两者先分别测，再测组合。确认有效后，再决定落在 resourced 的启动配置还是平台补丁。

**预期收益**（估算）：高压力场景下，非 CMA 低端内存的空闲低谷升高，allocstall_normal 和低端内存分配失败减少。代价是 HighMem 请求更早在 HighMem 内回收。MemAvailable 会随保护值下降，按 1.2 的口径不计为驻留增加。

**风险**：提前回收、换出或 OOM；影响后台存活数。kswapd 只要任意一个符合条件的区达到高水位就认为平衡，判断时用不含 CMA 的空闲量并加上 lowmem_reserve（`mm/vmscan.c:6695–6706`），所以提高 reserve 可能让 kswapd 运行得更久，需要单独测 kswapd CPU 和 pgscan_kswapd。调低 `alloc_in_cma_threshold` 只改变取页偏好，不保证非 CMA 保护按比例增加。

**验证**：相同的用户页压力下，分别加入 CMA 消费和不可移动的内核分配；记录非 CMA 空闲低谷、CMA 借用量、分配失败的 GFP 标志和阶数、allocstall_normal、allocstall_high、后台存活数和切换耗时。

#### 3.3.2 缩小 vmalloc 区（启动参数）

**依据**：当前 VmallocTotal 为 240 MiB，静置时 VmallocUsed 约 21 MiB。ARM 的 `vmalloc=` 启动参数决定 vmalloc 区大小，低端内存的上界随之移动（`arch/arm/mm/mmu.c:1163–1245` 的 `vmalloc_limit`）。低端内存只能来自第一段 RAM（末尾 948 MiB，见 2.3），所以本方法最多多出约 180 MiB；`vmalloc=128M` 时低端上界约 880 MiB，多约 112 MiB。这是线性映射上界的移动，不是新增物理内存，HighMem 容量相应转移。

**方案**：VmallocUsed 主要反映已分配的页，不反映可用的虚拟地址跨度；ioremap、保留区间、guard 页和碎片都影响连续映射，所以“峰值的两倍小于新大小”不是充分条件。先在标准场景、压力、热插拔和长时间运行下统计 vmalloc、vmap、ioremap 的地址区间、guard 和保留空间、最大单次请求和最大连续空洞（`/proc/vmallocinfo`），按调用者分类。依据地址高水位逐档测试 192M、160M、128M，首次只试一档。实际的 LowTotal 增量由内存空洞、对齐和保留区决定，以实测为准。低端内存变大后 min_free_kbytes 和各区水位会自动重算，报告前后值。

**风险**：vmalloc 区不够时 fork、驱动 ioremap、模块或 zram 初始化会失败。本配置 VMAP_STACK=y，每个线程的内核栈都占 vmalloc 地址空间；ARM_MODULE_PLTS=y 时模块也可能溢出到 vmalloc 区；zram 槽表、GPU 和多媒体驱动的映射也在这里。产品板的 ioremap 量可能不同。

**验证**：线程风暴、GPU 和多媒体映射、模块热插拔、最大连续请求、长时间碎片化和故障恢复；记录 vmap 失败和线程数峰值。

#### 3.3.3 用户/内核地址空间划分（评估，产品决策）

**依据**：当前 VMSPLIT_3G（PAGE_OFFSET 0xC0000000）。本板 ARM_LPAE=y，而 VMSPLIT_3G_OPT 依赖非 LPAE，不可选；只评估保持 LPAE 的 VMSPLIT_2G。它能多出约 1 GiB 低端内存，代价是每个进程的用户地址空间降到 2 GiB − 16 MiB（ARM 的 TASK_SIZE 还要减 16 MiB）。如果实际使用的机器描述没有设 DMA 区大小（见 2.3），改成 2G 后 DMA 区仍会覆盖全部低端内存，Normal 区不会出现，lowmem_reserve 的档位也不会改变。

**方案**：第一步不改内核，在标准场景中采集所有进程的 VmPeak、VmSize、最高映射地址、最大连续虚拟区间需求和固定地址映射；VmPeak 低于限制不能证明映射一定成功。数据满足前提后，再构建 VMSPLIT_2G 变体。不要为了开启 3G_OPT 而关闭 LPAE。

**风险**：浏览器引擎、.NET 运行时等大地址空间进程可能失败；GPU 用户映射、模块区、vmalloc 余量和 DMA/CMA 路径都要验证。这是产品级决策，结论必须在产品板上复核。

**验证**：完整启动到长时间运行的全部场景；低端内存增量以实测为准，不按地址差直接计算。

#### 3.3.4 SWIOTLB 池

**依据**：启动参数 `swiotlb=8192`，每槽 2 KiB，名义数据池 16 MiB；本配置 SWIOTLB=y、SWIOTLB_DYNAMIC=n。本树有使用高水位统计（`kernel/dma/swiotlb.c`）和动态扩展支持。

**方案**：先在 tracefs 中启用 `swiotlb/swiotlb_bounced`，统计标准场景中按设备分类的回弹次数和字节数。如果存储或 USB 控制器的 DMA 地址范围小于物理内存，HighMem 中页缓存的 I/O 都要经过回弹（多一次 CPU 拷贝），SWIOTLB 就处在 I/O 热路径上：这时缩小池子有阻塞 I/O 的风险，回弹本身也是性能成本，单独立项，不缩池。没有大量回弹时，再采集池的使用高水位（含恢复后和 DMA 并发峰值）。余量足够时测试 `swiotlb=4096`（约少 8 MiB）；打开 SWIOTLB_DYNAMIC 作为独立变体。不能凭静置时的低使用率缩池。

**风险**：DMA 映射失败；动态扩展在内存紧张或碎片化时也可能失败，不能据此认为任意小的池都安全。

**验证**：各类外设和并发 I/O，长时间碎片化后重复；DMA mapping 错误、池高水位、吞吐和延迟。

#### 3.3.5 按 cache 调整 SLUB 保留

**依据**：静置时 Slab 约 54 MiB，SUnreclaim 约 39 MiB，全部在低端内存。本配置 SLUB、SLUB_CPU_PARTIAL 均已启用，每个 cache 可通过 sysfs 调整 `cpu_partial`、`min_partial` 和主动 shrink。

**方案**：按 cache 统计对象数、slab 页数和 partial 分布，只对实测有大量可释放整页的 cache 逐个调整。本配置 SLAB_MERGE_DEFAULT=y，参数相同的 cache 会合并成一个（`/sys/kernel/slab/` 下表现为指向同一目录的链接），调整会作用于整个合并组；先确认合并组，按合并组报告收益，本轮不使用 `slab_nomerge`。全局关闭 SLUB_CPU_PARTIAL 只作诊断上限，不作正式方案。

**预期收益**（估算）：只按真正释放的整页计算；如果 5%–10% 的 slab 页可以释放，约 2.7–5.4 MiB 低端内存。目前没有空闲比例的数据。

**风险**：节点锁争用、重新分配的 CPU 成本和延迟长尾；对象空闲不等于整页可释放。

**验证**：按 cache 记录生命周期后的释放量；网络突发和应用恢复时的延迟；不用全机 drop_caches 干扰测量。

#### 3.3.6 CMA

本轮不修改 CMA 容量。记录播放、切台、图形合成和峰值并发时的 CMA 使用量、CmaFree 最小值、分配失败和回收延迟，为产品板的 CMA 取值提供数据。CMA 空闲时可被可移动页借用，不是全部浪费。

#### 3.3.7 降低主动内存整理（运行时参数）

**依据**：本板 THP 关闭，但 `vm.compaction_proactiveness` 为 20（[运行时参数](../evidence/task5/F_memory_runtime.txt) 第 44–45 行），主动整理仍会在后台迁移页面；6.12 文档允许设为 0 关闭主动整理，并提示迁移会带来延迟。它与 3.6.2 的 zsmalloc 碎片整理是两回事。

**方案**：先观测主动整理实际消耗的 CPU 和迁移页数；只有确实存在时，才单独比较 20 与 0。保留直接整理和 CMA 连续分配机制，不全局关闭 COMPACTION。

**预期收益**（估算）：上界是实测的主动整理 CPU，例如占一核 1% 时，整机约 0.25%；长尾延迟的收益另测。没有主动整理活动就停止。

**风险**：整理推迟到 DMA、CMA 或高阶分配的关键路径上。

**验证**：视频缓冲、GPU、USB、长时间碎片化和恢复；记录分配阶数、失败和最慢延迟；有回退就恢复 20。

### 3.4 zram

#### 3.4.1 算法可用性与配置闭环（先做）

**现状问题**：resourced 配置的是 zstd，内核只有 LZO 后端，实际是 lzo-rle。没有日志说明设置失败的原因。

**内核配置要点**：

- `ZRAM_BACKEND_FORCE_LZO` 是自动计算的符号：只要编入任何其他后端，它就变成 n。
- `ZRAM_BACKEND_LZO` 的默认值等于 FORCE_LZO。如果只加 LZ4/ZSTD 而不显式保留 LZO，LZO 后端会消失，默认算法 lzo-rle 也会跟着失效（`drivers/block/zram/Kconfig`）。

LZ4_COMPRESS、LZ4HC_COMPRESS、ZSTD_COMPRESS 已经内建（lib/zstd 约 0.54 MB 已在镜像中），增加后端只多出胶合代码，体积代价很小，但不是零；按 1.2，新增后端的代码字节数在报告中写明。实验内核的配置是：

```diff
+CONFIG_ZRAM_BACKEND_LZO=y
+CONFIG_ZRAM_BACKEND_LZ4=y
+CONFIG_ZRAM_BACKEND_ZSTD=y
+CONFIG_ZRAM_BACKEND_LZ4HC=y
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
| LZ4HC 对照 | lz4 | 只对空闲页用 lz4hc，先不带字典（本配置 LZ4HC_COMPRESS 已内建，缺的是 zram 后端 `ZRAM_BACKEND_LZ4HC`；lz4hc 的解压仍走 LZ4 解压器，有望在减少载荷的同时保持较快的换入） |

为了能解释结果，按下面的顺序逐个因素对照，不一次混入多个变化：

| 对照 | 目的 |
| --- | --- |
| 原内核 lzo-rle 与新实验内核 lzo-rle | 新增后端和框架本身的成本 |
| lzo-rle、原版 lz4、zstd，都不开二次压缩 | 主算法差异 |
| LZ4 旧版本 → 新版本（快速解压关）→ 同版本（快速解压开） | 分别测库升级与快速解压的增量 |
| 同一主算法，二次压缩关/开 | 二次压缩的价值 |
| 同一算法和级别，字典关/开 | 字典的价值 |
| 都用 idle=all 筛选，ACTIME 关/开 | 访问时间跟踪本身的成本（按时间筛选的价值另作实验） |

Jaehoon 的 lz4 三个补丁能干净合入，但还没有编译和验证，不能当作已验证正确。补丁新增的 `CONFIG_LZ4_DECOMPRESS_FAST_LOOP` 只在打补丁后才存在，默认条件是 `CPU_V7 && !CC_OPTIMIZE_FOR_SIZE`，所以全局 `-Os` 构建会改变它；对照时显式设为 y 或 n。原作者的 GCC 数据不能当作本平台的 Clang 数据。

**先做离线预筛**：编内核之前，先离线转储几个后台应用的匿名页，按独立的 4 KiB 页，调用与候选内核相同版本、相同级别、相同字典语义的算法实现，测压缩率和速度；分别统计同值页、不可压缩页，以及压缩大小落到 zsmalloc 哪个 size class。普通命令行工具按大块或流处理，结果只作粗线索，不能据此淘汰内核候选；lzo 命令行工具也不能代表内核的 lzo-rle。

#### 3.4.3 成本账本

`mm_stat` 的 `mem_used_total` 只统计 zsmalloc 的页，不是 zram 的全部成本。各项要分别标注所在的内存区，低端内存部分计入 1.2 的低端门槛：

- **低端内存**：zsmalloc 每个对象一个 handle，来自 handle slab（分配时去掉了 HIGHMEM 和 MOVABLE 标志，`mm/zsmalloc.c:331–332`）；每个 zspage 一个描述结构，来自 zspage slab；当前 lzo-rle 的每 CPU 工作区由 `kzalloc` 分配（`drivers/block/zram/backend_lzorle.c:20`）。handle 字段在 ARM32 上是 4 B，但对象按至少 8 B 对齐，满载 397,648 个非同值对象时 handle 部分约 3.03 MiB，还未计其他元数据，不能把“合计 2–4 MB”当作已验证的预算。
- **允许 HighMem 的部分**：zsmalloc 载荷页和槽表（`vzalloc`）的底层页允许来自 HighMem，但不保证在 HighMem，也可能来自低端或 CMA；按物理页实际所在的区统计。其他后端的上下文逐项列出分配方式。
- **vmalloc 地址空间**：槽表和经 vmalloc 分配的上下文占用 vmalloc 地址，总量只有 240 MiB（与 3.3.2 相关），另计。
- **slab 统计**：本配置 SLAB_MERGE_DEFAULT=y，按 cache 名读取或相加可能漏计或重复计数；解析 `/sys/kernel/slab` 的别名，按实际 cache 去重；混合 cache 不能整个归到 zram。

每个方案分项报告：

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

- `mark_idle()` 的全表循环中没有 `cond_resched()`（`zram_drv.c:291` 起），而本内核是 PREEMPT_VOLUNTARY，标记一次 39.8 万个槽会连续占用 CPU，可能让同一 CPU 上的 UI 线程错过帧；持续时间先实测（评审方估算 10–40 ms，没有测量依据）。补丁（单独提交，提交前查上游是否已有相同修复）：

  ```diff
  --- a/drivers/block/zram/zram_drv.c
  +++ b/drivers/block/zram/zram_drv.c
  @@ static void mark_idle(struct zram *zram, ktime_t cutoff)
   	for (index = 0; index < nr_pages; index++) {
  +		/* idle_store() runs from sysfs with only init_lock held for read */
  +		if (!(index & 1023))
  +			cond_resched();
  ```

  调用方只持有 init_lock 的读锁，可以睡眠，没有功能变化。验证：全空、稀疏、接近满表三种分布下执行 `echo all > idle`，启动一个与写 idle 的进程绑在同一 CPU、SCHED_FIFO 50、每 1 ms 唤醒一次的探针进程，用 tracefs 的 `wakeup_rt` tracer（本配置 SCHED_TRACER=y）读取 `tracing_max_latency` 和对应的调用栈，比较改前改后的值（perf 没有 libtraceevent，不能用 perf sched）。没有并发访问时，核对标记结果与改前一致；有并发读写、释放或 reset 时，验证数据完整性、标志位转换和延迟上限，不要求候选集合逐槽一致。统计每批扫描数、尝试数、成功数、CPU 和最长连续运行时间。
- 共享的换出页（引用计数大于 1，例如 launchpad 派生进程共享的匿名页）换入时会走 swap cache 预读，预读到的页也会被清掉空闲标记，冷页被当成热页。结果是少重压缩一些，方向保守，但收益偏低。
- 重压缩在槽锁内完成解压、压缩和新对象分配，期间对同一槽的换入要等待。锁在两页之间释放，但单页的处理时间仍决定一次持锁和不可抢占延迟的上限，要分别测量压缩、分配和等待各段；分批不能代替单页上限的验证。锁外压缩的改进见 7.16。
- `recompress` 每次调用都从槽 0 开始扫描（`zram_drv.c` 中 recompress_store 的循环），`max_pages` 只限制实际重压缩的次数，不限制扫描长度和墙钟时间。
- 重压缩时原对象和新对象会短暂共存；被 zstd 压缩的冷页如果重新变热，解压长尾会变长。

**调度流程**：

1. resourced 是空闲标记和重压缩的唯一管理者，其他组件不能写 idle。`idle=all` 作用于整个设备，没有进程或 memcg 过滤，所以 resourced 按全局轮次管理“标记、观察、重压缩”：同一轮内不重复标记，其他应用的事件合并或推迟，不让观察窗口被反复重启。触发来源可以是屏灭、待机，或应用进入后台（只用来请求一轮设备级工作）；处理的是整个设备上没有被访问的对象，收益不归到触发的应用。测试连续切换、多个应用同时退到后台、观察期取消和设备 reset；
2. 标记 `idle=all`，等待预先定义的观察窗口；
3. 确认仍允许后台工作；
4. 以较小的 `max_pages` 分批提交 `type=idle` 的重压缩；
5. 每批检查实际耗时和净物理页收益；
6. 收到前台切换事件后，停止提交新批次。现有 sysfs 重压缩是同步调用，已经进入的调用不能被取消，只能等它返回；需要硬性的扫描、时间或取消上限时，依赖 7.1 或 7.16 的原型。

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

**通过条件**：按 1.2 的容差，换入延迟最慢 1%、应用切换耗时（包括长时间后台后切回）、kswapd CPU（按固定工作量归一，作为本实验预登记的硬门槛）不超过基线 2%，writestall 不增加，重压缩期间的前台指标也不回退；在此前提下，选同等负载下 zram 总成本最低的方案。

### 3.5 MGLRU

#### 3.5.1 min_ttl_ms

当前 `min_ttl_ms=0` 表示没有启用最小时间窗口的防抖动保护；MGLRU 的代际、分层和 refault 相关机制仍在运行。设置非零值后，如果在这个时间窗口内的工作集无法被保护，内核会直接触发 OOM（`mm/vmscan.c` 中 `lru_gen_age_node()` 调用 `out_of_memory()`），这会绕过 resourced 的查杀策略。

**方案**：先保持 0，完成 zram 算法对比；之后单独测试 100、500、1000 ms 三档，不与算法或 swappiness 同时改变。min_ttl 只在 kswapd 的老化路径中生效（`lru_gen_age_node()` 只由 `kswapd_age_node()` 调用），memcg 的 force_reclaim 不检查它，所以测试必须制造全局内存压力。内核 OOM 选择被杀进程时，按 RSS、Swap、页表、`oom_score_adj` 和可杀资格综合打分，还受 OOM 作用域影响（`mm/oom_kill.c:203–241`）。阶段 0a 读取所有进程的 `oom_score_adj`，结合 RSS、Swap、页表评估风险；静态快照不能保证最终被杀的进程，以实际 OOM 日志和进程角色为准。

另外，ARM32 没有硬件维护的访问位（没有 ARCH_HAS_HW_PTE_YOUNG，LRU_GEN_WALKS_MMU 也关闭），老化时每清一次访问位，下次访问就要多一次缺页，老化越激进缺页越多。

**验证**：后台存活数；vmstat 的 oom_kill、被杀进程及其类别（前台、后台、系统）、杀进程的来源（内核 OOM 还是 resourced）；minor fault 次数；前台切换耗时、内存突增。出现内核 OOM 杀掉前台或系统进程，就判定该档不可用。读取各 memcg 实际的 `memory.swappiness`，不用 resourced 配置值代替。

#### 3.5.2 MGLRU-FG（上游在审系列，回移植评估）

**上游现状**：Kairui Song（腾讯）2026 年 5 月发出 RFC；2026-10-16 发出 v4，共 17 个补丁，已经移出 RFC 阶段，基于 mm-new。作者在 Pixel 9 Pro 上做过非正式的 6.1 GKI 回移植（结果噪声较大）。尚未确认进入主线。作者报告的 Chromium 与 Node.js 负载请求数比原 MGLRU 多 75%，但这是服务器环境的数据，不能作为本平台的收益承诺。

**方案**：针对 v4 的 17 个补丁建立依赖清单，参考作者的 6.1 回移植分支估算工作量；重点检查 ARM32 页标志位、memcg v1、HighMem 路径，以及本平台没有 LRU_GEN_WALKS_MMU 的情况。放在阶段 5，以 3.4、3.5.1 的结果作为对照基线；与其他同事负责的 ML 回收方案分开测试。

**验证**：代际计数、迁移与回收竞态、PSI 口径变化、memcg 销毁、长时间压力。

### 3.6 用户态协同

#### 3.6.1 转入后台前主动归还已无用途的内存

**依据**：应用转入后台后，回收会把它的匿名页压缩进 zram；其中一部分是分配器缓存的空闲块或可重建的缓存，压缩它们既占 zram 也耗 CPU。glibc 的 `malloc_trim()` 和 Linux 的 `madvise(MADV_DONTNEED)` 都是现成机制；Android 官方指南也建议在生命周期转换时归还不需要的匿名页。

**先量清楚可归还的是什么**：smaps 只用来盘点映射、PSS 和 SwapPss，它不记录对象归属哪个分配器，不能可靠区分所有 glibc arena 和托管堆；要结合分配器统计和运行时的堆诊断，识别可以安全归还的页，不按进程名推断。大内存进程中有 .NET 应用（例如 SystemUI.dll、runner），托管内存由 GC 管理，`malloc_trim` 管不到；GC 压缩也不等于把内存还给操作系统。先清理可重建的缓存，再分别评估 native trim、托管回收和向操作系统释放，不默认强制压缩式 GC。通知优先复用应用框架已有的低内存事件（例如 `APP_EVENT_LOW_MEMORY`，.NET 侧为 `OnLowMemory`）；但现有事件是否支持序号、截止时间、完成回报和取消，没有接口证据，阶段 0a 核实。不够时，在应用框架中扩展一个最小的请求/应答协议，不假设现有回调已经具备这些语义。

**方案**：应用转入后台时，resourced 发出带序号和截止时间的生命周期通知；可控的应用和服务在安全点异步释放可重建的缓存、工作缓冲和分配器的空闲页（glibc 进程先试 `malloc_trim(0)`；musl 或自有分配器走各自接口），完成后回报。前台切换不等待无上限的清理；普通的主动回收尽量避开正在进行的归还窗口，到截止时间或内存紧急时按原策略继续。回到前台时取消尚未开始的清理，已执行的清理不假定可撤销。resourced 不对未知地址直接做破坏性的 madvise。

**协议要点**：请求以“进程实例身份 + 生命周期代次”为键，重复请求幂等；回报带代次和完成状态，过期代次的回报不再阻挡回收；resourced 重启、进程退出、PID 复用、回到前台都使旧代次失效；截止时间只限制等待和后续工作，不能中断已经进入的 malloc_trim 或 GC。归还工作放在后台 cpu cgroup 中低权重执行，推迟到前台应用首帧完成之后开始。本配置 CGROUP_FREEZER=y：如果 resourced 会冻结后台应用（阶段 0a 核实），顺序固定为“通知 → 等待回报或截止时间 → 冻结”。

**预期收益**（估算）：如果 4 个后台进程各有 8–20 MiB 可安全归还，可减少 32–80 MiB 驻留；按 2.5:1 的压缩比，相当于少压缩 13–32 MiB 的载荷。这两种收益不能重复相加。

**风险**：前提是确实有可归还的空闲页；`malloc_trim` 不保证清空线程缓存；有锁停顿和随后重新缺页的代价；错误丢弃活对象会造成数据损坏。

**验证**：测试应用卡住不回复、迟到的回报、PID 复用、resourced 重启、刚退后台又回前台、GC 正在执行、前台冷启动与后台归还同时发生、多线程 arena 和紧急回收；先挑一两个常驻内存高的进程试验；比较 PSS、SwapPss、zram 实际物理页、切回前台的首帧时间和最慢 1%；反复前后台切换、多线程并发和数据校验。

#### 3.6.2 zsmalloc 碎片与压缩率分开评估

**依据**：本板 `ZSMALLOC_CHAIN_SIZE=8` 已启用；本树已有 `zs_compact()` 和 shrinker。

**方案**：实验镜像打开 `ZSMALLOC_STAT`，读取各 size class 的分布和可释放页数（freeable）。只有在重压缩之后确实存在可释放的碎片时，才评估主动触发 compact，并扣除原生 shrinker 已经释放的部分，避免重复计算收益。

**预期收益**（估算）：上限约为 freeable × 页大小。假设 300 MiB 的池中有 5%–10% 的可整理空洞，上限约 15–30 MiB；没有空洞时收益接近零。静置时只有 1.43 MiB 的池，不支持“可省几十 MiB”的判断。

**风险**：迁移时的锁争用、对象搬运的 CPU、前台解压长尾。

**验证**：同样的匿名内容和存活数，算法固定，compact 关/开；测每毫秒释放的字节数、最慢 1% 延迟、多轮稳态碎片。

#### 3.6.3 KSM 重复量测量（先作测量工具）

**依据**：上游已有按进程启用 KSM 的 `prctl(PR_SET_MEMORY_MERGE)`（6.4）、按净收益统计的 `general_profit`（6.6）和控制扫描 CPU 的 advisor；本配置 KSM 未开启，但可以选择。

**方案**：先在测量镜像上，只对 3–5 个候选进程启用 KSM，读取 `general_profit`、`pages_sharing` 和 `ksm_rmap_item` 的 slab 大小，得到跨进程的真实重复量（包括驻留页和换出后又换入的页）。这比自己写页哈希工具便宜，也是 7.9 的前置测量。只有净收益（全机节省减去低端内存成本）显著时，才考虑作为正式方案：由可控应用对低写入的候选区域 opt-in，空闲窗口扫描、交互期停止扫描，停止时不做全量 unmerge（避免瞬时内存峰值）；排除跨信任域的数据。7.9 能低成本共享同一数据时，优先 7.9。

**风险**：每个被扫描的页需要一个位于低端内存 slab 中的 `ksm_rmap_item`（ARM32 上约 36–40 B），扫描 400 MiB 匿名内存约需 4 MB 低端内存（估算），正是本平台最紧的资源；扫描占 CPU；合并页写时复制的延迟；跨进程内容侧信道；共享页的 memcg v1 计费归属可能影响 resourced 的策略。

**验证**：净收益、非 CMA 低端内存、写时复制 p99、切换耗时、zram 往返和进程退出。

### 3.7 采样驱动优化

**能力边界**：见 2.4。armv7l 上只有指令地址采样，没有分支数据；PMU 中断不是 NMI，关中断区间采不到；function profiler 能给出覆盖范围内的调用计数，但覆盖不了开机阶段，也不能证明零调用。

**armv7l 内核 AutoFDO**：

- 本树没有 AUTOFDO_CLANG 接入；上游的接入从 6.13 开始，而且不包含 ARM32。
- 上游流程以分支数据为输入，现有 llvm-profgen 不接受只有指令地址的样本。
- 没有分支数据时，profile 只能提供函数级热度，预期收益很可能小到无法与噪声区分（注意 2% 是回退容差，不是噪声范围；噪声范围由 A/A 测得）。
- **结论**：本轮不做完整 AutoFDO 接入，降为跟踪项，与 AutoFDO/BOLT Agent 那条线的结果对照。没有本平台数据之前，收益预算按 0 计。armv7l 产品板到位后，如果它的 SoC 开放 CoreSight ETM/PTM 追踪，重新评估这一结论。

**本轮做的事**（阶段 4，最小实验放在阶段 4 开头）：

1. **热度数据**：两个来源互相补充。
   - cycles 采样：标准场景下系统范围、只看内核的采样，在开发机离线按函数聚合，使用与镜像 build-id 一致的 vmlinux 和模块，给出耗时热度。用两种不同的采样周期复核热点是否稳定，避免与周期性负载同步造成偏差；记录采样丢失和场景覆盖。
   - function profiler：在训练镜像上打开，得到覆盖范围内的调用计数。训练前保存并清空 ftrace 过滤器（4.3 的测量会设过滤器），记录可追踪函数的全集、模块的加载时间、启停窗口、各 CPU 的数据和丢失情况。它会改变调度和覆盖，只用于训练。
2. **热函数重排**：只对明确、重复出现的热点排序。在 3.1.4 打开按函数分段、并回移植链接脚本修正之后，用 LLD 的 `--symbol-ordering-file` 把热函数集中排列。LLD 的排序受链接脚本输入段分组约束，先核对最终 map 中的实际地址顺序，再讨论缓存收益。
3. **冷代码体积优化**：
   - 未被观察到的函数保持“未知”，不当作冷函数；**不使用 `-fprofile-sample-accurate`**。
   - 输出中没有出现的函数默认是“未知”；只有在覆盖条件成立（过滤器为空、模块已加载、启停窗口覆盖全部场景）时，才列为该训练集中的“未观测”候选，再人工审阅。再排除入口代码、中断处理、调度核心、锁、hrtimer 和异常恢复路径。
   - function profiler 覆盖不了开机阶段，所以冷候选还要减去“开机期间执行过的函数”。这个集合由 7.14 的首次执行位图训练内核获得；在它实现之前，排除所有带 probe、init、mount、setup 字样的非 `__init` 函数和驱动的 probe 路径，开机和恢复路径一律保持原优化等级。
   - 采样热度的关中断修正用调用链：`perf record -g`（ARM32 内核调用链经 EHABI 可用，`arch/arm/kernel/perf_callchain.c`），把落在 `_raw_spin_unlock_irqrestore`、中断返回路径等开中断点上的样本归给调用链上的祖先函数；关中断期间已执行完并返回的被调函数，再用静态调用图补上一层。调用链和静态调用图只能作为保护热函数名单的保守线索，不能恢复这些函数的真实样本归属。
   - 候选形成人工可审计的白名单，由编译器给这些函数加 `cold`/`minsize` 属性，或按对象使用 `-Os`；每批白名单单独做 A/B，先从目录级白名单开始，收益按最终符号和段的字节数统计，不按函数个数统计。上游没有“读入冷函数清单”的编译器选项，做法见 7.12；第一步先不改编译器，用 `__attribute__((cold, minsize))` 手工标记一个目录（例如 `net/sunrpc`）测体积变化。`cold` 属性使函数进入 `.text.unlikely`，前提是 3.1.4 的链接脚本修正。
   - 不走 sample profile 的冷处理：`-fprofile-sample-accurate` 触发的按体积优化（PGSO）只作用于部分优化步骤，`cold`/`minsize` 也不等于 `-Os`（minsize 更偏向最小尺寸），它们与整函数 `-Os` 的体积没有确定的大小关系，不能直接引用全局 `-Os` 的数字。
4. **profile 转换**（只在需要 sample profile 时做）：按成本从低到高尝试，前一条可行就不做后一条。
   - `create_llvm_prof --use_lbr=false`（Clang 文档给出的方式；平台没有提供该工具，需要验证能否处理 ARM32 内核映像）。
   - 把单个指令地址写成 `[IP,IP]` 区间，构造 llvm-profgen 的 unsymbolized profile 输入。这在 llvm-profgen 中是单地址的闭区间，只作为转换器实验；必须用已知执行次数、内联栈和行映射的测试程序验证计数语义，不能虚构分支边、入口次数，也不能把 cycles 样本当作准确的执行次数。
   - 自写转换器：用 llvm-symbolizer 把指令地址映射到函数、行偏移和内联栈，直接输出文本格式的 sample profile。
   初期优先直接生成函数热度清单，用于重排和白名单，不做不必要的 profile 推断。
5. **最小实验**：
   - 在 2–3 分钟的标准场景上采样，统计前 N% 函数占的样本比例，以及被采到的函数占 .text 的比例（约一天）；
   - 构建一次全内核 `CONFIG_CC_OPTIMIZE_FOR_SIZE=y` 作为全局对照点（它不是混合优化的上界；另外注意它会改变 LZ4 快速解压选项的默认值，见 3.4.2）；
   - 热度高度集中、且对照点显示体积可观时，才做白名单和重排。
6. **需要精确边信息时**：用插桩 PGO 而不是采样。GCC 路线是 `CONFIG_GCOV_KERNEL`（本配置 ARCH_HAS_GCOV_PROFILE_ALL=y）配合 `-fprofile-use`，内部有先例 `sandbox/sebuns2/pgo_applied_kernel`（8423391f，arm64）；Clang 路线需要移植 2021 年 LKML 上未合入主线的 PGO_CLANG 系列，工作量较大。

**风险**：采样偏移（skid）造成边界函数误判；场景代表性决定收益；对单一流程过拟合；冷函数误判导致长尾回退。验收增加未训练的场景、异常恢复、网络突发、模块热插拔和长时间后台后恢复。

**测试**：一个热函数、一个从未执行的函数、一个关中断区间内的函数、一个只在开机时调用的非 `__init` 函数（例如某个驱动的 probe 函数，必须不在冷函数清单中）、重名的 static 函数、内联函数、晚加载的模块函数、残留的过滤器、深调用链、已知调用次数的用例，检查热度清单、优化备注、最终地址和代码尺寸。

**内核 BOLT**：

- LLVM 22.1.8 的 BOLT 只支持 x86-64 和 AArch64 的 ELF，不支持 ARM32，本轮排除。
- 产品板主要是 armv7l，目前没有 aarch64 产品板，内核 BOLT 只在 RPi4 的 aarch64 镜像上做可行性验证，不作为本项目可交付的优化。

### 3.8 调度参数（阶段 3，单独变体）

这两项影响全系统的调度和吞吐，分别做对照，再做组合；只有吞吐类指标和开机时间都通过时才保留。评审方称 Android GKI 使用 HZ=250 和完全抢占，本文没有逐行核对公开配置，不作为依据。

**HZ=250**：本平台为 HZ=100（ARM 的 HZ 是没有显式默认值的选择项）。6.12 的 EEVDF 调度器在时钟中断中检查时间片是否用完，HZ=100 时一个持续占用 CPU 的任务在时间片到期后最多还能再运行约 10 ms 才被抢占（唤醒抢占除外）；schedutil 的利用率更新也依赖时钟中断。改为 250 后，后台 CPU 密集时前台 UI 线程等待 CPU 的长尾可能从约 10 ms 缩短到约 4 ms，升频反应更快（推理，需实测）。本配置 NO_HZ_IDLE=y，空闲时没有额外的时钟中断。风险：忙碌时时钟中断增加 2.5 倍，吞吐可能下降不到 1%（估算）；对 jiffies 精度敏感的用户态程序要检查。验证：切换和冷启动的 p99、`wakeup_rt` 调度延迟、吞吐类指标、开机时间。

**完全抢占（PREEMPT）**：本平台为 PREEMPT_VOLUNTARY；ARM32 没有 PREEMPT_DYNAMIC。完全抢占下，内核态的长循环（zram 标记和重压缩、slab 收缩、回收）不再阻塞前台线程，3.4.4 那类不可抢占区间的问题会自然消失。风险：自旋锁和抢占计数的开销使内核吞吐下降，常见估计 1%–2%，可能超过门槛；驱动中隐藏的抢占假设会暴露。验证：p99 类、吞吐类指标，按工作量归一的内核态 instructions 和 cycles；另做一次开启 DEBUG_PREEMPT 的诊断构建跑完整场景。

### 3.9 不做的项

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
| 内存 | 1.2 中的全机、低端指标；非 CMA 部分的 LowFree；`/proc/zoneinfo` 中 DMA 区的 nr_free_pages、nr_free_cma、protection；CmaFree 最小值；vmallocinfo；应用 PSS 与 SwapPss；memcg v1 的 usage、memsw、stat；3.4.3 的 zram 分项成本；DMA/Normal/HighMem 各区水位，以及 CMA 池的空闲、借用和分配；Slab、SUnreclaim、KernelStack、PageTables、VmallocUsed；直接回收次数和 PSI | 按层级统计，不累加父子 memcg；共享页不重复计算 |
| 回收 | refault（文件/匿名）、pswpin/pswpout、kswapd CPU、PSI memory、后台存活应用数、杀进程来源 | 从 /proc/vmstat、/proc/pressure 取差值 |
| zram | mm_stat、io_stat、debug_stat（writestall）、每页压缩/解压耗时、标记和重压缩的耗时 | 测量本身的开销要先单独测出 |
| 延迟 | 见 4.3 | — |
| CPU | cycles、instructions、热点函数 | 按任务 5c 的方式临时推送 perf；perf 不能解析 tracepoint，tracepoint 一律直接用 tracefs |

**测量专用内核**：需要按调用点找出主要的分配者时，构建一个打开 MEM_ALLOC_PROFILING 的测量内核（6.12 已有该功能，本配置关闭但可选）。它按调用点汇总分配量，没有区域维度，不能直接当作低端内存排行；低端归属要结合分配器类别和物理页所在的区另行采集。它会选上 PAGE_EXTENSION 和对象扩展，自身占用低端内存并减慢分配路径，这部分开销单列；结论用差值表达，回到正式镜像复验，不提供正式收益数字。

### 4.3 换入延迟和切换耗时

分四层测量，各层不互相替代：

1. **换入缺页的墙钟时间**：`do_swap_page()` 的进入到返回，包括分配、memcg 计费、页表处理和并发等待。
2. **同步读路径**：`swap_read_folio()`（zram 同步路径会走到 `swap_read_folio_bdev_sync()`）。
3. **zram 内部**：槽锁等待、映射、解压。
4. **应用切换**：从切换请求到第一个满足完成条件的画面。

**换入延迟分布：合成微基准**（确定性最好）。

- 在一个 memcg v1 中分配 N MB 匿名内存，填入从后台应用离线转储的真实页面内容，保证压缩率有代表性。
- 用 `memory.force_reclaim` 回收后，先确认目标页的换出状态，分别记录成功换出和未换出的页数（回收成功不保证所有目标页都已换出）。
- 固定并预热计时代码和结果缓冲，必要时只锁住少量测量控制页，目标数据不锁定，避免计时代码自身被换出而污染结果。
- 逐页访问并用 `clock_gettime` 计时；分别报告随机页序和顺序页序、同值页和普通压缩页；用已驻留页做同路径的计时校准。
- 测试：部分回收、无回收、测量线程迁移、控制页缺页、随机内容、真实内容、同值内容。

**真实应用**：

- taskstats 的 swapin 延迟（本配置 TASK_DELAY_ACCT=y，运行时打开 `kernel.task_delayacct`）：记账区间在 `swap_read_folio()` 内，只给出该读路径的总时间和次数，是辅助指标，不能代替完整缺页或应用恢复耗时。
- 单次调用耗时用 tracefs 的 function_graph：分两轮测量，每轮的 `set_ftrace_filter` 只写一个函数（`do_swap_page` 或 `swap_read_folio`），并设 `max_graph_depth=1`（`set_graph_function` 不限制插桩范围，打开后全系统所有函数都会经过钩子，扰动测量）。两个函数放在同一过滤器里、depth=1 时，在 `do_swap_page` 内部调用的 `swap_read_folio` 位于第 2 层，不会被记录（`kernel/trace/trace.h:1056–1065`）；确实需要同轮关联时，两个都过滤并设 depth=2，先验证嵌套和入口、返回的配对完整。测量前记录并显式设置 `sleep-time`、`trace_clock`、过滤器和缓冲大小；验证跨 CPU 的时间一致后，才把结果解释为含睡眠和抢占的墙钟时间。调度延迟可以用 sched 事件解释，但不能从用户可见的墙钟时间中扣除。

**抽查**：在 `kprobe_events` 中定义 `do_swap_page` 的入口和返回探针，按线程配对；检查 `kprobe_profile` 的 missed 次数和缓冲丢失。本内核没有 HIST_TRIGGERS 和 SYNTH_EVENTS，不能在内核内做直方图；确实需要时，做一个测量专用内核，在 `swap_read_folio` 中加直方图通过 debugfs 导出，只用于测量，不进入产品。log2 直方图只能定位数量级，分辨不了 2% 的尾延迟变化；判定用原始时长，或在判定区间有足够细分辨率的统计。

**注意**：

- zram 不走通常的块请求调度路径，不能只看 `block_rq_issue/complete`；
- 内存介质的换入缺页不能只按 major fault 的次数筛选；
- 追踪开关本身要做 A/A，用已知人为等待做计时校验，检查跨 CPU 迁移和缓冲丢失；
- 追踪开销影响 2% 门槛的判定时，改用受 static key 控制的窄 tracepoint 或直方图采集，而不是增加全量日志。

### 4.4 标准场景

- 固定应用版本、数据集和完成条件；应用从 Tizen 官方仓库安装，名单在阶段 0b 确定。
- 场景覆盖：冷启动、热切换、持续播放与合成、后台积累、内存压力与恢复、后台停留很久之后切回前台。
- 每轮的应用顺序、等待时间都写进脚本。
- 分别评估“同等存活应用数下的成本”和“同等内存预算下的容量”。
- 训练场景与验收场景分离。缓存状态、频率策略和温度区间保持可比。

### 4.5 噪声控制

按 1.3 执行。另外每次实验记录板子状态：内核版本、build-id、uptime、温度、调频策略、其他进程。

### 4.6 开机时间

开机时间由几部分组成，与文件大小、压缩方式和内核初始化都有关：

1. **固件和引导加载器**：包括从存储读入内核映像，耗时与文件大小有关。
2. **解压**：耗时取决于压缩算法和解压后的大小。GZIP 压缩率高、解压慢；LZ4 解压快、文件大。两者的净效果要实测。
3. **内核初始化到 init**：取决于内建驱动和 initcall、开机时加载的模块、各子系统的初始化（例如 zram、BTF、SWIOTLB 池）。
4. **用户态到桌面**：取决于 systemd 服务、resourced 等用户态组件。

**两个组别，不得混合**：

- **软件重启组**：Codex 通过 sdb 重启（RULES.md 第 4 项），可以自动化、做多次，作为日常 A/B 的主要数据。
- **断电冷启动组**：sdb 重启不等于断电冷启动（固件初始化、存储缓存状态都不同）。冷启动组由用户断电上电，或用户提供可控电源（见第 6 章硬件需求）后自动化；只对入围的最终候选执行，轮次较少。
- 报告分别给出两组结果；冷启动组设施不可用时，不能宣称某方案已通过全部开机门槛。

**分段方法**（按可用性依次选择，正式 A/B 中所有变体用同一种方法）：

1. **串口上能看到的引导加载器输出**：本镜像的启动参数为 `loglevel=4`，串口上没有 INFO 级别的内核日志（包括 “Booting Linux”），zImage 解压器自身也没有输出（DEBUG_LL 未开）；修改启动参数不在常规授权内。所以串口只能看到固件或引导加载器自己打印的内容。阶段 0b 先由内网机器采集几次开机的串口原文，确认有没有可用的边界标记（例如读取耗时）；有就采用，没有就不把两条日志之差称为“读取 + 解压”时间。
2. **ARM 通用定时器计数器作为统一时间轴**：它在 SoC 上电后开始计数（RPi4 为 54 MHz），本内核默认允许用户态读取虚拟计数器 CNTVCT（`drivers/clocksource/arm_arch_timer.c` 的 `arch_counter_set_user_access()`，A72 没有需要陷入的勘误）。开机完成时，由同一个用户态程序依次读取 CNTVCT 和 CLOCK_MONOTONIC，两者之差约等于“固件 + 引导加载器 + 读取 + 解压 + 内核计时开始前的初始化”这一整段。软件重启时计数器是否复位，要在板上先确认。这需要推送一个很小的测量程序，不在“perf 及其依赖”的常规授权内，待用户授权。
3. **统一的测量补丁**：以上都不可用时，在所有内核变体（包括基线）中加入同一个测量补丁，在 `start_kernel` 开头以 KERN_ERR 级别输出一次计数器值。
4. **内核初始化段和用户态段**：用 dmesg 时间戳（到 init 启动为止）、`systemd-analyze` 和同一个“桌面可交互”标记。`initcall_debug` 只用于定位变慢的原因，不用于判定。

只能可靠标记的分段才单独判定；其余只报告端到端耗时和可观测区间。各变体的串口、日志量和标记方式保持一致；日志量变化本身会影响开机时间。

**串口采集**：开发机没有串口，由内网机器采集：持续记录串口输出并逐行打本机时间戳，只读，不向串口发送任何输入，不干扰串口上已有的 shell。各段时间只在同一份日志内相减，不需要两台机器对时。Codex 记录每次重启的编号，内网侧按开机标记切分，只把逐次开机的分段时间（小体积文本）传出。

**开机自动配网服务**：板子开机默认不配置网络，sdb 连不上。由一个开机服务在 connman 启动后设置固定 MAC 和静态 IP、写入 DNS。这个服务在所有变体中完全相同，属于基线的一部分；它只影响用户态段，并在用户态段的分析中单列。刷新镜像后的一次性准备（扩展分区、卸载 wlandrv-plugin-tizen、mesa、coregl）不放进开机服务，每次刷机后由用户做一次。

**部署方式**（用户已同意只替换内核）：

- **内核实验固定用户态**：只替换 boot 分区的内核映像、设备树和模块分区；**用户态实验固定内核**和其他用户态组件，只改变目标组件。
- 第一次替换前，先只读调研启动链：分区布局、引导加载器、启动参数中 `partition_ab=a` 所代表的 A/B 槽位机制、RPi 固件的一次性试启动（tryboot）是否可用、QB 内核 RPM 的安装文件清单。由 PM 审核替换和回退方案后再动手。
- 替换前备份当前可用的内核文件，并核对哈希；优先使用一次性试启动或备用槽位，新内核起不来时下一次开机能自动回到可用内核。
- 每次替换后核对运行内核的 build-id（不能只看 uname、/proc/version 和配置，同一版本号、同一配置的两个变体它们完全相同），以及内核、设备树、模块、外置 BTF 的配套清单和哈希；改变内存布局的实验同时保存启动参数和实际的内存边界。
- 新内核起不来且无法自动回退时，停下报告，由用户处理。

## 5. 实验计划

| 阶段 | 内容 | 前提 | 产出 |
| --- | --- | --- | --- |
| 0a | 只读盘点（不依赖场景）：`/proc/cpuinfo` 的 Hardware 行和启动日志中的 Zone ranges、各 memcg 实际 swappiness、所有进程的 `oom_score_adj`、btrfs 的 udev 规则、SWIOTLB 池位置、/opt/usr 的 F2FS 是否启用压缩、resourced 是否发送低内存事件、是否使用 cgroup 冻结；栈保护探测修复（3.1.2）的离线构建和对象级核对 | 无 | 平台事实清单；修复后的内核产物 |
| 0b | 部署设施：开机配网服务、启动链调研和只替换内核的方案（经 PM 审核）；标准场景脚本、换入微基准、测量工具和 perf 临时部署流程固化；判定程序的模拟数据检查；开机时间分段方法（4.6）的验证；function profiler 能否开关（有记录、可恢复的测量动作） | 0a（部分可并行准备） | 可重复的测量和部署设施 |
| 0c | 在修复后的内核上建立基线：标准场景下的 zoneinfo、vmallocinfo（地址区间、最大空洞、峰值）、slabinfo（含合并组和 zsmalloc 相关 cache）、SWIOTLB 高水位和回弹统计、非 CMA 低端内存低谷；追踪开销测量；A/A 试跑（含布局扰动构建）和样本量估算；开机时间基线（软件重启组，冷启动组视设施而定）；测量专用内核（MEM_ALLOC_PROFILING） | 0b | 冻结的基线；统计方案；低端内存压力的实测结论 |
| 0（并行） | 帧指针快速实验的离线部分：`-Xclang` 构建和对象、EHABI 核对（3.1.1）。运行和收益比较等基线冻结后再做 | 无 | 帧指针的静态数据 |
| 1 | zram 算法可用性与配置闭环（3.4.1）；逐因素对照（3.4.2，含 LZ4HC）；成本账本（3.4.3）；设备级轮次和 `cond_resched` 补丁（3.4.4）；跨区保护参数与 CMA 分配阈值（3.3.1）；主动内存整理（3.3.7）；min_ttl_ms（3.5.1） | 0c | zram 方案结论；低端内存参数结论 |
| 2 | 独立配置裁剪及组合变体（3.2，BTF 除外）；BTF 依赖清单；链接期死代码消除（3.1.4，保留和关闭 FUNCTION_TRACER 两种构建，并回移植 0043ecea2399）；TRIM_UNUSED_KSYMS（3.1.7）；vmalloc 区（3.3.2）；SWIOTLB（3.3.4）；SLUB 保留（3.3.5）；用户态主动归还（3.6.1）；zsmalloc 碎片（3.6.2）；KSM 重复量测量（3.6.3）；地址空间划分（3.3.3，先只看数据）；内核映像 LZ4 压缩（3.1.6，低优先级）。静态体积测量不必等 0c 完成 | 0c（运行时部分） | 每项的实际节省（含低端内存和 slab）和产品取舍表 |
| 3 | -pg 不强制帧指针（3.1.1：快速实验有收益才做编译器 PoC 加内核探测）；调度参数 HZ=250、完全抢占（3.8）；安全配置对齐之后的 GCC 与 Clang 内核运行时对比 | 0c | 补丁和对比报告 |
| 4 | 开头先做函数热度集中度分析和全局 Os 对照点（3.7 的最小实验）；局部内联膨胀（3.1.3）；热函数重排（依赖分段和链接验证）；冷代码白名单（依赖覆盖范围明确的调用计数）；sample profile 消费（依赖转换链验证）；小尺寸透明大页（7.6，依赖基线和受控应用接口） | 各项自身的前提 | 各项继续或停止的结论 |
| 5（PoC） | MGLRU-FG 回移植评估（3.5.2）；ARM32 LTO 可行性（3.1.5）；第 7 章中选定的探索项 | 阶段 1 | 可行性、收益上限、退出条件 |

- 每个阶段独立过门槛；配置、算法、编译器的变化组合后要重新验收。只有最终采用帧指针变体时，才基于该变体重新采样和验收。
- 高风险 PoC 不阻塞成熟方案落地，其估算收益也不计入年度承诺。
- 阶段 1、2 可以交替使用板子，但同一块板上的实验不能同时运行。阶段 3 的编译器修改在开发机上完成，最后再上板验证。

## 6. 风险与待确认事项

| 事项 | 影响 | 处理 |
| --- | --- | --- |
| RPi4 不等于 TV 产品 | 配置裁剪、zram、地址空间划分的结论能否用于产品 | 关键结论在产品级开发板上复核 |
| 产品内核由谁维护 | 改动能否进入产品 | 在 sandbox 上完成并验证后，再与相关负责人讨论是否采纳 |
| perf 每次都需要临时部署 | 阶段 0c 以后频繁使用 | 已常规授权，任务 5c 的流程写入 RULES.md；下一次 QB 镜像考虑加入 perf 包 |
| 运行时参数修改 | 调频策略、lowmem_reserve_ratio、min_ttl_ms 等实验都要写 `/proc/sys`、`/sys` | 已常规授权；修改前记录原值，结束后恢复并回读确认，同一块板上不并行做两组参数实验 |
| 低端内存和内核虚拟地址空间耗尽 | 实验可能导致分配失败或内核不稳定 | 每项实验设停止条件；保留可恢复的实验镜像 |
| 重压缩与前台竞争、TTL 提前 OOM、算法初始化顺序 | 前台卡顿、后台被杀、zram 初始化失败 | 见 3.4、3.5 的验证项 |
| 模块打包与恢复路径 | 裁剪后恢复模式或升级失败 | 3.2 的验证项 |
| 采样数据过拟合、组合改动的收益重叠 | 收益被高估 | 训练与验收分离；组合后重新验收 |
| 板子与其他工作线共用 | 噪声，测试相互干扰 | 实验期间独占板子；记录其他进程（例如已有的串口 shell） |
| 标准场景需要写 /opt 分区（安装测试应用） | 与“不改系统”的规则有冲突 | 待用户确认是否纳入常规授权；resourced 和内核的改动通过 QB 镜像 |
| 启动参数修改 | 常规授权不覆盖 boot 分区命令行（vmalloc=、swiotlb=、alloc_in_cma_threshold） | 通过镜像或由用户执行；zram 运行时重配已登记为 RULES.md 第 3 项 |
| 开机时间的分段与冷启动 | `loglevel=4` 下串口没有内核标记；sdb 重启不等于断电冷启动 | 按 4.6 的顺序选择分段方法；冷启动组需要用户或可控电源 |
| 外置 BTF 与运行内核不一致 | CO-RE 静默使用错误的结构偏移，数据错误 | 同一次构建生成、与内核同包发布，加载前比对运行内核的 build-id（3.2） |
| 编译器 `-pg` 放开条件不当 | 用户态 `-pg` 程序的旧式 mcount 读到无效帧指针而崩溃 | 只在带 `-meabi gnu` 时放开（3.1.1） |
| 只替换内核的部署 | 新内核起不来时板子变砖，需要用户介入 | 先只读调研启动链和回退机制；备份可用内核；优先一次性试启动或备用槽位 |
| 开机实验的可达性 | 重启后网络没起来，sdb 连不上，实验中断 | 开机自动配网服务先由用户在场时做一次重启验证；之后 Codex 每次重启都设超时，连不上就停下报告 |
| 编译器改动的影响面 | 平台上其他使用 `-pg` 的程序 | 只在带 `-meabi gnu` 且显式选择时生效（3.1.1）；使用独立版本的工具链做实验 |
| 无法核实的事项 | — | 产品 BOM 和硬件压缩能力；CMA 的实际来源；网络监控插件在产品中的触发条件；resourced 静默回退的真实执行路径。保留为待调查，不预先认定为缺陷或可裁剪 |

**硬件需求**：

- 高质量的采样优化需要分支数据。armv7l 产品板到位后，先只读确认它的 CPU 型号、PMU 能力，以及 SoC 是否开放 CoreSight ETM/PTM（设备节点、设备树、内核配置）。
- 断电冷启动组需要反复给 RPi4 断电上电。如果能提供一个可由开发机控制的电源开关（例如带接口的智能插座或 USB 继电器），冷启动也能自动化；否则由用户手工执行，只做少量轮次。

## 7. 后续研发储备（探索性方案）

本章是基于本平台特点提出的方案，上游没有对应实现，**不是已验证的收益，不计入本轮承诺**。每项先做最小验证实验，结果不成立就停止。等第 3 节的方案实现后再排期。

### 7.1 可恢复游标、可取消的重压缩

- **问题**：`recompress` 每次从槽 0 开始扫描，`max_pages` 只限制重压缩次数，不限制扫描长度；候选稀少或对象已经处于次级算法时，多次分批提交会反复扫全表。TV 在重压缩开始后收到遥控器的切换事件，也没有任务级的取消机制。
- **设计**：每个设备增加任务编号、扫描游标和状态，不增加每槽字段。
  - 每批同时限制扫描槽数、压缩次数和墙钟时间，下一批从游标处继续；
  - 取消入口只更新独立的任务状态，不等待扫描工作持有的长时锁；工作线程释放槽锁后检查取消；
  - reset 先请求取消并等工作退出，再进入设备重置；重配算法、销毁设备同样处理，不允许销毁仍被工作引用的对象；
  - 读写仍使用现有槽锁和空闲检查，避免处理已经被复用的槽。
- **粗估**：设一次全表扫描耗时为 T，分 20 批且每批从头扫时，扫描成本接近 20T；用游标后同一轮接近 T。实际收益取决于候选分布。设备级状态只有几十字节，仍然不需要 ACTIME 的约 4.55 MiB。
- **风险**：与 reset、关闭、CPU 热插拔的生命周期竞态；公平性；取消的响应上界包含当前这一页的处理时间，不能承诺立即停止；旧 sysfs 接口的兼容。
- **最小实验**：先只给现有循环增加“扫描槽数、实际尝试数、耗时”统计，构造稀疏冷页和大量已重压缩的对象；重复扫描占比明显时，再实现游标原型。

### 7.2 按净物理收益和区域压力结算主动回收

- **问题**：`force_reclaim` 返回成功不代表达到了请求量；回收一页匿名页后，zram 仍保留压缩后的载荷；HighMem 占大多数时，释放 HighMem 不一定能缓解低端内存压力。resourced 只看逻辑回收页数，可能持续做低收益的工作。
- **设计**：不改 victim 选择，不引入 ML。
  - resourced 发起的回收分小批执行，记录请求页数、实际回收页数、匿名和文件来源、CPU 时间、zram 物理页变化、各区压力；
  - 实验内核增加按区域的归属计数，不能用并发系统中的 LowFree 差值冒充；
  - 回收的原页及其区域归属用精确计数；zram 池的变化在有其他写入、释放或 compact 同时发生时只是窗口估计，要同时记录并发活动，不把其他应用的释放记到本批头上；
  - 先观察估计值的稳定性，再决定是否按“每毫秒净释放字节”闭环控制；低端内存紧张而本批主要释放 HighMem 时，停止无效追加；
  - 保留旧接口语义，新增统计接口。
- **粗估**：回收 128 MiB 匿名页、压缩比 2.5:1 时，忽略碎片和元数据，净收益约 128 − 128/2.5 = 76.8 MiB，而不是 128 MiB。
- **风险**：并发分配使归因困难；反馈延迟可能造成振荡；不能为了省 CPU 错过必要的应急回收。
- **最小实验**：只加统计、不改策略，跑固定前后台场景，看逻辑回收量与净收益是否稳定偏离、与低端内存压力是否相关；没有明显偏离就不做控制器。只读统计可以在阶段 1、2 先做。

### 7.3 场景驱动的内存策略编排（resourced，不用 ML）

- **问题**：TV 场景流程固定，但 swappiness、水位、zram 重压缩等参数是全局静态的；回收和重压缩的成本可能落在前台路径上。
- **设计**：利用 resourced 已有的状态钩子（屏灭、待机、前后台切换），用单一状态机仲裁策略：定义前台事件的优先级、最短驻留时间（迟滞）、工作预算和退出时的恢复。先只改变一个后台动作，验证后再组合。例如：
  - 待机或屏灭时：标记空闲加分批重压缩、提高后台组的 swappiness、主动回收；
  - 视频播放前：提前回收后台冷页；
  - 前台交互时：收紧后台工作。
  全部使用现有 sysctl、memcg、zram 接口，不改内核。
- **粗估**：把回收和重压缩的 CPU 成本移到空闲窗口，方向上可以降低场景切换的最慢 1% 延迟和 PSI full 时间；具体比例无依据，以实验为准。
- **风险**：策略错配导致前台 refault 抖动；每个切换点的参数都要逐个 A/B 定值。只用现有接口时，只能停止提交后续批次，不能取消已经进入的 sysfs 重压缩调用（3.4.4）。测试遥控器连按、待机后立即唤醒、视频持续播放、服务重启后的恢复，确认参数不会停留在错误状态。
- **最小实验**：用脚本模拟“前台交互、待机、回前台”，在待机段手工执行标记加重压缩，对比回前台时的切换耗时和 refault。不改 resourced 就能判断方向。

### 7.4 切回前台前的预换入

- **问题**：TV 的切换流程固定，切回某个应用之前往往已经能预知；切回时集中换入是切换耗时的一部分。
- **依据**：HPCA 2025 的 Ariadne 在 Pixel 7 上报告平均恢复延迟下降 50%（其他平台的整体系统结果，不是本方案的收益）。`process_madvise()` 支持 `MADV_WILLNEED`，6.12 对匿名映射的换出项会调用 `read_swap_cache_async` 读入 swap cache，不需要改内核。但它通常不替目标进程安装 PTE（切回时仍有 minor fault），在 zram 同步读路径上，发起调用的一方还可能直接承担解压时间。
- **设计**：resourced 在已经确定即将切回某应用时，由专用工作线程对它稳定的关键匿名区域分小批发 `MADV_WILLNEED`，设截止时间和严格的内存预算；检查 pidfd、地址范围生命周期、ptrace/LSM 权限和 CAP_SYS_NICE；不改页面置换策略。
- **粗估**：评审方估算可缩短切换关键路径 0.05–0.4 s。如果恢复耗时的 30% 来自换入、提前完成其中一半，理想情况下可隐藏约 15%，同时会增加峰值驻留；按 1.4，内存峰值必须通过门槛，预取预算据此确定。
- **风险**：预测错误会白白占内存，并可能触发回收；与 UI 争 CPU；地址空间随机化和映射生命周期问题。
- **最小实验**：比较三种方式的收益上限：远程 `MADV_WILLNEED`、应用自己访问已知关键区域、应用内调用 `MADV_POPULATE_READ`（它不在本树远程 `process_madvise` 的允许列表中，只能由应用自己调用）；记录调用方 CPU、剩余 minor fault、有效预取比例、额外驻留、p99 延迟。局部性没有被证明之前，不做内核改动。

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
- **最小实验**：先选存在明确分支或内联决策不确定性的 2–3 个对象，记录新增的边信息导致的具体代码生成变化；没有改变代码生成，或收益不超过插桩带来的训练扰动，就不扩大范围。同时保存训练扰动、正式无插桩代码和 EHABI 增量，不只看训练镜像的速度。

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
- **粗估**：如果某启动阶段 10% 的时间花在可摊销的缺页固定开销上，16 KiB 页的理想上界约为 10% × (1 − 1/4) = 7.5%，实际会更低。这是性能候选；按 1.4，内存（含峰值）不能因此回退，内核体积变大在报告中写明。
- **风险**：稀疏访问导致驻留放大、写时复制和高阶分配压力。本 ARM32 配置不能启用 THP_SWAP（它依赖 64BIT），大 folio 换出时需要先拆分，不能拆分时影响回收；本项只验证匿名首次触页的收益，同时记录拆分页数、拆分失败、回收延迟和之后 4 KiB 换入的行为，不把整块换出的收益计入预算。另外，6.12 对同步 IO 的 swap 设备（zram）支持大 folio 换入，会整个大页一起解压，要统计每次缺页实际解压的页数；打开 THP 会编入 huge_memory、khugepaged 等代码，这部分静态体积和低端内存开销要报告；khugepaged 线程只在启用 PMD 大页时才启动（`mm/khugepaged.c` 的 `hugepage_pmd_enabled()`），只启用小尺寸 madvise 时检查实际线程，不预计它必然存在。ARM32 THP_SWAP 关闭与同步换入的大 folio 路径分别验证，不能互相推导。初始配置为 TRANSPARENT_HUGEPAGE=y、TRANSPARENT_HUGEPAGE_NEVER=y。
- **最小实验**：先做密集匿名分配的微基准，再做真实启动和切换；超过内存 3% 门槛就停止扩大范围。放在阶段 4。

### 7.7 Clang ARM 的“指令集与调度 CPU 分离”

- **问题**：内核按通用 armv7-a 编译（`arch/arm/Makefile:64`），指令调度没有针对 Cortex-A72。Clang 22.1.8 的 ARM 驱动直接忽略 `-mtune`（`clang/lib/Driver/ToolChains/Arch/ARM.cpp` 中留有 TODO，并吞掉该参数，不给警告），所以“加一行 `-mtune=cortex-a72`”的实验什么都没改；`-mcpu=cortex-a72` 又会同时改变目标指令能力，不能悄悄替代。
- **设计**：
  1. 驱动解析并校验独立的调度 CPU，通过 IR 属性传递；
  2. ARM 的 TargetMachine 在 subtarget 缓存键中纳入调度 CPU；
  3. ARMSubtarget 分开使用“指令集 CPU 与特性”和“调度模型”（`llvm/lib/Target/ARM/ARMSubtarget.cpp` 当前把同一个 CPU 同时用作调度 CPU）；
  4. 先限定 ARM 模式、当前软浮点内核约束和 A72，默认行为不变。
  调优的最终目标应当是**产品 SoC 的 CPU**，而不是替身板的 A72；A72 上的结果只用来验证机制，产品 CPU 的收益要在产品板上测。
- **粗估**：假设受调度影响的热点占总时间 20%、局部改善 2%–6%，总收益约 0.4%–1.2%，也可能为零。
- **风险**：某些 CPU 特性同时带有语义和性能假设，拆分错误可能生成不支持的指令或改变 ABI；subtarget 缓存不能混用。
- **最小实验**：先用 GCC 的 `-mtune=cortex-a72`（GCC 支持）对 2–3 个热点对象做独立实验，判断调度是否有潜力；有潜力再做 Clang 的对象级原型，检查 IR、反汇编的指令集、栈和 EHABI，用硬件 cycles 按固定工作量比较。先不重编整套系统。

### 7.8 BTF 在初始化时转存到 HighMem（必须保留内核 BTF 时）

- **问题**：只有在 3.2 的依赖清单表明产品必须保留内核 BTF 时才考虑。BTF 段 6.48 MB 常驻低端内存。目标是把它移出低端内存，而不是减少总内存。
- **设计**：ARM 的 `change_memory_common()` 只允许修改模块区和 vmalloc 区的页属性，其他地址一律返回 -EINVAL（`arch/arm/mm/pageattr.c:66–68`），所以不能把内核映像只读区里的 BTF 页改为可写再释放；`.BTF` 现在位于 `RO_DATA` 中（`arch/arm/kernel/vmlinux.lds.S:72`），在 `__init_begin`（`:90`）之前。唯一能在运行时整体释放的映像区域是 init 区，它由 free_initmem 释放。做法是修改 ARM 链接脚本，把 `.BTF` 移进 init 区，在 free_initmem 之前（例如 late_initcall），且在任何长期使用 BTF 的组件建立类型引用之前，把它复制到长期的 vmalloc 映射。解析器、sysfs、模块的基础 BTF 都只引用这个稳定地址；交接完成后释放原物理页。先不压缩，也不在运行时回收副本。
- **粗估**：如果约 6.48 MB 的原页能全部释放，并且新页实际来自 HighMem，约 6.2 MiB 低端内存转到 HighMem。全机数据量基本不变，还多出少量映射和管理开销，启动时短暂多一份 BTF；按 1.4，全机物理占用和启动峰值必须通过门槛，否则放弃。
- **风险**：`kernel/bpf/sysfs_btf.c` 和 `btf_parse_vmlinux()` 直接引用 `__start_BTF`，都要改为指向副本（`.BTF_ids` 只保存类型编号，不受影响）；初始化顺序和早期使用者；只读属性；模块对类型指针的引用；vmalloc 地址空间；必须按物理页号验证新页确实在 HighMem，不能把“允许 HighMem”当作已转移。启用 BTF_MODULES 时，加载带 BTF 的模块也会请求 vmlinux BTF，第一次使用可能就在开机阶段。
- **最小实验**：先列出所有 BTF 使用入口及第一次调用的顺序，再做一次复制的原型；确认 free_initmem 之后“Freeing unused kernel memory”增加约 6.3 MiB，`/sys/kernel/btf/vmlinux` 的内容哈希与构建产物一致，free_initmem 之后加载带 BTF 的模块正常。启动前的使用者难以统一时，不继续。kallsyms 表的同类做法见 7.15。
- **压缩存储**：转存通过后，再评估压缩存储、首次使用时解压是否值得。注意：解析后的类型指针会长期引用解压后的数据，不能随意重新压缩释放；保留压缩段又生成解压副本时，总内存可能增加。

### 7.9 跨应用重复的只读运行时数据改为共享映射

- **问题**：不同 TV 应用可能各自生成相同的运行时元数据、字典或解析表。它们是活对象，3.6 的归还释放不了；进入 zram 后还会保存多份。fork 共享解决不了 fork 之后各自生成的数据。
- **设计**：先找出确实重复、长期不变的数据区域；由共同的运行时生成带版本标识、不含进程绝对指针的只读数据映像，用 sealed memfd 或产品只读文件共享映射。每个进程的可变状态另外存放；更新时创建新版本，不修改旧映射。
- **粗估**：如果 5 个进程各有 8 MiB 相同的活数据，共享后理论上少驻留 (5 − 1) × 8 = 32 MiB；如果原本都已按 2.5:1 压缩，对应的压缩载荷上界约 12.8 MiB，两者不相加。不承诺低端内存直接下降。
- **风险**：真实重复率可能很低；要排除已有的共享库和共享映射；指针重定位、版本一致性、SMACK 权限、修改频率，以及共享后的回收和换入行为。
- **最小实验**：先用 3.6.3 的 KSM 测量得到跨进程重复量的上界；再在固定 TV 流程中，由可控进程导出候选只读数据的页哈希和生命周期，排除零页、已共享页和敏感内容，先估计重复上界；达到预定收益门槛才做一个运行时数据结构的共享原型。不扫描、不合并任意应用的堆。

### 7.10 resourced 感知低端内存压力

- **问题**：resourced 现有的阈值按全机内存计算。HighMem 占大多数，低端内存可能已经很紧，而 MemAvailable 仍然很高，查杀和回收都不会动作。
- **设计**：resourced 增加非 CMA 低端内存空闲量（LowFree − CmaFree，或 `/proc/zoneinfo` 中 DMA 区的 nr_free_pages − nr_free_cma，同一时刻的快照，不拼接不同时间的读数）和 allocstall_normal 增速作为独立的压力信号，阈值带迟滞；低端内存紧张时，优先采取对低端内存有效的动作（例如释放 slab 密集的缓存、暂停后台的大块内核分配），而不是只做匿名页回收。
- **粗估**：收益取决于标准场景中是否出现低端内存压力（2.3），先测再定。
- **风险**：信号抖动导致误动作；与全机阈值的动作冲突，需要在 7.3 的状态机中统一仲裁。
- **最小实验**：只加日志，不改策略，在标准场景和压力场景下记录两种信号的时序，看低端内存紧张时全机信号是否滞后。

### 7.11 调用方提供稳定 handle 存储，去掉 zs_handle slab

- **问题**：zsmalloc 为每个对象从低端内存的 slab 中分配一个 handle。handle 是稳定的寻址单元，它的内容会因整理和迁移而改变，对象里还反向保存着它（`mm/zsmalloc.c`）；重压缩时先分配新对象、再释放旧对象。所以 zram 槽表保存的是 handle 地址，不能直接删掉这层间接，单个槽也不能不经协议同时充当两个对象的 handle。
- **设计**：给 zsmalloc 增加可选的“调用方存储”模式：槽内单元保存对象位置，单元地址就是稳定 handle，对象反向指向它，迁移沿用稳定引用更新。新写入和重压缩先使用独立的临时 handle，提交时在槽锁和规定的 zsmalloc 锁序下，完成旧对象释放、新对象反向引用和槽单元的原子重绑定；提交前失败则保留旧对象。保留原 API 给其他使用者；reset 在任务和迁移引用归零后才释放槽表；zsmalloc 迁移不能反向获取 zram 槽锁，避免锁序环。
- **粗估**：397,648 个非同值对象、按 8 B 对象步长约 3.03 MiB 常驻 slab（上界量级）；合并 cache 的碎片、未满载和对象分布会降低实际可释放的页；临时 handle 按并发写请求计，要扣除。若需要每槽再加 4 B 字段，槽表会增加约 1.52 MiB，要重新算全机和低端两本账。
- **风险**：跨 class 整理、物理迁移、双对象提交、同值页字段复用和错误回滚；这是协议变更，不是省一次 kmalloc 的小补丁；与上游 zram 重构冲突。
- **最小实验**：先解析 slab 别名，测 zram 的活对象数和实际 slab 页；再只在小型测试池上支持分配、映射、释放、整理，加入两个对象切换和失败注入，最后才接 zram。真实低端节省不足 1 MiB，或需要明显扩大槽表，就停止。

### 7.12 读入冷函数清单的编译器选项

- **问题**：3.7 的冷代码体积优化需要按函数加 `cold`/`minsize` 属性。sample profile 路线有三处不确定（工具链是否可用、PGSO 只作用于部分优化步骤、关中断盲区），体积收益难以预测；手工改源码加属性又无法维护。
- **设计**：用覆盖范围明确的调用计数（function profiler 加 7.14 的首次执行位图）在多个训练场景和开机过程中取得数据，生成冷函数候选清单（未观测到，且排除强制热名单），人工审阅后使用；新增一个 Clang 选项（例如 `-fcold-function-list=<file>`），在前端或早期 IR 步骤中为清单内的函数加上 `cold` 和 `minsize`。清单随内核源码版本管理，可以审阅，也便于回退。
- **粗估**：全局 `-Os` 只是对照点，不是混合优化的上界。冷候选占比按最终符号和段的字节数统计，不按函数个数；先测候选对象实际的缩减率，再给粗估。例如冷候选占 `.text` 字节的 80%、实测缩减 12% 时，约 1.9 MB（估算）。
- **风险**：训练场景没有覆盖的函数被误判为冷，造成长尾回退，用训练与验收分离控制；清单与源码版本错配。
- **最小实验**：先不改编译器，手工标记一个目录测体积；再在 2–3 分钟的场景上打开 function profiler，统计调用次数为 0 的函数占 `.text` 的比例。两者相乘不到 1 MB 就停止。

### 7.13 必需但不热的子系统改为开机加载的模块

- **问题**：低端内存是本平台最紧的资源，而内核映像中有不少必须保留、但不在热路径上的代码。配置裁剪（3.2）只处理“可以不要”的功能，7.8 只针对 BTF。
- **依据**：本平台模块内存经 execmem 以 `GFP_KERNEL` 调用 vmalloc 分配（`mm/execmem.c:21–31`），vmalloc 会自动加上 `__GFP_HIGHMEM`（`mm/vmalloc.c:3652`），所以模块即使开机就加载，代码和数据也位于 HighMem；ARM_MODULE_PLTS=y，模块区放不下时可以溢出到 vmalloc 区。
- **设计**：用调用计数或 7.14 的执行位图，选出调用频率低、体积大的必需子系统改为模块，由开机流程按需加载；不改内核机制，只改配置和开机加载顺序。候选量级（06 中 LLVM 普通版）：net/bluetooth 约 0.52 MB、net/wireless 约 0.60 MB、net/mac80211 约 0.71 MB（是否被本平台使用待确认）、fs/f2fs 约 0.53 MB。
- **粗估**：选出合计约 2 MB 的代码，低端内存约增加 2 MB；全机占用增加几十 KB（页取整和模块元数据）。
- **风险**：热点判断错误时 iTLB 缺失拖慢性能；开机加载拉长开机；F2FS 这类子系统涉及挂载顺序（/usr/lib/modules 本身是一个独立挂载的分区），需要保证模块分区先挂载。
- **最小实验**：只把 Bluetooth 核心改为模块（板上 hci_uart、btbcm 已是模块，net/bluetooth 核心仍是内建），开机后确认模块已加载、模块页位于 HighMem（`/proc/vmallocinfo` 加 `/proc/kpageflags`），比较非 CMA 低端空闲量、开机时间和蓝牙配对、传输的延迟。

### 7.14 首次执行位图训练内核

- **问题**：function profiler 只能在开机后打开，覆盖不了开机阶段；只统计 ftrace 能插桩、且在过滤器范围内的函数；每次调用都做一次哈希查找，开销大，会扰动训练场景（3.7）。
- **设计**：训练内核用 Clang 的 `-fsanitize-coverage=func,inline-bool-flag,pc-table` 编译。每个函数入口有一个 1 字节标志，第一次执行时置 1，此后不再写入；pc-table 把标志映射回函数地址。沿用 KCOV 的 `KCOV_INSTRUMENT := n` 排除规则，避免插桩 noinstr 等敏感路径；增加约百行的训练专用补丁，用 debugfs 导出标志区和 pc-table。内核一启动就开始记录，开机阶段和关中断区间都能覆盖。冷函数候选 = 多个场景加开机过程中都没有置位的函数，交给 7.12 使用。
- **粗估**：本身不带来体积收益，但让冷函数清单覆盖开机过程，训练开销远低于 function profiler。
- **风险**：Clang 对 ARM32 内核做这种插桩是否可用需要实测（本平台 KCOV 未启用）；插桩改变代码布局，训练内核不能用于性能验收；被内联的函数没有独立标志。
- **最小实验**：只对一个目录（例如 `net/bluetooth`）加上述编译参数，开机后从 debugfs 读出位图，与该目录的 function profiler 结果对比；确认一个开机时只执行一次的 probe 函数被正确置位。

### 7.15 kallsyms 表与 BTF 一起在初始化时转存到 HighMem

- **问题**：除 BTF 外，kallsyms 的几张表（`kallsyms_names` 1,841,884 B、`kallsyms_offsets` 507,072 B、`kallsyms_seqs_of_names` 380,304 B，合计约 2.73 MB，06 §2 的 LLVM 普通版）也常驻在低端内存的只读区里，只在 oops、perf 符号解析、`/proc/kallsyms`、kprobe 注册时访问。
- **设计**：按 7.8 的方式把这些表放进 init 区，在 free_initmem 之前复制到 vmalloc，并改用副本的指针；复制前（开机早期）出现的 oops 仍使用原表。
- **粗估**：约 2.7 MB 低端内存移到 HighMem，与 7.8 合计约 9 MB；全机占用基本不变。与关闭 KALLSYMS_ALL（3.2）有重叠，先关 KALLSYMS_ALL 时这里的收益约减半。
- **风险**：kallsyms 的表由 link-vmlinux.sh 多遍链接生成，移动段的位置可能影响多遍链接收敛；panic 和 oops 路径会访问 vmalloc 映射。
- **最小实验**：先只移动 `kallsyms_names` 一张表，确认多遍链接收敛、`/proc/kallsyms` 内容一致、free_initmem 释放量增加相应大小，再扩展。

### 7.16 重压缩“短锁快照、锁外压缩、校验后提交”

- **问题**：7.1 的游标和取消只能控制页与页之间；当前一页的解压、慢压缩和新对象分配仍持有槽锁，同一槽的前台读取会被挡住。现有 sysfs 重压缩是同步调用，已经进入的调用不能被取消（3.4.4）。
- **设计**：在槽锁下把内容快照到设备工作缓冲，解锁后压缩并分配候选对象；重新加锁，确认槽的代次、内容身份、空闲状态和任务代次都没有变化才提交，否则丢弃候选。写入、释放、复用和访问标记路径都要参与代次检查；不能只比较 handle 地址，以防 ABA。取消时释放候选；reset 等待任务退出。先不改现有压缩流的锁模型。
- **粗估**：若实测单页持锁 100 μs、其中 80 μs 是压缩和分配，同一槽的阻塞理想上可从约 100 μs 降到约 20 μs 加提交成本（示例拆账，不是实测）。
- **风险**：并发写导致无效压缩；生命周期和锁序复杂；现有压缩流仍可能关抢占，不能宣称解决了同一 CPU 上的全部调度延迟。
- **最小实验**：先统计槽锁持有的各子阶段，以及真正发生的前台冲突；没有显著冲突就停止。

### 7.17 HighMem 回退时的非 CMA 独立预算

- **问题**：全区的 lowmem_reserve 混合了 CMA 和普通页，`alloc_in_cma_threshold` 只控制取页偏好，都不能明确保护非 CMA 页（2.3）；resourced 看到压力再行动又偏迟。
- **设计**：只针对 HighMem 可移动请求回退到 DMA 区的路径增加双预算：非 CMA 普通页空闲低于独立保留量时，优先或限定从可迁移的 CMA 取页；CMA 也满足不了时，回到原有的 HighMem 回收或失败策略，避免继续消耗普通低端页。GFP_KERNEL 和紧急分配的语义不变；要处理每 CPU 页缓存、阶数、水位并发和分配标志。不修改页面置换。
- **粗估**：若基线高压时非 CMA 低谷为 8 MiB、目标预算 24 MiB，理论上可少被这类回退消耗约 16 MiB；这不是新增内存，代价是更多 HighMem 回收或 CMA 借用。与调 ratio 的收益不相加。
- **风险**：提前 OOM；CMA 碎片和迁移成本；分配器热路径开销。
- **最小实验**：只加按 GFP、区域、迁移类型分类的观测计数，以及“若采用双预算会拒绝”的影子判定；如果非 CMA 低端的消耗主要来自不可移动的 slab，立即停止本方案。

## 8. 请评审重点关注

1. 1.2、1.3 改写后的门槛（不可回收占用加容量、低端分配失败的 tracepoint 计数、p99 的使用条件、多终点检出力、布局噪声、频率校准）是否正确，在单块 RPi4 上是否可执行。
2. 4.6 的开机时间方法（两个组别、按可用性选择的分段方法、build-id 核对）是否可靠；还有没有更好的分段手段。
3. 1.4 副作用表是否完整，处理是否恰当。
4. 2.3、3.2、3.3 对低端内存的分析（模块内存来自 HighMem、SWIOTLB 在低端、vmalloc 区的可调范围、slab 合并、kswapd 平衡）是否正确，排序是否合理。
5. 3.7 和 7.14 的冷函数识别（覆盖范围、开机阶段、人工白名单）是否可靠。
6. 新增方案（3.3.7、3.4.2 的 LZ4HC、3.6.3、3.8、7.13–7.17）和改写的 7.8、7.11 是否站得住，最小实验能否判定。
7. 第 5 节的阶段划分是否还有依赖问题。

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
- BCM2835/BCM2711 机器描述：[raspberrypi/linux rpi-6.12.y arch/arm/mach-bcm/board_bcm2835.c](https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.12.y/arch/arm/mach-bcm/board_bcm2835.c)；下游 `alloc_in_cma_threshold`：[rpi-6.12.y mm/page_alloc.c](https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.12.y/mm/page_alloc.c)
- Clang ARM 的 mcount 名称：[Targets/ARM.cpp（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/lib/Basic/Targets/ARM.cpp) 第 326–330 行；`-mtune` 被忽略：[Arch/ARM.cpp（llvmorg-22.1.8）](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/clang/lib/Driver/ToolChains/Arch/ARM.cpp) 约第 660 行
- ARM 链接期死代码消除：上游提交 [ed0f94102251](https://github.com/torvalds/linux/commit/ed0f941022515ff40473ea5335769a5dc2524a3f)（v6.11，数据为 zImage）；链接脚本冷热分组修正：上游 0043ecea2399（v6.13，待 Codex 核对后回移植）
- 本轮新增核对（v6.12.80）：[mm/execmem.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/execmem.c) 第 21–31 行；[mm/vmalloc.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/vmalloc.c) 第 3652 行；[arch/arm/mm/pageattr.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/arch/arm/mm/pageattr.c) 第 66–68 行；[arch/arm/kernel/vmlinux.lds.S](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/arch/arm/kernel/vmlinux.lds.S) 第 72、90 行；[kernel/dma/swiotlb.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/kernel/dma/swiotlb.c) 第 334 行；[drivers/block/zram/backend_lzorle.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/drivers/block/zram/backend_lzorle.c) 第 20 行；[mm/zsmalloc.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/zsmalloc.c) 第 329–344 行；[mm/khugepaged.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/khugepaged.c)（hugepage_pmd_enabled）；[mm/page_alloc.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/page_alloc.c) 第 4862 行（mm_page_alloc）；[drivers/clocksource/arm_arch_timer.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/drivers/clocksource/arm_arch_timer.c) 第 983–1006 行；[kernel/trace/ftrace.c](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/kernel/trace/ftrace.c)（没有 function profiler 的启动参数）
- 链接脚本分组修正：[0043ecea2399](https://github.com/torvalds/linux/commit/0043ecea2399ffc8bfd99ed9dbbe766e7c79293c)（v6.13）
- 本轮评审记录：`docs/reviews/design_v3_review_codex.md`、`docs/reviews/design_v3_review_codex_verification.txt`、`docs/reviews/design_v3_review_claude_code.md`
- THP_SWAP 依赖 64BIT：[mm/Kconfig（v6.12.80）](https://raw.githubusercontent.com/gregkh/linux/v6.12.80/mm/Kconfig) 第 863–865 行；[libbpf v1.6.2](https://github.com/libbpf/libbpf/blob/v1.6.2/src/libbpf.c)

**上游方案（标明状态，核查日期 2026-10-30）**：

- MGLRU-FG：[RFC（2026-05）](https://lkml.iu.edu/2605.0/00922.html)；[v4，17 个补丁，已移出 RFC，在审（2026-10-16）](https://patchew.org/linux/20261016-mglru-fg-v4-0-2106750c0bfa@tencent.com/)。发行版试用和新闻报道只作线索，不作依据
- zram 重构：[v7，15 个补丁，在审（2026-10-25）](https://patchew.org/linux/20261025021839.1542805-1-senozhatsky@chromium.org/)
- swap table：[phase II](https://patchew.org/linux/20251125-swap-table-p2-v3-0-33f54f707a5c@tencent.com)、[phase III](https://lkml.iu.edu/2602.2/02283.html)（基础设施重构，不适合回移植到 6.12，只跟踪）
- Ariadne（HPCA 2025）：[论文](https://arxiv.org/abs/2502.12826)
- 生命周期转换时归还内存：[Android 页面归还指南](https://developer.android.com/topic/performance/memory/guide/page-advice)
- zsmalloc 链长：[6.12 zsmalloc 文档](https://kernel.org/doc/html/v6.12/mm/zsmalloc.html)
- CRAM：[LPC 2026 议程](https://lpc.events/event/20/contributions/2424/)
