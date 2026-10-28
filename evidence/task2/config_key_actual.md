# 最终配置重点核对

单元格为 value @行号；未输出表示.config没有该符号；CORESIGHT父项显式n，其子项未输出，不冒充实际硬件状态。

| 符号 | gcc_arm-rpi4 | gcc_arm-rpi4-rt | llvm_arm-rpi4 | llvm_arm-rpi4-rt |
| --- | --- | --- | --- | --- |
| AEABI | y @493 | y @498 | y @491 | y @496 |
| ARM_LPAE | y @415 | y @420 | y @414 | y @419 |
| CORESIGHT | n @7011 | n @7006 | n @7006 | n @7001 |
| CORESIGHT_CATU | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_CPU_DEBUG | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_CPU_DEBUG_DEFAULT_ON | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_CTI | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_CTI_INTEGRATION_REGS | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_DUMMY | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_LINKS_AND_SINKS | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_LINK_AND_SINK_TMC | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_SINK_ETBV10 | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_SINK_TPIU | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_SOURCE_ETM3X | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_SOURCE_ETM4X | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_STM | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_TPDA | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_TPDM | 未输出 | 未输出 | 未输出 | 未输出 |
| CORESIGHT_TRBE | 未输出 | 未输出 | 未输出 | 未输出 |
| DEBUG_INFO_BTF | y @6769 | y @6763 | y @6766 | y @6760 |
| DEBUG_INFO_BTF_MODULES | y @6772 | y @6766 | y @6770 | y @6764 |
| DEBUG_LOCK_ALLOC | n @6891 | n @6885 | n @6886 | n @6880 |
| DEBUG_SPINLOCK | n @6887 | n @6883 | n @6882 | n @6878 |
| HW_PERF_EVENTS | y @502 | y @506 | y @500 | y @504 |
| HZ | 100 @489 | 100 @494 | 100 @487 | 100 @492 |
| HZ_100 | y @483 | y @488 | y @481 | y @486 |
| HZ_1000 | n @488 | n @493 | n @486 | n @491 |
| HZ_200 | n @484 | n @489 | n @482 | n @487 |
| HZ_250 | n @485 | n @490 | n @483 | n @488 |
| HZ_300 | n @486 | n @491 | n @484 | n @489 |
| HZ_500 | n @487 | n @492 | n @485 | n @490 |
| HZ_FIXED | 0 @482 | 0 @487 | 0 @480 | 0 @485 |
| HZ_PERIODIC | n @92 | n @92 | n @93 | n @93 |
| KALLSYMS_ALL | y @255 | y @260 | y @254 | y @259 |
| LRU_GEN_WALKS_MMU | 未输出 | 未输出 | 未输出 | 未输出 |
| PAGE_SIZE_4KB | y @670 | y @670 | y @668 | y @668 |
| PAGE_SIZE_LESS_THAN_256KB | y @672 | y @672 | y @670 | y @670 |
| PAGE_SIZE_LESS_THAN_64KB | y @671 | y @671 | y @669 | y @669 |
| PAGE_SHIFT | 12 @673 | 12 @673 | 12 @671 | 12 @671 |
| PERF_EVENTS | y @263 | y @268 | y @262 | y @267 |
| PREEMPT | n @116 | n @115 | n @117 | n @116 |
| PREEMPTION | 未输出 | y @118 | 未输出 | y @119 |
| PREEMPTIRQ_DELAY_TEST | n @6990 | n @6985 | n @6985 | n @6980 |
| PREEMPTIRQ_TRACEPOINTS | y @6946 | y @6940 | y @6941 | y @6935 |
| PREEMPT_COUNT | 未输出 | y @117 | 未输出 | y @118 |
| PREEMPT_DYNAMIC | 未输出 | 未输出 | 未输出 | 未输出 |
| PREEMPT_NONE | n @114 | n @113 | n @115 | n @114 |
| PREEMPT_RCU | 未输出 | y @143 | 未输出 | y @144 |
| PREEMPT_RT | n @117 | y @116 | n @118 | y @117 |
| PREEMPT_TRACER | 未输出 | n @6953 | 未输出 | n @6948 |
| PREEMPT_VOLUNTARY | y @115 | n @114 | y @116 | n @115 |
| PREEMPT_VOLUNTARY_BUILD | y @113 | 未输出 | y @114 | 未输出 |
| SMP | y @465 | y @470 | y @463 | y @468 |
| STACKPROTECTOR | y @652 | y @653 | y @648 | y @649 |
| STACKPROTECTOR_PER_TASK | y @511 | y @515 | 未输出 | 未输出 |
| STACKPROTECTOR_STRONG | y @653 | y @654 | y @649 | y @650 |
| TRACE_IRQFLAGS | y @6899 | y @6893 | y @6894 | y @6888 |
| TRACE_IRQFLAGS_SUPPORT | y @622 | y @624 | y @618 | y @620 |
| ZRAM | y @1690 | y @1684 | y @1687 | y @1681 |
| ZRAM_BACKEND_842 | n @1695 | n @1689 | n @1692 | n @1686 |
| ZRAM_BACKEND_DEFLATE | n @1694 | n @1688 | n @1691 | n @1685 |
| ZRAM_BACKEND_FORCE_LZO | y @1696 | y @1690 | y @1693 | y @1687 |
| ZRAM_BACKEND_LZ4 | n @1691 | n @1685 | n @1688 | n @1682 |
| ZRAM_BACKEND_LZ4HC | n @1692 | n @1686 | n @1689 | n @1683 |
| ZRAM_BACKEND_LZO | y @1697 | y @1691 | y @1694 | y @1688 |
| ZRAM_BACKEND_ZSTD | n @1693 | n @1687 | n @1690 | n @1684 |
| ZRAM_DEF_COMP | "lzo-rle" @1700 | "lzo-rle" @1694 | "lzo-rle" @1697 | "lzo-rle" @1691 |
| ZRAM_DEF_COMP_LZO | n @1699 | n @1693 | n @1696 | n @1690 |
| ZRAM_DEF_COMP_LZORLE | y @1698 | y @1692 | y @1695 | y @1689 |
| ZRAM_MEMORY_TRACKING | n @1703 | n @1697 | n @1700 | n @1694 |
| ZRAM_MULTI_COMP | n @1704 | n @1698 | n @1701 | n @1695 |
| ZRAM_TRACK_ENTRY_ACTIME | n @1702 | n @1696 | n @1699 | n @1693 |
| ZRAM_WRITEBACK | n @1701 | n @1695 | n @1698 | n @1692 |
| ZSMALLOC | y @812 | y @807 | y @809 | y @804 |
| ZSMALLOC_CHAIN_SIZE | 8 @814 | 8 @809 | 8 @811 | 8 @806 |
| ZSMALLOC_STAT | n @813 | n @808 | n @810 | n @805 |

## GCC普通版全部DEBUG_*=y

- CONFIG_DEBUG_ALIGN_RODATA=y，.config:435
- CONFIG_DEBUG_BUGVERBOSE=y，.config:6750
- CONFIG_DEBUG_KERNEL=y，.config:6753
- CONFIG_DEBUG_MISC=y，.config:6754
- CONFIG_DEBUG_INFO=y，.config:6759
- CONFIG_DEBUG_INFO_DWARF4=y，.config:6763
- CONFIG_DEBUG_INFO_COMPRESSED_NONE=y，.config:6766
- CONFIG_DEBUG_INFO_BTF=y，.config:6769
- CONFIG_DEBUG_INFO_BTF_MODULES=y，.config:6772
- CONFIG_DEBUG_FS=y，.config:6792
- CONFIG_DEBUG_FS_ALLOW_ALL=y，.config:6793
- CONFIG_DEBUG_MEMORY_INIT=y，.config:6839
