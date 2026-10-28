# 任务3：内核静态内存构成

**基线变更（任务4，2026-10-28）：本报告中任务2/任务3的体积数据均来自未启用ARM_PMUV3驱动的 `f240c28093027707f5e09f8a9cbbed16a43ebb1a`。后续A/B实验以 Gerrit `sandbox/lhmax2025/kernel_optimization` 的构建为准，当前基线 `0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`；本轮仅核对配置，没有生成新体积数据。见[08](08_sandbox_baseline.md)。**

2026-10-28。分析任务2的四份原产物，源码 `lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a`。没有修改内核、重新构建内核或操作开发板。单位统一为B，MiB=2²⁰ B。GCC/LLVM是两套GBS基线，不是完全控制了配置、依赖和链接器的单变量实验。

**普通版LLVM常驻已分配段比GCC多2,669,604 B（8.11%），与PM复核值完全一致；RT多2,516,690 B（7.58%）。** 完整vmlinux文件变小主要来自DWARF调试信息，不能当作静态内存下降。

## 1. 四类大小与统计边界

| 类别/字节 | GCC普通 | LLVM普通 | Δ普通 | GCC RT | LLVM RT | ΔRT |
| --- | --- | --- | --- | --- | --- | --- |
| 调试 .debug_*（非分配） | 371,084,669 | 294,059,724 | -77,024,945 | 380,296,444 | 301,358,541 | -78,937,903 |
| 常驻：其余 SHF_ALLOC | 32,930,806 | 35,600,410 | +2,669,604 | 33,222,614 | 35,739,304 | +2,516,690 |
| 启动后释放 .init* / .exit.text | 781,896 | 854,008 | +72,112 | 738,496 | 802,148 | +63,652 |
| 构建 .ko（含调试，52个/版） | 39,028,264 | 29,325,668 | -9,702,596 | 39,126,596 | 29,348,752 | -9,777,844 |
| 打包 .ko（52个/版，RPM内逻辑字节） | 2,641,484 | 2,821,812 | +180,328 | 2,648,528 | 2,821,912 | +173,384 |


常驻定义严格采用本任务口径：ELF有SHF_ALLOC，排除`.init*`和`.exit.text`；`.debug_*`没有SHF_ALLOC，不加载。`.BTF`虽为类型/调试信息，却有SHF_ALLOC，归常驻。`.bss`是NOBITS，文件不占等量空间但内存需要。模块行是文件逻辑大小，构建目录含调试，RPM内是打包处理后的.ko，不是压缩RPM大小或已加载模块内存；是否加载、重定位及模块BSS仍需运行时核实。

附注：完整vmlinux GCC/LLVM普通412,486,440/338,481,420 B，RT421,759,136/345,620,612 B；文件差−74,005,020/−76,138,524 B。文件还包含符号/字符串表、ELF头和间隙，不能用上述三段类别直接相加恢复文件大小。逻辑段字节也不等于板上物理页占用：段对齐空洞、启动重定位、每CPU实例、动态分配及CMA没有在此折算。

原始证据：[GCC普通section](../evidence/task3/sections_gcc_arm-rpi4.txt)、[LLVM普通](../evidence/task3/sections_llvm_arm-rpi4.txt)、[GCC RT](../evidence/task3/sections_gcc_arm-rpi4-rt.txt)、[LLVM RT](../evidence/task3/sections_llvm_arm-rpi4-rt.txt)；[模块计量](../evidence/task2/modules_rpm_contents.txt)、[任务2汇总](../evidence/task2/artifact_measurements.txt)。工具均为对应root内readelf/size/nm/objdump；通过root内qemu-arm或其emul原生加速工具执行，命令记录绝对路径，宿主Python只做文本汇总。

## 2. 常驻逐段、启动释放和嵌入表

