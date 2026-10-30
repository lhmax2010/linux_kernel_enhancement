# 任务5c：板上perf实测

2026-10-30，仅SDB。硬件计数及cycles采样成功；branch-stack采样失败255；未观察到软件事件替换。数据分区临时目录已删除，df前后相同。

| 证据 | 内容 |
|---|---|
| [conclusions.txt](conclusions.txt) | 三项结论、计数、32个样本与边界 |
| [board_commands.jsonl](board_commands.jsonl) | 全部命令、宿主时间、SDB退出码；perf自身退出码见PERF-COMMAND-EXIT标记 |
| [02_identity_start.transport.txt](02_identity_start.transport.txt) | 三项身份、版本、uptime和起始进程列表 |
| [03_mounts.transport.txt](03_mounts.transport.txt)、[rw_exec_mounts.json](rw_exec_mounts.json)、[mount_selection.md](mount_selection.md) | 全部挂载、13个rw无noexec挂载点及数据分区选择 |
| [04_preflight.transport.txt](04_preflight.transport.txt)、[05_create_temp.transport.txt](05_create_temp.transport.txt) | 写前df、所有者、路径不存在及依赖逐项检查；新建目录所有者 |
| [pushed_files.json](pushed_files.json)、[08_push_hashes.transport.txt](08_push_hashes.transport.txt) | 仅推perf与缺失libLLVM；来源/大小/SHA及板上复核 |
| [09_perf_version.transport.txt](09_perf_version.transport.txt) | perf6.12.80构建选项（ANSI颜色已去除） |
| [10_perf_stat.transport.txt](10_perf_stat.transport.txt) | 三个硬件事件均有计数，exit0 |
| [11_perf_record.transport.txt](11_perf_record.transport.txt)、[12_perf_evlist.transport.txt](12_perf_evlist.transport.txt) | 32个cycles样本，明确type0/config0 |
| [13_perf_branch.transport.txt](13_perf_branch.transport.txt) | branch stack sampling不支持，exit255 |
| [perf_results.json](perf_results.json) | 每条perf命令与实际退出码 |
| [software_fallback_source.txt](software_fallback_source.txt) | 对应源码硬件事件名与cycles转软件事件路径，辅助解释日志 |
| [16_cleanup_end.transport.txt](16_cleanup_end.transport.txt)、[cleanup_summary.txt](cleanup_summary.txt) | 全目录清理、ls不存在、df、paranoid、进程与mounts前后核对 |
| [raw_manifest.tsv](raw_manifest.tsv) | 本地原始文本、辅助脚本、p.data大小及SHA；二进制不上传 |

00/01为连接与设备记录，06/07为两个文件推送，15为p.data拉回记录。证据文本去除ANSI颜色、统一CRLF/回车为LF并去行尾空白；原始字节保留temp/task5c，哈希见raw_manifest。RPM/ELF/采样数据只留temp，未安装RPM、未remount、未写根文件系统或改paranoid。`manifest.sha256`涵盖本目录文本，排除清单自身。

原始RPM/依赖的LLVM平台readelf证据复用[任务5b](../task5b/README.md)，本轮重新核对源文件哈希和板上依赖，没有重编/重新下载。报告见[09 G节](../../docs/09_board_rpi4_readonly.md)。
