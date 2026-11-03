# 任务9续跑三：监控与验收证据

- `resume3_verification_summary.json`：最终结论与全部主要数值；正文见docs/14_base01_build.md第11–12节。
- `resume3_monitor_history.jsonl`与14个`resume3_monitor_日期时间.json`：十分钟样本；终点ALL_OK。仅记录本任务进程组/后代。无关应用外部路径名称在公开终点样本及external文件中省略，原始数据保留temp/task9，未改写原文件。
- `resume3_monitor_archive_manifest.json`：原始完整日志/进程文件/外部扫描的大小、行数、SHA；`resume3_*_last80.txt`保留原始行号；`resume3_monitor_terminal_status.txt`包含ALL-END。
- `resume3_clang_version.txt`、`resume3_lld_version.txt`、`resume3_devel_installed_payload_comparison.json`：实际工具链与compile.h。
- `resume3_dependency_local_sources.json`、`resume3_installed_dependency_identity.txt`、`resume3_rpm_identity_*.txt`、`resume3_dependency_log_excerpt.txt`：依赖身份；BUILDTIME=0不用于墙钟证明，安装头/来源/载荷/SHA交叉核对。
- `resume3_zimage_verification.json`、`base01_arm-rpi4.config`、`resume3_config_diff_qb.txt`：映像版本/大小及最终配置。
- `resume3_module_vermagic.json`、`resume3_module_crc.json`、`resume3_external_module_imports.tsv`：59模块vermagic、7模块356项CRC、253个唯一符号。
- `resume3_module_disk_usage.txt`、`resume3_shared_config_comparison.json`：空间与共享配置。
- `resume3_deployment_*`：74普通文件及1个构建链接、部署包哈希和逐成员复核；二进制只在temp。
- `resume3_platform_python_packages.json`：modsrc移除Python后，仅解包本次GBS缓存中的平台Python作核验，不安装、不用宿主工具链。首次缺解释器和版本匹配格式常量的失败输出均保留；修正后实际验收通过。
- `resume3_source_integrity_after_build.json`：三个固定源码HEAD/分支/干净树。

除明确标为摘要/脱敏的文件外，命令文本均含输出与退出码；日志摘录带原始行号。验证用bwrap/qemu-arm及辅助脚本全文以`.py.txt`保存供复核。所有入库文件小于1 MB。