| 常驻已分配段/字节 | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | --- | --- | --- | --- |
| .head.text | 708 | 704 | 708 | 704 |
| .text | 17,808,156 | 19,862,536 | 18,128,580 | 20,005,868 |
| .rodata | 5,217,374 | 5,144,813 | 5,159,246 | 5,095,013 |
| .pci_fixup | 11,024 | 11,024 | 11,024 | 11,024 |
| __ksymtab | 78,552 | 78,564 | 78,480 | 78,492 |
| __ksymtab_gpl | 85,992 | 85,992 | 85,932 | 85,932 |
| __kcrctab | 26,184 | 26,188 | 26,160 | 26,164 |
| __kcrctab_gpl | 28,664 | 28,664 | 28,644 | 28,644 |
| __ksymtab_strings | 277,542 | 287,458 | 277,267 | 287,183 |
| __param | 7,860 | 7,860 | 7,840 | 7,840 |
| __modver | 792 | 792 | 792 | 792 |
| .notes | 84 | 84 | 84 | 84 |
| .BTF | 6,440,894 | 6,475,431 | 6,435,889 | 6,480,016 |
| .BTF_ids | 1,876 | 1,876 | 1,880 | 1,880 |
| __ex_table | 1,680 | 1,736 | 1,680 | 1,736 |
| .ARM.unwind_idx | 391,416 | 515,568 | 391,616 | 519,752 |
| .ARM.unwind_tab | 13,152 | 522,312 | 13,056 | 524,508 |
| .vectors | 32 | 32 | 32 | 32 |
| .vectors.bhb.loop8 | 32 | 32 | 32 | 32 |
| .vectors.bhb.bpiall | 32 | 32 | 32 | 32 |
| .stubs | 848 | 848 | 848 | 848 |
| .data..percpu | 46,092 | 46,092 | 46,808 | 46,872 |
| .data | 1,874,192 | 1,870,640 | 1,886,416 | 1,882,896 |
| __bug_table | 28,620 | 38,220 | 28,800 | 38,736 |
| .bss | 589,008 | 592,912 | 610,768 | 614,224 |
| .rodata1 | 0 | 0 | 0 | 0 |
| .builtin_fw | 0 | 0 | 0 | 0 |
| __init_rodata | 0 | 0 | 0 | 0 |
| .sbss | 0 | 0 | 0 | 0 |
| 合计 | 32,930,806 | 35,600,410 | 33,222,614 | 35,739,304 |


| 启动后释放段/字节 | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | --- | --- | --- | --- |
| .init.text | 293,200 | 345,192 | 295,488 | 348,752 |
| .exit.text | 14,184 | 20,368 | 14,192 | 20,372 |
| .init.proc.info | 572 | 572 | 572 | 572 |
| .init.arch.info | 448 | 448 | 448 | 448 |
| .init.tagtable | 16 | 16 | 16 | 16 |
| .init.smpalt | 120,336 | 138,936 | 75,168 | 83,264 |
| .init.pv_table | 1,176 | 1,376 | 1,192 | 1,400 |
| .init.data | 351,964 | 347,100 | 351,420 | 347,324 |


`.data..percpu`仅为ELF模板，不能乘以一个猜测CPU数当作实测内存；`.head.text`等按PM命名规则归常驻，实际启动映射/页释放另需板上核实。kallsyms在`.rodata`中，以下边界不是独立section，不能再次加到常驻合计。`__mcount_loc`以及ftrace_events/eval_maps在`.init.data`中，启动后释放；运行期间另有ftrace动态管理对象，本任务未测。

| 数据区间（字节） | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | ---: | ---: | ---: | ---: |
| kallsyms_num_syms | 4 | 4 | 4 | 4 |
| kallsyms_names | 1,800,628 | 1,841,884 | 1,800,184 | 1,846,664 |
| kallsyms_markers | 2,020 | 1,984 | 2,020 | 1,992 |
| kallsyms_token_table | 932 | 928 | 932 | 928 |
| kallsyms_token_index | 512 | 512 | 512 | 512 |
| kallsyms_offsets | 516,116 | 507,072 | 516,272 | 509,280 |
| kallsyms_relative_base | 4 | 4 | 4 | 4 |
| kallsyms_seqs_of_names | 387,087 | 380,304 | 387,204 | 381,960 |
| mcount_loc | 228,600 | 223,760 | 228,208 | 223,980 |
| ftrace_events | 7,256 | 7,256 | 7,256 | 7,256 |
| ftrace_eval_maps | 6,200 | 6,200 | 6,200 | 6,200 |

