# 任务4证据

对应[08](../../docs/08_sandbox_baseline.md)。全部为小于1 MB的文本；四份最终.config及复用的平台Kconfig工具留在WS/temp/pmu_config_check，不上传二进制或buildroot。

| 内容 | 文件 |
| --- | --- |
| 指定补丁SHA-256、初始基线 | [patch_verification.txt](patch_verification.txt) |
| 两个提交、仅一行源码diff | [commits_and_diff.txt](commits_and_diff.txt) |
| 只删指定句、作者/日期/footers | [message_verification.txt](message_verification.txt) |
| 无sudo环境探测及首次只读目录错误 | [no_sudo_environment_check.txt](no_sudo_environment_check.txt) |
| 原/新配置hash、行号、唯一变化 | [config_check_summary.txt](config_check_summary.txt) |
| 四份平台diffconfig | [GCC普通](diffconfig_gcc_arm-rpi4.txt)、[GCC RT](diffconfig_gcc_arm-rpi4-rt.txt)、[LLVM普通](diffconfig_llvm_arm-rpi4.txt)、[LLVM RT](diffconfig_llvm_arm-rpi4-rt.txt) |
| 四份完整生成日志 | [GCC普通](generation_gcc_arm-rpi4.txt)、[GCC RT](generation_gcc_arm-rpi4-rt.txt)、[LLVM普通](generation_llvm_arm-rpi4.txt)、[LLVM RT](generation_llvm_arm-rpi4-rt.txt) |
| 配置调度脚本留档，仅供复核 | [config_check_driver.py.txt](config_check_driver.py.txt) |
| Gerrit前置/推送/后置核对 | [before](sandbox_before.txt)、[push](sandbox_push.txt)、[after](sandbox_after.txt) |
| 本地/upstream一致与tizen不变 | [final_kernel_state.txt](final_kernel_state.txt) |
| 相对板上21645b17的4提交 | [board_baseline_commits.txt](board_baseline_commits.txt) |
| 任务3可选扫描回看 | [task3_scan_followup.txt](task3_scan_followup.txt) |

原任务对ARM_PMUV3“未输出”的描述经原.config核对更正为明确n，因此diffconfig格式为n -> y。没有其他符号差异。Gerrit subject长度warning保留原文，未触发提交重写。

[manifest.tsv](manifest.tsv)记录除README/manifest自身外各文本的字节数与SHA-256。
