# 项目硬规则

1. 所有临时文件和中间产物只能放在 $WS/temp/（export TMPDIR=$WS/temp），不许写到 $WS 以外的任何地方。
2. GitHub 只用 git push 推到 main，不开 PR，不 force push。只上传必要、重要的文件（文档、补丁、脚本、小体积文本证据）。linux-rpi 源码树、temp/、构建产物、RPM、二进制、大于 1 MB 的文件一律不上传，留在工作目录。
3. 提交署名一律用 Hao Lin <hao.lin@samsung.com>，用 git -c user.name=... -c user.email=... 指定，不改全局配置。
4. linux-rpi 本任务只读：不 checkout 其他分支、不改工作树、不提交。可以把远端分支 fetch 到 refs/remotes 下做只读比对。后续需要改代码时另开分支，届时另行说明。
5. 不向 Gerrit 推送任何东西。
6. 控制机器负载：并行度不超过 nproc 的一半。本任务不跑内核编译，也不跑 GBS 构建。
7. 每个任务收尾时更新 $WS/docs/STATUS.md，内容包括：计划、进度、已闭合结论（附证据路径）、需要人工裁决的前提、挂账事项。STATUS.md 与本次产出放在同一个 commit 推送。新 Session 开场先读 STATUS.md 和 RULES.md。
8. 结论必须有证据：给出 文件:行号、commit id 或命令输出。推测要明确标注"推测"。拿不到的信息如实写明原因和尝试过的命令，不要猜。