边界原文及命令：[kallsyms/ftrace](../evidence/task2/kallsyms_ftrace_measurements.txt)。

## 3. 源码目录分布与加总核对

选择最终链接输入`build/<variant>/vmlinux.a`薄归档；平台`size -A`逐成员统计`.text* + .rodata* + .data* + .bss*`，`.data..percpu`单独排除；普通2957、RT2956个成员，避免把各层built-in.a、复合.o和模块重复相加。目录按归档成员路径归属，头文件内联归于使用它的编译单元。

误差/边界：字符串合并、COMDAT、对齐、`.sched.text`等特殊输入节、生成kallsyms对象和链接脚本收集项不是上述四种输入名前缀的一一映射。故**输入目录和并不直接等于最终四段**，以显式“链接残差”补齐，未按比例伪分摊到目录；它们也不是整个常驻的归属分解（不含BTF/unwind等独立段）。

| 口径/字节 | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | --- | --- | --- | --- |
| text 输入对象 | 17,755,780 | 19,809,388 | 18,055,136 | 19,938,716 |
| text 链接残差 | 52,376 | 53,148 | 73,444 | 67,152 |
| text 最终ELF | 17,808,156 | 19,862,536 | 18,128,580 | 20,005,868 |
| rodata 输入对象 | 2,545,318 | 2,445,637 | 2,553,626 | 2,454,683 |
| rodata 链接残差 | 2,672,056 | 2,699,176 | 2,605,620 | 2,640,330 |
| rodata 最终ELF | 5,217,374 | 5,144,813 | 5,159,246 | 5,095,013 |
| data 输入对象 | 1,703,979 | 1,700,435 | 1,723,427 | 1,719,874 |
| data 链接残差 | 170,213 | 170,205 | 162,989 | 163,022 |
| data 最终ELF | 1,874,192 | 1,870,640 | 1,886,416 | 1,882,896 |
| bss 输入对象 | 586,419 | 587,516 | 608,405 | 609,555 |
| bss 链接残差 | 2,589 | 5,396 | 2,363 | 4,669 |
| bss 最终ELF | 589,008 | 592,912 | 610,768 | 614,224 |


每列输入+残差与最终四段逐项完全吻合。普通.text差：输入2,053,608 B+残差差772 B=最终2,054,380 B；大.rodata残差主要包括生成kallsyms表。完整计算：[核对](../evidence/task3/archive_reconciliation.txt)、[各深度四段分量](../evidence/task3/directory_components.tsv)。

### 顶层目录（不足30项则全列）

| 目录：输入四段合计 | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | --- | --- | --- | --- |
| drivers | 5,871,930 | 6,675,815 | 5,895,509 | 6,678,428 |
| net | 5,169,202 | 5,483,249 | 5,341,692 | 5,601,528 |
| fs | 4,652,427 | 4,920,071 | 4,713,153 | 4,934,045 |
| kernel | 3,126,186 | 3,363,218 | 3,191,889 | 3,397,583 |
| lib | 1,099,308 | 1,196,685 | 1,101,221 | 1,197,349 |
| mm | 876,017 | 925,439 | 894,119 | 931,941 |
| sound | 593,275 | 665,964 | 592,402 | 662,880 |
| block | 325,075 | 358,445 | 328,045 | 357,470 |
| crypto | 258,778 | 290,014 | 259,214 | 289,954 |
| arch | 236,103 | 251,487 | 237,223 | 252,873 |
| io_uring | 158,319 | 170,043 | 160,355 | 171,443 |
| security | 147,014 | 163,141 | 146,947 | 168,127 |
| ipc | 57,482 | 59,189 | 58,201 | 58,777 |
| init | 19,713 | 19,487 | 19,957 | 19,701 |
| certs | 667 | 729 | 667 | 729 |
| usr | 0 | 0 | 0 | 0 |


