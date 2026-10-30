# 任务6停止证据

2026-10-30（Asia/Shanghai）。身份通过，安装预检缺少systemd-analyze；verify返回127，按PM停止条件停止。尚未安装服务，未重启。

| 文件 | 内容 |
|---|---|
| [board_commands.jsonl](board_commands.jsonl) | 全部SDB命令、宿主时间和传输退出码；逐项工具/verify退出码见输出标记 |
| [01_identity_start.transport.txt](01_identity_start.transport.txt) | 三项身份断言、内核版本、起始uptime/进程 |
| [02_mounts_preflight.transport.txt](02_mounts_preflight.transport.txt) | 起始mounts/df、安装路径无同名文件、owner身份工具初查 |
| [03_root_on.transport.txt](03_root_on.transport.txt)、[04_root_preflight.transport.txt](04_root_preflight.transport.txt) | 按既有授权取得root，完整PATH重新核对工具/目标 |
| [05_verify_tool_search.transport.txt](05_verify_tool_search.transport.txt) | 标准二进制及systemd工具目录无systemd-analyze，systemctl244 |
| [06_verify_blocker.transport.txt](06_verify_blocker.transport.txt) | command not found，VERIFY-EXIT=127；触发停止 |
| [07_end_state.transport.txt](07_end_state.transport.txt) | mounts/df前后、所有安装目标仍不存在、临时目录从未创建、结束进程 |
| [08_root_off.transport.txt](08_root_off.transport.txt)、[09_owner_final.transport.txt](09_owner_final.transport.txt) | 恢复原owner身份、最终目录不存在确认 |
| [stop_and_cleanup_summary.txt](stop_and_cleanup_summary.txt) | 停止范围、未执行项和清理核对 |
| [raw_manifest.tsv](raw_manifest.tsv) | temp/task6原始文本/辅助脚本大小与SHA256 |

00为连接记录。去除了ANSI颜色，CRLF统一为LF、去除行尾空白；原始字节保留temp/task6。证据均为小于1MB文本。manifest.sha256不包含清单自身。没有服务文件哈希，因为本次没有写入服务文件。报告见[11_board_boot_chain.md](../../docs/11_board_boot_chain.md)。
