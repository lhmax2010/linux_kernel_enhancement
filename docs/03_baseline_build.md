# 任务2：armv7l 构建基线与实际配置核对

日期：2026-10-27（Asia/Shanghai）。本报告只记录本任务实际执行的结果；未获得的构建产物指标不以源码推导替代。所有体积与构建开销数字均为构建产物/开发机数据，不代表板上运行时内存。

## 最新任务2续二：源码核对、准备与静态成果

PM已明确采用工作区HOME方案，并排除修改源码.gbs.conf/exclude、独立工具副本及专属隔离环境；这些旧方案不再是待决事项。裁决已原文写入RULES两条硬要求之后。

- 源码核对确认用户配置由expanduser定位；已安装Python有HOME时优先使用HOME。gbs build→os.system→depanneur fork/exec→gbs export链未发现清空或重设HOME/GIT_CONFIG_NOSYSTEM。新方案能修正此前的用户配置来源，但这只是源码判断，尚无strace通过结果。完整路径清单与行号见[home_source_audit.md](../evidence/task2/home_source_audit.md)。
- 步骤2已完成：temp/gbs-home/.gbs.conf为两行普通文件；linux-rpi/.gbs.conf未改，base仍为f240c280、tizen仍42aeefac，工作树干净。见[准备记录](../evidence/task2/home_preparation.txt)。
- **导出/构建未执行：当前代理执行环境禁止重设HOME，无法执行PM规定命令。** 没有运行不带指定变量的GBS，也没有用替代方式绕过。此限制不是GBS或源码方案失败，不向PM重复请求已完成的方案裁决。
- 没有export_check_home.txt或r2日志、没有marker/find监测，没有实际打开配置路径清单；未发生本轮构建中断，未发送信号或调用sudo。不能声称“未检测到工作区外写入”或“导出通过”。
- 已继续独立步骤6：zram接口与ARM32布局推导、三条LZ4无冲突合入检查及临时分支删除、字典脚本全文与源码片段、Kconfig/DTS/perf静态核对。详见[04](04_zram_static.md)、[05](05_kernel_fdo_static.md)。
- LLVM是否确为Clang、四份最终.config、01修正符号数、两次完整耗时及vmlinux/zImage差值仍未取得。旧GCC的5:37.12/exit143是前轮人为中断尝试，不移用为本轮数据。平台LLVM工具版本和BOLT支持架构未确认。

以下保留上一轮与最初任务的历史记录，不能据此启动已被PM排除的方案。

## 本轮续任务：步骤A完成，步骤B停止（2026-10-27）

- 已按要求仅修改base标题为 `mm: restore vendor reclaim semantics for force_reclaim`；新SHA `f240c28093027707f5e09f8a9cbbed16a43ebb1a`。原tree、parent、作者/日期、提交者/日期、正文均逐字验证相同，`git diff 563c53c4 f240c2809302`为空，tizen未变且工作树干净。证据：[base_amend_r2.txt](../evidence/task2/base_amend_r2.txt)。初次amend被已有hook追加Change-Id，验证发现后用命令级工作区空hooks目录重新amend，最终正文严格保持原样；没有改全局配置或原hook。
- **项目.gbs.conf静态可见，但原GBS不能仅通过-c/项目键禁用外部配置文件加载。** `/etc/gbs.conf`不存在，`~/.gbs.conf`存在；只有5个键，无凭据键。当前build使用的profile/buildroot已有本项目覆盖，外部仓库节不选用；export不使用这些构建键。两个项目conf本轮新增覆盖0个键。
- `conf.py:318–321`仍逐个读取自动发现的文件，`add_conf`只插入更高优先层。按最前面的“不使用工作目录以外的文件”要求，不能把“当前外部值未影响构建”视为“没有使用外部配置文件”。因此停在B，未执行C/D/E；这是文件级隔离问题，不是未覆盖键或tmpdir不可见问题。
- 完整查找顺序、合并规则、depanneur的cwd和根目录补读、逐键影响与替代方案均见[配置审计](../evidence/task2/gbs_config_audit_r2.md)，原始工具行号见[源码证据](../evidence/task2/gbs_config_source_r2.txt)。替代方案只列供PM裁决，未自行采用。
- 未改写既有受跟踪linux-rpi/.gbs.conf或添加exclude项，未运行独立导出或strace，未生成export_check.txt，未开始r2 GCC/LLVM。因此没有本轮外部写入监测、编译器、体积、耗时、最终.config或符号修正数，不将这些写成0或通过。
- 步骤C另有前提：linux-rpi/.gbs.conf已受Git跟踪，包含3个导出键；改成两行后无法靠exclude保持干净。本轮保持原样，未使用assume-unchanged/skip-worktree掩盖差异。见[existing_project_gbs_r2.txt](../evidence/task2/existing_project_gbs_r2.txt)。
- 前轮日志/结果原样保留。以下第1–5节为原 `563c53c4` 的历史执行记录，不代表新SHA已构建。新增处置规则已写到RULES最前及末尾：越界写入发现后等待自然结束，不发信号；残留先等5分钟，不sudo、不操作其他任务。

