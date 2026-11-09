# 任务27后半：板上核对与预备基线

2026-11-09。**身份和受控回收验证通过；首轮重启后五分钟无法恢复SDB，已停止板上操作。三轮Idle采集未完成。** 详细原始输出和按进程数据仅在本地`vendor_local/task27b/`，本页不含内部服务名。

## 完成情况

| 部分 | 结果 | 证据和限制 |
| --- | --- | --- |
| 身份 | 通过 | armv7l、6.12.80-arm-rpi4-v7l、Tizen；tizen-build.conf实际字段TZ_BUILD_ID为tizen-unified-toolchain_20261106.063932。先owner断言，后进入root。 |
| 准备状态 | 已记录 | MemTotal=3,976,468KiB；boot配置没有total_mem，本轮未更改。根分区、HAL初始均rw,relatime。 |
| 图形依赖 | 通过 | coregl0.4.0-0和HAL mesa24.3.4-0安装，三个图形库链接和目标存在，显示程序ldd未发现缺库。 |
| 显示 | 服务起来但无画面（软件侧判定） | display-manager active/running、0重启、退出码0，Home/launcher进程存在；两个HDMI connector均disconnected、modes为空。未取得用户实屏确认，连接检测异常原因未闭合，未修复。 |
| 评估服务 | 状态与压力路径通过 | 初始化服务active/exited，守护服务active/running、0重启；本次回收路径无open/ioctl权限失败。 |
| swap管理分离 | 运行证据符合，路径核验未全闭合 | 读取配置SwapEnable=no，运行进程maps无swap插件；实际选中文件的三个高优先级路径仍待补查。 |
| Idle三轮 | 未完成 | 第一次reboot后300秒未重连；后两次未执行，不能计算三轮均值和极差。 |
| memps | 源码口径闭合，数值对照待补 | 已取RPM指定的源码；尚未取得Idle期间memps全文及同步meminfo。 |

本地证据：`logs/04_identity_owner_recheck.txt`、`07_mounts.txt`、`08_graphics_packages.txt`、`29_display_details.txt`、`32_boot_config_read.txt`、`pressure_summary.json`、`idle1_progress.json`及`commands.jsonl`。

## 受控压力结果

使用板上已有工具解释/tmp测试脚本；/tmp的noexec属性未改。逐步分配匿名内存，目标约400MiB，保持60秒；总142秒、143样本，间隔中位数1.01秒。worker有限额和绝对寿命，低内存/OOM触发停止；只结束四个本任务测试进程，没有操作其他进程。

| 指标 | 结果 |
| --- | ---: |
| 最低MemAvailable | 394,504KiB / 385.26MiB |
| pswpout增量 | 15,084页 / 58.92MiB |
| 压缩设备原始数据增量 | 55.68MiB |
| 压缩设备实际内存增量 | 31.70MiB |
| OOM计数增量 | 0 |
| 本次服务open/ioctl权限失败 | 0 |
| 释放后MemAvailable | 3,412,744KiB |

服务回收调用与系统换出/压缩数据增长同时被观测到，可确认此次路径实际触发；没有单独隔离内核后台回收，不把全部系统增量独占归因于该服务。另有测试前即存在的其他进程SMACK拒绝，不算本服务失败。运行身份组合在此次测试中足够使用，不推导最小权限结论。所有测试进程及/tmp文件在reboot前已核验清理。

## Idle汇总与停止点

| 轮次 | 结果 | Used / PSS / GPU / 内核分项 / memps |
| --- | --- | --- |
| 1 | 18:21:54发出无参数reboot；18:26:54达到五分钟重连上限 | 未采集 |
| 2 | 未重启 | 未采集 |
| 3 | 未重启 | 未采集 |
| 均值、极差 | 无有效三轮样本 | 不可计算 |

自动配网服务不存在；静态IP配置对应手动设置的MAC，另一原始MAC配置仍为DHCP。这是重连失败的候选原因，重启后未取得板上证据，不能断言唯一根因。没有安装配网服务、修改网络、重启宿主SDB服务或继续第二次重启；需用户串口查看并恢复网络。板上重启后身份、挂载和owner状态未回读，收尾恢复状态不能确认。

## memps口径

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

`-v`走smaps，`-q`优先smaps_rollup；跳过memps自身与不可读/已退出进程（1270–1291、1569–1581）。已准备在memps前后读取meminfo和uptime的采集脚本，注明非原子读数漂移；因本次重连停止，实际数值验证和三轮分项仍待完成。

## 收尾

仅公开本页及STATUS。内部服务日志、按进程记录、逐秒样本、测试和采集脚本、memps源码摘录与执行偏差说明均在本地`vendor_local/task27b/TASK27B_REPORT.md`及审读包。初始只读采集曾遇引号和分页问题，已保留错误并修正非交互调用；未把这些错误当作板上服务故障。

宿主重任务按CPUQuota400%/MemoryMax8G、nice10、ionice-c3限额；未sudo或向宿主进程发信号。未改镜像内文件、包、标签、显示配置或总内存设置。下一步先由用户串口恢复并明确重启后网络的恢复方式，再续做三轮Idle、memps数值验证与未闭合只读项。
