# 任务19证据

原始命令输出在temp/task19；本目录为去ANSI文本、相关日志摘录及结构化比较。raw_manifest.json列原始字节数、行数和SHA-256。构建机标识和cmdline设备序列字段已在发布文本脱敏，原文只留temp。dlog全文与完整dmesg不发布。

- image_gate.json、package_comparison.json、board_packages.sorted.txt：镜像判定与完整包清单差异。
- module_sample.json、platform_*：板上拉回5模块的平台工具vermagic/CRC核对。
- 18–20安装记录、reboot_results.json、reboot{1,2}_transport.txt与*_reconnect.json：服务安装、根ro失败原文、正常重启后的服务/身份/网络/只读挂载核对。
- total_mem_change.json、config.txt.before、config.txt.total_mem1600、38_final_boot_hashes.txt：config备份和仅追加内容的核对。
- 27–36、resourced_reclaim_log_excerpt.txt、force_reclaim_context.txt、kernel_warning_excerpt.txt：基线、服务及回收路径实测和限制。
- snapshot_{60,600}.txt、timed_snapshots.json、snapshot_summary.json：同一boot实测时间与完整free/meminfo/vmstat。
- base01_archive_preflight.json：仅部署包哈希复核，不代表内核切换或回退已执行。
- 收尾记录：临时目录/挂载/最终内核/网络及owner回读。主机脚本以*.py.txt留底。

任务20的详细安全门槛记录仅在vendor_local，本目录不包含代码集成或内部构建材料。