### 主要子目录前30（深度2，以LLVM普通合计排序）

| 目录：输入四段合计 | GCC普通 | LLVM普通 | GCC RT | LLVM RT |
| --- | --- | --- | --- | --- |
| fs/btrfs | 1,233,427 | 1,329,389 | 1,241,384 | 1,323,797 |
| drivers/net | 683,262 | 1,108,606 | 689,260 | 1,111,869 |
| drivers/gpu | 955,825 | 977,121 | 956,217 | 977,466 |
| mm | 876,017 | 925,439 | 894,119 | 931,941 |
| net/ipv4 | 692,759 | 728,004 | 707,856 | 737,972 |
| net/core | 675,634 | 725,536 | 692,320 | 733,681 |
| net/mac80211 | 665,351 | 706,706 | 690,913 | 726,566 |
| drivers/usb | 652,964 | 700,607 | 653,753 | 698,849 |
| kernel/bpf | 606,232 | 675,154 | 615,789 | 681,089 |
| fs/nfs | 583,301 | 628,706 | 596,665 | 633,378 |
| fs/ext4 | 591,435 | 621,482 | 599,399 | 626,942 |
| drivers/media | 573,067 | 604,890 | 574,379 | 605,834 |
| net/wireless | 574,385 | 598,300 | 598,977 | 617,448 |
| kernel/printk | 588,002 | 593,890 | 590,330 | 594,370 |
| fs | 543,008 | 586,784 | 547,334 | 585,098 |
| lib/zstd | 477,478 | 543,401 | 477,606 | 543,401 |
| fs/f2fs | 533,848 | 525,577 | 542,857 | 530,189 |
| net/bluetooth | 480,037 | 524,929 | 486,081 | 524,209 |
| net/ipv6 | 466,706 | 482,964 | 484,962 | 494,993 |
| kernel | 431,838 | 480,503 | 434,902 | 475,663 |
| kernel/trace | 447,744 | 466,223 | 458,717 | 473,161 |
| net/netfilter | 421,176 | 457,729 | 457,117 | 490,166 |
| lib | 384,882 | 410,747 | 386,655 | 411,391 |
| net/sunrpc | 376,131 | 394,169 | 387,982 | 401,381 |
| drivers/tty | 320,914 | 360,563 | 319,139 | 358,135 |
| block | 313,011 | 343,984 | 315,977 | 343,001 |
| kernel/sched | 281,222 | 301,380 | 292,585 | 300,358 |
| sound/usb | 247,871 | 288,063 | 247,803 | 287,879 |
| crypto | 237,010 | 266,639 | 237,490 | 266,627 |
| fs/netfs | 262,002 | 266,437 | 272,714 | 273,713 |


每个深度内部互不重叠；顶层表与子目录表不能相加。更细的前30见[深度4](../evidence/task3/directory_detail_top30.tsv)，增长另见[07](07_llvm_text_growth.md)。

## 4. 内建驱动/文件系统的条件候选

以下均由四份最终.config核实为y，并确有链接输入。D指`arch/arm/configs/tizen_bcm2711_defconfig`，源码定义/配置行完整封存在[源码证据](../evidence/task3/kernel_source_references.txt)。数值是**当前对象核心四段范围的估算**，不是实际改配置后的差分，不含各自产生的BTF/kallsyms/unwind和调用点；字符串合并/依赖共享还会改变净收益。可模块化的tristate改m仍有模块存储，启动后若加载则不保证省内存。

RPi4板载硬件之外的USB/相机/触屏属于明显非必需路径，但TV具体BOM、产品附件与分区清单没有提供，不能认定任一TV都不需要。下表以明确条件列候选，未提出立即删驱动。

