# 任务1：内核树与打包现状

> 任务2更新（2026-10-27）：本文第3节仍是 **tizen@42aeefac58ed 的任务1静态表**，源码行号也对应该commit；尚未与GCC最终.config逐项对照。任务2在源码导出/依赖初始化阶段中止，不能把“未改正符号”解释为推导全部正确。本地 lko/base@563c53c427bf 已仅拆入memcontrol修复，当前工作树的该函数与本文历史基线不同。详见 [03_baseline_build.md](03_baseline_build.md)。


采样日期：2026-10-26（Asia/Shanghai）。源码路径为 `$WS/linux-rpi`，本文源码 `文件:行号` 均相对该目录；证据链接相对本报告。只读分析，未运行 make/GBS、未切换内核分支、未访问开发板 shell。配置表是源码/依赖的静态推导，不是板上 `.config` 或运行时 sysfs 实测；工具链探测项明确保留条件。

## 1. 仓库与版本

- 当前分支 `tizen`，跟踪 `origin/tizen`，开始时工作树干净；完整仓库，非 shallow。
- HEAD：`42aeefac58edeb081aff440f0b60be71cbe49755`，作者 Seung-Woo Kim，作者日期 `2026-10-15T15:00:03+09:00`；标题 `drivers: media: pci: hailo: Port Hailo accelerator driver to v4.22.0`。
- origin fetch/push 均为 `ssh://lhmax2025@review.tizen.org:29418/platform/kernel/linux-rpi`。未向其推送。
- `Makefile:2` VERSION=6，`:3` PATCHLEVEL=12，`:4` SUBLEVEL=80；spec `packaging/linux-rpi.spec:15` 同为 6.12.80。
- GitHub 初始 `git ls-remote --symref` 成功且无 refs，工作区原先不是 Git 仓库；已在 `$WS` 建立独立 main 仓库。两个 GBS 配置人工检查和键名/URL 凭据扫描均未发现账号、密码、token，允许上传。

证据：[kernel_initial.txt](../evidence/task1/kernel_initial.txt)、[github_remote_initial.txt](../evidence/task1/github_remote_initial.txt)、[config_credentials_audit.txt](../evidence/task1/config_credentials_audit.txt)。空 GitHub 输出的退出码及复查见 publication_checks。

## 2. 打包和编译路径（仅阅读，未执行）

Tizen RPM spec 为 `packaging/linux-rpi.spec`；`scripts/package/kernel.spec` 是通用 Kbuild 打包模板，不是本项目的 GBS spec。完整带行号证据：[spec_numbered.txt](../evidence/task1/spec_numbered.txt)。

| 项目 | 结论与源码证据 |
| --- | --- |
| RPi4 armv7l | `config_name=tizen_bcm2711_defconfig`（spec:4）；非 aarch64 的 buildarch=arm（:5–9），读取 `arch/arm/configs/tizen_bcm2711_defconfig`（:187）。 |
| aarch64 | 支持；ExclusiveArch 包含 aarch64（:18），buildarch=arm64（:6），同名 arm64 defconfig；安装 Image（:245、:267），arm 则安装 zImage（:269）。 |
| 普通与 RT | 循环构建 arm-rpi4 和 arm-rpi4-rt（:180）；RT 叠加 `kernel/configs/rt.config`（:195），其中 PREEMPT_RT=y、RT_GROUP_SCHED=n（片段:1、:2）。普通版 PREEMPT_VOLUNTARY=y。 |
| LSM | dev_sel=1 选择 selinux.config，dev_wos=1 选择 nosmack.config（:171–178）；会改变最终配置，须固定实验变体。 |
| 配置解析 | `./scripts/kconfig/merge_config.sh -m -O build/${target} ${BASE_CONFIG} ${EXTRA_FRAGMENTS}`；随后 `make O=build/${target} olddefconfig %{?_smp_mflags}`（:199–201）。本任务未执行这些命令。 |
| 内核/DTB/模块 | `make O=build/${target} %{?_smp_mflags}`、同参数 `dtbs`、`modules`（:212–219）；外置输出目录但 spec 还写 localversion-tizen（:181）。spec 没有显式传 ARCH/CROSS_COMPILE，依赖 GBS 目标环境，不能直接当作宿主交叉编译命令照抄。 |
| perf/bpftool/BTF | perf 使用 `WERROR=0`、`EXTRA_CFLAGS="-fPIE"`、`NO_LIBTRACEEVENT=1 NO_JEVENTS=1`（:206）；bpftool（:209）；导出 vmlinux.h（:226）。这些 perf 参数不是内核 KBUILD_CFLAGS。 |
| Clang | `%{?_toolchain: ... %if %{toolchain_is clang} export LLVM=1 ...}`（:165–169，安装阶段:234–238）。Makefile:478–495 选择 clang/ld.lld/LLVM binutils，否则 CROSS_COMPILE+gcc/ld；host 工具也随 LLVM 切换（:423–436）。 |
| 优化/调试 | 默认 `CC_OPTIMIZE_FOR_PERFORMANCE=y`，Makefile:810 为 -O2；-Os 仅在 SIZE 选中时（:813）。本 defconfig 未启用 LTO；DWARF4/BTF 与 tracing 会影响体积和构建成本；未发现 spec 自行启用 AutoFDO/PGO/MLGO。 |
| 并发 | spec 用 RPM `%{?_smp_mflags}`；未来构建必须额外确保不超过 10（本机 nproc/2），本任务没有构建。 |

### 两个 GBS 配置的实际可证差别

`config/gbs_gcc.conf:11` / `:18` 使用 Tizen-Base、Tizen-Unified 的 reference 软件仓库；`config/gbs_llvm.conf:11` / `:16` 使用 Tizen-Base-Toolchain、Tizen-Unified-Toolchain。两者 general buildroot 也不同且均在 `$WS/temp/`。二者只指定仓库和 buildroot，**文件名并不强制编译器**，文件本身没有 LLVM=1、CC 或 _toolchain 赋值。

因此可确定的执行差别是仓库/依赖来源、隔离 buildroot；当 LLVM 仓库提供的 RPM 宏将 `_toolchain` 判定为 clang 时，spec 才走 LLVM=1，并切换完整 LLVM 工具集。否则仍可能走 GCC。实际 GBS 宏展开、compiler RPM 版本与最终参数需要目标构建环境或已有 build log；本任务没有该证据，也未为此运行 GBS。**不能宣称仅更换 conf 已经实测为 Clang 对 GCC。** 同样，BTF/pahole 与 stack protector 的有效值有工具版本前提。

## 3. 关键配置逐项盘点

基准：普通 armv7l，`arch/arm/configs/tizen_bcm2711_defconfig`，简称 D。原始配置：[defconfig_arm_numbered.txt](../evidence/task1/defconfig_arm_numbered.txt)。Kconfig 定义、反向 select：[kconfig_selected_definitions.txt](../evidence/task1/kconfig_selected_definitions.txt)。

表中“走 Kconfig 默认”表示 D 未写此符号；同时处理 choice 和 select，不能一律视为 n。无显式 default 的 bool/tristate 默认 n，但可被 select 拉起；未启用父项的子 choice 也为 n。`HZ_*` 采用 ARM 的 arch/arm/Kconfig，而非其他架构的通用 kernel/Kconfig.hz。下面的推导不是调用配置器所得；依赖编译器/pahole 的项目保留条件。

关键结论：MGLRU 编译并默认启用，完整调试统计关闭；ARM32 未选择 ARCH_HAS_HW_PTE_YOUNG，因此 `LRU_GEN_WALKS_MMU=n`，不能把启用 MGLRU 理解为拥有全部硬件 PTE aging 优化。zram 内建、默认 lzo-rle，仅 LZO 后端，二次压缩/写回/访问时间跟踪均未启用。CRYPTO_LZ4/ZSTD=y 不等于 ZRAM_BACKEND_LZ4/ZSTD=y。

### 内存回收与分配

