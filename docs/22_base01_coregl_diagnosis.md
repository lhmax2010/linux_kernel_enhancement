# 任务22：base01 部署失败与 coregl 缺失的只读诊断

## 结论

**base01 的可确定部署缺陷是 DAC 目录权限：部署归档将 `extra/`、`extra/kdbus/`、`extra/zlogger/` 保存为 root:root、0700，官方镜像这三个目录是 root:root、0755。** stability-monitor 以 UID/GID 204 运行，没有 CAP_DAC_OVERRIDE/CAP_DAC_READ_SEARCH，无法穿越 0700 的 `extra/` 来打开 proc-tsm.ko；模块文件本身 0644、SMACK 允许读取、具备 CAP_SYS_MODULE 均不能补足目录搜索权限。任务19的 tar 解包及 cp -a 保留此模式。两边模块路径完整、全部14个索引逐字相同、proc-tsm 的26项CRC均匹配，已具备明确的离线原因，按任务要求**跳过 C，不重做换内核或修复验证**。

**SR 1218764 和类产品 1218766 的官方 headed 镜像均实际包含 coregl，缺失发生在官方镜像产出之后。** 本板当前确实缺包、缺库；D 已执行，但可用日志和所查启动脚本没有删除动作证据，**谁、何时、通过哪个流程删除仍无法确定**。不能归因于用户手动卸载，也不能排除刷写流程、首次准备或其他未留存操作；这些仅是待查范围。

本轮未修部署包/权限/标签，未安装包、修改服务/网络、重启或发送信号。结束仍是原 SR 内核、既有 total_mem=1600 状态（MemTotal 1,507,996 KiB），owner 已恢复。未部署，故没有本轮回退动作或“回退通过”的新结论。

## 1. 输入身份与只读工具

首先按既有记录重新计算 SHA-256：

| 输入 | SHA-256 |
|---|---|
| base01 部署归档（15,990,491 B） | `583fbb45389f3b98a8498c09f4acb9a2a73a4b074439bdae6df663cbeaeeb61c` |
| SR headed 归档 | `68fe480cf0fa2e9107327ccfc0eb94e6b6aad7fa632f694620a5a8a8cc8abc01` |
| 类产品 headed 归档 | `aaa91350f47c7a89f2d44561531791c3bc83e38316e2e318ffa4c13ac0511904` |
| SR modules.img | `d0ec6f50ceb59c6f8a4cf3d901df221449705b63bad3db3b69e2c95ed86e939f` |

[归档身份](../evidence/task22/archive_identity.json)、[system-data身份](../evidence/task22/system_data_identity.json)。rootfs 和 system-data 从已核对归档解出，再复制为 `.readonly-copy` 后检查；没有挂载镜像。

分析使用任务9 GBS root 的 rpm/rpm2cpio/cpio/tar/depmod/modprobe/modinfo/strings/sha256sum，以及此前从该root缓存恢复的平台Python，经 bwrap + 该root的 qemu-arm。宿主Python只作调度、文本整理和文件复制。现有root缺 debugfs/7z，获PM补充授权后，从**固定 base 20261030.120529** 的 repomd/primary 获取以下 ARM 包，仅 rpm2cpio+cpio 解到 `temp/task22/tools/`，未安装RPM、未写任何GBS root：

| 工具包 NVR（armv7l） | 元数据与下载文件一致的 SHA-256 |
|---|---|
| e2fsprogs-1.46.0-1.9 | `27dbbaf622374c3a13c52abe82bc161d69a2318a58736bb6af0ec152198553c1` |
| libcom_err-1.46.0-1.9 | `96acda0cce46f821d5f2481c5ee1569640531b3c527cf75061887d238320d45e` |
| libext2fs-1.46.0-1.9 | `850a154a717d1f8356abc6db278ab9e5516d498679695262d52577cca1c5d159` |

[完整URL/NVR/元数据SHA](../evidence/task22/tool_packages.json)、[平台debugfs版本与命令](../evidence/task22/debugfs_version.txt)。此前旧缓存发现的1.8候选未下载/使用；实际采用上述固定快照的1.9。debugfs 始终不带 `-w`，仅 ls/stat/dump/rdump；LD_LIBRARY_PATH只增加任务工具解包目录。RPM只查询导出的数据库副本。rdump在用户命名空间中出现“changing ownership: Invalid argument”，没有改原镜像；所有73个导出模块文件的SHA与任务19板上原件清单一致，源目录owner/mode取debugfs的镜像内stat而非导出文件的宿主owner。

操作后原 rootfs 和只读副本重新计算SHA一致；工具目录、Task22镜像及解出的二进制/数据库已按授权删除，只保留文本。既有Task9/17产物未改。[操作后哈希](../evidence/task22/post_analysis_hashes.json)、[清理记录](../evidence/task22/cleanup.json)。