| =y候选 | 选择来源 | Kconfig定义 | GCC普通 | LLVM普通 | GCC RT | LLVM RT | 裁剪条件/风险 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BTRFS_FS | D:477 | fs/btrfs/Kconfig:3 | 1,233,427 | 1,329,389 | 1,241,384 | 1,323,797 | 根/数据分区均不用Btrfs时可m/n；关闭会失去读写/恢复Btrfs能力 |
| F2FS_FS | D:479 | fs/f2fs/Kconfig:2 | 533,848 | 525,577 | 542,857 | 530,189 | 确认无F2FS数据分区后可m/n；不能仅凭启动rootfstype=ext4推断所有分区 |
| NFS_FS | D:500 | fs/nfs/Kconfig:2 | 959,432 | 1,022,875 | 984,647 | 1,034,759 | NFS_FS及ROOT_NFS(:504)不用网络根/挂载时可m/n；数值含SUNRPC，仅在无其他RPC使用者时可一起省 |
| RT2800USB | D:248；rt2x00/Kconfig:141–145 select库，:238–240继续select RT2X00_LIB | drivers/net/wireless/ralink/rt2x00/Kconfig:138 | 162,263 | 497,998 | 162,288 | 498,445 | Ralink外接USB Wi-Fi，非RPi4板载无线；BOM无此设备时可m/n。含所选RT2800/RT2X00共享库 |
| USB_RTL8152 | D:236 | drivers/net/usb/Kconfig:99 | 80,471 | 123,741 | 80,499 | 123,869 | 外接Realtek USB网卡，非RPi4板载PCIe以太网；按产品附件支持决定m/n |
| USB_LAN78XX | D:237 | drivers/net/usb/Kconfig:115 | 33,443 | 34,998 | 33,407 | 34,878 | LAN78xx USB网卡，含旧RPi3 B+用途；RPi4无需其板载网口路径，附件支持仍需确认 |
| USB_NET_SMSC95XX | D:239 | drivers/net/usb/Kconfig:353 | 15,000 | 22,410 | 15,004 | 22,418 | SMSC95xx旧板/外接USB网卡；无此附件可m/n |
| USB_NET_NET1080 | drivers/net/usb/Kconfig:377 default y（USB_USBNET=y） | drivers/net/usb/Kconfig:375 | 1,765 | 1,749 | 1,773 | 1,761 | NetChip1080主机对接线（Laplink）非RPi4/TV基本需求，可m/n |
| VIDEO_IMX219 | D:332 | drivers/media/i2c/Kconfig:173 | 9,004 | 9,650 | 9,000 | 9,650 | 可选CSI相机；非板上必备，产品无此sensor可m/n |
| VIDEO_IMX708 | D:333 | drivers/media/i2c/Kconfig:327 | 12,030 | 12,300 | 12,046 | 12,304 | 可选CSI相机；同上 |
| VIDEO_OV5647 | D:334 | drivers/media/i2c/Kconfig:563 | 8,624 | 9,634 | 8,640 | 9,646 | 可选CSI相机；同上 |
| VIDEO_DW9807_VCM | D:335 | drivers/media/i2c/Kconfig:901 | 3,235 | 3,507 | 3,231 | 3,503 | 可选相机VCM；不使用对应摄像头可m/n |
| TOUCHSCREEN_EDT_FT5X06 | D:260 | drivers/input/touchscreen/Kconfig:771 | 13,198 | 13,344 | 13,210 | 13,356 | 可选FT5x06触屏，非板上必备；TV面板/附件清单无此控制器时可m/n |
| SND_USB_AUDIO | D:390 | sound/usb/Kconfig:13 | 247,871 | 288,063 | 247,803 | 287,879 | 整组sound/usb对象范围；若TV需USB声卡/耳机则保留或模块化，不能直接关闭 |


NFS数字含SUNRPC核心，仅在其他RPC用户也不需要时成立；RPi4本机启动cmdline含ext4不足以排除用户态NFS挂载。RT2800共享库由USB驱动select，必须解除选择者才能改库的值。Btrfs/F2FS还可能牵连压缩/校验库，表中不重复把这些共享库算入节省。全部对象成员清单与计量规则保留在temp/task3/savings.json，[发布估算表](../evidence/task3/configuration_object_estimates.tsv)。

## 5. 可由配置去掉的常驻项（均为估算）

### 5.1 BTF

