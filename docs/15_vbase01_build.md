# 任务12：类产品基线构建与核验

## 范围与当前状态

**三阶段构建与产物核验已完成，未部署。出类产品镜像时必须同步重编 linux-tizen-modules。** 与base01比较，253个导入符号中132个CRC变化，缺失0；本次新编配套模块与新内核356项CRC核对全部相符。

执行过程存在一项资源规则偏差：perf子构建实际采用-j20，超过本机nproc/2=10；未干预正在运行的构建，完整记录见下文。不能声称本轮全过程满足并行度上限。详细配置来源、取值、移植与符号明细仅在本地vendor_local/V3_report.md，不入库。未推Gerrit、未触发Quickbuild、未连接开发板。下方认证等待到期和恢复监控记录保留为历史。

## 构建前检查

起始源码HEAD与干净工作树核对通过。普通/RT各43项配置核对全部通过，无目标范围之外的差异；局部编译两种变体均0 error、23条编译器warning，相比任务11新增0。结果仅为局部编译通过，不代表完整链接、ABI或运行时验收。[通用计数证据](../evidence/task12/prebuild_summary.json)。

配置参考来源补核：普通版使用QB1211696已下载的最终配置；前置检查时RT使用同源码生成的参考。收尾时从QB1211696同一公开仓库下载RT devel包，112,065,728 B及SHA与已留存仓库元数据完全一致；包内最终配置与此前RT参考逐字一致，平台diffconfig为0差异，原RT差异范围结论得到实际RPM补证。该补证在完整构建后完成，未把它记成构建前已取得的证据。[来源核对](../evidence/task12/qb_rt_reference_summary.json)。

平台工具来自原有LLVM GBS root，只读挂载，经bwrap/qemu-arm运行，未使用宿主编译器。局部编译-j4/W=1；所有详细输出仅保留本地。宿主侧只对新脚本做bash -n，结果0；shellcheck未安装，未尝试安装。

## 启动流程与模板差异

[run_task12_build.sh](../scripts/run_task12_build.sh)沿用任务9已验证流程。全部差异为：任务目录和新独立GBS根、任务编号及日志/锁/PGID文件名、内核源码工作树路径、内核与模块期望SHA，以及按阶段核对各自本地分支。source阶段的固定SHA与分支不变。新增分支映射只是替代模板中三阶段共同的固定分支断言。

以下机制未改：只读GBS配置及其SHA、profile/arch/并行度、隔离HOME与GBP配置、前台用户认证/后台独立进程组、stdin接/dev/null、time -v、残留观察5分钟、凭据/停止状态检测、外部写入观测、原始日志及BUILD-END/ALL-END封存。构建脚本不做产物核验。

三阶段均在各自固定源码目录执行同一命令，只有提交参数不同：

```sh
HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home/.gbp.conf /usr/bin/time -v /usr/bin/gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -P tizen_unified_standard -A armv7l -B /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task12/GBS-ROOT-LKO-VBASE01 --threads 1 --define '_smp_mflags -j10' --commit <脚本中对应阶段的固定SHA>
```

独立tmux3.4会话lko-task12，socket为temp/task12/tmux.sock。代理不直接sudo、不输入或记录密码、不发信号。认证由用户连接原窗口完成；不重跑、不自动清理。外部监控每10分钟，30分钟日志无增长且无工作进程才触发静默停止；导出仍有工作进程时允许无输出。其余停止条件沿用任务9。

## 完整构建后验收计划（已按下文完成）

三阶段全部OK后，先核对Clang/LLD 22.1.8和实际kernel-devel依赖来源，再核对普通/RT版本、映像大小与干净基线差值、模块vermagic、7个外部模块CRC、最终配置、容量与部署包逐文件哈希。对干净基线留底的253个外部模块导入符号比较CRC，另报全部导出符号CRC变化数量。结果未产生前，不判定现成外部模块可复用，也不判定满足部署条件。

## 2026-11-04：认证等待到期

