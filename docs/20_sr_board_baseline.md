# 任务19：SR镜像验收与板上基线

## 范围与当前状态

本轮按PM授权先核对RPi4身份与镜像，再恢复配网、设置total_mem并演练独立版本内核和回退。仅用SDB；宿主不sudo、不处理密码、不发信号。重启仅用板上无参数reboot，本轮重连截止为5分钟，覆盖历史10分钟规则。**镜像验收、配网、total_mem及定时采样已完成。任务10切换/回退演练已执行：base01能启动，但模块/服务验收未通过；已完整回退并核验原SR状态。** 板子最终保持原SR内核、total_mem=1600、网络/resourced运行，SDB已恢复owner。

开场读取RULES、STATUS、18、19、11中r3/r6及PM审核结论、12与14的部署产物说明、现有配网脚本。未找到单独任务10演练文档，temp/task10亦不存在；PM随后确认无单独任务10文档，明确按11批准方案和14产物执行；后续结果见第7节。

## 1. 镜像身份与包清单

三项身份通过：armv7l、6.12.80-arm-rpi4-v7l、Tizen11.0/Unified。BUILD_ID为tizen-unified-toolchain_20261104.160709，内核Clang/LLD22.1.8，构建时间2026-11-04 17:05:36 UTC，对应QB1218764（SR）。SDB起始为owner，身份通过后才root on。

默认rpm数据库共1232包；两镜像官方boot+headed并集均1275包，其NVR/arch列表相同，仅来源SHA不同，所以不能靠rpm -qa的版本表区分两者。逐条对照均为新增0、缺43；只对headed则新增0、缺3：coregl-0.4.0-0.armv7l、crossgen2-mic-10.0.10-0.noarch、patchelf-0.16.1-1.13.armv7l。完整差异见evidence/task19/package_comparison.json。

官方headed kickstart的364–365行明确在制镜后处理移除patchelf和crossgen2-mic；此前将coregl缺失联系到用户一次性准备的推测已在任务22撤回：用户确认未手动卸载。任务22直接检查两份官方headed镜像，均有coregl实际库和RPM记录；缺失发生在镜像产出之后，但现有板上日志与操作记录仍不能确定删除者/时间，详见[22](22_base01_coregl_diagnosis.md)。boot清单包含独立boot/modules/HAL载荷，官方boot kickstart为HAL建立独立rpmdb；默认rpm -qa不能替代全分区安装清单。来源摘录见package_list_scope_sources.txt。未把包清单差异隐藏成完全一致。

## 2. 关键产物交叉核对

|项目|板上结果|判断|
|---|---|---|
|boot_a zImage SHA256|d5345f13eada3a3aab8b2fca9f511c608469f708d83a6a2445882e68241cc9af|与SR RPM逐字一致|
|resourced主程序SHA256|67a5bee5c9fe0f0eb266875c018089283f9291b6b2516691d6aa96837127d556|与SR RPM一致|
|resourced五包VCS|94d346c306233803661e8eab8557596549d82be4|修复版|
|dm-bow/extcon-usb-fixed/inform-reboot/kdbus/logger|5个文件SHA与SR对应RPM相同，vermagic全符|通过|
|上述5模块CRC|277项，0差异|与任务17记录一致|

模块从板上只读pull到temp/task19/modules，使用任务9平台root内modinfo/modprobe经bwrap+qemu-arm解析；未加载或替换模块。详见module_sample.json及平台原始输出。boot_a确认/dev/mmcblk0p1、vfat，首次仅ro挂载到/opt/usr/lko_task19/boot，读取后已卸载。

**判定：SR QB1218764来源，带上述安装包差异；不是未经任何准备的完整原样安装集。** BUILD_ID、内核构建串、zImage及5模块内容交叉支持，满足进入第二部分的镜像身份条件。

## 3. 配网恢复与两次重启

重新安装既有脚本与unit，未手动运行脚本，未start/restart服务。文件哈希仍为8fecc6d0b5383b04de53bec6ac0b3e795e93c140b8d8ae0c315f6b75855a6608、bb5be5756fb97065c4adb4b3df3c5041d4f6f148498ff4a9364d8e58799c5d78；模式0755/0644，标签均与ip/connman.service一致为下划线。enable链接为/etc/systemd/system/multi-user.target.wants/lko-net-setup.service，目标/etc/systemd/system/lko-net-setup.service。验证loaded、LoadError为空、enabled、inactive/dead。

宿主校验器初次误要求LoadError属性不存在，实际输出为空值，修正判据后通过；没有因此重装或重复enable。journal匹配返回1表示该时窗未匹配日志，非服务启动失败。

