# 任务9：干净基线构建与前置检查

**最新状态（2026-11-03续跑二）：已按PM裁决准备用户执行的三阶段构建脚本，bash -n通过，等待用户在tmux中运行。代理未运行脚本、GBS、导出、构建或sudo；目前没有新构建产物。第5节权限阻塞已由第6节新授权覆盖。**

第1–4节保留上一轮准备/停止记录，第2.3节是本轮PM裁决；旧的静态不通过项及补导出建议已由该裁决覆盖。

日期：2026-11-03（Asia/Shanghai）。**停在第一段第2项，没有进入构建环境初始化或第二段构建。** 本轮已完成三个本地分支和两次指定的本地提交；未连接开发板、未部署、未执行GBS/export/sudo、未发信号、未推Gerrit或触发Quickbuild，没有访问vendor_local。

## 1. 源码准备与提交

严格应用[12第4.1、4.2节](12_kernel_deploy_prep.md)中原有的零上下文diff，没有自行增加修改。三个工作树最终均干净，内核的lko/base仍指向原sandbox提交。

| 仓库 | 基准提交 | 本地lko/base01 HEAD | 新提交 |
|---|---|---|---:|
| linux-rpi | 0fac5de6a63091d141ad1cd3ed9d9e92b8dde708 | 8c8f2429401d6b282373e58b73399801a9486d5b | 1 |
| ext/linux-tizen-modules | 36d0925699ac0ffc1ce3854ed838a48d24a56c28 | 10deb822453c759f6f944baf067c8b16a48ad914 | 1 |
| ext/linux-tizen-modules-source | 25797e8af7ed95a5783bbe84c11959560aaf7e92 | 25797e8af7ed95a5783bbe84c11959560aaf7e92 | 0，源码不改 |

两次新提交标题均为`experiment: version suffix -lko-base01, local only`，作者和提交者均为Hao Lin <hao.lin@samsung.com>；仅各自的packaging spec发生变化。source仓库没有新提交，因此保留原提交作者。树外仓库从任务8已核验的本地公开源码检出复制Git对象（clone --no-hardlinks），再固定到指定SHA；origin登记原Tizen项目SSH地址，未push。本次没有重新使用浮动分支取得另一份源码。

`.gitignore`新增`/ext/`，两棵树外源码不进入结果仓库。每个修改后的spec与任务8候选文件逐字一致；linux-rpi的lko/base、tizen及远端引用均未改动，本地当前分支留在lko/base01，便于后续按裁决继续。

证据：[准备命令及退出码](../evidence/task9/source_prepare.txt)、[分支和提交身份](../evidence/task9/local_branches.json)、[差异范围及逐字核对](../evidence/task9/source_integrity.json)、[最终Git状态](../evidence/task9/final_local_state.txt)。这些内核/树外模块提交只保留本地；GitHub本次仅提交文档、文本证据和忽略规则。

## 2. 静态检查：解析通过，语义门槛未通过

借用任务2现有LLVM GBS root内的平台rpmspec，经该root的qemu-arm解析两个已经提交的spec，参数为`--target armv7l --define '_toolchain clang' -P`。root及内核源码只读绑定，HOME及输出全部在temp/task9，rpm宏复制自该已有root的原始.rpmmacros；没有修改已安装工具或配置。这是**静态解析用旧root**，不是任务9的新构建root，也不能证明任务9实际依赖或工具链已初始化。

| 检查 | 内核spec | 树外模块spec |
|---|---|---|
| rpmspec解析退出码 | 0 | 0 |
| %build导出LOCALVERSION=-lko-base01 | 有，源文件:163 | 有，RPi分支:263 |
| %install导出LOCALVERSION=-lko-base01 | 有，源文件:234 | **无，%install从:349开始** |
| RPi普通/RT的版本模块目录及devel路径带后缀 | 是 | 是 |
| RPi普通/RT的depmod使用精确release | Kbuild安装机制，本轮未运行 | 是，源文件:407、411；不再find第一个extra |
| 按字面要求，所有%files路径带后缀 | **否** | **否** |

完整命令、展开文本和退出码：[内核解析](../evidence/task9/rpmspec_kernel.txt)、[模块解析](../evidence/task9/rpmspec_modules.txt)。源码行号摘录：[内核](../evidence/task9/kernel_static_excerpt.txt)、[模块](../evidence/task9/modules_static_excerpt.txt)。机器可读检查结果：[static_preflight.json](../evidence/task9/static_preflight.json)，本轮语义门槛结果为FAILED，检查脚本退出1。它与rpmspec自身退出0是两件事，不能把解析成功写成整段预检通过。

### 2.1 确定的停止原因：树外模块%install缺少导出

