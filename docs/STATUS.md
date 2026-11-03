# 项目状态

任务 V1：厂商补丁已本地入库并完成试打，报告在本地 vendor_local/V1_report.md（不入库）

更新：2026-11-03（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务9停在第一段第2项静态门槛，尚未构建。** [14预检报告](14_base01_build.md)、[证据](../evidence/task9/README.md)。未连接开发板、未执行GBS/sudo、未发信号、未推Gerrit或触发QB。

- 计划/进度：指定源码与分支准备完成→两个spec原样应用任务8 diff并各提交一次→平台rpmspec解析成功→语义门槛失败，后续kernelrelease复验、独立root/工具链检查、构建及产物核验均未执行。
- 已闭合：内核lko/base01=`8c8f2429401d6b282373e58b73399801a9486d5b`；树外模块lko/base01=`10deb822453c759f6f944baf067c8b16a48ad914`；source仓库lko/base01仍为`25797e8af7ed95a5783bbe84c11959560aaf7e92`，不改源码。三树干净；lko/base仍0fac5de6；ext已忽略。证据见task9/source_integrity.json。
- 停止原因：12第4.2节方案未在树外模块%install导出LOCALVERSION；两个spec还有共享boot/配置/头文件/工具路径不带后缀，不满足本轮“所有%files路径”的字面门槛。RPi版本模块/devel目录及depmod精确release检查通过。没有在失败后自行修spec或放行例外。
- 需要PM裁决/挂账：补齐%install导出；明确后缀检查仅针对版本模块/devel目录还是也改共享路径。新root工具链、依赖来源、构建耗时、zImage/模块大小、vermagic/CRC、.config和部署包均未取得，不可部署。
- 后续：先恢复并完成任务9；验收通过后下一步为“任务10：部署base01到RPi4并验证可以启动和回退（需要用户提前开板、在场）”。任务10当前前提未满足，原有U-Boot串口等挂账保留。

**任务8开发机构建准备完成；未连接开发板、未完整构建、未推Gerrit或触发QB。** [12构建部署准备](12_kernel_deploy_prep.md)、[证据索引](../evidence/task8/README.md)。

- 计划/进度：读取PM审核和历史证据→规则第5/10项更新→同次QB元数据/RPM/固定公开源码交叉核对→后缀kernelrelease及spec解析→容量和任务9建议→文档/证据同commit推main，均完成。
- 已闭合：六个指定extra模块由linux-tizen-modules-rpi4 11.0.0-0提供，源码分属linux-tizen-modules和linux-tizen-modules-source两固定项目；同包另有zlogger。MIC根据同次KS生成modules.img，没有独立镜像提供RPM。证据见12第2–3节。
- 版本方法：普通版精确验证6.12.80-arm-rpi4-v7l-lko-base01，RT及第二后缀字符串也通过；无.o生成，sandbox HEAD/status不变。spec diff只在报告和temp，未应用/提交源码改动；完整构建和模块ABI仍待任务9。
- 容量估算：每套4,424 KiB；保留原厂再加两套约剩5,800 KiB，需任务9以新产物实测复核。共享modprobe.d/modules-load.d保持原状；不整块刷模块分区。
- 授权已登记：根分区默认ro，授权写入须rw后恢复ro；实验临时停用显示服务仅runtime mask并在结束unmask，本阶段不做图形场景。历史“显示服务处理待PM决定”由本次授权覆盖。
- 挂账/下一步：任务9构建干净基线和配套树外模块，建议约60–100分钟（估算，未执行）；独立依赖仓库、包哈希/Module.symvers/CRC、最终du/inode及部署前空间需核验；内核替换执行由PM另下发。RPi4仍下线；本轮任务8已明确只在开发机完成，无待补的任务8板上操作，后续部署待RPi4接回。U-Boot串口命令行能否进入仍待用户确认。

**PB1产品板只读探测已完成采集与证据整理；配置全文比较和经确认的空闲基线未闭合。** 产品身份断言通过（armv7l / Tizen / 内核6.12.60不含rpi4），内核由Clang/LLD22.1.8编译。报告：[13_product_board_probe.md](13_product_board_probe.md)，[证据索引](../evidence/pb1/README.md)。

