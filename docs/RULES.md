1. 不使用工作目录以外的文件（配置、脚本、数据等）。系统已安装的工具本身（gbs、depanneur、编译器、git 等）不在此限。
2. 生成的所有东西都必须在工作目录内。


## PM裁决：任务2续五（优先于后文历史记录）

- 只读核对并修改用户执行脚本；代理不运行脚本、gbs、导出、构建或sudo，只对脚本做bash -n。用户重跑后按任务2续四每10分钟只读监控；异常即停止报告，不自动重试。
- 所有gbs命令（export/build）及后代必须使用：`HOME=$WS/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=$WS/temp/gbs-home/.gbp.conf`。这三个变量不用于成果仓库git commit/push；Git继续使用正常环境的现有GitHub认证。
- `$WS/temp/gbs-home/.gbp.conf`是仅含注释的普通文件；GBP_CONF_FILES非空值完全替换git-buildpackage默认查找列表，不修改系统工具或系统配置。
- 系统运行时白名单新增：`/etc/gnutls/config`（TLS库自身运行时配置）、`/etc/gss/mech.d`（GSSAPI库自身运行时目录）、`/etc/ldap/ldap.conf`（LDAP库自身运行时配置）、`/run/systemd/resolve/stub-resolv.conf`（/etc/resolv.conf指向的实际文件）。
- 以只读、目录方式打开`/tmp`、`/var/tmp`允许；脚本要求O_RDONLY、目录检查通过且不含写入/创建标志，不扩大到目录内文件。
- 工作区外任何带O_WRONLY、O_RDWR或O_CREAT的成功打开，或任何mkdir/mkdirat调用（包括失败的尝试），都判为失败；脚本同时拒绝O_TRUNC。运行时路径白名单不自动豁免写入标志。发现问题不向进程发信号，等当前命令自然结束再报告。
- 上次用户运行产物只在WS/temp内整体归档，不删除；保留run_baseline_build.lock原位。新日志不得覆盖历史运行记录。

## PM裁决：任务2续三（优先于后文历史规则）

HOME=$WS/temp/gbs-home、GIT_CONFIG_NOSYSTEM=1 和 GBP_CONF_FILES=$WS/temp/gbs-home/.gbp.conf 这三个环境变量只用于 gbs 命令（export 和 build）以及它派生的进程。本项目结果仓库的 git commit、git push 一律在正常环境下执行，使用本机已有的 GitHub 认证。不修改认证配置，不索要密码。

本轮仅编写由用户在自己的终端运行的构建脚本；代理不运行脚本、导出或构建，只做静态核对与bash -n。脚本仅允许在前台执行一次sudo -v供用户完成必要认证，不执行其他sudo命令、不向进程发送信号；GBS工具自身的sudo调用须如实说明。用户运行结束并告知后再恢复产物核对。

## PM裁决：任务2续二

1. 对"不使用工作目录以外的文件"的界定：
   - 凡是会影响本项目行为的配置、脚本、数据，只能来自工作区。具体包括 gbs.conf、gitconfig、rpm 宏、构建脚本、仓库定义。
   - 系统已安装工具运行所需的程序文件和系统运行时文件（/usr、/lib*、/proc、/sys、/dev，以及 /etc 下的 passwd、nsswitch、ld.so、locale、sudoers 等）不在此限。
2. 在本机上，本项目所有 gbs 命令都必须带下面三个环境变量运行：
   HOME=$WS/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=$WS/temp/gbs-home/.gbp.conf
   不加这三个变量，就不许运行 gbs。
3. 不再采用修改 linux-rpi/.gbs.conf 或 .git/info/exclude 的方案：该文件已被 git 跟踪，保持原样。上一轮报告中列出的"独立工具副本"和"专属隔离环境"两个方案，同样不采用。

本裁决覆盖后文历史任务中的相冲突方案；历史审计保留作证据，不再视为待选择方案。

后面的规则和步骤都服从这两条。

# 项目硬规则

1. 所有临时文件和中间产物只能放在 $WS/temp/（export TMPDIR=$WS/temp），不许写到 $WS 以外的任何地方。
2. GitHub 只用 git push 推到 main，不开 PR，不 force push。只上传必要、重要的文件（文档、补丁、脚本、小体积文本证据）。linux-rpi 源码树、temp/、构建产物、RPM、二进制、大于 1 MB 的文件一律不上传，留在工作目录。
3. 提交署名一律用 Hao Lin <hao.lin@samsung.com>，用 git -c user.name=... -c user.email=... 指定，不改全局配置。
4. linux-rpi 本任务只读：不 checkout 其他分支、不改工作树、不提交。可以把远端分支 fetch 到 refs/remotes 下做只读比对。后续需要改代码时另开分支，届时另行说明。
5. 不向 Gerrit 推送任何东西。
6. 控制机器负载：并行度不超过 nproc 的一半。本任务不跑内核编译，也不跑 GBS 构建。
7. 每个任务收尾时更新 $WS/docs/STATUS.md，内容包括：计划、进度、已闭合结论（附证据路径）、需要人工裁决的前提、挂账事项。STATUS.md 与本次产出放在同一个 commit 推送。新 Session 开场先读 STATUS.md 和 RULES.md。
8. 结论必须有证据：给出 文件:行号、commit id 或命令输出。推测要明确标注"推测"。拿不到的信息如实写明原因和尝试过的命令，不要猜。

