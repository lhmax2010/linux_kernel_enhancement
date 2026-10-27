# 任务1：Gerrit 与 sandbox 重叠盘点

初始采样：2026-10-26；任务2更新：2026-10-27（Asia/Shanghai）。内核主线固定为 `tizen@42aeefac58edeb081aff440f0b60be71cbe49755`。任务1盘点只读。任务2已按 PM 指令将 memcontrol 修复拆入本地 lko/base；未向 Gerrit 推送、未联系同事。

## 1. 查询范围、方法与限制

origin 为 `ssh://lhmax2025@review.tizen.org:29418/platform/kernel/linux-rpi`，推导项目名 **platform/kernel/linux-rpi**。`git ls-remote --symref origin` 完整输出含全部分支/refs，见 [gerrit_remote_refs.txt](../evidence/task1/gerrit_remote_refs.txt)；发现 46 条 sandbox。执行：

```bash
export TMPDIR="$WS/temp" GIT_OPTIONAL_LOCKS=0
export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=20'
git -C "$WS/linux-rpi" ls-remote --symref origin
git -C "$WS/linux-rpi" -c pack.threads=4 -c gc.auto=0 fetch   --no-tags --no-write-fetch-head origin   'refs/heads/sandbox/*:refs/remotes/origin/sandbox/*'   refs/heads/tizen:refs/remotes/origin/tizen   refs/heads/upstream:refs/remotes/origin/upstream
```

没有 fetch 新输出通常意味着本地已有同 SHA，并不意味着未执行，见 [sandbox_fetch.txt](../evidence/task1/sandbox_fetch.txt)。比较命令为：

```text
git merge-base --all HEAD refs/remotes/origin/sandbox/<name>
git rev-list --count HEAD..refs/remotes/origin/sandbox/<name>
git rev-list --count refs/remotes/origin/sandbox/<name>..HEAD
git log --format='%H %an <%ae> %aI %s' HEAD..refs/remotes/origin/sandbox/<name>
git diff --numstat <merge-base> refs/remotes/origin/sandbox/<name>
```

许多旧 sandbox 的 merge-base 落在数年前，ahead 上万条中包含旧 stable/RPi/Tizen 背景，不能解释为作者新增上万条工作。按“过大输出本地汇总，只上传摘要”的要求，全量 ahead 元数据留在 `$WS/temp/sandbox_raw/`；每个上传摘要记录其文件名、字节数、SHA-256、完整 ahead/behind 数量、merge-base，以及去背景后的完整领先提交列表（作者、日期、标题）。

辅助去背景集合为**全部非 sandbox 的 origin 远端分支、官方 rpi-6.12.y、本地 v* tag** 的祖先合集，名单见 [sandbox_background_exclusions.txt](../evidence/task1/sandbox_background_exclusions.txt)。它只用来缩短背景，不替代相对 tizen 的 ahead 定义，也没有按 patch-id 消除等价重放；例如 fine_grained_thp 仍剩 733 条。全部 46 个分支共保留 2236 条辅助集合元数据（分支间可重复）。目录统计始终是各分支相对**与 tizen 的 merge-base**的净 diff，包含历史背景；不是把旧版本差异认作该同事独自改动。

## 2. Gerrit 查询：任务1匿名 REST 与任务2认证 SSH

### 2.1 任务1匿名 REST（历史记录）

查询日期窗口按用户当前日期设为 **2026-04-26 至 2026-10-26**（before:2026-10-27），open 不限日期。匿名 HTTPS，无 cookie/认证，查询参数含 CURRENT_REVISION、CURRENT_COMMIT、CURRENT_FILES、DETAILED_ACCOUNTS，每页 n=100；设计为有 `_more_changes` 时继续 S 偏移。实际第一页为空，没有后续页。

| 查询 | 返回 | 能得出的结论 |
| --- | --- | --- |
| `project:platform/kernel/linux-rpi status:open` | HTTP 200，移除 `)]}'` 首行后为 `[]` | 匿名接口本次未暴露 open 变更，不能认定项目没有 open |
| `project:platform/kernel/linux-rpi status:merged after:2026-04-26 before:2026-10-27` | HTTP 200，去前缀后为 `[]` | 无法提供可靠的六个月 merged 变更列表 |
| 项目查询，不限状态/时间 | HTTP 200，`[]` | 排除仅日期过滤造成空结果 |
| `/projects/platform%2Fkernel%2Flinux-rpi` | HTTP 404 | 匿名项目详情不可得 |
| `/projects/?p=platform%2Fkernel%2Flinux-rpi` | HTTP 200，`{}` | 项目未在匿名列表显示 |
| 查询主线已知 Change-Id `I4e3cd32cf76abb9d9f147680cddbd48aadbe9207` | HTTP 200，`[]` | 即使已知已提交对象，也不能从匿名索引查回 |
| 全站 `status:open&n=1` | HTTP 200，`[]` | 同样为空；原因未确定 |
| 全站 `status:merged&n=1` | 读取超时 | 此次接口探测失败 |
| 无 `/gerrit` 前缀 `/changes/` | HTTP 404 | 不是可用替代入口 |

**不能把空响应伪装成“无人涉及”。** 推测：匿名可见性或索引/服务行为导致不可用；现有证据不足以确定具体原因。Git/SSH 可读与 REST 匿名可读是两个不同范围。本任务不改用认证 REST，也不将 Git 提交作者日期冒充 Gerrit merged 时间。

原始响应与完整 URL：[gerrit_rest_requests.txt](../evidence/task1/gerrit_rest_requests.txt)、[gerrit_open_empty.txt](../evidence/task1/gerrit_open_empty.txt)、[gerrit_merged_empty.txt](../evidence/task1/gerrit_merged_empty.txt)、[gerrit_rest_sanity.txt](../evidence/task1/gerrit_rest_sanity.txt)、[gerrit_rest_followup.txt](../evidence/task1/gerrit_rest_followup.txt)。浏览器检索入口亦不可访问，未据此补造结果。

因此“其中与内存、性能、构建有关的 open/merged 变更”无可列出的匿名结果；下面只列可验证的 Git 分支与 commit，不声称其 Gerrit 审核状态。

### 2.2 任务2 SSH 查询（2026-10-27）

按 PM 指定的 SSH 命令查询，仅增加 StrictHostKeyChecking=yes 和 ConnectTimeout=20，避免修改 known_hosts 或无限等待；BatchMode=yes，不交互输入凭据。两条命令均 exit=0：open **0**，`status:merged -age:6mon` **17**。stats.moreChanges=false，未达到500条，不需要 --start 翻页。原始 JSONL 留在 `$WS/temp/task2_gerrit_<open|merged_6mon>_0.jsonl`。

`-age:6mon` 是 Gerrit 服务端按更新年龄过滤；报告“更新时间”来自 lastUpdated，不冒称确切合入时间。此 SSH 可见性结果替代任务1“无法获得列表”的当前挂账，但任务1原始匿名失败证据仍保留。仅在当前账号可见范围内，open=0；不扩展为所有私人工作都不存在。

[完整命令/退出码/分页统计](../evidence/task2/gerrit_ssh_queries.txt)；[全部17条摘要](../evidence/task2/gerrit_ssh_summary.txt)。以下 **12 条**与内存、性能/观测或构建直接相关；排除完整 Hailo 驱动移植1条和 USB cp210x 驱动4条，不把所有驱动功能更新都算性能优化。

| number | branch | owner | subject | 更新时间（Asia/Shanghai） | 相关内容 |
| --- | --- | --- | --- | --- | --- |
| 356569 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | configs: packaging: modularize defconfig with RT and LSM fragments | 2026-10-21T10:19:44+08:00 | 统一普通/RT及LSM片段，影响最终配置与构建基线。 |
| 352864 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | script: build: support non-sudo image creation and mounting | 2026-09-03T12:29:58+08:00 | 构建脚本的无sudo镜像创建/挂载支持；不改变GBS的sudo要求。 |
| 351450 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | ARM/ARM64: configs: tizen_bcm2711: Enable F2FS compression configs | 2026-08-26T19:21:31+08:00 | 启用F2FS压缩，涉及压缩存储/页缓存。 |
| 349146 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | perf build: Add make check-headers target | 2026-08-20T14:20:43+08:00 | perf构建新增头文件检查目标。 |
| 349148 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | packaging: Replace #!/bin/bash with #!/bin/sh in devel package for dash compat | 2026-08-10T21:32:50+08:00 | devel包脚本改用/bin/sh，适配dash。 |
| 349147 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | packaging: Remove bash shebang scripts from perf package for dash compat | 2026-08-06T09:32:27+08:00 | 从perf包删除bash shebang脚本，修复打包兼容。 |
| 347136 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | drm/vc4,v3d: Fix wrong lock protecting filelist in gem_info debugfs | 2026-07-25T17:00:13+08:00 | vc4/v3d gem_info调试接口锁修正，关系图形内存观测正确性。 |
| 334935 | tizen | Unsung Lee &lt;unsung.lee@samsung.com&gt; | cputime: Export symbol of thread_group_cputime_adjusted for the kernel module | 2026-07-14T16:26:52+08:00 | 导出线程组CPU时间函数给模块，支持性能统计。 |
| 343424 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | script: build: support LLVM/CLANG build including tizen modules | 2026-05-28T09:29:34+08:00 | build-rpi.sh支持LLVM/Clang及Tizen模块。 |
| 343680 | tizen | Hoegeun Kwon &lt;hoegeun.kwon@samsung.com&gt; | script: build: add clean step before building tizen modules | 2026-05-18T12:46:21+08:00 | 构建Tizen模块前清理旧产物，避免陈旧构建结果。 |
| 343176 | tizen | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | ARM: configs: tizen_bcm2711: Enable MG-LRU configuration | 2026-05-13T09:00:08+08:00 | 默认启用MGLRU；已经合入主线，不是待实施的新开关。 |
| 343423 | tizen | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | ARM: 9441/1: rust: Enable Rust support for ARMv7 | 2026-05-12T19:36:26+08:00 | 回移ARMv7 Rust支持，改变工具链能力前提。 |

