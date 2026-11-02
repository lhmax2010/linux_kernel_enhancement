# 任务7 r4：根因确认、新重连流程、三次开机验证

三次通过：第1次为17:26重启后补采（用户此前重启宿主SDB后恢复），第2/3次由新流程自动完成，各kill-server一次；本轮合计两次。配置未改，板上无服务操作/手动配网。报告见[11 r6](../../../docs/11_board_boot_chain.md#2026-11-02-r6根因确认与重启验证)。

| 文件 | 内容 |
|---|---|
| pm_adjudication.txt | PM根因裁定原文，串口/手动恢复事实明确归属PM |
| board_commands.jsonl | 精确argv、宿主时间、传输退出码、输出文件名 |
| 00–02*.transport.txt | 当前连接、三项身份/目标boot、root on |
| reboot1/2/3_tag.transport.txt | 配网日志全文及完成标记 |
| reboot1/2/3_journal_excerpt.txt | 各boot全journal相关摘录，原文全文只留temp |
| reboot1/2/3_kernel_excerpt.txt | dmesg的genet/eth0/link摘录 |
| reboot1/2/3_service、units、identity、network、display、journald.transport.txt | 各boot状态、时刻、身份、MAC/IP/路由、噪声、容量 |
| reboot2/3_before.transport.txt、pre.json | 新重启前LOWER_UP、完整哈希、enabled、boot_id及噪声 |
| reboot2/3_reason.txt、request.transport.txt | 编号/原因、唯一无参数reboot调用结果；124是宿主传输超时 |
| reconnect_attempts.txt | disconnect/connect/timeout shell/TCP/devices/kill/start全输出 |
| reboot2/3_round05_reset_decision.txt | 端口可连后devices列表为空的允许依据 |
| reboot2/3_reconnect.json | 轮数、宿主单调耗时、实际kill-server次数 |
| reboot1/2/3_verdict.json、three_boots.json | 各判定及精确微秒时间/计算值 |
| reconnect_implementation.txt | 本轮实际执行的宿主重连函数；调用的capture辅助文件留temp，精确命令见JSON |
| 03_display_inspect.transport.txt | unit全文、ExecStart/Pre、首次disk usage及起始只读快照 |
| 04_display_files.transport.txt、05_display_commands.transport.txt | 脚本全文/ELF魔数、每个外部命令是否存在 |
| 06_final_readonly.transport.txt | 最终容量、哈希/标签、挂载/df/进程快照 |
| 07_root_off、08_owner.transport.txt | owner恢复及回读 |
| raw_manifest.tsv、SHA256SUMS | 原始文件大小/行数/SHA、发布文本SHA |
| verification.txt | 核验摘要与结论边界 |

transport副本去ANSI/CR与行尾空白；摘录标明规范化原始行号。命令输出中的RC或*-EXIT是子命令退出码，JSON exit为宿主SDB/timeout退出；没有把传输0当所有子命令成功。完整日志只留temp，不上传其他工作区或板上文件。单文件小于1MB。