| 符号（省略 CONFIG_） | D 显式值 / 默认推导值 | 来源和说明 |
| --- | --- | --- |
| `ARM_LPAE` | D:36：`y` | arch/arm/mm/Kconfig:663； |
| `CMA` | D:66：`y` | mm/Kconfig:925； |
| `CMA_SIZE_MBYTES` | D:526：`256` | kernel/dma/Kconfig:189； |
| `DAMON` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:5；DAMON=n；子项受依赖约束 |
| `DAMON_DBGFS` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:87；DAMON=n；子项受依赖约束 |
| `DAMON_DBGFS_DEPRECATED` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:74；DAMON=n；子项受依赖约束 |
| `DAMON_DBGFS_KUNIT_TEST` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:92；DAMON=n；子项受依赖约束 |
| `DAMON_KUNIT_TEST` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:15；DAMON=n；子项受依赖约束 |
| `DAMON_LRU_SORT` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:116；DAMON=n；子项受依赖约束 |
| `DAMON_PADDR` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:35；DAMON=n；子项受依赖约束 |
| `DAMON_RECLAIM` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:104；DAMON=n；子项受依赖约束 |
| `DAMON_SYSFS` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:55；DAMON=n；子项受依赖约束 |
| `DAMON_SYSFS_KUNIT_TEST` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:62；DAMON=n；子项受依赖约束 |
| `DAMON_VADDR` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:27；DAMON=n；子项受依赖约束 |
| `DAMON_VADDR_KUNIT_TEST` | 走 Kconfig 默认：`n` | mm/damon/Kconfig:43；DAMON=n；子项受依赖约束 |
| `HIGHMEM` | D:39：`y` | arch/arm/Kconfig:1214； |
| `KSM` | 走 Kconfig 默认：`n` | mm/Kconfig:728；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LRU_GEN` | D:68：`y` | mm/Kconfig:1240； |
| `LRU_GEN_ENABLED` | D:69：`y` | mm/Kconfig:1249； |
| `LRU_GEN_STATS` | 走 Kconfig 默认：`n` | mm/Kconfig:1255；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LRU_GEN_WALKS_MMU` | 走 Kconfig 默认：`n` | mm/Kconfig:1264；声明 def_bool y，但需 ARCH_HAS_HW_PTE_YOUNG；ARM32 未 select（arch/arm/Kconfig:2 起） |
| `MEMCG` | D:18：`y` | init/Kconfig:998； |
| `MEMCG_V1` | D:19：`y` | init/Kconfig:1006； |
| `PSI` | D:17：`y` | init/Kconfig:673； |
| `PSI_DEFAULT_DISABLED` | 走 Kconfig 默认：`n` | init/Kconfig:693；default n |
| `SHUFFLE_PAGE_ALLOCATOR` | 走 Kconfig 默认：`n` | mm/Kconfig:349；default SLAB_FREELIST_RANDOM && ACPI_NUMA |
| `SLAB_BUCKETS` | 走 Kconfig 默认：`n` | mm/Kconfig:289；default SLAB_FREELIST_HARDENED |
| `SLAB_FREELIST_HARDENED` | 走 Kconfig 默认：`n` | mm/Kconfig:280；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `SLAB_FREELIST_RANDOM` | 走 Kconfig 默认：`n` | mm/Kconfig:272；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `SLAB_MERGE_DEFAULT` | 走 Kconfig 默认：`y` | mm/Kconfig:258；default y |
| `SLAB_OBJ_EXT` | 走 Kconfig 默认：`y` | init/Kconfig:966；MEMCG select；init/Kconfig:1002 |
| `SLUB` | 走 Kconfig 默认：`y` | mm/Kconfig:242；def_bool y |
| `SLUB_CPU_PARTIAL` | 走 Kconfig 默认：`y` | mm/Kconfig:319；default y |
| `SLUB_DEBUG` | 走 Kconfig 默认：`y` | mm/Kconfig.debug:48；default y |
| `SLUB_DEBUG_ON` | 走 Kconfig 默认：`n` | mm/Kconfig.debug:59；default n |
| `SLUB_KUNIT_TEST` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:2704；default KUNIT_ALL_TESTS |
| `SLUB_RCU_DEBUG` | 走 Kconfig 默认：`n` | mm/Kconfig.debug:73；default KASAN_GENERIC \|\| KASAN_SW_TAGS |
| `SLUB_STATS` | 走 Kconfig 默认：`n` | mm/Kconfig:306；default n |
| `SLUB_TINY` | 走 Kconfig 默认：`n` | mm/Kconfig:245；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `TRANSPARENT_HUGEPAGE` | 走 Kconfig 默认：`n` | mm/Kconfig:816；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `TRANSPARENT_HUGEPAGE_ALWAYS` | 走 Kconfig 默认：`n` | mm/Kconfig:840；父项 TRANSPARENT_HUGEPAGE=n |
| `TRANSPARENT_HUGEPAGE_MADVISE` | 走 Kconfig 默认：`n` | mm/Kconfig:847；父项 TRANSPARENT_HUGEPAGE=n |
| `TRANSPARENT_HUGEPAGE_NEVER` | 走 Kconfig 默认：`n` | mm/Kconfig:856；父项 TRANSPARENT_HUGEPAGE=n |
| `VMSPLIT_1G` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1043；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `VMSPLIT_2G` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1041；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `VMSPLIT_3G` | 走 Kconfig 默认：`y` | arch/arm/Kconfig:1036；choice 默认；arch/arm/Kconfig:1029 |
| `VMSPLIT_3G_OPT` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1038；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |

### 压缩内存

| 符号（省略 CONFIG_） | D 显式值 / 默认推导值 | 来源和说明 |
| --- | --- | --- |
| `CRYPTO_842` | 走 Kconfig 默认：`n` | crypto/Kconfig:1149；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `CRYPTO_LZ4` | D:517：`y` | crypto/Kconfig:1160； |
| `CRYPTO_LZ4HC` | 走 Kconfig 默认：`n` | crypto/Kconfig:1171；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `CRYPTO_LZO` | D:516：`y` | crypto/Kconfig:1138； |
| `CRYPTO_ZSTD` | D:518：`y` | crypto/Kconfig:1182； |
| `SWAP` | 走 Kconfig 默认：`y` | mm/Kconfig:15；default y |
| `ZRAM` | D:209：`y` | drivers/block/zram/Kconfig:2； |
| `ZRAM_BACKEND_842` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:41；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_BACKEND_DEFLATE` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:35；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_BACKEND_FORCE_LZO` | 走 Kconfig 默认：`y` | drivers/block/zram/Kconfig:47；其他 zram backend 均 n，def_bool 条件为真 |
| `ZRAM_BACKEND_LZ4` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:17；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_BACKEND_LZ4HC` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:23；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_BACKEND_LZO` | 走 Kconfig 默认：`y` | drivers/block/zram/Kconfig:53；默认 ZRAM_BACKEND_FORCE_LZO=y |
| `ZRAM_BACKEND_ZSTD` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:29；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_DEF_COMP` | 走 Kconfig 默认：`"lzo-rle"` | drivers/block/zram/Kconfig:95；"lzo-rle"；drivers/block/zram/Kconfig:98 |
| `ZRAM_DEF_COMP_842` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:89；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_DEF_COMP_DEFLATE` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:85；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_DEF_COMP_LZ4` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:73；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_DEF_COMP_LZ4HC` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:77；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_DEF_COMP_LZO` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:69；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_DEF_COMP_LZORLE` | 走 Kconfig 默认：`y` | drivers/block/zram/Kconfig:65；choice 默认；drivers/block/zram/Kconfig:62 |
| `ZRAM_DEF_COMP_ZSTD` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:81；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_MEMORY_TRACKING` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:129；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_MULTI_COMP` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:140；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_TRACK_ENTRY_ACTIME` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:121；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZRAM_WRITEBACK` | 走 Kconfig 默认：`n` | drivers/block/zram/Kconfig:107；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZSMALLOC` | 走 Kconfig 默认：`y` | mm/Kconfig:202；声明无 default，ZRAM select；drivers/block/zram/Kconfig:5 |
| `ZSMALLOC_CHAIN_SIZE` | 走 Kconfig 默认：`8` | mm/Kconfig:221；8；mm/Kconfig:223 |
| `ZSMALLOC_STAT` | 走 Kconfig 默认：`n` | mm/Kconfig:211；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZSWAP` | 走 Kconfig 默认：`n` | mm/Kconfig:25；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ZSWAP_COMPRESSOR_DEFAULT` | 走 Kconfig 默认：`""` | mm/Kconfig:117；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_COMPRESSOR_DEFAULT_842` | 走 Kconfig 默认：`n` | mm/Kconfig:92；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_COMPRESSOR_DEFAULT_DEFLATE` | 走 Kconfig 默认：`n` | mm/Kconfig:80；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_COMPRESSOR_DEFAULT_LZ4` | 走 Kconfig 默认：`n` | mm/Kconfig:98；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_COMPRESSOR_DEFAULT_LZ4HC` | 走 Kconfig 默认：`n` | mm/Kconfig:104；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_COMPRESSOR_DEFAULT_LZO` | 走 Kconfig 默认：`n` | mm/Kconfig:86；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_COMPRESSOR_DEFAULT_ZSTD` | 走 Kconfig 默认：`n` | mm/Kconfig:110；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_DEFAULT_ON` | 走 Kconfig 默认：`n` | mm/Kconfig:38；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_SHRINKER_DEFAULT_ON` | 走 Kconfig 默认：`n` | mm/Kconfig:48；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_ZPOOL_DEFAULT` | 走 Kconfig 默认：`""` | mm/Kconfig:165；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_ZPOOL_DEFAULT_Z3FOLD_DEPRECATED` | 走 Kconfig 默认：`n` | mm/Kconfig:149；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_ZPOOL_DEFAULT_ZBUD` | 走 Kconfig 默认：`n` | mm/Kconfig:143；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |
| `ZSWAP_ZPOOL_DEFAULT_ZSMALLOC` | 走 Kconfig 默认：`n` | mm/Kconfig:158；父项 ZSWAP=n，子项不生效；choice 受 mm/Kconfig:65、134 约束 |

