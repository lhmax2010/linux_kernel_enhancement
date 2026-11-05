# base01 部署包元数据检查

此工具修正任务9的部署归档制作流程，不构建内核、不操作开发板。参考固定为SR QB1218764的modules.img；数字uid/gid、类型和模式见`evidence/task23/sr_module_reference.json`。

- `module_metadata.py`：共同的校正和验收实现。校正仅在主机非特权user namespace内进行，不跟随链接；验收不做修正。
- `task9/extract_artifacts.py`：现有任务9脚本的修订副本。RPM解包后按官方元数据校正版本树，包括cpio自动创建的父目录。
- `task9/make_deployment.py`：合并extra、平台depmod、再次校正、生成完整元数据及SHA清单、平台Python归档并验收。74个普通文件的哈希必须与原任务9核验产物完全一致。
- `task9/verify_deployment_archive.py`：独立复核归档，不解包到板上。
- `task9/platform_tools.py`：GBS root只读绑定；只把所选新输出目录绑定可写。`bwrap --unshare-user --uid 0 --gid 0`的root是非特权用户命名空间身份，不是宿主root，不调用sudo。ARM工具经该root的qemu-arm执行。
- `tests/metadata_tests.py`：r2正例、旧归档以及目录不可搜索、文件不可读、错误uid、错误链接目标五个负例。

原`temp/task9/verify/`对应四个脚本已同步修正，公开副本与其逐字一致。`LKO_TASK_ROOT`指定全新的工作区输出目录；目录已存在时制作脚本拒绝覆盖。`LKO_DEPLOY_ONLY=1`只解出制作普通版部署包需要的三个RPM。原GBS root和原RPM只读使用，旧归档不得再部署。

本次实际调用和结果见`evidence/task23/`。r2产物在`temp/task23/artifacts/deploy_lko-base01-r2/`。板上复制之后必须按docs/11附录回读完整元数据，再用同一验收实现检查；不符就不替换zImage、不重启。不要在板上临时chmod来绕过验收。
