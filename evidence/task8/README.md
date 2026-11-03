# 任务8：开发机构建准备证据

报告：[12_kernel_deploy_prep.md](../../docs/12_kernel_deploy_prep.md)。仅公开Tizen/Linux源码、QB1211696同次发布元数据及开发机只读/轻量计算；没有板上命令、完整构建或vendor_local资料。

- source_provenance、primary/filelists、metadata_hashes、rpm_metadata_checksums、srpm_spec_comparison、source_payload_comparison：固定提交→来源包→发布RPM的核验链。
- *_sources.txt：原始路径、SHA-256和逐行编号的公开源码摘录。
- qb_image_*：实际KS、包清单和MIC日志摘录；不上传完整含账号设置的KS。
- kernelrelease_*：对应GBS root的qemu-arm/platform make命令、输出、退出码、耗时、源树前后状态；无.o文件。
- rpmspec_*：候选spec的Clang/armv7l展开摘要；仅解析，未执行构建步骤。初次缺宏失败与cpio选项错误留temp/task8，之后用已有root原始宏/受控cwd验证成功。
- module_vermagic、modules_rpm_files、external_modules_disk_usage：7个发布.ko的属性及包清单；没有声称新变体模块已构建。
- devel_release_state：旧devel中源码localversion标记与缓存/生成头的差异；建议在新安装循环修正标记。

原始下载、完整XML、RPM、源码检出及候选spec仅留temp/task8；本目录只含小于1MB文本。容量计算引用任务7既有板上证据，RPi4与产品板未在本轮访问。