## 任务2起生效的新增与调整（2026-10-27，PM 指令）

以下规则覆盖上文任务1限定的第4条“源码只读”和第6条“不构建”；其余原规则继续有效。任务2授权在 lko/base 上串行执行 armv7l GCC/LLVM 基线构建，每次 --threads 1、_smp_mflags=-j10，且不超过 nproc 的一半。拆分 a9cc39b8dd1d 时按 PM 明确要求保留原作者 He Fangyu，提交者仍用 Hao Lin <hao.lin@samsung.com>，使用 git -c 指定，不改全局配置。

1. linux-rpi 允许建本地分支，分支名统一用 lko/ 前缀。不许修改 tizen 分支，不许删除或改写任何远端分支，不许向 Gerrit 推送。
2. PM 需要核对源码时，只上传相关文件，不上传整棵树。路径为 code_snapshots/<内核commit短id>/<源码原路径>，并在 code_snapshots/INDEX.md 中记录：文件、commit、上传原因。单个文件超过 1 MB 时，只上传相关片段，并注明行号范围。
3. 构建产物（RPM、vmlinux、buildroot）全部留在 $WS/temp/，不上传。
4. 分析构建产物（size、readelf、nm、bloat-o-meter、objdump、llvm-bolt 等）时，用 GBS buildroot 里平台自带的工具，不用本机工具链。
5. 构建过程中遇到 sudo 密码或任何凭据要求：立即停止，报告卡在哪一步。不要尝试绕过，也不要索要密码。
6. 优先级：armv7l 优先。aarch64 的优化（包括内核 BOLT）在 armv7l 完成后再做；在此之前，aarch64 只做静态记录，不构建、不上板。
7. 开发板：本任务不碰开发板。今后的板上操作都以 PM 下发的任务为准，执行前必须用三项断言确认板子身份：uname -r 包含 rpi4、uname -m 为 armv7l、os-release 为 Tizen。

任务2停止条件：任一构建失败时，保留日志、分析原因并写入报告，然后停止，不修改 spec 或代码；如果 LLVM 配置实际没有使用 Clang，记录原因并停在编译器核验步骤，等待 PM 决定。收尾仍须更新 STATUS.md，与本次已获得产出同一个 commit 推送 GitHub main。

## 构建进程组管理补充（2026-10-27，PM 后续指令）

本机还有其他编译任务在跑。后续每次构建前后都要检查本次构建的进程组。发现残留时，先等 5 分钟看它是否自行退出；仍未退出就停下报告，不要尝试 sudo，也不要动任何不属于本次构建的进程。

执行时记录本次构建的 PID/PGID、启动时间和命令，启动前确认所用进程组独立且不存在上次未闭合的本任务残留，结束后只核对本次记录的进程组及其身份。等待期间分段进行只读检查，满 5 分钟仍有残留即报告并停止；不通过进程名批量终止，也不清理其他任务的挂载或产物。此前历史记录中的 sudo 清理尝试不构成今后授权。

## 任务2续：配置隔离与越界处置（2026-10-27，PM 指令）

- 不许修改 ~/.gbs.conf、/etc/gbs.conf，也不许修改已安装的 gbs 和 depanneur：本机有其他编译任务在用同一账号。
- 构建中发现有文件写到工作区外时，不要中途向构建进程发信号：中途终止会留下需要 root 才能清理的残留进程。正确做法是：让当前构建自然结束，然后记录写入的路径、时间和进程，停下报告。工作区外的文件不要删除，也不要移动。
- 本轮授权修正lko/base提交标题，审计系统工具的配置加载逻辑和外部配置的section/键名（外部键值不上传），在源码根目录创建被本地exclude忽略的两行普通.gbs.conf，经独立strace导出验证后恢复步骤4–9。审计外部配置仅用于识别并隔离影响，不将它们作为项目配置使用。若项目配置无法被导出读取或存在无法覆盖的外部配置，停在步骤B报告替代方案，不自行选择。
- 每轮构建日志使用build_<gcc|llvm>_r2.log，不覆盖历史日志；构建前后核对本任务进程组，残留先等5分钟，仍存在则报告，不尝试sudo、不操作其他任务进程。外部写入监测仅归属分析，不删除文件，无法确定归属的注明“无法归属”。