根分区开始为rw。安装后执行sync与remount,ro返回32（mount point is busy）；未关闭文件、杀进程或反复重试。按已授权的配网验证流程执行一次普通reboot，并在恢复连接后核对根分区状态；两次重启均在5分钟内重连且三重身份断言通过，根分区恢复ro。旧失败原始输出保留。

|重启|用途|重连秒数|服务耗时秒|服务退出|网络/身份/根ro|
|---|---|---:|---:|---|---|
|1|配网首次验证|62.338|4.409943|success / 0|通过|
|2|total_mem生效验证|56.983|4.587014|success / 0|通过|

每次只在板上执行无参数reboot，disconnect/connect串行轮询；没有kill-server或向宿主进程发信号。boot_id均变化、日志含network setup complete。详见[reboot_results.json](../evidence/task19/reboot_results.json)及对应reboot1/reboot2记录。

## 4. total_mem与SR基线表

在boot_a只读挂载时pull保存config.txt，确认原文无total_mem。宿主备份temp/task19/config.txt.before，SHA256为38a4959985ed44398e9656392c245b554155805808524fc04e556e31cc472925。随后仅追加换行、[all]、total_mem=1600，读写挂载时另存boot内config.txt.task19-before；新SHA为7ecdb662716cab1532da77ff755912775284eb3aab5e3c89fd571dba854f7d07。sync、核对哈希后卸载，再正常reboot。没有改cmdline、DT/overlays或内核映像。详见[total_mem_change.json](../evidence/task19/total_mem_change.json)。

回退方法：确认对应boot_a和备份哈希后，只在获准的读写窗口把完整旧config恢复成config.txt，sync、卸载、普通reboot，再核对身份和MemTotal。本轮按要求保留total_mem=1600，未执行这个回退。

|项|本次实测/限制|证据|
|---|---|---|
|MemTotal|1,507,996 KiB；它是内核可用内存口径，不直接等于固件设置1600 MiB|27_kernel_baseline|
|配置|/proc/config.gz不存在，无法作板上直接diff；镜像zImage哈希吻合，任务17对应devel .config与base01逐字一致|configuration_limits.txt|
|force_reclaim|根memory cgroup节点存在；本次dlog有10条value=2560写入路径日志及两条tried 12800 pages摘要|force_reclaim_context.txt|
|resourced|active/running，PID401；swap插件在/proc/401/maps中存在|29_service_status、33_ksm_maps|
|回收日志边界|记录的是服务自身开机回收，代理没有写节点或触发回收；这些日志不是逐次write返回值跟踪，不能将tried页数当成功回收量|force_reclaim_context.txt|
|swap/zram|/dev/zram0已启用，算法lzo-rle，disksize=617676800 B，swap总量603196 KiB，priority0；mm_stat/io_stat留原文；bd_stat不存在|28_memory_parameters|
|KSM|/sys/kernel/mm/ksm不存在，故无运行时参数；对应SR镜像CONFIG_KSM未设置|33_ksm_maps、configuration_limits.txt|
|VM|swappiness=60，page-cluster=3，min_free_kbytes=3388，watermark_scale_factor=10，vfs_cache_pressure=100|28_memory_parameters|
|MGLRU|enabled=0x0001|28_memory_parameters|
|失败unit|当次systemctl --failed为0；display-manager处于activating并反复退出127，不会因此出现在failed列表，109秒时NRestarts=9，未停用|31_health、36_system_state|
|dmesg|regulatory.db/无线固件缺失、systemd BPF/cgroup firewall能力警告、USB gadget启动失败-19；没有本轮所采日志中的Unknown symbol/CRC错误|kernel_warning_excerpt.txt|

日志筛选排除了SDB对查询命令的回显，不能把命令中出现force_reclaim当作服务实际执行。journal仅有监听socket行；写入路径证据来自dlogutil -d。完整dlog只留temp，公开仅相关摘录、行号和原始文件哈希。

## 5. 定时快照和内核演练

60秒与600秒快照在同一次total_mem生效后的boot采集，使用/proc/uptime定时，保存free -k、完整meminfo/vmstat及开始/结束uptime。实际采样时间分别为60.18–60.21秒和600.19–600.21秒；没有用墙钟或重连耗时冒充开机时间。

