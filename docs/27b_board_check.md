# 任务27后半：板上核对与预备Idle基线

2026-11-09。**网络持久化单次验证及三轮重启采集完成；身份、显示、评估服务运行与受控回收检查通过。** Used三轮均值 **495.99MiB**、极差 **15.49MiB**。这是观察波动的预备基线，不是正式测量；内部服务名、unit和按进程数据仅在本地`vendor_local/task27b/`。

## 身份、显示与服务结论

| 项目 | 结果 |
| --- | --- |
| 身份 | 每次root/写入和重启前后断言armv7l、6.12.80-arm-rpi4-v7l、Tizen；TZ_BUILD_ID=tizen-unified-toolchain_20261106.063932。 |
| 内存设置 | MemTotal=3,976,468KiB；boot配置没有total_mem，本轮未设置1600、未修改boot。 |
| 图形依赖 | coregl0.4.0-0、HAL mesa24.3.4-0安装；EGL/GLES/COREGL链接与目标存在，显示程序无缺库。 |
| 显示 | **正常显示**：用户目视确认开机后正常Home；三轮display-manager均active/running、NRestarts=0、退出0。初采两个HDMI节点均disconnected；最终回读HDMI-A-1已connected、HDMI-A-2 disconnected，与Home正常显示一致；未修改显示配置。 |
| 评估服务 | 三轮初始化服务active/exited、守护服务active/running、0重启、退出0。 |
| swap管理分离 | 三个更高优先级配置路径均不存在；有效配置只有一处SwapEnable=no，运行进程maps无swap插件，优先级核验已补齐。 |
| failed units | 三轮均0。 |
| 收尾 | 根分区与HAL均ro,relatime；任务临时目录不存在；SDB已恢复owner并回读。 |

证据：本地`logs/resume2_identity_owner.txt`、`config_priority_closed.txt`、`idle_r2_[1-3]_snapshot.raw.txt`、`final_completed_board.txt`、`final_completed_owner.txt`及`commands.jsonl`。按进程详情不进入公开仓库。

## 受控回收（前一阶段已完成）

最低MemAvailable385.26MiB，目标区间保持60秒，总142秒/143样本；pswpout增加15,084页（58.92MiB），zram原始数据增加55.68MiB、实际内存增加31.70MiB；OOM增量0，本服务open/ioctl权限失败0。四个测试worker及/tmp脚本已删除。服务回收调用与系统换出增长同时观测到，确认实际触发；未隔离内核后台回收，不把全部系统增量独占归因于服务。当前运行身份组合对此路径够用，不推导最小权限。

逐秒证据为`pressure_samples.json`、`pressure_summary.json`、相关journal/dlog及清理日志，均仅本地保存。此次续跑未重复压力测试。

## 板上本地改动：网络持久化

此配置**不属于QB镜像**。后续SR基线须安装同一文件并核对SHA、完成同样的自动恢复验证，才能保持本地准备一致。

先把ConnMan目录及相关网络配置备份到/tmp再拉回；备份`network_resume/network-before.tar`为75,264B，SHA-256 `49755e38cc5462405fb804d03cbc545bb11a52bd40dd6068fb4cf8c81d171361`，板端/宿主核对一致。完整成员、原权限/标签和配置只留本地。

实际持久写入仅两项：

| 路径 | 内容/元数据 |
| --- | --- |
| /etc/systemd/system/ethernet-mac-setup.service | root:root、0644、SMACK `_`、432B，SHA-256 `f319a1842879a317e33006ed1ce8ae4d109c54bf09fecadb96e28c72be80b14c` |
| /etc/systemd/system/multi-user.target.wants/ethernet-mac-setup.service | enable符号链接，指向上一行绝对路径；root:root、SMACK System::Privileged；以readlink核验链接目标，解引用SHA同unit |

unit全文：

```ini
[Unit]
Description=Set Ethernet address before connection management
Requires=sys-subsystem-net-devices-eth0.device
After=sys-subsystem-net-devices-eth0.device
Before=connman.service
Wants=connman.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip link set eth0 down
ExecStart=/usr/sbin/ip link set eth0 address 2c:cf:67:a0:72:b5
ExecStart=/usr/sbin/ip link set eth0 up

[Install]
WantedBy=multi-user.target
```

沿用原配网脚本的ip down→MAC→up序列；按本轮授权改为Before=connman.service，仅设置MAC，现有ConnMan配置提供IP/网关/DNS，没有重复写静态配置。网卡device依赖已确认active。无新脚本、无常驻进程，不改/usr/lib、不装卸包。安装前根分区已rw，故**未remount**；装完仍rw，第一次验证重启后按镜像默认回到ro。仅daemon-reload/enable，未手动start断网。