12第4.2节的diff只在RPi的%build区段导出LOCALVERSION，随后还在该区段末尾unset；并未在%install添加导出。本轮要求两个spec的%build和%install均导出，原方案不满足。这是任务8候选方案与本轮门槛之间的遗漏，本轮没有在失败后自行补行、修改提交或继续构建。

树外模块的%install当前只复制已构建的.ko和共享配置，不调用Kbuild。因此这个缺项**不能证明模块的release已经错误**，也不是一次编译失败；当前根本没有开始编译。但不能据此忽略PM给定的检查项。后续若要求保持该门槛，需在此spec的%install开头补`export LOCALVERSION=%{lko_suffix}`，再重新核验；本次未实施。

### 2.2 %files字面要求与共享路径

RPi内核模块、devel和14条树外模块路径（普通/RT各7个）已经带正确后缀。没有后缀的条目来自既有共享布局：[内核完整路径表](../evidence/task9/kernel_expanded_files.txt)、[模块完整路径表](../evidence/task9/modules_expanded_files.txt)。

- 内核19条路径表达式：普通/RT的zImage、设备树、overlays、固件/boot配置，以及BTF头、通用头文件、perf和bpftool路径。包括`/boot/zImage`、`/usr/include/bpf/vmlinux.h`、`/usr/include/*`、`/usr/bin/*`等。
- 树外模块4条路径表达式（普通/RT各列同一对）：`/lib/modules/modprobe.d/tizen-modprobe-rpi4.conf`和`/lib/modules/modules-load.d/tizen-modules-rpi4.conf`。

这些共享路径与12第5节及PM批准的zImage命名相符；它们不是漏改版本模块目录。建议明确门槛为“所有RPi版本模块目录和devel目录均带后缀”，列明上述共享路径例外。若确实要求所有包路径都带后缀，则需要重新设计打包/部署方案；本轮没有擅自改zImage名、共享配置路径或放行例外。

### 2.3 PM裁决（任务9续跑，2026-11-03）

以下为PM对上一轮两条不通过项的裁决，覆盖2.1/2.2及第4节的历史待办，不修改原始检查证据：

- 树外模块 %install 不补 LOCALVERSION。理由：%install 只复制 %build 已产生的 .ko，不调用 Kbuild；外部模块的 release 目录由 KERNELDIR 指向的 devel 树中 include/config/kernel.release 决定；%files 列的是带后缀的精确路径，若目录不对 rpmbuild 会因文件缺失失败，构建本身就是检查。
- %files 后缀检查的门槛改为：RPi 普通/RT 的版本模块目录、devel 目录、%post 中 depmod 的 release 字符串必须带 -lko-base01；共享路径（/boot 下 zImage、zImage_rt、dtb、overlays、config.txt、固件文件，/usr/include、/usr/bin、/usr/libexec、/usr/sbin/bpftool，/usr/include/bpf/vmlinux.h，以及 modprobe.d、modules-load.d 两个配置）为允许例外。理由：上板按已批准方案手工替换 zImage（原文件保留为 zImage.orig），不在板上安装这些 RPM。
- 按此门槛，上一轮 static_preflight.json 的结果判为通过。把裁决和判定写进证据（新文件 evidence/task9/static_preflight_rejudged.json，引用原 json 的 SHA，不改原文件）。

执行判定：**PASS，仅限上述静态门槛**。原JSON保持逐字不变，SHA-256为`2beed081b1833db84bc067b1dff89c3803d4369055cea735dad16b076354bd15`。[重新判定证据](../evidence/task9/static_preflight_rejudged.json)。未补导出、未改任何spec、未新增或改写源码提交；新root/实际工具链和构建仍须独立检查。

## 3. 停止边界、产物与未执行项

遵守“第一段任一失败就停下报告”，在完成这次静态检查后仅整理证据和收尾，没有执行后续kernelrelease复验或初始化新的GBS-ROOT。

| 要求 | 本轮状态 |
|---|---|
| 普通/RT make kernelrelease重复验证 | 未执行；任务8结果不能替代本次复验 |
| task9独立GBS-ROOT、实际clang/lld与22.1.8比较 | 未初始化、未核验，不能声明一致 |
| build_kernel.log / build_modules.log | 未创建；没有GBS构建进程或BUILD-END记录 |
| 新内核、source包、树外模块RPM | 未产生 |
| 新zImage大小/SHA/版本及相对原厂差值 | 未取得，不拿任务2旧产物填数 |
| RT新映像版本 | 未取得 |
| 合并目录、depmod索引、全部vermagic | 未执行 |
| 7个extra模块CRC与新Module.symvers比对 | 未执行，不将未测写成“0项不一致” |
| 新.config与QB1211696比较 | 未取得新.config，无法比较 |
| 新模块目录du及三套并存容量 | 未实测；12中4,424 KiB/套、余5,800 KiB仍只是历史估算 |
| deploy_lko-base01部署包/逐文件哈希 | 未生成，不可部署 |
| 构建总耗时 | 未开始构建，无构建耗时数据 |

