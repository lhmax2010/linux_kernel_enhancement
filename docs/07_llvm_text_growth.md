# 任务3：LLVM代码体积增长分析

2026-10-28；同一`lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a`的任务2产物。GCC14.2.0/GNU ld2.43与Clang22.1.8/LLD22.1.8；仓库release、自动探测的配置不同，故不是纯编译器单变量实验。未修改内核、未重新构建内核、未操作开发板。只按本任务授权做了Clang单文件优化报告重编和栈保护探测，输出在temp，未替换任何原产物。

**普通.text从17,808,156增至19,862,536 B，+2,054,380 B（+11.54%）；RT从18,128,580增至20,005,868 B，+1,877,288 B（+10.36%）。** 常驻总段增量为普通2,669,604 B（8.11%）、RT2,516,690 B（7.58%），详见[06](06_static_footprint.md)。增长存在局部强内联及重复初始化、Clang大量保留帧指针、EHABI展开表外移等多种因素，不能凭前50函数名字的涨幅作因果百分比分解。

## 1. 五个代表目标的实际编译参数

[原始.cmd第1行及逐token差异](../evidence/task3/representative_commands.txt)逐一记录以下普通版目标；[RT逐目标核对](../evidence/task3/representative_commands_rt_delta.txt)确认：GCC per-task offset变为1704（普通1648），其余token相同；LLVM这五个目标的普通/RT token相同。所有路径指向对应root中的本次构建目录。

| 目标 | 两编译器共有关键项 | 特例 |
| --- | --- | --- |
| drivers/block/zram/zram_drv.o | O2、-march=armv7-a、-msoft-float、-funwind-tables、-fstack-protector-strong、-ftrivial-auto-var-init=zero、-pg、-g -gdwarf-4 | 仅通用差异组，见下表/完整token |
| drivers/net/wireless/ralink/rt2x00/rt2800lib.o | 同上 | 无额外内联阈值/MLGO选项 |
| crypto/blake2b_generic.o | 同上 | 无本文件专属Os或展开指令 |
| lib/zstd/compress/zstd_double_fast.o | 同上 | 无本文件专属Os或-mllvm |
| kernel/sched/core.o | 同上 | **两边另有-fno-omit-frame-pointer**，来自kernel/sched/Makefile；不能把调度文件误当普通默认序言 |

| 参数类别 | GCC | Clang | 解释 |
| --- | --- | --- | --- |
| 优化级别 | -O2 | -O2 | 同名优化等级不是同一优化策略 |
| ARM目标/汇编器 | -marm、-mno-fdpic、-Wa,-mno-warn-deprecated | --target=arm-linux-gnueabi、-fintegrated-as、-meabi gnu、-Wa,-W | 实际代码均ARM32；不能由缺少字面-marm推断Thumb |
| IPA/栈与竞争选项 | -fno-ipa-sra、-fconserve-stack、-fno-allow-store-data-races、-fno-stack-clash-protection | 没有这些字面选项 | 为不同编译器的支持/策略路径 |
| canary位置 | -mstack-protector-guard=tls、-mstack-protector-guard-offset=1648 | 无这两项，实际全局guard | 强栈保护均开；TLS探测原因见第6节 |
| 自动初始化 | -ftrivial-auto-var-init=zero | 相同 | 不能归因为“只有Clang开了自动初始化”；内联后留下的store数量可能不同 |
| 对齐、LLVM控制 | 五个.cmd均无-falign-*、无-mllvm | 同左 | 未显式设置不等于默认策略相同，当前没有MLGO启用证据 |
| 展开/调试 | -funwind-tables、-fno-dwarf2-cfi-asm、-g -gdwarf-4 | 相同 | EHABI生成策略不同；DWARF不计常驻 |
| 通用帧指针 | 前四个没有显式-fomit/-fno-omit | 同左，但driver实际传-mframe-pointer=all | Kbuild因FUNCTION_TRACER不主动加-fomit-frame-pointer；两编译器生成序言不同 |

为避免略去警告和安全相关参数，下列是五目标共有的完整差异token组（其余-I/-D/输入输出按目标变化，共有部分见证据）：

