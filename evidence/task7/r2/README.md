# 任务7 r2：只读排查证据（2026-11-02）

报告：[11 r4](../../../docs/11_board_boot_chain.md#2026-11-02-r4首次重启失败排查)。本轮仅只读查询和获准的SDB root on/off；没有重启、服务操作、logger/配网脚本执行、网络/文件/标签修改。当前网络为用户手动恢复后的状态。

| 文件 | 内容 |
|---|---|
| user_background.txt | PM提供的网线松动/重插/串口恢复及时间描述，非采集事实 |
| board_commands.jsonl | 每条SDB命令、开始/结束时间、传输退出码及对应输出文件名 |
| 00_connect、01_identity、02_root_on | 连接、三项身份、授权root切换 |
| 03_basic.transport.txt | boot、uptime、UTC、list-boots、journald存储、运行/失败/job、起始mounts/df |
| 04_service.transport.txt | 全部指定服务属性、文件/链接/标签和完整SHA-256 |
| 05_journal.transport.txt | unit/tag及本次boot全journal（全部文本小于1MB） |
| 06_targets_logger_sdb.transport.txt | target依赖/时间、logger元数据、SDB相关units及cat全文 |
| 07_network_link.transport.txt | 手动恢复后的网络、ConnMan旧MAC配置、.link/udev只读前提 |
| 08_retention_link.transport.txt | journald配置/容量、默认.link屏蔽、墙钟跳变、logger/socket补充 |
| 09_final.transport.txt | 最终服务/哈希/boot、临时目录不存在、mounts/df |
| 10_root_off、11_owner | 恢复owner及uid5001回读、目录仍不存在 |
| lko_matches.txt / denials.txt / network_timeline.txt | 从05全文筛选的计数/匹配；均0，网络最多400行规则未触发截断 |
| journal_summary.txt | 日志范围、重复日志统计及推测边界 |
| verification.txt | 耗时、multi-user时差、mounts/df/清理/权限验证 |
| raw_manifest.tsv | temp/task7/r2中原始transport文本的大小与SHA-256 |
| SHA256SUMS | 本目录发布文本哈希（不含该清单自身） |

原始输出和宿主采集/整理辅助文件保留于temp/task7/r2，不上传脚本或其他历史产物。本目录transport副本只去ANSI/CR及行尾空白，未删错误行。命令的远端退出码在输出中的RC、*-EXIT等字段；SDB传输退出0不等同每个子命令成功。目录不存在、无unit文件等非零结果是只读事实，不静默略去。命令JSON给出准确参数；CMD文字标记是便于阅读的展开形式。

板上没有创建临时文件，未删除任何已有文件；/opt/usr/lko_task7最终明确不存在，owner恢复回读完成。只读结果不足以证明11:09失败唯一由网线导致，也不能替代两次重启验收。墙钟和用户约13:12描述的差异见报告，时间线按本次boot单调时钟列出。
