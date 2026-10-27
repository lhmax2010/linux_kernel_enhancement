# git-buildpackage 配置核对（任务2续五）

证据为本机已安装源码的只读摘录：[gbp_source_lines.txt](gbp_source_lines.txt)。没有导入执行gbp/gbs模块，没有运行脚本。

1. 默认顺序：`/etc/git-buildpackage/gbp.conf` → `~/.gbp.conf` → `%(top_dir)s/.gbp.conf` → `%(top_dir)s/debian/gbp.conf` → `%(git_dir)s/gbp.conf`，见`/usr/lib/python3/dist-packages/gbp/config.py:323–327`。top_dir来自repo.path，git_dir来自repo.git_dir（:367–370）。:407–408按顺序读取；Python `configparser.py:1047–1085`合并已有section并赋值，因此后文件同名键覆盖前文件。内置默认、[DEFAULT]、旧命令section、当前命令section、额外指定section依次更新，见gbp/config.py:397–438；命令行参数随后解析。
2. `GBP_CONF_FILES`支持冒号分隔路径，非空字符串在:357–360用split(':')**完全替换**默认列表，并expanduser；未设置或空字符串回退默认列表，不应传空值。no_local会筛掉非绝对路径（:360–362），本方案绝对路径不受影响。传工作区文件只影响配置列表，不取消内置默认值。
3. 指定文件不存在/不可打开时，gbp/config.py:389调用的`/usr/lib/python3.12/configparser.py:665–690`捕获OSError并跳过，不回退系统配置；格式错误不属于该忽略逻辑。本项目预检要求文件存在、可读、非空、普通且不是符号链接，每行仅注释，避免静默缺失。
4. GBS export使用**库调用**：`gitbuildsys/cmd_export.py:34`导入gbp.scripts.buildpackage_rpm.main，:225调用gbp_build(gbp_args)，不是另起gbp程序。argv[0]是:143的占位字符串；buildpackage_rpm.py:391–392按basename(argv[0])创建Rpm解析器且不指定额外sections，config.py:448默认sections=[]。因此不能把本次配置section误写为Debian的[buildpackage]。
5. `gbs build → depanneur → gbs export → GBP库`环境链：cmd_build.py:724只设置TIZEN_BUILD_ROOT，:730 os.system；depanneur:784–827拼出普通gbs export并交给my_system，:397–425 fork/exec继承环境，没有sudo/env -i或清空GBP_CONF_FILES；export库直接读同一进程os.environ。检索`$ENV`仅发现VIRTUAL_ENV、BUILD_DIR等既有赋值，未发现GBP_CONF_FILES覆盖。故静态确认变量能传到导出，不扩大到后续sudo/chroot构建进程。用户下次trace才是新隔离的运行证据。

## 系统gbp.conf的实际内容与影响

[gbp_system_config.txt](gbp_system_config.txt)逐行保存所有非空、非注释行。当前文件没有凭据。空section共9个：[DEFAULT]、[buildpackage]、[import-orig]、[import-dsc]、[dch]、[pq]、[clone]、[pull]、[create-remote-repo]；它们没有提供任何设置值。

| 实际设置 | 所属section | 对上次导出的影响 |
| --- | --- | --- |
| remote-url-pattern = ssh://git.debian.org/git/pkg-libvirt/%(pkg)s | remote-config pkg-libvirt | 远端仓库创建模板；本次导出解析器不选择此section，未进入self.config，不改变导出内容 |
| template-dir = /srv/alioth.debian.org/chroot/home/groups/pkg-libvirt/git-template | remote-config pkg-libvirt | 同一远端模板的目录设置；本次不选择该section，不用于导出 |

上次trace:15132、15252证明文件被读取两次；buildpackage_rpm.py:518–543先解析参数，再根据tree重新解析配置，解释两次读取。结论是**读取发生过，但当前这两个有效设置不参与该导出**，并非声称系统配置普遍无害。文件是否在更早尝试时内容相同没有历史快照，不能回溯保证；本结论基于本次读取的内容与上次调用链。
