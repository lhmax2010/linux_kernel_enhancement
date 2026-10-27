# 任务2：armv7l AutoFDO/BOLT静态前提

更新：2026-10-27；内核基线f240c28093027707f5e09f8a9cbbed16a43ebb1a。本轮完成Kconfig、DTS include链和perf打包源码核对；没有成功构建产物、平台LLVM版本或板上数据。证据：[源码摘录](../evidence/task2/static_source_lines.txt)、[FDO符号检索](../evidence/task2/fdo_symbol_search.txt)、[DTS递归扫描](../evidence/task2/bcm2711_dts_scan.txt)。

## 1. Kconfig与编译接入

- 通用LTO_CLANG和ARCH_SUPPORTS_LTO_CLANG/THIN定义在arch/Kconfig:731–750；HAS_LTO_CLANG（751–764）要求CC_IS_CLANG、LD_IS_LLD、AS_IS_LLVM、LLVM nm/ar、架构选择及其余兼容条件。arm/下未发现选择ARCH_SUPPORTS_LTO_CLANG/THIN，所以**本树ARM32没有现成的架构LTO开启路径**；不能仅增加defconfig一行就认为支持。
- 对已跟踪Kconfig/Makefile全文检索AUTOFDO_CLANG、PROPELLER_CLANG及ARCH_SUPPORTS_AUTOFDO/PROPELLER，退出码1、无匹配。**本树没有这些Kconfig/Kbuild接入项**，不是“已有项只是关闭”。实现内核AutoFDO需要另行设计、移植或实现编译profile接入及ARM32可用性验证；不能把通用Clang具有profile功能等同于该内核已支持。
- ARCH_HAS_HW_PTE_YOUNG定义在arch/Kconfig:1622；ARM32无select，arm64/Kconfig:43选择。HAVE_PREEMPT_DYNAMIC定义在arch/Kconfig:1544，CALL/KEY选择链在1547–1577；ARM32无选择，arm64/Kconfig:236选择KEY。这里是源码能力条件，不是最终.config实测。
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

该choice没有显式default；不能套用kernel/Kconfig.hz的通用HZ_250默认。最终HZ及PREEMPT相关值仍须等待最终.config。

## 2. PMU、CoreSight与perf

BCM2711主板入口arch/arm/boot/dts/broadcom/bcm2711-rpi-4-b.dts递归include链已扫描，没有未解析的字面include。bcm2711.dtsi:435–442有pmu节点，compatible为 `arm,cortex-a72-pmu`，SPI16–19并分别关联四个CPU。该链未发现coresight、etm、funnel、tpiu、etf、cti节点；不把静态DTS无节点扩大为芯片硬件不存在，也未检查运行时固件overlay后的树。

packaging/linux-rpi.spec:206编译perf时传入EXTRA_CFLAGS=-fPIE、NO_LIBTRACEEVENT=1、NO_JEVENTS=1，没有CORESIGHT=1或OpenCSD参数；安装命令273也没有。tools/perf/Makefile.config:520–534只在CORESIGHT有定义时探测libopencsd并启用HAVE_CSTRACE_SUPPORT；因此当前spec没有显式打开该接入路径。最终perf能力、CORESIGHT*配置均未验证。

## 3. 前提清单

| 范围 | 已具备 | 缺什么 | 需上板确认 |
| --- | --- | --- | --- |
| armv7l内核AutoFDO | 内核源码与打包基线、BCM2711 PMU DTS声明 | 本树AUTOFDO_CLANG/PROPELLER及对应ARCH_SUPPORTS项不存在；ARM32 LTO架构支持未接入；需明确可行profile采样格式、Clang版本、生成/消费profile编译链并验证正确性 | PMU事件/权限、采样稳定性、工作负载代表性、优化收益及回归 |
| CoreSight采样/解码 | perf源码包含CORESIGHT/OpenCSD条件路径 | 板级include链无CoreSight节点；spec未传CORESIGHT=1；没有最终CORESIGHT*配置及OpenCSD库版本 | 设备/trace节点、ETM路由和采样数据是否可用；不能仅凭CPU型号保证 |
| create_llvm_prof / llvm-profgen | 尚无本轮平台版本证据 | 未产生LLVM buildroot；旧中断GCC buildroot的usr/bin未找到这些工具名 | 完成静态工具核验后再考虑采样；本任务不操作板 |
| llvm-bolt | 尚无平台版本/后端证据 | 未取得平台llvm-bolt，**支持架构列表未确认**；不使用宿主工具或上游通用列表冒充此平台版本能力 | ARM32支持须先由平台工具静态确认，不能跳过后直接上板 |
| aarch64 | Kconfig有小端LTO及THIN支持路径 | 本树无上述FDO符号；本轮只做Kconfig记录 | armv7l完成前不开展aarch64构建/优化 |

工具查找范围和未取得原因见[platform_tools_pending.txt](../evidence/task2/platform_tools_pending.txt)。没有调用宿主size/readelf/nm等替代平台产物分析。所有静态结论不代表板上运行时内存或性能。
