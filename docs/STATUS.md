# 项目状态

更新：2026-10-29（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务5只读采集与报告完成；镜像SHA/最终配置核对、perf实测仍有明确缺口。** RPi4身份断言通过，PMU驱动已绑定；未安装perf，不能把驱动注册等同硬件计数/采样成功。`/tmp/lko_task5`已删除，SDB恢复owner，未修改内核、系统参数或服务配置。

## 计划

本轮：读取规则/状态 → SDB连接及身份/root/进程记录 → 开机超过5分钟后优先取F快照 → A–H只读采集与受限perf尝试 → 拉回候选ELF，用平台工具静态核对 → 删除板上临时文件 → 09、RULES、STATUS、evidence/task5同commit普通推GitHub main。已按此完成。

下一步依PM补充信息和任务安排：取得QB构建记录及最终.config后补来源/配置核对；需要采样时由PM另行决定提供perf的方式；不自行安装、挂载启动分区、加载BPF程序或更改用户态配置。

## 进度

- 仅SDB访问192.168.108.26:26101，uname-r含rpi4、架构armv7l、Tizen11.0均通过。sdb root on成功，结束恢复owner。
- /proc/version为Clang22.1.8/LLD22.1.8，内核构建于2026-10-28 12:18:25 UTC。PM声明来自sandbox@0fac5de6；版本不含SHA，尚未取得QB记录，独立来源核对未闭合。
- /proc/config.gz不存在；模块build链接失效，没有找到已安装配置副本；boot_a未挂载。未运行缺输入的diffconfig，未报告零差异。
- Cortex-A72 PMU已注册，启动日志7 counters；板上perf缺失，version/stat/record/record -b均127，没有实际perf负载或perf.data。CoreSight sysfs/DT相关节点未发现。
- BTF 6,478,350 B；当前FD/maps/pins未见BPF运行证据；网络资源监控插件存在真实静态CO-RE/BTF依赖，不再仅处于“是否安装相关程序待确认”的状态。
- tracefs全局开关开着，当前nop、events=0、无实例；function profiler/stack tracer/latencytop均0。F2FS正在承载用户分区；Btrfs/NFS无当前挂载。指定六个USB网卡/声卡驱动均没有设备绑定。
- MGLRU=0x0001、min_ttl_ms=0；zram0=lzo-rle、1,628,766,208 B；resourced写zstd、ratio0.4，算法不一致；没有修改或验证回退执行链。实际CMA=320MiB。
- HZ由timer_list两快照估算约100；memcg v1，取得67个目录的limit/usage及force_reclaim存在性。完整vmstat和原始配置保留本地。

## 已闭合结论（附证据）

| 结论 | 证据 |
| --- | --- |
| A–H报告，B–E产品取舍事实前置 | [09](09_board_rpi4_readonly.md)、[任务5证据索引](../evidence/task5/README.md) |
| 当前Clang版本、构建时间，配置/SHA不能独立核对的原因 | [A身份](../evidence/task5/A_identity_memory.txt)、[A核对缺口](../evidence/task5/A_config_comparison.txt) |
| 有CO-RE静态依赖、当前未观测运行 | [B ELF](../evidence/task5/B_elf_btf_analysis.txt)、[B方法](../evidence/task5/B_embedded_method.txt)、[B运行](../evidence/task5/B_bpf_runtime.txt) |
| 追踪实际状态、F2FS使用、USB六驱动未绑定 | [C](../evidence/task5/C_debug_usage.txt)、[D](../evidence/task5/D_filesystem_usage.txt)、[E](../evidence/task5/E_usb_usage.txt) |
| MGLRU/zram及resourced不一致 | [F运行](../evidence/task5/F_memory_runtime.txt)、[F配置全文](../evidence/task5/F_resourced_config.txt) |
| PMU驱动生效；perf不存在，计数/分支测试未完成 | [G](../evidence/task5/G_pmu_perf.txt) |
| HZ运行时估算、CPU频率状态 | [H](../evidence/task5/H_scheduler_clock.txt) |
| 板上临时目录已删除、owner已恢复、全部执行命令 | [清理](../evidence/task5/session_and_cleanup.txt)、[命令全集](../evidence/task5/commands.txt)、[原始文件哈希](../evidence/task5/raw_manifest.tsv) |

