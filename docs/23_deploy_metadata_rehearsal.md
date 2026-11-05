# 任务23：部署包目录权限修正与 base01 演练

2026-11-05。**制作、归档和板上元数据验收通过；base01演练通过，完整回退通过。** 最终板子为原SR内核`6.12.80-arm-rpi4-v7l` + `total_mem=1600`，10个原有模块全部加载，stability-monitor/resourced正常，root和模块分区只读，SDB恢复owner。未改SMACK标签、display-manager或coregl，未重新构建内核、未安装RPM。

## 1. 制作工具修正与证据

基于任务9原RPM重新解包；原archive和原stage保留。参考为官方SR QB1218764的`temp/task17/sr/modules.img`，SHA256 `d0ec6f50ceb59c6f8a4cf3d901df221449705b63bad3db3b69e2c95ed86e939f`。用同平台ARM debugfs逐目录只读`ls -p`/`stat`/`cat`，取得123个条目（含版本根）的类型、uid/gid、模式和build链接目标；未用宿主分析工具、未读写挂载镜像。原镜像操作后SHA不变。[参考清单](../evidence/task23/sr_module_reference.json)、[命令和输出](../evidence/task23/reference_commands.txt)、[工具包固定URL/NVR/SHA](../evidence/task23/tool_packages.json)、[操作后SHA](../evidence/task23/final_original_hashes.txt)。

任务9的`extract_artifacts.py`、`make_deployment.py`、`verify_deployment_archive.py`及平台调用包装均已修正；公开副本在[scripts/deploy/task9](../scripts/deploy/task9/)，与本地任务9文件逐字一致。共同实现为[module_metadata.py](../scripts/deploy/module_metadata.py)，板上回读验证调用同一实现。实际RPM解包输出和命令保留在`temp/task23/artifacts/verify/`，不修改旧归档。

关键差异如下（完整diff见链接）：

```diff
 # RPM解包完成后，校正包括cpio自动创建父目录在内的版本树
+normalize(version_tree, official_reference)
 # 合并extra之后继续沿用任务9的平台depmod
+depmod -b payload 6.12.80-arm-rpi4-v7l-lko-base01
+normalize(payload_version_tree, official_reference)
+rows = scan(payload)  # 类型、uid/gid、模式、链接目标、SHA256
+assert check(rows, official_reference, release)['pass']
+assert all_regular_file_hashes == original_task9_verified_hashes
 # 归档不跟随符号链接；归档后再次读取成员验收
+assert verify_archive(archive, rows, official_reference, release)['pass']
```

[解包diff](../evidence/task23/extract_artifacts.py.diff.txt)、[组装/归档diff](../evidence/task23/make_deployment.py.diff.txt)、[归档验收diff](../evidence/task23/verify_deployment_archive.py.diff.txt)、[平台包装diff](../evidence/task23/platform_tools.py.diff.txt)。

同名路径按官方数字元数据处理；官方没有的新目录root:root/0755、新普通文件root:root/0644。符号链接不解引用，必须保留官方字面目标；未参考的新链接拒绝。文件不递归加执行位。所有`.ko`对others可读，从版本目录根到它的每级目录对others有x。归档清单与实际成员逐项完全相同才通过。

不使用宿主sudo：平台工具在只读GBS root内经qemu-arm执行；`bwrap --unshare-user --uid 0 --gid 0`仅建立非特权用户命名空间的root，宿主文件仍归运行用户。这样可在namespace内设置和检验数字root:root并归档，板上由root解包还原。宿主Python只做调度、文件整理和报告。内核源码未修改，未运行GBS。

### 1.1 检查发现与处理留痕

- 本次解包复现外部RPM自动父目录0700；校正记录含版本根、extra、extra/kdbus、extra/zlogger。最终组装版本根来自内核RPM，本来为0755。[解包校正](../evidence/task23/external_modules_normalize.txt)
- 第一次组装被74文件内容比较拦下：四个索引仍为仅内核模块的RPM索引。补齐原任务9已有的“合并extra后depmod”步骤，四索引与旧合格载荷完全一致后才继续；首次失败输出和目录保留，未部署。[首次失败](../evidence/task23/make_deployment_r2.txt)、[四索引差异](../evidence/task23/platform_payload_difference.txt)、[depmod](../evidence/task23/depmod.txt)
- 官方build链接长度68字节，不是fast symlink；首次参考读取未取到目标而停止，随后用只读debugfs cat读取链接本体。未解析或访问该链接指向的构建路径。
- 板上预检中两个字符串匹配问题均在写boot/模块前停止：身份输出首行没有前导换行；`mmcblk0p1`未锚定时误匹配`mmcblk0p10`。修正为逐行身份匹配、完整设备字段匹配后继续，实际身份和分区状态未变。[预检记录](../evidence/task23/board_02_identity.txt)、[首次设备匹配](../evidence/task23/board_06_boot_preflight.txt)、[修正后的预检](../evidence/task23/board_06b_boot_preflight.txt)

