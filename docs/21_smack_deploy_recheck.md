# 任务21：SMACK部署前提复核与显示服务只读排查

## 结论与停止点

**在第1步停止，未进入标签修改和base01演练。** 当前规则明确存在`System User::Shell rwxat`，包含读权限，与“stability-monitor的System主体无法读取User::Shell模块文件”的前提矛盾。按PM停止条件，没有修改docs/11的部署方法、标签或模块，没有部署/重启，也没有需要执行的回退。本次不能把标签修正写成已验证解决方案。

任务20内部审读材料已在本地打包并逐成员核验；产品代码、补丁、包内细节和审读包均未进入GitHub。

## 1. 身份、当前开机和原目录标签

三重身份通过：armv7l、6.12.80-arm-rpi4-v7l、Tizen11.0/Unified，BUILD_ID对应SR QB1218764。当前boot_id为`efb329ce-c985-4835-8124-e7a98c8b4aeb`，与任务19结束时的boot_id不同；本任务没有重启，不把当前规则或日志当作任务19失败开机时的证据。[身份](../evidence/task21/02_identity.txt)

`chsmack -r`只读列出原版本目录全部123个对象：73个普通文件、49个目录、1个build符号链接。全部仅有`access="_"`，没有其他access值或exec、mmap、transmute标签；未跟随build链接到构建机路径。完整清单及分类：[标签原文](../evidence/task21/06_original_labels.txt)、[逐项清单](../evidence/task21/original_label_manifest.json)、[统计](../evidence/task21/original_label_summary.json)。

## 2. proc_tsm加载路径与参数

- stability-monitor.service明确`User=stability_monitor`、`Group=stability_monitor`、`SmackProcessLabel=System`、`ExecStart=/usr/sbin/stability-monitor`，配置能力包含cap_sys_module。当前PID493、UID204，`/proc/493/attr/current`为System，服务active/running、退出0。[unit和共享配置](../evidence/task21/05_load_path.txt)、[进程/依赖](../evidence/task21/07_stability_dependencies.txt)
- ldd解析到libkmod.so.2；平台readelf确认程序导入`kmod_new`、`kmod_module_new_from_name`、`kmod_module_probe_insert_module`等。strings含`src/raw_data_providers/proc_tsm.c`、`Unable to find module proc_tsm`、`Unable to insert %s: %m`。这支持该服务通过libkmod加载proc_tsm，非依赖modules-load.d；本轮没有主动加载或跟踪实际加载syscall。[符号](../evidence/task21/stability-monitor_symbols_excerpt.txt)、[字符串](../evidence/task21/stability-monitor_strings_excerpt.txt)
- libkmod导入init_module，提供probe_insert/insert接口；未发现finit_module动态符号名不能证明内部不用直接syscall。[libkmod符号](../evidence/task21/libkmod_symbols_excerpt.txt)
- modules-load.d的现有条目为dm-bow、extcon-usb-fixed、inform-reboot、logger、kdbus，没有proc-tsm。当前共10个已加载模块，含proc_tsm；其余模块可能由依赖或设备触发加载，不能把“其余9个都直接写在modules-load.d”当作事实。
- modprobe.d含`options proc-tsm blacklist=System::TEF`。公开源码`ext/linux-tizen-modules-source/kernel/proc-tsm.c:49–52`将blacklist声明为模块字符串数组参数；`:159–174`在遍历进程时匹配安全标签并跳过相应进程。这是采样过滤参数，不是禁止加载proc-tsm的modprobe blacklist指令。[源码版本/行号证据](../evidence/task21/proc_tsm_parameter_source.txt)

按服务日志标签筛选dlog得到69行，排除SDB查询命令回显；本次可见正常进程监控/样本记录，不能重建任务19失败时的加载错误。[stability日志](../evidence/task21/dlog_stability_excerpt.txt)，完整原始dlog留temp，哈希与原始行号已记录。

## 3. SMACK前提不成立，禁止越过停止条件

`/sys/fs/smackfs/load2`本次相关原文如下（前两个字段依次为主体和客体）：

```text
System User::Shell rwxat
System _ rwxa
User::Shell System wx
```

前两条都包含`r`。反向的`User::Shell System wx`不能反过来解释为System对User::Shell没有读权限。[原始行号/命令/退出码](../evidence/task21/smack_rules_relevant.txt)

原文件标签确实是`_`，前轮新文件确实曾为User::Shell，但**标签不同不等于已经证明本次所述读权限拒绝**。当前全局规则与PM假设矛盾，故执行第1步停止条件。此结论不排除历史开机规则差异、进程局部限制或其他访问/模块加载问题；本轮未对这些另做试探或修复，也未把root身份等同于无条件绕过SMACK。