单次验证：reboot发出后56.793秒自动连回，首次成功uptime=24.17秒，满足3分钟上限；身份、MAC、IP正确。oneshot active/exited、success/0，MainPID/ControlPID=0且cgroup不存在，没有常驻进程；退出15.490956秒，ConnMan开始15.585124秒，顺序正确。其后每轮也都自动恢复；未使用宿主SDB服务重启或人工网络干预。

撤销步骤（未执行）：连接并断言身份后记录根分区状态，必要时remount rw；执行`systemctl disable ethernet-mac-setup.service`（不带--now），仅删除以上unit及残存enable链接，daemon-reload、确认路径不存在，恢复根分区原状态。已有ConnMan配置不动，不自动重启；撤销后下次重启须预先安排网络恢复。

## 三轮Idle结果

每轮在首次SDB连接及身份核对后，不再操作板子，到**网络恢复起满600秒**才采集；验证重启不计入三轮。首次成功时uptime是“开机到可达”的观测上界，轮询有时间分辨率限制，不等同链路实际up的精确时刻。

| 轮次 | reboot发出→首次SDB成功(s) | 首次成功时uptime(s) | 静置(s) | 快照uptime起–止(s) |
| --- | ---: | ---: | ---: | --- |
| 1 | 60.819 | 23.96 | 600.000 | 624.31–628.29 |
| 2 | 56.747 | 23.96 | 600.000 | 624.20–628.32 |
| 3 | 56.664 | 24.10 | 600.000 | 624.29–628.32 |

| 指标（KiB） | 第1轮 | 第2轮 | 第3轮 | 均值 | 极差 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Used（Total−Available） | 501,692 | 504,440 | 517,556 | 507,896 | 15,864 |
| MemTotal | 3,976,468 | 3,976,468 | 3,976,468 | 3,976,468 | 0 |
| MemAvailable | 3,474,776 | 3,472,028 | 3,458,912 | 3,468,572 | 15,864 |
| MemFree | 3,310,176 | 3,310,236 | 3,297,156 | 3,305,856 | 13,080 |
| Cached | 368,676 | 365,552 | 384,664 | 372,964 | 19,112 |
| Shmem | 187,536 | 187,072 | 206,012 | 193,540 | 18,940 |
| 用户态PSS合计 | 200,364 | 199,464 | 199,379 | 199,735.67 | 985 |
| Pss_Anon | 121,557 | 121,007 | 120,787 | 121,117 | 770 |
| Pss_File | 77,990 | 77,636 | 77,772 | 77,799.33 | 354 |
| Pss_Shmem | 807 | 807 | 807 | 807 | 0 |
| Slab | 51,700 | 51,828 | 51,524 | 51,684 | 304 |
| SReclaimable | 13,516 | 13,520 | 13,516 | 13,517.33 | 4 |
| SUnreclaim | 38,184 | 38,308 | 38,008 | 38,166.67 | 300 |
| PageTables | 5,064 | 5,192 | 5,128 | 5,128 | 128 |
| KernelStack | 3,264 | 3,264 | 3,256 | 3,261.33 | 8 |
| zram实际占用 | 684 | 684 | 684 | 684 | 0 |
| V3D BO统计 | 248,308 | 247,288 | 245,308 | 246,968 | 3,000 |
| 显示设备命名GEM对象 | 53,696 | 53,696 | 52,944 | 53,445.33 | 752 |
| CmaTotal | 327,680 | 327,680 | 327,680 | 327,680 | 0 |
| CmaFree | 263,080 | 263,060 | 263,828 | 263,322.67 | 768 |
| SwapTotal | 2,584,700 | 2,584,700 | 2,584,700 | 2,584,700 | 0 |
| SwapFree | 2,583,932 | 2,583,932 | 2,583,932 | 2,583,932 | 0 |

PSS逐个读取全部枚举进程的smaps_rollup：第1轮51个可读用户进程、146个无用户地址空间的内核线程、0个其他不可读项, 第2轮49个可读用户进程、146个无用户地址空间的内核线程、0个其他不可读项, 第3轮50个可读用户进程、146个无用户地址空间的内核线程、0个其他不可读项。内核线程以/proc/PID/stat的PF_KTHREAD（include/linux/sched.h:1691）区分，不把无用户地址空间当PSS读权限故障；逐进程表仅本地。PSS及其分项按KiB取整，求和可能存在少量舍入差。

GPU统计来自规范路径`/sys/kernel/debug/dri/fec00000.v3d/bo_stats`和`/sys/kernel/debug/dri/gpu/gem_names`；0/1/128是别名，不重复加总。V3D量是驱动BO页数统计（drivers/gpu/drm/v3d/v3d_debugfs.c:212–223），显示GEM量只涵盖命名对象。跨设备导入和PSS仍可能重叠，二者不能相加当物理GPU总量。PSS、GPU、Slab、页表、内核栈、zram、CMA是不同视图，也不能简单相加闭合Used；Cached和Shmem等有包含关系。

