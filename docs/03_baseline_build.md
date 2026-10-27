# 任务2：armv7l 构建基线与实际配置核对

日期：2026-10-27（Asia/Shanghai）。本报告只记录本任务实际执行的结果；未获得的构建产物指标不以源码推导替代。所有体积与构建开销数字均为构建产物/开发机数据，不代表板上运行时内存。

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

带行号工具代码见 [gbs_export_root_cause.txt](../evidence/task2/gbs_export_root_cause.txt)。这是本次外层配置没有传递到导出子进程的可证链条；未修改已安装GBS/depanneur、未向源码加.gbs.conf、未重试构建。下一次执行前须由PM确定配置传播方案以及可安全终止整个root子进程树的方式。

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