## 2. A：模块目录、索引和 ABI

### 2.1 完整目录对照

以版本目录为相对根，两边各73个普通文件（59个.ko、14个索引）、1个build链接、48个子目录：**无多文件、无缺文件**。59个.ko哈希不同，逐项大小/哈希见[完整比较](../evidence/task22/module_image_comparison.json)；这是不同版本/构建的产物，不把哈希变化直接判为不兼容。build链接目标相同；目录模式仅下表三处不同。官方模块镜像导出的73文件与任务19实际板上原目录哈希0差异。[汇总](../evidence/task22/module_comparison_summary.json)

| 相对目录 | base01归档 uid:gid / mode | SR镜像 uid:gid / mode |
|---|---|---|
| extra | 0:0 / 0700 | 0:0 / 0755 |
| extra/kdbus | 0:0 / 0700 | 0:0 / 0755 |
| extra/zlogger | 0:0 / 0700 | 0:0 / 0755 |

[归档所有成员权限](../evidence/task22/base_archive_members.json)、[SR extra stat](../evidence/task22/sr_modules_probe_1.txt)、[kdbus](../evidence/task22/sr_modules_probe_2.txt)、[zlogger](../evidence/task22/sr_modules_probe_3.txt)。D期间又只读确认板上原extra为755、proc-tsm为644。[最终状态](../evidence/task22/board_13_final_state.txt)

14个索引全部相同，包括 `modules.dep`(4223 B)、`modules.dep.bin`(7028 B)、`modules.alias`/`.bin`、`modules.softdep`、`modules.builtin`/`.bin`/`.modinfo`、`modules.builtin.alias.bin`、`modules.order`、`modules.symbols`/`.bin`、`modules.devname`、`modules.weakdep`。两边dep中都有 `extra/proc-tsm.ko:`，没有依赖；均为相对路径。

平台 `modprobe -d <root> -S <release> -C /dev/null -n -v proc-tsm`、`--show-depends`均退出0，解析为各自版本的 `extra/proc-tsm.ko`。这是离线试解析，没有加载模块。平台 `depmod -n`只向stdout输出，退出0；未重写原索引。[base dry-run](../evidence/task22/base_modprobe_dry.txt)、[base依赖](../evidence/task22/base_modprobe_depends.txt)、[SR dry-run](../evidence/task22/sr_image_modprobe_dry.txt)、[SR依赖](../evidence/task22/sr_image_modprobe_depends.txt)、[两边depmod摘录](../evidence/task22/base_depmod_excerpt.txt)、[SR摘录](../evidence/task22/sr_image_depmod_excerpt.txt)

早期另做的“内核RPM+树外RPM直接解包”目录没有经历镜像安装后的depmod，查找proc-tsm失败；后来改用**真正modules.img**后上述检查全部成功。不能把RPM解包目录的未更新索引误报成官方镜像缺陷，也不能把cpio自动生成目录的模式当成官方镜像模式。

### 2.2 proc-tsm 与退出路径候选

| 项 | SR | base01 |
|---|---|---|
| 大小 | 10,680 B | 10,680 B |
| srcversion | 4AAA2EAB4A1F60715A4F1E3 | 相同 |
| depends | 空 | 空 |
| 参数 | blacklist:array of charp | 相同 |
| vermagic release | 6.12.80-arm-rpi4-v7l | 6.12.80-arm-rpi4-v7l-lko-base01 |
| vermagic其余字段 | SMP mod_unload modversions ARMv7 p2v8 | 相同 |
| SHA-256 | cae6d5fa1a4a8f2dc70caf944a3e29f42847e429e7df2500e0b08372eac29531 | 2fe9421d332af653c091adaefe325ca4b6e70577272ac4f5b751dae5a3d5b4d9 |

[SR modinfo](../evidence/task22/sr_image_proc_tsm_info.txt)、[base modinfo](../evidence/task22/base_proc_tsm_info.txt)。base模块引用26个符号，在base01 Module.symvers中**0缺失、0 CRC不一致**；SR模块的同26个CRC亦相同。[逐符号](../evidence/task22/proc_tsm_crc_check.json)、[SR导入](../evidence/task22/sr_image_proc_tsm_versions.txt)

平台strings在stability-monitor中找到候选错误链：`kmod_new() failed`、`Unable to find module proc_tsm`、`Unable to insert %s: %m`、`Unable to open /proc/tsm: %m`、`Unable to initialize %s raw data provider: %d`、`Unable to find any raw data providers`。[带行号摘录](../evidence/task22/stability_error_candidates.txt)。结合任务21动态符号，程序使用libkmod加载模块。字符串本身不能证明哪个分支在任务19执行，也没有单独的“版本检查失败”字符串证据；本轮没有捕获失败那次的open errno。

