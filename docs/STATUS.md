# 项目状态

更新：2026-10-28（Asia/Shanghai）。新Session先读本文件和[RULES.md](RULES.md)。

**任务3已完成现有四产物的静态分析。普通版LLVM常驻已分配段增加2,669,604 B（+8.11%），RT增加2,516,690 B（+7.58%）；完整vmlinux的文件缩小不能称为内存减少。** 独立因果占比、实际产品BTF依赖及rpmdb写入者仍有明确证据边界，见挂账。

## 计划

本轮：按段改正03结论 → 目录/功能静态占用 → 5个.cmd与目录/函数增长 → 至少10函数反汇编/remarks → unwind与TLS探测 → rpmdb只读归属 → 同commit发布。已取得并整理所有可用证据；所有配置节省量标“估算”，未据此改配置或代码。优化实验、产品用途裁决与上板验证由PM另发任务。

## 进度

- 新增[06](06_static_footprint.md)、[07](07_llvm_text_growth.md)，03按debug/常驻/init/模块分类更正；未改01/04/05既有任务2实测结论。
- 四产物readelf SHF_ALLOC逐段加总；vmlinux.a唯一输入对象按顶层/子目录统计，显式列链接残差，不重复求和built-in.a。
- 5目标.cmd逐token差异、目录.text前30、普通/RT函数前50与增减分布完成；17个前50函数有平台反汇编/优化记录核对。
- 只按任务3授权，在LLVM root内单文件重编4个目标以获取remarks；输出全在temp，.text SHA256与原对象4组全部相同，未替换产物。没有运行gbs、内核构建、sudo、发送信号或碰开发板。
- 用完整CLANG_FLAGS实际复现TLS探测：默认armv4t+cp15失败，补-march=armv7-a通过；不把原因写成Clang不支持ARM32 TLS。
- 四个原vmlinux/.config/zImage/zram对象及平台工具与任务2SHA-256复核一致；内核工作树干净，lko/base与tizen SHA不变。

## 已闭合结论（附证据）

| 类别/字节 | GCC普通 | LLVM普通 | Δ普通 | GCC RT | LLVM RT | ΔRT |
| --- | --- | --- | --- | --- | --- | --- |
| 调试 .debug_*（非分配） | 371,084,669 | 294,059,724 | -77,024,945 | 380,296,444 | 301,358,541 | -78,937,903 |
| 常驻：其余 SHF_ALLOC | 32,930,806 | 35,600,410 | +2,669,604 | 33,222,614 | 35,739,304 | +2,516,690 |
| 启动后释放 .init* / .exit.text | 781,896 | 854,008 | +72,112 | 738,496 | 802,148 | +63,652 |
| 构建 .ko（含调试，52个/版） | 39,028,264 | 29,325,668 | -9,702,596 | 39,126,596 | 29,348,752 | -9,777,844 |
| 打包 .ko（52个/版，RPM内逻辑字节） | 2,641,484 | 2,821,812 | +180,328 | 2,648,528 | 2,821,912 | +173,384 |


上述单位B；模块为文件逻辑大小，.BTF有SHF_ALLOC计常驻，.debug_*不加载；段逻辑字节不等于板上物理内存。附注：完整vmlinux普通LLVM−GCC −74,005,020 B，RT −76,138,524 B，主要是DWARF缩小，不能代替常驻指标。

| 结论 | 证据 |
| --- | --- |
| 常驻增量与PM普通版计算完全一致 | [06](06_static_footprint.md)、[四类汇总](../evidence/task3/section_categories.tsv)、[逐段原文索引](../evidence/task3/README.md) |
| 目录输入与最终四核心段通过显式残差核对 | [链接加总](../evidence/task3/archive_reconciliation.txt)、[目录分量](../evidence/task3/directory_components.tsv) |
| 条件裁剪候选：BTF、ALL符号、Btrfs、NFS/RPC、追踪；全为估算 | [06](06_static_footprint.md)、[对象估算](../evidence/task3/configuration_object_estimates.tsv)、[KALLSYMS估算](../evidence/task3/kallsyms_all_estimate.txt) |
| .text普通+11.54%、RT+10.36%；已审计对象净增19.01%，外部帧指针指令11.34%，其余未分因果 | [07](07_llvm_text_growth.md)、[范围记账](../evidence/task3/cause_quantification.txt)、[remarks代码相同性](../evidence/task3/remarks_code_identity.txt) |
| unwind_tab普通13,152→522,312 B：外部compact model1 1,096→43,526条，均12 B | [解码](../evidence/task3/unwind_summary.txt)、[LLVM来源](../evidence/task3/llvm_ehabi_source_identity.txt) |
| TLS失败是探测缺ARMv7目标参数，优先修内核探测一致性 | [精确探测](../evidence/task3/kconfig_probe_exact.txt)、[ARMv7对照](../evidence/task3/kconfig_probe_armv7.txt) |
| 隔离HOME内无.rpmdb；真实shm写入者仍不能归属 | [只读审计](../evidence/task3/rpmdb_readonly_audit.txt) |
| 原产物与源码未变化 | [SHA与状态](../evidence/task3/original_artifact_integrity.txt) |

