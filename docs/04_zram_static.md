# 任务2：zram静态核对

更新：2026-10-28。基线 `f240c28093027707f5e09f8a9cbbed16a43ebb1a`。已完成源码接口、三补丁合入检查和快照；本轮用成功产物和最小平台编译探针核实结构布局，没有重编内核或上板。所有源码行号相对linux-rpi；[带行号证据](../evidence/task2/static_source_lines.txt)、[快照索引](../code_snapshots/INDEX.md)。

## 1. 能力接口

本节表内短文件名均位于drivers/block/zram/。

| 接口 | 实现与参数 | 条件/关系 |
| --- | --- | --- |
| recomp_algorithm | zram_drv.c:1166–1206，algo=名称、priority=N；默认次级优先级1，必须提供algo，合法次级范围1–3（zram_drv.h:94–102） | CONFIG_ZRAM_MULTI_COMP；只是配置次级算法，不等于已经执行重压缩 |
| recompress | zram_drv.c:1842–1999，type=idle/huge/huge_idle，max_pages、threshold、algo、priority；priority=0调整成1；未指定type时mode=0，无冷热筛选；未指定priority默认遍历次级优先级 | MULTI_COMP；初始化后使用；pp_in_progress阻止并发后处理。threshold必须小于huge_class_size（1913）；max_pages限制尝试次数，不等于成功页数（1776–1784） |
| idle按秒标记 | zram_drv.c:329–365；all或非负整数秒；计算boottime减age_sec截止时间；294–327逐页判定 | 秒数需要ZRAM_TRACK_ENTRY_ACTIME，否则返回EINVAL；all不要求ACTIME。访问更新时间见181–182 |
| algorithm_params | zram_drv.c:1060–1123；priority、algo、level、dict；algo可用于查找优先级 | comp_params_store在1007–1058；初始化后EBUSY。dict由kernel_read_file_from_path读取（1046），并非sysfs传入字典字节 |
| zstd dict/level | backend_zstd.c:70–91、139–140、185–212：缺省level用zstd_default_clevel；准备cdict/ddict，压缩和解压分别使用 | 源码有能力不等于defconfig已启用ZSTD后端；字典需从工作负载离线生成，运行效果未测 |
| writeback | zram_drv.c:609–655；idle、huge、huge_idle、incompressible或page_index=N；backing_dev见499–526，writeback_limit/enable见368–430 | CONFIG_ZRAM_WRITEBACK（2318–2323/2340–2351）；需已配置后端块设备，不能以静态支持代替板上介质与寿命评估 |
| 压缩流获取/释放 | zcomp.c:110–119：local_lock、本CPU stream、local_unlock | 当前获取/释放函数没有区分读流/写流，接口本身不是并行解压实现 |

属性注册证据：zram_drv.c:2324–2356。未知key在部分解析循环会被跳过，不应把上述解析器视为严格拒绝未知参数的接口。

四份最终.config均确认仅LZO后端、lzo-rle默认，MULTI_COMP/ACTIME/WRITEBACK=n，ZRAM=y；[各符号与行号](../evidence/task2/config_key_actual.md)。这是构建配置，不是板上sysfs实测。

## 2. armv7l元数据计算

这些布局现已用**最终产物DWARF和平台编译器sizeof/offsetof**验证。四配置均SMP=y、AEABI=y、DEBUG_SPINLOCK=n、DEBUG_LOCK_ALLOC=n；普通版PREEMPT_RT未启用、RT版为y，页大小4 KiB。不能无条件推广到其他页大小或锁调试配置。