### 调度与时钟

| 符号（省略 CONFIG_） | D 显式值 / 默认推导值 | 来源和说明 |
| --- | --- | --- |
| `BPF_JIT` | D:9：`y` | kernel/bpf/Kconfig:42； |
| `BPF_JIT_ALWAYS_ON` | 走 Kconfig 默认：`n` | kernel/bpf/Kconfig:58；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `BPF_JIT_DEFAULT_ON` | 走 Kconfig 默认：`n` | kernel/bpf/Kconfig:69；def_bool ARCH_WANT_DEFAULT_BPF_JIT \|\| BPF_JIT_ALWAYS_ON |
| `BPF_SYSCALL` | D:8：`y` | kernel/bpf/Kconfig:27； |
| `CPU_FREQ_DEFAULT_GOV_CONSERVATIVE` | 走 Kconfig 默认：`n` | drivers/cpufreq/Kconfig:85；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `CPU_FREQ_DEFAULT_GOV_ONDEMAND` | 走 Kconfig 默认：`n` | drivers/cpufreq/Kconfig:72；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `CPU_FREQ_DEFAULT_GOV_PERFORMANCE` | 走 Kconfig 默认：`n` | drivers/cpufreq/Kconfig:47；ARM 分支已先选择 SCHEDUTIL；drivers/cpufreq/Kconfig:40、42 |
| `CPU_FREQ_DEFAULT_GOV_POWERSAVE` | 走 Kconfig 默认：`n` | drivers/cpufreq/Kconfig:55；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `CPU_FREQ_DEFAULT_GOV_SCHEDUTIL` | 走 Kconfig 默认：`y` | drivers/cpufreq/Kconfig:98；ARM choice 默认；drivers/cpufreq/Kconfig:40 |
| `CPU_FREQ_DEFAULT_GOV_USERSPACE` | 走 Kconfig 默认：`n` | drivers/cpufreq/Kconfig:63；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `ENERGY_MODEL` | 走 Kconfig 默认：`n` | kernel/power/Kconfig:362；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `HZ` | 走 Kconfig 默认：`100` | arch/arm/Kconfig:1124；100；arch/arm/Kconfig:1127；不是常见的 250 假设 |
| `HZ_100` | 走 Kconfig 默认：`y` | arch/arm/Kconfig:1104；ARM choice 无 default，首个可见项；arch/arm/Kconfig:1100、1104 |
| `HZ_1000` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1119；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `HZ_200` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1107；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `HZ_250` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1110；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `HZ_300` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1113；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `HZ_500` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1116；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `HZ_FIXED` | 走 Kconfig 默认：`0` | arch/arm/Kconfig:1095；0；非 SOC_AT91RM9200 |
| `HZ_PERIODIC` | 走 Kconfig 默认：`n` | kernel/time/Kconfig:102；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `NO_HZ` | D:6：`y` | kernel/time/Kconfig:184； |
| `NO_HZ_COMMON` | 走 Kconfig 默认：`y` | kernel/time/Kconfig:94；由 NO_HZ_IDLE select；kernel/time/Kconfig:110 |
| `NO_HZ_FULL` | 走 Kconfig 默认：`n` | kernel/time/Kconfig:118；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `NO_HZ_IDLE` | 走 Kconfig 默认：`y` | kernel/time/Kconfig:108；由 NO_HZ=y 选择；kernel/time/Kconfig:100 |
| `PREEMPT` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:51；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPTION` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:92；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPTIRQ_DELAY_TEST` | 走 Kconfig 默认：`n` | kernel/trace/Kconfig:1118；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPTIRQ_TRACEPOINTS` | 走 Kconfig 默认：`y` | kernel/trace/Kconfig:141；IRQSOFF_TRACER=y 选择 TRACE_IRQFLAGS，满足 default y 条件；kernel/trace/Kconfig:346、350 |
| `PREEMPT_BUILD` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:9；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPT_COUNT` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:89；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPT_DYNAMIC` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:96；ARM 未选择 HAVE_PREEMPT_DYNAMIC |
| `PREEMPT_NONE` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:18；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPT_NONE_BUILD` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:3；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPT_NOTIFIERS` | 走 Kconfig 默认：`n` | init/Kconfig:2041；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPT_RCU` | 走 Kconfig 默认：`n` | kernel/rcu/Kconfig:19；default y if PREEMPTION |
| `PREEMPT_RT` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:70；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `PREEMPT_TRACER` | 走 Kconfig 默认：`n` | kernel/trace/Kconfig:370；default n |
| `PREEMPT_VOLUNTARY` | D:10：`y` | kernel/Kconfig.preempt:32； |
| `PREEMPT_VOLUNTARY_BUILD` | 走 Kconfig 默认：`y` | kernel/Kconfig.preempt:6；PREEMPT_VOLUNTARY select；kernel/Kconfig.preempt:35 |
| `SCHED_AUTOGROUP` | D:30：`y` | init/Kconfig:1355； |
| `SCHED_CLASS_EXT` | 走 Kconfig 默认：`n` | kernel/Kconfig.preempt:136；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `UCLAMP_TASK` | 走 Kconfig 默认：`n` | init/Kconfig:837；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `UCLAMP_TASK_GROUP` | 走 Kconfig 默认：`n` | init/Kconfig:1102；default n |

### 编译、体积与调试