## 2. r2包与验收

本地目录：`temp/task23/artifacts/deploy_lko-base01-r2/`。

| 项目 | 结果 |
|---|---|
| 归档 | deploy_lko-base01-r2.tar.gz |
| 大小 | 15,991,422 B |
| SHA256 | `c88dad7d83734f7edad66e49e5712b6d71da7e529e4cacf5ce651e5918b8ea14` |
| 全部条目 | 127：52目录、74普通文件、1符号链接 |
| 模块 | 59个`.ko`，59条路径可达性通过 |
| 内容 | 74普通文件与原任务9逐字节哈希相同，包含14个索引；zImage/模块代码未改 |
| DAC | 所有条目root:root；目录0755、普通文件0644、链接0777 |
| build链接 | 保留原构建目录字面目标，不跟随、不随包带devel树 |

[逐条元数据](../evidence/task23/deployment_metadata.json)、[74文件SHA](../evidence/task23/deployment_SHA256SUMS.txt)、[验收结果](../evidence/task23/deployment_acceptance.json)。旧归档`583fbb45…`仍在原路径，SHA不变，旁置DO_NOT_USE.txt，docs/14已标“权限缺陷，不再使用”。新验收还识别了旧归档外层目录0775、zImage0664，本次一并按通用规则校正。

测试使用平台Python执行同一实现，6项全部符合预期：[完整结果](../evidence/task23/metadata_tests.json)、[测试源码](../scripts/deploy/tests/metadata_tests.py)。

| 用例 | 预期/实际 |
|---|---|
| r2完整归档 | 通过/通过 |
| 旧归档 | 拒绝/拒绝，命中三个0700目录等 |
| 目录去掉others x | 拒绝/拒绝 |
| `.ko`去掉others r | 拒绝/拒绝 |
| 目录uid改为1000 | 拒绝/拒绝 |
| build链接改目标 | 拒绝/拒绝 |

## 3. 板上复制与重启前门槛

先做armv7l、rpi4、Tizen三重身份断言，确认原SR、原boot_id `efb329ce-c985-4835-8124-e7a98c8b4aeb`、MemTotal 1,507,996 KiB、10模块及关键服务正常，模块分区可用14,648 KiB、8,054空闲inode。新版本目录和`/opt/usr/lko_task23`均不存在。

依据docs/11附录+docs/14：只读挂载boot备份zImage/DTB/config，记录414个boot文件、75个原模块/共享配置文件SHA，以及127条原模块树元数据。逐条新增路径/回退计划见[change_plan](../evidence/task23/board_change_plan.json)；原文件备份只留temp。新内核只改zImage，保留zImage.orig；不改DTB、overlays、config.txt及原模块版本/共享配置。

r2解包SHA通过后，只把新版本目录复制入模块分区，立即恢复ro。**板上回读123条新模块树元数据与归档零差异，59个`.ko`可达性再次通过**，才替换zImage和重启。未在板上chmod/chown/chsmack补救。[回读原文](../evidence/task23/board_15_new_metadata.txt)、[同一实现的门槛结果](../evidence/task23/board_metadata_gate.json)、[复制/只读恢复](../evidence/task23/board_14_copy_modules.txt)。板上新目录du=4,468 KiB，df可用10,668 KiB；与宿主du统计不同，不把它当运行时内存。

## 4. 演练验收及完整回退

两次均只执行无参数`reboot`，串行disconnect/connect/只读探测，300秒截止。未调用kill-server、未发信号、未手动加载模块或重启服务。[第一次重连](../evidence/task23/board_reboot1_reconnect.json)、[回退重连](../evidence/task23/board_reboot2_reconnect.json)。