SSH 返回的17条中没有发现本矩阵所列 zram stream/并行解压、MGLRU-FG、免引用计数读取、kallsyms/modpost并行化、AutoFDO 的新增变更；已有sandbox仍按下文证据和PM划界处理。

## 3. 候选方向重叠矩阵

用语边界：“已有人在做”表示存在实质相关分支/提交证据，**不保证作者仍在推进**；“无人涉及”只表示当前可见分支差异及提交检索中未发现，不覆盖不可见 Gerrit、个人未推送分支。旧版本回移也标明年代，不能作为独占 6.12 方向的依据。

| 候选方向 | 标注 | 证据与边界 |
| --- | --- | --- |
| MGLRU 启用与调参 | **已合入主线；调参尚无本次新证据** | SSH merged #343176（c0b66bcd342c）确认默认启用；旧 dwlee08 两条5.4回移分支仍属历史工作。 |
| MGLRU-FG：访问次数驱动的代龄提升 | **无人涉及**（本次可见范围） | PM明确 cache-ext 没有实现按访问次数提升MGLRU代龄，标为“不重叠，不再跟踪”；普通MGLRU tiers不等于该候选。SSH相关变更中未出现该实现。 |
| zram 读写压缩流拆分 | **无人涉及**（可见范围未发现） | jaehoon80/zram 仅改 ARM defconfig 与启动脚本，silent-reclaim-fix 改 defconfig 与 memcontrol-v1.c；未改 zcomp stream 实现。其他去背景元数据检索未命中该机制。 |
| zram 并行解压 | **相关但不重叠** | jaehoon80/lz4 的 7459b2911b52 是 ARMv7 fast decode loop；旧 EROFS 分支有 per-CPU 解压线程，但对象不是 zram 并行解压。未发现 zram 并行队列实现。 |
| zram 重压缩全局缓冲 | **无人涉及**（可见范围未发现） | zram sandbox 未改驱动分配/缓冲路径；检索 recompress/global buffer 未发现对应提交。 |
| zram 算法、二次压缩配置 | **已有相关方案；本项目评估** | 85fcc6edce0b选择zstd、multi-comp、actime和字典脚本，同时**删除CONFIG_DEBUG_INFO_BTF=y**；a9cc39b8dd1d由另一条工作线负责，本项目仅拆入memcontrol修复，zram配置单独评估。证据：[配置diff](../evidence/task2/zram_branch_config_diff.txt)。 |
| zram 写回 | **无人涉及**（可见范围未发现） | 当前 D 未启用 ZRAM_WRITEBACK；85fcc6edce0b 启用 idle 重压缩不等于写回，未添加 backing_dev/writeback 策略。 |
| 冷热分层压缩 / CRAM 类软件实现 | **相关但不重叠** | zram字典/二次压缩配置可作相邻基础，但未发现完整冷热分类及跨层迁移实现；cache-ext按PM决定不重叠、不再跟踪。 |
| 页缓存读取免引用计数 | **无人涉及**（本次可见范围） | PM确认 cache-ext 没有实现读取时免引用计数，仅移植BPF页缓存策略框架；不重叠，不再跟踪。SSH相关变更中未出现该实现。 |
| Kbuild 并行化（kallsyms、modpost） | **相关但不重叠** | 主线 91730e1655f5 将 make jobs 传给 pahole；devel 的 c042b147b853 仅 linker 调试，旧 use_lto 改构建流程。未发现 kallsyms/modpost 并行化方案。 |
| 编译器层 Clang/GCC、优化级别、LTO、AutoFDO | **部分已有历史工作** | SSH #343424确认build-rpi.sh的LLVM支持；dkson95/clang、sebuns2/use_lto、pgo_applied_kernel仍为相关历史。**lhmax2025/mlgo为用户本人的编译器MLGO分支，与本项目不重叠**；未发现明确AutoFDO新变更。 |
| 内核配置裁剪（debug 等） | **已有相关改动** | 主线已裁掉部分无用驱动/NFSD；85fcc6edce0b还删除DEBUG_INFO_BTF，不能当纯zram开关直接照搬。SSH #356569统一配置片段，#351450加入F2FS压缩；未查到完整debug裁剪试验。 |
| 调度参数调优 | **已有人在做** | jaehoon80/eevdf：5 条去背景提交；f08ff9bbd937 cache affinity、b516ce5fa5a5 wakeup granularity、ab0bba206cfd 最小粒度/rb-tree 等。是旧主线上的 EEVDF backport/修正，不能直接套到当前 6.12。 |
| sched_ext | **相关但不重叠** | 当前 Kconfig 有 SCHED_CLASS_EXT 但未启用；EEVDF 分支不是 sched_ext；cache-ext 是页缓存扩展，不是调度扩展。可见 sandbox 中未发现专用 sched_ext 实验。 |
| 机器学习页面置换/回收（本项目不做） | **不重叠，不再跟踪 cache-ext** | PM确认 mmajewski2/cache-ext 移植的是BPF页缓存策略框架，未实现MGLRU按次数升代龄、未实现读时免引用计数；最后提交2026-07-29。MLGO属于用户本人的编译器分支，与本项目不重叠。 |
| vendor force_reclaim、zram 算法回退 | **memcontrol已纳入base；zram另评估** | sandbox位于用户账号下，作者He Fangyu，由另一条工作线负责。本项目将a9cc39b8dd1d的mm/memcontrol-v1.c部分拆为lko/base@563c53c427bf；两个defconfig未带入，zram配置由本项目另行评估。 |

关键原文/补丁：[focused_sandbox_details.txt](../evidence/task1/focused_sandbox_details.txt)、[sandbox_silent_reclaim_patch.txt](../evidence/task1/sandbox_silent_reclaim_patch.txt)、[cache_ext_changes.txt](../evidence/task1/cache_ext_changes.txt)、[cache_ext_source_excerpt.txt](../evidence/task1/cache_ext_source_excerpt.txt)、[overlap_search.txt](../evidence/task1/overlap_search.txt)。每条分支的作者、日期和提交完整清单链接见下一节。没有从提交标题宣称实测收益。

## 4. 全部 sandbox 分支逐项

每节先列 tizen 比较的 merge-base 和完整 ahead/behind；再给去背景提交摘要与目录统计。目录数为净 diff 的文件数，`+/-` 为文本新增/删除行，二进制项不累计行数。完整细分目录统计和完整去背景提交均链接至证据；正文只摘最多六条，避免把旧内核历史铺满报告。


### 1. `sandbox/aadaszkiewi/dm-user`

添加 dm-user 与 dm-snapshot，面向用户态块设备/快照；与 zram 流或回收策略不直接重叠。