### 2.3 根因链与建议（未执行）

1. 任务9 `verify/extract_artifacts.py:19` 用cpio -id解RPM；树外RPM清单只含模块文件，没有extra目录条目。当前同工具解SR RPM也自动产生extra 0700，说明**原始RPM解包不等于安装后目录权限**。[RPM文件/模式](../evidence/task22/sr_rpm_directory_modes.txt)
2. 任务9 copytree及归档将该模式保留，归档uid/gid统一为0；此前逐文件哈希、CRC及tar验收未检查非root访问所需目录权限。任务19 `exercise_install.py:10` 的cp -a继续保留。这是部署包制作/验收缺口，非内核proc-tsm逻辑或索引缺陷。[原脚本带行号](../evidence/task22/deployment_mode_provenance.txt)
3. stability-monitor.service显式User/Group=stability_monitor、SMACK System；任务21实际UID/GID204，CapEff=0x90020，只有所需的SYS_MODULE等能力，没有DAC两项豁免。root:root 0700的父目录必然拒绝其路径搜索；即使proc-tsm.ko为0644也打不开。[unit/前次255](../evidence/task19/58_base01_failure_readonly.txt)、[实际身份/能力](../evidence/task21/07_stability_dependencies.txt)、[权限判定](../evidence/task22/dac_cause.json)
4. SMACK `System User::Shell rwxat`允许读，但不替代DAC。root加载的其它模块能工作与此一致；CAP_SYS_MODULE授权插入模块，不授予任意文件读取权限。

因此离线原因已足够明确，C不执行。这里证明了确定的访问阻塞及其来源，**并未声称已观察到修复后启动成功**。

建议下一次由PM另行安排：制作部署包时以实际镜像模式/属主为基准验证所有目录和文件，将上述三个目录恢复为官方0755；归档清单同时记录文件类型、owner/group、mode、链接、哈希，安装后在重启前回读，增加服务身份可搜索/读取检查。不要仅比较文件SHA或调整SMACK，也不建议全目录递归改文件执行位。本任务只写建议，未更改归档、板上目录或docs/11执行步骤。

## 3. B：coregl 在两份官方镜像中的实际状态

两份rootfs均有以下链接及非空实际文件：

| 链接 | 目标文件 | 目标大小 |
|---|---|---:|
| /usr/lib/libEGL.so.1 | libEGL.so.1.5 | 38,144 B |
| /usr/lib/libGLESv2.so.2 | libGLESv2.so.2.0 | 230,660 B |
| /usr/lib/libCOREGL.so.4 | libCOREGL.so.4.0 | 1,604,388 B |

[SR镜像stat](../evidence/task22/sr_coregl_and_rpmdb_image.txt)、[类产品镜像stat](../evidence/task22/vbase_coregl_and_rpmdb_image.txt)、[导出文件SHA](../evidence/task22/post_analysis_hashes.json)。没有仅凭链接存在认定库存在。

rootfs的 `/var -> opt/var`；实际RPM数据库在挂到 `/opt` 的system-data.img内 `/var/lib/rpm`，不在rootfs空挂载点中。已只读导出数据库，平台 `rpm --dbpath <副本> -qa/-q coregl`：

| 项 | SR1218764 | 类产品1218766 |
|---|---|---|
| coregl | 0.4.0-0.armv7l，存在 | 相同 |
| VCS | platform/core/uifw/coregl#424afc2f0beeb70d16b84014f761b1fc27256fc7 | 相同 |
| headed清单 / 实际DB包数 | 1235 / 1233 | 1235 / 1233 |
| DB比清单少 | crossgen2-mic-10.0.10-0.noarch；patchelf-0.16.1-1.13.armv7l | 相同 |
| DB比清单多 | 0 | 0 |

[SR查询](../evidence/task22/sr_rpmdb_coregl.txt)、[类产品查询](../evidence/task22/vbase_rpmdb_coregl.txt)、[逐项清单对照](../evidence/task22/image_package_comparison.json)、[SR实际包表](../evidence/task22/sr_image_packages.txt)、[类产品实际包表](../evidence/task22/vbase_image_packages.txt)。

两份headed kickstart全部%post（49–410）和%post --nochroot（412–431）均已查：364–365明确移除patchelf、crossgen2-mic；62/67为var/home迁移，363删除临时dotnet目录，371–376删除头文件/文档/zypp日志等，**没有coregl/libEGL删除语句**。424–425调用build-backup-data.sh用于备份opt，读取该脚本未见coregl删除。官方制镜日志403、1781–1782分别记录下载/安装coregl；最终镜像与数据库证明安装结果保留。[SR全部带行号KS](../evidence/task22/sr_headed_kickstart_numbered.txt)、[类产品KS](../evidence/task22/vbase_headed_kickstart_numbered.txt)、[检索摘录](../evidence/task22/kickstart_log_matches.json)