| 符号（省略 CONFIG_） | D 显式值 / 默认推导值 | 来源和说明 |
| --- | --- | --- |
| `CC_OPTIMIZE_FOR_PERFORMANCE` | 走 Kconfig 默认：`y` | init/Kconfig:1459；choice 默认，init/Kconfig:1457 |
| `CC_OPTIMIZE_FOR_SIZE` | 走 Kconfig 默认：`n` | init/Kconfig:1466；同一 choice 未选；init/Kconfig:1457 |
| `DEBUG_ATOMIC_SLEEP` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:1560；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_BUGVERBOSE` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:200；default y |
| `DEBUG_FS` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:653；本项 default n；BLK_DEV_IO_TRACE=y select，kernel/trace/Kconfig:648 |
| `DEBUG_FS_ALLOW_ALL` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:675；choice 默认，lib/Kconfig.debug:668 |
| `DEBUG_INFO` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:227；由 DEBUG_INFO_DWARF4 select；lib/Kconfig.debug:273 |
| `DEBUG_INFO_BTF` | D:531：`y` | lib/Kconfig.debug:377；D 写 y；有效值还需 PAHOLE_VERSION>=116 等条件，lib/Kconfig.debug:379–385 |
| `DEBUG_INFO_BTF_MODULES` | 走 Kconfig 默认：`y（有条件）` | lib/Kconfig.debug:412；default y，需 DEBUG_INFO_BTF && MODULES && PAHOLE_HAS_SPLIT_BTF；未核验 pahole，不能确定实际值 |
| `DEBUG_INFO_COMPRESSED_NONE` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:325；压缩 choice 首个可见项；lib/Kconfig.debug:320、325 |
| `DEBUG_INFO_COMPRESSED_ZLIB` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:330；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_INFO_COMPRESSED_ZSTD` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:345；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_INFO_DWARF4` | D:530：`y` | lib/Kconfig.debug:271； |
| `DEBUG_INFO_DWARF5` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:283；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:259；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_INFO_NONE` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:253；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_INFO_REDUCED` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:305；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_INFO_SPLIT` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:357；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_KERNEL` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:211；本项 default n，但 EXPERT=y select；init/Kconfig:1546 |
| `DEBUG_LL` | 走 Kconfig 默认：`n` | arch/arm/Kconfig.debug:111；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `DEBUG_MEMORY_INIT` | D:535：`y` | lib/Kconfig.debug:893； |
| `DEBUG_MISC` | 走 Kconfig 默认：`y` | lib/Kconfig.debug:217；default DEBUG_KERNEL |
| `DEBUG_PREEMPT` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:1331；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `FORCE_RECLAIM` | 走 Kconfig 默认：`不存在` | ；不存在该 Kconfig 符号；代码由 MEMCG_V1 && SWAP 控制，mm/memcontrol-v1.c:2424、3083 |
| `FTRACE` | 走 Kconfig 默认：`y` | kernel/trace/Kconfig:182；EXPERT select DEBUG_KERNEL，满足 default y |
| `FUNCTION_TRACER` | 走 Kconfig 默认：`y` | kernel/trace/Kconfig:200；本项 default n，但 STACK_TRACER=y select；kernel/trace/Kconfig:319 |
| `KALLSYMS_ALL` | 走 Kconfig 默认：`y` | init/Kconfig:1852；无显式 default，但 D:538 LATENCYTOP=y 在 lib/Kconfig.debug:1811 select KALLSYMS_ALL。 |
| `KASAN` | 走 Kconfig 默认：`n` | lib/Kconfig.kasan:34；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LOCKDEP` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:1501；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LTO` | 走 Kconfig 默认：`n` | arch/Kconfig:726；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LTO_CLANG` | 走 Kconfig 默认：`n` | arch/Kconfig:731；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LTO_CLANG_FULL` | 走 Kconfig 默认：`n` | arch/Kconfig:781；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LTO_CLANG_THIN` | 走 Kconfig 默认：`n` | arch/Kconfig:800；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `LTO_NONE` | 走 Kconfig 默认：`y` | arch/Kconfig:776；choice 默认；arch/Kconfig:768 |
| `MODULES` | D:57：`y` | kernel/module/Kconfig:2； |
| `MODULE_COMPRESS` | 走 Kconfig 默认：`n` | kernel/module/Kconfig:283；无显式 default；bool/tristate 默认 n（choice/依赖按上述规则） |
| `MODULE_COMPRESS_ALL` | 走 Kconfig 默认：`n` | kernel/module/Kconfig:324；父项 MODULE_COMPRESS=n，子 choice/默认不生效 |
| `MODULE_COMPRESS_GZIP` | 走 Kconfig 默认：`n` | kernel/module/Kconfig:304；父项 MODULE_COMPRESS=n，子 choice/默认不生效 |
| `MODULE_COMPRESS_XZ` | 走 Kconfig 默认：`n` | kernel/module/Kconfig:310；父项 MODULE_COMPRESS=n，子 choice/默认不生效 |
| `MODULE_COMPRESS_ZSTD` | 走 Kconfig 默认：`n` | kernel/module/Kconfig:316；父项 MODULE_COMPRESS=n，子 choice/默认不生效 |
| `PROVE_LOCKING` | 走 Kconfig 默认：`n` | lib/Kconfig.debug:1351；default n |
| `STACKPROTECTOR` | 走 Kconfig 默认：`y（有条件）` | arch/Kconfig:646；default y；依赖 ARM 支持和编译器 -fstack-protector 探测，未运行探测 |
| `STACKPROTECTOR_PER_TASK` | 走 Kconfig 默认：`y（有条件）` | arch/arm/Kconfig:1379；default y；还需 CURRENT_POINTER_IN_TPIDRURO、GCC_PLUGINS 或 CC_HAVE_STACKPROTECTOR_TLS，保留工具链条件 |
| `STACKPROTECTOR_STRONG` | 走 Kconfig 默认：`y（有条件）` | arch/Kconfig:670；default y；依赖 STACKPROTECTOR 和 -fstack-protector-strong 探测 |
| `THUMB2_KERNEL` | 走 Kconfig 默认：`n` | arch/arm/Kconfig:1137；default y if CPU_THUMBONLY |


### 调试项与 vendor 机制补充

D 中所有显式 `DEBUG_*=y` **只有三项**：DEBUG_INFO_DWARF4（D:530）、DEBUG_INFO_BTF（D:531）、DEBUG_MEMORY_INIT（D:535）。这不等于完整配置只有三个 DEBUG 项：EXPERT 会 select DEBUG_KERNEL，后者使 DEBUG_MISC 默认 y；BLK_DEV_IO_TRACE 会 select DEBUG_FS，DEBUG_INFO_DWARF4 会 select DEBUG_INFO。相关默认/派生项已在表中列出；BTF_MODULES 依赖 pahole，未生成最终 .config，不能将其认定为实测值。

D:532–544 另显式启用 KGDB、KGDB_KDB、KDB_KEYBOARD、DETECT_HUNG_TASK、LATENCYTOP、FUNCTION_PROFILER、STACK_TRACER、IRQSOFF_TRACER、SCHED_TRACER、BLK_DEV_IO_TRACE；这是未来裁剪的具体待评审范围，而不是本任务已禁用的内容。FTRACE 与 FUNCTION_TRACER 静态推导为 y；运行时 tracer 是否启动未查。

没有独立的 CONFIG_FORCE_RECLAIM。`mm/memcontrol-v1.c:2424`、`:3083` 的条件是 `CONFIG_MEMCG_V1 && CONFIG_SWAP`；本基准二者为 y，所以 vendor 接口被编入。原始补丁 `478d7fd169c2d7489bad1d52d69f037e4e830286`，见 [force_reclaim_patch.txt](../evidence/task1/force_reclaim_patch.txt)。

该代码仍以 `true` 传递 reclaim_options（memcontrol-v1.c:2435–2436），而 `MEMCG_RECLAIM_MAY_SWAP=(1<<1)`（include/linux/swap.h:421），`mm/vmscan.c:6607` 按位判定 may_swap。因此静态可证这一调用不会设置 MAY_SWAP；返回 total、整数范围和循环停止条件也已在 `silent-reclaim-fix` sandbox 中修复。本任务仅记录，不修改。接口实际目录名前缀/挂载、调用用户态和影响程度未上板验证。

树莓派层另有启动参数 `alloc_in_cma_threshold`，不是新 Kconfig：mm/page_alloc.c:240–256，默认 12/16，用于降低 CMA 碎片风险；补丁 `e640262c2f69dd56acaf7feae56ab801700fde1a`。Tizen 相对 RPi 分叉点的 mm/Kconfig、mm/Kconfig.debug、mm/damon/Kconfig、drivers/block/zram/Kconfig diff 为空，未发现新增 vendor 回收 Kconfig。证据：[vendor_config_audit.txt](../evidence/task1/vendor_config_audit.txt)。

## 4. 下游边界和提交盘点

### 边界方法与计数口径

