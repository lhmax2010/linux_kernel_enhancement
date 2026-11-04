# 任务14：He Fangyu resourced 提交与 tizen 基线核对

2026-11-04（Asia/Shanghai），只读源码与既有镜像证据核对。未构建、未连接开发板、未推Gerrit、未改变任何远端源码引用。GitHub只提交本报告、证据与STATUS。

**结论：16d6125d不基于当前最新tizen，缺少tizen上的1个提交；向最新tizen试cherry-pick干净，0冲突。当前QB1211696镜像中的resourced为10.0.0-1，源码b0bbb7c5，不包含该修复。** 用户态修改兼容修复前的正数返回约定，但不能替代内核侧允许swap的修复；SR基线仍需两侧配套。

## 1. 获取与引用范围

沿用任务4正常SSH环境，远端为`ssh://lhmax2025@review.tizen.org:29418/platform/core/system/resourced`，克隆到被忽略的`ext/resourced`。先`git ls-remote --heads`列出所有分支，再`git clone --no-checkout --branch tizen`取得完整历史及远端分支；没有仅取单分支或浅克隆。clone已取得目标对象，因此无需直接按SHA补fetch。`--no-checkout`使主克隆仅用于对象查询，试移植使用另建工作树。

`git branch -r --contains 16d6125d0cbb99eea354eee4315d7ed301e67917`仅返回：

```text
origin/sandbox/lhmax2025/silent-reclaim-fix
```

该分支HEAD就是目标提交。结论范围为本次全部`refs/heads`，不声称检查了Gerrit未合并的`refs/changes`。开场与收尾两次远端查询一致；“最新”仅指本轮查询时刻，不是未来承诺。

证据：[全部远端分支](../evidence/task14/remote_heads.txt)、[克隆](../evidence/task14/clone.txt)、[contains](../evidence/task14/containing_branches.txt)、[收尾远端复核](../evidence/task14/remote_final.txt)。每份有命令、输出、退出码。

## 2. 提交关系

|对象|SHA|提交日期（原时区）|标题|
|---|---|---|---|
|当前tizen HEAD|`82e79c09ea80c1977dfb27d3752577c74340f9bc`|2026-10-27 13:54:59 +09:00|lowmem-controller: Keep memory-limited apps in Private cgroup on BackgroundMru|
|merge-base|`1d529ce7b24d7b4c3a8fca7c25c4173a228c6f01`|2026-09-29 18:02:10 +09:00|Convert shell scripts from bash to dash compatibility|
|He Fangyu提交|`16d6125d0cbb99eea354eee4315d7ed301e67917`|2026-10-19 10:45:34 +08:00|memory: fix silent failures throughout the reclaim path|

上表日期为committer date；对应author date分别为2026-10-26 15:30:49 +09:00、2026-09-29 17:34:54 +09:00、2026-10-19 10:13:07 +08:00。目标作者/提交者均为He Fangyu，最新tizen提交作者为Unsung Lee，merge-base作者为DongHun Kwak。

`merge-base --is-ancestor origin/tizen 16d6125d...`退出1（非祖先）。两侧从merge-base分叉，各自1个提交：

```text
b0bbb7c5（QB1211696镜像源码）
  └─ 1d529ce7（共同基线）
       ├─ 82e79c09（当前tizen）
       └─ 16d6125d（He Fangyu修复）
```

tizen在merge-base之后新增的全部提交只有上表`82e79c09`；目标分支在merge-base之后的全部提交只有上表`16d6125d`，并不存在还需携带的其他隐含前置提交。

目标修改**11文件，206行增加、59行删除**：cgroup专用接口及声明、watchdog计数处理、配置解析、文件读写辅助、notifier释放、watchdog恢复调用、lowmem-controller、compaction、swap及zramswap。逐文件统计、完整作者和标题见[目标提交列表](../evidence/task14/target_since_base.txt)及[补丁](../evidence/task14/target_patch.txt)。

