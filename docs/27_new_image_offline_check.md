# 任务27前半：QB1220670离线核对

2026-11-09。**离线验收通过，可以交用户烧录；本任务未连接开发板。** 本结论不代替刷机后的身份、服务运行和网络核验。详细来源表、unit及执行证据只保存在本地`vendor_local/task27/`。

## 逐项结果

| 项目 | 结果 | 依据与边界 |
| --- | --- | --- |
| 1. 构建状态与设置 | 通过 | Successful；Full / Ref. Snapshot；参考20261102.122237、base20261030.120529；显式输入恰好四项，对照1220056仅增加批准的安全配置项目。生成的编号、时间和输出路径另记。 |
| 2. 来源链 | 通过 | 页面、source manifest、12个相关RPM头一致；两个安全配置RPM均为任务26指定的新来源，无旧来源混入。 |
| 3. 官方包清单 | 通过 | boot 187→187，headed 1236→1236；分别只有1个、2个安全配置系列包的来源变化；其余0新增、0删除、0版本或来源变化。 |
| 4. 制镜服务准入 | 通过 | 两个待验unit不再隔离；生成名单268行、与任务26预期逐字一致；正常路径unit与RPM一致，两个wants均解析到存在文件；其余仍为预期3个service及2个socket。 |
| 5. 内核与模块 | 通过 | 实际modules.img中59模块vermagic全符；7树外模块356项CRC比较、253去重符号，0缺失、0不一致；逐项结果与任务24相同。 |
| 6. 图形依赖 | 通过 | 默认RPM库有coregl 0.4.0-0，HAL库有mesa 24.3.4-0；EGL/GLESv2/COREGL三个链接及目标文件完整。未做运行测试。 |
| 7. 烧录归档 | 通过 | boot/headed原件与站点SHA一致，收尾哈希复核不变；原件留存。 |
| SR1218764补查 | 通过 | 旧SR制镜日志及哈希核对过的镜像隔离目录均只有五个通用条目，无resourced、无额外条目。 |

构建页面记录开始2026-11-06 06:39:32、耗时5:22:17，据此计算结束12:01:49；摘录未给出明确时区，不作时区换算。页面输入与运行期展开的包列表分开检查：后者两次均1030项，仅批准项目来源变化。初次本地检查把展开列表误当四条输入，已修正验证对象并保留初次错误与复核记录；未更改或放行镜像不符项。

## 安全检查与SR补查

新headed日志4356–4362行、旧SR日志4353–4359行以及两镜像隔离目录，剩余条目完全相同：

- privilege-checker-integrity.service
- systemd-bless-boot.service
- systemd-boot-system-token.service
- amd-tizen-action-service.socket
- tizen-watcherd.socket

未放宽安全检查，也未处理其他service/socket挂账。新boot日志没有该检查段；本轮服务准入结论来自headed制镜日志及实际rootfs/system-data内容。

## 烧录清单

两个归档配套使用，本轮只列清单，不执行烧录。原件保存在工作区`vendor_local/task27/download/`；内部镜像检查详情不上传。

- 文件：`tizen-unified-toolchain_20261106.063932_tizen-boot-armv7l-rpi.tar.gz`
  - 大小：28,706,356 B
  - SHA-256：`332239b30a42ba2b09390f3bf882d87f503c8be1e4ded01954482be3430a4e5d`
  - 下载：[站点原件](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261106.063932/images/standard/tizen-boot-armv7l-rpi/tizen-unified-toolchain_20261106.063932_tizen-boot-armv7l-rpi.tar.gz)

- 文件：`tizen-unified-toolchain_20261106.063932_tizen-headed-armv7l.tar.gz`
  - 大小：551,587,582 B
  - SHA-256：`e2ded03698d9fae05d327b83f8886d56c6cb8eea9691725aa3a7640ece6ee73a`
  - 下载：[站点原件](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261106.063932/images/standard/tizen-headed-armv7l/tizen-unified-toolchain_20261106.063932_tizen-headed-armv7l.tar.gz)

boot归档包含boot/modules/hal镜像；headed包含rootfs/system-data/user/ramdisk/ramdisk-recovery。各成员哈希在本地`partition_images.json`，完整清单见本地`FLASHING_CHECKLIST.md`。

## 证据与后续

本地证据索引：`settings_check.json`、`source_manifest_check.json`、`rpm_headers.json`、`package_comparison.json`、`security_log_section.txt`、`image_checks.json`、`abi_check.json`、`abi_vs_task24.json`、`graphics_check.json`、`sr_supplement.json`、`image_integrity.json`及`logs/`。审读包为`vendor_local/task27/TASK27_REVIEW.tar.gz`，摘要与校验值保留在同目录。

重负载均经CPUQuota=400%/MemoryMax=8G的systemd用户scope、nice10、ionice-c3；未并发大文件解包。平台分析经只读GBS根、bwrap和qemu-arm；临时ARM工具按固定快照校验后解包，检查后清理。镜像副本只读打开，所有原件哈希复核不变。浏览器正常关闭、临时profile删除。未sudo、未发信号、未连板、未修改镜像/源码或推送sandbox。

下一步：等待用户刷机后另行核验实际身份、运行时标签和服务状态。旧QB1220056的隔离失败保留为历史；本轮新镜像已闭合离线阻塞。正式测量准备仍不卸载图形相关包，任务19旧采样仍仅供参考。