|后续项|本轮结果|
|---|---|
|docs/11标签附录、部署方法修改|未执行，待PM处理矛盾证据|
|复制新模块、改SMACK、写boot、base01重启|未执行|
|base01模块/服务验收、完整回退|未执行，不标为通过或失败|
|接屏后重启及回退后的display-manager对照|未执行，不能绕过部署停止条件另做重启|

## 4. display-manager退出127：当前已闭合到缺失库

用户说明显示器在本次开机后接入；本次只读读取当前状态，没有停用、屏蔽、启停或修复服务，也没有安装coregl。

|采样|uptime秒|ActiveState / SubState|NRestarts|ExecMainStatus|
|---|---:|---|---:|---:|
|第一次|629.38|activating / auto-restart|59|127|
|第二次|706.58|activating / auto-restart|67|127|

77.20秒中增加8次，journal各次间隔约10.25秒，与unit的RestartSec=10相符。两次HDMI-A-1、HDMI-A-2均为`disconnected`，Writeback-1为`unknown`。不能把用户接线说明替代DRM的检测结果，当前没有取得“有效连接显示器”的对照状态。[第一次](../evidence/task21/10_display_current.txt)、[第二次](../evidence/task21/15_display_later.txt)

实际ExecStart是ELF`/usr/bin/enlightenment`，ExecStartPre为已有keymap_update.sh；未手动运行任一入口。程序的DT_NEEDED直接包含libEGL.so.1和libGLESv2.so.2，ldd两项均`not found`，其它列出的依赖有解析路径。`rpm -q coregl`报告未安装，对应库路径不存在。[unit/依赖/脚本](../evidence/task21/09_display_details.txt)、[平台readelf](../evidence/task21/enlightenment_dynamic_excerpt.txt)

额外只读依赖检查`/lib/ld-linux.so.3 --list /usr/bin/enlightenment`没有启动应用本体，返回127，原文：

```text
/usr/bin/enlightenment: error while loading shared libraries: libEGL.so.1: cannot open shared object file: No such file or directory
```

[命令及远端退出127](../evidence/task21/14_display_loader.txt)。SR QB1218764的已下载primary元数据确认coregl-0.4.0-0.armv7l提供libEGL.so.1、libGLESv2.so.2及libCOREGL.so.4，文件来源与VCS记录见[提供者证据](../evidence/task21/coregl_provider.json)。没有重新下载、安装或修改包。

journal显示主程序退出127，dlog的相关标签主要重复“Enlightenment is not ready”，并非直接的缺库诊断。缺库结论来自ELF依赖、ldd、loader检查和包提供者交叉核对，不伪称dlog已打印该错误。[dlog摘录](../evidence/task21/dlog_display_excerpt.txt)

**判定：本次127循环的直接阻塞是coregl所提供的库缺失，在进入显示器初始化前已失败；不是仅靠未接显示器能解释的错误。** HDMI仍为disconnected，但本轮未证明它是否还会引起另一种独立启动失败，不能下“两者都有”的确定结论。由于第1步停止，没有取得接屏启动、base01和最终回退三状态对照。未改display-manager、coregl或连接器配置。

## 5. 收尾与证据范围

起止均原SR内核、同一boot_id，MemTotal为1,507,996 KiB；未触碰既有total_mem设置。当前10个模块均已加载，stability-monitor、resourced正常，配网服务success/0。根分区和模块分区始终ro；前后挂载列表相同。/opt/usr可用115,421,468 KiB、模块分区14,648 KiB，前后一致。

没有创建板上任务目录、写文件/标签、remount、重启、发送信号或使用宿主sudo。只读pull的三个ELF只留宿主temp/task21，平台分析使用任务9 GBS根的工具经bwrap+qemu-arm。结束sdb root off，回读uid5001(owner)；/opt/usr/lko_task21不存在。[最终状态](../evidence/task21/19_final_state.txt)、[owner](../evidence/task21/21_owner.txt)、[汇总](../evidence/task21/summary.json)

宿主首个身份判据错误要求输出前有换行，实际三项身份完整正确；据原始完整行修正判据后才root on，未把矛盾身份放行。各命令、退出码、原始输出哈希见[commands.jsonl](../evidence/task21/commands.jsonl)、[raw_manifest.json](../evidence/task21/raw_manifest.json)。复合命令尾部退出码不代表其中每个诊断命令均返回0；缺包/缺路径和loader127分别按输出如实记录。公开证据均为小于1MB的脱ANSI文本，仅含本轮RPi4/Tizen内容。
