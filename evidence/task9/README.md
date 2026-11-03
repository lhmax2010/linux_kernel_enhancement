# 任务9预检停止证据

报告：[14_base01_build.md](../../docs/14_base01_build.md)。源码准备完成，静态语义门槛失败，没有执行构建。

- source_prepare.txt、local_branches.json、source_integrity.json、final_local_state.txt：三棵本地树的固定基准、两次本地提交、精确应用任务8方案、最终干净状态。
- rpmspec_kernel.txt / rpmspec_modules.txt：旧LLVM GBS root的平台rpmspec命令、展开文本、退出码0；并非新task9构建环境。
- *_static_excerpt.txt：带原源码行号的相关区段。
- *_expanded_files.txt：所有%files绝对路径；其中共享boot/配置/工具路径不带后缀。
- static_preflight.json：语义门槛FAILED；树外模块%install未导出LOCALVERSION；后续步骤未执行。
- static_preflight.py.txt：静态检查脚本文本，仅用于复现当前检查；不是构建启动入口。
- raw_log_integrity.json：temp/task9原始日志的行数、大小、SHA-256。

初次收集%files时检查脚本将%defattr也当成段结束，导致漏列共享路径；发现后仅重新解析已有rpmspec输出，修正段落边界并保存更正后的脚本和完整路径表。树外模块%install缺少导出的失败结论始终相同，没有因此继续kernelrelease或构建。

只含公开源码相关的小体积文本；ext、temp和二进制均不提交，没有读取vendor_local。

## 续跑（2026-11-03）

- static_preflight_rejudged.json：PM改判PASS，引用原static_preflight.json的SHA，原文件未修改。
- resume1_source_assertions / final_source_state：本轮前后三棵树HEAD和干净状态。
- resume1_kernelrelease_*：普通/RT复验命令、输出、退出码、耗时及执行脚本；两项通过。
- resume1_environment_gate.json：独立root已建为空目录，初始化前因sudo调用与任务约束冲突停止；非命令执行失败。
- resume1_gbs_privilege_audit.txt：已安装工具的只读调用链证据，包含命令行buildroot覆盖和明确sudo调用，未执行这些调用。

旧root仅只读用于任务8同方式的kernelrelease计算；没有复制或复用它进行任务9实际构建。没有新RPM或部署包，没有启动GBS、sudo或连接板子。
