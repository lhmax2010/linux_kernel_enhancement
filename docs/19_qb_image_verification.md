# 任务17：QB 两镜像产物核验（2026-11-05）

## 1. 结论与边界

两构建均为 **Successful**；QB页面、公开目录、源清单、镜像包清单和RPM头组成的来源链已闭合。两套内核/模块静态ABI检查通过，resourced均为任务15修复版。

<span style="color:red">🔴 SR偏离预期：linux-tizen-modules并非直接复用现成RPM，而是本次从458baad02d812098938663971d1b8560a4813375重编；也不同于此前36d0925699ac0ffc1ce3854ed838a48d24a56c28来源。CRC通过不等于模块行为相同，该来源/复用偏差须PM裁决。</span>

类产品指定来源及本次重编要求全部满足，不触发“模块CRC不匹配、镜像不可用”的判定。实际启动、模块加载、swap和回收行为仍待上板验证。本轮未连板、构建、sudo、触发QB或推Gerrit。

详细证据：[SR](../evidence/task17/sr/)、[类产品](../evidence/task17/vbase/)。类产品配置全文、逐项CRC及内核构建日志仅保留在vendor_local/task17/vbase；公开材料只含通用核验、来源和计数。

## 2. 构建页面与公开目录

用户在可见浏览器窗口登录；仅提取允许的构建表格/变量，不读取账号输入、cookie、token或请求头，不保存会话凭据。首个会话提前关闭后重新打开完成读取。最终浏览器正常关闭，temp/task17/browser-profile已删除，见[清理记录](../evidence/task17/browser_cleanup.json)。匿名overview跳转signin、REST返回401仅表示需要登录。

