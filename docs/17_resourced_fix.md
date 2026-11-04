# 任务15：resourced 回收路径修复（待 PM 审核）

本轮基于查询时最新的公开 Tizen resourced 源码自行整理修复，不推 Gerrit、不部署。本文不包含板上运行验证。

## 1. 基线、提交与审核范围

2026-11-04 查询 `platform/core/system/resourced`：`origin/tizen` 仍为 `82e79c09ea80c1977dfb27d3752577c74340f9bc`，与任务14一致；`sandbox/lhmax2025/kernel_optimization` 不存在。已从该 tizen HEAD 新建本地 `lko/resourced-fix`。用户授权日后创建此 sandbox，但本轮只交审核材料。

证据：[远端查询](../evidence/task15/remote_before.txt)、[fetch](../evidence/task15/fetch_tizen.txt)、[基线摘要](../evidence/task15/source_base.json)。收尾只读复核仍相同（[remote_after.txt](../evidence/task15/remote_after.txt)）。本轮未修改内核源码，未改变任何远端源码分支。

参考提交为 He Fangyu 的 `16d6125d0cbb99eea354eee4315d7ed301e67917`。保留所有现有生产函数名称和调用方式，按问题分为九个本地提交；每个提交正文均注明 `Based on analysis of He Fangyu's fix 16d6125d`。

|序号|本地提交|解决的问题|
|---|---|---|
|1|`152161a1d80b2dbf244f044824699df77f84d5d1`|force_reclaim 只提交一次，兼容旧内核正数返回|
|2|`3f59151b2f8b9f2d506181d61722d1d7b9555c7c`|传播缓冲写入、刷新、关闭错误，保留首错|
|3|`53452fa3315f10c02c0260efe032e3e6ef398779`|配置算法不可用时保留内核已选中算法|
|4|`abdbc4a414b9616b5d90f3ae1c2f4c6b114a9d0e`|普通激活失败不再误标 SWAP_ON；安全移除失败模块|
|5|`a8e3344c10d355857a17b008709ee303a0ecc9f6`|开机回收缺少有效读数时停止，防止无符号下溢|
|6|`7d418a6604fb8d00950713b318befd863a9b92c5`|swap 使用占比先转浮点计算，并保护零分母|
|7|`649d9434977b52357f28fd69d99fef19477de9d2`|compact_memory 使用文本整数触发|
|8|`879c021f9daac03875c5919f5456876e741885ed`|四类整数读取均拒绝无转换结果，保留调用者原值|
|9|`94d346c306233803661e8eab8557596549d82be4`|vconf 读取失败后使用明确的未知状态|

完整提交说明：[source_commits.txt](../evidence/task15/source_commits.txt)。补丁系列在 [patches/resourced](../patches/resourced/)，按编号应用到上述固定 tizen 提交；[SHA-256 清单](../evidence/task15/patches.sha256)。所有生产修改仅涉及公开 resourced 代码。以下行号以本地最终 HEAD `94d346c3` 为准；参考提交与旧内核行号分别见任务14原文证据。

## 2. 分问题分析与取舍

### 2.1 memory.force_reclaim 的写入与返回值

**现象与根因：** 现有调用经 `cgroup_write_node_uint32` → `fwrite_uint` → stdio 写入命令节点。旧内核的回调返回回收页数，可能与请求字符串字节数不同，stdio 的短写处理不适合有副作用的命令。另一方面，修复后的内核回调返回0，不能错误地要求用户态 write 也返回0。

内核 `kernel/cgroup/cgroup.c:4242–4256` 的 write_u64 分派以 `ret ?: nbytes` 返回：回调0转换为正字节数；旧正页数直接传出。`mm/memcontrol-v1.c:2426–2452` 的旧实现传入 true，不含 `MEMCG_RECLAIM_MAY_SWAP` 位；修复 f240c280 才恢复允许 swap 的语义。见 [内核分派/修复](../evidence/task14/kernel_source_excerpt.txt)和[旧内核](../evidence/task14/kernel_parent_excerpt.txt)。

**16d6125d 的做法：** 新增 cgroup_force_reclaim 专用函数并修改调用者，单次 open/write/close，任何正返回视为提交成功，0返回 EIO，失败保留 errno，不重试短写；close 失败只记日志。

**本次采用：** 保留原函数与调用者，在 `cgroup_write_node_uint32` 内仅对 `MEMCG_FORCE_RECLAIM` 走同样的单 write 语义（`src/common/cgroup/cgroup.c:121–160`）；其余 uint32 节点继续原有辅助路径。额外检查拼接路径是否截断。没有新增生产接口、没有重试 EINTR/短写。正返回仅代表命令已提交，不能证明回收了多少页；close 失败不能把已执行命令变为“可重试失败”。