base01部署归档已重新核对SHA256=583fbb45389f3b98a8498c09f4acb9a2a73a4b074439bdae6df663cbeaeeb61c，15,990,491 B，与任务9记录一致；模块目录3,976 KiB，现场模块分区仍可用14,648 KiB、8,054空闲inode，原目录4,424 KiB。尚未复制到模块分区、未切换内核；不把可用产物与容量前提当作演练通过。

|指标|60秒点|10分钟点|
|---|---:|---:|
|MemTotal（KiB）|1,507,996|1,507,996|
|MemFree（KiB）|1,258,812|1,187,792|
|MemAvailable（KiB）|1,353,328|1,365,824|
|SwapTotal（KiB）|603,196|603,196|
|SwapFree（KiB）|603,196|589,728|
|pswpin（开机累计）|0|476|
|pswpout（开机累计）|0|2,878|
|pgfault（开机累计）|340,152|2,260,543|
|pgmajfault（开机累计）|825|1,617|

完整free/meminfo/vmstat见[snapshot_60.txt](../evidence/task19/snapshot_60.txt)、[snapshot_600.txt](../evidence/task19/snapshot_600.txt)和[snapshot_summary.json](../evidence/task19/snapshot_summary.json)。不是受控性能结论；display-manager持续重试仍构成噪声。最后642秒采样该服务NRestarts=61、ExecMainStatus=127，而systemctl --failed仍为0，没有把后者解释为系统无异常。

### 先前等待确认的历史记录（已由第7节覆盖）

工作区docs、scripts、evidence的文件名/正文检索未找到任务10执行文档，temp/task10不存在；STATUS仍写任务10待执行。当前GitHub main与本地开场SHA b53678c1一致，没有远端新版文档可取。现有11中PM审核方案与14的已核验部署包均已读取，容量前提也满足；已向PM请求任务10文档路径，或确认按11/14执行。待回复前不自行把“按任务10文档”替换为另拟流程。没有复制新版本模块目录、改zImage文件名或启动base01，因此启动与回退均标“未执行”，不标通过。

## 6. 第一次收尾状态（后续演练/最终状态见第7节）

- 内核仍为6.12.80-arm-rpi4-v7l；最终boot_id=7c924a80-5176-4301-9c17-4c4540933d1f。原zImage哈希再次与SR RPM相符；config与备份再次核对后已卸载boot_a。
- total_mem=1600保留，MemTotal=1,507,996 KiB。lko-net-setup为active/exited、Result=success、退出0；resourced为active/running、退出0；MAC/IP与指定值一致，SDB可连。
- 本次持久写入：/usr/local/sbin/lko-net-setup.sh、/etc/systemd/system/lko-net-setup.service、/etc/systemd/system/multi-user.target.wants/lko-net-setup.service，以及boot_a上的config.txt与config.txt.task19-before。没有改启动参数cmdline、设备树、模块分区内容或原内核。脚本/unit与config的SHA见前文；enable链接目标亦已回读。
- 临时目录/opt/usr/lko_task19整体删除，ls退出2、owner回读确认不存在。/opt/usr可用空间回到开始的115,421,468 KiB；模块分区始终ro、可用14,648 KiB未变。根分区开始rw，重启后及最终为ro；不声称整份mounts与开始一致。
- root off后回读uid=5001(owner)。[最终状态](../evidence/task19/40_final_state.txt)、[清理](../evidence/task19/41_cleanup.txt)、[owner](../evidence/task19/43_owner.txt)。没有运行GBS、宿主sudo、处理密码、发信号或操作其他任务的进程。

宿主原始材料保留temp/task19，公开证据每文件小于1MB、去ANSI；完整dlog只留本地，引用摘录保留源行号。构建机标识与cmdline设备序列字段在公开文本脱敏。证据导出首轮发现拼接的重连文本仍含ANSI，改为对全部发布文本统一清理后重新检查通过；原始日志不变。证据索引：[README](../evidence/task19/README.md)。

## 7. 任务10演练，依据docs/11 + docs/14

PM确认没有单独任务10文档，允许按11中2026-11-02审核方案和14的合格产物执行；要求列全改动、逐文件备份/哈希，遇到未覆盖情况停止，不临场修复，必须完整回退。此确认覆盖第5节先前等待。先重新通过三重身份断言，root on；新版本目录与zImage.orig均不存在，模块分区可用14,648 KiB/8,054 inode。

### 改动、备份与写入

完整预先清单：[kernel_exercise_change_plan.json](../evidence/task19/kernel_exercise_change_plan.json)。现有zImage、DTB和当前total_mem配置已pull至`temp/task19/kernel_exercise_backup/`，哈希与板上相同。对原模块目录及两个共享配置作75个文件哈希基线，对boot全部414个文件作哈希基线；DTB/overlays不改。新目录所有文件原先不存在，无旧文件可备份，清单逐项注明。