1. 用 stable 官方仓库 `git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git 'refs/tags/v6.12.80*'` 核对本地 tag，annotated tag 对象 `fa1f9d71610c58ec2d00ad142472a65aa7647a7e`，peeled commit `00d7934ffcc35e65b113ba4991c8a3338bd85fc1`。`merge-base HEAD v6.12.80` 正是该 commit，说明 stable 是祖先。
2. fetch 官方 `https://github.com/raspberrypi/linux.git` 的 rpi-6.12.y 到 `refs/remotes/raspberrypi/rpi-6.12.y`，不 checkout、不创建/更新本地内核分支、不写 FETCH_HEAD。采样 tip 为 `5bd564aaa8dc4b1b8ed11733c19ec8ece63a72cc`（2026-10-21）；与 HEAD 的唯一 merge-base 为 `49b3f941b664864583064c2ea84b8e3df86ab005`（2026-04-10）。
3. 拓扑集合 `v6.12.80..HEAD` 有 1940 个提交（含 merge），其中同时含 RPi 改动、旧 stable 重放提交和 Tizen 改动，**不把这 1940 条都叫 Tizen 原创补丁**。`rpi-6.12.y..HEAD` 为 119 条；从 merge-base 到 HEAD 得到同一 Tizen 独有集合。不是用作者邮箱或提交日期猜边界，也没有把会漏掉继承补丁的“版本升级 commit 之后”当边界。
4. `origin/upstream` 实际停在 `8f5ff9784f3262e6e85c68d86f8b7931827f2983`（Linux 6.12.41），不能用于代替所要求的 6.12.80 或 rpi-6.12.y。Gerrit symbolic HEAD 指向 master，但本盘点主线为当前跟踪的 tizen，不以 master 作 sandbox 基线。
5. 以下统计排除 merge commit，以 `git log --no-merges` 获取候选、`git diff-tree --name-only -r` 审核路径；fs/ 仅保留页缓存数据/folio/压缩上下文处理，排除纯目录缓存、元数据、网络会话和 namespace。`include/linux/mm*` 按用户指定 glob 保留，因此也包含 mmc/，表中明确其关系是存储而非回收。105 条符合口径（其中 Tizen 独有 19 条），42 条 fs-only 候选被排除，理由清单见证据。

| 范围（非 merge；触及目录的 commit 去重） | mm/ | drivers/block/zram/ | 意义 |
| --- | ---: | ---: | --- |
| stable v6.12.80..HEAD | 14 | 0 | 包含 RPi 层和已重放的 stable 修复，不能全归因 Tizen |
| RPi rpi-6.12.y..HEAD | 2 | 0 | Tizen 独有：force_reclaim + mm/memfd.c 的 kdbus 符号导出 |

zram 配置启用提交不修改 drivers/block/zram/，因此不计入驱动补丁数。与 RPi merge-base 比较，mm/ 最终差异仅 memcontrol-v1.c +36 行、memfd.c +1 行，zram/ 无差异。没有运行性能实验，提交内容不能证明收益。

证据：[upstream_remote_refs.txt](../evidence/task1/upstream_remote_refs.txt)、[rpi_boundary.txt](../evidence/task1/rpi_boundary.txt)、[boundary_initial.txt](../evidence/task1/boundary_initial.txt)、[mm_zram_counts.txt](../evidence/task1/mm_zram_counts.txt)、[downstream_selected_metadata.txt](../evidence/task1/downstream_selected_metadata.txt)、[downstream_fs_exclusions.txt](../evidence/task1/downstream_fs_exclusions.txt)。完整 commit id、作者日期及涉及文件均在元数据证据中；下面日期为 author date，历史补丁 rebase 后可能早于本基线版本。

### Tizen 独有的范围内提交（19 条）

| commit | 作者 | 日期 | 标题 | 涉及目录/文件 | 内容与内存/性能关系 |
| --- | --- | --- | --- | --- | --- |
| `d5ef43b342dc` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2026-10-07 | configs: packaging: modularize defconfig with RT and LSM fragments | arch/arm/configs/ | 统一普通/RT 配置并叠加片段，消除 RT 漏开 MGLRU 等配置漂移。 |
| `b78585126c31` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2026-08-24 | ARM/ARM64: configs: tizen_bcm2711: Enable F2FS compression configs | arch/arm/configs/ | 启用 F2FS 压缩，使压缩文件系统可挂载并改变存储/内存与 CPU 开销。 |
| `529e83fbf904` | Christian Schrrefl &lt;chrisi.schrefl@gmail.com&gt; | 2025-01-31 | ARM: 9441/1: rust: Enable Rust support for ARMv7 | scripts/generate_rust_target.rs | 回移 ARMv7 Rust 目标支持，影响可编译代码范围，不是回收算法优化。 |
| `c0b66bcd342c` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-09 | ARM: configs: tizen_bcm2711: Enable MG-LRU configuration | arch/arm/configs/ | 默认打开 ARM MGLRU，直接改变匿名页/文件页的回收策略。 |
| `4079759cc86f` | Unsung Lee &lt;unsung.lee@samsung.com&gt; | 2025-12-01 | cputime: Export symbol of thread_group_cputime_adjusted for the kernel module | kernel/sched | 导出线程组 CPU 时间统计符号，供外置模块做进程统计。 |
| `952e05b77038` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-09-17 | ARM/ARM64: configs: tizen_bcm2711: Enable CGROUP_BPF config | arch/arm/configs/ | 启用 cgroup BPF，用于容器路径，增加可编程控制能力。 |
| `7a5165a4f8b0` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-09-17 | ARM/ARM64: configs: tizen_bcm2711: Enable DMABUF_HEAPS related configs | arch/arm/configs/ | 打开 DMA-BUF heaps，影响共享缓冲区及 CMA 分配能力。 |
| `91730e1655f5` | Florian Schmaus &lt;flo@geekplace.eu&gt; | 2024-11-02 | kbuild,bpf: Pass make jobs' value to pahole | scripts/Makefile.btf | 让 pahole 遵守 make 的并发数，降低并发 BTF 生成的内存峰值/OOM 风险。 |
| `6f9c2a59325b` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2025-09-03 | ARM/ARM64: configs: tizen_bcm2711: Disable unused configurations | arch/arm/configs/ | 裁掉无使用场景的 TV/tuner/DVB 配置，减少构建与模块体积。 |
| `b7a217f07695` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2025-09-02 | ARM: configs: tizen_bcm2711: Disable NFSD configuration | arch/arm/configs/ | 关闭未使用 NFSD，并规避其 BTF 生成失败。 |
| `5957526f38cb` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-14 | kbuild: Remove unsupported dd option “status=none” | scripts/link-vmlinux.sh | 移除老 coreutils 不支持的 dd status=none，修复链接脚本兼容性，未并行化阶段。 |
| `fc7312683cf8` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17 | ARM/ARM64: configs: tizen: Enable BTF and DWARF4 debug options | arch/arm/configs/ | 启用 DWARF4/BTF，支持 eBPF/调试并增加构建时间和调试信息体积。 |
| `2676158fe0de` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2025-08-12 | ARM/ARM64: configs: Change CONFIG_HCIUART to module from built-in | arch/arm/configs/ | 将蓝牙 UART 改为模块，调整固件加载时序和常驻代码组成。 |
| `ca5195aee1bd` | Hoegeun Kwon &lt;hoegeun.kwon@samsung.com&gt; | 2025-08-12 | ARM: configs: tizen: Enable zram configurations | arch/arm/configs/ | ARM 配置启用 zram 与 crypto 算法，但没有启用新版独立 ZRAM_BACKEND_LZ4/ZSTD。 |
| `9dc5d9b07b0a` | Hoegeun Kwon &lt;hoegeun.kwon@samsung.com&gt; | 2025-07-15 | ARM/arm64: configs: tizen_bcm2711: Enable legacay CGROUP configs | arch/arm/configs/ | 启用旧 cgroup MEMCG/CPUSET 选项，匹配 Tizen v1 用户态控制接口。 |
| `f90421e2aa5d` | Hoegeun Kwon &lt;hoegeun.kwon@samsung.com&gt; | 2025-07-08 | ARM/arm64: configs: tizen_bcm2711: Enable MEMCG_V1 | arch/arm/configs/ | 打开 MEMCG_V1，保留旧内存控制器及 vendor 接口编译前提。 |
| `478d7fd169c2` | Dongwoo Lee &lt;dwoo08.lee@samsung.com&gt; | 2020-08-03 | mm: memcontrol: Add force_reclaim to reclaim tasks' memory in memcg | mm/memcontrol-v1.c | 增加按 memcg 请求回收页数的 force_reclaim 接口，当前参数位语义有静态问题。 |
| `5b793e7c2b34` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2021-11-25 | kdbus: export needed symbols for out-of-tree support | fs/namespace.c, mm/memfd.c | 导出 memfd/namespace 符号供外置 kdbus 使用；涉及 mm 但不改变回收算法。 |
| `03fcf7417e28` | Hoegeun Kwon &lt;hoegeun.kwon@samsung.com&gt; | 2025-06-30 | ARM/arm64: configs: Add the intial tizen defconfig for RPI | arch/arm/configs/ | 导入 Tizen RPi 基础配置，确立后续内存、调度和调试选项的默认基础。 |