**依赖和风险：** 用户态兼容两种返回契约，但不能替代 f240c280 的 MAY_SWAP 修复；SR 基线仍须内核和用户态配套。write 错误也不保证内核未产生部分副作用，调用者不得据此无限重试。回归测试模拟完整/短/超长正返回、0、EINTR、EACCES、缺 errno、open/close 失败与超长路径。

### 2.2 文件写入错误传播

**现象与根因：** `fwrite_str` 原来只判断 fputs，使用自动 fclose 清理；短字符串可能还在缓冲区里，真正写 sysfs 时的 EINVAL/EBUSY/权限错误在关闭时才发生，调用者却收到成功。算法回退及其他配置写入因而失去可信的失败信息。

**参考做法与采用：** 显式检查 fputs、fflush、fclose，保留最早错误，errno 缺失用 EIO。与参考同一策略，仍使用现有 `fwrite_str` API；代码在 `src/common/file-helper.c:37–69`。新测试覆盖正常、fputs 失败、延迟 flush 失败、仅 close 失败，以及首错不被后续 close 错误覆盖。

**副作用：** 以前被吞掉的错误现在会让调用者停止，属于必要的错误传播。fclose 在刷新失败之后仍可能处理缓冲区，通用 stdio helper 不承诺有副作用命令的 exactly-once；因此 2.1 的命令节点单独使用一次 write。部分写入后报错不等于回滚。

### 2.3 zram 压缩算法回退

**现象与根因：** 原来不论何种写入错误都再写硬编码 DEFAULT_ZRAM_COMPRESSOR（lz4）。这会掩盖权限/I/O 错误，在只编 LZO 的内核上仍然失败。RPi 镜像配置实际为 `CompAlgorithm=zstd`（[任务5配置](../evidence/task5/F_resourced_config.txt)，原始配置第68行），而 QB1211696 最终配置只有 LZO 后端、默认 lzo-rle（[最终配置](../evidence/task5b/qb_arm-rpi4.config):1688–1697）。

**参考做法：** 只在 EINVAL 且配置不是 lz4 时再试 lz4；仍不可用或 EBUSY 时尝试保留内核当前算法；已初始化设备即使读不出当前算法也警告后继续。

**本次修改：** 只尝试配置算法一次；EINVAL 或 EBUSY 时读取 comp_algorithm，必须能确认非空的 `[...]` 选中项，然后保留它，不写任何任意指定的后备算法。其他错误直接上报；读不到或解析不了选中项也失败。直接在原 `swap_zram_activate` 内处理，不另造生产函数。见 `zramswap.c:92–163`。内核 store 在不可用算法时返回 EINVAL、已初始化时返回 EBUSY；show 输出选中项的机制见 [内核源码摘录](../evidence/task15/kernel_algorithm_excerpt.txt)。

**两目标推演（静态，非本轮板测）：**

|场景|请求 zstd 的结果|后续行为|
|---|---|---|
|SR：QB1211696 LZO-only，初始 `[lzo-rle]`|EINVAL|读回选中 lzo-rle，保留它，继续原 disksize/mkswap/swapon 流程；不会再尝试 lz4|
|类产品基线：lz4 与 zstd|成功|继续使用 zstd；没有回退|
|上述任一内核，配置了其他不可用算法|EINVAL|只保留该内核显示的当前可用算法，不假定 LZO/LZ4/ZSTD 均存在|
|已初始化但尚未 swapon|EBUSY|确认当前选中算法后保留；原有非零 disksize 不覆盖|
|已经 swapon|activate 提前返回 -EEXIST|上层确认为已激活，不重复配置|
|权限、I/O、读取/格式错误|失败|明确停止激活，不把未知状态伪装成可用|

“得到可用 zram”是算法选择层面的兼容性保证；设备节点、权限、内存分配、mkswap/swapon 仍可能独立失败。保留算法意味着实际算法可能不同于配置，日志会明确写出请求与保留值。本次不 reset 设备、不改容量策略、不强制切换已运行的 swap。

### 2.4 SWAP_ON 误标与链表移除

**现象与根因：** 原 `swap_activate_in_module` 在 activate 的所有负返回分支里都设 SWAP_ON，即普通失败也误认为已开启。随后状态检查可能阻止再激活；同时在普通遍历中删除当前 GSList 节点会使用失效迭代器。

**采用参考策略：** 仅 activate 返回 -EEXIST 或后续 swapon 成功时标记 ON；普通失败只移除失败模块，并使用已有安全遍历宏，未改函数名或设备策略。见 `swap.c:600–655`。副作用是失败会真实保持未开启，而不是继续依赖错误状态；日志和上层错误处理仍需在后续板测核实。

### 2.5 开机回收的读数与下溢

