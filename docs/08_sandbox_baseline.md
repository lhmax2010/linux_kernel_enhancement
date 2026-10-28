# 任务4：PMU补丁与Gerrit sandbox基线

2026-10-28（Asia/Shanghai）。本轮应用一行defconfig补丁、生成四份最终配置并推送已授权sandbox；没有完整编译内核、运行GBS、执行sudo或操作开发板。

## 1. 已建立的唯一内核推送目标

| 项目 | 结果 |
| --- | --- |
| Gerrit项目/QB项目 | `platform/kernel/linux-rpi` |
| 分支 | `sandbox/lhmax2025/kernel_optimization` |
| 远端提交SHA | `0fac5de6a63091d141ad1cd3ed9d9e92b8dde708` |
| 本地基线 | `lko/base`，SHA与上述远端相同 |
| 本地upstream | `origin/sandbox/lhmax2025/kernel_optimization`，ahead/behind均0 |
| Gerrit origin | `ssh://lhmax2025@review.tizen.org:29418/platform/kernel/linux-rpi` |

推前`git ls-remote origin refs/heads/sandbox/lhmax2025/kernel_optimization`返回空、exit=0；随后仅执行一次`git push origin lko/base:refs/heads/sandbox/lhmax2025/kernel_optimization`，不加-f，没有向refs/for/*或其他分支推送。使用原origin和正常SSH环境，无GIT_SSH/GIT_SSH_COMMAND覆盖、未修改认证设置。推后再次ls-remote返回上述SHA，与本地逐字比对相同。

证据：[推前](../evidence/task4/sandbox_before.txt)、[推送原文](../evidence/task4/sandbox_push.txt)、[推后](../evidence/task4/sandbox_after.txt)、[最终源码状态](../evidence/task4/final_kernel_state.txt)。服务器对既有f240c28提示`subject >50 characters`，没有拒绝推送；保留原始warning，未改写已推送提交。内核工作树干净，tizen仍为42aeefac58edeb081aff440f0b60be71cbe49755。

## 2. 两个提交的来源和作用

相对`tizen@42aeefac58edeb081aff440f0b60be71cbe49755`正好两个提交：

| 提交 | 来源 | 作用 |
| --- | --- | --- |
| `f240c28093027707f5e09f8a9cbbed16a43ebb1a` — mm: restore vendor reclaim semantics for force_reclaim | 任务2既有lko/base；从vendor a9cc39b8dd1d拆出，作者He Fangyu，提交者Hao Lin | 修复force_reclaim选项位/回调返回值及边界，保留允许swap的vendor回收语义 |
| `0fac5de6a63091d141ad1cd3ed9d9e92b8dde708` — ARM: configs: tizen_bcm2711: enable ARM_PMUV3 | PM指定autofdo_bolt_agent@0dff5b0fcdc52720a286ee9efd3d2360e38728db中的补丁；邮件原提交2834afb2f85a6ef0905de18ed5b4a4ef7059635e | 在CONFIG_GENERIC_PHY=y之后新增CONFIG_ARM_PMUV3=y，普通/RT共用defconfig，arm64不改 |

[补丁下载源](https://raw.githubusercontent.com/lhmax2010/autofdo_bolt_agent/0dff5b0fcdc52720a286ee9efd3d2360e38728db/patches/0001-ARM-configs-tizen_bcm2711-enable-ARM_PMUV3.patch)。下载到WS/temp/patches，大小1834 B，SHA-256严格匹配PM给定值：

`620c35409023bfcf881cafb8a91c20d84a26d625e6d14dc8aba644a32a4ca55e`

`git am`无冲突。随后只删除提交正文中跨两行的指定句“See the project report docs/kernel/03_pmuv3_build_result.md in lhmax2010/autofdo_bolt_agent.”，其余正文逐字验证相同，作者Hao Lin <hao.lin@samsung.com>、作者日期2026-10-28T16:13:43+08:00保持，Signed-off-by和Change-Id `I2f00e4cca847dae70fb9e99f3948ed3df699f05f`保持。此次本地amend发生在首次推送之前；后续不得改写已推送提交。

`git diff f240c280 HEAD`的numstat严格为1增加/0删除，唯一文件`arch/arm/configs/tizen_bcm2711_defconfig`，新增行469。`git log 42aeefac..HEAD`恰为上面两项。[hash/前置核对](../evidence/task4/patch_verification.txt)、[提交与完整差异](../evidence/task4/commits_and_diff.txt)、[正文验证](../evidence/task4/message_verification.txt)。补丁对旧镜像的测试描述保留为补丁来源陈述，本轮没有重做板上验证。

## 3. 四份配置核对

**四组生成成功，平台scripts/diffconfig均仅有 `ARM_PMUV3 n -> y`。** 原任务中“未输出”的前提与保存的任务2最终.config不同：四份均明确写有`# CONFIG_ARM_PMUV3 is not set`。这是原始值口径纠正，没有额外符号差异。

| 对应buildroot | 变体 | 任务2旧配置行 | 新配置行 | 唯一diffconfig结果 | 生成/比较exit |
| --- | --- | --- | --- | --- | --- |
| GCC | arm-rpi4 | 5960：ARM_PMUV3未设置（n） | 5960：ARM_PMUV3=y | `ARM_PMUV3 n -> y` | 0 / 0 |
| GCC | arm-rpi4-rt | 5954：ARM_PMUV3未设置（n） | 5954：ARM_PMUV3=y | 同上 | 0 / 0 |
| LLVM | arm-rpi4 | 5957：ARM_PMUV3未设置（n） | 5957：ARM_PMUV3=y | 同上 | 0 / 0 |
| LLVM | arm-rpi4-rt | 5951：ARM_PMUV3未设置（n） | 5951：ARM_PMUV3=y | 同上 | 0 / 0 |

[汇总及原/新SHA-256](../evidence/task4/config_check_summary.txt)确认旧配置副本与任务2Git证据逐字hash一致；额外使用只做文本比较的解析器核对所有键值，变化集合也严格等于`{ARM_PMUV3: [n,y]}`。平台diffconfig原文：[GCC普通](../evidence/task4/diffconfig_gcc_arm-rpi4.txt)、[GCC RT](../evidence/task4/diffconfig_gcc_arm-rpi4-rt.txt)、[LLVM普通](../evidence/task4/diffconfig_llvm_arm-rpi4.txt)、[LLVM RT](../evidence/task4/diffconfig_llvm_arm-rpi4-rt.txt)。没有手工修改生成后的.config、删去不希望看到的差异或强制其他选项。

### 生成方式与无sudo边界

两个root分别是`WS/temp/GBS-ROOT-TOOLCHAIN-GCC-CODES/local/BUILD-ROOTS/scratch.armv7l.0`与`WS/temp/GBS-ROOT-TIZEN-LLVM-CODES/local/BUILD-ROOTS/scratch.armv7l.0`。使用本机已有bwrap建立无sudo的用户/挂载namespace：平台root及当前linux-rpi源码只读挂载，配置输出与namespace目录全部位于WS/temp/pmu_config_check；TMPDIR为WS/temp。没有安装工具、修改宿主环境或修改既有GBS root。

最初只读root挂载方案试图新建/task4-source，报只读文件系统，未进入配置生成；改为全部在WS/temp准备可写home目录骨架，并把源码挂载到root内原有源码路径。验证平台ARM shell和经qemu-arm的ARM make可运行后，才执行配置操作。[环境预检原文](../evidence/task4/no_sudo_environment_check.txt)。预检直接执行make时可见GBS自带的原生加速工具；正式merge shell、make及diffconfig的Python都显式经该root的qemu-arm启动，make递归也显式使用同一qemu-arm；工具及依赖均来自相应GBS root，没有回退宿主工具链。

按spec:199–201的语义，merge_config.sh带`-m -O`，普通只输入tizen_bcm2711_defconfig，RT再合并kernel/configs/rt.config；两轮实际构建都没有LSM附加fragment。为保证只读源码不接收merge脚本的临时文件，将其当前目录设为对应新输出目录，输入使用绝对路径。随后仅执行`make O=<输出> ARCH=arm olddefconfig -j1`；ARCH与平台uname -m（armv7l）对应，不是改用宿主ARCH。

GCC组LLVM/CC/CXX等覆盖保持未设置；LLVM组按spec:165–168及原日志设置LLVM=1，并复现CC=armv7l-tizen-linux-gnueabi-clang、CXX、AR/RANLIB及MAKEFLAGS=-k。CFLAGS/CXXFLAGS/LDFLAGS从各自任务2构建日志读取，同步原环境；没有对本任务引入额外编译优化选项。没有执行headers_install、Image、vmlinux、modules、dtbs、perf或bpftool目标。

各变体从其原build目录复制已构建的平台scripts/basic与scripts/kconfig工具到新输出目录，保留时间戳以复用。四份生成日志均无HOSTCC/HOSTLD/CC/LD/AR构建行；只生成Makefile/.config等配置文件，编译器能力探测属于olddefconfig自身流程。

生成日志：[GCC普通](../evidence/task4/generation_gcc_arm-rpi4.txt)、[GCC RT](../evidence/task4/generation_gcc_arm-rpi4-rt.txt)、[LLVM普通](../evidence/task4/generation_llvm_arm-rpi4.txt)、[LLVM RT](../evidence/task4/generation_llvm_arm-rpi4-rt.txt)。调度脚本文本：[config_check_driver.py.txt](../evidence/task4/config_check_driver.py.txt)。初次文本断言预期“新增符号”格式，因实际为n→y停止了调度；核对四份原配置后修正该断言，复用已生成GCC普通结果，没有重新生成/改写它。其余三组依次完成，推送门槛仍为且仅为ARM_PMUV3变化。

## 4. 相对板上镜像源码21645b17

`21645b17c0d913e2ba7e10fbc9c993d286b3f57d`已在本地，无需fetch；确认它是lko/base祖先。`git log --oneline 21645b17..lko/base`为 **4个提交**，标题如下（新到旧）：

```text
0fac5de6a630 ARM: configs: tizen_bcm2711: enable ARM_PMUV3
f240c2809302 mm: restore vendor reclaim semantics for force_reclaim
42aeefac58ed drivers: media: pci: hailo: Port Hailo accelerator driver to v4.22.0
d5ef43b342dc configs: packaging: modularize defconfig with RT and LSM fragments
```

[命令原文](../evidence/task4/board_baseline_commits.txt)。本节只列提交数和标题，没有把两源码基线视为仅差PMU一行。

## 5. 后续A/B和QB输入

任务2/任务3已有体积、编译耗时、ACTIME布局及静态分析所对应的构建源码仍是 **f240c280（未启用PMU驱动）**；本任务只生成配置，没有取得含PMU驱动的新zImage/vmlinux体积或运行数据。[03](03_baseline_build.md)、[06](06_static_footprint.md)、[07](07_llvm_text_growth.md)已加基线提示。此后的A/B以本sandbox构建为准，不能把旧体积直接移称新基线结果。

用户在QB上构建填写：

```text
Project: platform/kernel/linux-rpi
Branch: sandbox/lhmax2025/kernel_optimization
Commit: 0fac5de6a63091d141ad1cd3ed9d9e92b8dde708
```

本地lko/base已经跟踪该sandbox。所有未来内核推送仅允许此目标，不允许其他分支、refs/for/*、force push、删除或改写已推送提交。任何后续新baseline仍需新提交并普通推送，保持lko/base与sandbox一致。

任务3交付已在GitHub 3f26e8d2f7806751034b4a15259edf39d9ae0a3c完成。本轮结束后回看其两个可选nm -l扫描，收尾快照仍自然运行；未发信号，未使用其未完成输出，不影响现有任务3结论。[回看证据](../evidence/task4/task3_scan_followup.txt)。未启动新的任务3优化实验。