### 相对 stable 额外继承的 RPi/重放提交（86 条）

以下均已存在于所取 RPi 历史中，不归为 Tizen 独有；拓扑非同 SHA 不代表 stable 没有等价修复。本任务没有对整个 stable 差集做 patch-id 去重，因此不使用该表宣称发现新缺陷或原创改动。

| commit | 作者 | 日期 | 标题 | 涉及目录/文件 | 内容与内存/性能关系 |
| --- | --- | --- | --- | --- | --- |
| `42c8bbfa4cdd` | Nicolai Buchwitz &lt;nb@tipi-net.de&gt; | 2026-02-25 | configs: enable CONFIG_HID_CP2112=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_HID_CP2112=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `5aa2f4eae2c3` | Kurva Prashanth &lt;krvprashanth@riseup.net&gt; | 2026-02-06 | configs: enable Si5351 i2c common clock driver | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_COMMON_CLK_SI5351=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `30c0c145c51b` | Leonard Lausen &lt;leonard@lausen.nl&gt; | 2026-01-25 | configs: enable CONFIG_CRYPTO_LZ4HC=m | arch/arm/configs/ | RPi 通用配置增加 LZ4HC crypto 模块；不等价于 Tizen zram 后端已启用。 |
| `bf9a557b0c66` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2026-01-25 | defconfigs: Remove vestigial RTL8712 config usage | arch/arm/configs/ | RPi 通用 ARM 配置删除旧项 `CONFIG_R8712U=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `3b2b4267d502` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2026-01-09 | Revert "Partial Revert "BCM2708: Add core Device Tree support"" | scripts/Makefile.build | 实施标题所述构建/配置改动；涉及路径见本行，性能收益未经实验验证。 |
| `208d9dc8e153` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2026-01-09 | Partial Revert "BCM2708: Add core Device Tree support" | scripts/Makefile.build | 实施标题所述构建/配置改动；涉及路径见本行，性能收益未经实验验证。 |
| `3df21d5eaa7e` | Dave Stevenson &lt;dave.stevenson@raspberrypi.com&gt; | 2025-11-17 | defconfig: Add TOUCHSCREEN_ILITEK to all Pi configs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_TOUCHSCREEN_ILITEK=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `16fd946fa771` | JinShil &lt;slavo5150@yahoo.com&gt; | 2025-11-24 | configs: Add CONFIG_INPUT_PWM_BEEPER=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_INPUT_PWM_BEEPER=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `11a1e7417c12` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-10-24 | configs: Add the AD799X driver module | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_AD799X=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `391c2e3f0599` | Naushir Patuck &lt;naush@raspberrypi.com&gt; | 2025-09-30 | drivers: pcie: Hailo: Remove Hailo PCIe driver | arch/arm/configs/ | RPi 通用 ARM 配置删除旧项 `CONFIG_MEDIA_PCI_HAILO=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `0923c467445c` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-10-17 | configs: Enable the SCD4X sensor driver | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SCD4X=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `0c7075b4607f` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-10-08 | config: Add CONFIG_TMP117=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_TMP117=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `bd56339b0399` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-09-17 | configs: Add CONFIG_VEML6030=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_VEML6030=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `8bab73cd1816` | Nicolai Buchwitz &lt;nb@tipi-net.de&gt; | 2025-09-18 | configs: Add CONFIG_W1_SLAVE_DS2430=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_W1_SLAVE_DS2430=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `e60edb2c4b99` | Dave Stevenson &lt;dave.stevenson@raspberrypi.com&gt; | 2025-04-29 | defconfig: Add CONFIG_ADXL355_I2C to the defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_ADXL355_I2C=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `58db9ee795e4` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-09-02 | configs: Add EROFS_FS_ZIP_ZSTD | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_EROFS_FS_ZIP_ZSTD=y`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `1f724808d426` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-07-04 | configs: Enable more packet classification options | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_CLS_U32_PERF=y`、`CONFIG_NET_CLS_FLOWER=m`、`CONFIG_NET_CLS_MATCHALL=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `78c0bf89d051` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2025-06-30 | Revert "include/linux/mmc/card.h: Partial revert" | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `19aa8bc1946a` | Greg Kroah-Hartman &lt;gregkh@linuxfoundation.org&gt; | 2025-06-27 | Linux 6.12.35 | Makefile | 历史 stable 版本号提交改变顶层 Makefile；是 RPi 图中的旧版本重放，不是本 HEAD 版本回退。 |
| `010e02f6d336` | Stefan Metzmacher &lt;metze@samba.org&gt; | 2025-06-18 | smb: client: fix max_sge overflow in smb_extract_folioq_to_rdma() | fs/smb | 修复 SMB folioq 到 RDMA 映射的 max_sge 溢出，关系页缓存数据传输正确性。 |
| `fed957da2007` | Gary Guo &lt;gary@garyguo.net&gt; | 2025-05-17 | rust: compile libcore with edition 2024 for 1.87+ | scripts/generate_rust_analyzer.py | 针对 Rust 1.87+ 以 edition 2024 编译 core，关系工具链兼容。 |
| `db1059490d6a` | Miguel Ojeda &lt;ojeda@kernel.org&gt; | 2025-02-10 | kbuild: rust: add rustc-min-version support function | scripts/Makefile.compiler | 增加 Rust 最低版本检测函数，关系 Kbuild 能力选择。 |
| `d1fe5674dd43` | Jann Horn &lt;jannh@google.com&gt; | 2025-05-27 | mm/hugetlb: unshare page tables during VMA split, not before | mm/hugetlb.c, mm/vma.c, mm/vma_internal.h | 将 hugetlb 页表解除共享移到 VMA 分割过程中，修复内存映射并发安全。 |
| `7b5214d9f158` | Dhananjay Ugwekar &lt;dhananjay.ugwekar@amd.com&gt; | 2025-02-05 | cpufreq/amd-pstate: Add missing NULL ptr check in amd_pstate_update | drivers/cpufreq | 修正标题所述 CPU 调频驱动行为；可能影响对应硬件的频率管理，非 RPi ARMv7 通用回收算法。 |
| `69a5f46a1d9b` | Tejun Heo &lt;tj@kernel.org&gt; | 2025-06-16 | sched_ext, sched/core: Don't call scx_group_set_weight() prematurely from sched_create_group() | kernel/sched | 避免调度组尚未初始化就调用 sched_ext 权重设置，影响可扩展调度正确性。 |
| `77665996850a` | Ryan Roberts &lt;ryan.roberts@arm.com&gt; | 2025-06-06 | mm: close theoretical race where stale TLB entries could linger | mm/madvise.c | 关闭过期 TLB 条目可能残留的理论竞态，关系页表与内存访问正确性。 |
| `a0de278b1d2b` | Mike Tipton &lt;quic_mdtipton@quicinc.com&gt; | 2025-05-14 | cpufreq: scmi: Skip SCMI devices that aren't used by the CPUs | drivers/cpufreq | 修正标题所述 CPU 调频驱动行为；可能影响对应硬件的频率管理，非 RPi ARMv7 通用回收算法。 |
| `2301bd779166` | Chao Yu &lt;chao@kernel.org&gt; | 2025-05-13 | f2fs: use vmalloc instead of kvmalloc in .init_{,de}compress_ctx | fs/f2fs | F2FS 压缩上下文分配改用 vmalloc，调整压缩路径的分配策略。 |
| `f85468130b02` | Linus Torvalds &lt;torvalds@linux-foundation.org&gt; | 2025-05-27 | Make 'cc-option' work correctly for the -Wno-xyzzy pattern | scripts/Makefile.compiler | 修复 cc-option 对 -Wno 选项探测的判断，影响构建参数可靠性。 |
| `3e83bac5c685` | Erick Shepherd &lt;erick.shepherd@ni.com&gt; | 2025-03-31 | mmc: Add quirk to disable DDR50 tuning | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `477c28cd22ac` | Jann Horn &lt;jannh@google.com&gt; | 2025-05-27 | mm/hugetlb: fix huge_pmd_unshare() vs GUP-fast race | mm/hugetlb.c | 修复 huge_pmd_unshare 与 GUP-fast 并发，保障大页 pin/页表安全。 |
| `0eff933ef9d1` | Jinliang Zheng &lt;alexjlzheng@tencent.com&gt; | 2025-04-15 | mm: fix ratelimit_pages update error in dirty_ratio_handler() | mm/page-writeback.c | 修正 dirty_ratio 更新 ratelimit_pages 的错误，影响脏页回写节流。 |
| `66f760ba4049` | Brian Foster &lt;bfoster@redhat.com&gt; | 2025-05-16 | ext4: only dirty folios when data journaling regular files | fs/ext4 | ext4 data journal 仅对普通文件标脏 folio，修正页缓存写回行为。 |
| `75cf0f5f1f2f` | Max Kellermann &lt;max.kellermann@ionos.com&gt; | 2025-04-23 | fs/nfs/read: fix double-unlock bug in nfs_return_empty_folio() | fs/nfs | 修复 NFS 空 folio 返回路径的重复解锁，保障读取页缓存并发安全。 |
| `fc7aa071e15e` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2025-06-30 | include/linux/mmc/card.h: Partial revert | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `a0bc7675265e` | Greg Kroah-Hartman &lt;gregkh@linuxfoundation.org&gt; | 2025-06-10 | Linux 6.12.33 | Makefile | 历史 stable 版本号提交改变顶层 Makefile；是 RPi 图中的旧版本重放，不是本 HEAD 版本回退。 |
| `48a9cd5059ec` | Jon Hunter &lt;jonathanh@nvidia.com&gt; | 2025-06-05 | Revert "cpufreq: tegra186: Share policy per cluster" | drivers/cpufreq | 修正标题所述 CPU 调频驱动行为；可能影响对应硬件的频率管理，非 RPi ARMv7 通用回收算法。 |
| `f2670defdb00` | Gautham R. Shenoy &lt;gautham.shenoy@amd.com&gt; | 2025-05-29 | acpi-cpufreq: Fix nominal_freq units to KHz in get_max_boost_ratio() | drivers/cpufreq | 修正标题所述 CPU 调频驱动行为；可能影响对应硬件的频率管理，非 RPi ARMv7 通用回收算法。 |
| `63252ab94e4f` | macmpi &lt;16296055+macmpi@users.noreply.github.com&gt; | 2025-06-04 | configs: add rtw88/89 PCI drivers | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_RTW88_8822BE=m`、`CONFIG_RTW88_8822CE=m`、`CONFIG_RTW88_8723DE=m` 等 11 项；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `cee5723dd0c4` | Kieran Bingham &lt;kieran.bingham@ideasonboard.com&gt; | 2025-05-23 | defconfigs: Add IMX283 to all Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_VIDEO_IMX283=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `23e6672404e8` | Tim Gover &lt;tim.gover@raspberrypi.com&gt; | 2025-05-29 | defconfigs: Enable WATCHDOG_SYSFS | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_WATCHDOG_SYSFS=y`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `6a53eb833984` | philippe baetens &lt;philippe.baetens@ams-osram.com&gt; | 2025-04-15 | defconfigs: Add ams Mira220 image sensor to Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_VIDEO_MIRA220=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `d0c40456aae5` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-05-15 | configs: Enable more MediaTek drivers | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_BT_HCIBTUSB_MTK=y`、`CONFIG_MT7925U=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `f9dfc609ca65` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-05-09 | configs: Enable SENSORS_POWERZ | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SENSORS_POWERZ=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `0dc20a353230` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-04-01 | configs: Add FTRACE_SYSCALLS=y | arch/arm/configs/ | RPi 通用配置启用 syscall ftrace，增加观测能力与可选跟踪成本。 |
| `63f591d4a189` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-05-02 | configs: Regenerate the defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SENSORS_ADS7828=m`；删除旧项 `CONFIG_SENSORS_ADS7828=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `20e8ae413c22` | Adam Wilson &lt;adamwilson266@rocketmail.com&gt; | 2025-04-28 | configs: add CONFIG_SENSORS_ADS2728=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SENSORS_ADS7828=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `57bc100119ad` | Waveshare_Team &lt;support@waveshare.com&gt; | 2025-04-08 | configs : Enable configs of new series of Waveshare DSI panels | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_REGULATOR_WAVESHARE_TOUCHSCREEN=m`、`CONFIG_DRM_PANEL_WAVESHARE_TOUCHSCREEN_V2=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `5d7f5656dabf` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-04-23 | configs: Enable UNICODE support (for filesystems) | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_UNICODE=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `cc0cf6abe3e4` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2024-10-29 | configs: Add TCS3472=m and VEML6040=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_TCS3472=m`、`CONFIG_VEML6040=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `8d1b6ad3fafd` | Kieran Bingham &lt;kieran.bingham@ideasonboard.com&gt; | 2025-04-23 | defconfigs: Add IMX335 to all Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_VIDEO_IMX335=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `b086a4b40665` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-04-22 | configs: Enable the EROFS read-only filesystem | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_EROFS_FS=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `2a536bfca932` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-04-03 | configs: Make the RTL8152 driver a module | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_USB_RTL8152=m`；删除旧项 `CONFIG_USB_RTL8152=y`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `82ea1311dc38` | Trevor Man &lt;tman_github@trejan.com&gt; | 2025-04-02 | Show process name in set_mempolicy() ignored message | mm/mempolicy.c | 在被忽略的 set_mempolicy 日志中打印进程名，改善内存策略问题定位。 |
| `550a46ee2e5b` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2025-02-05 | mm/mempolicy: Ignore runtime policy changes when set through cmdline | mm/mempolicy.c | 命令行固定 NUMA 策略时忽略运行时更改，影响内存分配策略覆盖规则。 |
| `38142479eee1` | Giedrius Trainavičius &lt;giedrius@blokas.io&gt; | 2025-03-19 | Include Pisound Micro kernel module in Raspberry Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SND_PISOUND_MICRO=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `25ea121edd28` | Dave Stevenson &lt;dave.stevenson@raspberrypi.com&gt; | 2025-03-17 | defconfigs: Add DRM_PANEL_ILITEK_ILI9806E_SPI to Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_DRM_PANEL_ILITEK_ILI9806E_SPI=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `d66ce1640ad6` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-03-10 | configs: Add GPIO_FXL6408=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_GPIO_FXL6408=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `d16d4e334c6e` | Dave Stevenson &lt;dave.stevenson@raspberrypi.com&gt; | 2024-11-14 | arm: defconfig: Replace VIDEO_RPIVID with VIDEO_RPI_HEVC_DEC | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_VIDEO_RPI_HEVC_DEC=m`；删除旧项 `CONFIG_VIDEO_RPIVID=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `b3c4a07fdd65` | Tvrtko Ursulin &lt;tvrtko.ursulin@igalia.com&gt; | 2024-05-22 | mm/mempolicy: Add MPOL_RANDOM | mm/mempolicy.c | 增加随机 NUMA 分配策略 MPOL_RANDOM，影响跨节点内存布局。 |
| `b3578eb7cd04` | Tvrtko Ursulin &lt;tvrtko.ursulin@igalia.com&gt; | 2024-06-18 | iommu/dma: Add ability to configure NUMA allocation policy for remapped allocations | mm/mempolicy.c | 给 DMA 重映射分配增加 NUMA 策略控制，影响分配位置。 |
| `939b392cfafa` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2025-02-20 | configs: Enable more ZRAM backends | arch/arm/configs/ | RPi 通用 defconfig 启用更多 zram 后端；未自动改变后续独立 Tizen defconfig。 |
| `965143c5491f` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2024-12-09 | configs: Enable Intel Wireless (PCI) drivers | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_IWLWIFI=m`、`CONFIG_IWLDVM=m`、`CONFIG_IWLMVM=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `22b60dde6f7f` | Nicolai Buchwitz &lt;n.buchwitz@kunbus.com&gt; | 2025-02-02 | configs: Enable Renesas XHCI driver | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_USB_XHCI_PCI_RENESAS=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `d63ff92dfcec` | Ethan Shold &lt;sholdee@gmail.com&gt; | 2025-01-30 | Enable CONFIG_NETKIT | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_NETKIT=y`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `a3e84b3508b6` | James Sarrett &lt;jsarrett@gmail.com&gt; | 2025-01-26 | configs: add CONFIG_SENSORS_INA238=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SENSORS_INA238=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `7023072d162a` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-01-22 | configs: add CONFIG_SND_SOC_WM8904=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SND_SOC_WM8904=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `cb6b027dcd8c` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2025-01-13 | configs: Switch to the upstream SDHOST driver | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_MMC_HSQ=y`、`CONFIG_MMC_BCM2835=y`；删除旧项 `CONFIG_MMC_BCM2835_SDHOST=y`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `42a3010523fc` | Jonathan Bell &lt;jonathan@raspberrypi.com&gt; | 2025-01-08 | mmc: use downstream DT property to modify CQE and/or SD CQ behaviour | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `41e93ebc83bf` | Jonathan Bell &lt;jonathan@raspberrypi.com&gt; | 2025-01-08 | mmc: sd: filter card CQ support based on an allow-list | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `d000637da7ae` | plumbeo &lt;plumbeo@users.noreply.github.com&gt; | 2025-01-09 | configs: add CONFIG_CRYPTO_NHPOLY1305_NEON=m | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_CRYPTO_NHPOLY1305_NEON=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `53f22d9fc519` | Dave Stevenson &lt;dave.stevenson@raspberrypi.com&gt; | 2025-01-02 | defconfigs: Add IMX415 to all Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_VIDEO_IMX415=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `185a01743504` | Tim Gover &lt;tim.gover@raspberrypi.com&gt; | 2024-11-01 | configs: Enable the RPi FW UART driver | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SERIAL_RPI_FW=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `b055c79f0180` | Giedrius &lt;giedrius@blokas.io&gt; | 2024-11-21 | Include snd-pimidi kernel module in Raspberry Pi defconfigs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_SND_PIMIDI=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `ac68d8a7d317` | Michael Heimpold &lt;mhei@heimpold.de&gt; | 2024-11-17 | configs: enable driver for Vertexcom MSE102X | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_MSE102X=m`；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `532fc50f78c3` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2024-09-12 | mm/vmscan: Maintain TLB coherency in LRU code | mm/vmscan.c | 在 LRU 路径维持 TLB 一致性，避免回收/访问标志处理中的陈旧映射。 |
| `92719518d633` | Tvrtko Ursulin &lt;tvrtko.ursulin@igalia.com&gt; | 2024-07-29 | numa/emulation: Check emulated zones around the CMA window | mm/cma.c, mm/numa_emulation.c | 检查 NUMA 模拟区与 CMA 窗口关系，防止区域布局影响 CMA。 |
| `73f851d09df2` | Tvrtko Ursulin &lt;tvrtko.ursulin@igalia.com&gt; | 2024-05-22 | mm/numa: Allow override of kernel's default NUMA policy | mm/mempolicy.c | 允许覆盖内核默认 NUMA 策略，影响内存页分配位置。 |
| `514dc2cbb79c` | Jonathan Bell &lt;jonathan@raspberrypi.com&gt; | 2024-06-20 | mmc: restrict posted write counts for SD cards in CQ mode | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `142ae0f3cfc5` | Jonathan Bell &lt;jonathan@raspberrypi.com&gt; | 2024-03-20 | drivers: mmc: preallocate a block for SD extension register accesses | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `a0ca20d3436c` | Jonathan Bell &lt;jonathan@raspberrypi.com&gt; | 2024-03-15 | drivers: mmc: add SD support for Command Queueing | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `bb1e203d150d` | Phil Elwell &lt;phil@raspberrypi.com&gt; | 2023-12-01 | dtc update | scripts/dtc | 更新设备树编译器源码，影响 DTB 构建兼容性。 |
| `e640262c2f69` | David Plowman &lt;david.plowman@raspberrypi.com&gt; | 2022-03-29 | mm,page_alloc,cma: introduce a customisable threshold for allocating pages in cma | mm/page_alloc.c | 增加 CMA 分配阈值启动参数，默认 12/16，以降低 CMA 碎片风险。 |
| `561033b2ab5e` | gellert &lt;gellert@raspberrypi.org&gt; | 2014-08-15 | MMC: added alternative MMC driver | include/linux | 调整 MMC 卡或队列支持，关系存储 I/O；由 mm* 路径匹配纳入，不是 mm 回收补丁。 |
| `20f7bfe9e4fc` | popcornmix &lt;popcornmix@gmail.com&gt; | 2015-04-13 | config: Add default configs | arch/arm/configs/ | RPi 通用 ARM 配置新增/设置 `CONFIG_LOCALVERSION="-v7"`、`# CONFIG_LOCALVERSION_AUTO is not set`、`CONFIG_SYSVIPC=y` 等 1655 项；影响功能/模块组成，不自动改变 Tizen 独立配置。 |
| `3a44d1cb497e` | Dom Cobley &lt;popcornmix@gmail.com&gt; | 2024-09-30 | BCM2708: Add core Device Tree support | scripts/Makefile.build, scripts/Makefile.dtbinst, scripts/Makefile.lib | 实施标题所述构建/配置改动；涉及路径见本行，性能收益未经实验验证。 |

