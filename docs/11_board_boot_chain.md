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

---

## 2026-11-02 r2：恢复调研与安装（本轮结果）

**本轮任务6完成：只读调研和方案草案已交付；配网服务已安装、启用且通过PM替代验收，但未启动、未执行脚本、未重启。** 上文2026-10-30停止记录原样保留为历史。PM于2026-11-02允许用systemctl装载状态、enable链接和journal替代板上缺失的systemd-analyze；本轮根分区必须已rw，否则只停止安装部分，不remount。第一部分与第二部分的停止条件分别适用。

原始输出/拉回的启动脚本在`temp/task6/r2/`，上次原始文件未覆盖。去ANSI的文本、SDB命令与传输退出码见[evidence/task6/r2/README.md](../evidence/task6/r2/README.md)。SDB通常把远程shell失败仍报为传输0，因此报告优先引用输出内的单项退出码、错误文本和验收字段，不能把传输0等同所有子命令成功。

### 1. 身份、内存与分区事实

[01身份](../evidence/task6/r2/01_identity.transport.txt)：`6.12.80-arm-rpi4-v7l`、`armv7l`、`ID=tizen`三项通过；BUILD_ID仍为`tizen-unified-toolchain_20261028.105834_tizen-headed-armv7l`。开始uid5001(owner)，按授权root on，结束root off恢复owner。初末uptime为209867.42/210138.24秒。本轮未操作原有ttyS0 shell或其他任务进程。

[03启动/分区快照](../evidence/task6/r2/03_initial_facts.transport.txt)和[05补全Zone/模块](../evidence/task6/r2/05_slots_modules.transport.txt)：

- Machine model为Raspberry Pi 4 Model B Rev 1.5；Hardware=BCM2835，Revision=c03115。
- `/proc/cmdline`包含`bootmode=normal partition_ab=a console=ttyS0,115200n8 earlycon=uart8250,mmio32,0xfe215040 loglevel=4`；完整值在03证据，未修改。
- DMA范围0x00000000–0x2fffffff，Normal empty，HighMem范围0x30000000–0xfbffffff。System RAM为0x00000000–0x3b3fffff、0x40000000–0xfbffffff。
- Memory日志：`3628300K/4050944K available (20480K kernel code, 1867K rwdata, 11884K rodata, 2048K init, 575K bss, 91372K reserved, 327680K cma-reserved, 3264512K highmem)`。
- CMA池320MiB，0x1ac00000–0x2ebfffff；与boot配置`dtoverlay=vc4-kms-v3d-pi4,cma-320`一致。只记录，不据此批准修改CMA。

| 用途 | A槽 | B槽 | 观察 |
|---|---|---|---|
| boot，64MiB | mmcblk0p1、boot_a | mmcblk0p11、boot_b | A为vfat/LABEL=boot；B仅识别PARTLABEL，blkid未识别文件系统 |
| rootfs，3072MiB | p2、rootfs_a | p12、rootfs_b | A为ext4、挂载/、rw,relatime；B未识别文件系统 |
| modules，32MiB | p6、module_a | p13、module_b | A为ext4、/usr/lib/modules、ro,relatime；B未识别文件系统 |
| ramdisk，32MiB | p7、ramdisk_a | p14、ramdisk_b | boot脚本按槽加载原始分区 |
| recovery ramdisk，32MiB | p8、ramdisk-recovery_a | p15、ramdisk-recovery_b | 有分区标签，不代表已验证恢复镜像 |
| HAL，256MiB | p10、hal_a | p16、hal_b | A已挂载/hal |

共享分区还有p3 system-data（/opt、ext4）、p5 user（/opt/usr、F2FS）、p9 inform（/mnt/inform、ext4）及保留分区。完整分区表、大小、UUID和标签见03；本轮未挂载或写入B槽，**不把“无文件系统识别”直接等同空分区**。

### 2. boot文件与实际启动链

boot_a初始未挂载，使用`mount -t vfat -o ro /dev/mmcblk0p1 /opt/usr/lko_task6/boot`成功，挂载输出明确ro；每次读取后立即umount成功，共三次。没有以rw挂载、修改boot文件。额外两次只用于检查/拉回boot脚本：板上strings不可用（127），随后用SDB pull读取两个小文件，在宿主解析，没有向板上补工具。

413个普通文件的名称、大小、SHA-256见[boot_files.tsv](../evidence/task6/r2/boot_files.tsv)。主要文件：

| 文件 | 字节 | SHA-256 |
|---|---:|---|
| zImage | 14,905,736 | `50d642e137853a46029945965556f4f30e1d87a5706e4eb5f4b02f735a260a5e` |
| bcm2711-rpi-4-b.dtb | 56,450 | `a0561668ec520b0605cdc8b7be6844365ce44f569f363e85f3d7332e1989d6ed` |
| config.txt | 1,716 | `38a4959985ed44398e9656392c245b554155805808524fc04e556e31cc472925` |
| u-boot.bin | 808,272 | `cd6abbb4475282aa54024adbfd079f16363930de9cd0f65a7e5ac7f41c871e16` |
| boot.scr.uimg | 7,520 | `b470712abab8a1d9ad0ffb0061dd34e3acd21ea2483b7ffaca38db6db18fe041` |
| uboot.env | 16,384 | `a1fb3849c26f8d0aabe99e60c1bb986c27db3d36f2162e6ad68fe67856eecdc6` |

[config.txt全文](../evidence/task6/r2/config.txt.txt)：`[pi4] kernel=u-boot.bin`；`auto_initramfs=1`；`enable_uart=1`、`uart_2ndstage=1`；没有显式device_tree、os_prefix或`initramfs <file>`项。DT实际chosen的os_prefix为空、overlay_prefix为overlays/。`cmdline.txt`不存在（cat的原始ENOENT保留），不能提供不存在文件的全文；`boot.scr`、`tryboot.txt`、`autoboot.txt`均不存在，但存在`boot.scr.uimg`。不要把boot.scr的缺席误写为没有启动脚本。

实际可证链条：固件读config.txt并加载u-boot.bin；U-Boot通过boot.scr.uimg从所选boot槽根目录加载环境变量`kernel=zImage`，用`bootz`启动，设备树使用固件已经提供的`$fdt_addr`。脚本从所选ramdisk槽读取initrd，并自己拼接bootargs，所以本机无需cmdline.txt。[已校验uImage头/数据CRC的脚本文本](../evidence/task6/r2/boot_script.txt)、[环境文本](../evidence/task6/r2/uboot_environment.txt)、[解码说明](../evidence/task6/r2/boot_decode.txt)。脚本文本仅解码、未执行。

### 3. A/B选择、tryboot与回退能力边界

`partition_ab=a`的来源已闭合：boot脚本默认a，读取inform分区的`partition-ab.info`，首字节为0x62才选b；继而查找`boot_${partition_ab}`和`ramdisk_${partition_ab}`并把该值写入bootargs。`/mnt/inform/partition-ab.info`实读为`61 0a`（a换行）；reboot-param.bin为normal。uboot.env有`set_to_part_a/b`，通过ext4write改该标记；**本轮未运行这些环境命令或任何device_board_set接口**。