GCC独有：`gcc -mno-fdpic -fno-ipa-sra -marm -Wa,-mno-warn-deprecated -fno-allow-store-data-races -fno-stack-clash-protection -fconserve-stack -Wno-main -Wno-dangling-pointer -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=designated-init -Wno-packed-not-aligned -Wno-format-truncation -Wno-stringop-truncation -Wno-maybe-uninitialized -mstack-protector-guard=tls -mstack-protector-guard-offset=1648`。

Clang独有：`clang --target=arm-linux-gnueabi -fintegrated-as -Werror=unknown-warning-option -Werror=ignored-optimization-argument -Werror=option-ignored -Werror=unused-command-line-argument -meabi gnu -Wa,-W -Wno-gnu -Wno-format-overflow-non-kprintf -Wno-format-truncation-non-kprintf -Wno-default-const-init-unsafe -Wno-unterminated-string-initialization -Wimplicit-fallthrough -Wno-pointer-to-enum-cast -Wno-tautological-constant-out-of-range-compare -Wno-unaligned-access -Wno-enum-compare-conditional -Wno-enum-enum-conversion`。

`Makefile:847–861`：未启用FRAME_POINTER时，仅在没有FUNCTION_TRACER才显式加-fomit-frame-pointer；本树两者关系不能用CONFIG_FRAME_POINTER=n推断机器码无帧指针。[Kbuild原行](../evidence/task3/kernel_source_references.txt)、[Clang实际driver计划](../evidence/task3/clang_driver_plan.txt)。

## 2. 增长位置

### 2.1 目录.text增量前30

使用最终vmlinux.a成员的`.text*`输入段，按两级目录互斥归组。生成符号/特殊节/对齐的链接残差不硬分到目录。普通输入差2,053,608 B、最终差2,054,380 B，相差772 B；RT输入差1,883,580 B、最终差1,877,288 B，相差−6,292 B。完整加总方法见06，不重复递归计算多个built-in.a。

| 目录 | GCC普通 | LLVM普通 | Δ普通 | GCC RT | LLVM RT | ΔRT |
| --- | --- | --- | --- | --- | --- | --- |
| drivers/net | 567,384 | 993,376 | 425,992 | 573,188 | 996,396 | 423,208 |
| fs/btrfs | 1,066,724 | 1,165,744 | 99,020 | 1,074,272 | 1,159,748 | 85,476 |
| kernel/bpf | 515,776 | 591,332 | 75,556 | 524,876 | 596,824 | 71,948 |
| lib/zstd | 464,640 | 531,588 | 66,948 | 464,768 | 531,588 | 66,820 |
| net/core | 565,664 | 621,868 | 56,204 | 581,544 | 629,240 | 47,696 |
| drivers/usb | 515,808 | 568,340 | 52,532 | 516,440 | 566,428 | 49,988 |
| mm | 683,740 | 735,960 | 52,220 | 697,560 | 738,176 | 40,616 |
| kernel | 368,456 | 418,728 | 50,272 | 371,060 | 413,468 | 42,408 |
| fs/nfs | 357,732 | 405,832 | 48,100 | 371,052 | 410,456 | 39,404 |
| net/bluetooth | 443,888 | 489,804 | 45,916 | 449,708 | 488,864 | 39,156 |
| fs | 487,420 | 531,804 | 44,384 | 491,432 | 529,776 | 38,344 |
| net/mac80211 | 577,628 | 620,944 | 43,316 | 603,248 | 640,812 | 37,564 |
| drivers/tty | 246,664 | 289,252 | 42,588 | 244,592 | 286,456 | 41,864 |
| sound/usb | 166,940 | 208,816 | 41,876 | 166,864 | 208,624 | 41,760 |
| drivers/media | 355,508 | 394,580 | 39,072 | 355,700 | 394,404 | 38,704 |
| net/ipv4 | 630,380 | 667,824 | 37,444 | 644,804 | 677,152 | 32,348 |
| net/netfilter | 372,796 | 410,044 | 37,248 | 381,300 | 415,052 | 33,752 |
| drivers/base | 178,888 | 211,984 | 33,096 | 181,660 | 209,172 | 27,512 |
| block | 279,988 | 311,444 | 31,456 | 282,604 | 310,100 | 27,496 |
| fs/ext4 | 479,268 | 510,240 | 30,972 | 486,796 | 515,260 | 28,464 |
| crypto | 175,512 | 204,988 | 29,476 | 175,996 | 204,980 | 28,984 |
| drivers/pci | 194,648 | 223,052 | 28,404 | 194,096 | 222,436 | 28,340 |
| drivers/gpu | 639,524 | 667,088 | 27,564 | 639,616 | 667,124 | 27,508 |
| lib | 304,628 | 331,936 | 27,308 | 306,232 | 332,416 | 26,184 |
| net/wireless | 467,792 | 492,664 | 24,872 | 492,360 | 511,840 | 19,480 |
| sound/core | 177,956 | 202,392 | 24,436 | 176,156 | 198,572 | 22,416 |
| kernel/trace | 329,300 | 350,716 | 21,416 | 340,112 | 357,508 | 17,396 |
| kernel/sched | 244,688 | 265,556 | 20,868 | 253,428 | 261,956 | 8,528 |
| drivers/scsi | 141,492 | 161,440 | 19,948 | 142,772 | 161,900 | 19,128 |
| net/sunrpc | 298,148 | 317,512 | 19,364 | 309,724 | 324,456 | 14,732 |