## 1. lko/base

- 起点：tizen@42aeefac58edeb081aff440f0b60be71cbe49755。
- 本地基线：lko/base@563c53c427bff4d685d18544a8f4f6db14be9368。
- 按PM指定执行 `cherry-pick -n a9cc39b8dd1d`，随后 restore 两个架构的 tizen_bcm2711_defconfig，只提交 mm/memcontrol-v1.c。
- 作者保留 He Fangyu <fangyu.he@samsung.com>，作者日期2026-10-19；提交者 Hao Lin <hao.lin@samsung.com>，使用命令级 git -c user.name/user.email。
- 提交正文保留原文并删除 zram backend 段，末尾追加PM指定拆分说明。标题按“保留原文”仍含 zram 字样，**实际 diff 不含任何 zram 配置或驱动文件**。
- `git diff 42aeefac lko/base --stat`：仅 mm/memcontrol-v1.c，22 insertions、7 deletions。完整 [base_diff.txt](../evidence/task2/base_diff.txt)、[base_commit.txt](../evidence/task2/base_commit.txt)。
- 已上传函数前后各20行：[快照索引](../code_snapshots/INDEX.md)，原始文件2405–2486行。

## 2. 构建命令与环境

仅构建已提交的lko/base，不使用 --include-all；普通和RT由spec自身的两个target循环产生。nproc=20；GBS包级threads=1，包内make并行-j10；GCC与LLVM串行，遇任一失败停止，不自动修改spec/代码或重试。不构建aarch64，不碰开发板。

```bash
export TMPDIR=/home/linhao/Toolchain/development/linux_kernel_optimization/temp
cd /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi
/usr/bin/time -v gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_gcc.conf build -A armv7l --threads 1 --define '_smp_mflags -j10'
/usr/bin/time -v gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -A armv7l --threads 1 --define '_smp_mflags -j10'
```

两个命令以上述顺序按停止条件执行，命令列出不代表都已运行。后台管理进程将完整输出和time -v写到 `$WS/temp/build_<gcc|llvm>.log`，最后一行为 `BUILD-END <kind> <Asia/Shanghai时间> exit=<退出码>`。后台无交互stdin；日志监视器遇凭据请求停止，不输入密码、不配置askpass、不绕过sudo。

必要的项目配置调整：两个gbs.conf在[general]新增 `tmpdir=$WS/temp`。原因：已安装的GBS `gitbuildsys/conf.py:196`默认tmpdir为/var/tmp，`cmd_build.py:814`使用自身配置值，不读取环境TMPDIR覆盖；只有export TMPDIR不够。未改变repo URL、buildroot或工具链选择，未改spec。证据：[gbs_tempdir_adjustment.txt](../evidence/task2/gbs_tempdir_adjustment.txt)。

## 3. 构建结果

**本次停止于 GCC 源码准备/依赖初始化阶段；未完成任何内核构建。LLVM未启动。**