证据：[tizen HEAD](../evidence/task14/tizen_head.txt)、[merge-base信息](../evidence/task14/merge_base_info.txt)、[祖先判断](../evidence/task14/ancestry.txt)、[tizen新增列表](../evidence/task14/tizen_since_base.txt)、[机器可读汇总](../evidence/task14/history_summary.json)。

## 3. 向最新tizen试移植

在`temp/task14/try_tizen`基于固定tizen HEAD建立detached工作树，执行：

```sh
git cherry-pick --no-commit 16d6125d0cbb99eea354eee4315d7ed301e67917
```

结果exit0，自动合并`src/resource-limiter/memory/lowmem-controller.c`成功。冲突文件0、冲突段0；暂存差异仍为11文件、+206/-59。未产生新提交，未移动任何源码分支；这是单提交向最新基线的干净cherry-pick试验，不是已发布rebase分支，也不是编译或运行验证。

试验后用`git worktree remove --force`仅删除本任务生成且带暂存修改的临时工作树，保留命令、暂存diff和统计。`worktree list`确认仅余主克隆，临时目录已不存在。

证据：[添加工作树](../evidence/task14/worktree_add.txt)、[试打输出](../evidence/task14/cherry_pick.txt)、[冲突查询](../evidence/task14/conflict_files.txt)、[暂存统计](../evidence/task14/trial_diff_stat.txt)、[暂存diff](../evidence/task14/trial_diff.txt)、[删除工作树](../evidence/task14/worktree_remove.txt)、[最终工作树列表](../evidence/task14/worktree_list.txt)、[试验汇总](../evidence/task14/trial_summary.json)。

## 4. QB1211696当前镜像中的resourced

此前板上BUILD_ID为`tizen-unified-toolchain_20261028.105834_tizen-headed-armv7l`，且RPM查询已记录resourced/resourced-bin/resourced-config均为10.0.0-1；本轮不连板，只沿用[任务5包版本证据](../evidence/task5/A_config_comparison.txt)和[任务5配置证据](../evidence/task5/F_resourced_config.txt)。

任务8保存的是boot镜像包清单，其中没有resourced；不能据此判断用户态包不存在。本轮从**同一QB产物目录的headed镜像**补取`.packages`，并与任务8留存仓库`primary.xml`交叉核对：

|镜像中的包（armv7l）|版本|来源提交|
|---|---|---|
|resourced、resourced-bin、resourced-config、resourced-isu、resourced-watchdog-handler|10.0.0-1|`b0bbb7c5a1c9dc90100928cf7b230cc751722a19`|

该源码提交是当前tizen和目标提交的共同祖先：到tizen为2个提交（1d529ce7、82e79c09），到目标为2个提交（1d529ce7、16d6125d）。镜像既没有He Fangyu修复，也没有当前tizen最新的cgroup修复。它的包版本号不能独自标识源码，必须同时记录manifest中的VCS SHA。

证据：[headed清单摘录及URL](../evidence/task14/image_manifest_excerpt.txt)（原始行1101–1105）、[primary选取记录](../evidence/task14/image_primary_selected.xml.txt)、[文件SHA与包来源汇总](../evidence/task14/image_provenance.json)、[镜像提交关系命令](../evidence/task14/image_git_relations.txt)。完整清单留在`temp/task14/headed.packages`，未下载或安装RPM。本结论是已记录QB镜像的来源闭合，不是本轮重新读取板上当前包状态。

## 5. 改动行为及内核依赖

以下为固定提交的源码分析，未做编译、故障注入或板上运行；源码摘录保留原文件行号，不能把“命令提交成功”当成“实际回收了目标页数”。

### memory.force_reclaim：兼容旧返回，不重复提交

`src/common/cgroup/cgroup.c:121–165`新增`cgroup_force_reclaim`，使用open及**单次write**提交十进制页数。任何正返回视为命令已提交，不按短写重试；write返回0按EIO失败，负值保留errno（缺失时EIO）。成功write后的close错误只记录，不把已经提交的命令反转为失败。`swap.c:312–315`改用该接口。