- 13:42:54启动原会话，前置源码/配置/新根检查后进入用户认证；14:12:54仍未观察到认证完成，等待达到30分钟上限。
- 截止时preflight为RUNNING，kernel/modsrc/modules均PENDING，supervisor PGID文件未生成；不是GBS构建失败，没有三阶段耗时、RSS或产物数据。原始status没有ALL-END，因为原启动脚本仍在前台等待；没有伪造或改写其状态。
- 原会话、锁和新根均保留；没有重跑、清理、发信号或绕过认证。[截止状态](../evidence/task12/status_at_authentication_deadline.txt)、[认证等待摘要](../evidence/task12/authentication_wait_summary.json)。
- 用户后续应连接**原会话**完成认证；不要重新执行启动脚本。认证后从原status及PGID恢复监控，再按上节完成验收。当前不满足部署条件，也无法判断镜像能否沿用现成树外模块。
- 脚本还原允许的路径/提交/分支差异后与任务9模板逐字一致：[一致性证据](../evidence/task12/runner_parity.json)。任务9脚本哈希保持不变，linux-rpi主工作树HEAD和干净状态未变；六个局部检查进程组均无残留。

```sh
tmux -S /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task12/tmux.sock attach -t lko-task12
```

## 2026-11-04：用户认证后恢复监控

用户报告已在原窗口认证；status显示14:59:14 preflight=OK、kernel=RUNNING。supervisor PGID=1038573存活，kernel PGID=1038698中有git/xz导出工作进程，恢复门槛通过。没有重启脚本或清理文件。[恢复摘要](../evidence/task12/resume_preflight_summary.json)。按任务12的10分钟间隔与静默门槛监控，详细快照仅本地保留，三阶段全部OK后才核验。

## 构建和核验结果

全部依据汇总在[验收JSON](../evidence/task12/verification_summary.json)、[最终状态](../evidence/task12/completed_status.txt)、[九轮监控摘要](../evidence/task12/monitor_summary.json)、[完整日志身份清单](../evidence/task12/build_log_manifest.json)。完整原始输出保留本地，公开证据仅含通用结果、计数和哈希。

### 阶段与时间

|阶段|结果|time -v墙钟|最大单进程RSS（KiB）|
|---|---|---|---:|
|kernel|OK / exit0|1:10:18|2,608,860|
|modsrc|OK / exit0|1:01.39|153,236|
|modules|OK / exit0|1:11.69|139,500|

监督阶段14:59:14–16:12:56，共 **1:13:42**；time -v三阶段合计4351.08秒，差额包括扫描/封存等阶段间操作，不含用户认证等待。16:20的第9轮监控看到ALL-END三项OK，组内无残留；宿主当前挂载表没有task12残留挂载。不以本次耗时与任务9的差值推断源码带来构建加速。

### 工具链与依赖

Clang/LLD均22.1.8，RPM为clang/llvm-22.1.8-1.6.armv7l，[平台原始版本输出](../evidence/task12/toolchain_versions.json)。全部分析通过本次GBS root中的平台工具及qemu-arm运行，root只读。末阶段root不再提供Python；沿用任务9方式从**本次缓存**仅解出python3-base/libpython3_141_0 3.14.2-1.8，在私有目录运行平台Python，不安装RPM、不使用宿主Python做映像/模块分析。

modules所用普通/RT devel来自本次local仓库：新RPM完整SHA与.srcfiles.cache路径关联；安装数据库NVR/BUILDTIME/SIGMD5/SHA1HEADER与本次RPM一致；INSTALLTIME落在modules阶段；再核对10份已安装文件与RPM载荷，0差异。BUILDTIME均为0，不能当作真实构建墙钟；实际时序以日志/INSTALLTIME为准，不声称RPM数据库直接储存了整个RPM的SHA。身份明细仅本地保存。

### 映像、配置和模块

|映像|大小（B）|SHA-256|
|---|---:|---|
|normal|14,928,528|`d3bc1ec49e56a8d279f566da3f0b536584e18349627a33ff9efd1f3c4b1e3c9e`|
|rt|14,977,872|`fd00f8e0c150401707f120cf5d3acd826d1895c48504005d81ff6e78a1ad4dfe`|

普通版版本为`6.12.80-arm-rpi4-v7l-lko-vbase01`，RT为`6.12.80-arm-rpi4-rt-v7l-lko-vbase01`；均通过解压真实映像中的版本串确认，普通版另用平台strings交叉核对。普通zImage比base01的14,906,368 B增加 **22,160 B（+0.148661%）**。这是构建产物大小，不是运行时内存。

普通最终.config与第5步结果逐字一致，平台diffconfig输出空、0差异；配置全文仅私有保存。RT只做本任务要求的映像版本核验，不作为普通版部署验收的替代。

