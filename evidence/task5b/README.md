# 任务5b：来源/配置闭合，perf执行受限，BPF只读核实

2026-10-30（Asia/Shanghai）。前轮的QB包级分支停止条件已由PM裁决覆盖，本轮未再登录QB。指定公开来源的devel包最终.config与任务4LLVM普通版逐字节相同。板上perf version因/tmp noexec返回126；计数/采样未执行，临时目录已删除。源码与运行观察分开记录，不能把缺少ARM32 trampoline当作插件实际失败日志。

## 本轮证据

| 文件 | 内容 |
| --- | --- |
| [pm_adjudication_20261030.txt](pm_adjudication_20261030.txt) | PM来源裁决，QB开始时间UTC为推断、编译时间窗计算 |
| [remote_contains_0fac5de6.txt](remote_contains_0fac5de6.txt) | 只读branch -r --contains原文及本地refs范围 |
| [public_download_traversal.txt](public_download_traversal.txt)、[rpm_manifest.json](rpm_manifest.json) | 指定公开目录路径与两包URL、大小、SHA256 |
| [rpm_metadata.txt](rpm_metadata.txt) | 平台RPM查询；BUILDTIME均为epoch0，不用于实际时间证明 |
| [final_config_diff.txt](final_config_diff.txt)、[config_comparison_summary.txt](config_comparison_summary.txt)、[qb_arm-rpi4.config](qb_arm-rpi4.config) | 平台diffconfig命令/退出码、相同SHA及RPM最终配置全文 |
| [perf_readelf.txt](perf_readelf.txt)、[llvm_library_readelf.txt](llvm_library_readelf.txt)、[llvm_library_package.txt](llvm_library_package.txt) | 平台ELF依赖与唯一缺失库的工作区来源 |
| [board_commands.jsonl](board_commands.jsonl) | 各次SDB命令、宿主起止时间、transport退出码；perf自身退出码需看日志标记 |
| [02_identity_start.transport.txt](02_identity_start.transport.txt)、[17_cleanup_end.transport.txt](17_cleanup_end.transport.txt) | 三项身份、版本、开始/结束uptime与进程；清理确认 |
| [03_libraries_preflight.transport.txt](03_libraries_preflight.transport.txt)、[05_llvm_dependencies.transport.txt](05_llvm_dependencies.transport.txt) | perf与libLLVM依赖逐项板上ls/可读性检查 |
| [pushed_files.json](pushed_files.json)、[10_push_hashes.transport.txt](10_push_hashes.transport.txt) | 仅推perf和缺失libLLVM，共34,480,560 B，板上SHA核验 |
| [11_perf_version.transport.txt](11_perf_version.transport.txt)、[18_exec_restriction.transport.txt](18_exec_restriction.transport.txt)、[perf_attempt_summary.txt](perf_attempt_summary.txt) | Permission denied/126、/tmp noexec、未执行事件测试、第二次清理确认 |
| [bpf_source_error_chain.txt](bpf_source_error_chain.txt) | 内核源码文件/行号/哈希；ARM32弱size/prepare及libbpf1.6.2上游错误传播（不声称与Tizen下游源码同一） |
| [04_bpf_processes.transport.txt](04_bpf_processes.transport.txt)、[06_bpf_dlog.transport.txt](06_bpf_dlog.transport.txt)、[07_bpf_journal.transport.txt](07_bpf_journal.transport.txt)、[bpf_runtime_summary.txt](bpf_runtime_summary.txt) | 进程/maps、包版本、只读日志；排除SDB自身回显，不存在插件实际失败证据 |
| [execution_notes.txt](execution_notes.txt)、[continuation_local_manifest.tsv](continuation_local_manifest.tsv) | 工具/异常边界与本地辅助文件大小/哈希 |
| [source_and_design_final_check.txt](source_and_design_final_check.txt) | 收尾确认内核HEAD/tree未变、工作树干净，设计10哈希未变 |

其余00/01为SDB连接/设备记录，08/09为本次临时目录与两个文件推送记录。所有transport输出均为文本，保留命令原始CRLF与行尾空格；readelf输出及带行号的源码摘录也保留原有空白。完整RPM、CPIO、ELF、公开目录HTML和辅助脚本只在temp/task5b，未安装RPM或上传二进制。

## 前轮历史证据（保留原文）

| 文件 | 内容 |
| --- | --- |
| [design_move.txt](design_move.txt) | 设计文件移动，Downloads无副本，字节数/SHA256 |
| [qb_1211696_page.txt](qb_1211696_page.txt) | 登录后页面相关字段；移除登录用户/Triggered By，无凭据 |
| [provenance_gate.txt](provenance_gate.txt) | 旧分支/时区停止判断，已由本轮PM裁决覆盖 |
| [browser_cleanup.txt](browser_cleanup.txt) | 前轮有界面浏览器正常关闭、会话目录删除 |
| [local_manifest.tsv](local_manifest.tsv) | 前轮本地文本/脚本/截图哈希，截图不上传 |

[manifest.sha256](manifest.sha256)涵盖本目录发布文本，不含清单自身。设计[10](../../docs/10_design_v1.md)保持PM原字节；当前结论见[09](../../docs/09_board_rpi4_readonly.md)与[STATUS](../../docs/STATUS.md)。