原始准备/解析日志保留temp/task9，小体积文本入evidence/task9；[原始日志行数、大小和SHA-256](../evidence/task9/raw_log_integrity.json)。无构建进程组、残留进程或构建挂载需要清理；静态工具的namespace已随命令退出，没有发信号。三棵本地源码树均干净，后续不能把“本地提交完成”误当作“构建完成”。

## 4. 后续事项

先闭合第2节门槛：补齐树外模块%install的LOCALVERSION导出，并由PM明确%files共享路径的适用范围；重新完成第一段全部检查后，才能进入内核→source包→树外模块的GBS构建及产物验收。当前尚未到工具链或依赖解析阶段，不臆测新root的版本、依赖包来源或sudo认证状态。

任务9尚未完成。成功构建且所有验收通过之后，下一步才是：**任务10：部署base01到RPi4并验证可以启动和回退（需要用户提前开板、在场）**。本次不满足任务10的执行前提。

## 5. 任务9续跑：kernelrelease通过，环境初始化前停止

### 5.1 源码身份和静态裁决

开工重新核对三个HEAD、lko/base01分支及工作树：内核仍为`8c8f2429401d6b282373e58b73399801a9486d5b`，树外模块仍为`10deb822453c759f6f944baf067c8b16a48ad914`，source仍为`25797e8af7ed95a5783bbe84c11959560aaf7e92`，均干净。没有改spec、补LOCALVERSION、新增或改写源码提交。[开工断言](../evidence/task9/resume1_source_assertions.json)、[收尾状态](../evidence/task9/resume1_final_source_state.json)。

按第2.3节PM裁决，静态结果改判PASS；原static_preflight.json保留，新增的static_preflight_rejudged.json引用原文件SHA，不替换历史证据。该通过不自动覆盖环境、构建和产物验收。

### 5.2 kernelrelease本轮复验

与任务8相同，使用已有LLVM平台root的qemu-arm/make只读计算版本字符串，内核源码只读绑定；本次O=输出均位于`temp/task9/resume1/kernelrelease/`。普通/RT分别从任务4对应配置复制.config和auto.conf，设置相应localversion-tizen，执行`ARCH=arm LLVM=1 LOCALVERSION=-lko-base01 -j1 kernelrelease`。这仅是用户指定的任务8式前置检查；没有将旧root复制或用于任务9实际构建。

| 变体 | 输出 | 退出码 | 耗时 |
|---|---|---:|---:|
| 普通 | 6.12.80-arm-rpi4-v7l-lko-base01 | 0 | 3.223529秒 |
| RT | 6.12.80-arm-rpi4-rt-v7l-lko-base01 | 0 | 0.304571秒 |

无.o生成，源码HEAD及工作树保持不变。[普通版完整命令](../evidence/task9/resume1_kernelrelease_arm-rpi4.txt)、[RT完整命令](../evidence/task9/resume1_kernelrelease_arm-rpi4-rt.txt)、[结果JSON](../evidence/task9/resume1_kernelrelease_results.json)、[执行脚本](../evidence/task9/resume1_kernelrelease_driver.py.txt)。两项合计约3.528秒，**不是构建耗时**。

### 5.3 环境初始化检查与确定的阻塞

已新建独立目录`temp/task9/GBS-ROOT-LKO-BASE01/`，保持空目录，尚未初始化；没有复用或复制其他任务的GBS-ROOT。`config/gbs_llvm.conf`与Git记录逐字一致，未修改。只读确认现有隔离HOME的.gbs.conf及仅含注释的.gbp.conf可用，/etc/gbs.conf不存在；配置与文件哈希见[环境门槛记录](../evidence/task9/resume1_environment_gate.json)。

指定新root不必修改配置：`/usr/bin/gbs:204–209`支持`-B/--buildroot`，`gitbuildsys/cmd_build.py:686–695`优先采用命令行buildroot。因此本轮预定覆盖值为`-B $WS/temp/task9/GBS-ROOT-LKO-BASE01`，原config只读引用，三个隔离变量按RULES保留。**这只是已核对的参数方案，没有执行GBS。**

阻塞来自已安装工具的实际调用路径，而非对认证缓存的推测：[当前工具源码摘录及SHA](../evidence/task9/resume1_gbs_privilege_audit.txt)。