| 项目 | GCC | LLVM |
| --- | --- | --- |
| 主命令开始 | 2026-10-27 14:14:17 +08:00 | 未启动 |
| 主命令结束 | 2026-10-27 14:19:54 +08:00 | 未启动 |
| 退出码 | **143（SIGTERM）** | 不适用 |
| time -v 墙钟 | **5:37.12**（失败尝试，不是完整构建耗时） | 无 |
| time -v Maximum RSS | **100088 KiB**；中途杀父/子进程，子进程统计不完整，不能用作正常构建峰值比较 | 无 |
| 是否进入内核编译 | 没有；日志只到源码导出与依赖下载/初始化 | 没有 |
| sudo/凭据 | GBS此前已启动root初始化子进程；残留进程清理时sudo -n返回“a password is required”，此后停止所有sudo尝试 | 未启动 |

原始build_gcc_result.json的credential_stop=false仅表示后台runner结束前未匹配凭据提示；sudo清理要求密码发生在runner结束后，另记录于build_stop_reason.txt，不能把false解释为全程未遇凭据要求。

GNU time同时打印 `Command terminated by signal 15` 与 `Exit status: 0`；这里采用实际子进程返回码143及信号记录，**不能把后者误读为构建成功**。原始结果见 [build_gcc_result.json](../evidence/task2/build_gcc_result.json)，完整封存日志见 [build_gcc_log.txt](../evidence/task2/build_gcc_log.txt)（含主进程结束后残留初始化输出，最终末行重写为原主命令的BUILD-END；不是新的构建尝试）。中止原因见 [build_stop_reason.txt](../evidence/task2/build_stop_reason.txt)。

### 3.1 中止原因与已发生的目录越界

预检发现GBS自己的tmpdir默认/var/tmp，因此两个项目conf加了tmpdir。但这只修正了顶层gbs build的仓库缓存位置，**没有解决嵌套gbs export**。本次仍实际发生越界临时写入，不能声称全程满足目录约束。

2026-10-27 14:18:55，读取压缩进程 `/proc/116876/fd/1` 得到 `/var/tmp/.gbs_export_4d01tubn/linux-kernel-6.12.80.tar.xz`，立即对构建进程组116650发送SIGINT。后台进程继承了忽略SIGINT的行为，首次信号没有及时终止；在确认仍运行后发送SIGTERM终止可控子进程和gbs主进程。在此期间GBS完成导出并进入了root依赖初始化。

残留root初始化/下载进程拒绝普通kill；为结束本任务创建的残留进程，仅尝试一次 `sudo -n /bin/kill -KILL -- <该进程组的残留PID>`，返回 `sudo: a password is required`。按PM硬规则立即停止一切sudo尝试，未提供凭据、未使用askpass、未换方式绕过。已通知PM需要本机处理该组残留进程。随后于2026-10-27 14:24:16只读复查确认PGID 116650已无活跃进程；残留进程自行完成了依赖初始化，没有进入内核编译，不再需要PM终止。本任务未因此恢复构建。实际PID/状态见 [residual_state.txt](../evidence/task2/residual_state.txt)，停止尝试完整记录见 [build_stop_reason.txt](../evidence/task2/build_stop_reason.txt)。

只读复查发现上述/var/tmp导出目录已由工具正常导出结束时自行移除；本任务没有删除/移动工作区外文件。源tar等随后已放入WS/temp的GBS路径。目录曾存在的事实保留，不因已消失而抹去。

### 3.2 静态根因证据

1. `/usr/bin/depanneur:788–824` 拼出 `gbs export ... --commit=HEAD ...`，**没有传入顶层的 `-c config/gbs_gcc.conf`**。
2. 实际进程命令也为 `gbs export <linux-rpi> -o <WS/temp/...> --outdir-directly --spec linux-rpi.spec --commit=HEAD ...`，没有-c。输出目录-o在temp，不等于导出中间目录也在temp。
3. `gitbuildsys/cmd_export.py:298–300` 从 `configmgr.get('tmpdir','general')` 构造 `.gbs_export_`，没有以环境TMPDIR替代；`gitbuildsys/conf.py:196` 的默认值就是/var/tmp。