### 2.2 普通版函数增长前50

平台nm -S输出，限最终`.text`地址范围与T/t/W/w类型；只合并编译器`.isra.N/.constprop.N/.part.N`后缀，同名项求和。0表示该编译器没有同名独立符号，可能被内联、拆分或改名，**不表示少了该功能**。别名、尾部合并、无size符号和填充使符号加总不严格等于section。普通符号净差2,066,332 B，和section差11,952 B；以section值为最终总量。

| 函数 | GCC普通B | LLVM普通B | ΔB |
| --- | --- | --- | --- |
| rt2800_init_rfcsr | 0 | 92,444 | 92,444 |
| rt2800_init_rfcsr_6352 | 0 | 71,360 | 71,360 |
| rt2800_config_channel | 0 | 56,300 | 56,300 |
| rt2800_calibration_rt6352 | 0 | 21,972 | 21,972 |
| rt2800_config_channel_rf55xx | 0 | 21,092 | 21,092 |
| blake2b_compress_generic | 112 | 21,060 | 20,948 |
| rt2800_init_bbp | 10,832 | 30,440 | 19,608 |
| binder_ioctl_write_read | 0 | 16,852 | 16,852 |
| ZSTD_compressBlock_doubleFast_dictMatchState | 12,600 | 28,524 | 15,924 |
| __f2fs_ioctl | 0 | 14,424 | 14,424 |
| r8156b_hw_phy_cfg | 4,852 | 18,704 | 13,852 |
| rt2800_loft_iq_calibration | 7,720 | 20,784 | 13,064 |
| rt2800_rxiq_calibration | 4,292 | 17,156 | 12,864 |
| rt2800_init_rfcsr_3883 | 1,624 | 14,284 | 12,660 |
| do_check | 0 | 12,480 | 12,480 |
| check_leaf_item | 0 | 10,984 | 10,984 |
| vli_mmod_fast | 4,388 | 15,076 | 10,688 |
| rt2800_config_txpower | 76 | 10,576 | 10,500 |
| build_body | 8,400 | 18,560 | 10,160 |
| hidinput_configure_usage | 0 | 9,684 | 9,684 |
| rt2800_init_bbp_6352 | 0 | 9,648 | 9,648 |
| bpf_check | 12,796 | 22,236 | 9,440 |
| ZSTD_compressBlock_fast_dictMatchState | 10,244 | 19,372 | 9,128 |
| r8156_hw_phy_cfg | 3,388 | 12,448 | 9,060 |
| rt2800_bw_filter_calibration | 3,080 | 11,656 | 8,576 |
| ZSTD_decompressSequencesSplitLitBuffer | 0 | 8,380 | 8,380 |
| ZSTD_decompressBlock_internal | 3,736 | 11,848 | 8,112 |
| l2cap_recv_frame | 8,688 | 16,132 | 7,444 |
| gc_data_segment | 0 | 5,960 | 5,960 |
| ieee80211_assoc_success | 0 | 5,736 | 5,736 |
| ext4_ioctl | 12 | 5,744 | 5,732 |
| btrfs_fiemap | 244 | 5,444 | 5,200 |
| print_cpu | 3,268 | 8,344 | 5,076 |
| ax88179_reset | 1,172 | 6,228 | 5,056 |
| snd_scarlett2_controls_create | 0 | 5,016 | 5,016 |
| HUF_decompress4X2_usingDTable_internal | 0 | 5,008 | 5,008 |
| drm_gtf2_mode | 460 | 5,284 | 4,824 |
| csi_ECMA | 0 | 4,776 | 4,776 |
| nf_tables_newsetelem | 564 | 5,276 | 4,712 |
| proc_sched_show_task | 6,164 | 10,836 | 4,672 |
| ovl_copy_up_flags | 272 | 4,868 | 4,596 |
| ZSTD_compressBlock_fast | 15,256 | 19,796 | 4,540 |
| check_stack_write | 0 | 4,488 | 4,488 |
| mas_wmb_replace | 0 | 4,448 | 4,448 |
| sha512_generic_block_fn | 0 | 4,440 | 4,440 |
| bpf_obj_get_info_by_fd | 0 | 4,320 | 4,320 |
| audit_receive | 384 | 4,644 | 4,260 |
| evict_folios | 1,996 | 6,232 | 4,236 |
| bfq_add_request | 0 | 4,132 | 4,132 |
| ZSTD_compressBlock_doubleFast | 12,076 | 16,168 | 4,092 |


