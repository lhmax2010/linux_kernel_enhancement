# 任务24：QB 1220056 离线验收与后续上板计划

## 1. 当前结论（2026-11-06，离线阶段）

**离线核对已完成，验收未通过；暂不建议刷机开始基线测量。尚未连接开发板。** QB 的 Successful 只表示构建结束，不表示镜像满足本任务安装与启动要求。

两个待验服务在 RPM 里存在，但制镜安全检查将其移出正常 unit 目录；镜像留下两个悬空的 wants 链接。因此“服务及启动链接已正确安装”不通过。另有一项包存在性要求未满足：wlandrv-plugin-tizen 未安装；它也不在此前 1218766 的相应清单中，不是本轮新增包差异。详细路径、制镜日志、文件哈希与内部组件核对仅存本地报告。

已完成项与失败项汇总见 [offline_summary.json](../evidence/task24/offline_summary.json)。本轮不修改镜像、服务、安全策略或源码，不自行补包；先交 PM 处理上述不符项，并等待用户刷机确认。

## 2. 构建信息和来源

| 项目 | 实测 |
|---|---|
| QB | 1220056，Successful |
| 项目 | Tizen-Unified-Toolchain |
| 构建方式 | Full / Ref. Snapshot |
| 参考快照 | tizen-unified-toolchain_20261102.122237 |
| base | tizen-base-toolchain_20261030.120529 |
| 页面开始时间 | 2026-11-05 13:47:28 |
| 耗时 | 5h19m58s |
| 推算结束时间 | 2026-11-05 19:07:26，页面未标时区，非另行读取的结束字段 |
| 来源一致性 | 指定的3个源码来源，页面、source manifest 与 RPM 头全部一致；关联11个RPM头核对通过 |

与任务17留存的 1218766 设置相比，Full、Ref. Snapshot、参考/base 快照及所记录的其余变量一致；只有指定用户态组件的源码来源更新。构建号、时间、输出目录和子任务号不同。此比较覆盖已读取并留存的设置，不声称未读取的隐藏配置也完全相同。

本次公开产物目录为 `tizen-unified-toolchain_20261105.134728`。浏览器由用户在窗口内登录，未读取或记录凭据；读取完毕后正常关闭并删除临时 profile，见 [browser_cleanup.json](../evidence/task24/browser_cleanup.json)。

## 3. 包清单、实际镜像与 ABI

| 核对项 | 结果 |
|---|---|
| boot 清单与1218766比较 | 187→187，0变化 |
| headed 清单与1218766比较 | 1235→1236；5个允许包仅来源变化，新增1个预期配套包 |
| 合并去重 | 1275→1276；0删除，0预期之外的版本/来源变化 |
| 新增服务安装 | **不通过：2个正常unit文件缺失，2个wants链接悬空** |
| coregl | 镜像默认RPM数据库中0.4.0-0存在 |
| HAL mesa | HAL数据库中24.3.4-0存在 |
| libEGL.so.1 / libGLESv2.so.2 / libCOREGL.so.4 | 链接和实际目标库文件均存在 |
| wlandrv-plugin-tizen | **不通过：默认及HAL数据库未安装；两次构建的boot/headed清单均未包含** |
| 模块 vermagic | 从实际modules.img取出的59个模块全部符合 |
| 树外模块 CRC | 7模块、356项比较、253个去重符号；0不一致、0缺失 |

vermagic 为 `6.12.80-arm-rpi4-v7l SMP mod_unload modversions ARMv7 p2v8`。CRC 对照本次内核 devel RPM 中的 Module.symvers；未加载模块。上述检查不替代未来上板时的服务、显示器和运行状态验收。

为今后换内核，已从1220056的modules.img另建独立元数据基准，绑定镜像SHA：全图129条目，版本目录123条目，记录类型、UID/GID、权限及链接目标，字段兼容任务23。基准保存在本地；SR的 `evidence/task23/sr_module_reference.json` 未覆盖。

## 4. 刷机材料（已下载，等待不符项处理）

完整URL、本地路径、大小、SHA及8个img的用途/挂载点见 [刷机清单](../evidence/task24/flashing_checklist.md)。

| 归档 | 大小 B | SHA-256（与站点一致） |
|---|---:|---|
| boot-armv7l-rpi | 28,707,458 | `ac024be4b7a1b5401ac041c487c9ebaf038120c1a598c9ebd09b8e0b3e010a40` |
| headed-armv7l | 555,272,491 | `92eef40309b651d06fdba1202cb57310a187ec496abc410dab13af61bd6c2aaf` |

boot归档含boot/modules/hal；headed含rootfs/system-data/user/ramdisk/ramdisk-recovery。归档站点校验值核验通过，平台Python流式计算内部镜像哈希，debugfs只打开副本且不带`-w`；检查结束后原件与副本SHA均复核。证据：[归档](../evidence/task24/archive_checksums.json)、[分区镜像](../evidence/task24/partition_images.json)、[前后完整性](../evidence/task24/image_integrity.json)。

## 5. 资源限制、资料边界与清理

下载、解包、平台qemu/rpm/debugfs、大文件哈希及审读包打包全部经过：

```sh
systemd-run --user --scope -p CPUQuota=400% -p MemoryMax=8G nice -n 10 ionice -c3 <命令>
```

user scope可用，不需降级；实测`cpu.max=400000 100000`、`memory.max=8589934592`、nice10、I/O idle，见 [资源限制证据](../evidence/task24/resource_limit_probe.txt)。没有同时进行两个大文件解包，没有无上限线程池。

平台工具来自任务12 GBS构建根，以bwrap只读绑定，通过qemu-arm执行；ARM debugfs及必要库仅从获准固定base快照取包、校验并解包，未安装，未改构建根。工具包NVR/URL/SHA见 [tool_packages.json](../evidence/task24/tool_packages.json)。检查结束删除本轮临时工具和镜像副本，原归档/原镜像保留；清理证据见 [cleanup.json](../evidence/task24/cleanup.json)。

内部详情及命令、原始输出在 `vendor_local/task24/TASK24_REPORT.md` 和同目录证据中；GitHub只保留中性结论及Tizen公开材料。离线审读包为 `vendor_local/task24/TASK24_REVIEW.tar.gz`，不是已完成上板验收的报告。

## 6. 下一阶段及待裁决

1. PM先处理两个离线不符项。未授权临场修补镜像，本轮不修。
2. 用户明确回复“已刷好”后才开始B0。先只读核对三重身份、BUILD_ID、三包和库、根/HAL挂载、HDMI connector及display-manager；当前均未采集。
3. 新准备流程保留coregl、HAL mesa和无线驱动包，只配网/remount/扩分区，不再执行历史卸载操作。任务19旧SR采样仍仅供参考。
4. B1配网服务、B2 total_mem=1600、B3运行基线及60/600秒采样均待执行。届时按本任务要求仅用无参数reboot，5分钟重连上限；内部运行详情留本地，公开报告只更新允许的内容。
