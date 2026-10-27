# 任务2：内核AutoFDO/BOLT前提（未执行，停止条件触发）

更新：2026-10-27（Asia/Shanghai）。任务2续的base已改标题至 `f240c28093027707f5e09f8a9cbbed16a43ebb1a`，代码未变；步骤B发现原GBS不能通过配置覆盖禁用外部文件加载，按硬要求停止，步骤9仍未执行。详见[配置审计](../evidence/task2/gbs_config_audit_r2.md)。

历史记录：按PM给定顺序，本任务在步骤4停止，未执行步骤9；原因及证据见 [03_baseline_build.md](03_baseline_build.md)。未构建aarch64、未操作开发板、未以宿主LLVM工具冒充平台buildroot工具。

| 范围 | 已具备（本轮实证） | 缺什么/未完成核对 | 需要上板确认什么 |
| --- | --- | --- | --- |
| armv7l LTO/AutoFDO/Propeller | 仅已建立lko/base；没有本轮能力核验结论 | ARM/通用Kconfig的符号与select、ARCH_HAS_HW_PTE_YOUNG、HAVE_PREEMPT_DYNAMIC、HZ choice原文尚未按任务9收集 | 不在本任务执行；静态核对完成后由PM另发任务 |
| armv7l性能采样 | 没有本轮实证 | DTS/DTSI include链、PMU compatible、CoreSight节点、最终.config、perf的CORESIGHT/OpenCSD参数均待查；没有LLVM buildroot的create_llvm_prof/llvm-profgen版本证据 | 未来需实测PMU/trace可用性与权限，当前不推测 |
| armv7l BOLT | 没有本轮实证 | LLVM未构建，未执行平台llvm-bolt --version/help；**本轮不能证实或否定32位ARM支持，也不列猜测的支持架构** | 静态能力核对先行，板测由PM另行授权 |
| aarch64 | 未构建、未上板 | 仅允许的Kconfig记录也因停止条件未执行 | armv7l完成前不开展aarch64优化/板测 |

恢复前必须由PM裁决GBS配置文件隔离方案并通过导出验证；残留按新规等待5分钟，不尝试sudo，越界不在构建中发送信号；本报告不等于批准AutoFDO、Propeller或BOLT实施。