这里要区分**内核write_u64回调返回0**和**用户态write系统调用返回0**。`kernel/cgroup/cgroup.c:4242–4256`先执行回调，最后`return ret ?: nbytes`：修复后的回调返回0，会转换成正的写入字节数；旧回调返回正的回收页数时，会直接作为正返回传出。新resourced兼容这两种正返回，避免把回收页数当成短写而重复提交。证据：[用户态源码](../evidence/task14/resourced_source_excerpt.txt)、[内核分派及修复源码](../evidence/task14/kernel_source_excerpt.txt)。

### zram压缩算法回退

`zramswap.c:37`默认回退为lz4。`:151–163`只在配置算法写入返回`-EINVAL`且配置算法不是lz4时尝试lz4，避免无条件回退、重复尝试lz4。其他权限/I/O错误继续上报。仍为`-EINVAL`时读取`comp_algorithm`中`[...]`选中项，能够确认当前算法才沿用；`-EBUSY`表示设备已初始化，保留内核当前算法，即使读取/解析当前算法失败也警告后继续（`:92–128`）。这不是强制得到配置所指定的算法。

原通用写辅助仅检查fputs，可能漏掉缓冲区刷新/关闭阶段错误；`file-helper.c:37–90`现在检查fputs、fflush和fclose，保留首个错误、errno缺失用EIO，从而使上述回退真正收到失败原因。专用force_reclaim不走该stdio helper，避免flush/close再次提交有副作用的命令。

### swap状态及其他修复

- `swap.c:617–642`仅在设备已激活（activate返回-EEXIST）或swapon成功后标记SWAP_ON；普通activate失败移除对应模块，不再错误标记为ON；移除时使用安全链表遍历。
- `zramswap.c:265–268`用double算后台swap占比，先检查总已用swap大于0，避免整数截断和除零；`:171–191`沿用已有非零disksize，未重新设置已初始化容量。
- `swap.c:552–585`开机回收用ULLONG_MAX处理usage读取失败的初值，并在usage不下降时停止，避免无符号差值下溢。
- 同提交还覆盖整数读取转换检查、true/false配置解析、文本“1”触发compaction、vconf读取失败初值/日志、notifier安全释放，以及watchdog计数持久化失败不能阻止恢复动作。完整范围见补丁，不能把它描述为只改zram一处。

### 不带f240c280时是否仍能工作

**静态判断：用户态接口兼容和其他修复仍可工作，但无法恢复旧内核被禁用的匿名页swap回收；所以不能代替内核修复。**

- f240c280之前的`mm/memcontrol-v1.c:2426–2452`把boolean true传给现在的reclaim_options，并返回累计页数。新helper接受其正返回；若累计页数为0，cgroup分派仍把0转换为nbytes，所以write成功也不证明真的回收了页。
- `include/linux/swap.h:420–421`定义MAY_SWAP为`1 << 1`；`mm/vmscan.c:6607`按该位决定may_swap。旧值true=1不含此位，用户态修改无法打开它。f240c280改为MEMCG_RECLAIM_MAY_SWAP并修正write_u64返回契约、范围/循环终止逻辑。
- 若内核根本没有memory.force_reclaim节点，helper会在open时返回错误；此提交没有另造等价的内核回收接口。

依据：[修复前源码](../evidence/task14/kernel_parent_excerpt.txt)、[修复后与位定义/分派](../evidence/task14/kernel_source_excerpt.txt)。QB1211696的内核固定提交0fac5de6已包含f240c280（[任务4基线记录](08_sandbox_baseline.md)），但其resourced仍是上述旧提交。后续SR基线应明确固定内核修复和配套用户态源码，是否选择“最新tizen+本提交”由PM决定；本轮仅证明该单提交可干净移植，不发布新源码或镜像。

## 6. 收尾与证据完整性

临时工作树已删除；克隆仓库和原始资料保留在被忽略的ext/、temp/task14/，没有触及vendor_local、任务9构建文件或内核工作树。证据只含本任务resourced及已公开基线的必要文本，单文件均小于1 MB，无ANSI颜色；[证据哈希清单](../evidence/task14/manifest.sha256)覆盖随报告提交的证据。主源码仓库没有推送；GitHub提交仅承载本报告、STATUS的一行更新及任务14证据。