1. `gitbuildsys/cmd_build.py:725–730`生成depanneur命令并由os.system执行。
2. `/usr/bin/depanneur:3164–3174`在启动路径设置认证维持回调并立即触发，回调明确调用`sudo /bin/echo -n`。
3. `/usr/bin/depanneur:2048`无条件把`sudo /usr/bin/build`放入实际构建命令；`:2177–2183`的初始化用--no-build分支也是基于同一命令，不是无sudo初始化通道。
4. `:2247`初始化后保存dist配置仍调用sudo。`--noinit`仅跳过初始化；`:529–548`要求已有scratch和配置，`:2067`不移除上述sudo调用，所以既不满足独立新root初始化要求，也不是不用sudo的解决办法。

当前执行身份为uid1000。此前任务2的成功GBS由用户终端启动，文档03明确记录工具自身会调用sudo；不能据此把本轮“不用sudo”解释为允许间接执行。**本轮未执行sudo -v/-n/-l、未尝试密码、未运行GBS探测认证状态、未修改已安装工具或建立sudo替代脚本。** 也没有通过复制旧root、改走宿主工具链或提前编译跳过前置检查。

因此停在“第一段剩余检查第2项：独立GBS-ROOT初始化”。这不是初始化命令返回失败、不是认证失败、不是工具链版本不一致，更不是内核编译失败：初始化命令尚未发出，clang/ld.lld版本及22.1.8一致性均未知。若继续沿用本机现有GBS链，需要PM明确是否允许GBS工具自身的sudo调用及由谁启动；若要求全过程完全不调用sudo，则须另行确定构建环境。本轮没有自行选择替代方案，也没有索要密码。

### 5.4 已产生内容、未执行项及下一步

已产生：新静态改判证据、两个kernelrelease输出目录/日志、空独立root目录、只读初始化调用链审计，以及本轮文档。历史源码提交和上轮原始证据保留。

| 验收项目 | 本轮结果 |
|---|---|
| kernelrelease普通/RT | 两项通过 |
| 新root中的Clang/LLD是否22.1.8 | 未初始化，未核验 |
| 内核、source包、树外模块构建 | 均未启动；build_kernel.log、build_modules.log未创建，无BUILD-END可记录 |
| 新zImage/RT版本、大小、SHA与原厂差值 | 无新产物，未核验 |
| 模块合并、共享配置比较、depmod | 未执行 |
| vermagic数量/不一致项、7个extra的CRC总比较数/不一致项 | 未取得；不能把未测写成0项不一致 |
| 新.config与QB1211696差异 | 无新构建.config，未比较 |
| 模块目录大小与三套容量 | 无新实测；任务8的估算不升级为实际结果 |
| deploy_lko-base01部署包及逐文件哈希 | 未生成 |
| 构建总耗时 | 未开始构建，无构建耗时数据 |

没有创建构建进程组、root子进程或持久构建挂载，无需发送信号或清理残留。静态检查namespace随命令自然退出；未连接任何开发板。下一步先闭合GBS初始化权限边界、完成任务9全部前置和构建验收；之后才是**任务10：部署base01到RPi4并验证可以启动和回退（需要用户提前开板、在场）**。当前不可部署。

## 6. 任务9续跑二：用户执行构建脚本（本轮只写不运行）

### 6.1 PM裁决与运行入口

GBS 内部的 sudo 调用（depanneur 的 sudo /usr/bin/build、认证维持 sudo /bin/echo -n、chroot/挂载等）允许，但只能由用户在自己的终端启动脚本时发生，沿用任务2的做法：脚本开头前台执行一次 /usr/bin/sudo -v 由用户认证，之后后台运行。你本人仍然不运行脚本、gbs、导出、构建或任何 sudo，不发信号。

已同步RULES任务9条目，覆盖第5节中需要明确启动主体的历史挂账。脚本为[scripts/run_task9_build.sh](../scripts/run_task9_build.sh)，权限0755；源码三个提交及配置保持不变。没有独立导出审计阶段，也没有在脚本中加入产物验证；导出由三次gbs build各自内部执行。

建议用户先进入tmux；以下一行会新建会话、运行脚本，并在前台脚本退出后保留交互shell，使depanneur依赖的控制终端继续存在。tmux socket在任务目录，`-f /dev/null`不加载用户tmux配置；保留的bash不加载profile/rc。**本机当前PATH及常见系统位置未发现tmux、screen或shellcheck；未安装这些工具。下面tmux命令须先由用户准备可用的tmux，不能声称当前已经能启动tmux。**

```sh
tmux -f /dev/null -S /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task9/tmux.sock new-session -s lko-task9 -c /home/linhao/Toolchain/development/linux_kernel_optimization '/usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_task9_build.sh; exec /usr/bin/bash --noprofile --norc -i'
```