**现象与根因：** usage 是 unsigned long long。usage 增长时 `prev - current` 下溢成大数，错误地认为回收进展很大；初始读取失败用 ARM32 的 ULONG_MAX 伪造64位读数，且 maxtry 非正值不能靠 `!try` 正确限制。

**参考做法：** 把哨兵改为 ULLONG_MAX，并增加 usage 不下降时的停止条件。

**本次修改：** 不造哨兵：初始 usage 无法取得或 maxtry<=0 直接跳过；循环每次先判断 `try<=0 || current>=prev`，才允许执行无符号减法。见 `swap.c:520–593`。保留原 usage 来源、阈值及回收策略。风险是读数不可用时少一次启动回收，但比无依据的重复回收更可控；不把吞掉读取错误当容错成功。

### 2.6 swap 占比的截断与除零

原来在强转 float 前做整数除法，未达100%的比例截断为0；总已用 swap 为0时可除零。采用参考的 double 计算，先确认 `free < total`，否则比例置0，避免不一致采样导致分母无符号下溢。见 `zramswap.c:233–245`。保持既有阈值/候选组选择；修复后原本被截断的比例可能改变候选，这是恢复原有比例判断的效果，后续需板上验证。

### 2.7 compact_memory 文本触发

原代码把二进制 int 地址传给 write；该 sysctl 的整数解析需要文本。采用参考做法，一次写入文本 `"1"`，要求返回1；保留原用于扫描的 n。见 `compaction.c:214–227` 与内核 `mm/compaction.c:sysctl_compaction_handler`（[摘录](../evidence/task15/kernel_algorithm_excerpt.txt)）。这会恢复原本请求的 compaction，可能增加实际执行量，但不增加触发场景/频率；本任务不在板上触发。

### 2.8 整数读取转换失败

原来只判断 fscanf==EOF，返回0时仍把未初始化或上一次字段的值交给调用者。参考只修改 int 读取；本次对已有 int、uint、ulong、ulonglong 四个 helper 都要求每个字段转换数为1，否则 EINVAL，输出变量保持原值。usage 路径使用 ulonglong，故不能仅修 int。见 `file-helper.c:147–242`。新测试覆盖首字段非法、前一字段有效而目标字段非法、四种输出不变，并验证有效首字段仍可读取。没有新增格式/范围语法，不声称解决所有 scanf 溢出边界。

### 2.9 vconf 读取失败的未知状态

`swap_activate_act` 和 `high_mem_control` 原先的 status 未初始化，失败后仍参与比较。采用参考的未知值 -1，并在失败分支再次赋值，避免依赖失败 API 是否修改输出；保留原日志级别及后续动作。见 `lowmem-controller.c:286–306,530–550`。未知值不冒充 NORMAL；仍由已有路径处理，不新增政策。

### 2.10 参考提交中未纳入的修改

|参考改动|本次决定与理由|
|---|---|
|配置 true/false 同义词|不纳入。已有 yes/no、on/off 等解析满足现有 RPi 配置；扩展输入语法不属于本轮回收失败修复，需单独配置兼容需求|
|notifier 退出时安全释放|暂不纳入。属于退出生命周期的独立问题，与本轮实际激活/回收路径无直接依赖；并非否认原代码潜在问题，另行审核|
|watchdog 计数文件失败时继续恢复、删除不完整计数、FailOther 策略|暂不纳入。会改变系统恢复/重启动作与持久化策略，需要独立故障模型和 PM 审核，不能夹在回收兼容补丁中|
|已初始化 status 的其他回调仅调日志级别/补日志|不纳入。不是上述未初始化根因所需修复，保留现有日志政策|
|新增 cgroup_force_reclaim、swap_zram_use_current_algorithm 名字|不采用新生产接口。分别在现有调用函数内实现，保持调用方式|
|保留已有非零 disksize、已激活设备提前 -EEXIST|原 tizen 已有，保持而非宣称本次新增|

完整参考 diff 及行号：[任务14补丁](../evidence/task14/target_patch.txt)、[参考源码摘录](../evidence/task14/resourced_source_excerpt.txt)。以上采用、修改、舍弃均是本轮实现取舍，不代表 He Fangyu 原提交不适用于其原目标环境。

## 3. 检查与构建机制

`git diff --check origin/tizen` 通过。三组新增 cmocka 测试经既有 `ADD_TESTS` 接入 CMake `do-test ALL`，spec 已设置 RD_TESTS_PATH；不改 spec、不禁用原测试、不推到板上。测试只使用包装的文件操作和构建目录内临时普通文件，不访问真实 cgroup/sysfs。原有返回 SKIP_TEST 的用例须与本次实际执行测试分开统计，不能把 skipped 称为 passed。

