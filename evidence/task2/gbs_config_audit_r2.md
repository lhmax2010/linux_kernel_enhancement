# 任务2续：GBS配置审计（停止于步骤B）

日期：2026-10-27。仅执行已安装工具源码审计和PM明确指定的外部配置键名审计；没有导入gitbuildsys.conf运行ConfigMgr，没有启动GBS/export/strace/build。以下外部配置键值一律不记录。

## 1. 配置查找与合并

源码摘录见 [gbs_config_source_r2.txt](gbs_config_source_r2.txt)。路径均为本机已安装工具。

| 环节 | 行为与证据 |
| --- | --- |
| ConfigMgr初始化 | conf.py:287–303：可选fpath放在列表最前，但仍追加自动发现配置；没有“只读这个文件”模式。conf.py:913在模块导入时实例化单例。 |
| repo工具项目配置 | conf.py:358–375：从os.getcwd()逐级向上找首个同时存在.repo和.gbs.conf的目录，放在自动发现列表首位。不是向上找任意.gbs.conf，也不是自动找.git根目录。 |
| 当前目录、用户、系统 | conf.py:376–380：依次追加cwd/.gbs.conf、~/.gbs.conf、/etc/gbs.conf，存在才追加，按路径字符串去重。 |
| 加载与默认值 | conf.py:314–330：每个文件独立解析，最后追加内置默认值。general.work_dir为点号时改为对应配置所在绝对目录（322–326）。 |
| 合并 | conf.py:431–441：对每一个section/键从优先级最高层开始取第一个可用值；不是整节替换。446–462合并所有层的键名，464–469合并section存在性。 |
| -c | /usr/bin/gbs:790–798：解析参数后调用add_conf；conf.py:334–346把-c文件插到最前并重新加载全部文件。因此-c提高优先级，不屏蔽用户/系统文件。 |
| 仓库根级配置 | utils.py:687–701：gitdir位置参数用RpmGitRepository解析repo.path，再read_localconf；674–679在repo.path不同于cwd时把该根目录.gbs.conf插到最高层。cmd_export.py:267和cmd_build.py:839在命令入口再次调用。因而不能笼统说-c永远高于项目配置：不同cwd时命令入口可能再次把项目配置提升；本任务cd到linux-rpi，read_localconf不重复添加。 |
| 命令行参数 | conf.py:509–517：get_arg_conf遇非None命令行值优先于配置。 |
| 无配置时 | conf.py:298–300、384–390：可能创建~/.gbs.conf；不能把“删除外部配置”当作隔离方案，且用户禁止修改外部文件。 |
| 解析副作用 | conf.py:332、395–429：加载后扫描各层passwd键，可能写回原文件；更高优先级覆盖同名键也不会取消逐层扫描。当前实查没有凭据键，没有触发或运行这段逻辑。 |

自动发现的完整优先顺序是“首个祖先.repo根配置 → cwd配置 → 用户配置 → 系统配置 → 内置默认值”；显式-c/add_conf再按实际调用时机插到最前。repo.path补读提供Git根查找，但不是ConfigMgr自动发现本身的行为。

## 2. depanneur的cwd与导出可见性

本任务命令从$WS/linux-rpi启动。cmd_build.py:730通过os.system调用depanneur，本命令未使用full/deps/worktree；其923–925的chdir只在full/deps分支，935–942普通构建直接调用_build_one。depanneur:621–629从cwd或--path定位包目录；784–827拼装gbs export '$base'，没有-c，也没有在此处chdir。my_system在397–422通过fork/exec继承调用处cwd，没有cwd覆盖。目录遍历用File::Find，不能用局部遍历时目录推断所有子命令cwd。

即便调用时cwd不等于linux-rpi，gbs export '$base'的SearchConfAction和cmd_export.py:267仍会读取repo.path/.gbs.conf（utils.py:674–701）。所以源码可证：**步骤C的项目配置能被导出子进程读取；tmpdir键会覆盖内置/外部低优先级值。** 这是静态结论，未运行验证，不能写成“strace已通过”。

## 3. 外部配置逐键审计

使用Python标准库RawConfigParser只枚举section/键名；原始结果见 [external_gbs_keys_r2.txt](external_gbs_keys_r2.txt)。/etc/gbs.conf不存在；~/.gbs.conf存在，共5个section、5个键，无DEFAULT项，无user/passwd/passwdx等凭据键。空节也完整列出。以下export一栏假设按步骤C只有两行项目配置；未实际创建或加载。