- 计划/进度：规则及设计复核→授权重连→身份/root与只读采集→内存/进程汇总→脱敏扫描→owner恢复→报告/状态/证据同commit推main；读取与整理完成。本轮仅一次宿主SDB服务重启，未操作板上服务。
- 已闭合：LowTotal563,132 KiB；独立CMA区304 MiB；vmalloc=300M、UsedVirt122,944 KiB；zram主算法zstd、disksize1,065,132,032 B、重压缩算法接口存在；MGLRU0x0001/TTL0；没有暴露BTF和function profiler接口。出处见13首表。
- 限制/待裁决：/proc/config.gz不存在、/boot为空，所列149个符号的产品配置值未知，无法做真实配置diff；需同镜像可信.config。进程快照发生在开机约100–110秒，负载较高，不视为空闲基线；需用户确认标准/空闲场景后另采。其余接口缺失、两个VM读取无权限及需要源码核对项见13末节。
- 收尾：sdb root off后回读uid5001；没有板上临时文件；原始输出及真实进程映射仅保留temp/pb1，脱敏证据入库。产品板不适用RPi4常规授权，继续禁止推程序、写文件/参数、重启和服务变更。
- **RPi4当前下线；任务8的板上部分待RPi4接回后补做。** 既有RPi4挂账（显示服务处理、U-Boot串口命令行等）保留，不在产品板执行。

以下任务7及更早记录为RPi4历史结果：