- zram_drv.h:64–74含union(unsigned long handle/element)、unsigned int flags、spinlock_t lock，以及可选ktime_t ac_time。
- ARM32 unsigned long/unsigned int/指针为4字节；union占4字节。普通spinlock映射raw_spinlock（include/linux/spinlock_types.h:13–29）；无锁调试时raw只有arch_spinlock（spinlock_types_raw.h:14–23），ARM票据锁为u32 union（arch/arm/include/asm/spinlock_types.h:11–24），占4字节。
- 无ACTIME：offset 0/4/8分别放handle/flags/lock，共12字节、4字节对齐。
- ktime_t是s64（include/linux/types.h:125）；AAPCS32的64位成员按8字节自然对齐，依据[Arm官方AAPCS32基本类型表](https://github.com/ARM-software/abi-aa/blob/main/aapcs32/aapcs32.rst#fundamental-data-types)。加ACTIME后offset12补4字节padding，ac_time位于16–23，共24字节。**每槽增加12字节，而不只是时间戳的8字节。** AEABI选择见arch/arm/Kconfig:1166–1169，编译ABI参数见arch/arm/Makefile:112–115。
- 页大小由arch/arm/include/asm/page.h:11–12和arch/Kconfig:1239–1246决定；按4 KiB计，槽数=disksize/4096；表分配见zram_drv.c:1344附近。仅计算table，不含zsmalloc、压缩流、字典、对象载荷及分配器额外开销。

下表把用户的512MB/1GB/2GB明确按512 MiB/1 GiB/2 GiB（二进制单位）计算：

| disksize | 槽数 | 普通无ACTIME，12 B/槽 | 普通含ACTIME，24 B/槽 | 增量 |
| --- | ---: | ---: | ---: | ---: |
| 512 MiB | 131072 | 1572864 B = 1.5 MiB | 3145728 B = 3 MiB | 1.5 MiB |
| 1 GiB | 262144 | 3145728 B = 3 MiB | 6291456 B = 6 MiB | **3 MiB** |
| 2 GiB | 524288 | 6291456 B = 6 MiB | 12582912 B = 12 MiB | 6 MiB |

RT版应另算：spinlock_t为rt_mutex_base（spinlock_types.h:48–60），在相同无锁调试前提下raw锁4 + rb_root_cached两个指针8 + owner指针4 =16字节（rtmutex.h:23–27、rbtree_types.h:15–29）。因此table entry无ACTIME为24 B，含ACTIME为32 B，每槽增加8 B；512 MiB/1 GiB/2 GiB分别从3/6/12 MiB增到4/8/16 MiB，增量1/2/4 MiB。两版现已完成实际布局核验。这里没有使用宿主sizeof代替ARM32。


### 实际布局证据与方法（2026-10-28）

先用各自buildroot的pahole读取GCC/LLVM普通/RT的drivers/block/zram/zram_drv.o DWARF，四者均与关闭ACTIME布局一致：[原产物布局](../evidence/task2/zram_layout_baseline.txt)。再用LLVM buildroot Clang 22.1.8，将本次实际zram .o.cmd的架构/ABI/头文件/配置参数用于最小探针；移除依赖文件与原目标输出，所有新产物写temp/artifact_review_20261028，保留原config/generated headers，分别不定义/额外定义CONFIG_ZRAM_TRACK_ENTRY_ACTIME。探针包含真实zram_drv.h，未手写替代结构体，未修改源码或最终.config。

[探针全文](../evidence/task2/zram_layout_probe.c.txt)、[全部编译命令、pahole及readelf输出](../evidence/task2/zram_layout_probe.txt)。const数组记录sizeof、alignof、handle/flags/lock偏移、spinlock_t大小，开启时另记ac_time偏移/ktime_t大小；平台readelf读取ARM小端.rodata，与pahole一致。

| 变体 | ACTIME | sizeof | 对齐 | handle / flags / lock偏移 | spinlock_t | ac_time偏移/大小 |
| --- | --- | ---: | ---: | --- | ---: | --- |
| 普通 | 关 | 12 | 4 | 0 / 4 / 8 | 4 | 不存在 |
| 普通 | 开 | 24 | 8 | 0 / 4 / 8 | 4 | 16 / 8 |
| RT | 关 | 24 | 4 | 0 / 4 / 8 | 16 | 不存在 |
| RT | 开 | 32 | 8 | 0 / 4 / 8 | 16 | 24 / 8 |

每GiB disksize有1,073,741,824/4096=262,144槽；普通增加262,144×12=3,145,728 B=**3 MiB**，RT增加262,144×8=2,097,152 B=**2 MiB**。开启ACTIME的两份对象仅作布局探针，实际四份内核均未开启ACTIME，不声称已测量板上分配/回收开销。

## 3. LZ4三补丁合入检查

已从f240c280建立lko/tmp-lz4，依次执行以下cherry-pick，三次退出码均0、无冲突。检查后返回lko/base并删除临时分支；base与tizen未变。详见[原始命令输出](../evidence/task2/lz4_merge_check.txt)。仅验证文本合入，不代表可编译、通过测试或性能改善。

| 原提交 | 修改文件 | 作用 |
| --- | --- | --- |
| 1051099cb8da | include/linux/lz4.h，lib/lz4/lz4_compress.c、lz4_decompress.c、lz4defs.h、lz4hc_compress.c | 从1.8.3更新到1.10.0，涉及压缩/解压实现 |
| 7b64cf4f1065 | include/linux/lz4.h | 同步LZ4HC上下文布局 |
| 7459b2911b52 | lib/Kconfig、lib/lz4/lz4_decompress.c | 加入armv7 fast decode loop选择能力 |

## 4. 字典脚本与源码快照

85fcc6edce0b原始全文：[zram-dict-setup.sh](../code_snapshots/85fcc6edce0b/scripts/zram-dict-setup.sh)、[zram-dict-init.rc](../code_snapshots/85fcc6edce0b/scripts/zram-dict-init.rc)。仅上传核对，未执行、未安装、未部署。

setup.sh依次写comp_algorithm=zstd、algorithm_params（level=3，可带dict）、disksize=1G，再mkswap/swapon优先级100；字典预期由rootfs提供/etc/zram/zstd.dict，缺失时脚本退回无字典模式。文件后半的采样/训练/install只是注释中的离线示例，不会自动生成字典。

init.rc含systemd服务示例（注释：After=local-fs.target、Before=swap.target），及Android风格early-fs/fs/post-fs触发器；后者在fs配置sysfs，post-fs格式化启用swap。不能把该文件存在视为Tizen RPi已经集成这些触发器。脚本注释中的压缩比、时延和节省内存均是原作者假设，**不是本项目测量结论**；property回退触发器也不等于具备自动缺字典检测。

struct、recompress处理函数及zcomp流函数片段已上传到[code_snapshots/f240c2809302](../code_snapshots/INDEX.md)，注明原始行号。所有快照与源commit核对；没有改动内核代码。