## 需要人工裁决的前提

- 需要本次QB构建编号/记录及最终arm-rpi4.config，才能独立证明运行镜像对应0fac5de6并逐符号比较。当前只能引用PM声明，不能猜测配置一致。
- 若继续验证cycles/instructions/branch-misses、硬件采样或分支采样，需要PM决定如何提供板上perf；本任务禁止安装和推二进制，已遵守。
- resource-monitor-plugin-network内嵌fentry/CO-RE程序存在，但当前没有运行证据。BTF是否可裁剪仍需该功能产品需求、触发条件及外部BTF替代路径核对；静态依赖已是实际ELF事实。
- F2FS当前在用；其余文件系统/外设的当前未用不能替代产品BOM。调试能力保留策略由PM决定。
- resourced请求zstd与zram实际lzo-rle不一致的具体执行链、CMA320MiB的固件配置来源仍待确认。未挂载boot分区、未触发算法切换或回收。
- 采集时已有root交互shell与高CPU的enlightenment；未识别出明确其他实验，但无法排除共用工作线。未干预，结果不是严格空闲性能基线。

## 已建立的内核基线

任务4完成，Gerrit唯一授权目标`sandbox/lhmax2025/kernel_optimization`与本地`lko/base`均为`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`；相对42aeefac为force_reclaim修复和PMU两提交，相对板上旧源码21645b17多4提交。四组合配置核对仅ARM_PMUV3 n→y，tizen仍为42aeefac。见[08](08_sandbox_baseline.md)。本轮未修改或推送内核仓库。

任务4结果GitHub commit `ff4e843d87dffb51a6d2aa68850a2328de176bf4`。后续所有内核改动仅向上述sandbox普通推送；不改写已推送提交、不推refs/for/*。

## 历史测量和挂账

- 任务2/3体积仍来自**没有PMU驱动的f240c280**，不是本次sandbox镜像的体积。任务3 commit `3f26e8d2f7806751034b4a15259edf39d9ae0a3c`；普通LLVM常驻+2,669,604 B（8.11%）、RT+2,516,690 B（7.58%），不能把完整ELF缩小称为内存下降。[06](06_static_footprint.md)、[07](07_llvm_text_growth.md)。
- 任务3六类代码增长独立贡献未分离；19.01%为四对象混合增量、11.34%为其外帧指针建立指令、余69.65%未分离。rpmdb更新归属仍不确定；TLS探测ARMv4t/CP15问题已定位未修复。
- 两个可选nm扫描仅在任务4收尾曾记录运行；本轮不检查或操作其他任务进程，不将旧快照当当前状态。正式任务3目录统计不依赖它们。
- 任务2：buildroot磁盘为普通权限下界；平台缺llvm-bolt/create_llvm_prof；ARM32 AutoFDO仍缺内核配置/Kbuild与采样转换消费链。任务5补上PMU驱动实际绑定证据，但板上无perf，CoreSight路径也未暴露。
- 任务2构建墙钟GCC58:44.70/Clang36:50.38；ACTIME布局普通12→24B、RT24→32B，每GiB增3/2MiB；LZ4三补丁合入检查干净。保留[03](03_baseline_build.md)、[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)，不因现场发现而改写旧构建数据。

## 发布状态

本轮09、RULES、STATUS及evidence/task5在同一GitHub提交，以Hao Lin <hao.lin@samsung.com>署名、正常Git环境普通push main；具体commit见本轮回复。发布的仅小于1MB的文本，原始日志/候选ELF仅留temp/task5。没有向其他人或外部服务发送采集消息。