如果用户已经进入自己建立的持久终端，会话内的完整脚本命令是：

```sh
/usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_task9_build.sh
```

非root用户前台会执行一次sudo -v；策略需要时由用户在自己的终端输入密码。root跳过。认证后不等待用户输入，worker及每次构建stdin均接/dev/null；工具自行尝试控制终端认证时，凭据/停止态检查会停止后续调度，不回答提示、不再次认证。tmux不保证sudo缓存永久有效，工具仍按原机制每3分钟维持认证。

### 6.2 前置核对与实现行号

下表行号指本commit的run_task9_build.sh，不是旧脚本。所有前置核对均在:365唯一的直接sudo -v之前；root条件也仅跳过该行，不跳过预检。

| 前置项 | 实现位置 | 判定 |
|---|---|---|
| task9工作目录可写、真实路径不重定向 | :295–303 | 失败即输出原因及ALL-END；目录不可写时只能写stderr，不谎称已写状态文件 |
| 工具齐备、不接受用户参数 | :304–307 | 仅检查可执行文件存在，不执行GBS或sudo探测 |
| 独占锁 | :308–310 | 拒绝符号链接/非普通节点，flock -n失败即停，不释放别人的锁 |
| 前次supervisor及三个阶段PGID | :311–319 | 先校验非空正整数，再只读检查存活进程；有存活则停，不发信号 |
| 历史日志/状态/监控证据 | :320–333 | 拒绝覆盖；仅在确认无冲突后把独立预检status提升为status.txt |
| ROOT位于task9且独立、首次为空 | :334–338 | realpath、可写、非符号链接；不复制/复用旧root，不自动清理 |
| 三个HEAD、分支、干净树 | :171–180、:339 | 精确匹配固定SHA、lko/base01；git读取失败不当作空状态成功；成功空status才是干净 |
| config存在及SHA | :9–10、:181–186、:340 | 固定SHA=`d47536dd30900412e7bbd2d7057e9dd486f94ad2b2b6d8404a510a23be0bdc48` |
| 隔离HOME与GBP配置 | :341–349 | .gbs.conf精确两行；.gbp.conf仅注释普通文件；/etc/gbs.conf不存在 |
| 负载与环境覆盖 | :350–355 | nproc先判非空数字；-j10≤nproc/2；拒绝未审查Git/XDG/构建根/虚拟环境覆盖 |
| 同root进程与已有编译任务 | :356–361 | 同root已有进程则停；其他GBS进程只打印，不处理 |

构建各阶段启动前:256–266再次核对当前源码和config，并切换到对应仓库；commit参数固定SHA，不使用include-all。日期函数:25使用Asia/Shanghai；命令替换对必须有值的HEAD/branch/SHA/路径/PGID/nproc先检查退出状态和非空；git status及“无存活进程”的合法空结果单独处理。所有read都有文件或here-string输入，没有交互read。

预检失败也由EXIT trap写ALL-END。重复启动/锁占用时写独立`preflight.<pid>.status`并保留已有status.txt；首次取得运行所有权后使用status.txt。无法写任务目录时只在stderr给ALL-END，属于明确记录能力限制。预检失败时三个阶段为SKIPPED，具体失败见STAGE preflight；不能仅因ALL-END中没有FAILED单词就判断成功。

### 6.3 与任务2已验证机制的对照

基础文件SHA-256为`7a47b58cea0bf9d8dba3b97045a53559d37ddf644c70814790b264f17066ecba`；没有修改run_baseline_build.sh。[静态检查记录](../evidence/task9/user_runner_static_checks.json)。

| 机制 | 沿用或调整及原因 |
|---|---|
| 前台认证→独立后台supervisor | 沿用set -m、后台worker、FD9锁继承、disown；不使用setsid，保留控制终端用于GBS认证 |
| 构建步骤 | 原export→GCC→LLVM改为kernel→modsrc→modules；本任务明确只要求三次build，取消独立export/trace审计及其清理，不运行其他构建入口 |
| 配置与源码 | 改为三个固定HEAD、单一LLVM config SHA及明确-P tizen_unified_standard；-B指定task9独立root，arch/thread/-j保持任务2值 |
| stdin与umask | 沿用后台/dev/null、系统PATH；不设置umask，不在后台进行额外sudo认证 |
| 进程组/残留 | 沿用ps分组快照和300秒只读等待；本轮对凭据/停止态不调用可能无限等待的wait，只有组已空才reap；未退出则保留ACTIVE-OR-RESIDUAL，停止后续阶段 |
| 实时日志 | 旧脚本仅raw实时、结束复制；本轮运行时log与raw为硬链接，同一输出立即可见；结束复制到新inode封存log，raw留给可能的残留写入者，保证BUILD-END仍是log末行 |
| 凭据提示 | 增加日志模式检查，约5秒一次；出现提示立即停止后续调度，只观察本组最多五分钟，不输入、不重试、不向当前进程发信号 |
| 工作区外写入 | 沿用marker/find和本组stdout/stderr直接观察；发现直接越界只记录、等当前构建自然结束后判失败；其他任务的文件仅标无法归属、不删不移 |
| 状态/退出 | 沿用原子状态更新和EXIT/INT/TERM/HUP trap；三个阶段任一失败则后续SKIPPED；不宣称能拦截SIGKILL/断电 |
| 产物验收 | 本脚本完全不做工具链/包身份/CRC等验收，按本轮要求移到用户报告结束后的独立核对 |