- 原zImage改名zImage.orig；base01放到zImage。base01 SHA为`4bb488d8d7768bde6f9b53b53342d9bde0d996cb37284a6d5547855d20e8c5f1`。
- 新模块仅写`/usr/lib/modules/6.12.80-arm-rpi4-v7l-lko-base01/`，73个普通文件和1个build链接；原目录/共享配置不改、不安装RPM、不整块写分区。74个部署载荷（含zImage）在暂存目录全部通过SHA校验，模块落盘再核对通过。模块分区仅复制期间rw，随后sync恢复ro。
- 不改设备树、overlays、cmdline或本轮已设的config。记录见48–55编号证据；部署归档身份沿用14和任务9验收。

### 切换结果及停止原因

第三次无参数reboot后62.334秒内连上，boot_id变为`2abc9ac9-544f-4b02-b0a9-761fbe859dd0`，uname为`6.12.80-arm-rpi4-v7l-lko-base01`。网络服务success/0（4.374383秒）、MAC/IP正确；resourced active/running、主二进制哈希未变，swap仍正常。

**未通过完整验收：** 原来10个已加载模块中proc_tsm未加载（其余9个vermagic均为新release），stability-monitor.service失败、ExecMainStatus=255；系统模块加载unit本身success/0。未发现Unknown symbol、disagrees about version或invalid module format。只读检查发现新proc-tsm.ko标签为User::Shell、原件为`_`；这是可能原因（推测），当前日志不足以证明因果。未修改标签、手动加载模块、重启服务或再次尝试部署；按要求停止实验，执行既有回退。

证据：[56运行快照](../evidence/task19/56_base01_runtime.txt)、[57模块诊断](../evidence/task19/57_base01_module_diagnostic.txt)、[58只读诊断](../evidence/task19/58_base01_failure_readonly.txt)。模块运行异常/标签适配超出现有部署记录，需要PM决定下一轮检查与方案；不把“内核可启动”写成“系统验收通过”。

### 完整回退验收

已先核对zImage.orig原SR哈希，再把它改回zImage，sync卸载，第四次无参数reboot。57.026秒内恢复，boot_id为`4e5c71ff-0cf8-4e7e-9f61-16602d3c3b57`。

|回退项|结果|
|---|---|
|uname / version|恢复6.12.80-arm-rpi4-v7l及SR构建串|
|zImage / DTB|分别恢复/保持d5345f13… / a0561668…，全文SHA见60记录|
|boot全部文件|414个文件名及SHA与演练前逐项相同；zImage.orig已改回，不遗留实验映像|
|模块目录|原版本75个普通文件（含共享配置）SHA全相同；新版本目录已删除；原build链接未改；df回到可用14,648 KiB，原目录4,424 KiB|
|模块运行|原10模块全部加载，含proc_tsm；10个vermagic全符；无符号CRC/格式错误|
|服务|stability-monitor恢复active/running、success/0；resourced active/running、success/0，主程序SHA相同；failed单位0|
|网络|MAC/IP/路由恢复；lko-net-setup success/0、active/exited，耗时3.384852秒；SDB自动连上|
|最终基线|原SR内核+total_mem=1600，MemTotal1,507,996 KiB；zram lzo-rle/617,676,800 B；根和模块分区ro|
|清理|/opt/usr/lko_task19和新模块目录均已删除；root off后uid5001(owner)回读通过|

第四次开机tag journal已无保留记录，复用的宿主检查器因未找到network setup complete文本退出1；实际服务属性success/0、MAC/IP/SDB及独立回退核验均通过。没有伪造缺失日志。清理脚本第一次在set -e下执行预期失败的ls（目录不存在）提前退出，随后的独立不存在断言、df和owner回读完成收尾。两处宿主判据/日志限制与真正的base01服务异常分开记录。

/opt/usr最终可用115,421,428 KiB，比演练前少40 KiB；任务目录确认不存在，运行中的系统可自行写日志，不能把全分区变化归因于本任务或声称df完全相同。模块分区块数和inode完整恢复。没有发送信号、宿主sudo、改设备树、改用户态或遗留挂载。

结论：**任务10演练流程执行完毕；base01部署验收未通过，回退验收通过。** 后续不得把此作为base01可直接部署的证明。详见[kernel_exercise_final.json](../evidence/task19/kernel_exercise_final.json)、60–68编号证据及reboot3/4记录。
