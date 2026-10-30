# 项目状态

更新：2026-10-30（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**设计文档当前版本为v2：[docs/10_design_v2.md](10_design_v2.md)，待外部评审；[v1](10_design_v1.md)保留为历史记录。** 本次计划为原样移动v2与上一轮评审记录、登记两项常规授权并提交main；文件移动和授权登记已完成，未执行板上实验。

- v2为同日修订版，补入上一轮 Claude Code 完整评审中初稿遗漏的内容；已从指定Downloads路径移动覆盖现有文件，Downloads下已无该文件；移动过程未修改内容，75,639 B，移动前后SHA-256均为`4894e7c188d5fefb1c940ede06af9882d8f550487bf86987d32d2523e47c1bdc`。
- 上一轮评审记录已找到：`docs/11_design_v1_review.md`原样移动至[docs/reviews/design_v1_review_claude_code.md](reviews/design_v1_review_claude_code.md)；69,236 B，移动前后SHA-256均为`df909afc7e4c30b8d495c280950a81abe24554f0b4766ca20ad969bbfde59392`。移动验证原文在`temp/design_v2_intake_20261030/moves_verified.json`。
- 已登记两项常规授权，今后不再逐次申请：同一次QB构建的临时perf及缺失库按任务5c流程在/opt/usr任务专用目录运行，三个环境变量仅指向该目录，结束删除并核对df/mounts；实验可修改/proc/sys和/sys可写参数，记录原值、结束恢复并回读、写入报告，同板参数实验串行。详见[RULES板上常规授权](RULES.md#板上常规授权2026-10-30pm裁决)。其余规则不变，重启仍由用户执行、不用sudo、不碰其他任务进程。

**任务5c已完成实测与清理：硬件计数可用，cycles采样32个样本且evlist明确type=0；分支栈采样-b在当前组合不支持（255）；未观察到软件事件替换。** 一次性授权的数据分区目录`/opt/usr/lko_task5c`已整体删除，ls确认不存在、df前后相同。未remount、写根文件系统、安装RPM或改paranoid。

## 计划与进度

本轮计划：读取规则/状态 → 记录一次性数据分区授权 → 身份/挂载/空间/所有者只读预检 → 仅推perf和缺失库 → version、stat、cycles record/evlist、branch record → 清理/df对照 → 09/RULES/STATUS及evidence/task5c同commit推main。已完成。

- SDB连接192.168.108.26:26101；三项身份、BUILD_ID和/proc/version与任务5b一致。会话起止均已uid0，未切换SDB root模式；paranoid始终2。保留起止uptime/进程快照，未操作既有串口shell PID3708或其他进程。
- /proc/mounts筛出13个rw且不带noexec的挂载点，选`/opt/usr`（/dev/mmcblk0p5、F2FS，独立于根/dev/mmcblk0p2）。写前可用115,421,020 KiB；父目录0:0、0755。专用目录原先不存在，新建后0:0、0777、SMACK User::Shell；未修改安全策略。
- 复用已验证来源的QB perf及工作区LLVM root的唯一缺失libLLVM.so.22.1，共34,480,560 B；推送前后SHA一致。依赖重新逐项只读确认，不推板上已有库。HOME/TMPDIR/LD_LIBRARY_PATH仅指向专用目录。
- perf6.12.80 version成功；stat cycles=3,071,509、instructions=1,042,281、branch-misses=9,343，退出0。cycles record(-c100000/sleep2)退出0、32样本；evlist type0/config0。
- record -b退出255，原文“PMU Hardware or event type doesn't support branch stack sampling.”。这项是已取得的“不支持”测试结论，不是未执行项；branch-misses计数成功不能替代分支栈采样。
- 未观察到软件事件替换：cycles记录明确type0，stat仍输出原三硬件事件，-b直接失败。没有泛化到未测试事件。
- 清理前du最大34,440 KiB（含HOME内自动生成的.debug缓存），低于50 MiB。整个目录已删除，ls退出2/No such file；df已用983,204 KiB、可用115,421,020 KiB前后完全相同。/proc/mounts全文前后相同。

## 已闭合结论（附证据）

| 结论 | 证据 |
|---|---|
| 本次使用获准、可执行的独立数据分区，未写根分区 | [全部候选/选择](../evidence/task5c/mount_selection.md)、[写前df/所有者](../evidence/task5c/04_preflight.transport.txt) |
| 硬件计数与cycles采样可用，记录不是软件时钟 | [stat](../evidence/task5c/10_perf_stat.transport.txt)、[record](../evidence/task5c/11_perf_record.transport.txt)、[type0](../evidence/task5c/12_perf_evlist.transport.txt) |
| 当前组合不支持-b分支栈采样；未发生可观察的软件事件替换 | [branch报错](../evidence/task5c/13_perf_branch.transport.txt)、[三项结论](../evidence/task5c/conclusions.txt)、[09 G节](09_board_rpi4_readonly.md) |
| 专用目录清理完成、df/mounts/paranoid前后核对通过 | [结束原文](../evidence/task5c/16_cleanup_end.transport.txt)、[摘要](../evidence/task5c/cleanup_summary.txt)、[命令全表](../evidence/task5c/board_commands.jsonl) |
| QB1211696来源与最终.config此前已按PM裁决闭合 | [来源裁决](../evidence/task5b/pm_adjudication_20261030.txt)、[配置摘要](../evidence/task5b/config_comparison_summary.txt) |
| 设计10原文保持不变；BPF静态缺口与运行未知分别记录 | [设计10](10_design_v1.md)、[BPF源码](../evidence/task5b/bpf_source_error_chain.txt)、[BPF运行摘要](../evidence/task5b/bpf_runtime_summary.txt) |

## 需要人工裁决的前提与挂账

- 临时perf和运行时参数现按上述常规授权执行，无需逐次申请；后续性能实验由PM下发。任务5c硬件能力测试不是产品工作负载基准。
- -b不支持已由实测确认；若后续设计需要分支样本，采样方案需另行设计。perf build-options的auxtrace=on、libopencsd=OFF也不能独立证明CoreSight可用；本次不扩展测试。
- BPF插件历史load/attach尝试及实际失败原因仍无法判断，缺少相关日志。是否受控触发、插件产品需求/BTF取舍由PM决定，未启动服务或手动加载BPF。
- QB开始时间按UTC理解是PM接受的推断，未独立证明页面时区，不再作为来源停止条件。
- 设计当前版本为v2，待外部评审；v1原样保留为历史记录，其历史“待闭合/未实测”描述保留为PM原文；当前结果以09及本状态为准。

## 保留的任务5/5b结论

QB1211696 BUILD_PKG_LIST固定`platform/kernel/linux-rpi@0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`。PM接受SHA作为来源证明，不再要求包级分支；PROJECT_BRANCH=tizen为项目级字段且USE_BRANCH_POLICY=false，公开产物目录与板上BUILD_ID一致。按UTC推断的构建窗口2026-10-28 10:58:35–17:14:18包含内核12:18:25 UTC；本地远端跟踪refs只有授权sandbox包含该SHA。[09 A节](09_board_rpi4_readonly.md)。

指定公开来源的devel/perf RPM已下载、未安装。devel最终.config与任务4LLVM普通版全文相同，194,980 B、SHA256 `62e3b8512d8bd4a336410a9468afd8c1ed338b9030dc69c754dbccf888617ba5`，平台diffconfig为空。设计10为21,880 B、SHA256 `80ecded8314071d8781c7329b37210613d8c788e819fba9a13c6d76c25909249`，前轮已移动入库，本轮未改。

ARM32缺少BPF trampoline；正常前置条件下挂载先从弱size实现返回-ENOTSUPP(524)。当前未见resource-monitor进程/插件映射或实际加载失败日志；静态缺口不等于实测失败，也不自动批准移除BTF。任务5时BTF6,478,350 B、tracefs开启但nop/events0、F2FS在用、六个指定外设驱动未绑定、MGLRU0x0001、zram lzo-rle/1,628,766,208 B、实际CMA320MiB，未在本轮重复采集。

任务5b续提交`0f2bd63c0b6e8b6f07bb7ff2d67d5fefb290b91b`记录的/tmp noexec阻塞，已由本次新授权路径解决；旧证据保留为历史。没有重新登录QB、下载其他包、改源码或完整编译。

## 内核基线与历史挂账

- Gerrit唯一授权目标`sandbox/lhmax2025/kernel_optimization`与本地lko/base为`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`，相对tizen@42aeefac为force_reclaim与PMU两提交；相对21645b17多4提交。四组合配置只ARM_PMUV3 n→y。[08](08_sandbox_baseline.md)。本轮未改内核树或推Gerrit。
- 任务2/3体积来自不含PMU的f240c280：普通LLVM常驻+2,669,604 B（8.11%）、RT+2,516,690 B（7.58%）。不是本次QB镜像体积。[06](06_static_footprint.md)、[07](07_llvm_text_growth.md)。
- 代码增长的六类独立贡献未分离；rpmdb归属不明；ARMv4t/CP15 TLS探测问题未修复。可选nm扫描只保留旧状态，不将旧快照当当前运行情况。
- 平台缺llvm-bolt/create_llvm_prof，ARM32 AutoFDO消费链未接入。任务2 GCC/LLVM墙钟58:44.70/36:50.38；ACTIME普通12→24B、RT24→32B，每GiB增3/2MiB。[03](03_baseline_build.md)、[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)。
- 产品BOM、现场调试取舍、网络监控插件需求及BTF替代、zstd回退执行链、CMA固件来源仍需后续核实；不由当前未使用直接推定可裁剪。

## 发布状态

本次09、RULES、STATUS与evidence/task5c在同一commit普通推送GitHub main，署名Hao Lin <hao.lin@samsung.com>，沿用现有认证。仅上传小于1MB文本；RPM、ELF、p.data、辅助脚本与完整原始日志留temp。最终commit见本轮回复。