run_managed在:187–255；残留等待在:132–144；凭据检查在:145–148；外部写入检查在:149–170。每个阶段记录完整运行前进程表、实际PGID和结束快照，其他任务不处理。观察失败不会被静默当作“无进程”。

每个build_*.log末行是`BUILD-END <kernel|modsrc|modules> <Asia/Shanghai时间> exit=<阶段退出码>`；实际GBS/time退出码另记COMMAND-EXIT，残留时为UNKNOWN，不能冒充命令自然结束。SKIPPED日志明确NOT-STARTED、exit=125为监督器约定而非一次GBS退出；尚未开始的日志在最终收尾时生成。可能持续增长的原始输出仅在.log.raw，封存日志不再被后代追加。

status.txt末行固定`ALL-END <时间> kernel=<结果> modsrc=<结果> modules=<结果>`；三个OK才代表构建调度成功，且仍需后续产物验收。凭据/残留失败的ALL-END表示监督器已停止调度，不表示残留全部退出。最后两条前台输出分别是tail三个日志及status的命令、grep ALL-END的命令；未创建的后续日志会由tail -F等待出现。

### 6.4 三次构建完整命令（由脚本执行，不要另行并发运行）

三个阶段均使用profile.tizen_unified_standard（命令-P省略profile.前缀），仓库URL由未修改且校验SHA的config/gbs_llvm.conf决定。相同GBS-ROOT使新内核RPM成为后续依赖候选；脚本不强行替换resolver结果、不安装指定旧包、不用--noinit。实际依赖是否为本次包，仍须按第7节核验。

阶段`kernel` → `temp/task9/build_kernel.log`：

```sh
cd /home/linhao/Toolchain/development/linux_kernel_optimization/linux-rpi && /usr/bin/env TMPDIR=/home/linhao/Toolchain/development/linux_kernel_optimization/temp PYTHONDONTWRITEBYTECODE=1 PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home/.gbp.conf /usr/bin/time -v /usr/bin/gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -P tizen_unified_standard -A armv7l -B /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task9/GBS-ROOT-LKO-BASE01 --threads 1 --define '_smp_mflags -j10' --commit 8c8f2429401d6b282373e58b73399801a9486d5b
```

阶段`modsrc` → `temp/task9/build_modsrc.log`：

```sh
cd /home/linhao/Toolchain/development/linux_kernel_optimization/ext/linux-tizen-modules-source && /usr/bin/env TMPDIR=/home/linhao/Toolchain/development/linux_kernel_optimization/temp PYTHONDONTWRITEBYTECODE=1 PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home/.gbp.conf /usr/bin/time -v /usr/bin/gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -P tizen_unified_standard -A armv7l -B /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task9/GBS-ROOT-LKO-BASE01 --threads 1 --define '_smp_mflags -j10' --commit 25797e8af7ed95a5783bbe84c11959560aaf7e92
```

阶段`modules` → `temp/task9/build_modules.log`：

```sh
cd /home/linhao/Toolchain/development/linux_kernel_optimization/ext/linux-tizen-modules && /usr/bin/env TMPDIR=/home/linhao/Toolchain/development/linux_kernel_optimization/temp PYTHONDONTWRITEBYTECODE=1 PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home/.gbp.conf /usr/bin/time -v /usr/bin/gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -P tizen_unified_standard -A armv7l -B /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task9/GBS-ROOT-LKO-BASE01 --threads 1 --define '_smp_mflags -j10' --commit 10deb822453c759f6f944baf067c8b16a48ad914
```

命令中的TMPDIR/PYTHONDONTWRITEBYTECODE/PATH在脚本顶层导出，HOME/GIT_CONFIG_NOSYSTEM/GBP_CONF_FILES只给GBS及后代；这里展开为完整行便于评审。每次用time -v记录墙钟耗时和最大RSS，三阶段串行。源码、profile、root参数不会由用户填写或临时选择。

