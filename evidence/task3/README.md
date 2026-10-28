# 任务3文本证据

对应源码f240c28093027707f5e09f8a9cbbed16a43ebb1a、任务2原始四产物，2026-10-28。报告：[06](../../docs/06_static_footprint.md)、[07](../../docs/07_llvm_text_growth.md)。所有文件UTF-8、单个小于1 MB；完整大输出留在WS/temp/task3，不上传ELF、对象、RPM、完整源码或优化记录大文件。

| 内容 | 入口 |
| --- | --- |
| 方法/统计边界 | [analysis_method.txt](analysis_method.txt) |
| 原产物保持不变、工具路径/hash | [original_artifact_integrity.txt](original_artifact_integrity.txt) |
| 四类大小及四份readelf | [section_categories.tsv](section_categories.tsv)，sections_* |
| 目录及最终段核对 | [archive_reconciliation.txt](archive_reconciliation.txt)，directory_* |
| 条件配置裁剪 | [configuration_object_estimates.tsv](configuration_object_estimates.tsv)，[kallsyms_all_estimate.txt](kallsyms_all_estimate.txt)，[profiler_and_memory_init_symbols.txt](profiler_and_memory_init_symbols.txt) |
| 内核行号/实际配置/CMA | [kernel_source_references.txt](kernel_source_references.txt)，[reserved_memory_sources.txt](reserved_memory_sources.txt) |
| Tizen公开镜像与cgit查询限制 | [tizen_image_bpf_search.txt](tizen_image_bpf_search.txt)，[external_source_attempts.txt](external_source_attempts.txt) |
| 五目标参数与driver实际参数 | [representative_commands.txt](representative_commands.txt)，[clang_driver_plan.txt](clang_driver_plan.txt) |
| 函数前50/数量分布 | functions_growth_*，[function_growth_distribution.txt](function_growth_distribution.txt) |
| 17函数反汇编与remarks | disasm_*，*_optimization_excerpt.txt，[optimization_counts.txt](optimization_counts.txt)，[initialization_guard_unroll_remarks.txt](initialization_guard_unroll_remarks.txt) |
| 报告重编命令及原对象.text相同 | [inline_record_commands.txt](inline_record_commands.txt)，[remarks_code_identity.txt](remarks_code_identity.txt) |
| 可量化范围（非独立因果分解） | [cause_quantification.txt](cause_quantification.txt)，[growth_function_instruction_summary.txt](growth_function_instruction_summary.txt)，[full_text_instruction_patterns.txt](full_text_instruction_patterns.txt) |
| ARM EHABI | [unwind_summary.txt](unwind_summary.txt)，[unwind_frame_pattern.txt](unwind_frame_pattern.txt)，[llvm_ehabi_source_identity.txt](llvm_ehabi_source_identity.txt) |
| 精确TLS能力探测及单因素控制 | [kconfig_probe_exact.txt](kconfig_probe_exact.txt)，[kconfig_probe_armv7.txt](kconfig_probe_armv7.txt)，global_control.txt、tls_* |
| rpmdb只读调查，不能归属 | [rpmdb_readonly_audit.txt](rpmdb_readonly_audit.txt) |
| 完整大文本输出行数/hash | [large_output_integrity.txt](large_output_integrity.txt) |

源码行号对应原文件，不是证据摘录里的行号。函数名字0表示没有同名独立符号；不是缺功能。配置节省全为估算；内存数是ELF逻辑段，非运行页占用。摘要保留stderr/失败探测，不把预期失败改成通过。

发布文件字节数与SHA-256（不含本README自身）见[manifest.tsv](manifest.tsv)。

补充DWARF方案的两个nm -l只读扫描仍在自然运行，未使用其不完整输出：[收尾快照](optional_nm_scan_state.txt)。正式目录分解已使用完整vmlinux.a统计。
