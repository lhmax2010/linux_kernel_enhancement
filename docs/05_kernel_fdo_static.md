# 任务2：armv7l AutoFDO/BOLT静态前提

更新：2026-10-28；内核基线f240c28093027707f5e09f8a9cbbed16a43ebb1a。已取得两轮成功构建的最终配置和平台工具证据；未上板。源码证据：[源码摘录](../evidence/task2/static_source_lines.txt)、[FDO符号检索](../evidence/task2/fdo_symbol_search.txt)、[DTS递归扫描](../evidence/task2/bcm2711_dts_scan.txt)；新增[平台版本/perf能力原文](../evidence/task2/fdo_platform_actual.txt)、[四配置重点项](../evidence/task2/config_key_actual.md)。

## 1. Kconfig与编译接入

- 通用LTO_CLANG和ARCH_SUPPORTS_LTO_CLANG/THIN定义在arch/Kconfig:731–750；HAS_LTO_CLANG（751–764）要求CC_IS_CLANG、LD_IS_LLD、AS_IS_LLVM、LLVM nm/ar、架构选择及其余兼容条件。arm/下未发现选择ARCH_SUPPORTS_LTO_CLANG/THIN，所以**本树ARM32没有现成的架构LTO开启路径**；不能仅增加defconfig一行就认为支持。
- 对已跟踪Kconfig/Makefile全文检索AUTOFDO_CLANG、PROPELLER_CLANG及ARCH_SUPPORTS_AUTOFDO/PROPELLER，退出码1、无匹配。**本树没有这些Kconfig/Kbuild接入项**，不是“已有项只是关闭”。实现内核AutoFDO需要另行设计、移植或实现编译profile接入及ARM32可用性验证；不能把通用Clang具有profile功能等同于该内核已支持。
- ARCH_HAS_HW_PTE_YOUNG定义在arch/Kconfig:1622；ARM32无select，arm64/Kconfig:43选择。HAVE_PREEMPT_DYNAMIC定义在arch/Kconfig:1544，CALL/KEY选择链在1547–1577；ARM32无选择，arm64/Kconfig:236选择KEY。最终四配置中LRU_GEN_WALKS_MMU及PREEMPT_DYNAMIC均未输出/未启用，与上述架构条件一致。
- aarch64仅记录：arm64/Kconfig:96在CPU_LITTLE_ENDIAN时选择LTO_CLANG架构支持，97选择THIN；AutoFDO/Propeller符号本树同样不存在。未构建aarch64、未做BOLT优化。

ARM专用HZ choice及相邻默认逻辑原文（arch/arm/Kconfig:1095–1133）：

```kconfig
config HZ_FIXED
	int
	default 128 if SOC_AT91RM9200
	default 0

choice
	depends on HZ_FIXED = 0
	prompt "Timer frequency"

config HZ_100
	bool "100 Hz"

config HZ_200
	bool "200 Hz"

config HZ_250
	bool "250 Hz"

config HZ_300
	bool "300 Hz"

config HZ_500
	bool "500 Hz"

config HZ_1000
	bool "1000 Hz"

endchoice

config HZ
	int
	default HZ_FIXED if HZ_FIXED != 0
	default 100 if HZ_100
	default 200 if HZ_200
	default 250 if HZ_250
	default 300 if HZ_300
	default 500 if HZ_500
	default 1000

```

该choice没有显式default；不能套用kernel/Kconfig.hz的通用HZ_250默认。四份最终.config均HZ=100、HZ_100=y；普通为PREEMPT_VOLUNTARY=y，RT为PREEMPT_RT=y；其他PREEMPT*值及行号见实测重点表。

## 2. PMU、CoreSight与perf

BCM2711主板入口arch/arm/boot/dts/broadcom/bcm2711-rpi-4-b.dts递归include链已扫描，没有未解析的字面include。bcm2711.dtsi:435–442有pmu节点，compatible为 `arm,cortex-a72-pmu`，SPI16–19并分别关联四个CPU。该链未发现coresight、etm、funnel、tpiu、etf、cti节点；不把静态DTS无节点扩大为芯片硬件不存在，也未检查运行时固件overlay后的树。