59个模块（52内核+7树外）的vermagic全部精确匹配`6.12.80-arm-rpi4-v7l-lko-vbase01 SMP mod_unload modversions ARMv7 p2v8`。合并目录后平台depmod成功；7个树外模块356项CRC比较，0缺失/不一致。两个共享配置与原厂一致，不放入部署包。

### base01兼容性结论

基于任务9留底的253个去重导入符号：**132个CRC变化，121个相同，0缺失**。按PM判据，出类产品镜像时 **linux-tizen-modules必须一起重编，不能沿用现成包**。本次配套重编模块与新内核已通过CRC核验；该结论不等于已上板验证运行语义。

全部同名导出符号中CRC变化 **10,208个**，另有新增2、删除0；新增/删除单独统计，不混入“同名CRC变化”数量。这里比较的是本次源码和配置组合与base01，未分离各项改动的单独影响；明细仅保留vendor_local。

### 容量与部署包

版本目录 **3,976 KiB**（kernel 3,040、extra 288，余下为索引等），比此前4,424 KiB估算少448 KiB。原厂已保留，按既有可用14,648 KiB扣除base01实测3,976与vbase01实测3,976，估算剩 **6,696 KiB**，三套可并存。宿主分配大小与板上文件系统可能不同，部署前仍须重查df/inode；本任务没有连板。

`temp/task12/deploy_lko-vbase01/`包含普通zImage、完整新版本模块目录及逐文件SHA256SUMS/manifest；共74个普通文件、1个原RPM build链接。归档保留链接、不跟随，不含设备树、overlays、共享配置或RT部署内容。74文件哈希和归档成员/大小/链接/uid/gid核验全部通过。

归档`deploy_lko-vbase01.tar.gz`：16,011,775 B，SHA256 `0c76212eff51c74bc1a7469ffb40e7354d25c85d79bd595c3bf12d4b1f80eb4c`。二进制和逐文件部署清单留本地，公开仅记录身份与计数。

### 执行偏差与观测限制

perf日志明确启动`-j20`；其Makefile:19取消MAKEFLAGS继承，:28按在线CPU设置JOBS，:65显式使用-j$(JOBS)，因此覆盖外层-j10。本机nproc=20，项目上限10，**该阶段实际超限**。[日志摘录及源码依据](../evidence/task12/perf_parallelism_deviation.json)。未发信号、修改运行中脚本/spec或重跑；当时登记后续显式限制perf JOBS；该待办现由下方任务13的PM裁决覆盖，保留为历史。

外部find候选数（kernel/modsrc/modules）为514/54/42，全部无法归属；本进程组直接观测的工作区外输出为0。find均exit1，且不覆盖所有权限、深度、root写入及已删除路径，**不能据此证明完全没有工作区外写入**。无文件删除或移动，其他任务路径不公开。

主linux-rpi HEAD/工作树、任务9脚本和原模块lko/base01引用未变；本任务源码分支干净，未推Gerrit。无后缀lko/vbase01为`b11f669e0cb1c1e26d878430b998d6486c5476a1`，后续内部推送须另行下达。部署与运行测试仍待PM安排。

公开文件提交前已扫描119个配置/来源/补丁标题模式，0命中；vendor_local被忽略且没有受跟踪文件。配置全文、符号明细、完整编译输出和下载RPM仅保留本地；公开文件均小于1 MB。

## 任务13：PM裁决（2026-11-04）

perf 并行数 -j20 来自 spec 自身，为保持本地构建与镜像构建一致，不修改 spec；作为已知偏差记录，后续本地构建沿用。实际覆盖外层并行参数的实现与证据见上文，历史超限事实不变。

PM最新裁决替换新分支方案：不新建分支，直接快进更新platform/kernel/linux-rpi的sandbox/lhmax2025/kernel_optimization，从0fac5de6a63091d141ad1cd3ed9d9e92b8dde708到b11f669e0cb1c1e26d878430b998d6486c5476a1。干净基线以原提交号保留；如需干净基线镜像，必须显式指定0fac5de6，不再使用该分支最新值。仍不force、不走refs/for/*；本轮不构建、不连板、不触发Quickbuild。

任务13执行结果：9个提交与本地报告一致，祖先关系及无后缀spec核对通过；采用任务4原origin和正常SSH环境普通快进推送，推后SHA符合目标，未新建分支。详细提交标题、推送原文与出镜像说明仅保存在vendor_local；镜像必须同步重编配套树外模块。