| 外部section / 键 | 指定-c的gbs build | gbs export（不传-c） | 本轮覆盖动作 |
| --- | --- | --- | --- |
| general / profile | 两个config/gbs_*.conf:4已显式选择项目profile，覆盖外部值 | 仍在解析器低优先层可查询；cmd_export不选择构建profile，不影响源码导出 | 已有覆盖，本轮无新增 |
| general / buildroot | 两个config/gbs_*.conf:5已有工作区内独立buildroot，覆盖外部值；cmd_build.py:686–698在无命令行/environment/profile buildroot覆盖时读项目值 | 仍可查询，但cmd_export使用显式-o和tmpdir，不消费buildroot | 已有覆盖，本轮无新增 |
| profile.tizen / repos | 项目选择profile.tizen_unified_standard:repos，外部节不选用 | 不构造构建profile，不消费该键 | 无需改动；不把外部仓库复制进项目 |
| repo.tizen_base / url | 项目repos仅引用repo.base-standard、repo.unified-standard，外部节不选用 | 不消费仓库URL | 无需改动 |
| repo.tizen_unified / url | 同上 | 同上 | 无需改动 |
| repo.my_local / （空节） | 没有键，且未选用 | 没有键 | 无需改动 |

build选择profile见cmd_build.py:329–343；repo列表及URL按所选profile取值见conf.py:708–713、754–765。export实际配置访问见cmd_export.py:64、68、75、87、110–119、177、218、236、280、298；没有profile/buildroot/repos/URL访问。

本轮config/gbs_gcc.conf和config/gbs_llvm.conf **改动0个键**：影响当前build路径/仓库的外部键已有覆盖或未被选用；本轮没有发现需要新增行为覆盖的键。原有tmpdir是此前任务已加入的工作区值，不冒充本轮新增。本轮环境检查TIZEN_BUILD_ROOT未设置，因此没有该环境变量覆盖项目buildroot；此结论不替代下次启动前复查。

## 4. 为什么停在B

按当前文件内容，项目配置足以隔离已知键对build/export的行为影响；但是**键值覆盖不等于禁止读取外部文件**。conf.py:318–321无条件遍历自动发现列表并read_one，-c和项目文件不会把~/.gbs.conf从列表删除，conf.py:53–55调用ConfigParser.read，65–70保存读取的原文件内容。ConfigMgr没有关闭用户/系统配置发现的开关。这种外部配置输入和解析行为不能通过本任务两个-c配置或两行项目配置覆盖掉。

PM最前面的硬要求是“不使用工作目录以外的文件（配置、脚本、数据等）”，后面步骤服从它。因此这里按严格文件隔离理解停止；**不是声称有未覆盖的构建键，也不是项目.gbs.conf不可见**。尚未执行C/D/E，未改写既有受跟踪项目.gbs.conf或添加exclude项，未运行导出/strace或任一r2构建。不存在r2工作区外写入监测结果，不能把“未执行”写成“未检测到越界”。

### 步骤C的额外前提：项目文件已受跟踪

收尾验证发现 `$WS/linux-rpi/.gbs.conf` 是已存在的普通文件，并非待新建文件；`git ls-files --stage -- .gbs.conf` 返回100644、blob f744dbaac48eacff6f1c4c55d00e550f24c69daf。内容是general下的upstream_branch、upstream_tag、squash_patches_until三键，均为工作区内文件，不受外部键值保密限制。文件内容、历史commit与命令结果见[existing_project_gbs_r2.txt](existing_project_gbs_r2.txt)。本轮原样保留。

因此按C改成只含tmpdir的两行会修改受跟踪工作树；`.git/info/exclude`只影响未跟踪文件，不会使此修改消失。既要两行内容、又只用exclude、还要git status干净，这三个要求在当前仓库上不能同时满足。现有三键也参与源码导出，删去会改变默认导出参数，不能无记录忽略。该前提需PM裁决：是否允许新的项目配置提交（与A“仅改标题”区分），或者改用不改受跟踪文件的独立配置注入/工具副本方案；不能通过assume-unchanged/skip-worktree掩盖工作树差异。本轮未做任何这类操作。

## 5. 可行的替代设计及影响面（未选择、未实施）

| 方案 | 如何隔离 | 影响面与待验证点 |
| --- | --- | --- |
| 工作区独立GBS工具副本 | 在$WS/temp内准备已安装GBS的独立副本，仅改其配置发现为工作区文件白名单；本任务PATH/Python模块路径指向副本，覆盖depanneur启动的嵌套gbs | 不改已安装gbs/depanneur或外部配置，不影响其他任务；需要PM授权此工具副本改动，审阅与原工具差异，验证Python导入路径及嵌套gbs归属，然后重做strace。当前未复制/修改工具。 |
| 本任务专属文件系统隔离环境 | 为本任务配置视图隐藏外部gbs.conf，并确保GBS所见项目配置、所有可写路径均来自工作区；系统工具只读提供 | 不修改共享原文件；需设计并核验隔离权限、GBS的root/chroot流程和子进程继承，不能未经验证假定可用，不执行sudo/挂载探测。对运行方式影响大于单独工具副本。 |
| PM明确允许解析外部文件但不采纳其行为值 | 沿用原工具和已有逐键覆盖，项目两行tmpdir解决导出路径；每次启动前重审键名与覆盖 | 这是放宽最前面硬要求的选项，当前规则下不可执行。仍存在其他任务修改外部配置后影响本项目的风险；不能声称实现文件级隔离。 |

以上只供PM裁决，不自行选用任何方案；保持本次停止状态。
