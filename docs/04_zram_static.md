# 任务2：zram静态准备（未执行，停止条件触发）

更新：2026-10-27（Asia/Shanghai）。任务2在步骤4的GCC构建准备阶段因临时输出越界中止，随后残留root进程清理要求sudo密码。按PM“失败后停止”及“不索要/绕过凭据”的要求，未继续步骤8。详情见 [03_baseline_build.md](03_baseline_build.md)。本文件是待办记录，不是已完成的静态核对报告。

当前基线为 lko/base@563c53c427bff4d685d18544a8f4f6db14be9368，仅拆入memcontrol修复；没有启用zram后端或二次压缩。

待恢复后逐项执行：

1. 以源码行号核对recomp_algorithm/recompress支持参数、按秒idle、algorithm_params及zstd dict/level、writeback。
2. 核对armv7l字段大小/对齐，从struct zram_table_entry计算基础与ACTIME配置的每槽位字节数，以及512 MiB/1 GiB/2 GiB元数据总量。**本轮没有计算“每GB增加多少”，不从未核实的结构/ABI猜数。**
3. 从base建立lko/tmp-lz4，依次检查1051099cb8da、7b64cf4f1065、7459b2911b52的合入，再删除临时分支。本轮未建该分支、未cherry-pick这三条、未测试冲突。
4. 上传85fcc6edce0b中的zram-dict-setup.sh和zram-dict-init.rc全文，并解释执行时机、sysfs和字典来源；本轮未执行此步骤。
5. 上传zram_table_entry、recompress、zcomp stream获取/释放函数片段及原行号；本轮未执行此步骤。

步骤3要求的既有方案修订已完成：85fcc6edce0b会删除CONFIG_DEBUG_INFO_BTF=y，见 [zram_branch_config_diff.txt](../evidence/task2/zram_branch_config_diff.txt)；这不代表该方案已合入本项目。