### 6.5 静态检查和预计耗时

`/usr/bin/bash -n scripts/run_task9_build.sh`退出0；本机没有shellcheck，按“若已有”条件跳过，没有安装或调用替代构建检查。人工逐项检查了前台认证之前的所有门槛、三阶段顺序、失败跳过、锁与残留、凭据不输入、日志封存及退出trap。**没有运行脚本、source脚本、运行模拟构建或试验trap路径；语法/静态通过不代表运行验收已通过。** [检查证据](../evidence/task9/user_runner_static_checks.json)。

三阶段构建估算约45–90分钟：参考任务2LLVM普通+RT约36分50秒，另计新root依赖初始化、source包和树外模块构建；后两者尚未实测，网络/缓存/其他任务负载可能延长。构建后的产物核验另需时间。本轮无构建耗时实测，也未生成运行日志/status/锁。

## 7. 构建后核验计划（只写说明，未执行）

用户告知结束后先看status的各阶段结果、BUILD-END和进程组；有失败/凭据/残留就封存日志并报告，停止后续验收或重试，不因存在RPM文件跳过失败状态。成功时按下列顺序处理：

1. 在任务9新root中读取clang、ld.lld版本和对应RPM，必须同为22.1.8；结合compile.h、编译日志确认实际编译器。**不一致则本次产物作废，不部署**；不拿旧root版本替代。
2. 核对modules构建实际安装的普通/RT kernel-devel、modules及source包：安装日志、root RPM数据库中的NVR/BUILDTIME和新devel路径，与本次生成RPM的NVR、构建时间、SHA-256交叉确认。还要关联实际解析/缓存/安装的RPM文件SHA，不能仅凭同名NVR认定；若缺乏安装来源证据就标未闭合，不强行指定依赖或把remote旧包当新包。共享root后续阶段可能更改已安装包集合，故须保留各阶段原始日志/仓库缓存作为证据。
3. 解出普通版zImage，记录大小及SHA，核验版本6.12.80-arm-rpi4-v7l-lko-base01；与QB1211696原厂zImage比较字节和百分比。RT只核验zImage_rt的6.12.80-arm-rpi4-rt-v7l-lko-base01版本字符串。
4. 在temp/task9/stage/合并普通版kernel/和extra/七个.ko；使用该root的depmod -b <stage> <release>生成索引。确认modprobe.d、modules-load.d共享配置与原厂一致，**不放进部署包**，板上沿用原件。
5. 用该root的平台modinfo逐个检查所有.ko的vermagic必须为`6.12.80-arm-rpi4-v7l-lko-base01 SMP mod_unload modversions ARMv7 p2v8`；记录数量及全部不一致项。用平台工具解析七个树外模块__versions，对照新Module.symvers逐符号CRC，记录总比较数、缺失符号及不一致项，不以vermagic一致替代CRC。
6. 用平台工具du -sk统计整个版本目录，与4,424 KiB估算对照；设新目录为S KiB，原厂已保留时再放干净/类产品两套的剩余空间估算为14,648−2×S KiB。类产品基线暂按同样大小估算，明确尚未实测，并复核inode/部署前df。
7. 合格后生成temp/task9/deploy_lko-base01/部署包，仅含zImage和完整新版本模块目录，逐文件SHA-256清单随包保存；二进制不入库，不执行板上部署。
8. 用平台Python运行scripts/diffconfig，与QB1211696最终.config比较。后缀当前来自环境LOCALVERSION，故.config可以完全相同；若出现非LOCALVERSION差异，逐项列出工具/来源依据，不自行认定可接受。

验收结束后再更新14/STATUS及小体积证据。下一步仍为“任务10：部署 base01 到 RPi4 并验证可以启动和回退（需要用户提前开板、在场）”，只有任务9验收通过才具备执行前提。


## 8. 任务9续跑三：启动前因tmux不可用停止（2026-11-03）

PM允许代理按第6.1节同一socket/会话以分离方式启动脚本并监控；唯一前台sudo -v仍由用户在tmux窗口自行认证，代理不直接执行sudo、不处理密码、不配置askpass/sudoers、不发信号。规则已登记。

按启动第1步检查，`/usr/bin/test -e /usr/bin/tmux`和`/usr/bin/test -x /usr/bin/tmux`均退出1：指定路径不存在且不可执行。**需要用户安装 tmux。** 已按停止条件结束，未尝试安装、替代终端、创建会话或启动脚本。[命令/输出/退出码与脚本哈希](../evidence/task9/resume3_tmux_gate.txt)，原始记录保存在`temp/task9/resume3/tmux_gate.txt`。