**对等性：两份官方镜像在coregl是否存在、版本和源码上对等；当前板上SR已偏离官方状态。** 若之后只让一侧缺coregl，display-manager重启/日志负载会影响基线对比；须由PM决定统一运行条件。本轮不安装coregl、不改变display-manager。

## 4. D：板上删除来源追查与证据边界

首次connect失败，第二轮disconnect/connect成功；未重启SDB服务。身份armv7l、rpi4、Tizen全部通过，BUILD_ID为1218764对应SR。开始已是root，仍记录root on，结束root off回读owner。[身份](../evidence/task22/board_02_identity.txt)、[命令表](../evidence/task22/board_commands.jsonl)

- 当前 `rpm -q coregl`为未安装，三个库路径均不存在。[包/库及日志范围](../evidence/task22/board_05_coregl_current.txt)
- journal可读范围为2026-11-05 22:08:52–23:35:13 KST，list-boots有前一次和当前开机；全文保存在temp。搜索coregl或rpm erase无命中，仅能看到display-manager失败，无法回溯更早删除。[journal检索统计](../evidence/task22/board_log_search_summary.json)
- `/var/log`文本扫描得到大量enlightenment缺libEGL.so.1的日志，包括校时前1970时间戳；未发现coregl卸载命令/操作者。它们证明缺库，不证明谁删库。`/var/log/zypp`、rpm日志、history类日志路径不存在。[原行号摘录](../evidence/task22/board_07_varlog_search_excerpt.txt)、[启动项及缺日志](../evidence/task22/board_12_startup_units.txt)
- 已查 `/etc/rc.d`、`/usr/share/upgrade`、`/usr/lib/systemd/system`、`/etc/systemd/system`；没有coregl/libEGL或rpm erase命中。枚举了first/init/setup/upgrade启动项，setup-adaptor本次退出0，未见删包语句；osu为ELF，grep的“binary matches”仅是包含rpm/resize等字样，**不足以排除其或其他二进制内部行为**。部分unit链接悬空导致grep退出2，具体缺路径已记录；没有把搜索结果写成完整排除所有脚本。[搜索](../evidence/task22/board_08_firstboot_search.txt)、[setup/错误边界](../evidence/task22/board_setup_unit_search.txt)、[osu/rc只读结果](../evidence/task22/board_11_resize_and_init.txt)
- 审计既往evidence中10份command JSONL、555条记录：0解析失败，`rpm -e/--erase`候选为0；本项目**已记录命令中未发现卸载包**。该结论不覆盖未记录会话、外部操作或间接调用，不能据此推断用户做过删除。[逐文件SHA与统计](../evidence/task22/recorded_command_audit.json)

结论闭合到“官方镜像有、当前板上无”；删除具体位置/时刻/操作者**仍未知**，缺少刷写后首次启动至首次采集期间的完整操作和包管理日志。已撤回docs/20此前与用户一次性准备相联系的推测；用户明确未手工卸载，不再将其列为已知事实。

## 5. 最终状态与收尾

C跳过；D只读完成。无部署、无重启、无标签/权限修复、无boot或模块分区写入，因此无需回退；未把任务19的旧回退结果冒充本轮新验证。最终同一boot_id `efb329ce-c985-4835-8124-e7a98c8b4aeb`、`6.12.80-arm-rpi4-v7l`、MemTotal 1,507,996 KiB；proc_tsm在内的10模块已加载，stability-monitor/resourced active/running，配网success/0，eth0为192.168.108.26且LOWER_UP。

根和模块分区仍ro，前后挂载列表相同；/opt/usr可用115,421,468 KiB、模块分区14,648 KiB前后相同。没有创建板上lko_task22目录，结尾test确认不存在；owner回读uid5001。total_mem未改，保留任务19已验收的1600状态。本轮未重新挂载boot或重算boot文件哈希。[最终状态](../evidence/task22/board_13_final_state.txt)、[owner](../evidence/task22/board_15_owner.txt)

原始命令、退出码、行数与SHA见[原始输出清单](../evidence/task22/raw_output_manifest.json)。公开证据只含本任务Tizen内容，所有文件小于1MB；无需上传RPM、镜像、库、模块或私有材料。后续挂账：PM安排带DAC权限验收的部署包修订与重测；coregl删除来源仍需更早操作记录，display-manager/coregl处理保持未授权修复状态。