RT独立前50见[RT表](../evidence/task3/functions_growth_arm-rpi4-rt_top50.tsv)。所有普通增长函数中，两边都有名字且增长43,406个、合计+2,870,508 B；两边都有且缩小12,579个、−1,086,444 B；LLVM单独出现2,755个、+1,362,740 B；GCC单独出现3,440个、−1,080,472 B；相同3,668个。

| 每个正增量的区间（含LLVM独有） | 函数名组数 | 正增量总B |
| --- | ---: | ---: |
| 1–64 B | 34,791 | 549,232 |
| 65–256 B | 8,141 | 1,132,252 |
| 257–1024 B | 2,804 | 1,245,728 |
| 1025–4096 B | 376 | 667,160 |
| >4096 B | 49 | 638,876 |

正增量之和大于最终净增量，因为还需扣除负增量/消失函数。[普通及RT分布原表](../evidence/task3/function_growth_distribution.txt)。

## 3. 至少10个增长函数的反汇编与优化记录

在LLVM buildroot内的clang-22上，读取原.cmd，仅把源/头路径映射回同一root、把-o及依赖/优化输出转到temp，附加`-Rpass=inline -Rpass-missed=inline -fsave-optimization-record`。四个单文件为rt2800lib、blake2b_generic、zstd_double_fast、r8152；不是内核构建，也未修改输入。平台objcopy提取.text后，原对象与仅加报告对象的SHA-256 **四组均相同**，所以报告对应既有代码路径，未把改变参数的实验产物混入基线。[命令](../evidence/task3/inline_record_commands.txt)、[相同性](../evidence/task3/remarks_code_identity.txt)。

下面17项均位于普通版前50。数字是优化记录的事件数，不是指令数或字节；StackProtectorAddressTaken统计的是触发保护的局部对象，不能误读成每个对象各有一个canary检查。GCC/LLVM双侧反汇编与局部call计数一起核对，避免GCC局部调用没有重定位项造成漏计。

