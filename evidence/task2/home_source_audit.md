# 任务2续二：工作区HOME方案源码核对

核对范围：已安装/usr/bin/gbs、/usr/bin/depanneur、gitbuildsys Python模块和系统Python路径实现。只读源码，没有启动ConfigMgr或gbs。证据：[源码摘录](home_source_lines.txt)、[完整检索输出](home_source_search.txt)。

1. 用户配置定位：gitbuildsys/conf.py:377调用os.path.expanduser('~/.gbs.conf')；没有用pwd取该路径。/usr/lib/python3.12/posixpath.py:270–284在HOME存在时使用环境值，只有HOME缺失才回退pwd.getpwuid。cmd_build.py:80的getpwuid只取用户名作缓存子目录名，不决定用户配置路径。depanneur:433–440对裸~也优先HOME；~指定用户才查询用户数据库，本项目配置均用工作区绝对路径。
2. 自动创建：conf.py:297–300仅在自动发现列表为空时调用_new_conf。当前linux-rpi/.gbs.conf已存在，因此即使准备工作区用户配置之前，在该目录执行也不会触发；步骤2准备后用户配置也存在。若在完全无配置的目录触发，conf.py:386–390同样expanduser，在PM指定HOME前提下目标为$WS/temp/gbs-home/.gbs.conf，父目录须事先存在。并非只传-c就能阻止自动创建，因为初始化发生在add_conf之前。
3. 环境传递：cmd_build.py:724只设置TIZEN_BUILD_ROOT，730使用os.system；depanneur:130设置BUILD_DIR，397–422 fork/exec，784–827调用gbs export，无env清空或HOME/GIT_CONFIG_NOSYSTEM赋值。源码检索没有发现这条导出链重设这两项。因此静态判断会继承调用者环境；本轮未运行进程验证。该判断限于导出链，不扩大为所有sudo/chroot后代：depanneur:2048会调用sudo /usr/bin/build，sudo环境策略及buildroot内abuild环境不能只凭fork/exec推断。
4. HOME其他路径逐项见下表。没有找到gbs/depanneur自身直接读取.rpmmacros、.gitconfig、.cache、.config的代码；这不表示其调用的git/rpm及库不会读取，须由步骤3的open/openat实测验证。不能用静态字符串搜索替代全调用树系统调用审计。

| 路径/用途 | 源码 | 本方案下的定位/是否进入本命令 |
| --- | --- | --- |
| ~/.gbs.conf | conf.py:377、386 | 用户配置加载或自动生成，都expanduser |
| ~/.gbs.conf.template | conf.py:694–700 | 旧格式转换时写入；本项目显式profile配置不走旧格式转换 |
| ~/.gbs.conf.auto | cmd_build.py:501–505、834–836 | 未传-c且full/deps构建时创建；本任务传-c且非full/deps，不触发 |
| ~/.ref-gbs/git-ref-mapping及XML | utils.py:546–563 | 引用版本映射下载/读取；expanduser；本任务普通构建不走自动full/deps仓库映射 |
| ~/gbs-build前缀临时目录 | cmd_build.py:853–858 | full/deps分支，普通构建不触发 |
| ~/GBS-ROOT默认buildroot | conf.py:202、cmd_build.py:686–696 | 项目-c已指定工作区绝对路径，不用该默认值 |
| 配置中的~仓库URL/buildconf、命令行~repo/worktree | conf.py:710、787；cmd_build.py:151、782 | expanduser；本任务实际配置使用HTTP(S)URL及工作区绝对路径 |
| depanneur路径中的~ | depanneur:433–440 | 裸~优先HOME；本项目不使用~其他用户 |
| Git/RPM/第三方库的用户文件 | gbs/depanneur本身没有相应直接读取点 | 运行时证据待采；GIT_CONFIG_NOSYSTEM只禁系统Git配置，不应等同于禁止所有环境注入/用户文件 |

本轮只读环境存在性检查：XDG_CONFIG_HOME、XDG_CACHE_HOME、GIT_CONFIG、GIT_CONFIG_COUNT、GIT_CONFIG_PARAMETERS、RPM_CONFIGDIR、RPM_MACROS、TIZEN_BUILD_ROOT、VIRTUAL_ENV均未设置；/etc/gbs.conf仍不存在。没有读取这些环境项的敏感值。未来启动前仍需复查。

## 执行状态与限制

源码核对未发现工作区HOME无法定位GBS用户配置或导出链主动重设环境的问题；PM的新方案解决此前已知的用户配置定位问题。这里只能给出静态结论，不能声称所有实际文件访问已经合规。

步骤2已完成：$WS/temp/gbs-home/.gbs.conf是普通文件、内容严格为两行；linux-rpi/.gbs.conf及exclude未改，base/tizen不变，见[准备记录](home_preparation.txt)。

步骤3–5未执行的原因是**当前代理执行环境禁止重设HOME**，与PM命令要求冲突；不是GBS报错，不是导出验证失败，也不是此前两个方案仍待PM选择。没有运行任何缺少PM指定环境变量的GBS命令，没有换方法绕过。不存在export_check.strace、r2构建日志或外部写入监测结果，不能标记为通过。此次只继续了用户明确授权、不依赖构建结果的步骤6静态工作。
