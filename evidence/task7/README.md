# 任务7证据，2026-11-02

第一部分只读核实完成；第二部分用户在场确认后修正两文件标签、发出第一次无参数重启，600秒SDB未恢复，停止，未做第二次重启或补救。没有运行配网脚本/start/restart服务。

- board_commands.jsonl：每条SDB精确命令、时间、传输退出码；raw_manifest.tsv记录原始transport字节数与SHA。SDB传输0不能等同所有远端命令成功；看输出内RC/错误文本。reboot及最初若干probe的124是宿主8秒等待超时，不是远端命令返回码。
- 01–05：身份、进程/挂载/空间前置快照、已加载模块和modinfo、外部模块rpm -qf、dlog backend、SMACK、模块挂载来源、ramdisk dd及板上哈希。
- 06–09：SDB只读拉回、删除ramdisk临时副本、boot ro挂载与U-Boot拉回/立即卸载。
- ramdisk_file/gzip/list/extract/init_extract：在LLVM GBS root经qemu使用平台file/gzip/cpio。解压尾部警告原样保留，first gzip stream正常结束，完整镜像有非零尾部，未猜其来源。
- ramdisk_init.txt：/init的链接目标usr/sbin/init全文，仅分析；ramdisk_references保留grep位置；ramdisk_summary和gzip_padding说明范围/完整性。没有提取设备节点或危险归档链接，没有执行解出的脚本。
- 10、part1_cleanup：modules-load.d配置与重启前临时目录/挂载/df清理；11记录第一部分结束root off。
- uboot_strings.txt、uboot_command_strings.tsv：平台strings输出与逐项字符串/独立token匹配；不据此声称命令可用。
- version_suffix_sources、dtb_comparison：版本拼接和RPM路径的源码行号、现有sandbox基线DTB与板上相同。不构建、不改源码。
- user_presence、12–15：明确在场确认、再次身份、仅两文件chsmack变更、reload/loaded/enabled、首次重启前boot_id/MAC/IP/DNS。
- reboot1_command、reboot_reconnect_log、reboot1_reconnect.json：首次重启及全部重连原文；10秒节拍、截止600秒，未获取新的boot_id。逐次小日志原始文件留temp，上传合并文本。第二次未执行；服务结果、耗时和multi-user.target等待关系均未知。
- pm_decision：用户原文，已逐字追加docs/11；未执行替换。

没有上传镜像、二进制、完整构建树。ANSI/OSC颜色和终端回车已清理，行末空格已裁掉；原始精确字节留temp/task7。文本文件哈希见manifest.sha256。结束因SDB不可达，不能完成重启后的owner/df/mounts回读；报告明确区分重启前清理事实与未完成项。