| 构建 | 状态 | 页面Begin Date | 页面Duration | 结束：开始＋时长计算 |
|---|---|---|---|---|
| [SR 1218764](https://quickbuild.tizen.org/build/1218764/overview) | Successful | 2026-11-04 16:07:09 | 5 hours 22 minutes 38 seconds | 2026-11-04 21:29:47 |
| [类产品 1218766](https://quickbuild.tizen.org/build/1218766/overview) | Successful | 2026-11-04 16:08:25 | 5 hours 19 minutes 23 seconds | 2026-11-04 21:27:48 |

页面未标注时区，也未单列结束墙钟，上表结束是计算值。结合包日志UTC时间和镜像生成时刻，**推测**页面时区为UTC，不将推测写成QB明示值。原文见[sr/qb_page_text.txt](../evidence/task17/sr/qb_page_text.txt)、[vbase/qb_page_text.txt](../evidence/task17/vbase/qb_page_text.txt)。

两者项目Tizen-Unified-Toolchain，Full / Ref. Snapshot；PROJECT_BRANCH=tizen、USE_BRANCH_POLICY=false。profile来源tizen-unified-toolchain_20261102.122237，base来源tizen-base-toolchain_20261030.120529。包仓库standard；本次核验/烧录组合为armv7l的tizen-boot-armv7l-rpi＋tizen-headed-armv7l，与此前RPi4 headed用途一致。QB三包构建子项Succeeded、六镜像子项全部SUCCESSFUL。

公开目录：

- SR：[tizen-unified-toolchain_20261104.160709](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261104.160709/)。
- 类产品：[tizen-unified-toolchain_20261104.160825](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261104.160825/)。

每构建全部六份镜像archive的文件名、大小、URL、站点SHA256SUMS和生成时刻见两证据目录all_image_artifacts.json。本次实际下载四份armv7l boot/headed archive并逐字节校验；其余八份只记录公开大小/校验值，未下载或声称实测。4份archive、22份目标RPM、4份额外debuginfo RPM均通过仓库大小/SHA检查。镜像清单.packages、source manifest和选定BUILD_PKG_LIST已保存。

## 3. 源码与RPM身份

| 对象 | SR | 类产品 | 判定 |
|---|---|---|---|
| linux-rpi：kernel/modules/devel/RT kernel，6.12.80-0 | 0fac5de6a63091d141ad1cd3ed9d9e92b8dde708 | b11f669e0cb1c1e26d878430b998d6486c5476a1 | 符合 |
| resourced系列五包，10.0.0-1 | 94d346c306233803661e8eab8557596549d82be4 | 同左 | 五包全部符合 |
| linux-tizen-modules-rpi4，11.0.0-0 | 458baad02d812098938663971d1b8560a4813375 | 36d0925699ac0ffc1ce3854ed838a48d24a56c28 | SR复用预期不符；类产品符合 |
| linux-tizen-modules-source，11.0.0-0 | 25797e8af7ed95a5783bbe84c11959560aaf7e92 | 同左 | 仓库来源一致 |

五个用户态包是resourced、resourced-bin、resourced-config、resourced-isu、resourced-watchdog-handler。证据：各目录source_manifest_excerpt.txt、rpm_headers.json、boot.packages、headed.packages和QB变量。devel、modules-source、RT为同仓库配套分析包，不把它们误称为普通镜像已安装包；安装集以.packages为准。RPM BUILDTIME=0是可复现构建字段，不用它推断“没重编”。

SR模块日志原始第6/470/763行：2026-11-04 17:44:10 UTC开始、对普通devel执行make、17:45:49结束。类产品第6/260/554行：17:51:07开始、对普通devel执行make、17:52:55结束，均在对应构建时间窗内。见[sr摘录](../evidence/task17/sr/modules_buildlog_excerpt.txt)、[类产品摘录](../evidence/task17/vbase/modules_buildlog_excerpt.txt)，包含完整日志URL/SHA和原行号。类产品**确实本次重编**，CRC进一步确认其配套关系。

## 4. 内核版本、配置与体积

分析均使用任务9/12对应GBS buildroot的工具，经bwrap＋qemu-arm运行；没有用宿主编译器/binutils。平台rpm/rpm2cpio/cpio读取RPM，平台Python解压zImage gzip载荷并识别真实Linux版本；平台modinfo/modprobe、readelf/nm检查模块和ELF。完整入口命令见两目录commands.txt；通用实现见[kernel_audit_platform.py.txt](../evidence/task17/kernel_audit_platform.py.txt)。

| 普通版 | SR | 类产品 |
|---|---:|---:|
| zImage字节 | 14,905,760 | 14,927,712 |
| 本地对应zImage字节 | 14,906,368 | 14,928,528 |
| QB减本地（B） | -608 | -816 |
| QB减本地（%） | -0.004079 | -0.005466 |
| diffconfig差异行数 | 0 | 0 |
| 配置逐字节一致 | 是 | 是 |

普通release均6.12.80-arm-rpi4-v7l，RT均6.12.80-arm-rpi4-rt-v7l，无-lko-后缀；banner均Clang/LLD22.1.8。RT仅核对版本（大小/哈希留底），未做RT模块或配置验收。

普通.config与对应本地配置**0差异、字节相同**，LOCALVERSION也无差异；本地后缀由spec/环境传入，不要求写回.config。版本、构建身份变化与608/816B的小幅压缩映像差相容，但本轮没有证明全部差异仅由某个版本字符串导致。每个映像SHA、版本banner（构建账号/主机已脱敏）和配置SHA见两目录kernel_summary.json。

## 5. 模块配套

每套52个内核模块＋7个树外模块全部核对，59个vermagic均为：

    6.12.80-arm-rpi4-v7l SMP mod_unload modversions ARMv7 p2v8

平台modprobe --show-modversions读取7模块__versions，与该镜像devel中的Module.symvers逐符号比较CRC；不一致列表为空，缺失0。

| 树外模块 | 每镜像CRC项数 | SR不一致 | 类产品不一致 |
|---|---:|---:|---:|
| dm-bow.ko | 56 | 0 | 0 |
| extcon-usb-fixed.ko | 9 | 0 | 0 |
| inform-reboot.ko | 16 | 0 | 0 |
| kdbus.ko | 154 | 0 | 0 |
| logger.ko | 42 | 0 | 0 |
| proc-tsm.ko | 26 | 0 | 0 |
| zlogger.ko | 53 | 0 | 0 |
| 合计 | **356（253个去重符号）** | **0** | **0** |

见[sr/module_counts.json](../evidence/task17/sr/module_counts.json)、[vbase/module_counts.json](../evidence/task17/vbase/module_counts.json)。这是镜像包清单对应RPM载荷的静态核验，不是板上加载测试。archive内部各分区已流式计算哈希，但未挂载分区逐文件核对载荷，不把这些结论扩大为运行时成功。

## 6. resourced修复确认

两套五包VCS均94d346c3；主二进制/usr/bin/resourced均93,844B，与任务15相同。主程序、private API库和swap插件整文件SHA与本地不同，但**所有具有文件载荷的SHF_ALLOC段逐段大小/字节哈希均与任务15相同**。不以NOBITS段的“字节”作比较；非加载调试链接不影响该一致性结论。见resourced_sections.json及[段比较程序](../evidence/task17/resourced_sections_platform.py.txt)。

发布ELF已strip，无完整.symtab；本次下载同仓库debuginfo，用.gnu_debuglink文件名与CRC32绑定至确切二进制，再用平台nm读符号。两套均有swap_activate_act、high_mem_control、cgroup_write_node_uint32、fwrite_str、四个fread_nth_*、swap_zram_activate；swap_activate_in_module与swap_early_reclaim_memcg无独立函数符号（后者仅留同名静态变量），不伪报为存在。优化可能合并静态函数，修复存在性还由来源、加载段一致性和新增字符串交叉确认。

“Cannot apply configured algorithm %s; retaining kernel algorithm %s”在两套**swap插件**和任务15插件中均存在，不在主可执行文件。两镜像均为修复版，不能仅因NVR仍为10.0.0-1或主程序strings无该字符串而判定旧版。证据见各目录resourced_summary.json、resourced_sections.json、debug_downloads.json。

## 7. 完整安装包差异

对boot＋headed的完整.packages按包名/架构合并，每边1275包；新增0、删除0，版本/来源不同3包：

| 包 | NVR | 来源变化（SR→类产品） |
|---|---|---|
| arm-rpi4-linux-kernel | 均6.12.80-0 | 0fac5de6→b11f669e |
| arm-rpi4-linux-kernel-modules | 均6.12.80-0 | 0fac5de6→b11f669e |
| linux-tizen-modules-rpi4 | 均11.0.0-0 | 458baad0→36d09256 |

其余1272包版本/来源一致，**没有内核和模块类别之外的意外差异**。见[package_comparison.json](../evidence/task17/package_comparison.json)及四份完整.packages。范围为所选RPi4 armv7l boot/headed组合，未声称六profile全量比较；同版本/来源也不保证所有RPM或整个rootfs位级相同。模块来源不同仍可能影响对照，SR偏差需PM接受。

## 8. 烧录清单（只准备、不执行）

按此前RPi4 headed用途选择**同构建的一对archive**，不混用SR与类产品boot/modules/rootfs。当前组合实际为分区镜像集合，没有发现整卡镜像。以下不含任何设备写入命令，实际烧录由后续任务安排。

### SR / 1218764

- [tizen-unified-toolchain_20261104.160709_tizen-boot-armv7l-rpi.tar.gz](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261104.160709/images/standard/tizen-boot-armv7l-rpi/tizen-unified-toolchain_20261104.160709_tizen-boot-armv7l-rpi.tar.gz)
  - 大小：28,695,321 B；SHA-256：6cf9857866692ed51c540c7d51508c8e7ce27ba4fab3204db87c04be1eb1b01e。
  - 下载位置：$WS/temp/task17/sr/images/tizen-unified-toolchain_20261104.160709_tizen-boot-armv7l-rpi.tar.gz；站点SHA与实测一致。
- [tizen-unified-toolchain_20261104.160709_tizen-headed-armv7l.tar.gz](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261104.160709/images/standard/tizen-headed-armv7l/tizen-unified-toolchain_20261104.160709_tizen-headed-armv7l.tar.gz)
  - 大小：550,716,734 B；SHA-256：68fe480cf0fa2e9107327ccfc0eb94e6b6aad7fa632f694620a5a8a8cc8abc01。
  - 下载位置：$WS/temp/task17/sr/images/tizen-unified-toolchain_20261104.160709_tizen-headed-armv7l.tar.gz；站点SHA与实测一致。
### 类产品 / 1218766

- [tizen-unified-toolchain_20261104.160825_tizen-boot-armv7l-rpi.tar.gz](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261104.160825/images/standard/tizen-boot-armv7l-rpi/tizen-unified-toolchain_20261104.160825_tizen-boot-armv7l-rpi.tar.gz)
  - 大小：28,716,977 B；SHA-256：1de3c0101266198be4645e96229f6636e770fddd91ff63d6ddcd05360c173358。
  - 下载位置：$WS/temp/task17/vbase/images/tizen-unified-toolchain_20261104.160825_tizen-boot-armv7l-rpi.tar.gz；站点SHA与实测一致。
- [tizen-unified-toolchain_20261104.160825_tizen-headed-armv7l.tar.gz](https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261104.160825/images/standard/tizen-headed-armv7l/tizen-unified-toolchain_20261104.160825_tizen-headed-armv7l.tar.gz)
  - 大小：549,232,942 B；SHA-256：aaa91350f47c7a89f2d44561531791c3bc83e38316e2e318ffa4c13ac0511904。
  - 下载位置：$WS/temp/task17/vbase/images/tizen-unified-toolchain_20261104.160825_tizen-headed-armv7l.tar.gz；站点SHA与实测一致。

两构建archive成员名相同，挂载位置由manifest/KS/XML给出：

| archive | 文件 | 用途/挂载位置 |
|---|---|---|
| boot-armv7l-rpi | boot.img | boot（/boot） |
| boot-armv7l-rpi | modules.img | 模块（/lib/modules） |
| boot-armv7l-rpi | hal.img | HAL（/hal） |
| headed-armv7l | rootfs.img | 根文件系统（/） |
| headed-armv7l | ramdisk.img | initrd（/mnt/initrd） |
| headed-armv7l | ramdisk-recovery.img | recovery initrd（/mnt/initrd-recovery） |
| headed-armv7l | system-data.img | /opt |
| headed-armv7l | user.img | /opt/usr |

每个内部镜像的精确字节数/实测SHA-256见[sr/partition_images.json](../evidence/task17/sr/partition_images.json)、[vbase/partition_images.json](../evidence/task17/vbase/partition_images.json)。平台Python流式遍历整个archive计算全部分区哈希；仅将boot.img/modules.img另行解出，其余保留在archive中。分区名到实际刷机工具/物理槽位的映射不在本轮执行范围，不凭清单擅自烧录。

## 9. 收尾与待裁决

已完成页面核对、公开下载、来源/配置/ABI/resourced检查、包清单比较和烧录准备。下载/原始输出在temp/task17，类产品敏感分析在vendor_local/task17，GitHub仅小体积文本。检查见[final_checks.json](../evidence/task17/final_checks.json)。

待PM接受或处置SR模块重编及458baad0来源偏差；实际uname/config、模块加载无CRC/Unknown symbol错误、resourced来源、/proc/swaps与回收写入仍待上板核验，未在本轮完成。