| 前50内的函数 | 最终.text符号B GCC→LLVM | Clang内联/展开/自动初始化记录数 | 反汇编/内联记录确认的归类 |
| --- | --- | --- | --- |
| `rt2800_rxiq_calibration` | 4,292→17,156 (+12,864) | 185 / 0 / 96 | GCC保留bbp/rfcsr读写辅助调用；Clang内联后出现锁、寄存器访问和临时变量初始化；新增guard |
| `rt2800_loft_iq_calibration` | 7,720→20,784 (+13,064) | 197 / 2 / 122 | 寄存器helper内联；明确2次FullyUnrolled；两者都已有guard，不能把全部增量算作栈保护 |
| `rt2800_bw_filter_calibration` | 3,080→11,656 (+8,576) | 123 / 0 / 54 | GCC有rfcsr读46/写52处调用；Clang展开其helper并保存局部值，新增guard |
| `rt2800_config_txpower` | 76→10,576 (+10,500) | 6 / 0 / 12 | GCC小分派函数，Clang将具体功率配置体内联到此；同时必须扣除其他消失helper，不能只看本行 |
| `rt2800_config_channel_rf55xx` | 0→21,092 (+21,092) | 132 / 0 / 128 | GCC无同名单独符号；LLVM分离/内联策略改变，声明归属迁移，非独立新增功能 |
| `rt2800_config_channel` | 0→56,300 (+56,300) | 146 / 0 / 325 | 同名GCC未单独输出；Clang大函数含多分支及众多mutex操作；只以rt2800lib总量作净增依据 |
| `rt2800_init_bbp_6352` | 0→9,648 (+9,648) | 77 / 0 / 77 | GCC无独立同名；Clang报告77次内联及77个AutoInitStore，归属迁移与重复helper体并存 |
| `rt2800_init_bbp` | 10,832→30,440 (+19,608) | 14 / 0 / 286 | GCC有565处bbp_write调用；Clang针对多分支内联，286个初始化store记录；新增guard |
| `rt2800_init_rfcsr_3883` | 1,624→14,284 (+12,660) | 93 / 0 / 92 | GCC有73处rfcsr_write、18处bbp_write调用；LLVM直接含mutex及读写逻辑，新增guard |
| `rt2800_calibration_rt6352` | 0→21,972 (+21,972) | 82 / 0 / 124 | GCC无独立同名；Clang将若干校准helper内联到此并保留外层函数，不能仅按21,972 B算新增功能 |
| `rt2800_init_rfcsr_6352` | 0→71,360 (+71,360) | 596 / 0 / 417 | 596次内联、417个初始化store记录；GCC无独立同名，使用对象净增防止重复计算 |
| `rt2800_init_rfcsr` | 0→92,444 (+92,444) | 12 / 0 / 520 | GCC无独立同名；LLVM保留入口且内联若干芯片分支，520个初始化store记录；注意callee体迁移 |
| `blake2b_compress_generic` | 112→21,060 (+20,948) | 2 / 0 / 0 | Clang把compress_one_generic内联；GCC该helper 19,404 B而LLVM不再单独输出；本函数+20,948不等于对象增量 |
| `ZSTD_compressBlock_doubleFast` | 12,076→16,168 (+4,092) | 4 / 0 / 0 | 4个mls专门化helper内联；条件组合/指令选择差异；未见此函数loop-unroll记录，不能臆定循环展开 |
| `ZSTD_compressBlock_doubleFast_dictMatchState` | 12,600→28,524 (+15,924) | 4 / 0 / 0 | 4个mls专门化helper内联，多个匹配循环拷贝；对象内其他函数缩小，净增小于本行 |
| `r8156b_hw_phy_cfg` | 4,852→18,704 (+13,852) | 195 / 0 / 35 | 195次helper内联，35个自动初始化store；GCC依赖OCP包装helper，LLVM含大量generic_ocp_write调用和局部guard |
| `r8156_hw_phy_cfg` | 3,388→12,448 (+9,060) | 120 / 0 / 52 | 120次helper内联、52个初始化store；寄存器读写序列重复，结合反汇编，非单纯函数对齐 |


反汇编片段：[rt2800 GCC](../evidence/task3/disasm_gcc_rt2800lib_excerpt.txt)/[LLVM](../evidence/task3/disasm_llvm_rt2800lib_excerpt.txt)、[blake GCC](../evidence/task3/disasm_gcc_blake2b_generic_excerpt.txt)/[LLVM](../evidence/task3/disasm_llvm_blake2b_generic_excerpt.txt)、[zstd GCC](../evidence/task3/disasm_gcc_zstd_double_fast_excerpt.txt)/[LLVM](../evidence/task3/disasm_llvm_zstd_double_fast_excerpt.txt)、[r8152 GCC](../evidence/task3/disasm_gcc_r8152_excerpt.txt)/[LLVM](../evidence/task3/disasm_llvm_r8152_excerpt.txt)。[完整局部call计数摘要](../evidence/task3/growth_function_instruction_summary.txt)包含GCC已解析本地bl目标，优先于片段标题中仅重定位call的计数。

优化记录：[rt2800](../evidence/task3/rt2800lib_optimization_excerpt.txt)、[blake](../evidence/task3/blake2b_generic_optimization_excerpt.txt)、[zstd](../evidence/task3/zstd_double_fast_optimization_excerpt.txt)、[r8152](../evidence/task3/r8152_optimization_excerpt.txt)、[自动初始化/guard/展开原文](../evidence/task3/initialization_guard_unroll_remarks.txt)、[事件计数](../evidence/task3/optimization_counts.txt)。