packaging/linux-rpi.spec:206编译perf时传入EXTRA_CFLAGS=-fPIE、NO_LIBTRACEEVENT=1、NO_JEVENTS=1，没有CORESIGHT=1或OpenCSD参数；安装命令273也没有。tools/perf/Makefile.config:520–534只在CORESIGHT有定义时探测libopencsd并启用HAVE_CSTRACE_SUPPORT；因此当前spec没有显式打开该接入路径。实际GCC/LLVM的perf version --build-options均显示libopencsd OFF（HAVE_CSTRACE_SUPPORT未编入），auxtrace on不等于CoreSight解码可用。四份最终.config均CORESIGHT显式n，其CORESIGHT_*子项未输出；PERF_EVENTS=HW_PERF_EVENTS=y。最终配置具体行号和全部子项见重点表。

## 3. 平台工具实测与能力边界

所有命令使用本次LLVM buildroot内工具，经该root的qemu-arm运行；未使用宿主LLVM代替。完整绝对路径、输出、退出码和扫描范围见[平台工具证据](../evidence/task2/fdo_platform_actual.txt)。

| 工具/能力 | 实测结果 | 限制 |
| --- | --- | --- |
| llvm-profgen --version | LLVM version 22.1.8，Optimized build，exit=0；RPM llvm-22.1.8-3.1.armv7l | 版本存在不证明可将RPi4 ARM32采样转换成可消费的内核profile；没有本轮采样输入 |
| create_llvm_prof --version | 指定root/usr/bin路径不存在，qemu执行exit=1，无输出；root文件名扫描无同名文件；autofdo RPM未安装 | 未取得版本，不写成不支持所有ARM架构，也不臆测版本 |
| llvm-bolt --version | 指定root/usr/bin路径不存在，qemu执行exit=1，无输出；扫描usr/emul及其余可读root目录无同名工具；bolt RPM未安装 | **平台llvm-bolt支持架构列表无法实测**。本轮没有该可执行工具，不能将llvm-profgen/LLVM通用targets列表当成BOLT架构支持；未安装工具或借用别的buildroot |
| CoreSight/OpenCSD | 四配置CORESIGHT=n；两份perf 6.12.80均libopencsd OFF；root查询libopencsd未安装 | 不能用PERF_EVENTS=y或auxtrace on推断ETM可用；包名查询仅该名字，文件扫描与实际perf输出共同佐证 |

文件扫描的root、usr/share/upgrade、var/cache/ldconfig三个目录权限不足，错误保留；可执行工具标准路径、emul路径和RPM查询已核对。不使用sudo，也不通过更改权限补查。旧[platform_tools_pending.txt](../evidence/task2/platform_tools_pending.txt)是未构建时的历史证据，本节替代其“没有LLVM buildroot”的状态。

## 4. 前提清单

| 范围 | 已具备 | 缺什么 | 需上板确认 |
| --- | --- | --- | --- |
| armv7l内核AutoFDO | 成功GCC/Clang基线、Clang/LLD 22.1.8、llvm-profgen 22.1.8、PERF_EVENTS/HW_PERF_EVENTS=y、BCM2711 PMU DTS声明 | 本树AUTOFDO_CLANG/PROPELLER及对应ARCH_SUPPORTS项不存在；需设计/移植profile生成和编译消费链、确认ARM32采样格式与llvm-profgen兼容性；若方案依赖LTO，本树ARM32 LTO接入也缺失，不能说所有AutoFDO必需LTO | PMU事件/权限、采样稳定性、代表性负载、profile匹配、优化收益及回归 |
| CoreSight采样/解码 | perf源码存在CORESIGHT/OpenCSD条件路径，实际perf有auxtrace | 最终CORESIGHT=n、板级include链无CoreSight节点、perf实际无OpenCSD；需要先确认硬件/固件可行再决定是否补支持 | 设备/trace节点、ETM路由和数据可用性；不能凭CPU型号保证 |
| create_llvm_prof / llvm-profgen | llvm-profgen实测22.1.8 | create_llvm_prof未提供、无版本；尚无可验证的ARM32转换链 | 完成静态链设计后再采样；本任务不操作板 |
| llvm-bolt | 已完成本次root路径/包核对 | root未提供工具；**支持架构未取得**，须由PM后续指定平台包/源码核对范围；本轮不能给出经过验证的支持架构列表 | 未解决工具/架构前提前，不开展板上BOLT实验 |
| aarch64 | Kconfig有小端LTO及THIN支持路径 | 本树无上述FDO符号；本轮仅保留Kconfig记录 | armv7l完成前不开展aarch64构建/优化 |

以上结论是构建配置和工具可用性，不代表板上运行时内存或性能。本轮已完成可用产物的核对；缺失工具的架构/版本没有伪造为“已测”。
