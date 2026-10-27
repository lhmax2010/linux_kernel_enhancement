# 任务2：内核AutoFDO/BOLT前提（未执行，停止条件触发）

更新：2026-10-27（Asia/Shanghai）。按PM给定顺序，本任务在步骤4停止，未执行步骤9；原因及证据见 [03_baseline_build.md](03_baseline_build.md)。未构建aarch64、未操作开发板、未以宿主LLVM工具冒充平台buildroot工具。

| 范围 | 已具备（本轮实证） | 缺什么/未完成核对 | 需要上板确认什么 |
| --- | --- | --- | --- |
| armv7l LTO/AutoFDO/Propeller | 仅已建立lko/base；没有本轮能力核验结论 | ARM/通用Kconfig的符号与select、ARCH_HAS_HW_PTE_YOUNG、HAVE_PREEMPT_DYNAMIC、HZ choice原文尚未按任务9收集 | 不在本任务执行；静态核对完成后由PM另发任务 |
| armv7l性能采样 | 没有本轮实证 | DTS/DTSI include链、PMU compatible、CoreSight节点、最终.config、perf的CORESIGHT/OpenCSD参数均待查；没有LLVM buildroot的create_llvm_prof/llvm-profgen版本证据 | 未来需实测PMU/trace可用性与权限，当前不推测 |
| armv7l BOLT | 没有本轮实证 | LLVM未构建，未执行平台llvm-bolt --version/help；**本轮不能证实或否定32位ARM支持，也不列猜测的支持架构** | 静态能力核对先行，板测由PM另行授权 |
| aarch64 | 未构建、未上板 | 仅允许的Kconfig记录也因停止条件未执行 | armv7l完成前不开展aarch64优化/板测 |

下一任务必须先处理GBS临时目录配置传播和中止后的root进程清理能力，再恢复armv7l构建；本报告不等于批准AutoFDO、Propeller或BOLT实施。
