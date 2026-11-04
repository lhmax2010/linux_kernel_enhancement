# 任务12：类产品基线构建与核验

## 范围与当前状态

第一、二段已完成；原tmux窗口等待认证满30分钟，按要求停止等待，完整构建尚未开始。尚无完整构建或部署验收结论。仅在开发机执行；未推Gerrit、未触发Quickbuild、未连接开发板。详细配置来源、取值、移植内容及诊断仅保留于本地vendor_local/V3_report.md，不入库。

## 构建前检查

起始源码HEAD与干净工作树核对通过。普通/RT各43项配置核对全部通过，无目标范围之外的差异；局部编译两种变体均0 error、23条编译器warning，相比任务11新增0。结果仅为局部编译通过，不代表完整链接、ABI或运行时验收。[通用计数证据](../evidence/task12/prebuild_summary.json)。

平台工具来自原有LLVM GBS root，只读挂载，经bwrap/qemu-arm运行，未使用宿主编译器。局部编译-j4/W=1；所有详细输出仅保留本地。宿主侧只对新脚本做bash -n，结果0；shellcheck未安装，未尝试安装。

## 启动流程与模板差异

[run_task12_build.sh](../scripts/run_task12_build.sh)沿用任务9已验证流程。全部差异为：任务目录和新独立GBS根、任务编号及日志/锁/PGID文件名、内核源码工作树路径、内核与模块期望SHA，以及按阶段核对各自本地分支。source阶段的固定SHA与分支不变。新增分支映射只是替代模板中三阶段共同的固定分支断言。

以下机制未改：只读GBS配置及其SHA、profile/arch/并行度、隔离HOME与GBP配置、前台用户认证/后台独立进程组、stdin接/dev/null、time -v、残留观察5分钟、凭据/停止状态检测、外部写入观测、原始日志及BUILD-END/ALL-END封存。构建脚本不做产物核验。

三阶段均在各自固定源码目录执行同一命令，只有提交参数不同：

```sh
HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home/.gbp.conf /usr/bin/time -v /usr/bin/gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -P tizen_unified_standard -A armv7l -B /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task12/GBS-ROOT-LKO-VBASE01 --threads 1 --define '_smp_mflags -j10' --commit <脚本中对应阶段的固定SHA>
```

独立tmux3.4会话lko-task12，socket为temp/task12/tmux.sock。代理不直接sudo、不输入或记录密码、不发信号。认证由用户连接原窗口完成；不重跑、不自动清理。外部监控每10分钟，30分钟日志无增长且无工作进程才触发静默停止；导出仍有工作进程时允许无输出。其余停止条件沿用任务9。

## 完整构建后验收（待执行）

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
