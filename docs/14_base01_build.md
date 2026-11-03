# 任务9：干净基线构建与前置检查

**最新状态（2026-11-03续跑）：PM已裁定静态门槛通过，普通/RT kernelrelease复验通过；停在独立GBS root初始化前。已安装GBS/depanneur的初始化路径会执行sudo，与本轮“不用sudo”的约束不兼容。未启动GBS或任何构建。详见第5节。**

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
