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