### 可量化范围与归因限制

| 观察范围/类别 | 普通.text净增B或观测 | 占最终2,054,380 B | 可作出的结论 |
| --- | ---: | ---: | --- |
| 强内联相关的四个已审计对象 | 390,532 | **19.01%** | rt2800lib +332,772，r8152 +43,216，zstd_double_fast +13,132，blake +1,412；包括内联、初始化、guard、循环等共同影响，不能全称为内联独立贡献 |
| 其余对象中新增帧指针建立指令 | 232,912 | **11.34%** | 排除上述对象后，add/mov fp,sp从1,741到59,969处，ARM每指令4 B；这是明确结构性指令差，未涵盖全部push/pop、保存/恢复变化 |
| 剩余未作因果分离部分 | 1,430,936 | **69.65%** | 其他内联、指令选择、分支、寄存器分配、序言/尾声、数据嵌入和布局等，不能自动归到某一原因 |
| 循环展开 | loft_iq中2次FullyUnrolled | 独立字节占比未知 | 已证实存在，和内联/初始化重叠；没报告的函数不等于全局未展开 |
| 自动初始化 | 多个rt2800/r8152函数保留AutoInitStore | 独立字节占比未知 | 两编译器均zero-init，Clang内联后存储多；未做消融，不能用store条数直接折成净字节 |
| 栈保护 | 最终.text guard失败调用13,898→13,988处 | 独立字节占比未知 | 新受保护函数与内联临时对象相关；canary加载方式也不同，不能以90次调用差代替全套guard字节 |
| 对齐填充 | 解码nop 6,972→5,112；链接.text残差差+772 B | 独立字节占比未知 | nop还可能有语义/热补丁用途；残差也含特殊输入节，不能据此说对齐是主因 |

上面前三行是**互斥的观测范围记账**（帧指针排除四对象），不是六类互斥的因果实验。命名归属排除也有同名局部函数/别名误差，故百分比保留两位；前50中存在很多GCC消失的helper，不能把它们的正增量直接累加后称内联比例。例：blake主函数+20,948 B，整个对象只+1,412 B，反证这种算法会高估。

本任务没有执行去掉内联/初始化/guard后的对照编译，故无法可靠给六类各自的独立净占比；这一限制明确保留，不捏造份额。[范围计算](../evidence/task3/cause_quantification.txt)、[全.text模式计数](../evidence/task3/full_text_instruction_patterns.txt)。此处详细原因采样以普通版为主，RT给出独立目录/函数/段数据，没有把普通因果比例套到RT。

## 4. .ARM.unwind_tab为何由13 KB到522 KB

普通`.ARM.unwind_tab` 13,152→522,312 B（+509,160），`.ARM.unwind_idx` 391,416→515,568 B（+124,152）。两段都SHF_ALLOC，按06规则常驻。RT数值见06逐段表，不能把普通计数写成RT实测。

平台readelf -u解码：

| 普通版EHABI条目 | GCC | LLVM |
| --- | ---: | ---: |
| exidx条目总数 | 48,927 | 64,446 |
| cantunwind | 41 | 45 |
| exidx内联compact model 0 | 47,790 | 20,875 |
| 指向extab的compact model 1 | 1,096 | 43,526 |
| 上项中包含vsp=r11 | 935 | 43,495 |

**这里不是EHABI generic/“非紧凑模型”：它们仍是compact model 1，只是展开操作不能塞进exidx的3个opcode字节，需要外部extab。** 此基线每个外部记录12 B，1,096×12=13,152，43,526×12=522,312，完整解释该段大小。样例包含`handle_fiq_as_nmi`、`bcm2835_handle_irq`、`gic_handle_irq`和大量trace_event函数；LLVM典型操作依次恢复vsp=r11、减偏移、pop多个寄存器。额外帧指针恢复加上pop编码使序列超过3 B。[解码证据](../evidence/task3/unwind_summary.txt)、[帧指针分布](../evidence/task3/unwind_frame_pattern.txt)。