tip `8d376edf0af576ebda586b313d103f9042b1e6a3`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **4675**、落后 **112095**；去背景后 **2** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2147/+177113/-19169；`arch` 945/+59779/-2262；`net` 237/+7555/-1373；`fs` 235/+4524/-2389；`include` 219/+4468/-651。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__aadaszkiewi__dm-user_summary.txt)；[全部目录统计](../evidence/task1/sandbox__aadaszkiewi__dm-user_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `8d376edf0af5` | Antoni Adaszkiewicz &lt;a.adaszkiewi@samsung.com&gt; | 2024-08-08T11:53:43+02:00 | add dm user |
| `40c712e8c356` | Jacek Kryszyn &lt;j.kryszyn@samsung.com&gt; | 2024-07-22T09:13:52+02:00 | add dm snapshot |

### 2. `sandbox/dkson95/clang`

旧版本 spec 接入 LLVM/Clang 编译；当前主线另有 LLVM 支持，属于编译器方向重叠历史。

tip `f2c3d799708c87ccbf50e912684db822222987cf`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **13796**、落后 **112095**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4372/+232576/-42156；`arch` 1689/+71749/-9010；`fs` 624/+23505/-14319；`net` 508/+15950/-9328；`tools` 497/+8844/-4460。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__dkson95__clang_summary.txt)；[全部目录统计](../evidence/task1/sandbox__dkson95__clang_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `f2c3d799708c` | Dongkyun Son &lt;dongkyun.s@samsung.com&gt; | 2025-03-17T19:58:17+09:00 | packaging: support LLVM/Clang build |

### 3. `sandbox/dwlee08/erofs-backports-v5.4`

向 5.4 回移 EROFS 修复、压缩和解压功能，涉及文件系统缓存与 I/O；不是 zram 驱动。

tip `eb2786e233dc779cb0920f0ffd94f6be1951a5b1`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **8140**、落后 **455938**；去背景后 **269** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317408/-19606；`arch` 1048/+43298/-4241；`net` 356/+8885/-2986；`fs` 344/+10049/-6510；`include` 275/+5586/-2052。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__dwlee08__erofs-backports-v5.4_summary.txt)；[全部目录统计](../evidence/task1/sandbox__dwlee08__erofs-backports-v5.4_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `eb2786e233dc` | Gao Xiang &lt;hsiangkao@linux.alibaba.com&gt; | 2023-11-29T02:04:31+08:00 | erofs: fix memory leak on short-lived bounced pages |
| `ce04c2dd00ee` | Jingbo Xu &lt;jefflexu@linux.alibaba.com&gt; | 2023-09-15T16:27:28+08:00 | erofs: allow empty device tags in flatdev mode |
| `ba272f34c63f` | Gao Xiang &lt;hsiangkao@linux.alibaba.com&gt; | 2023-09-07T13:05:42+08:00 | erofs: fix memory leak of LZMA global compressed deduplication |
| `2ef14841ceee` | Jingbo Xu &lt;jefflexu@linux.alibaba.com&gt; | 2023-08-22T19:05:30+08:00 | erofs: release ztailpacking pclusters properly |
| `89e3cf015712` | sunshijie &lt;sunshijie@xiaomi.com&gt; | 2023-08-21T23:21:16+08:00 | erofs: don't warn dedupe and fragments features anymore |
| `098b274a1558` | Gao Xiang &lt;hsiangkao@linux.alibaba.com&gt; | 2023-08-17T16:28:11+08:00 | erofs: get rid of fe->backmost for cache decompression |

### 4. `sandbox/dwlee08/v5.4-erofs-deflate`

5.4 EROFS deflate 支持与构建脚本调整，属于压缩文件系统工作。

tip `46f0811bf6a4b9ab2eab0a5c11c0b3c674003efa`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7890**、落后 **455938**；去背景后 **19** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317408/-19606；`arch` 1048/+43298/-4241；`net` 356/+8885/-2986；`fs` 336/+6101/-3176；`include` 276/+5623/-2052。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__dwlee08__v5.4-erofs-deflate_summary.txt)；[全部目录统计](../evidence/task1/sandbox__dwlee08__v5.4-erofs-deflate_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `46f0811bf6a4` | Dongwoo Lee &lt;dwoo08.lee@samsung.com&gt; | 2024-10-16T18:39:14+09:00 | fix for script |
| `4c9df0c4f37e` | Dongwoo Lee &lt;dwoo08.lee@samsung.com&gt; | 2024-10-16T18:38:58+09:00 | fixup |
| `f23b58c119ea` | Gao Xiang &lt;hsiangkao@linux.alibaba.com&gt; | 2023-08-10T23:48:59+08:00 | erofs: DEFLATE compression support |
| `687e4bc98728` | Gao Xiang &lt;hsiangkao@linux.alibaba.com&gt; | 2021-10-11T05:31:45+08:00 | erofs: lzma compression support |
| `18f6bc472f87` | Gao Xiang &lt;hsiangkao@linux.alibaba.com&gt; | 2021-10-11T05:31:44+08:00 | erofs: rename some generic methods in decompressor |
| `756f08991073` | Gao Xiang &lt;hsiangkao@redhat.com&gt; | 2021-03-29T18:00:12+08:00 | erofs: add on-disk compression configurations |

### 5. `sandbox/dwlee08/v5.4-mg-lru`

向 5.4 回移 MGLRU 及修复，涉及代际回收/文件与匿名页统计；不是当前 6.12 新算法。

tip `8c29e11f893001bec76ae063c51b0fa594c6fc3f`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7927**、落后 **455938**；去背景后 **56** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317408/-19606；`arch` 1051/+43308/-4247；`net` 356/+8885/-2986；`fs` 326/+4995/-2950；`include` 289/+6406/-2142。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__dwlee08__v5.4-mg-lru_summary.txt)；[全部目录统计](../evidence/task1/sandbox__dwlee08__v5.4-mg-lru_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `8c29e11f8930` | Kalesh Singh &lt;kaleshsingh@google.com&gt; | 2023-08-01T19:56:04-07:00 | FROMGIT: BACKPORT: Multi-gen LRU: Fix can_swap in lru_gen_look_around() |
| `081bda423e3a` | Kalesh Singh &lt;kaleshsingh@google.com&gt; | 2023-08-01T19:56:03-07:00 | FROMGIT: BACKPORT: Multi-gen LRU: Avoid race in inc_min_seq() |
| `8ad15aa42c03` | Kalesh Singh &lt;kaleshsingh@google.com&gt; | 2023-08-01T19:56:02-07:00 | FROMGIT: BACKPORT: Multi-gen LRU: Fix per-zone reclaim |
| `2a388b6a4286` | Yu Zhao &lt;yuzhao@google.com&gt; | 2022-11-15T18:38:07-07:00 | BACKPORT: mm: multi-gen LRU: retry pages written back while isolated |
| `8a1ab5446d49` | Kalesh Singh &lt;kaleshsingh@google.com&gt; | 2023-05-23T13:59:21-07:00 | BACKPORT: FROMGIT: Multi-gen LRU: fix workingset accounting |
| `4fa269241ca5` | Dongwoo Lee &lt;dwoo08.lee@samsung.com&gt; | 2024-04-30T12:11:01+09:00 | changed |

### 6. `sandbox/dwlee08/v5.4-tizen-mg-lru`

Tizen 5.4 MGLRU 回移系列，补 pgtable 接口与 Android 修正；历史基础相关。

tip `6953fba32d63c8d105694ec7174ae28fcee711d7`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7913**、落后 **455938**；去背景后 **42** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317408/-19606；`arch` 1051/+43308/-4247；`net` 356/+8885/-2986；`fs` 326/+4989/-2944；`include` 287/+6393/-2133。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__dwlee08__v5.4-tizen-mg-lru_summary.txt)；[全部目录统计](../evidence/task1/sandbox__dwlee08__v5.4-tizen-mg-lru_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `6953fba32d63` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2024-01-18T15:41:31+01:00 | pgtable: add pmd_index() fallback |
| `dc0d3da2f9ed` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2023-12-06T13:25:55+01:00 | tizen: enable MG-LRU in tizen_bcm2711_defconfig |
| `268c1f46b2aa` | Kalesh Singh &lt;kaleshsingh@google.com&gt; | 2023-02-14T14:17:57-08:00 | ANDROID: MGLRU: Avoid reactivation of anon pages on swap full |
| `3f3e1a95461f` | Kalesh Singh &lt;kaleshsingh@google.com&gt; | 2023-04-13T14:43:26-07:00 | BACKPORT: mm: Multi-gen LRU: remove wait_event_killable() |
| `da7988723345` | Sebastian Andrzej Siewior &lt;bigeasy@linutronix.de&gt; | 2022-10-26T15:48:30+02:00 | BACKPORT: mm: multi-gen LRU: move lru_gen_add_mm() out of IRQ-off region |
| `18a7b6a8d4ac` | Yu Zhao &lt;yuzhao@google.com&gt; | 2022-09-18T02:00:11-06:00 | BACKPORT: mm: multi-gen LRU: design doc |

### 7. `sandbox/hoegeun/next-btf`

BTF/DWARF4、bpftool 与开发子包试验；影响构建耗时、体积和 BPF 开发能力。

tip `46287f81b53a8606434124649fcf9d101feac0fc`；merge-base `11d5d0d30abe08fddc8a0e856d0e333ca6e22114`；领先 **38**、落后 **7600**；去背景后 **4** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 18/+397/-27；`rpi` 12/+546/-0；`arch` 6/+2026/-0；`packaging` 3/+419/-0；`security` 3/+259/-116。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__hoegeun__next-btf_summary.txt)；[全部目录统计](../evidence/task1/sandbox__hoegeun__next-btf_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `46287f81b53a` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17T10:23:00+01:00 | packaging: Introduce BTF subpackage for eBPF development |
| `92ec5d9e60df` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-14T13:30:42+01:00 | kbuild: Remove unsupported dd option “status=none” |
| `1aeaa3a05835` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17T09:31:27+01:00 | ARM/ARM64: configs: tizen: Enable BTF and DWARF4 debug options |
| `c99dd06e3922` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17T10:22:34+01:00 | packaging: Add dwarves BuildRequires |

### 8. `sandbox/jaehoon80/devel`

在链接脚本增加调试输出，目的是构建排错；没有实现并行 kallsyms/modpost。

tip `c042b147b853219cf8a7f7db5bb44e0d94b7d193`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **13813**、落后 **112095**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4372/+232576/-42156；`arch` 1689/+71775/-9011；`fs` 624/+23505/-14319；`net` 508/+15952/-9328；`tools` 497/+8844/-4460。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jaehoon80__devel_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jaehoon80__devel_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `c042b147b853` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2025-09-16T10:16:22+09:00 | Add debug option for checking message |

### 9. `sandbox/jaehoon80/eevdf`

旧主线 EEVDF 移植及最小粒度、唤醒抢占、cache buddy 调整，明确与调度优化相关。

tip `f08ff9bbd937038d7e293862debc4774dd803bca`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7854**、落后 **455938**；去背景后 **5** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317390/-19605；`arch` 1048/+43290/-4241；`net` 356/+8885/-2986；`fs` 325/+4983/-2942；`include` 273/+4604/-2052。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jaehoon80__eevdf_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jaehoon80__eevdf_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `f08ff9bbd937` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-14T05:18:26+09:00 | sched/fair: Add cache affinity buddy heuristics to EEVDF scheduler |
| `b516ce5fa5a5` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-13T22:01:11+09:00 | sched/fair: Add wakeup granularity guard to EEVDF preemption |
| `ab0bba206cfd` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-10T20:32:39+09:00 | sched/fair: Optimize EEVDF pick with augmented rb-tree and min granularity |
| `d9a30342a6e3` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-10T05:26:34+09:00 | sched/fair: Fix multiple bugs in EEVDF scheduler implementation |
| `689dfcf30701` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-08T22:50:54+09:00 | sched/fair: Implement EEVDF (Earliest Eligible Virtual Deadline First) scheduler |

### 10. `sandbox/jaehoon80/lz4`

LZ4 升级 1.10.0、修正 HC 内部结构和 ARMv7 fast decode loop；是压缩库性能方向。

tip `7459b2911b5224bba424b8fc47905437240f8fe3`；merge-base `d2e59dfd2830321c006d84fa0864f35cfa441504`；领先 **3**、落后 **6**；去背景后 **3** 条。

净改动目录（前 5，文件数/+行/-行）：`lib` 5/+2456/-1459；`include` 1/+45/-12。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jaehoon80__lz4_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jaehoon80__lz4_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `7459b2911b52` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-08-20T13:59:06+09:00 | lib/lz4: Allow the fast decode loop on armv7 |
| `7b64cf4f1065` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-08-20T13:39:58+09:00 | lib: lz4: Sync LZ4HC_CCtx_internal with lz4 v1.10.0 |
| `1051099cb8da` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-08-20T11:46:33+09:00 | lib: lz4: Update lz4 version to v1.10.0 from v1.8.3 |

### 11. `sandbox/jaehoon80/rebase`

分支 tip 已是当前 tizen 的祖先，当前相对主线无领先提交；不可当作未合并的新方案。

tip `b9a6e80323a03e0a0670425f0b889f333aec51a8`；merge-base `b9a6e80323a03e0a0670425f0b889f333aec51a8`；领先 **0**、落后 **14**；去背景后 **0** 条。

净改动目录（前 5，文件数/+行/-行）：无。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jaehoon80__rebase_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jaehoon80__rebase_dirs.txt)。