打包相关的 d64d389cebe0（LLVM 条件）、80351212d379（build-rpi.sh LLVM）等仅用于第 2 节解释；不因主题相关而混入上述限定路径计数。

## 5. 开发机资源和访问边界

- `nproc`=20，本任务并发上限 10；采集脚本串行遍历，少量独立命令并行，Git pack.threads 限为 4，没有编译。
- 内存总量约 30 GiB，采样 available 14 GiB；swap 4 GiB、使用约 2 GiB。`$WS` 在 /dev/sda1、/home，剩余 539 GiB（70% 已使用）。数值为采样时刻，非持续监控。
- GBS `/usr/bin/gbs`，版本 2.1.0。PATH 上找到 GCC 13.3.0 的 x86_64 主机编译器，未发现可直接在 PATH 调用的 ARM GCC/Clang 交叉编译器。
- 扩展只读检索 `/opt`、`/usr/local`、`/home/linhao/Toolchain` 找到 armv7l/aarch64 Tizen Clang 21 wrapper、clang-21.real，以及已有 GBS roots 下 GCC 和 Clang 22。`file -L` 证明其中一部分是 x86_64 可执行文件，另一部分是 ARM 目标机程序；GBS 加速 GCC/Clang 还依赖 `/emul/...` loader。抽查 Clang 21/22 的 `--version` 返回 127，原因是 libxml2.so.16 缺失；详见 [compiler_version_attempts.txt](../evidence/task1/compiler_version_attempts.txt)。部分其他 `--version` 失败/无 stdout，故“文件存在”不等于“当前宿主可用的交叉工具链”。未更改 PATH、未运行 wrapper 构建、未安装软件。
- sdb 在 PATH：`/home/linhao/.local/bin/sdb`，链接到 Tizen Studio 工具；只执行 `sdb devices`。它自动启动了本机 server，但设备列表为空；未进入 shell、未推送/拉取、未连接目标执行命令。

证据：[host_resources.txt](../evidence/task1/host_resources.txt)、[compilers_path.txt](../evidence/task1/compilers_path.txt)、[compilers_local_inventory.txt](../evidence/task1/compilers_local_inventory.txt)、[sdb_devices.txt](../evidence/task1/sdb_devices.txt)。

## 6. 后续任务状态（任务2更新）

- 普通/RT最终配置、实际工具链、板上运行值仍未验证；任务2构建已中止，见03，不用静态推导替代产物数据。
- PM已明确silent-reclaim-fix在用户账号下，作者He Fangyu，由另一条工作线负责；本项目已仅拆入memcontrol到lko/base，zram配置由本项目另评估。
- PM明确MLGO是用户本人的编译器分支，与本项目不重叠；cache-ext不重叠、不再跟踪。
- 任务2认证SSH已查到open 0、merged 17，其中内存/性能观测/构建相关12条；任务1匿名REST记录保留为历史，相关挂账已解除，见02第2节。
- 本任务没有板上swappiness、zram disksize/实际comp_algorithm、命令行、MGLRU sysfs或benchmark数据。