LLVM22.1.8源码：`ARMELFStreamer.cpp:1314–1336`遇UsedFP生成恢复SP的操作，仅model 0且无handler data时不建立extab；`ARMUnwindOpAsm.cpp:158–188`按opcode数≤3选择PR0，否则PR1并按word补齐，streamer随后输出终止项。来源：[ARMELFStreamer](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/llvm/lib/Target/ARM/MCTargetDesc/ARMELFStreamer.cpp)、[ARMUnwindOpAsm](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-22.1.8/llvm/lib/Target/ARM/MCTargetDesc/ARMUnwindOpAsm.cpp)，缓存hash/行号见[来源记录](../evidence/task3/llvm_ehabi_source_identity.txt)；格式依据[ARM EHABI规范](https://github.com/ARM-software/abi-aa/blob/main/ehabi32/ehabi32.rst)。

这与driver传-mframe-pointer=all、实际60,225处建立fp一致。内联同时改变函数数目/栈布局，但不是“函数数量仅增32%就能解释extab近40倍”；主导特征是43,495个记录使用r11恢复SP，因而外移到model 1。

**没有已经验证安全的“一行关闭表”选项。** 当前ARM_UNWIND=y而UNWINDER_FRAME_POINTER=n，`-fno-unwind-tables`可能使内核栈回溯、perf调用栈、锁/崩溃诊断失去依据。候选是保持正确EHABI而验证部分/全部`-fomit-frame-pointer`，或优化LLVM的等价EHABI编码；应检查变长栈、汇编入口、IRQ、异常和函数图追踪。不能只删除输出section或strip表来宣称优化成功；本任务未执行这些候选。

## 5. 可提议的实验（只列出，未执行）

| 实验 | 预期作用 | 风险/约束 | 必须验证的指标 |
| --- | --- | --- | --- |
| rt2800lib/r8152及非热目录-O2→-Os | 限制helper重复与部分优化膨胀 | 驱动初始化/吞吐变慢；改变内联仍可能影响栈 | 四段/常驻、启动时延、网卡吞吐/CPU/栈峰值 |
| 用户sandbox/lhmax2025/mlgo的内联体积模型 | 用模型挑选内联，压低局部大函数 | 模型是否已编入Clang、ARM32训练分布与性能回归 | 版本/模型/flags证据、.text、IPC/CPU、启动与业务延迟 |
| 分目录调整inline阈值/限制大函数内联 | 降低rt2800级别的重复代码 | 少内联可能增加调用、访存与锁路径代价；不得全局盲设 | 对象/函数/常驻变化、性能、栈、remarks变化 |
| 帧指针/EHABI策略 | 降低序言和extab外部记录 | 本树依赖ARM_UNWIND；需保留可靠异常/IRQ回溯 | extab/exidx数量、unwind覆盖、panic/perf/ftrace栈与稳定性 |
| 修正TLS能力探测后重建受控基线 | 恢复每任务canary，使编译器比较更公平 | 探测通过不等于内核代码生成/切任务路径完全正确 | 配置、guard汇编、实际task偏移、SMP/切换、栈保护测试 |
| 自动初始化保留策略/热点局部消除冗余 | 避免内联后的重复zero store | 安全性退化，不能默认用全局关闭换体积 | 未初始化访问测试、安全要求、写指令/栈/业务性能 |
| 关闭无产品需求的驱动/debug | 减少06中确认无依赖的常驻功能 | 丢失附件/分区/现场诊断；必须先确认用途 | 配置依赖、常驻各段、模块加载、产品用例 |
| ARM32 LTO接入可行性 | 跨编译单元消重与全局优化 | 本树ARM32没有已接入路径，不能只写LTO_CLANG=y；汇编/链接/EHABI风险 | 另立可行性验证、链接正确性、启动/SMP/模块/回溯、体积与性能 |

MLGO已有用户分支`0eb2748f5d698124d24a6368936992af889ac9de`（packaging启用），是编译器优化，非页面置换ML；[任务1分支证据](../evidence/task1/sandbox__lhmax2025__mlgo_summary.txt)。当前五份.cmd没有-mllvm/MLGO参数，不能声称本基线已经使用模型。单文件remarks重编只是证据采集，没有执行本表优化实验。

## 6. STACKPROTECTOR_TLS探测失败已复现

`arch/arm/Kconfig:1376–1377`：CC_HAVE_STACKPROTECTOR_TLS检查`-mtp=cp15 -mstack-protector-guard=tls -mstack-protector-guard-offset=0`。`scripts/Kconfig.include:28`展开为`CC -Werror CLANG_FLAGS <选项> -c -x c /dev/null -o <临时对象>`；`scripts/Makefile.clang:4,20,28,34–39`给ARM配置`--target=arm-linux-gnueabi`和IAS/警告参数。**探测阶段没有实际编译命令中的-march=armv7-a。**

在LLVM buildroot的Clang22.1.8上原样执行上述编译器探测（仅把-o指向WS/temp/task3），exit=1，输出：`hardware TLS register is not supported for the armv4t sub-architecture`。同一完整命令只补`-march=armv7-a`，exit=0；只换armv7目标triple的先前对照也通过。未带TLS guard、只用-mtp=cp15的控制仍报armv4t不支持，证明是探测目标架构与CP15能力不一致，不能下结论“Clang22不支持ARM32 per-task guard”。

[完整精确探测及输出](../evidence/task3/kconfig_probe_exact.txt)、[ARMv7对照](../evidence/task3/kconfig_probe_armv7.txt)、[只保留cp15的控制](../evidence/task3/global_control.txt)、[triple控制](../evidence/task3/tls_armv7_triple_control.txt)、[源码行](../evidence/task3/kernel_source_references.txt)。未运行Kconfig的清理trap/重配置，原.config未动。

当前两版SMP=y、STRONG=y；`arch/arm/kernel/entry-armv.S:528–539`的全局guard随任务切换仅适用于非SMP，所以本基线不能借该UP路径获得每任务隔离。LLVM采用全局`__stack_chk_guard`，不是完全无栈保护。GCC每任务guard按当前task+offset访问，不同任务canary隔离；全局guard一旦被某上下文泄漏，其值可影响其他使用相同guard的任务，隔离弱于per-task。`arch/arm/include/asm/stackprotector.h`及最终.cmd支持此区别；不能据此宣称已存在可利用漏洞。

修复方向首先是**内核Kconfig能力探测的ARM目标一致性**：用实际适用CPU架构参数检查，而不是在未验证前改编译器或强写配置y。对于跨ARMv6/ARMv7等配置必须避免硬编码不适用架构；即使空输入通过，还需验证生成guard指令、task偏移与上下文切换。编译器侧可以改善诊断/默认目标策略，但本次证据没有显示Clang在明确ARMv7目标下不支持这些选项。

## 7. rpmdb只读归属核对

[只读原始输出与日志行](../evidence/task3/rpmdb_readonly_audit.txt)。本项按PM明确授权只读访问真实目录元数据、宿主rpm宏及已安装工具；未查询/修改真实rpm数据库，没有删除/移动外部文件。

| 核对项 | 观察 | 可推断范围 |
| --- | --- | --- |
| WS/temp/gbs-home/.rpmdb | 16:09:27检查不存在，故无mtime | 不能证明没有其他路径写入 |
| 宿主rpm --eval '%{_dbpath}' | /home/linhao/.rpmdb；/usr/lib/rpm/macros:124用bash展开~/.rpmdb | 此默认值受调用进程HOME影响；显式宏覆盖/root/dbpath仍可能改变结果 |
| 真实rpmdb.sqlite与wal | mtime均2026-06-10 11:11:49+08 | shm更新时间不能等同数据库包记录修改 |
| 真实rpmdb.sqlite-shm | size32768；mtime 2026-10-28 15:49:40.122885+08 | 晚于两构建结束，说明该mtime不是保留的构建中最后事件；不反证构建窗口内曾被更新 |
| 两轮时间窗口 | GCC13:18:57–14:18:01，LLVM14:18:01–14:55:09 | 两轮find都列shm，但未记录打开者PID/调用 |
| 构建日志 | GCC:178与LLVM:516明确是buildroot内exec rpmbuild；LLVM:234初始化rpm db | 没有宿主rpm的完整exec/路径跟踪，不能由安静日志证明宿主从未调用rpm |
| 其他gbs任务 | 本次启动existing_processes快照为空；本项检查时没有可匹配的gbs/depanneur进程 | 不能追溯用户此前提到的其他任务与shm写入关系，更不能指定它们为写入者 |

**结论：无法归属；不能认定属于本次，也没有足够证据归给其他来源。** 这是证据缺口，不把HOME隔离、当前进程快照或事后mtime当作追溯审计。进一步闭合需要在明确授权的新运行中记录实际写调用与PID/环境，而非再次事后find猜测。本轮没有重跑构建或自行加监控程序。