**任务7 r4完成：配网服务三次开机验证均通过（第1次补采，第2/3次自动重连）。** PM确认此前故障为宿主SDB旧连接状态；本轮第2/3次各经1次获准kill-server/start-server自动恢复，设备列表均为空，支持该裁定。未修改板上文件/标签/网络、未手动执行配网脚本或操作板上服务。[11 r6](11_board_boot_chain.md#2026-11-02-r6根因确认与重启验证)、[证据](../evidence/task7/r4/README.md)。

- 计划/进度：规则/历史读取→补采第1次→新重连流程登记→journald/显示服务只读核对→第2/3次前置检查、重启、自动重连与验收→owner恢复→文档证据同commit推main，均完成。
- 已闭合：三次boot_id依次24a5fc5a…、e9257b33…、f0f81c95…；服务success/0、完成日志、MAC/IP及SDB可达均满足。第1次可达基于用户此前手动恢复宿主SDB；第2/3次分别65.130/62.122秒自动恢复，本轮kill-server总2次，没有其他设备受影响。
- 服务耗时3.448104/3.415764/3.418215秒；multi-user到达比分别退出晚31.879/26.133/23.160毫秒；sdbd ActiveEnter为开机20.499910/20.352107/21.075432秒。三次链路均100Mbps/Full。
- journald已证实System Journal max64.0M；最终disk-usage52.0M。两服务文件及容量配置哈希不变；未改配置或重启板上服务。
- display-manager的Pre脚本外部命令均存在；ExecStart为存在的ELF enlightenment，主进程退出127；缺失命令无法确定，不猜测、不试跑。其持续重启仍作为测量噪声挂账。
- 收尾：root off后回读uid5001(owner)，闭合此前owner收尾；无板上临时目录/文件。原始日志留temp/task7/r4，仅小体积摘录入库。
- 挂账：**display-manager处理方式待 PM 决定**；**U-Boot串口命令行能否进入，用户待测**。内核替换具体执行任务仍由PM下发。

以下r3及更早条目为历史停止状态，已由本轮补采和验证闭合；不再作为当前阻塞：

**任务7 r3：授权和journald配置登记完成；第一次重做重启后SDB等待600秒超时，未通过可达性验收，第二次未执行。** 已按停止条件结束，未进行服务/网络补救。新boot的服务状态/退出码、日志、耗时、unit时间点及journald运行时上限均未取得，不能拿上轮结果替代。[11 r5](11_board_boot_chain.md#2026-11-02-r5重启验证重做)、[证据](../evidence/task7/r3/README.md)。

- 计划/进度：身份核对→登记新授权→写入容量配置→用户确认在场/网线牢固/显示器已接→前置检查→第一次无参数重启→每10秒探测→600秒超时停止→封存证据同commit推main。未达到第二次重启条件。
- 已闭合：/opt可用1,225,180 KiB，配置选SystemMaxUse=64M；/etc/systemd/journald.conf.d为0755，50-lko.conf为0644，标签均与journald.conf一致为`_`，内容和SHA回读通过。没有restart/reload journald；是否实际生效待恢复后取日志确认。
- 前置检查通过：LOWER_UP、脚本/unit哈希不变、enabled。用户已在场并接显示器；display-manager仍activating、NRestarts=2199，前10分钟58次计划重启（5.8次/分钟）、348行相关日志；直接报错exit127，底层原因未给出。
- 第一次重做于17:26:14+08发出reboot，600.0002秒内59次实际connect/探测未恢复shell；第二次跳过。已请用户在串口执行ip link show eth0并查看网口指示灯。本轮最终owner恢复/回读因不可达未完成；等待用户确认时的owner回读不作最终替代。没有板上临时目录，授权的journald配置保留。
- PM对r4裁定原文见11 r5：r4即11:09重启后的boot；约13:12是日志范围误读。上次最可能链路中断但未完全确定；本次原因仍未知。
- 新常规授权已登记RULES第7–9项：测量小程序、/opt测试应用、journald容量；冷启动由用户手动，读卡器已具备。这四项不再作为待答问题。
- 挂账：**display-manager反复重启：用户可接显示器，实验期间如何处理待 PM 决定**（本轮已接仍观察到失败）；**U-Boot串口命令行能否进入，用户待测**；本次超时后的配网验证/owner收尾及内核替换执行步骤待PM后续安排。

以下为任务7 r2的历史状态；其开机对应关系已由上述PM裁定更新：

**任务7 r2只读排查完成；没有重启或修复服务。** 本次boot服务为active/exited、Result=success、ExecMainStatus=0，耗时4.974194秒，multi-user.target在退出后4.258毫秒到达。当前网络由用户手动恢复，不能补判上次首次重启验收通过。[11 r4](11_board_boot_chain.md#2026-11-02-r4首次重启失败排查)、[证据](../evidence/task7/r2/README.md)。

- 计划/进度：身份断言、服务/日志/网络/udev只读采集、时间线与缺失证据分析、owner恢复、文档证据同commit推main；采集分析与收尾已完成。
- 已闭合：两服务文件哈希/标签与启用链接保持不变，当前boot服务确实执行并退出0；现存journal从开机8605秒开始，不覆盖16–21秒执行窗口。Storage=persistent、上限4MiB且已占满；早期日志被高频display-manager日志挤出是推测，logger是否曾成功写入无法确定。11:09失败不能仅归因网线松动。
- 时间前提：用户报告约13:12再次开机，但当前uptime/UTC推算与之不一致且早期墙钟由1970跳变；不将当前boot直接对应11:09故障，详见11 r4。
- .link前提：目录与net_setup_link udev规则存在；默认99-default.link被/etc同名/dev/null链接屏蔽，eth0无ID_NET_LINK_FILE，启用前设置MAC的效果未验证。
- 收尾：本轮无板上临时文件，/opt/usr/lko_task7不存在，mounts与根/opt/usr df前后一致；SDB已恢复owner并回读uid5001。原始输出保留temp/task7/r2，不删除历史证据。
- 挂账：**配网服务的修复方案或重启验证重做，待 PM 决定**；内核替换执行步骤仍待PM下发。历史待答事项已按本轮授权更新，当前挂账见本文件开头。

以下为任务7 r3结束时的历史状态（本轮补充以以上及11 r4为准）：

**任务7：第一部分完成；第二部分首次重启后SDB等待600秒超时，按PM条件停止，未执行第二次重启。服务运行结果未知，整体未通过首次重启验收。** 未修改内核、启动参数或boot/模块分区；不安装RPM、不手动启动配网服务。已请用户通过串口手动配网恢复；本轮未做其他补救。

- 已闭合：模块分区Available=14,648 KiB、空闲inode=8,054，现有版本目录du=4,424 KiB；kdbus已加载使用，zlogger未加载，logger是另一模块；rpm -qf未找到两外部模块所属包。ramdisk无版本目录/.ko，init按槽位只读挂载模块分区再modprobe。已有sandbox QB1211696 DTB与板上SHA一致。证据：evidence/task7/。
- 已记录PM审核结论：不采用tryboot/A/B，不整块重写模块分区；后续每个实验kernelrelease唯一，模块新目录并存，原厂zImage.orig与实验zImage文件名切换。具体内核替换执行步骤待PM下发；本轮不执行替换。
- 用户待测：串口能否进入U-Boot命令行。读卡器已具备；测量小程序、测试应用已授权；冷启动由用户手动操作。
- 临时目录/opt/usr/lko_task7已在第一部分结束整体删除；首次重启前只持久修改了两服务文件SMACK标签User::Shell→`_`，内容哈希不变。重启前临时目录已删除、mounts/df一致；首次重启后不可达，最终owner恢复及新一轮身份/mounts/df无法回读，不声称完成。详见[11 r3](11_board_boot_chain.md)、[超时证据](../evidence/task7/reboot1_reconnect.json)。

**任务6 r2已完成调研与只安装验收，未运行配网脚本、未重启。** PM于2026-11-02明确替代systemd-analyze的验收规则，解除上轮工具阻塞。上次停止报告保留在[11](11_board_boot_chain.md)前半部分，本轮结果追加在其末尾。

- 计划/进度：身份断言 → 先只读启动链及阶段0a → 脚本语法/人工检查 → root原本rw条件下安装、enable → PM替代验收 → 删除临时目录、恢复owner → 文档/证据同commit推main，均完成。未改内核树/分区/启动参数，未推Gerrit。
- 已闭合：boot_a=p1/vfat，固件加载u-boot.bin，boot.scr.uimg从所选槽加载zImage及ramdisk，/mnt/inform/partition-ab.info当前a；module_a=p6/ext4、ro。CMA320MiB对应cma-320 overlay；413个boot文件已记录大小/哈希。详见[11本轮结果](11_board_boot_chain.md#2026-11-02-r2恢复调研与安装本轮结果)、[证据索引](../evidence/task6/r2/README.md)。
- 服务已安装：/usr/local/sbin/lko-net-setup.sh、/etc/systemd/system/lko-net-setup.service及multi-user.target.wants启用链接。LoadState=loaded、LoadError为空、enabled，inactive/dead且ExecMainPID=0；reload后journal无该unit警告/错误。[验收](../evidence/task6/r2/18_verify.transport.txt)。脚本运行及SMACK执行权限仍待首次重启验证，未以装载成功替代运行验收。
- 清理闭合：/opt/usr/lko_task6已整体删除，SDB恢复owner；/proc/mounts全文前后一致，/始终rw,relatime、未remount。/opt/usr df不变；根分区已用增加12KiB，服务文件/enable目录按授权保留。[对照](../evidence/task6/r2/cleanup_and_verification.txt)。
- 需PM审核/挂账：内核替换与回退草案；B槽完整性/可启动性、端到端tryboot及自动复位/回退、initramfs模块槽映射、QB模块镜像封装/刷写命令及现场恢复途径仍未知或未验证。没有把A/B标签当成可用回退。设计v4此前三项授权问题现已由任务7 r3裁定，见本文件开头。
- 下一步：**第一次重启验证（需要用户在场）**；**PM审核内核替换方案**。这是任务6结束时的后续项；任务7已按在场确认尝试第一次但超时，PM审核原文已追加11 r3。

**设计文档当前版本为v4：[docs/10_design_v4.md](10_design_v4.md)，待外部评审；[v1](10_design_v1.md)、[v2](10_design_v2.md)、[v3](10_design_v3.md)保留为历史记录。**

- 2026-11-02 A入库完成：v4从指定Downloads移动，原文未改，147,550 B，SHA-256 `f620a3cdc34a6afd586396252c901c1a0ca4d1c591afc27c4c2d3b9a07698fb3`；Downloads已无副本。三份v3评审记录均找到且已位于docs/reviews，原样入库：[Codex评审](reviews/design_v3_review_codex.md)、[Codex核验](reviews/design_v3_review_codex_verification.txt)、[Claude Code评审](reviews/design_v3_review_claude_code.md)。核验记录：temp/task6/r2/intake.json。
- 此前设计授权问题已闭合：测量小程序/测试应用纳入常规授权，冷启动由用户手动操作（任务7 r3）。A未操作开发板，独立提交`1526c85`；B按2026-11-02替代验收裁决完成任务6并另行提交，见本文件开头。

- v3为同日修订版，补入上一轮 Claude Code 完整评审（docs/reviews/design_v2_review_claude_code.md）中此前未处理的内容；阶段 0 拆为 0a/0b。已从指定Downloads路径移动覆盖现有文件，Downloads下已无该文件；移动过程未修改内容，114,130 B，移动前后SHA-256均为`793c0762d48d9dc46a7af7ccc4c55a0aeb212b967c58184a8052f4db68d435cb`。
- v2的Claude Code评审已找到，原文件已位于目标路径[docs/reviews/design_v2_review_claude_code.md](reviews/design_v2_review_claude_code.md)，原样入库；59,159 B，SHA-256为`126f6951cf1bb22286a991f57be0bce022482faf232538ea4eb3b5290ab03696`。
- Codex核验记录已找到，按要求从`temp/design_v2_codex_review/verification.txt`复制到[docs/reviews/design_v2_review_codex_verification.txt](reviews/design_v2_review_codex_verification.txt)，原文件保留；3,205 B，源文件与副本SHA-256均为`9d59b823a4f7010a66636e49ef5463e06920b7afb721936be38208fc40b4fecb`。`lz4-fast-loop.patch.txt`不上传。上述文件字节核对记录在`temp/design_v3_intake_20261030/files_verified.json`。
- v2为同日修订版，补入上一轮 Claude Code 完整评审中初稿遗漏的内容；已从指定Downloads路径移动覆盖现有文件，Downloads下已无该文件；移动过程未修改内容，75,639 B，移动前后SHA-256均为`4894e7c188d5fefb1c940ede06af9882d8f550487bf86987d32d2523e47c1bdc`。
- 上一轮评审记录已找到：`docs/11_design_v1_review.md`原样移动至[docs/reviews/design_v1_review_claude_code.md](reviews/design_v1_review_claude_code.md)；69,236 B，移动前后SHA-256均为`df909afc7e4c30b8d495c280950a81abe24554f0b4766ca20ad969bbfde59392`。移动验证原文在`temp/design_v2_intake_20261030/moves_verified.json`。
- 已登记两项常规授权，今后不再逐次申请：同一次QB构建的临时perf及缺失库按任务5c流程在/opt/usr任务专用目录运行，三个环境变量仅指向该目录，结束删除并核对df/mounts；实验可修改/proc/sys和/sys可写参数，记录原值、结束恢复并回读、写入报告，同板参数实验串行。详见[RULES板上常规授权](RULES.md#板上常规授权2026-10-30pm裁决)。本次补充授权见下文；不用sudo、不碰其他任务进程。
- 2026-10-30授权补充已写入RULES：zram运行时重配按参数实验记录原算法/disksize/swap状态并恢复回读；实验可通过sdb重启，记录原因/编号，重连超时10分钟停止、不补救；仅为安装开机配网服务允许一次remount读写，只写登记的unit/脚本并恢复只读，镜像刷新后准备仍由用户执行；只替换内核映像/设备树/模块分区、用户态不变，首次替换须只读调研并经PM审核方案，每次备份校验、替换后核对版本/配置，启动失败且无法自动回退时交用户处理。boot cmdline仍不在常规授权内。
- 串口分工（PM提供）：开发机无串口，开机时间的串口分段由用户在内网机器采集，不属于本仓库板上操作。
- 任务6上轮因verify工具缺失停止的历史已保留；2026-11-02 r2恢复并完成调研与安装，当前结果见本文件开头。

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

- 板上操作按上述常规授权及本次补充的各项前提执行；首次内核替换方案已由PM 2026-11-02裁定，原文见11；具体执行步骤与后续性能实验仍由PM下发。任务5c硬件能力测试不是产品工作负载基准。
- -b不支持已由实测确认；若后续设计需要分支样本，采样方案需另行设计。perf build-options的auxtrace=on、libopencsd=OFF也不能独立证明CoreSight可用；本次不扩展测试。
- BPF插件历史load/attach尝试及实际失败原因仍无法判断，缺少相关日志。是否受控触发、插件产品需求/BTF取舍由PM决定，未启动服务或手动加载BPF。
- QB开始时间按UTC理解是PM接受的推断，未独立证明页面时区，不再作为来源停止条件。
- 设计当前版本为v4，待外部评审；v1–v3原样保留为历史记录，其历史“待闭合/未实测”描述保留为PM原文；当前结果以09及本状态为准。

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

本轮提交任务7 r4：11追加r6、RULES第4项重连流程、STATUS及evidence/task7/r4。普通推送GitHub main，作者/提交者Hao Lin <hao.lin@samsung.com>；不开PR、不force push、不推Gerrit。三次开机验收通过，最终owner已恢复。历史r3停止提交89919c3及更早证据保持原样；最终SHA见回复。