带行号工具代码见 [gbs_export_root_cause.txt](../evidence/task2/gbs_export_root_cause.txt)。这是本次外层配置没有传递到导出子进程的可证链条；未修改已安装GBS/depanneur、未向源码加.gbs.conf、未重试构建。下一次执行前须由PM确定配置传播方案；残留进程按PM新规则等待5分钟，仍存在则停止报告，不尝试sudo、不操作其他任务进程。

### 3.3 PM后续确认：退出归因与完整日志封存

**归因：本次主构建命令被执行者主动中断，不是GBS正常完成，也不是已发现的内核编译错误。** 触发中断的是3.1节所述导出中间文件写入工作区外。SIGINT未及时奏效后，执行者向本任务gbs/depanneur等进程发送SIGTERM；[停止记录](../evidence/task2/build_stop_reason.txt)列出目标PID及结果。完整日志第63行是 `Command terminated by signal 15`，第91行已记录 `BUILD-END gcc 2026-10-27T14:19:54+08:00 exit=143`，与[runner结果](../evidence/task2/build_gcc_result.json)一致。143对应128+SIGTERM(15)。

主命令退出时，部分root子进程未能被普通信号操作终止，仍持有同一日志输出文件并继续下载/安装依赖，因此其输出出现在首次BUILD-END之后。主命令被信号终止不等于所有后代进程同步退出；这解释了两者结束时间不同，不能将此现象解释成GBS构建成功后正常后台下载。日志最后50行仅能证明依赖初始化到了 `now finalizing build dir...`；退出原因必须结合第63行、runner返回码和信号操作记录判断。

PM随后确认：PGID116650已无任何进程，用户没有执行kill，残留自行退出，temp下无残留挂载。2026-10-27 14:44:40 +08:00再次只读核验也未发现该PGID进程或当前挂载命名空间内temp下的挂载，见[封存复核](../evidence/task2/build_closure_recheck.txt)。本次跟进未发送信号、未调用sudo、未启动任何构建，也未影响其他编译任务。

完整日志仍为532行、48259字节，本地与上传副本字节一致，SHA-256为 `3157116b9e9b5f8d6822103ff5adf4d4e1b6f2f8fa13ff2dae277bc82bfc401a`；没有截掉主命令退出后输出，也没有再次改写已封存日志。末行的时间表示原主命令退出时间，封存时间另由前一行TASK2-LOG-SEAL说明。以下逐字引用[最后50行](../evidence/task2/build_gcc_last50.txt)，对应完整日志第483–532行：