仅ELF`.BTF`：GCC/LLVM普通6,440,894/6,475,431 B，RT6,435,889/6,480,016 B。若最终能关闭且不再保留嵌入BTF，可按整个该段估算静态节省；没有重链接，不预测其他节变化。

已确认使用者：`packaging/linux-rpi.spec:208–226`构建bpftool并对vmlinux执行BTF dump生成vmlinux.h；`:110–121,275–281,371`定义/安装btf-devel产物。`kernel/bpf/sysfs_btf.c:16–45`将内核BTF暴露在`/sys/kernel/btf/vmlinux`。vmlinux.h用于用户程序编译期类型描述，本身不等于运行时CO-RE重定位需要的目标BTF。

只读查询Tizen官方20261027.231956 armv7l headed/boot镜像清单，发现libbpf 1.6.2-1.15、resourced和插件；清单未证明存在或不存在CO-RE程序，BPF对象可能嵌入用户ELF。cgit查询因TLS握手失败，不能检查其源码；通用公开镜像也不代表实际TV镜像。**Tizen实际CO-RE/typed BPF依赖：待确认。** [镜像/包名证据](../evidence/task3/tizen_image_bpf_search.txt)、[尝试与失败原因](../evidence/task3/external_source_attempts.txt)；[官方清单](https://download.tizen.org/snapshots/TIZEN/Tizen/Tizen-Unified/reference/images/standard/tizen-headed-armv7l/tizen-unified_20261027.231956_tizen-headed-armv7l.packages)。

关闭影响：现有spec的BTF dump路径需配套调整；缺失内核BTF会影响依赖它的CO-RE目标发现、BTF类型校验以及fentry/kfunc等能力，不能泛称所有BPF都失效。`tools/lib/bpf/btf.c:5050`附近支持从sysfs/匹配vmlinux找BTF，`libbpf.h:145`允许btf_custom_path；提供与运行内核匹配的独立BTF可满足部分用户态CO-RE重定位，但不会替内核恢复其类型能力。

折中方案只作设计候选：保留含BTF构建产物供开发包导出，并把独立BTF随匹配版本交付、修改加载器路径；最后是否能从启动映像去掉BTF仍须核对内核和用户态依赖、重新链接与验证。**本树DEBUG_INFO_BTF是bool（lib/Kconfig.debug:377），没有“改成m”的路径；BTF_MODULES只为模块生成BTF，不能替代内核BTF。** 仅留下btf-devel的vmlinux.h不足以等价保留运行功能。

### 5.2 KALLSYMS_ALL

`LATENCYTOP=y`来自D:538，`lib/Kconfig.debug:1811`明确select KALLSYMS_ALL；另一个select来自LOCKDEP（:1506），四配置LOCKDEP=n。本基线主动选择来源为LATENCYTOP。仅在取消LATENCYTOP及核对所有select后，才可保持KALLSYMS=y但让ALL=n；直接写ALL=n会被select重新打开。

按最终kallsyms生成汇编的压缩名字流与nm类型，估算移除非T/t/W/w符号：普通GCC 62,528/129,029个（48.46%），LLVM60,496/126,768个（47.72%）。按各非函数名字当前压缩字节+每符号4 B offsets、3 B名字排序索引、markers减少量估算，可减少普通 **1,317,999 / 1,364,583 B**，RT **1,319,626 / 1,366,628 B**。不是简单用函数数量比例乘整个表，也不去掉token共享字典。类型代理、必须保留边界符号、重新压缩字典及对齐都带来误差；数值是估算，不能精确到1 B承诺。关闭失去全局数据符号解析/LatencyTOP相关诊断。[计算证据](../evidence/task3/kallsyms_all_estimate.txt)。

### 5.3 调试与追踪

| 选项（估算） | GCC普通 | LLVM普通 | GCC RT | LLVM RT | 来源 | 运行开销/关闭风险 |
| --- | --- | --- | --- | --- | --- | --- |
| KGDB / KGDB_KDB | 106,595 | 115,272 | 106,691 | 115,236 | D:532/533；lib/Kconfig.kgdb:11/91 | 串口断点、单步与KDB现场命令失效；默认cmdline含kgdboc，需同步检查运维方案。未启用断点时不等于持续调试停顿 |
| FUNCTION_PROFILER | ≥2,856 | ≥2,677 | ≥2,832 | ≥2,685 | D:539；kernel/trace/Kconfig:302 | 已识别独占常驻符号下界2,856/2,677/2,832/2,685 B；共享ftrace/strings/动态表未归属。默认function_profile_enabled=0，启用后每函数计数/时间开销 |
| STACK_TRACER | 7,256 | 7,269 | 7,288 | 7,353 | D:540；kernel/trace/Kconfig:316 | 启用时每函数检查最大栈深；关闭失去最大栈现场证据；仍保留FUNCTION_TRACER时不能减去通用-pg开销 |
| IRQSOFF_TRACER | 3,856 | 4,131 | 4,024 | 4,243 | D:541；kernel/trace/Kconfig:346 | 中断开关路径调用trace_hardirqs_*，查每CPU状态/追踪条件；关闭失去长关中断定位。共享TRACE_IRQFLAGS另有2,217/2,487 B普通核心对象，其他选择者存在时不消失 |
| SCHED_TRACER | 5,416 | 5,879 | 5,860 | 6,331 | D:542；kernel/trace/Kconfig:394 | 开启wakeup tracer后跟踪唤醒/切换、锁与时间戳；关闭失去调度延迟追踪，普通未激活时不应按完整回调成本计 |
| LATENCYTOP | 8,323 | 8,610 | 8,323 | 8,610 | D:538；lib/Kconfig.debug:1804 | 记录任务阻塞栈/延迟并搜索匹配记录；关闭失去LatencyTOP，并需核对KALLSYMS_ALL的其他选择者。任务结构/动态影响不含在本表 |
| DETECT_HUNG_TASK | 2,193 | 2,252 | 2,385 | 2,444 | D:536；lib/Kconfig.debug:1215 | 周期扫描阻塞任务，超时告警；关闭失去hung task告警，收益取决于实际超时/任务数 |
| DEBUG_MEMORY_INIT | 已定位0；总量未知 | 已定位0；总量未知 | 已定位0；总量未知 | 已定位0；总量未知 | D:535；lib/Kconfig.debug:893 | 已命名mminit检查代码/变量556/640/556/640 B位于.init.text/.init.data；已识别常驻贡献0 B，不把整个mm_init.o当作节省量。字符串/内联未分离，省量未知；关闭失去启动期内存布局自检 |
| BLK_DEV_IO_TRACE | 15,231 | 16,363 | 15,907 | 16,527 | D:543；kernel/trace/Kconfig:643 | 启用blktrace后写事件；关闭失去块I/O延迟现场证据；静态key/调用点与通用trace共享成本未隔离 |
| FTRACE / FUNCTION_TRACER | 449,724 | 467,987 | 460,697 | 474,925 | FTRACE默认DEBUG_KERNEL；STACK_TRACER select FUNCTION_TRACER，kernel/trace/Kconfig:185/321 | 表值为kernel/trace及ARM ftrace实现整组，包含其他共享追踪设施，不能声称只关一个bool就全部释放；还需单算全局-pg，见下文 |


表中“核心对象”不含被内联到调用者的代码、共享字符串、unwind和BTF；FUNCTION_PROFILER采用最终符号下界（其中含44 B每CPU模板，未乘CPU数），DEBUG_MEMORY_INIT只把明确init代码判入启动释放，不用总对象大小冒充常驻收益。[独占符号证据](../evidence/task3/profiler_and_memory_init_symbols.txt)。KGDB含KDB，KDB子集普通69,732/73,536 B，不能两项相加；每CPU模板另见估算表。

IRQ路径依据：`include/linux/irqflags.h:196–225`中local_irq_enable/disable/save/restore调用trace_hardirqs_on/off；`kernel/trace/trace_preemptirq.c:53–96`含每CPU状态检查与事件/延迟追踪调用。即使lockdep关闭，也不能断言这些调用消失；实际纳秒开销需板测。其他开销是源码确定的工作类型，不是执行时间测量。

ARM32 `-pg`插入push {lr}与bl __gnu_mcount_nc；`arch/arm/kernel/ftrace.c:25–42`说明动态关闭时把bl替换为add sp,sp,#4，前一条push仍在，所以“运行时关闭等于无指令成本”不成立。最终普通`.text`中GCC/LLVM分别55,344/53,937处mcount调用，按两条ARM指令估算 **442,752 / 431,496 B** 插桩；函数序言变化、常量池和重排的额外收益未量化。不要用全部mcount_loc条数乘8当作常驻：其中还有init函数。`__mcount_loc`本身228,600/223,760 B在init.data，启动后释放，不能再计入常驻裁剪收益。[指令统计](../evidence/task3/full_text_instruction_patterns.txt)、[源码](../evidence/task3/kernel_source_references.txt)。

### 5.4 优先评审的前五项

按普通版估算范围排序，不相加；“关闭”均以产品/运维依赖已排除为前提。

| 候选 | GCC普通估算B | LLVM普通估算B | 主要不确定性 |
| --- | ---: | ---: | --- |
| 嵌入.BTF | 6,440,894 | 6,475,431 | 用户态CO-RE、内核typed BPF与spec开发包，待确认 |
| KALLSYMS_ALL数据符号 | 1,317,999 | 1,364,583 | 先解除LATENCYTOP select；重压缩与边界保留 |
| Btrfs对象 | 1,233,427 | 1,329,389 | 实际分区/恢复需求；共享压缩库不计 |
| NFS+不再使用的SUNRPC | 959,432 | 1,022,875 | 网络根/用户态挂载、其他RPC用户 |
| 函数追踪及整组追踪设施+插桩的宽范围 | 892,476 | 899,483 | 449,724/467,987对象+442,752/431,496插桩；含共享设施，不能仅关FUNCTION_TRACER就承诺全部省下 |

下一项F2FS核心对象约533,848/525,577 B。前五是优先确认用途的候选，不是经重编验证的收益排序；追踪大范围与各debug行重叠，KALLSYMS_ALL与LATENCYTOP相互依赖。

## 6. CMA与其他预留：只记录，不评估

- D:526及最终.config均为CMA_SIZE_MBYTES=256；不能据此断言板上实际保留256 MiB。
- RPi4 DTS递归include闭包内，`bcm283x.dtsi:11`声明`/memreserve/ 0 0x1000`（4 KiB启动stub）；`:33–43`的linux,cma为reusable、linux,cma-default，size=0x04000000（64 MiB）。
- `bcm2711.dtsi:1118–1125`限定CMA分配地址低1 GiB，`bcm2711-rpi-ds.dtsi:80–83`又覆盖为低768 MiB；这是地址范围，不是额外预留容量。
- `bcm2711-rpi-ds.dtsi:6`bootargs含coherent_pool=1M、cgroup_disable=memory等；编入CONFIG_CMDLINE为`console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait`，CMDLINE_FROM_BOOTLOADER=y，未包含cma=。保留源码bootargs全文于证据。
- 未取得实际启动分区cmdline.txt/config.txt、固件GPU划分、运行时DT及覆盖层选择；CMA Kconfig默认、DT值和固件覆盖最终何者生效需上板核实。上述来源不合并成一个“已预留总量”。

[保留内存原行](../evidence/task3/reserved_memory_sources.txt)、[最终配置与源码行](../evidence/task3/kernel_source_references.txt)、[DTS include闭包](../evidence/task2/bcm2711_dts_scan.txt)。

## 7. 可复核性与限制

原始完整size/反汇编/优化记录留在temp/task3；Git只提交小体积文本摘要及命令，索引见[evidence/task3](../evidence/task3/README.md)。所有节省量均为估算；没有修改配置或重编验证，没有把构建产物数字改称板上运行时内存。任务3的四个单文件Clang重编仅为获取07的内联记录，输出独立temp路径且.text与原对象逐字节相同，未用于替换本报告四份原产物。
