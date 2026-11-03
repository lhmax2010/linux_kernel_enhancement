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