## memps口径与数值核验

板上RPM为memps0.2.0-0.armv7l；对应Tizen项目`platform/core/system/memps`提交`dd28371a426bf75c7cb307acc571fbcc1aa3331f`。以下均为该提交memps.c行号，完整源码和编号摘录仅本地留底。

| 汇总行 | 公式/来源 | 行号 |
| --- | --- | --- |
| Total RAM | MemTotal | 676–688、766 |
| Used(Mem+Reclaimable) | MemTotal−MemFree | 769–772 |
| Used(Mem)、Used(Mem+Swap) | **两行都是MemTotal−MemAvailable，后者也未加SwapUsed**；Available=0时回退Free+Cached | 734–778 |
| Used(Swap) | max(SwapTotal−SwapFree,0) | 744–781 |
| Used(Zram block device) | mm_stat第三字段mem_used_total，bytes转KiB/MiB；打不开时回退旧节点 | 509–538、759–784 |
| Used Ratio | 正常容量下整数used/(MemTotal/100) | 739–742、786 |
| Free / Available | MemFree / MemAvailable（上述回退） | 788–793 |
| 进程CODE/DATA | Shared+Private的Clean/Dirty总和，共享项可能重复 | 988–1001、1333–1347、1378–1379 |
| 进程PSS/PEAK/SWAP | 归类后的映射Pss；VmHWM与DRM映射调整；映射Swap求和 | 967–1018、1333–1347 |
| 3D | GPU helper或设备映射统计，另有驱动gpu_gem_info分支 | 926–972、1026–1033 |
| GEM(PSS/RSS) | gem_info按TGID累计size/hcount、size | 230–371、1020–1024 |
| GEM(ALLOC) | gem_names合法对象size相加；节点缺失返回0 | 452–506、1351 |
| 进程TOTAL(KB) | **PSS+3D+GEM(ALLOC)**，不加SWAP，不等于系统Used | 1369–1370、1383–1384 |
| TMPFS | statfs：blocks×4、(blocks−bfree)×4、bfree×4，写死4KiB块 | 797–828 |
| cgroup Mem/Mem+Swap/Swap | usage_in_bytes、memsw.usage_in_bytes、非负差；根组/子组不可相加 | 582–654 |

**系统Used不额外相加GEM/3D**，但GPU使用的系统RAM可以经MemAvailable反映；不能说GPU必然被排除。进程TOTAL会显式相加图形指标，映射分类不等于物理页去重，不能保证与原始smaps_rollup PSS无重叠；缺图形统计节点时显示0也不代表实际零占用。Slab、页表、内核栈、PSS、GPU、zram和CMA属于不同视图，不能简单相加闭合Used。

`-v`走smaps，`-q`优先smaps_rollup；跳过memps自身与不可读/已退出进程（1270–1291、1569–1581）。三轮均已保存memps全文及前后meminfo/uptime，实际数值核验见下表。

以下为同一次采集窗口的KiB数值；memps读取前后都记录meminfo，并核对其自己打印的Total/Available/Free。三轮Used=Total−Available、Mem+Swap行与Mem行相同、Mem+Reclaimable=Total−Free均通过。

| 轮次 | 采集起点Used | memps前Used | memps报告Used | memps后Used | 算术核验 |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 501,692 | 536,260 | 535,500 | 535,352 | 通过 |
| 2 | 504,440 | 552,968 | 552,032 | 552,432 | 通过 |
| 3 | 517,556 | 535,968 | 535,760 | 535,760 | 通过 |

采集起点与后续memps不是同一原子时刻；期间逐进程/GPU读取及系统活动可能改变内存，保留前后读数漂移，不将差额当作公式错误或GPU额外加项。完整memps输出、源码编号摘录和比较JSON见本地。

## 历史停止与执行限制

18:21:54首次尝试重启、18:26:54达到五分钟无SDB上限后停止；随后再次连接失败也未越权安装。用户恢复一次网络并明确授权持久化后，本轮才继续。旧失败不混入三轮，也不删除原始日志。初次采集的引号/分页错误及本轮可选systemd-analyze缺失的只读预检早退均保留，未把它们当板上服务故障。

宿主重任务经CPUQuota400%/MemoryMax8G、nice10、ionice-c3限额；未sudo、输入密码或向宿主进程发信号。除授权网络unit外，未改镜像文件、显示、内核参数或包；未设置total_mem。原始材料、按进程PSS、网络备份和审读包仅本地；公开只提交本页及STATUS。
