# 项目硬规则

1. 所有临时文件和中间产物只能放在 $WS/temp/（export TMPDIR=$WS/temp），不许写到 $WS 以外的任何地方。
2. GitHub 只用 git push 推到 main，不开 PR，不 force push。只上传必要、重要的文件（文档、补丁、脚本、小体积文本证据）。linux-rpi 源码树、temp/、构建产物、RPM、二进制、大于 1 MB 的文件一律不上传，留在工作目录。
3. 提交署名一律用 Hao Lin <hao.lin@samsung.com>，用 git -c user.name=... -c user.email=... 指定，不改全局配置。
4. linux-rpi 本任务只读：不 checkout 其他分支、不改工作树、不提交。可以把远端分支 fetch 到 refs/remotes 下做只读比对。后续需要改代码时另开分支，届时另行说明。
5. 不向 Gerrit 推送任何东西。
6. 控制机器负载：并行度不超过 nproc 的一半。本任务不跑内核编译，也不跑 GBS 构建。
7. 每个任务收尾时更新 $WS/docs/STATUS.md，内容包括：计划、进度、已闭合结论（附证据路径）、需要人工裁决的前提、挂账事项。STATUS.md 与本次产出放在同一个 commit 推送。新 Session 开场先读 STATUS.md 和 RULES.md。
8. 结论必须有证据：给出 文件:行号、commit id 或命令输出。推测要明确标注"推测"。拿不到的信息如实写明原因和尝试过的命令，不要猜。

## 任务2起生效的新增与调整（2026-10-27，PM 指令）

以下规则覆盖上文任务1限定的第4条“源码只读”和第6条“不构建”；其余原规则继续有效。任务2授权在 lko/base 上串行执行 armv7l GCC/LLVM 基线构建，每次 --threads 1、_smp_mflags=-j10，且不超过 nproc 的一半。拆分 a9cc39b8dd1d 时按 PM 明确要求保留原作者 He Fangyu，提交者仍用 Hao Lin <hao.lin@samsung.com>，使用 git -c 指定，不改全局配置。

1. linux-rpi 允许建本地分支，分支名统一用 lko/ 前缀。不许修改 tizen 分支，不许删除或改写任何远端分支，不许向 Gerrit 推送。
2. PM 需要核对源码时，只上传相关文件，不上传整棵树。路径为 code_snapshots/<内核commit短id>/<源码原路径>，并在 code_snapshots/INDEX.md 中记录：文件、commit、上传原因。单个文件超过 1 MB 时，只上传相关片段，并注明行号范围。
3. 构建产物（RPM、vmlinux、buildroot）全部留在 $WS/temp/，不上传。
4. 分析构建产物（size、readelf、nm、bloat-o-meter、objdump、llvm-bolt 等）时，用 GBS buildroot 里平台自带的工具，不用本机工具链。
5. 构建过程中遇到 sudo 密码或任何凭据要求：立即停止，报告卡在哪一步。不要尝试绕过，也不要索要密码。
6. 优先级：armv7l 优先。aarch64 的优化（包括内核 BOLT）在 armv7l 完成后再做；在此之前，aarch64 只做静态记录，不构建、不上板。
7. 开发板：本任务不碰开发板。今后的板上操作都以 PM 下发的任务为准，执行前必须用三项断言确认板子身份：uname -r 包含 rpi4、uname -m 为 armv7l、os-release 为 Tizen。

任务2停止条件：任一构建失败时，保留日志、分析原因并写入报告，然后停止，不修改 spec 或代码；如果 LLVM 配置实际没有使用 Clang，记录原因并停在编译器核验步骤，等待 PM 决定。收尾仍须更新 STATUS.md，与本次已获得产出同一个 commit 推送 GitHub main。