| 项目 | base01 | 回退原SR |
|---|---|---|
| reboot开始（北京时间） | 23:13:13 | 23:15:56 |
| SDB重连耗时 | 62.37秒 | 56.93秒 |
| boot_id | 8701dafa-c547-43fb-adf0-36ea312ad9c9 | b1cfa3f3-276f-42e7-adc6-148df9cc4ee1 |
| uname -r | 6.12.80-arm-rpi4-v7l-lko-base01 | 6.12.80-arm-rpi4-v7l |
| 原有10模块 | 全部加载，含proc_tsm | 全部加载，含proc_tsm |
| vermagic | 10/10精确匹配base01 release | 10/10精确匹配原release |
| stability-monitor | active/running，exit0，NRestarts0 | 相同 |
| resourced | active/running，exit0，二进制SHA未变 | 相同 |
| systemctl --failed | 0 | 0 |
| 网络 | LOWER_UP，固定MAC/IP，SDB可连 | 相同 |
| dmesg符号错误 | 无Unknown symbol/CRC disagreement/invalid format | 相同 |
| MemTotal | 1,507,996 KiB | 1,507,996 KiB |
| 结论 | **通过** | **通过** |

详细判定：[base01](../evidence/task23/board_20_base01_summary.json)、[回退](../evidence/task23/board_30_rollback_summary.json)。base01 dlog出现`Registered raw data provider: proc_tsm`及tsm_cpu/tsm_mem/tsm_io/tsm_fd注册，表明原先失败的模块访问/初始化路径已工作。[dlog](../evidence/task23/board_20_base01_stability_dlog.txt)。unit journal当时无条目，未用无日志替代运行状态；dlog另有短命进程`/proc/<pid>/status`消失记录，未造成服务退出。

display-manager的已知问题仍保留：base01采集时activating/auto-restart、exit127、NRestarts6；回退时同状态、NRestarts4。`--failed`快照为0不代表它已修复，本轮没有停用、屏蔽或安装coregl。[base01](../evidence/task23/board_20_base01_display-manager.txt)、[回退](../evidence/task23/board_30_rollback_display-manager.txt)。

回退将zImage.orig恢复为zImage，sync卸载boot、重启原内核。确认原运行态后移除本轮新版本目录并恢复模块分区ro：

- 414个boot文件、75个原模块/共享配置文件哈希全部与开始相同；原build链接目标相同。
- 原模块树127条类型/uid/gid/权限全部相同；新版本目录和zImage.orig均不存在。
- 原zImage SHA `d5345f13eada3a3aab8b2fca9f511c608469f708d83a6a2445882e68241cc9af`；DTB SHA `a0561668ec520b0605cdc8b7be6844365ce44f569f363e85f3d7332e1989d6ed`；config.txt SHA `7ecdb662716cab1532da77ff755912775284eb3aab5e3c89fd571dba854f7d07`，保留total_mem=1600。
- `/opt/usr/lko_task23`已整体删除；`/opt/usr`可用115,421,468 KiB、模块分区14,648 KiB，均回到开始值；按挂载点比较mounts无变化（行顺序不计），root/模块/HAL为ro。
- `sdb root off`后回读uid5001(owner)，原SR内核。

[完整回退汇总](../evidence/task23/board_final.json)、[boot哈希](../evidence/task23/board_34_boot_final.txt)、[模块哈希](../evidence/task23/board_32_original_modules_final.txt)、[元数据](../evidence/task23/board_33_original_metadata_final.txt)、[空间/mounts对照](../evidence/task23/mount_space_comparison.json)、[清理](../evidence/task23/board_35_cleanup.txt)、[owner](../evidence/task23/board_37_owner_final.txt)。

## 5. coregl来源补充与后续测量

用户确认其刷机准备脚本卸载wlandrv-plugin-tizen、HAL mesa、coregl，并remount根及HAL为rw、执行osu --resize。docs/20与docs/22已更新为“刷机后由用户的板子准备脚本卸载”，关闭来源未知挂账。当前只读查询三个包均未安装，逐项退出1；本轮没有安装或卸载。[查询](../evidence/task23/board_05_removed_packages.txt)

按用户决定：下次刷机准备只扩分区和安装lko-net-setup，不再卸载这三个包；任务19缺coregl/mesa时的SR测量**仅供参考**。正式测量需重新刷官方镜像并重采。本次演练证明部署方法可行，不替代正式测量资格。

全部命令和原始文本的大小/行数/SHA见[清单](../evidence/task23/raw_output_manifest.json)；板上命令和返回码见[commands](../evidence/task23/board_commands.jsonl)。平台原始输出和备份在temp/task23，二进制不入库；临时下载/解包的Task23工具目录已删除，原GBS工具、原镜像与两版部署归档均保留。平台Python语法检查通过，见[语法检查](../evidence/task23/source_syntax_check.txt)和[清理记录](../evidence/task23/cleanup.json)。无需PM再裁决权限修法；后续为按已验证门槛部署及重新采集正式基线。