- 认证：尚未进入sudo -v，没有密码提示，用户无需在本轮认证。
- 监控：未启动supervisor或阶段进程，未创建monitor.log；status.txt及三个build_*.log均不存在，因此没有ALL-END、BUILD-END或可引用的失败日志末80行。这是启动条件不满足，不是脚本preflight或编译失败。
- 三阶段kernel/modsrc/modules：均未启动；耗时、峰值RSS不适用，不写成0秒构建成功。
- 本轮工具链版本、实际kernel-devel身份、zImage大小/差值、模块目录容量、vermagic/CRC和.config均未核验；没有新部署包，也没有Module.symvers.base01可复制。下一轮成功后须补充Module.symvers副本哈希及七个树外模块引用符号清单。
- 源码、启动脚本及现有构建根未修改，既有文件未清理；未访问vendor_local，未连板、推Gerrit或触发QB。

下一步由用户安装tmux；可用后再按已授权流程启动，不自动重复本次尝试。任务9未完成，**不满足任务10的产物验收前提**。后续模块依赖来源若不符，按本轮PM指令继续其余核验但明确标记；工具链不是22.1.8则停止并判产物作废。


## 9. tmux安装后续跑：认证等待超时（2026-11-03）

开工重新读取RULES、第7–8节和上次tmux门槛证据。`/usr/bin/tmux -V`返回`tmux 3.4`、退出0；启动前task9顶层没有status.txt、build_*.log/raw、锁或阶段PGID文件。只新建本轮观察记录，未删除或归档旧构建文件。[检查记录](../evidence/task9/resume3_tmux_installed_launch.txt)。

执行如下命令，返回0；TMPDIR为工作区temp，未加载用户tmux/bash配置：

```sh
/usr/bin/tmux -f /dev/null -S /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task9/tmux.sock new-session -d -s lko-task9 -c /home/linhao/Toolchain/development/linux_kernel_optimization '/usr/bin/bash /home/linhao/Toolchain/development/linux_kernel_optimization/scripts/run_task9_build.sh; exec /usr/bin/bash --noprofile --norc -i'
```

脚本于23:24:46（Asia/Shanghai）进入preflight，通过认证之前的前置检查后显示：

```text
Foreground sudo validation; authenticate only in your own terminal.
[sudo] password for linhao:
```

已向用户提供该socket/会话的attach命令；代理没有直接执行sudo、输入或记录密码、设置askpass/sudoers、发送信号。按30秒间隔读取窗口及status；前段通过工具逐轮读取，23:32:37起的结构化观察持久保存在[认证观察日志](../evidence/task9/resume3_auth_observation.txt)，只记录时间、状态、读取退出码和提示是否可见，不保存用户终端输入或其他任务进程清单。

30分钟等待期限后首轮检查（23:55:42）仍为WAITING，按PM要求停止轮询，不重启脚本。23:55:59封存时：会话仍存活（pane_pid=4029395、pane_dead=0），状态为preflight RUNNING、kernel/modsrc/modules PENDING，未出现Background supervisor PID/PGID，没有supervisor PGID文件。[状态原文](../evidence/task9/resume3_auth_timeout_status.txt)、[终点摘要](../evidence/task9/resume3_auth_timeout_summary.json)、[证据大小/行数/SHA-256](../evidence/task9/resume3_auth_manifest.json)。

这是**代理等待认证超时**，不是sudo返回认证失败，也不是脚本preflight已退出或编译失败：没有可报告的认证退出码。脚本没有生成ALL-END；不能替它写入FAILED/ALL-END或把PENDING改为SKIPPED。锁和status按原样保留。

| 项目 | 本轮结果 |
|---|---|
| 用户认证完成 | 未观察到完成；终点仍为密码提示 |
| kernel / modsrc / modules | 均未启动；无构建耗时或峰值RSS |
| 三份构建日志 / BUILD-END / 最后80行 | 文件不存在，无可引用构建日志 |
| 工具链22.1.8与新kernel-devel来源 | 未核验 |
| zImage大小/差值、模块大小/容量、vermagic/CRC、配置差异 | 未取得新产物，未核验 |
| 部署包 / Module.symvers.base01及引用符号清单 | 未生成 |
| 任务10前提 | 不满足 |

未访问vendor_local、连接开发板、修改源码/启动脚本、推Gerrit或触发QB。GBS尚未启动，因此没有进入10分钟构建监控，也没有伪造build监控日志。原tmux会话及前台认证进程没有被终止；**以后在原窗口完成认证仍会继续启动构建**。等待用户反馈后应读取原会话/status恢复监控，不再次执行启动脚本；本轮不清理锁、status或其他已有文件。
