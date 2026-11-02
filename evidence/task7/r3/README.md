# 任务7 r3：journald容量登记与重启验证重做

结果：配置写入完成，第一次重做重启SDB等待600秒超时，第二次跳过。运行时64M上限、配网服务日志/结果、新boot时间线、最终owner恢复均未取得；未做其他补救。报告见[11 r5](../../../docs/11_board_boot_chain.md#2026-11-02-r5重启验证重做)。

| 文件 | 内容 |
|---|---|
| pm_adjudication.txt | PM对r4开机对应关系及网线可能原因的裁定原文 |
| user_presence.txt | 用户在场、网线插牢、显示器已接的确认 |
| board_commands.jsonl | 精确SDB argv、宿主开始/结束时间、传输退出码、输出文件 |
| 00–03*.transport.txt | 连接、三项身份、root、配置前只读快照 |
| 04_config_install.transport.txt | df选择64M、配置写入、标签修改前后、内容/权限/SHA回读 |
| 05–06*.transport.txt | 等待确认期间恢复owner（不能代替最终恢复） |
| 07–08*.transport.txt | 用户确认后重新核对身份、root on |
| reboot1_before.transport.txt | LOWER_UP、两哈希、enabled、boot/uptime/UTC、display状态和最近40行 |
| reboot1_noise_summary.txt | 前10分钟相关日志348行（去ANSI） |
| reboot1_noise_excerpt.txt | 原始10分钟journal按关键词摘录，带原始规范化行号 |
| reboot1_pre.json / reboot1_reason.txt | 前置boot、噪声计数、重启编号/原因 |
| reboot1_request.transport.txt | 宿主SDB超时124（不是板上reboot退出码） |
| reconnect_attempts.txt | 59次connect/59次shell探测输出，保留原始文件名 |
| reboot1_reconnect.json | 原始600秒结果；attempts字段60为截止检查计数，实际发出59次，见verification |
| verification.txt | 计数、噪声、配置与未闭合事项核验 |
| raw_manifest.tsv | 原始transport输出大小、行数、SHA-256 |
| SHA256SUMS | 此目录发布文本哈希（不含清单自身） |

原始输出/宿主编排脚本只留temp/task7/r3。transport副本去ANSI/CR和行尾空白；JSON记录精确命令，远端子命令退出见RC/IDENTITY-PASS/CONFIG-INSTALL-EXIT等，传输0不等于每个子命令0。缺少配置目录是安装前正常事实，其错误原文保留。

重启后未取得journal全文。重启前10分钟全文只留temp，证据仅相关摘录；单文件均为小于1MB文本。本轮没有创建板上临时目录；只保留获准的journald配置。SDB超时后停止，未发送更多板上命令，已请用户通过串口执行ip link show eth0并查看网口指示灯。