去背景后无提交；完整 ahead 的计数仍见上。

### 12. `sandbox/jaehoon80/zram`

仅一条配置/脚本提交，启用 zstd 字典、二次压缩和访问时间跟踪；驱动本身未改。该提交还删除 CONFIG_DEBUG_INFO_BTF=y（原始行528，diff见 evidence/task2/zram_branch_config_diff.txt），后续方案需单独评估其BPF/BTF影响。

tip `85fcc6edce0b0df05e5d630027f37634bde078bb`；merge-base `b9a6e80323a03e0a0670425f0b889f333aec51a8`；领先 **1**、落后 **14**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`scripts` 2/+241/-0；`arch` 1/+5/-1。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jaehoon80__zram_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jaehoon80__zram_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `85fcc6edce0b` | Jaehoon Chung &lt;jh80.chung@samsung.com&gt; | 2026-04-29T23:22:40+09:00 | zram: Enable zstd dictionary compression support for BCM2711 |

### 13. `sandbox/jhoon20kim/iotrace`

I/O trace 环形缓冲和锁优化系列，偏观测工具；与性能测量相邻。

tip `734af7d599d2d0eee0fdb6917763393dd4f6b0f6`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7769**、落后 **455938**；去背景后 **14** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2858/+316891/-19595；`arch` 1048/+43270/-4241；`net` 356/+8885/-2986；`fs` 326/+5024/-2942；`include` 274/+4604/-2051。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jhoon20kim__iotrace_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jhoon20kim__iotrace_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `734af7d599d2` | Junghoon Kim &lt;jhoon20.kim@samsung.com&gt; | 2020-07-22T16:57:52+09:00 | IOtrace: Change the locking mechanism of trace buffer |
| `97ff8674f3bc` | Junghoon Kim &lt;jhoon20.kim@samsung.com&gt; | 2020-07-22T14:31:20+09:00 | iotrace: Change the log_ws memset position |
| `ae9aaab8a1d9` | Junghoon Kim &lt;jhoon20.kim@samsung.com&gt; | 2020-07-22T14:30:41+09:00 | iotrace: Fix the read bytes handling |
| `1a364f11e6cf` | Junghoon Kim &lt;jhoon20.kim@samsung.com&gt; | 2020-07-22T14:29:41+09:00 | IOtrace: Add the filesystem journal info to the trace log |
| `4cd0fb96d651` | Junghoon Kim &lt;jhoon20.kim@samsung.com&gt; | 2020-07-22T14:28:10+09:00 | IOtrace: Add the fsync tag to the filesystem journal |
| `a1861c19cc02` | Junghoon Kim &lt;jhoon20.kim@samsung.com&gt; | 2020-07-22T11:18:26+09:00 | IOtrace: Add the fsync information to the trace log |

### 14. `sandbox/jkryszyn/dm-snapshot`

添加 device-mapper snapshot，涉及块设备快照，不是内存页面替换。