## 需要人工裁决的前提

- BTF关闭前需明确TV镜像/用户态CO-RE及内核typed BPF使用；公开Tizen镜像只有libbpf等存在性证据，cgit TLS失败，不能据此判定无依赖。spec的btf-devel/vmlinux.h生成也需配套设计；本树BTF是bool，不能改m。
- 驱动/文件系统候选需BOM、附件支持、分区、NFS根/挂载与现场诊断需求；未直接认定所有TV都无此用途。追踪整组估算与单项有重叠，不承诺相加收益。
- 如开展受控GCC/Clang对比，应先处理TLS探测/配置差异、工具依赖差异；修复代码和任何候选优化实验均未在本任务执行。

## 挂账事项

- 补充分析进程：早先为备选DWARF归属启动的只读nm -S -l扫描PID1636046（GCC）/1636318（LLVM）在收尾快照时仍自然运行，各约1 CPU；已采用完成的vmlinux.a方法，所有发布数字不依赖这两个未完成输出。没有发送信号；输出仅在temp/task3，见[进程快照](../evidence/task3/optional_nm_scan_state.txt)。下次Session先核对是否已自然结束，不把它们误认作GBS构建或其他任务。

- 六类代码增长的独立净贡献不能仅由已有产物/remarks唯一分解；19.01%是已审计对象范围（内联/初始化/guard等混合），11.34%是排除这些对象的帧指针建立指令记账，余69.65%未因果分离。需要另行消融实验才能给可靠独立占比。
- rpmdb两轮find更新仍无法归属；事后15:49:40 mtime晚于构建，日志不含写调用PID，不能可靠归给其他任务。没有删除/移动/查询宿主rpm数据库内容。
- 静态段/对象节省不是板上运行收益；实际CMA、固件/DT覆盖、每CPU分配、运行追踪开销等待上板任务。
- 任务2遗留：平台缺llvm-bolt/create_llvm_prof；ARM32内核AutoFDO缺Kconfig/Kbuild profile接入及采样转换消费链；CoreSight最终n、perf OpenCSD OFF。buildroot磁盘精确总量仍因3目录不可读只有下界，不sudo补读。

## 保留的任务2基线

用户以e028a072启动；ALL-END 2026-10-28T14:55:09+08:00 OK。GCC/LLVM time墙钟58:44.70/36:50.38，实际GCC14.2.0/Clang22.1.8。四.config已核对，01补全/澄清7符号；MGLRU启用，zram内建lzo-rle，MULTI_COMP/WRITEBACK/ACTIME=n。ACTIME真实头文件探针证明普通12→24 B、RT24→32 B，每GiB增3/2 MiB；见[04](04_zram_static.md)。LZ4三补丁此前干净合入后临时分支已删。导出a/b/c通过，外部find更新GCC27/LLVM48项不能归属；见[03](03_baseline_build.md)、[任务2证据](../evidence/task2/README.md)。

内核：lko/base@f240c28093027707f5e09f8a9cbbed16a43ebb1a；tizen@42aeefac58edeb081aff440f0b60be71cbe49755。

## 发布

06、07、更新后的03/STATUS及evidence/task3在同一提交，以Hao Lin <hao.lin@samsung.com>、正常Git环境普通push main；最终SHA见交付回复。未修改RULES或构建脚本，未开PR/force push/推Gerrit。证据索引：[task3 README](../evidence/task3/README.md)。
