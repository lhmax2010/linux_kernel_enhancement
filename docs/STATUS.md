# 项目状态

更新：2026-10-26（Asia/Shanghai）。新 Session **先读本文件与 [RULES.md](RULES.md)**。

## 计划

- 任务1只读摸底：建独立成果仓库；核对内核/打包/配置/下游边界；盘点所有 sandbox 和匿名 Gerrit；保留小体积文本证据；同一提交提交本文件和全部产出，git push 到 GitHub main。
- 后续实现、编译、板测须等待 PM 给出新任务及范围。不要把本任务报告视为已批准优化方案。

## 进度

- 已完成四份要求文档、两份无凭据 GBS 配置的检查、文本证据与索引，以及上传前校验脚本。
- GitHub 原为空仓库，工作区原非 Git 仓库；独立 main/origin 已建立。发布采用 main 单次普通 push，不开 PR、不 force push；最终提交号以本次交付回复及 `git log -1` 为准。
- 46 条 sandbox 已 fetch/核对；全部保存相对当前 tizen 的 merge-base、ahead/behind、目录统计和去背景提交元数据。过大全量输出仅留 temp/sandbox_raw，不上传。
- 匿名 REST 的 open 和最近六个月 merged 均返回空，并且项目查询/已知 Change-Id 也不可见；已完成限定的匿名尝试与原因记录，**并未获得完整审核变更清单**。
- 未修改 linux-rpi 工作树/分支/HEAD，未向 Gerrit 推送，未运行 make 或 GBS 构建。仅运行 sdb devices（设备为空，自动启动本机 server），未进入开发板 shell。

## 已闭合结论及证据

| 结论 | 证据 |
| --- | --- |
| 内核 HEAD 42aeefac58edeb081aff440f0b60be71cbe49755，tizen，6.12.80；前后工作树干净 | [kernel_initial.txt](../evidence/task1/kernel_initial.txt)、[kernel_final_readonly_check.txt](../evidence/task1/kernel_final_readonly_check.txt) |
| ARM RPi4 使用 tizen_bcm2711_defconfig；普通/RT 同源片段；支持 aarch64 和条件 LLVM=1 | [spec_numbered.txt](../evidence/task1/spec_numbered.txt)、[01_kernel_inventory.md](01_kernel_inventory.md) |
| MGLRU=y，默认启用；完整统计 n，ARM32 的 MMU walk 条件未满足 | [defconfig_arm_numbered.txt](../evidence/task1/defconfig_arm_numbered.txt)、[kconfig_selected_definitions.txt](../evidence/task1/kconfig_selected_definitions.txt) |
| zram=y；当前静态默认 lzo-rle/LZO backend；多压缩、写回、访问时间跟踪 n；crypto LZ4/ZSTD 不等于 zram 后端 | [source_contexts.txt](../evidence/task1/source_contexts.txt)、[01_kernel_inventory.md](01_kernel_inventory.md) |
| stable 官方 tag 00d7934ffcc3；与 RPi rpi-6.12.y 的 merge-base 49b3f941b664；Tizen 独有 mm 2 条、zram 驱动 0 条；相对 stable 则 mm 14、zram 0 | [upstream_remote_refs.txt](../evidence/task1/upstream_remote_refs.txt)、[rpi_boundary.txt](../evidence/task1/rpi_boundary.txt)、[mm_zram_counts.txt](../evidence/task1/mm_zram_counts.txt) |
| force_reclaim 仍传 true 而 MAY_SWAP 为 1<<1，存在静态可证的参数位失配；已有修复 sandbox | [force_reclaim_patch.txt](../evidence/task1/force_reclaim_patch.txt)、[sandbox_silent_reclaim_patch.txt](../evidence/task1/sandbox_silent_reclaim_patch.txt) |
| 重叠工作包含 zram、LZ4、MLGO、历史 LTO/PGO/EEVDF；cache-ext 与另一同事方向相关，不能直接称作已实现 ML 策略 | [02_gerrit_overlap.md](02_gerrit_overlap.md)、[focused_sandbox_details.txt](../evidence/task1/focused_sandbox_details.txt)、[cache_ext_changes.txt](../evidence/task1/cache_ext_changes.txt) |
| 两个 conf 无账号密码；只改变仓库/buildroot，实际 Clang 分支依赖目标环境 RPM 宏 | [config_credentials_audit.txt](../evidence/task1/config_credentials_audit.txt)、[01_kernel_inventory.md](01_kernel_inventory.md) |
| nproc=20、并行上限10；内存约30 GiB、磁盘剩余539 GiB；GBS2.1.0；sdb为空 | [host_resources.txt](../evidence/task1/host_resources.txt)、[sdb_devices.txt](../evidence/task1/sdb_devices.txt) |

## 需要人工裁决的前提

1. 普通/RT、LSM 和工具链基线；板上最终配置与 GBS RPM 宏没有实测，BTF/pahole、stack protector 的工具版本条件未闭合。
2. silent-reclaim-fix 与 jaehoon80/zram 的采用顺序/负责人：一个保留 lzo-rle 且不启用二次压缩，另一个选择 zstd 并启用二次压缩；本次未合并任何方案。
3. cache-ext 是否属于指定同事的机器学习回收项目，以及文件修改边界。该方向本项目不做；本次没有联系同事。
4. 是否需要后续具备可见性的 Gerrit 查询。当前匿名空结果不能证明无人提交变更，也不能证明某分支仍在维护。

## 挂账事项

- Gerrit open/2026-04-26 至 2026-10-26 merged 全量与审批状态不可得；完整匿名尝试和返回见 [gerrit_rest_requests.txt](../evidence/task1/gerrit_rest_requests.txt)、[gerrit_rest_followup.txt](../evidence/task1/gerrit_rest_followup.txt)。
- 未核验板上 /proc/config.gz、MGLRU sysfs、zram 实际算法/容量、swappiness、命令行及性能指标；任务1明确不做板测。
- 未构建/展开最终 GBS `.config`，未测编译耗时/峰值内存/镜像大小；conf 名字不保证实际 compiler。
- 部分本地 Clang 文件执行 --version 因 libxml2.so.16 缺失失败；GBS 加速工具另依赖 /emul loader。存在文件不等于宿主可用。见 [compiler_version_attempts.txt](../evidence/task1/compiler_version_attempts.txt)。
- 旧 sandbox 的拓扑领先包含历史背景；去背景摘要仍可能包含重放，未全量 patch-id 去重。不得把 raw ahead 数称为作者原创补丁数。
- 任务1不修 force_reclaim、不改 zram 后端、不裁 debug 项。实现任务另开内核分支，按 PM 后续说明执行。

所有上传证据、命令口径及 raw URL 清单：[evidence/task1/README.md](../evidence/task1/README.md)。