tip `6bc8f6fd11a8afa5a7f64b418e397c283040cd3f`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **4677**、落后 **112095**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2146/+175812/-19169；`arch` 945/+59782/-2262；`net` 237/+7555/-1373；`fs` 235/+4524/-2389；`include` 218/+4400/-651。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__jkryszyn__dm-snapshot_summary.txt)；[全部目录统计](../evidence/task1/sandbox__jkryszyn__dm-snapshot_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `6bc8f6fd11a8` | Jacek Kryszyn &lt;j.kryszyn@samsung.com&gt; | 2024-08-28T21:37:00+02:00 | Add dm-snapshot |

### 15. `sandbox/kfrolov1/criu`

spec 追加 CHECKPOINT_RESTORE、MEM_SOFT_DIRTY、USERFAULTFD 等 CRIU 选项并调整 perf/bpftool 构建位置；同时禁用 SMACK/NETLABEL，不能作为单纯性能补丁采用。补丁见 [criu_packaging_patch.txt](../evidence/task1/criu_packaging_patch.txt)。

tip `6cacd00e9713b1982131d00483ba2d35ac144555`；merge-base `11d5d0d30abe08fddc8a0e856d0e333ca6e22114`；领先 **115**、落后 **7600**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 57/+1289/-515；`rpi` 12/+550/-0；`net` 10/+3498/-194；`arch` 9/+2255/-24；`include` 9/+676/-1。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__kfrolov1__criu_summary.txt)；[全部目录统计](../evidence/task1/sandbox__kfrolov1__criu_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `6cacd00e9713` | Kirill Frolov &lt;k.frolov+1@samsung.com&gt; | 2026-03-03T23:31:23+03:00 | fix |

### 16. `sandbox/klewandowski/rpi5`

为 32 位用户空间提供 64 位内核和模块的 baselibs 打包，属于平台/ABI 支持。

tip `fb3cd7334c19cb8ded5f2f553f3109863859b8ad`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **4634**、落后 **112095**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2136/+174659/-19130；`arch` 944/+59715/-2262；`net` 237/+7519/-1337；`fs` 235/+4522/-2387；`include` 215/+4201/-600。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__klewandowski__rpi5_summary.txt)；[全部目录统计](../evidence/task1/sandbox__klewandowski__rpi5_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `fb3cd7334c19` | Karol Lewandowski &lt;k.lewandowsk@samsung.com&gt; | 2024-03-12T00:27:19+01:00 | tizen: packaging: Add baselibs.conf to provide 64-bit kernel & modules for 32-bit userspace |

### 17. `sandbox/lhmax2025/mlgo`

PM已确认：这是用户本人的编译器 MLGO 分支，与本项目不重叠。它通过 packaging 为 clang 内核构建启用 MLGO，不是页面回收 ML。

tip `0eb2748f5d698124d24a6368936992af889ac9de`；merge-base `8cdc66794c4281f47cc90efe8b218add97303274`；领先 **1**、落后 **10**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`packaging` 1/+37/-8。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__lhmax2025__mlgo_summary.txt)；[全部目录统计](../evidence/task1/sandbox__lhmax2025__mlgo_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `0eb2748f5d69` | lhmax2025 &lt;hao.lin@samsung.com&gt; | 2026-07-03T11:32:38+08:00 | packaging: enable MLGO for clang kernel builds |

### 18. `sandbox/lhmax2025/silent-reclaim-fix`

PM已确认：分支在用户账号下，作者He Fangyu，由另一条工作线负责。本项目已将其memcontrol修复拆入 lko/base@563c53c427bf；zram defconfig部分未带入，由本项目另行评估。原sandbox同时启用LZ4/ZSTD后端并保留lzo-rle默认。

tip `a9cc39b8dd1deaa8c9cb5ae45cb815526f3dd87a`；merge-base `42aeefac58edeb081aff440f0b60be71cbe49755`；领先 **1**、落后 **0**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`arch` 2/+6/-0；`mm` 1/+22/-7。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__lhmax2025__silent-reclaim-fix_summary.txt)；[全部目录统计](../evidence/task1/sandbox__lhmax2025__silent-reclaim-fix_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `a9cc39b8dd1d` | He Fangyu &lt;fangyu.he@samsung.com&gt; | 2026-10-19T10:13:06+08:00 | mm: restore vendor reclaim semantics and enable zram backends |

### 19. `sandbox/lstelmach/arm-kexec-file`

ARM kexec_file/zImage/initrd/dtb 加载支持，涉及启动和重启路径。

tip `1669e94ae93dbc4ab275e3b40c78f93a761a11ff`；merge-base `84df9525b0c27f3ebc2ebb1864fa62a97fdedb7d`；领先 **14064**、落后 **545612**；去背景后 **36** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4302/+333411/-34045；`arch` 1802/+51089/-9579；`net` 557/+13845/-6170；`fs` 452/+11237/-5549；`include` 424/+5030/-1264。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__lstelmach__arm-kexec-file_summary.txt)；[全部目录统计](../evidence/task1/sandbox__lstelmach__arm-kexec-file_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `1669e94ae93d` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-03-26T19:42:24+01:00 | arm: kexec_file: load zImage, initrd and dtb |
| `edb1162a3bd1` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-03-24T17:56:26+01:00 | arm: enable KEXEC_FILE config |
| `416a511c168d` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-04-30T00:14:43+02:00 | arm: decompressor: define a new zImage tag |
| `df16a5181e74` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-04-16T17:01:33+02:00 | arm: move magic numbers to asm/image.h |
| `0241921df3d0` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-03-26T19:43:33+01:00 | arm: add image header definitions |
| `9d194a88e03b` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-04-29T01:49:11+02:00 | arm: decompressor: set malloc pool size for the decompressor |

### 20. `sandbox/lstelmach/perf-libtraceevent`

perf 链接 libtraceevent 的打包改动，影响观测工具能力。

tip `513cc7e74e7809f4feda06372a82202b88924086`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **13784**、落后 **112095**；去背景后 **2** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4372/+232576/-42156；`arch` 1689/+71735/-9010；`fs` 622/+23464/-14318；`net` 508/+15992/-9314；`tools` 497/+8844/-4460。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__lstelmach__perf-libtraceevent_summary.txt)；[全部目录统计](../evidence/task1/sandbox__lstelmach__perf-libtraceevent_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `513cc7e74e78` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2024-11-20T13:56:02+01:00 | tizen: Link perf against libtraceevent |
| `b4db5c6872b5` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2024-11-20T19:59:58+01:00 | packaging: Do not build perf twice |

### 21. `sandbox/lstelmach/rt`

旧内核 RT 包构建与相关 RT 系列；当前主线也有 RT fragment，不能直接重复套用。

tip `ea9488c6134cb8a1cd352a897106e5339918b9b1`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **13380**、落后 **360601**；去背景后 **5** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4356/+189131/-36138；`arch` 1768/+57105/-8792；`net` 500/+11462/-4226；`include` 471/+8014/-1745；`fs` 419/+8291/-4676。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__lstelmach__rt_summary.txt)；[全部目录统计](../evidence/task1/sandbox__lstelmach__rt_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `ea9488c6134c` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2022-03-03T13:51:19+01:00 | spec: Build rt packages |
| `6ed5442134e7` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2022-02-02T21:34:57+01:00 | Add tizen_bcm2711_rt_defconfig for arm and arm64 |
| `deefe9642562` | Luis Claudio R. Goncalves &lt;lclaudio@uudg.org&gt; | 2022-02-18T14:33:21+01:00 | patch-5.10.100-rt62.patch |
| `fdb10580235e` | Randy Dunlap &lt;rdunlap@infradead.org&gt; | 2021-02-25T17:21:10-08:00 | kernel: delete repeated words in comments |
| `5b00d57f6e56` | Tianchen Ding &lt;dtcccc@linux.alibaba.com&gt; | 2022-01-18T18:05:18+08:00 | cpuset: Fix the bug that subpart_cpus updated wrongly in update_cpumask() |

### 22. `sandbox/lstelmach/stdio-dlog`

stdio 到 dlog/LOGGER_MUTE_ALL 的日志原型；不是回收或压缩优化。

tip `f19c6559602064e6368695cce8d3fef86959d0aa`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **4110**、落后 **360601**；去背景后 **10** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 1773/+121888/-11567；`arch` 755/+40415/-1916；`fs` 209/+2776/-1704；`net` 178/+5035/-1051；`include` 163/+3690/-266。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__lstelmach__stdio-dlog_summary.txt)；[全部目录统计](../evidence/task1/sandbox__lstelmach__stdio-dlog_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `f19c65596020` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-04-12T12:11:54+02:00 | WIP: introduce LOGGER_MUTE_ALL |
| `a41996183927` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-04-12T07:53:09+02:00 | WIP: logger: secure mute operations |
| `5d99f47a91c7` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-03-19T15:17:07+01:00 | WIP: logger-test: test muting |
| `c615af089d5d` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-04-09T18:16:39+02:00 | WIP: logger: mute writers by PID or by tag |
| `131517c68774` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-02-12T18:41:09+01:00 | WIP: logger: use spinlocks to protect lists |
| `26ac55a682d9` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-04-08T15:36:04+02:00 | logger-test: more intensive tests |

### 23. `sandbox/m.szyprowski/virgl`

QEMU/virt/virgl 配置支持，面向虚拟化显示平台，与 RPi4 回收优化不直接重叠。

tip `0dc49ee335dbd0f4fcd49922011e186459b8e4ba`；merge-base `8bb7eca972ad531c9b149c0a51ab43a417385813`；领先 **15710**、落后 **284426**；去背景后 **4** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4868/+295205/-48215；`arch` 2051/+67184/-9312；`net` 563/+14959/-6537；`fs` 500/+13675/-7525；`include` 489/+7881/-2357。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__m.szyprowski__virgl_summary.txt)；[全部目录统计](../evidence/task1/sandbox__m.szyprowski__virgl_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `0dc49ee335db` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2023-11-21T14:20:17+01:00 | x86: add tizen_qemu_x86_defconfig & tizen_qemu_x86_64_defconfig |
| `45e29982e7e3` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2023-11-17T09:12:19+01:00 | arm64/defconfigs: add defconfig for QEmu's 'virt' aarch64 machine |
| `47431c295f19` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2023-11-17T14:42:23+01:00 | drm: virtio_gpu: add support for ARGB8888 primary plane |
| `3647a0d7ca20` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2023-11-16T10:36:32+01:00 | drm: virtio_gpu: add fake timer based vblank handler |

### 24. `sandbox/mbloch/binder`

ARM64 binder 配置与平台通信支持；关注进程间共享机制，不是候选回收算法。

tip `fab22ef8f5f69b5460782e7f919441b98cf38d16`；merge-base `8bb7eca972ad531c9b149c0a51ab43a417385813`；领先 **15707**、落后 **284426**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4867/+295126/-48207；`arch` 2048/+65923/-9312；`net` 563/+14959/-6537；`fs` 500/+13675/-7525；`include` 489/+7881/-2357。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mbloch__binder_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mbloch__binder_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `fab22ef8f5f6` | Michal Bloch &lt;m.bloch@samsung.com&gt; | 2024-02-21T13:28:19+01:00 | Add binder to deathconfig for arm64. |

### 25. `sandbox/mmajewski2/cache-ext`

**PM划界：不重叠，不再跟踪。** 该分支移植BPF页缓存策略框架，没有实现按访问次数提升MGLRU代龄，也没有实现读取时免引用计数；最后一次提交为2026-07-29（c9bf4b7ea8f5）。保留以下历史元数据供审计。

tip `c9bf4b7ea8f543a53949d86818075057ae5f4154`；merge-base `8cdc66794c4281f47cc90efe8b218add97303274`；领先 **8**、落后 **10**；去背景后 **8** 条。

净改动目录（前 5，文件数/+行/-行）：`mm` 11/+1598/-12；`include` 10/+216/-3；`kernel` 5/+293/-6；`tools` 4/+79/-0；`arch` 2/+9/-4。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mmajewski2__cache-ext_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mmajewski2__cache-ext_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `c9bf4b7ea8f5` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2026-07-29T16:51:57+02:00 | Reduce the debugging stuff for now |
| `c44209156abc` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2026-07-08T16:55:32+02:00 | AAAAAAAAAAAAAAAAAAAAAAAAA |
| `412b0e335086` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2026-06-22T16:09:42+02:00 | debug -> DYNAMIC_DEBUG |
| `385ed10fb744` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2026-06-19T15:29:04+02:00 | AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA |
| `ea27ca2bc1cd` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2026-06-17T16:48:07+02:00 | debug |
| `81aabdb62a6d` | Mateusz Majewski &lt;m.majewski2@samsung.com&gt; | 2026-06-15T15:55:29+02:00 | v1 |

### 26. `sandbox/mszyprowski/apply_kfence_arm32b`

ARM32 KFENCE 支持及启用配置，属于低开销内存错误检测。

tip `d8150042a9c093053519043202d6eb09ae859a1d`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **4184**、落后 **360601**；去背景后 **30** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 1775/+123051/-11567；`arch` 768/+42182/-1993；`fs` 210/+2803/-1714；`net` 178/+5035/-1051；`include` 177/+4126/-281。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mszyprowski__apply_kfence_arm32b_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mszyprowski__apply_kfence_arm32b_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `d8150042a9c0` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-11-18T12:31:37+01:00 | arm: tizen_bcm2711_defconfig: enable KFENCE feature |
| `5eb0a944b016` | Kefeng Wang &lt;wangkefeng.wang@huawei.com&gt; | 2021-11-15T21:48:48+08:00 | ARM: Support KFENCE for ARM |
| `f3cfa87188f8` | Kefeng Wang &lt;wangkefeng.wang@huawei.com&gt; | 2021-11-15T21:48:46+08:00 | ARM: mm: Provide set_memory_valid() |
| `386b41fb7187` | Kefeng Wang &lt;wangkefeng.wang@huawei.com&gt; | 2021-11-15T21:48:47+08:00 | ARM: mm: Provide is_write_fault() |
| `4a390d91052c` | Wang Kefeng &lt;wangkefeng.wang@huawei.com&gt; | 2021-09-22T14:56:31+01:00 | ARM: 9130/1: mm: Provide die_kernel_fault() helper |
| `cbd6cab1c2fb` | Wang Kefeng &lt;wangkefeng.wang@huawei.com&gt; | 2021-09-22T14:56:29+01:00 | ARM: 9127/1: mm: Cleanup access_error() |

### 27. `sandbox/mszyprowski/thp_stabilize`

细粒度 THP 稳定性修复，包括 2M 边界的 64K 映射问题。

tip `96673a0b603f26f496280d8034a07ded6746df9a`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7925**、落后 **455938**；去背景后 **79** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317410/-19605；`arch` 1048/+43318/-4241；`net` 356/+8885/-2986；`fs` 326/+4996/-2943；`include` 281/+4845/-2061。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mszyprowski__thp_stabilize_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mszyprowski__thp_stabilize_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `96673a0b603f` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-31T15:21:39+02:00 | thp: fix mapping a 64k THP at the 2M boundary for the new process |
| `0eae0c756df2` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-29T14:40:14+02:00 | thp: final fix for unmap/split related issues |
| `7e5cf8bb4f62` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-24T15:25:21+01:00 | thp: even more fixes for the cleanup paths |
| `afac5cb5c217` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-18T08:08:16+01:00 | THP: enable THP only if disk pages are properly aligned |
| `d8e8bc4b2bf4` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-17T15:22:11+01:00 | THP: disable sanity check |
| `266326f0ffdc` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-15T14:18:58+01:00 | thp: rework mmap |

### 28. `sandbox/mszyprowski/thp_stabilize2`

继续 THP 修正并加入 64KB 匿名 THP 统计，涉及页大小与可观测性。

tip `058cb8e7a546e7e7ea2b0aaa8d509e71085f0939`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7930**、落后 **455938**；去背景后 **84** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317410/-19605；`arch` 1048/+43318/-4241；`net` 356/+8885/-2986；`fs` 326/+5000/-2943；`include` 281/+4852/-2061。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mszyprowski__thp_stabilize2_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mszyprowski__thp_stabilize2_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `058cb8e7a546` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-04-01T13:08:50+02:00 | thp: add separate counters for 64KB anonymous THPs |
| `48bddc8f5ffa` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-04-01T13:07:42+02:00 | thp: reorder enums to match vmstat_text mm/vmstat.c |
| `0b890e53bd60` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-04-01T10:49:33+02:00 | thp: fix potential NULL pointer dereference in debug messages |
| `7afe7f551f01` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-04-01T10:19:29+02:00 | thp: don't leak preallocated 2M huge page if 64k page is applied |
| `a329712ea85f` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-31T15:21:39+02:00 | thp: fix mapping a 64k THP at the 2M boundary for the new process |
| `af98b14900ee` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-29T14:40:14+02:00 | thp: final fix for unmap/split related issues |

### 29. `sandbox/mszyprowski/vc4_hugepage`

文件 mmap 对齐/THP 与 vc4 大页试验，涉及图形内存布局。

tip `4444c2e8fe718062e1a0269653f0dba4ed904c22`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7908**、落后 **455938**；去背景后 **62** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317405/-19605；`arch` 1048/+43318/-4241；`net` 356/+8885/-2986；`fs` 326/+4996/-2943；`include` 281/+4846/-2060。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mszyprowski__vc4_hugepage_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mszyprowski__vc4_hugepage_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `4444c2e8fe71` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-01T10:00:06+01:00 | mm: thp: enable aligning all mmapped files |
| `ec9339619829` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-03-01T09:59:21+01:00 | mm: thp: fix partial unmap of phys PMD |
| `b5901aaeba28` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-02-26T11:38:23+01:00 | mm: thp: add missing case to vma_adjust_trans_huge |
| `5a2752ebb2a4` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-02-26T11:36:50+01:00 | mm: thp: add support for splitting thp pfn range mappings |
| `7771f8d43575` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-02-22T14:40:36+01:00 | mm: thp: add counters for physical memory mmaped to userspace |
| `56899234e7e5` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-02-16T14:41:45+01:00 | mm: thp: map CMA buffers with 64K or 2M huge pages |

### 30. `sandbox/mwilczynski/btf-test`

BTF 打包基础上调整 DWARF 版本，偏调试格式和工具链兼容。

tip `646c1c62b03720153b0e1cc7f018e9f055465ce2`；merge-base `11d5d0d30abe08fddc8a0e856d0e333ca6e22114`；领先 **39**、落后 **7600**；去背景后 **5** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 18/+397/-27；`rpi` 12/+546/-0；`arch` 6/+2026/-0；`packaging` 3/+419/-0；`security` 3/+259/-116。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mwilczynski__btf-test_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mwilczynski__btf-test_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `646c1c62b037` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-08-22T11:36:26+02:00 | change DWARF version |
| `46287f81b53a` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17T10:23:00+01:00 | packaging: Introduce BTF subpackage for eBPF development |
| `92ec5d9e60df` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-14T13:30:42+01:00 | kbuild: Remove unsupported dd option “status=none” |
| `1aeaa3a05835` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17T09:31:27+01:00 | ARM/ARM64: configs: tizen: Enable BTF and DWARF4 debug options |
| `c99dd06e3922` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2025-03-17T10:22:34+01:00 | packaging: Add dwarves BuildRequires |

### 31. `sandbox/mwilczynski/xenomai_patches`

回移 Xenomai/Cobalt/IRQ pipeline 实时支持，调度领域相关但不等于 sched_ext。

tip `724654aa2547ed81eb4ff2732d00532959e44610`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **4772**、落后 **112095**；去背景后 **125** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2500/+381016/-18322；`arch` 1075/+65106/-2856；`include` 372/+26001/-718；`net` 244/+8203/-1331；`fs` 237/+4553/-2390。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__mwilczynski__xenomai_patches_summary.txt)；[全部目录统计](../evidence/task1/sandbox__mwilczynski__xenomai_patches_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `724654aa2547` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2024-07-08T16:41:42+02:00 | Xenomai: Enable missing xenomai cobalt code |
| `a691edbf7a3e` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2024-04-15T13:49:42+02:00 | Xenomai: Enable xenomai cobalt |
| `d94d66aff795` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2024-04-11T10:08:25+02:00 | ARM64: configs: Add the new config for xenomai builds |
| `c01a360a0f1c` | Michal Wilczynski &lt;m.wilczynski@samsung.com&gt; | 2024-04-11T09:21:13+02:00 | packaging: Don't build kernel with xenomai and rt patches |
| `08684311d70c` | Philippe Gerum &lt;rpm@xenomai.org&gt; | 2024-03-12T10:02:57+01:00 | x86: irq_pipeline: add missing __noreturn annotation |
| `ad6aef4fa580` | Florian Bezdeka &lt;florian.bezdeka@siemens.com&gt; | 2024-02-26T23:53:42+01:00 | dovetail: arch: Fix fetching of the first syscall argument from compat tasks |

### 32. `sandbox/opensw0312/android-memsize`

Android memblock/memsize 和保留内存记账系列，涉及可用内存报告语义。

tip `fc0dad964e2b218ef40d86c8174342d1d6609252`；merge-base `d2e59dfd2830321c006d84fa0864f35cfa441504`；领先 **14**、落后 **6**；去背景后 **14** 条。

净改动目录（前 5，文件数/+行/-行）：`mm` 3/+492/-4；`drivers` 2/+12/-0；`include` 1/+10/-1；`kernel` 1/+7/-2。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__opensw0312__android-memsize_summary.txt)；[全部目录统计](../evidence/task1/sandbox__opensw0312__android-memsize_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `fc0dad964e2b` | Jaewon Kim &lt;jaewon31.kim@samsung.com&gt; | 2024-07-12T00:17:04+09:00 | ANDROID: memblock: remove CONFIG_MEMBLOCK_MEMSIZE to simplify |
| `f3cd1172c103` | Jaewon Kim &lt;jaewon31.kim@samsung.com&gt; | 2024-05-07T17:26:27+09:00 | ANDROID: memblock: introduce an early param for memsize |
| `27d1b28261a7` | Jaewon Kim &lt;jaewon31.kim@samsung.com&gt; | 2023-04-20T12:17:49+09:00 | ANDROID: memblock: support memsize reusable to consider as reusable |
| `18740c607557` | Jaewon Kim &lt;jaewon31.kim@samsung.com&gt; | 2020-06-30T11:42:23+09:00 | ANDROID: memblock: print kernel internal size |
| `e857e9987983` | Jaewon Kim &lt;jaewon31.kim@samsung.com&gt; | 2020-06-30T10:57:32+09:00 | ANDROID: memblock: print memsize summary information |
| `007f0a143ea8` | Jaewon Kim &lt;jaewon31.kim@samsung.com&gt; | 2020-06-30T10:32:13+09:00 | ANDROID: memblock: track kernel size on memsize |

### 33. `sandbox/opensw0312/incremental_fs`

回移 Android Incremental FS 及压缩/测试修正，与按需文件读取相邻。

tip `a9291486df4461fbc8c0183da18b281f7a2139e3`；merge-base `ffc253263a1375a65fa6c9f62a893e9767fbebfa`；领先 **13956**、落后 **112095**；去背景后 **150** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4372/+232576/-42156；`arch` 1689/+71773/-9010；`fs` 644/+32081/-14319；`net` 508/+15956/-9328；`tools` 504/+15172/-4460。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__opensw0312__incremental_fs_summary.txt)；[全部目录统计](../evidence/task1/sandbox__opensw0312__incremental_fs_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `a9291486df44` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-07-07T15:25:43+09:00 | selftests: incfs: Fix memory error with zero count mtree in incfs_perf |
| `8021da1fa57d` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-07-01T14:21:32+09:00 | selftests: incfs: Set read_timeout mount option only when not zero |
| `9e03ff2d6151` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-07-01T10:12:22+09:00 | selftests: incfs: print error value with signed type |
| `0cc89716e891` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-06-30T18:24:59+09:00 | incfs: Use locked function for lock required inode |
| `ee1a6a8f4d25` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-06-24T15:25:20+09:00 | selftests: incfs: avoid double free for verity_test |
| `9046d469df45` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2025-06-25T20:03:33+09:00 | selftests: incfs: clear freed pointer in static variable |

### 34. `sandbox/sebuns2/apply_kfence`

旧内核 KFENCE 回移，与内存调试工具裁剪/观测相关。

tip `2c223d5a64a33385934963e25666aa70f81e7a86`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **4174**、落后 **360601**；去背景后 **22** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 1775/+123051/-11567；`arch` 763/+42028/-1925；`fs` 210/+2803/-1714；`net` 178/+5035/-1051；`include` 177/+4126/-281。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__apply_kfence_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__apply_kfence_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `2c223d5a64a3` | Marco Elver &lt;elver@google.com&gt; | 2021-03-17T09:47:40+01:00 | kfence: make compatible with kmemleak |
| `d16b578a2d4d` | Marco Elver &lt;elver@google.com&gt; | 2021-03-04T21:52:56+01:00 | kfence, slab: fix cache_alloc_debugcheck_after() for bulk allocations |
| `6659d4ec39e4` | Marco Elver &lt;elver@google.com&gt; | 2021-03-04T15:40:00+01:00 | kfence: fix reports if constant function prefixes exist |
| `c58ee313b36b` | Marco Elver &lt;elver@google.com&gt; | 2021-03-03T13:11:57+01:00 | kfence: fix printk format for ptrdiff_t |
| `59a34396014f` | Marco Elver &lt;elver@google.com&gt; | 2021-02-23T09:20:43+01:00 | kfence: report sensitive information based on no_hash_pointers |
| `2c631c718b29` | Linus Torvalds &lt;torvalds@linux-foundation.org&gt; | 2021-02-22T11:04:36-08:00 | Merge tag 'printk-for-5.12' of git://git.kernel.org/pub/scm/linux/kernel/git/printk/linux |

### 35. `sandbox/sebuns2/cma_workaround`

CMA_EXCLUDE 分配和 free memory 统计 workaround，涉及 CMA 与低内存判定。

tip `445b27645e82a92361765b5ed10cc33f21cd52e8`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7803**、落后 **455938**；去背景后 **2** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317050/-19559；`arch` 1048/+43286/-4241；`net` 356/+8885/-2986；`fs` 325/+4983/-2942；`include` 274/+4603/-2053。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__cma_workaround_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__cma_workaround_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `445b27645e82` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-09-08T21:57:59+09:00 | tizen_bcm2711_defconfig: enable CMA_EXCLUDEd allocation and free memory calculation |
| `48f25ce00a8d` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-09-08T21:44:30+09:00 | mm: avoid memory thrashing caused by mismatched free memory calculation |

### 36. `sandbox/sebuns2/fine_grained_thp`

细粒度 THP 原型及架构代码拆分，背景仍较多，不能将 733 条都算本分支独创。

tip `a18f4756f0047888d77dd7eb184a33ad5ff074c3`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **1739**、落后 **360601**；去背景后 **733** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 905/+108634/-5571；`arch` 487/+37595/-918；`sound` 96/+19788/-87；`fs` 91/+976/-592；`include` 79/+3141/-107。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__fine_grained_thp_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__fine_grained_thp_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `a18f4756f004` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-02-25T19:22:40+09:00 | mm: THP: separate arch-dependent code from core systems |
| `211bcca26e28` | Seung-Woo Kim &lt;sw0312.kim@samsung.com&gt; | 2021-02-15T16:21:27+09:00 | staging/bcm2835-codec: fix 64-bit build warning for print format |
| `04652b2a7ca5` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-02-04T15:35:27+01:00 | kdbus: read hide_pid and pid_gid from mounted proc |
| `11e83f87cd52` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-02-02T19:52:58+01:00 | pid: mark struct pid* argument as const |
| `6cdf59872b45` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2021-01-28T17:31:15+01:00 | kdbus: Use sizeof_field() macro |
| `3ad261e47314` | Łukasz Stelmach &lt;l.stelmach@samsung.com&gt; | 2020-12-22T12:56:00+01:00 | kdbus: build and package kdbus-tests |

### 37. `sandbox/sebuns2/iotrace`

I/O trace 添加进程/文件标签等改进，服务性能诊断。

tip `f4825da9cb3ff2548749a292ebf36374e27da82d`；merge-base `8bb7eca972ad531c9b149c0a51ab43a417385813`；领先 **13491**、落后 **284426**；去背景后 **19** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4384/+281681/-42740；`arch` 1858/+63056/-8183；`net` 506/+13008/-5469；`include` 450/+7253/-2060；`fs` 440/+11816/-6363。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__iotrace_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__iotrace_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `f4825da9cb3f` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-06-01T19:54:46+09:00 | iotrace: Add "proc:" and "file:" labels to distinguish the process name and the file name |
| `4b9c65c2c12b` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-06-01T19:52:00+09:00 | iotrace: Get iotrace without the dev file initialization |
| `e86e94dbd34b` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-06-01T17:20:16+09:00 | iotrace: Add an iotrace point and pid information for catching missing traces and information |
| `d184bbd72b15` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-05-09T16:52:26+09:00 | iotrace: Fix a lock-after-free bug |
| `624b88f06b92` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-04-28T12:44:21+09:00 | iotrace: Reaarange iotrace trace points |
| `e447d23b7384` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-04-28T10:55:41+09:00 | iotrace: Print the file name which is the I/O's target |

### 38. `sandbox/sebuns2/kernel_compression`

ARM64 允许 LZ4 压缩内核镜像，是启动镜像压缩而非 zram。

tip `624d6479ab03377b8b792b5605d3ecf27e0e6aa8`；merge-base `8bb7eca972ad531c9b149c0a51ab43a417385813`；领先 **13464**、落后 **284426**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4202/+207365/-42740；`arch` 1860/+63052/-8187；`net` 506/+13008/-5469；`include` 449/+7227/-2060；`fs` 439/+11776/-6363。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__kernel_compression_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__kernel_compression_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `624d6479ab03` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-02-20T11:06:42+09:00 | boot: arm64: Enable lz4-compressed kernel image |

### 39. `sandbox/sebuns2/pgo_applied_kernel`

为 profiling/PGO 内核增加构建选项，属于编译器优化历史；未见明确 AutoFDO。

tip `8423391fa02bbd4132ba86f16de5f52e3d225bcd`；merge-base `8bb7eca972ad531c9b149c0a51ab43a417385813`；领先 **15709**、落后 **284426**；去背景后 **3** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 4867/+295126/-48207；`arch` 2049/+66415/-9312；`net` 563/+14959/-6537；`fs` 500/+13675/-7525；`include` 489/+7881/-2357。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__pgo_applied_kernel_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__pgo_applied_kernel_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `8423391fa02b` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-11-14T12:22:42+09:00 | scripts: add an option for building profiling kernel and PGO kernel |
| `e9f30bc2d0fa` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-11-14T12:22:08+09:00 | scripts: increase partition size for profiling kernel image |
| `4087e3da3f81` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2023-11-14T12:20:39+09:00 | arm64: defconfig: add a defconfig for enabling gcov |

### 40. `sandbox/sebuns2/thp-stabilize-sandbox`

THP use-after-free 等稳定性修复，关系内存管理正确性。

tip `af6525b0546aca0af3096636b639ecd69a9facad`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7922**、落后 **455938**；去背景后 **73** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317390/-19605；`arch` 1048/+43344/-4243；`net` 356/+8885/-2986；`fs` 326/+4996/-2943；`include` 281/+4845/-2061。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__thp-stabilize-sandbox_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__thp-stabilize-sandbox_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `af6525b0546a` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-06-21T20:23:41+09:00 | mm: THP: fix bugs on use-after-free cases |
| `f1c3ed8c8daf` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-06-21T20:16:26+09:00 | mm: THP: bug fixes for mismatches of map counts |
| `be35510fb9e7` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-06-11T19:47:24+09:00 | mm: THP: bug fix for reboot failure issue |
| `96eae5300eff` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-05-26T16:38:35+09:00 | mm: THP: remove a variable for delaying THP |
| `e090fba1c3b5` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-05-26T16:36:30+09:00 | mm: THP: add condition for hugepage of the area smaller than 2MB |
| `d3f666070b45` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-05-25T14:48:53+09:00 | mm: THP: fix log level and remove logs |

### 41. `sandbox/sebuns2/thp_5.10_rebase`

将 THP 配置/工作迁移到 5.10，属历史回移。

tip `1420492cc9226ad01c8b483da14b520a5985ea04`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **4117**、落后 **360601**；去背景后 **2** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 1773/+121729/-11567；`arch` 755/+40443/-1916；`fs` 210/+2792/-1705；`net` 178/+5035/-1051；`include` 168/+3860/-266。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__thp_5.10_rebase_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__thp_5.10_rebase_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `1420492cc922` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-07-06T20:51:12+09:00 | arm64: defconfig: add transparent hugepage configs |
| `431449ab209f` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-07-02T18:43:36+09:00 | mm: THP: introducing a fine-grained transparent hugepage technique for ARM64 architecture |

### 42. `sandbox/sebuns2/tizen-5.10.y-thp`

Tizen 5.10 THP 回移和 pte_unmap 等修正，仍含旧下游背景。

tip `ec6724e22ce5bcfe65962fecd8a04c0e439d8750`；merge-base `2c85ebc57b3e1817b6ce1a6b703928e113a90442`；领先 **11192**、落后 **360601**；去背景后 **303** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 3766/+166522/-29864；`arch` 1457/+52216/-6169；`net` 441/+9759/-3406；`fs` 384/+7073/-4090；`include` 378/+6083/-881。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__tizen-5.10.y-thp_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__tizen-5.10.y-thp_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `ec6724e22ce5` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-11-10T08:39:34+01:00 | mm: thp: add missing pte_unmap() calls |
| `35d157c2ac15` | Marek Szyprowski &lt;m.szyprowski@samsung.com&gt; | 2021-11-09T15:34:52+01:00 | mm: thp: fix split_huge_pte() operation on non-THP aligned address |
| `5d7b39b9a1e6` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-10-07T16:57:39+09:00 | mm, thp: preventing hugepage creation for read-write file pages |
| `19067870caf7` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-10-06T13:33:00+09:00 | thp, khugepaged: skip retracting page table if a 64KB hugepage mapping is already established |
| `e53eabea7922` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-10-01T14:15:51+09:00 | mm: thp: khugepaged: flush tlb range to prevent concurrent memory accesses |
| `dce079c99189` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-10-01T13:06:07+09:00 | mm, thp: do not set PTE_SPECIAL for huge zero page |

### 43. `sandbox/sebuns2/use_hugepage`

细粒度 THP 扫描与使用条件实验，影响合并、内存占用和扫描成本。

tip `5ce636ad561b6ac2701b488314e0b82afb19c689`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7883**、落后 **455938**；去背景后 **34** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317390/-19605；`arch` 1048/+43317/-4241；`net` 356/+8885/-2986；`fs` 326/+4992/-2943；`include` 281/+4840/-2060。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__use_hugepage_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__use_hugepage_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `5ce636ad561b` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-03-30T15:33:01+09:00 | mm: THP: reconfigure scanning condition |
| `02326270855c` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-03-24T19:35:11+09:00 | mm: THP: expand memory hook for all kind of transparent hugepages |
| `89b2f5051203` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-03-24T19:30:04+09:00 | mm: THP: bug fix in hugepage fault handling on first pmd expansion |
| `1647de7ba73d` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-03-17T23:54:12+09:00 | mm: THP: bug-fixes: resolve condition mis-matching |
| `f2ee4b5c8580` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-03-17T23:50:31+09:00 | mm: THP: bug-fixes: resolve unexpected scanning for unmapped regions |
| `c217ce95e558` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2021-03-09T17:06:18+09:00 | mm: THP: extend 64KB hugepage for anonymous pages |

### 44. `sandbox/sebuns2/use_lto`

旧内核 Kconfig/Makefile/scripts 接入 LTO，目标减少镜像体积。

tip `a4fe97e13a49f05869d685bcde1799394596168b`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7841**、落后 **455938**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2856/+317388/-19605；`arch` 1048/+43292/-4241；`net` 356/+8885/-2986；`fs` 325/+4983/-2942；`include` 273/+4598/-2052。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__sebuns2__use_lto_summary.txt)；[全部目录统计](../evidence/task1/sandbox__sebuns2__use_lto_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `a4fe97e13a49` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-12-03T12:44:05+09:00 | Kconfig: Makefile: Scripts: apply link-time optimization for reducing kernel size |

### 45. `sandbox/shkim/lksm`

KSM 过滤/轻量合并方案与 ARM64 配置，属于页面去重而非 MGLRU-FG。

tip `dd49d1840c83359c4a842b4914badbd3d35c33ca`；merge-base `219d54332a09e8d8741c1e1982f5eae56099de85`；领先 **7761**、落后 **455938**；去背景后 **5** 条。

净改动目录（前 5，文件数/+行/-行）：`drivers` 2858/+316891/-19595；`arch` 1048/+43273/-4241；`net` 356/+8885/-2986；`fs` 325/+4983/-2942；`include` 273/+4598/-2052。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__shkim__lksm_summary.txt)；[全部目录统计](../evidence/task1/sandbox__shkim__lksm_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `dd49d1840c83` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-07-16T16:00:07+09:00 | arch: arm64: enable CONFIG_KSM_FILTER |
| `a5a9a84ddf95` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-07-16T15:58:28+09:00 | mm: LKSM: : new feature: use filter-based scanning to reduce scanning cost |
| `82a4475b9663` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-07-16T09:07:37+09:00 | arch: arm64: enable CONFIG_LKSM |
| `437b277f4abd` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-07-16T09:05:12+09:00 | mm: LKSM: lightweight memory deduplication for embedded devices |
| `d52823705573` | Sung-hun Kim &lt;sfoon.kim@samsung.com&gt; | 2020-07-14T15:04:38+09:00 | mm: LKSM: prepare to add LKSM code |

### 46. `sandbox/swadas/selinux`

将主 LSM 从 SMACK 改为 SELinux；当前主线已有可选片段，测试配置需统一。

tip `271f7d7add415f98fc0a182ee8cb19afaf61d3ac`；merge-base `8cdc66794c4281f47cc90efe8b218add97303274`；领先 **1**、落后 **10**；去背景后 **1** 条。

净改动目录（前 5，文件数/+行/-行）：`arch` 2/+34/-4；`packaging` 1/+2/-2。

[完整领先提交摘要（作者、日期、标题）](../evidence/task1/sandbox__swadas__selinux_summary.txt)；[全部目录统计](../evidence/task1/sandbox__swadas__selinux_dirs.txt)。

| commit | 作者 | 作者日期 | 标题 |
| --- | --- | --- | --- |
| `271f7d7add41` | Stanislaw Wadas &lt;s.wadas@samsung.com&gt; | 2026-07-09T12:50:09+02:00 | Add SELinux as a main lsm instead of SMACK |

## 5. 任务2划界与后续前提

- silent-reclaim-fix的归属已明确；memcontrol修复已拆入base，zram配置由本项目另评估。
- 用户本人的MLGO分支与本项目不重叠。
- cache-ext不重叠，不再跟踪，不再要求确认负责人或机器学习项目归属。
- jaehoon80/zram删除BTF与启用二次压缩是两个需要单独评估的行为，尚未合入base。
- SSH查询已获得17条merged/0条open，其中相关12条；不再把匿名REST限制列为未取得此次变更清单的阻塞。
- 历史sandbox的存在不代表当前仍在维护；具体优化方案以PM后续任务为准。