源码/调用证据：[source_excerpt.txt](../evidence/task15/source_excerpt.txt)。静态检查：[source_diff_check.txt](../evidence/task15/source_diff_check.txt)、[script_static_check.txt](../evidence/task15/script_static_check.txt)。 提交署名、参考标注、干净树及脚本检查汇总见 [static_review.json](../evidence/task15/static_review.json)。`bash -n` 通过；本机没有 shellcheck，未安装。

脚本 [run_task15_build.sh](../scripts/run_task15_build.sh) 直接从任务12模板改为单包；完整差异见 [runner_vs_task12.diff.txt](../evidence/task15/runner_vs_task12.diff.txt)。差异仅为任务号/目录、GBS-ROOT、源路径、固定 SHA/分支、单阶段数组/调度/状态及 tail 输出；另显式增加 `--define 'jobs 10'`，原因见下段。认证、锁、配置哈希核对、独立进程组、stdin=/dev/null、time -v、实时日志、五分钟残留观察、凭据停止、外部写入观察和封存机制保持不变。沿用用户终端 umask；不更改系统工具/配置。

完整构建命令（由脚本在 ext/resourced 中执行）：

```sh
HOME=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home GIT_CONFIG_NOSYSTEM=1 GBP_CONF_FILES=/home/linhao/Toolchain/development/linux_kernel_optimization/temp/gbs-home/.gbp.conf /usr/bin/time -v /usr/bin/gbs -c /home/linhao/Toolchain/development/linux_kernel_optimization/config/gbs_llvm.conf build -P tizen_unified_standard -A armv7l -B /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task15/GBS-ROOT-RESOURCED --threads 1 --define '_smp_mflags -j10' --define 'jobs 10' --commit 94d346c306233803661e8eab8557596549d82be4
```

独立构建根初始为空，不复用任务9/12。本包 spec 第188行使用 `make %{?jobs:-j%jobs}`；depanneur 第2050–2066行默认 jobs 为2倍CPU数，既有构建根宏值为40，外层 `_smp_mflags=-j10` 不覆盖这个宏。因此额外传入 `--define 'jobs 10'` 保证本包 make 上限为10，符合半核规则，不修改 spec。发现时前台仍在认证、supervisor未生成，已更新同一路径脚本；认证后worker重新读取更新后的脚本，不重启原启动器。构建后仍须以实际展开日志核实。见 [宏依据](../evidence/task15/jobs_macro_source.txt)、[更新时状态及脚本哈希](../evidence/task15/jobs_macro_correction.json)。脚本不做产物验收。

## 4. 构建与产物结果

**本轮停止在前台认证：等待已达30分钟，未观察到认证完成；构建尚未开始，不是编译失败。**

2026-11-04 22:11:26（+08:00）已在 tmux 3.4 的独立 `lko-task15` 会话启动。前台已到用户认证提示；检查器共记录58轮，终点2026-11-04T22:42:33.735442+08:00，status仍为 preflight=RUNNING、resourced=PENDING。未生成 supervisor PGID、构建日志或 ALL-END；没有新 RPM，单元测试和包文件对比未执行。代理未直接sudo、未输入/记录密码、未发信号、未重跑或清理。

证据：[启动](../evidence/task15/launch.json)、[30分钟等待摘要](../evidence/task15/authentication_wait_summary.json)、[状态原文](../evidence/task15/authentication_status_snapshot.txt)、[保留会话](../evidence/task15/tmux_session_snapshot.txt)。原会话和锁保留，不能重新启动脚本；用户在原窗口完成认证后原脚本可继续，下一轮应从原status及进程组恢复监控。当前补丁只完成静态核对，尚不能称为“本地构建通过”或可部署。

原会话连接命令：

```sh
tmux -S /home/linhao/Toolchain/development/linux_kernel_optimization/temp/task15/tmux.sock attach -t lko-task15
```

构建通过后核对：RPM NVR/大小/SHA-256、CTest 实际执行/跳过结果；与 QB1211696 镜像所含 resourced、resourced-bin、resourced-config、resourced-isu、resourced-watchdog-handler 10.0.0-1 的路径、文件内容与链接/权限变化比较。基线来源固定为任务14镜像 manifest 与任务8 primary.xml；旧包下载校验记录在 [baseline_rpm_downloads.json](../evidence/task15/baseline_rpm_downloads.json)。新增生成的非镜像包单独列出，不与“镜像删除了文件”混为一谈。QB 包源码为 b0bbb7c5，当前 tizen 还包含既有的 dash 兼容和 cgroup 修复两个提交；包内容差异同时受这两个提交、工具链/构建环境及本轮九补丁影响，不能全部归因于本轮补丁。

即使构建和单元测试全部通过，也仅代表开发机构建验证，不能替代两种目标内核上的实际激活、回收及错误路径验证。本轮不部署；待 PM 审核补丁后另行决定 Gerrit 推送与镜像验证。