[12槽位运行文件](../evidence/task6/r2/12_slot_runtime.transport.txt)、[14克隆配置](../evidence/task6/r2/14_firmware_clone.transport.txt)：存在clone_partitions服务及脚本，upgrade-common.inc:160读取cmdline槽位，322起实现background_copy、435起加载复制清单。当前`partition-ab-cloned.info=0`；clone服务ActiveState=active、UnitFileState=disabled、Result=success，这些字段不能证明B槽已克隆完成。B槽文件系统/镜像完整性、实际可启动性和启动失败自动切回机制**未知**。

固件与EEPROM证据：

- vcgencmd、rpi-eeprom-update不可用；dmesg明确firmware日期`2025-05-14T12:23:36`、hash `17084b403fb60475b8ee2641c26049a7d54bf153`。
- DT chosen：U-Boot `2025.10-gd5489c7b9-TIZEN.org`，bootloader/version=`8ba17717fbcedd4c3b6d4bce7e50c7af4155cba9`；build-timestamp字节63 be f4 a4，按大端Unix时间解码为2023-01-11 17:40:52 UTC；tryboot=0、capabilities=0x7f。未把capabilities各位作未经验证的解释。[06版本原文](../evidence/task6/r2/06_boot_script_firmware.transport.txt)。
- 板上reboot链接到systemctl，`reboot --help`只读调用退出0，显示`reboot [OPTIONS...] [ARG]`。上游systemd v244的systemctl.c:8776–8784接受一个reboot参数并传入update_reboot_parameter_and_warn；这只是相同上游版本的源码佐证，不声称Tizen补丁完全一致。[参数源码摘要](../evidence/task6/r2/tryboot_references.txt)。
- 本树0fac5de6的drivers/firmware/raspberrypi.c:204–220识别参数中的`" tryboot"`并设置RPI_FIRMWARE_SET_REBOOT_FLAGS；496–503注册reboot notifier。[内核源码摘录](../evidence/task6/r2/kernel_source_excerpts.txt)。因此`reboot '0 tryboot'`存在用户态参数接口和内核实现路径，**本轮没有执行或试验该命令**。
- 官方文档说明该标志会让固件选择替代配置，并在移交前清除，下一次复位可回到原配置；它不等于自动复位/看门狗。当前没有tryboot配置，且U-Boot脚本固定从boot槽根目录选kernel，单加os_prefix不足以证明Linux及modules一起切换。[RPi官方tryboot文档](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#fail-safe-os-updates-tryboot)、[autoboot文档](https://www.raspberrypi.com/documentation/computers/config_txt.html#autoboot-txt)。端到端一次性试启动与自动回退**仍未知、未验证**。

### 4. 模块与RPM安装位置

`/usr/lib/modules`直接挂载mmcblk0p6、ext4、ro,relatime；`/lib -> usr/lib`。当前版本目录为`6.12.80-arm-rpi4-v7l`，含kernel/{fs,sound,lib,drivers,net,crypto}，以及extra/kdbus、extra/zlogger，还有顶层modprobe.d、modules-load.d。[05目录结构](../evidence/task6/r2/05_slots_modules.transport.txt)。实际已加载模块/BTF说明仅替换zImage不够，版本/ABI变化必须配套模块；外部模块也须核对。

以下为**RPM文件安装位置，不等同刷写地址**。源码HEAD/工作树已核对，0fac5de6、干净；[spec带行号证据](../evidence/task6/r2/kernel_source_excerpts.txt)：

| 包（armv7l） | 安装文件 | spec行 |
|---|---|---|
| arm-rpi4-linux-kernel | /boot/zImage、/boot/bcm*.dtb、/boot/overlays/*.dtb*；还包含config.txt、start*.elf、fixup*.dat、许可证 | 241–257、264–270、374–386 |
| arm-rpi4-linux-kernel-modules | /lib/modules/*arm-rpi4-v7l/ | 299–300、351–356 |
| arm-rpi4-rt-linux-kernel | /boot/zImage_rt及共享DT/固件配置文件；%post会把zImage_rt改名为zImage | 291–295、337–350、388–400 |
| arm-rpi4-rt-linux-kernel-modules | /lib/modules/*arm-rpi4-rt-v7l/ | 358–363 |

U-Boot及boot.scr.uimg不在该kernel包文件清单。本轮没有安装RPM。原始任务6的“QB镜像内模块镜像文件及刷写流程”未在本轮续任务中取得新证据，确切镜像封装/写入命令仍**未知**；只确认板上模块是独立ext4分区，不将RPM目录当成可直接刷写的镜像。

### 5. 仅替换内核与回退草案（待PM审核，不是执行许可）

1. 首次实验前，由PM审核并安排用户在场，确认串口/取卡或原有刷机途径可用。备份GPT/分区映射、当前boot_a完整文件及分区镜像、module_a完整分区镜像、ramdisk_a和inform状态；所有备份拉到WS/temp下，保存SHA-256并复读核对。ramdisk/inform只备份，不在本方案中改写；无需备份/改写整个用户态才能做到保留用户态。若备份或可操作恢复路径不能确认，停止替换。
2. 变更集合应为同一构建的zImage、匹配bcm2711-rpi-4-b.dtb/确需更新的overlays、配套module_a内容；维持U-Boot、boot.scr.uimg、uboot.env、config.txt、固件和cmdline不变。使用包解开后的目标文件，**不安装整个kernel RPM**，避免覆盖固件配置或触发RT包脚本。模块离线生成ext4镜像或离线维护，包含匹配的外部kdbus/zlogger及depmod索引；大小必须容纳于32MiB分区，不能在已ro挂载的活动模块分区直接写块设备。具体离线更新入口尚待PM批准和恢复环境核实。
3. 回退优先级：若后续能闭合“固件tryboot → U-Boot替代kernel/DT → 匹配模块且用户态不变”的独立启动路径，优先一次性试启动；当前没有该配置，不能立即采用。次选A/B，但现有选择器同时涉及rootfs/ramdisk/hal，B槽克隆未闭合，直接切B不能保证用户态不变，也未见自动失败回切证据，当前不采用。
4. 在自动回退未证实前，保守草案仅允许**用户在场的离线替换/恢复**：保留当前A槽镜像作已知良好备份，失败时由用户通过已确认的取卡恢复或平台刷机恢复boot_a/module_a；保留现有rootfs/user/system-data。U-Boot串口命令或DFU是否可用于快速恢复仍需用户实际确认，环境中的dfu_alt_info只能证明映射定义，不能证明现场恢复链已验证。
5. 新内核起不来、无自动回退或SDB不可达时，代理停止，由用户在内网串口机诊断并执行物理恢复；最坏需取出介质，用备份恢复相关分区，若备份/介质损坏则可能须重刷已知可用镜像并由用户完成配网准备。不能承诺全程无现场操作。启动成功后核对uname、/proc/version、最终配置、模块版本/加载错误和镜像SHA，再开始性能实验。

本任务没有备份大分区、替换内核/模块、改启动参数/槽位、启动克隆服务或测试回退。以上“备份/替换/恢复”均为未来方案，不是本轮已执行事实。

### 6. 设计v4阶段0a只读采集

[07完整采集](../evidence/task6/r2/07_phase0a.transport.txt)、[所有PID快照](../evidence/task6/r2/oom_score_adj.tsv)：

- /sys/kernel/btf存在，vmlinux为6,478,350 B，另有brcmfmac等模块BTF；不是“BTF不存在”。
- 枚举当时196个可读进程的pid/comm/oom_score_adj：191个0，systemd-journal=-250、systemd-udevd=-1000、pkginfo-server与amd各-100、org.tizen.multi=230。这是逐PID非原子快照，进程可在枚举中退出，不把它当固定产品策略全集。
- `/usr/lib/udev/rules.d/50-udev-default.rules`含btrfs-control设备组规则；`64-btrfs.rules`含btrfs ready/ID_BTRFS_READY/systemd readiness处理。两文件全文已采集；未触发udev规则或改Btrfs状态。
- /opt/usr的F2FS挂载选项没有compress相关项；这仅描述当前挂载参数，不证明内核/磁盘完全不支持压缩。
- freezer根目录只有tzip子目录，完整ls与目录列表已保存；未冻结进程。

### 7. 配网脚本、安装与替代验收

宿主提交[脚本](../scripts/board/lko-net-setup.sh)和[unit](../scripts/board/lko-net-setup.service)。`bash -n`退出0；宿主systemd-analyze参考检查退出1，唯一问题是宿主没有ExecStart目标文件，按PM裁决不作板上判定。[检查原文](../evidence/task6/r2/host_verify.txt)。人工自查：执行eth0 down→MAC→up；MAC设置失败也尝试恢复up再退出；等待ConnMan指定服务，使用/proc/uptime的60秒截止和有1秒reply timeout的只读D-Bus GetServices，避免无界等待单次回复；找到后按PM指定connmanctl参数设置；日志统一tag=lko-net-setup。等待所用D-Bus命令已单独只读验证可用；**没有运行脚本**。

DNS先记录/etc/resolv.conf是否为符号链接，再readlink解析目标、findmnt检查该目标实际挂载rw并检查普通文件可写，才写一行指定nameserver；查询/写入失败只记录并以成功结束DNS部分，不导致服务失败。脚本可重复设置相同值，但运行时会短暂中断eth0，不能在当前远程安装会话试跑。

[13预检](../evidence/task6/r2/13_install_preflight.transport.txt)：目标文件和enable链接均不存在；`/`原本rw,relatime，**未执行remount**。resolv.conf→/opt/etc/resolv.conf，其ext4分区p3为rw；/var/lib/connman解析到/opt/var/lib/connman，同为p3持久分区，已有ethernet_2ccf67a072b5_cable/settings，manual地址/网关/DNS与本次要求一致，说明该服务配置已能持久存储；并非必须依靠每次开机直接写DNS才持久化。

实际只推两文件到任务临时目录，再install到以下位置：[17安装原文](../evidence/task6/r2/17_install.transport.txt)。

| 板上持久写入项 | 权限/目标 | SHA-256 |
|---|---|---|
| /usr/local/sbin/lko-net-setup.sh | root:root 0755，2642 B | `8fecc6d0b5383b04de53bec6ac0b3e795e93c140b8d8ae0c315f6b75855a6608` |
| /etc/systemd/system/lko-net-setup.service | root:root 0644，213 B | `bb5be5756fb97065c4adb4b3df3c5041d4f6f148498ff4a9364d8e58799c5d78` |
| /etc/systemd/system/multi-user.target.wants/lko-net-setup.service | enable创建，→ /etc/systemd/system/lko-net-setup.service；父目录本轮随enable创建 | 解引用目标的SHA同unit；符号链接自身以readlink核验 |

daemon-reload与enable均退出0。reload开始为2026-11-02 01:52:16 UTC（Asia/Shanghai 09:52:16；板上journal显示10:52:16+0900）。[18验收](../evidence/task6/r2/18_verify.transport.txt)、[19独立journal查询](../evidence/task6/r2/19_journal_confirm.transport.txt)：

```text
Wants=connman.service
After=sysinit.target system.slice basic.target connman.service
LoadState=loaded
LoadError=
UnitFileState=enabled
ActiveState=inactive
SubState=dead
ExecMainPID=0
ExecMainStartTimestamp=
IS-ENABLED-EXIT=0
```

ExecStart正确指向/usr/local/sbin/lko-net-setup.sh；is-enabled输出enabled；readlink与unit绝对路径一致。journal两次完整读取退出0，reload之后没有lko-net-setup消息，更无该unit警告/错误。journal中有其他unit的memory.limit_in_bytes警告及display-manager失败，原文保留，未干预、不归因于本服务。本次各验收项通过，未触发disable/删除回滚。实际执行/配网连通性、SMACK执行权限和开机时序仍待用户在场首次重启验证，装载成功不等于运行成功；当前两安装文件的SMACK标签为User::Shell，未另改标签。

### 8. 收尾、未知项与下一步

[20清理](../evidence/task6/r2/20_cleanup.transport.txt)、[22恢复owner](../evidence/task6/r2/22_owner_final.transport.txt)、[对照摘要](../evidence/task6/r2/cleanup_and_verification.txt)：

- /opt/usr/lko_task6整体删除，rm退出0、ls退出2且明确不存在，最后owner身份再次确认；其下无残留挂载。
- /proc/mounts全文含顺序前后一致；/始终`/dev/mmcblk0p2 / ext4 rw,relatime`。本轮无remount、无重启。
- /opt/usr的df完全一致：已用983,204、可用115,421,020 KiB。/已用1,340,316→1,340,328 KiB，增加12KiB；可用相应减少12KiB。本轮获准保留服务文件/enable目录，不伪称根分区df数值完全未变，也不把每个块的变化强归因。
- 首次重启验证必须用户在场；PM先审核上述内核替换/回退草案，未批准前不替换。设计v4另挂账的三项授权仍待用户决定。

第一部分仍为**未知/未验证**的清单：B槽镜像内容/完整性和可启动性；Tizen A/B启动失败自动切回策略；当前固件→U-Boot→内核→匹配模块的端到端tryboot效果及失败后的自动复位来源；initramfs内模块槽选择的具体实现；QB模块镜像封装与实际刷写命令；现场串口/DFU/取卡恢复路径及可执行回退的实测。相应调查已读取分区标签、boot脚本/环境、DT版本、克隆脚本和相关源码；本任务不通过重启、克隆或写分区来填补这些未知。

---

## 2026-11-02 r3：任务7，内核替换前提与首次重启验证

### 第一部分：只读核实

三项身份通过：uname-r=6.12.80-arm-rpi4-v7l，uname-m=armv7l，ID=tizen。宿主原始产物在temp/task7；板上只使用/opt/usr/lko_task7。第一部分没有修改启动参数、boot或模块分区，boot只ro挂载并立即卸载，没有安装/卸载RPM。[命令及证据索引](../evidence/task7/README.md)。

**模块当前使用与归属。** [03](../evidence/task7/03_modules_initial.transport.txt)、[05](../evidence/task7/05_ramdisk_copy.transport.txt)记录10个已加载模块，每个modinfo -n均成功：proc_tsm、hci_uart、btbcm、brcmfmac、brcmutil、kdbus、dm_bow、logger、inform_reboot、extcon_usb_fixed。kdbus来自extra/kdbus/kdbus.ko，引用计数88；logger来自extra/logger.ko，引用计数194。extra/zlogger/zlogger.ko的内部名称为zlogger，未出现在/proc/modules中；不能把logger等同zlogger。kdbus在用，zlogger未见当前加载使用，不能推断以后可从产品删除。

/usr/lib/modules和/lib/modules两种路径的rpm -qf均报“not owned by any package”，后者明确退出1，故**已安装RPM数据库无法给出kdbus/zlogger所属包**；不猜包名。/dev/kdbus*和/dev/zlogger*均不存在，ls退出2；但/sys/fs/kdbus存在control及0-system、5001-user，其中0-system/bus存在，设备路径不在/dev不能证明kdbus未使用。/dev/log_main、log_radio、log_system存在，与已加载logger分别记录。

/etc/dlog.conf未发现有效的backend赋值，只有backend相关注释；/etc/dlog.conf.d/20-pipe.conf和25-logger.conf中的backend=pipe/logger均注释掉，表示自动检测；86-disable-dlog.conf_inactive有backend=null，但文件名为inactive，不能把该值当当前有效backend。只读配置不足以直接断言最终自动选择的backend，原文保留。

**模块容量。** 本次df/du命令的实测如下，单位KiB；不要把GPT的32MiB分区大小当成可用文件空间：

| 项目 | 数值 |
|---|---:|
| df总量 / 已用 / Available | 19,396 / 4,020 / **14,648** |
| inode总量 / 已用 / 空闲 | 8,192 / 138 / **8,054** |
| 6.12.80-arm-rpi4-v7l版本目录du -sk | **4,424** |
| kernel子目录du -sk | 3,428 |
| extra子目录du -sk | 328 |

df和du是不同口径，本轮不修改文件系统、也不强行解释二者差值。新版本预计大小需在实际生成后另测，加上外部模块和索引核对可用容量/余量，当前数字不等于批准部署任意变体。[03容量原文](../evidence/task7/03_modules_initial.transport.txt)。

**谁挂载模块分区。** systemctl list-units可见usr-lib-modules.mount，但systemctl cat报No files found、退出1；FragmentPath为空，SourcePath=/proc/self/mountinfo，What=/dev/mmcblk0p6。这是systemd观察到的既有挂载，**不是由systemd mount unit文件发起挂载**。实际挂载者是ramdisk init脚本，见下文。[04](../evidence/task7/04_mount_smack.transport.txt)。

**ramdisk解包与模块版本依赖。** dd只读p7到专用目录，32MiB、退出0，SDB拉回后删除板上副本。SHA-256 `01e2f0cbfe091b14989f69154c488697c60ac98bea32e11bebfec6ea98b71024`，宿主与板上一致。GBS LLVM buildroot内的file判为gzip；gzip -dc返回2并明确“decompression OK, trailing garbage ignored”。复核第一个gzip流已正常结束/校验，输出15,211,008 B，与cpio文件完全相同；整个原始分区在该gzip流之后尚有25,644,116 B尾部，其中1,036,266 B非零，**不是全零padding**。本轮不猜尾部来源、不改镜像，分析对象是成功解码的当前首个gzip/cpio流。[格式与解压](../evidence/task7/ramdisk_file.txt)、[gzip警告](../evidence/task7/ramdisk_gzip.txt)、[尾部核对](../evidence/task7/ramdisk_gzip_padding.txt)。

cpio -it成功，103个entry；只有空的usr/lib/modules目录，没有版本子目录、没有.ko。lib→usr/lib，init→sbin/init，sbin→usr/sbin。先按用户指定路径提取普通文件，再明确提取init指向的usr/sbin/init及相关update-checkpoint-create.sh；全部使用cpio --no-absolute-filenames，预先拒绝绝对路径/..，只选择普通文件，不解设备节点/符号链接，也不执行解出的init。[完整清单](../evidence/task7/ramdisk_list.txt)、[init全文](../evidence/task7/ramdisk_init.txt)。

- usr/sbin/init:122–127从partition_ab形成_a/_b；198–201优先找PARTLABEL=module${P_SUFFIX}，退回LABEL=modules。
- :412–417在initramfs的/lib/modules用mount -o ro挂模块分区；:419–427随后move到新root的lib/modules，或在HAL提供模块时改bind挂载。当前板上观察到p6直接挂载，符合move路径。
- :497–530读取各modules-load.d/*.conf，调用modprobe加载名字，没有写死6.12.80或其他版本、也没有指定--set-version；:904–905第一轮从模块分区加载，:920–921移挂后从模块/HAL配置第二轮加载。
- 当前模块分区tizen-modules-rpi4.conf列出dm-bow、extcon-usb-fixed、inform-reboot、logger、kdbus；modprobe配置另含proc-tsm选项。HAL两个modules-load.d路径不存在。[10配置](../evidence/task7/10_readonly_finish.transport.txt)。因此新版本目录必须包含这些所需外部模块及索引，**不能只放内核源码内编出的kernel/模块**。

**U-Boot字符串。** ro挂载p1拉回u-boot.bin后立即卸载；SHA-256与前轮完全一致：`cd6abbb4475282aa54024adbfd079f16363930de9cd0f65a7e5ac7f41c871e16`。使用LLVM buildroot平台strings，只记录字符串，不推定命令已编译注册或运行可用。[逐项结果](../evidence/task7/uboot_command_strings.tsv)。fatwrite、fatload、fatls、load、bootz、ext4write、ext4load、mmc、part、setenv、saveenv、ums、dfu均出现；booti未出现；thor作为thor_init/thor_handle/usb_dnl_thor等片段出现，独立thor命令名未出现，另有thordown。boot.scr中引用booti不意味着这个U-Boot二进制有该命令。

**独立版本后缀方法（仅方案）。** spec:4–11把variant定义成arm-rpi4；:180–181对普通/RT target分别写localversion-tizen=-arm-rpi4/-arm-rpi4-rt；defconfig:1为CONFIG_LOCALVERSION="-v7l"、:2关闭LOCALVERSION_AUTO；scripts/setlocalversion:174–208按KERNELVERSION、localversion文件、CONFIG_LOCALVERSION、LOCALVERSION、scm依次拼接。[源码行号](../evidence/task7/version_suffix_sources.txt)。未来实验可在该实验构建的所有内核make步骤统一传`LOCALVERSION=-lko-base01`（下一变体换唯一标识），得到`6.12.80-arm-rpi4-v7l-lko-base01`；包括准备、实际编译、modules_install及外部模块构建/安装均须保持一致，不能只改uname显示或事后改目录名。CONFIG_LOCALVERSION_AUTO仍关闭，显式LOCALVERSION避免未指定变量时的scm加号路径。

现有spec:351–363的%files通配以-arm-rpi4-v7l/或-rt-v7l/结尾，直接追加后缀会不匹配；未来实现必须同步调整为**对应实验完整kernelrelease目录**并核对包内文件清单和外部模块vermagic，不能只加make参数便宣称打包已适配。方法尚未执行、未改spec或源码，具体实施待PM任务。

**DTB。** 已有QB1211696 sandbox基线的devel RPM解出产物，56,450 B，SHA-256 `a0561668ec520b0605cdc8b7be6844365ce44f569f363e85f3d7332e1989d6ed`，与板上值完全一致。来源沿用任务5b已经闭合的0fac5de6/QB1211696；不把任务2旧f240c280的DTB当sandbox基线，不为此构建。[比对](../evidence/task7/dtb_comparison.txt)。

**SMACK只读结果。** PID1标签为System::Privileged；ip、connmanctl、connman.service、/usr/local/sbin及/etc/systemd/system均为`_`，两安装文件均为User::Shell。load2中明确有`System::Privileged User::Shell rwxat`，不能断言旧标签必然导致访问拒绝。chsmack存在/usr/bin/chsmack。[04原文](../evidence/task7/04_mount_smack.transport.txt)。第二部分按PM要求仍统一为参考文件标签，具体前后及启动结果另列。

### 第二部分：标签修正与第一次重启超时（未完成验收）

用户已在对话中确认“已在场，可以开始”，此前已打印PM指定提示。[在场确认记录](../evidence/task7/user_presence.txt)。重启前重新通过三项身份断言并取得SDB root。只对两个指定文件执行chsmack -a，回读结果如下；其他对象标签未改：

| 文件 | 原标签 | 新标签 | 参考 |
|---|---|---|---|
| /usr/local/sbin/lko-net-setup.sh | User::Shell | `_` | /usr/sbin/ip |
| /etc/systemd/system/lko-net-setup.service | User::Shell | `_` | /usr/lib/systemd/system/connman.service |

脚本与unit SHA-256仍分别为`8fecc6d0b5383b04de53bec6ac0b3e795e93c140b8d8ae0c315f6b75855a6608`、`bb5be5756fb97065c4adb4b3df3c5041d4f6f148498ff4a9364d8e58799c5d78`。daemon-reload退出0，LoadState=loaded、LoadError为空、UnitFileState=enabled，ActiveState=inactive。没有手动执行脚本或start/restart服务。[14修正/验收原文](../evidence/task7/14_label_fix.transport.txt)。

第一次重启编号1，原因为“用户在场的配网服务首次开机验证”。重启前boot_id=`0fb981c1-1852-425c-bc1f-665fe09f946d`，uptime=214734.64秒；MAC=2c:cf:67:a0:72:b5、IP=192.168.108.26/24，ConnMan服务为`*AR Wired ethernet_2ccf67a072b5_cable`，DNS为nameserver 221.131.143.69。[15前置快照](../evidence/task7/15_reboot1_before.transport.txt)。

2026-11-02 11:09:27（Asia/Shanghai，精确时间见命令JSON）发出唯一一次无参数`sdb -s 192.168.108.26:26101 shell reboot`。该SDB客户端8秒内没有返回，宿主记录HOST-SDB-CALL-TIMEOUT/124；**124是宿主传输等待超时码，不是板上reboot退出码**，未获得远端退出状态。随后按10秒节拍尝试connect，并只读探测boot_id；600秒窗口内没有取得新的boot_id或可用shell。第6次connect曾返回“already connected”，随后shell却是target not found，因此未误判为恢复。[重连全记录](../evidence/task7/reboot_reconnect_log.txt)、[600秒结果](../evidence/task7/reboot1_reconnect.json)、[精确命令与退出码](../evidence/task7/board_commands.jsonl)。

窗口在约11:19:27达到600.0002秒，59次按10秒节拍发起的connect均未形成可用会话，达到截止不再发起新的连接。最后原文：

```text
connecting to 192.168.108.26:26101 ...
failed to connect to 192.168.108.26:26101
error: target not found
error: serial number '192.168.108.26:26101' wrong
{"number": 1, "result": "TIMEOUT", "elapsed_seconds": 600.0002119870041}
```

**按PM停止条件结束第二部分，不做第二次重启或其他板上补救。** 已向用户报告，请用户经串口手动执行配网命令恢复连接；本轮不绕过SDB、不修改服务、不重试重启。SDB不可达本身不能证明是该配网服务失败，也不能排除其他启动/网络问题，原因未知。没有新boot_id，因此连“内核已完成重启”也未通过规定的boot_id变更核验。

| 验收项 | 第一次 | 第二次 |
|---|---|---|
| SDB可连 | 未满足：600秒超时 | 未执行 |
| 三项身份、新boot_id | 无法采集/核验 | 未执行 |
| Result=success、ExecMainStatus=0 | 无法采集 | 未执行 |
| 重启后MAC/IP匹配 | 无法采集；重启前匹配不作替代 | 未执行 |
| journal -t/-u、SMACK/权限拒绝 | 无法采集 | 未执行 |
| 服务耗时=退出单调时刻−开始单调时刻 | 无法计算，缺重启后属性 | 未执行 |
| multi-user.target在服务退出之后到达 | 无法判断，缺目标/服务时间戳 | 未执行 |
| 总判定 | **未通过可达性验收，服务结果未知** | **按条件跳过** |

### 收尾与待恢复事项

第一部分结束时已经整体删除/opt/usr/lko_task7，rm退出0、ls退出2明确不存在，boot挂载全部卸载；/proc/mounts全文前后一致；根分区/opt/usr df也分别一致：根已用1,340,328/可用1,650,028 KiB，/opt/usr已用983,204/可用115,421,020 KiB。[10结束原文](../evidence/task7/10_readonly_finish.transport.txt)、[清理摘要](../evidence/task7/part1_cleanup.txt)。第二部分没有再创建板上临时目录。

第一部分后曾root off；第二部分按授权再次root on。因首次重启后无法连接，**最终无法再执行并回读owner恢复，也无法重新读取mounts/df**，不声称这些重启后核验已完成。临时目录已删除的证据时间点是重启前，而非假造重启后ls结果。恢复连接后的身份/日志/owner收尾待用户恢复及PM后续安排，本轮不继续连接或修复。

任务7第一部分完成，第二部分按超时停止，整体不标“首次重启验证通过”。内核替换执行步骤仍待PM下发；用户待答复：是否有读卡器、串口能否进入U-Boot命令行、测量小程序授权、冷启动电源控制、测试应用安装授权。

## PM审核结论（2026-11-02）

内核替换方案：不用一次性试启动（启动脚本只在内核文件名为 zImage 时走 bootz，其他名字走 booti；绕过 U-Boot 需要启动参数文件，不在授权内），不用 A/B 槽（B 槽未克隆，切槽会连带切换 rootfs/ramdisk/hal）。不整块重写模块分区。采用：每个实验内核（包括自编基线）加独立版本后缀，模块放在模块分区的新版本目录，与原有 6.12.80-arm-rpi4-v7l 目录并存；boot 分区保留原厂内核为 zImage.orig，实验内核以 zImage 放入，回退为改回文件名。设备树和 overlays 不动，除非变体本身改动设备树。前提：模块分区空间足够、ramdisk 不依赖带版本号的模块、外部模块（kdbus/zlogger）的使用情况已查清；空间不足时停下由 PM 决定。回退分级：sdb 可达时由 Codex 改回文件名；不可达时由用户经串口手工引导原厂内核或取卡改名；最坏重刷镜像。具体执行步骤另行下发。

## 2026-11-02 r4：首次重启失败排查

### 范围、背景与时间边界

本轮为任务7 r2，仅只读采集；没有重启、运行配网脚本或logger、操作服务、daemon-reload、修改网络/文件/标签。唯一权限切换是获准的SDB root on/off。三项身份断言通过，SDB可达。原始输出留在`temp/task7/r2/`，去ANSI文本及命令、退出码见[证据索引](../evidence/task7/r2/README.md)。

PM提供的背景：11:09重启后SDB未恢复，随后发现网线松动，已经重插并通过串口手动配网；据用户描述约13:12（北京时间）又开过一次机，11:09那次日志已不存在。[用户背景原文记录](../evidence/task7/r2/user_background.txt)。这是用户观察，不是本轮采集到的故障日志。

本轮boot_id始终为`559cfce8-46fe-49b0-97f2-2c5d18ecb275`；`--list-boots`只有该boot。首次读取uptime=13170.56秒、UTC时间06:49:52，日志显示KST时区，保留范围14:33:47–15:49:48 KST，即13:33:47–14:49:48北京时间。**list-boots两端是现存日志范围，不是实际开关机时间。** 来源：[03基本信息](../evidence/task7/r2/03_basic.transport.txt):5–20。

时间有未闭合之处：按当前UTC减uptime推算约11:10北京时间，与用户所述约13:12不一致；服务ExecStart的墙钟起点为1970、终点为2026-11-02 12:10:43 KST，表明启动早期墙钟发生跳变（[08补充](../evidence/task7/r2/08_retention_link.transport.txt):122–135）。本轮不能独立确认“13:12再次开机”的绝对时刻，也不据此将当前boot等同于11:09那次。以下顺序仅按当前boot的单调时钟；先前失败仍按缺失日志处理。

### 服务实际运行状态与文件核对

服务**本次boot确实执行并退出0**，最终为`active/exited`、`Result=success`，不是“没有执行”。[04服务快照](../evidence/task7/r2/04_service.transport.txt):1–18及[09结束回读](../evidence/task7/r2/09_final.transport.txt):4–13一致：

| 属性 | 实测 |
|---|---|
| LoadState / UnitFileState | loaded / enabled |
| ActiveState / SubState / Result | active / exited / success |
| ExecMainCode / ExecMainStatus | 1（ExecStart明确code=exited） / **0** |
| ExecMainStart / Exit TimestampMonotonic | 16,155,117 / 21,129,311 µs |
| InactiveExit / ActiveEnter TimestampMonotonic | 16,156,439 / 21,130,467 µs |
| ConditionResult / ConditionTimestampMonotonic | yes / 16,153,051 µs |
| TimeoutStartUSec / NRestarts | infinity / 0 |
| Before | shutdown.target multi-user.target |
| After | system.slice connman.service sysinit.target basic.target |

耗时`(21129311−16155117)/1e6`=**4.974194秒**。multi-user.target于21.133569秒到达，比脚本退出晚**4.258毫秒**；依赖图和Before同时支持其等待关系。默认target是graphical.target，其依赖包含multi-user.target，后者包含lko-net-setup.service。[06目标和SDB](../evidence/task7/r2/06_targets_logger_sdb.transport.txt):1–18、195–217。当前system状态running，failed为0、无待处理job（03:31–42）。

两个文件内容及标签不变，enable链接仍在且指向正确（04:19–31）：

| 对象 | 权限/标签 | SHA-256或目标 |
|---|---|---|
| /usr/local/sbin/lko-net-setup.sh | 0755 / `_` | `8fecc6d0b5383b04de53bec6ac0b3e795e93c140b8d8ae0c315f6b75855a6608` |
| /etc/systemd/system/lko-net-setup.service | 0644 / `_` | `bb5be5756fb97065c4adb4b3df3c5041d4f6f148498ff4a9364d8e58799c5d78` |
| /etc/systemd/system/multi-user.target.wants/lko-net-setup.service | symlink / System::Privileged | /etc/systemd/system/lko-net-setup.service |

退出0是本次boot的进程结果；当前网络已经用户手动恢复，**不能据此补判此前自动配网和两次重启验收通过**。

### 为什么没有日志：已证实的范围与推测

[05日志全文](../evidence/task7/r2/05_journal.transport.txt):1–8显示`-u`与`-t`查询都成功但“No entries”；全journal读取也退出0。全量文本中`lko-net|LKO fixed`为0行；`(smack|denied|audit)`且同时含`(lko|logger)`为0行；网络关键词也为0行。筛选统计和原始全文均保留，不能把“未命中”当“历史上从未产生”。

[08](../evidence/task7/r2/08_retention_link.transport.txt):15–23、47–80明确：Storage=persistent，SystemMaxUse=4M；/var/log/journal实际在/opt/var/log/journal（p3/ext4/rw）；/run/log/journal不存在；三个已检查journald.conf.d目录均不存在。journal当前占用4.0M，8个文件各524,288 B。现存完整journal首条是开机后**8605.093301秒**（05:11），不覆盖服务执行的16–21秒；其中2,677行是display-manager/Display manager失败与重启相关记录，统计见[日志摘要](../evidence/task7/r2/journal_summary.txt)。

**推测：4MiB容量限制加上反复产生的display-manager日志，使早期日志被轮转淘汰，是当前无服务日志的合理解释。** 可直接确认的是“早期时段已经不在保留范围”；具体淘汰过程、logger当时是否写入成功均**无法确定**，不能仅以容量碰满证明唯一原因。本轮未干预display-manager。

logger路径为/usr/bin/logger，标签`_`；/dev/log是标签System::Privileged的链接，指向/run/systemd/journal/dev-log，实际socket权限srw-rw-rw-、标签`*`（06:394–400、08:105–114、09:1–3）。服务StandardOutput/StandardError为dlog|journal（08:124–126）。仅有这些元数据不足以证明logger在当时服务环境一定能写入；遵照只读要求未执行logger，亦没有保留下来的相关拒绝日志，因此该点**无法确定**。

### 本次boot的网络相关时间线与当前状态

[网络筛选](../evidence/task7/r2/network_timeline.txt)：从完整journal按不区分大小写`connman|sdbd|eth0|genet|link is|carrier`匹配，总0行、保留0行，未触发400行截断。下表来自systemd属性/udev数据库，**不是补造缺失的journal时间线**；单位是本次开机后秒。

| 秒 | 事件/属性 | 证据 |
|---:|---|---|
| 11.074879 | systemd-journald ActiveEnter | 08:117–120 |
| 11.711858 | eth0 USEC_INITIALIZED（udev属性） | 07:74 |
| 14.350858 | sdbd_tcp.socket ActiveEnter | 06:479–480 |
| 15.990239 | connman.service ActiveEnter | 06:403–406 |
| 16.155117 | lko-net-setup开始 | 04:4 |
| 21.129311 | lko-net-setup退出0 | 04:5–7 |
| 21.133569 | multi-user.target ActiveEnter | 06:1–4 |
| 21.668379 | dev-usb\\x2dfuncs-sdb-default.mount ActiveEnter | 06:414–415 |
| 21.684805 | sdbd.socket ActiveEnter | 06:466–467 |
| 21.892593 | sdbd.service ActiveEnter | 06:422–423 |

SDB相关unit清单、每个systemctl cat及退出码见06:408起；观察到的USB mount无unit文件，cat报No files found；udev-sdb-init.service的ActiveEnterTimestampMonotonic为0，不当作有效启动时刻。socket/service active不等于某时刻远端已经连通。物理carrier变化、网线重插、手动配网与首次成功连接的精确时间，现存日志均**无法确定**。

[07网络快照](../evidence/task7/r2/07_network_link.transport.txt):1–40：eth0为UP/LOWER_UP，MAC=2c:cf:67:a0:72:b5，IP=192.168.108.26/24；ConnMan显示`*AR Wired ethernet_2ccf67a072b5_cable`；DNS为221.131.143.69。/var/lib/connman同时存在2ccf67a072b5与88a29e230117服务目录；用户指定的旧MAC settings全文已记录，IPv4/IPv6.method均auto、AutoConnect=true，Modified为1970时间，不能据此确定真实修改时刻。以上只描述**用户手动恢复后的状态**。

**11:09失败能否归因于网线松动：无法确定。** 松动是用户提供的物理观察，能够作为背景，但没有该次carrier/服务/连接日志，不能确定它是唯一原因，也不能排除其他问题。本次boot进程退出0不替代11:09故障证据。

### .link方案的只读前提

[07](../evidence/task7/r2/07_network_link.transport.txt):42–88与[08](../evidence/task7/r2/08_retention_link.transport.txt):82–103：

- /usr/lib/systemd/network和/etc/systemd/network均存在，只列出99-default.link。系统文件含NamePolicy=keep kernel database onboard slot path与MACAddressPolicy=persistent；/etc同名文件指向/dev/null，屏蔽默认文件。
- /usr/lib/udev/rules.d/80-net-setup-link.rules存在，全文已记录；net设备的add处理路径含`IMPORT{builtin}="net_setup_link"`。基础规则入口具备。
- eth0有ID_NET_NAMING_SCHEME=v243、ID_NET_NAME_MAC=enx88a29e230117、ID_NET_DRIVER=bcmgenet；没有ID_NET_LINK_FILE，也没有ID_NET_NAME属性。addr_assign_type当前为3。

结论：**目录和udev规则入口存在；当前默认.link被屏蔽，未取得实际应用.link的证据。** 是否能用该机制在网口启用前可靠设置指定MAC，单靠本轮只读元数据**无法确定**；没有创建文件、触发udev或实测。此处仅核实前提，不提出或执行修复方案。

### 收尾与挂账

[09结束快照](../evidence/task7/r2/09_final.transport.txt)、[10 root off](../evidence/task7/r2/10_root_off.transport.txt)、[11 owner回读](../evidence/task7/r2/11_owner.transport.txt)、[核验摘要](../evidence/task7/r2/verification.txt)：本轮未创建板上临时文件，/opt/usr/lko_task7明确不存在；/proc/mounts全文前后一致，根仍rw、模块分区仍ro。根与/opt/usr的df数值也一致。SDB已root off并回读uid=5001(owner)，闭合上轮因不可达而未能完成的owner收尾。本轮未删除宿主原始证据，全部保留在temp/task7/r2。

任务7 r2只读排查完成；**配网服务的修复方案或重启验证重做，待PM决定**。不将本轮观察标为两次重启验证通过。内核替换具体执行步骤及用户待答的读卡器、U-Boot串口、测量小程序授权、冷启动电源控制、测试应用安装授权继续挂账。

## 2026-11-02 r5：重启验证重做

### PM对r4的裁定（原文）

r4 采集时 uptime 为 13170.56 秒、UTC 06:49:52，倒推开机约为北京时间 11:10；服务 ExecStart 墙钟终点为 12:10:43 KST（即北京时间 11:10:43）；boot_id 已从 0fb981c1… 变为 559cfce8…。因此 r4 所查的就是 11:09 重启后的那次开机，'约 13:12 开机'为误读（那是 journal 保留范围的起点）。该次开机中服务在 16.155–21.129 秒运行并退出 0，说明重启和配网均已完成；之后 sdb 不可达，最可能的原因是链路中断（用户随后发现网线松动、看到 NO-CARRIER），因日志已被轮转，不能完全确定。重启验证需重做。

### journald配置与授权登记

任务7 r3已登记常规授权第7–9项：测量小程序、/opt测试应用、限定路径的journald容量配置；用户手动冷启动、手边有读卡器也已记录。三项身份断言通过；用户随后明确确认“已在场、网线插牢，已接显示器，可以开始”。[在场确认](../evidence/task7/r3/user_presence.txt)、[身份](../evidence/task7/r3/07_resume_identity.transport.txt)。本轮仅第2步写入下面的配置目录/文件并修改其标签，除此之外不改文件、标签或网络；未手动执行配网脚本，未start/stop/restart/enable/disable任何服务，未daemon-reload。

写前df -k /opt的Available为**1,225,180 KiB**，大于512 MiB（524,288 KiB），故选择64M。[配置写入和回读](../evidence/task7/r3/04_config_install.transport.txt)原文：

```text
/dev/mmcblk0p3         1335696     80408   1225180   7% /opt
[Journal]
SystemMaxUse=64M
```

实际新增目录`/etc/systemd/journald.conf.d`权限0755；新增文件`/etc/systemd/journald.conf.d/50-lko.conf`权限0644，内容仅上述两行、末行换行，共27 B。目录及文件初始SMACK标签User::Shell，chsmack后均为`_`，与/etc/systemd/journald.conf相同。SHA-256：`af93a4657b122ff5aff84aaae90ce03b94747155954e04f6a539bf83445b8f5e`。set -e安装链完成、CONFIG-INSTALL-EXIT=0；权限/标签/内容/哈希均已回读，已登记RULES第9项。根挂载原为rw，未remount。

**只证明配置已正确写入，不证明新上限运行时已生效。** 未重启journald服务；随后第一次整机重启未恢复SDB，无法取得journald容量max日志，运行时上限仍待核实。

### 重启前检查与噪声基线

[第一次前置快照](../evidence/task7/r3/reboot1_before.transport.txt)与[命令时间/退出码](../evidence/task7/r3/board_commands.jsonl)：

- eth0明确含LOWER_UP，MAC=2c:cf:67:a0:72:b5；is-enabled为enabled，退出0。
- 脚本SHA-256仍为`8fecc6d0b5383b04de53bec6ac0b3e795e93c140b8d8ae0c315f6b75855a6608`，unit仍为`bb5be5756fb97065c4adb4b3df3c5041d4f6f148498ff4a9364d8e58799c5d78`；sha256sum退出0。
- boot_id=`559cfce8-46fe-49b0-97f2-2c5d18ecb275`，uptime=22563.90秒，板上date -u为2026-11-02 09:26:25 UTC。宿主操作时间以JSON的Asia/Shanghai时间为准；板上墙钟与宿主存在小幅差异，不用二者混算重连耗时。
- 用户已接显示器，但display-manager为**ActiveState=activating、NRestarts=2199**，并非active。没有操作该服务或显示相关进程。

前10分钟journal中含display-manager或Display manager共**348行**，其中“Scheduled restart job”**58行**，即窗口内约**5.8次/分钟**。首末计划重启时间为18:16:32–18:26:17 KST，计数2142→2199；57个间隔覆盖585秒，平均约**10.26秒/次**。这是重启前的噪声基线，不能当作此次新boot的频率。[完整筛选及计数](../evidence/task7/r3/reboot1_noise_summary.txt)。

最近40行反复出现以下失败原文（前置快照保留全部40行）：

```text
display-manager.service: Main process exited, code=exited, status=127/n/a
display-manager.service: Failed with result 'exit-code'.
Failed to start Display manager.
display-manager.service: Scheduled restart job, restart counter is at 2199.
```

已知直接失败形式为**主进程退出127、result=exit-code**；这些日志没有给出更底层错误，不能仅凭127断言缺少某个命令或动态库，具体原因**无法确定**。接显示器后该快照仍显示反复失败。新boot是否仍然失败、频率如何，因本次SDB不可达没有采集到。

### 第一次重启：600秒超时；第二次按条件跳过

编号：本次重做第1次（自任务7首次尝试以来第2次），原因“用户在场且确认网线插牢，配网服务自动启动验证重做”。在**2026-11-02 17:26:14.376158 +08:00**发出唯一一次`sdb -s 192.168.108.26:26101 shell reboot`，没有参数。[原因](../evidence/task7/r3/reboot1_reason.txt)、[命令](../evidence/task7/r3/board_commands.jsonl)。

该SDB客户端8秒内未返回，宿主记录HOST-SDB-TIMEOUT/124；**124是宿主传输超时，不是板上reboot退出码**。随后每10秒发起connect，并以只读`echo SDB-READY`检查shell是否可用。最初connect返回成功/已连接，但shell前5次超时，第6次target not found；第7–59次均无法取得可用会话，没有误判为恢复。[完整重连输出](../evidence/task7/r3/reconnect_attempts.txt)。

截至约**17:36:14.376 +08:00**，等待**600.0002166100312秒**仍不可达，停止全部后续板上操作。共实际发起**59次connect和59次shell探测**。原始reconnect.json中的attempts=60是循环进入截止检查时的计数，**第60次未发出命令**；该统计瑕疵原样保留，实际次数按命令日志核算，见[核验摘要](../evidence/task7/r3/verification.txt)。不修改原始结果以掩盖计数差异。

末次失败原文：

```text
connecting to 192.168.108.26:26101 ...
failed to connect to 192.168.108.26:26101
error: target not found
error: serial number '192.168.108.26:26101' wrong
```

| 验收/采集项 | 第一次重做 | 第二次重做 |
|---|---|---|
| SDB恢复 | **未满足：600秒超时** | 按条件不执行 |
| 新boot_id及重启后三项身份 | 未取得，无法验证变化 | 未执行 |
| Result=success / ExecMainStatus=0 | 未取得，不能判定脚本成功或失败 | 未执行 |
| 日志有network setup complete | 未取得新boot日志 | 未执行 |
| 重启后MAC/IP匹配 | 未取得，重启前LOWER_UP和MAC不替代 | 未执行 |
| journald运行时max=64M | 未取得，只有配置写入核对通过 | 未执行 |
| 服务耗时 | 无法计算 | 无数据 |
| multi-user.target到达−服务退出 | 无法计算 | 无数据 |
| journald/connman/multi-user/graphical/sdbd_tcp.socket/sdbd.service的ActiveEnter | 全部未取得 | 无数据 |
| display-manager新boot状态、日志行数、采集uptime及频率 | 全部未取得 | 无数据 |
| 总判定 | **未通过SDB可达性验收；其余运行结果未知** | **跳过** |

没有用r4或重启前的旧时间戳填充本次结果，也不能用上次“最可能链路中断”的PM裁定解释本次超时。达到停止条件后已向用户报告：**请在串口执行`ip link show eth0`并查看网口指示灯**。没有另行修复、重启、改网络或继续连接尝试。

### 收尾与待PM决定

本轮没有创建板上临时目录；仅保留已登记的journald配置目录及文件。宿主原始输出/准备脚本均留在temp/task7/r3，不删除历史产物；证据目录仅小体积文本，原始全文的大小、行数和SHA-256见[manifest](../evidence/task7/r3/raw_manifest.tsv)。本轮尚未取得重启后journal全文；重启前10分钟全文只留temp，入库仅相关摘录。

等待用户确认期间曾root off且回读uid5001（[05](../evidence/task7/r3/05_wait_root_off.transport.txt)、[06](../evidence/task7/r3/06_wait_owner.transport.txt)）；收到在场确认后按授权再次root on。**由于本次重启后SDB不可达，最终无法恢复并回读owner，亦无法回读新boot挂载/空间状态**。不把等待期间的owner回读当作最终收尾。此项待用户恢复及PM后续安排，本轮不突破超时停止条件。

已答复事项从STATUS待答列表移除：测量小程序/测试应用已获常规授权，冷启动由用户手动操作，读卡器可用。保留：**display-manager反复重启：用户可接显示器（本轮已接），实验期间如何处理待PM决定**；**U-Boot串口命令行能否进入，用户待测**。配网重启验收未完成、内核替换执行步骤仍待PM后续安排。
