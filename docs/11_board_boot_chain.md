# 任务6：启动链只读调研与开机自动配网服务安装

日期：2026-10-30（Asia/Shanghai）。对象：RPi4，192.168.108.26:26101，仅通过SDB。

**状态：安装预检停止，任务6未完成。** 三项身份断言通过；板上没有`systemd-analyze`，执行规定的verify命令返回127，触发PM停止条件。未安装/启用服务、未执行配网脚本、未挂载boot或remount、未重启。停止后只记录结束状态并恢复原SDB身份，不作补救。

## 停止原因与证据

最初owner身份的command-v结果受权限/PATH影响，因此按既有授权用`sdb root on`取得root，以完整系统PATH `/usr/bin:/bin:/usr/sbin:/sbin`复查。`connmanctl`、`ip`、`mount`等可用，但systemd-analyze仍不存在；随后只读搜索`/usr/bin /usr/sbin /usr/lib/systemd /bin /sbin`，无匹配（find退出0）。`systemctl --version`显示systemd244，不能据此认为分析工具也已安装。

执行（仅验证调用，服务文件尚未生成/安装）：

```text
systemd-analyze verify /etc/systemd/system/lko-net-setup.service
/bin/sh: systemd-analyze: command not found
VERIFY-EXIT=127
```

这是**缺少验证工具**，不是unit内容的语法错误。SDB传输退出0不代表其中verify成功。证据：[完整PATH复查](../evidence/task6/04_root_preflight.transport.txt)、[工具目录搜索](../evidence/task6/05_verify_tool_search.transport.txt)、[verify原文](../evidence/task6/06_verify_blocker.transport.txt)。遵守“systemd-analyze verify报错就停下，不做其他补救”，未改用其他验证器、补装RPM或推送额外工具。

## 第一部分：已获得事实与未完成项

| 项目 | 本轮事实 | 证据 |
|---|---|---|
| 身份三项 | uname-r=6.12.80-arm-rpi4-v7l；uname-m=armv7l；ID=tizen，全部通过 | [身份](../evidence/task6/01_identity_start.transport.txt) |
| 内核/镜像标识 | Clang22.1.8/LLD22.1.8；编译时间2026-10-28 12:18:25 UTC；BUILD_ID=tizen-unified-toolchain_20261028.105834_tizen-headed-armv7l | 同上 |
| 根文件系统 | /dev/mmcblk0p2，ext4，rw,relatime | [起始mounts](../evidence/task6/02_mounts_preflight.transport.txt) |
| 模块挂载 | /dev/mmcblk0p6挂载于/usr/lib/modules，ext4，ro,relatime | 同上 |
| 数据分区 | /opt/usr为/dev/mmcblk0p5，F2FS、rw、无noexec | 同上 |
| boot分区/文件清单及哈希 | **未知，本轮未完成定位**；未创建挂载点、未挂载任何分区 | [命令全表](../evidence/task6/board_commands.jsonl) |
| config.txt/cmdline.txt、u-boot/boot.scr/tryboot.txt/autoboot.txt | 未读取，未知 | 停止后未继续 |
| /proc/cmdline、分区表、CPU Hardware/Revision、Machine model/Zone ranges/Memory日志 | 尚未采集 | 停止后未继续 |
| partition_ab=a、B槽位及切换机制 | 未调研，未知 | 停止后未继续 |
| 固件/EEPROM版本、tryboot及reboot参数支持 | 未形成结论；command-v未找到vcgencmd/rpi-eeprom-update，不据此推断固件功能 | [工具复查](../evidence/task6/04_root_preflight.transport.txt) |
| 模块目录结构、QB镜像写入方式、spec安装清单 | 尚未调研；挂载点事实不证明镜像制作/写入方法 | 停止后未继续 |

目前事实不足以提出可供执行的内核替换/回退方案，**本轮不提交方案草案为可用方案**。boot映像/设备树实际位置、模块分区写入形式、A/B或tryboot可用性以及最坏恢复路径均待恢复调研；不猜测存在自动回退。未替换任何内核文件或分区。

## 第二部分：安装预检与未执行项

下列目标在开始和结束核对时都不存在（含符号链接检查）：

- `/usr/local/sbin/lko-net-setup.sh`
- `/etc/systemd/system/lko-net-setup.service`
- `/etc/systemd/system/multi-user.target.wants/lko-net-setup.service`

父目录`/usr/local/sbin`和`/etc/systemd/system`存在；`multi-user.target.wants`当时不存在。因为缺少必需验证工具而提前停止，尚未编写本轮脚本/unit，未检查resolv.conf/ConnMan持久化路径，未执行daemon-reload、enable、start或任何脚本。**实际安装文件/enable链接清单为空，SHA-256不适用。** RULES第5项没有登记为已安装的路径，避免把计划路径写成事实。

## 收尾核对

开始SDB为uid5001(owner)，仅为预检按授权切换root；结束已root off，回读确认恢复uid5001(owner)。原有串口shell PID1540未触碰；开始uptime212.82s，最后389.60s，本任务没有重启。

`/opt/usr/lko_task6`**从未创建**。结束`ls -ld`返回No such file or directory、退出2；root和恢复owner后的存在性检查均确认不存在，因此没有需要删除的临时目录。根分区挂载前后均为`/dev/mmcblk0p2 / ext4 rw,relatime 0 0`，未进行remount；/proc/mounts全文（含行顺序）前后一致。

| 挂载点 | 总量KiB（前=后） | 已用KiB（前=后） | 可用KiB（前=后） |
|---|---:|---:|---:|
| / | 3,021,464 | 1,340,316 | 1,650,040 |
| /opt/usr | 116,404,224 | 983,204 | 115,421,020 |

[结束快照](../evidence/task6/07_end_state.transport.txt)、[owner恢复](../evidence/task6/09_owner_final.transport.txt)、[停止/清理摘要](../evidence/task6/stop_and_cleanup_summary.txt)。没有sudo、信号、其他进程干预、网络参数更改或服务文件写入。

## 待PM决定与后续顺序

需先解决规定的verify工具缺失：由PM提供具备该工具的环境，或明确可接受的替代验证方式。本次不自行安装RPM或选择替代手段。随后恢复任务6，完成启动链事实、替换/回退草案、脚本/unit检查及只安装不执行流程。

任务6完成后的下一步仍为“第一次重启验证（需要用户在场）”与“PM审核内核替换方案”。当前没有配网服务可供重启验证，也没有完成可供审核的替换方案，不能提前进入下一步。

全部本轮证据见[evidence/task6/README.md](../evidence/task6/README.md)。
