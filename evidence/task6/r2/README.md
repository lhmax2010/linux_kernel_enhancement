# 任务6 r2证据（2026-11-02）

仅SDB访问192.168.108.26:26101；宿主原始文件位于temp/task6/r2，前轮temp/task6文件保留。本轮未重启、未执行服务脚本。报告见docs/11_board_boot_chain.md末尾。

- board_commands.jsonl：每条SDB命令、时间窗口、传输退出码和原始文件名。传输退出0不代替远程子命令成功；输出中的*-EXIT、错误和状态字段分别作为证据。复合只读命令未逐项包装的状态不虚构。
- 01/03：三项身份、初始进程/uptime、cmdline、partitions、blkid、mounts、内存日志。
- 04、06、08–10：boot三次ro挂载/立即卸载；全部文件清单、config全文、cmdline.txt不存在；strings缺失后SDB只读pull两个文件。
- boot_files.tsv、config.txt.txt：从04原文提取；boot_script.txt为legacy uImage数据解码并验证头/数据CRC；uboot_environment.txt为NUL分隔环境的ASCII文本，未执行。boot_decode.txt记录方法和哈希，两个原始二进制仅在temp。
- 05、11、12、14：模块结构、槽位脚本/环境关联、inform字节、固件/EEPROM版本及克隆状态。
- 07、oom_score_adj.tsv：阶段0a BTF、所有当时可读PID的oom_score_adj、两份btrfs相关规则全文、F2FS选项、freezer目录。
- kernel_source_excerpts.txt：linux-rpi@0fac5de6 spec包路径、tryboot notifier、restart源码，保留原始行号。
- tryboot_references.txt：只读参考链接、上游systemd v244参数解析摘录；未声称与Tizen二进制完全相同。
- 13、15：安装目标不存在、根rw、resolv.conf/ConnMan持久化路径及等待所用D-Bus只读接口验证。
- bash_n.txt、host_verify.txt：宿主语法检查和仅参考的unit检查；宿主缺ExecStart路径是预期参考差异，不作板上判定。
- 16、17：仅推两安装文件，安装模式、SHA、daemon-reload/enable退出码和链接。
- 18、19：PM替代验收；journal完整读取退出0，无lko-net-setup警告/错误；保留其他服务告警，不干预或强归因。ExecMainPID=0、inactive/dead证明没有本服务执行记录。
- 20–22、cleanup_and_verification.txt：临时目录删除、mounts/df前后对照、owner恢复。
- raw_manifest.tsv：原始transport字节数/SHA；本文目录为去ANSI/控制换行并裁掉行末空格的文本副本，其哈希见manifest.sha256。原始精确字节留temp。

宿主可复核命令：bash -n scripts/board/lko-net-setup.sh；sha256sum scripts/board/lko-net-setup.*；git -C linux-rpi rev-parse HEAD；git -C linux-rpi status --porcelain。均只检查，没有运行板上脚本。人工自查包括接口操作顺序、等待截止、DNS软失败、unit依赖/类型、安装模式和不执行约束。