```text
[  220s] pkg-config-0.29.2-3.27                ########################################
[  220s] sed-4.1c-5.24                         ########################################
[  221s] util-linux-2.41.2-2.19                ########################################
[  221s] libatomic-14.2.0-4.30                 ########################################
[  221s] libunwind-devel-1.6.2-2.5             ########################################
[  221s] build-20120927-2.1                    ########################################
[  221s] python3-3.14.2-5.34                   ########################################
[  221s] libtool-2.5.4-4.4                     ########################################
[  221s] kmod-compat-34.2-2.1                  ########################################
[  221s] libncurses-6.6-4.5                    ########################################
[  221s] libdw-devel-0.189-1.101               ########################################
[  221s] binutils-devel-2.43-3.29              ########################################
[  221s] libopenssl3-devel-3.5.9-1.6           ########################################
[  222s] libstdc++-devel-14.2.0-4.30           ########################################
[  222s] app-rootstrap-checker-1.0.0-4.1       ########################################
[  222s] build-compare-2023.06.18-1.42         ########################################
[  222s] hal-rootstrap-checker-1.0.0-11.1      ########################################
[  223s] qemu-linux-user-x86_64-cross-9.2.3.1-4########################################
[  223s] gcc-14.2.0-4.30                       ########################################
[  227s] qemu-accel-x86_64-armv7l-0.4-6.4      ########################################
[  228s] util-linux-su-2.41.2-2.19             ########################################
[  228s] rpm-build-4.14.1.1-7.3                ########################################
[  228s] grep-2.5.2-4.2                        ########################################
[  228s] tar-1.17-5.1                          ########################################
[  228s] rsync-3.4.1-1                         ########################################
[  228s] elfutils-0.189-1.101                  ########################################
[  228s] dwarves-1.29-1                        ########################################
[  228s] bc-1.06-2.1                           ########################################
[  228s] less-685-2.1                          ########################################
[  228s] tzdata-2026d-1.1                      ########################################
[  228s] glibc-locale-2.40-16.8                ########################################
[  228s] which-2.17-11.1                       ########################################
[  228s] smack-1.3.1-2.21                      ########################################
[  228s] flex-2.6.4-1.89                       ########################################
[  228s] bison-3.0.5-2.69                      ########################################
[  228s] file-5.46-1.73                        ########################################
[  228s] cpp-14.2.0-4.30                       ########################################
[  228s] gcc-c++-14.2.0-4.30                   ########################################
[  228s] dash-0.5.13.4-1.2                     ########################################
[  228s] gawk-3.1.5-3.1                        ########################################
[  228s] cpio-2.8-2.2                          ########################################
[  228s] diffutils-3.10-2.1                    ########################################
[  228s] hostname-3.23-1.3                     ########################################
[  228s] net-tools-2.0_20121208git-1.62        ########################################
[  228s] update-alternatives-1.22.21-2.1       ########################################
[  229s] removing nis flags from /home/linhao/Toolchain/development/linux_kernel_optimization/temp/GBS-ROOT-TOOLCHAIN-GCC-CODES/local/BUILD-ROOTS/scratch.armv7l.0/etc/nsswitch.conf...
[  229s] now finalizing build dir...

TASK2-LOG-SEAL: 2026-10-27T14:24:16+08:00 read-only check found no live PGID 116650 processes. Orphan initialization output after the earlier BUILD-END was retained. No kernel compilation and no retry.
BUILD-END gcc 2026-10-27T14:19:54+08:00 exit=143
```

**处置：按未成功构建停止，LLVM及后续依赖成功产物的步骤均不继续。** 后续每次构建前后核对本次进程组；如有残留，先等待5分钟，仍存在则停止报告，禁止sudo清理或操作其他任务进程。规则已写入RULES.md。

## 4. 实际编译器与最终 .config：未取得

- GCC的LLVM=1/CC=/LD=编译调用、include/generated/compile.h、vmlinux .comment均未产生可用证据。未将依赖下载URL里的gcc包名冒充已安装编译器RPM清单。
- **gbs_llvm.conf未执行，因此不能确认内核由Clang编译，也不能断言它实际上使用GCC。**
- 没有4份最终.config；没有运行scripts/diffconfig；01第3节逐符号实测对照未执行，**改正符号数未得，不记为“0个错误”**。
- HZ、PREEMPT*、KALLSYMS_ALL、DEBUG_INFO_BTF*、STACKPROTECTOR*、TRACE_IRQFLAGS、PREEMPTIRQ_TRACEPOINTS、LRU_GEN_WALKS_MMU、CORESIGHT*、PERF_EVENTS、HW_PERF_EVENTS都尚无本轮最终.config核验值。

## 5. 体积与开销：不可比较

| 请求指标 | 本轮结果 |
| --- | --- |
| GCC/LLVM zImage字节数及差值 | 未产生，不能计算 |
| vmlinux text/rodata/data/bss与差值 | 未产生，未调用宿主size/readelf等替代 |
| 模块数量/总大小、kallsyms符号数 | 未产生 |
| bloat-o-meter前30项 | 没有成对vmlinux，未运行 |
| kallsyms、__mcount_loc/ftrace段占用 | 没有vmlinux，未运行 |
| 完整构建时间/RSS对照 | 没有；只有上表失败主命令的wall/RSS，且RSS统计不完整 |
| buildroot磁盘占用、产出RPM总大小 | 主命令中止后残留依赖初始化自行结束；只有不完整buildroot/下载依赖，不是成功内核产物，未给出误导性完整构建数值 |

以上待办只能在PM安排恢复任务、成功完成两次串行构建并核验工具链后继续；构建产物分析只用GBS buildroot平台工具。
