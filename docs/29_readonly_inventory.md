# 任务29：design v5 阶段0a只读盘点

核对日期：2026-11-10。仅源码、公开上游和离线镜像盘点；未连接开发板，未构建、运行回收接口、修改源码/镜像或推送Gerrit。结论中的“源码确认”不等于运行时测量；“推测”明确限定推导条件；无法从离线材料得出的事项标为“未确认”。本任务不直接改写design v5。

## 范围、证据与版本

- **K**：linux-rpi `0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`（6.12.80）。下文内核文件行号均对应此提交。
- **R**：resourced `94d346c306233803661e8eab8557596549d82be4`。下文resourced文件行号均对应此提交。
- **G**：platform/core/system/plugin/resourced-generic `d8ca36372116779a1a7d171198fdc20be8cd1858`，镜像实际安装的LMK后端。
- **S**：platform/upstream/systemd `317f5070936f11bea121e1f9fa6c16492b520902`，两镜像RPM数据库均为systemd 244-0。
- **H**：profile/iot/apps/dotnet/homescreen-app `f9109d793090f955c5f5afd594fb9c4a3264b118`。
- 镜像A=SR QB1218764；镜像B=QB1220670。两者的版本对照、内部差异和完整证据仅在本地 `vendor_local/task29/review/`；公开文档只引用上述Tizen公开源码、上游及可公开的镜像盘点结果。
- 两个headed原归档SHA-256先核对，再提取独立的rootfs/system-data只读副本。A=`68fe480cf0fa2e9107327ccfc0eb94e6b6aad7fa632f694620a5a8a8cc8abc01`；B=`e2ded03698d9fae05d327b83f8886d56c6cb8eea9691725aa3a7640ece6ee73a`。仅通过平台debugfs读取副本；RPM查询针对导出的数据库副本。未读写挂载镜像。
- 重负载均由 `systemd-run --user --scope -p CPUQuota=400% -p MemoryMax=8G nice -n 10 ionice -c3` 包装。镜像串行解包，平台debugfs/rpm经GBS根中的qemu-arm执行；临时工具仅从已批准固定快照取包并核对元数据SHA。完整命令、退出码和失败重查记录在本地执行日志中。

## 1. resourced杀进程路径（3.10.1）

**源码确认，两版本的resourced主程序对应路径相同。** `src/common/ipc/safe-kill.c:85–99` 最终调用 `kill(pid,sig)`，不是pidfd。`src/resource-limiter/memory/lowmem-controller.c:111–131` 根据应用优先级和PROC_SIGTERM选择SIGTERM或SIGKILL，重复处理已标记受害者时改用SIGKILL；并不是每次都直接SIGKILL。全量src/include检索没有pidfd_open、pidfd_send_signal、process_mrelease。

**没有逐个等待受害者退出。** `lowmem.c:1058–1128` 的worker在重试时固定等待1秒、完成一批后等待2秒并回调重新评估（常量在180–182）；不是pidfd轮询、waitpid或退出事件确认。`lowmem-controller.c:190–232` 每轮候选循环受max_victims限制；每3个候选索引读一次MemAvailable，达到阈值则停止；还会依据受害者原RSS的累计估值停止（205–209、232），这不是已经释放的内存实测量。

配置与限额（源码确认）：

| 项目 | 默认/镜像文件 | 依据 |
|---|---|---|
| 最大受害者数 | RAM分档：≤64MiB为1、≤256为2、448/512/768/1024档为5、>1024MiB档为10；本4GB镜像落在10档 | R `lowmem.c:91–169,1252–1320` |
| 覆盖键 | `[MemoryLevelThreshold] LmkMaxVictimPerOom`；镜像中`=10`为注释，沿用分档 | R `lowmem.c:1623–1624`；镜像`/etc/resourced/limiter.conf:9` |
| 内存级别 | Medium25%、Low15%、Critical10%、Oom7% | 镜像`/etc/resourced/limiter.conf:1–5`；R `lowmem.c:1510–1605` |
| 离开阈值 | LmkThresholdLeave未显式设置；高RAM分档初值500MiB，另受运行时阈值逻辑影响 | R `lowmem.c:160–169,1598–1605`；镜像limiter.conf:6 |
| 特殊请求 | proactive high最多4；force前台阶段1 | R `lowmem.c:78–79,1030–1041,1426–1427` |

这里的“10”是一次候选处理的上限，**不是整个持续压力事件最多杀10个PID**：请求可按LRU→MRU→前台→更广候选集合升级并重试（R `lowmem.c:1027–1048,1094–1112`）。应用组RSS参与排序，但执行器对选出的tsk.pid发信号，不能把victim_cnt等同于应用全部子进程的退出数。

**排序**：R `lowmem.c:592–660` 汇集oom_score_adj、LRU修正后的oom_score_lru、进程组RSS、前台/窗口及working-set信息；G `src/resourced-memory-lmk/resourced-memory-lmk.c:46–64,94` 按 `oom_score_lru × (totalram_KiB / 2000) + RSS_KiB` 的比较器排序，并非只按RSS或只按oom_score_adj。WSS与前台窗口后处理是可选项，镜像`limiter.conf:25–26`均为no；G同文件144起、199起提供对应实现。

**Home/前台保护不是无条件不杀**：R `proc-main.c:1654–1661,2149–2169` 把Home作为perceptible类别示例，`proc-process.c:151–154`给perceptible后台分数；`lowmem-controller.c:147–170` 在普通压力下只有MemAvailable高于动态OOM阈值才保护这一档（阈值赋值见lowmem.c:985,1148），force/single-shot另有排除。显式LMK例外和is_free_from_kill也会排除候选（`lowmem.c:604–620`、controller:214–216；配置说明`conf/README:629–636`）。**未确认**：当前Home在所有生命周期中是否总带对应元数据/例外，离线镜像不能证明“永不被杀”。v5的Home硬保护属于待实现并验收的策略，不能记为已有保证。

## 2. 冻结能力（3.13）

**源码确认**：R有cgroup freezer包装层，使用`/sys/fs/cgroup/freezer/frozen`（`src/resource-limiter/freezer/freezer.c:155–169`）；实际策略通过`/usr/lib/libsystem-freezer.so.0`动态加载（51、331–402；路径编译设置`src/CMakeLists.txt:226`）。包装层处理应用/服务wake-up、APP_SUSPEND、freezer状态、关机以及可选LCD事件；DBus溢出可唤醒被冻结进程并按时再次冻结（freezer.c:234–328,414–453）。

**镜像确认**：两镜像正常rootfs该库均不存在，RPM载荷清单也未发现system-freezer实现；初始化的存在性检查因此不能通过。不能把编入包装层当成镜像已有可用冻结策略。**未确认**：缺失插件内部的冻结对象选择、具体阈值及开关，当前源码不能完整回答；本resourced没有一套已启用的“播放期间按refault冻结”实现。两版本主程序此处无差异。

## 3. 按应用/服务的内存上限（3.15）

**源码确认，已有能力，不能写成完全没有上限。** R `lowmem-limit.c:473–560` 建立`Private/<appid或配置名>`并迁移进程；`lowmem_reassign_limit():328–410` 设置memory.limit_in_bytes、配置oom_control并注册eventfd。

- 按应用类型、前后台状态以及`[Private] App/Service/Process`均有配置入口；`MemLimitAction=<大小>,<action>`可覆盖动作（R `conf/README:105–168,597–613`；`config-parser.c:1038–1072`）。镜像limiter.conf:13启用ServicePerAppLimitAction=128MB，其他GUI/widget/web示例被注释。这里Service是应用服务类别，不等于每个systemd unit统一128MB。
- **当前镜像默认触发器是oom**（limiter.conf:29）。OOM事件的KILL动作重新允许内核OOM处理，并非直接走下面的用户态定时SIGKILL（R `lowmem-limit.c:179–199,307–313,367–375`）。
- threshold模式下检查memory.memsw.usage_in_bytes或usage，支持broadcast、reclaim、kill；kill先SIGTERM，2秒后检查存活再SIGKILL；硬上限可为触发阈值1.2倍（R `lowmem-limit.c:146–170,202–279,377–402`）。
- 系统服务还有systemd自己的硬限制，详见第13项。

**推测/待验证**：可以围绕现有memcg/事件入口扩展预算，但v5提出的前后台PSS预算、先定向回收再按超额排序，不是当前代码已经实现的完整流程。两版本resourced主程序这部分相同。

## 4. memcg分组（3.14）

**源码确认**：R `src/common/cgroup/memory-cgroup.h:42–61` 定义根组、`BackgroundMru`、`BackgroundLru`、`Private/<名称>`。`memory-cgroup.c:112–127` 按perceptible/favorite归MRU、普通后台归LRU、其余归root；`lowmem-controller.c:335–412` 在通知中处理迁组，已有private上限的应用优先维持private组。应用类型/前后台/窗口/例外在resourced元数据中存在，**目录本身不是“前台/后台/Home/系统服务”四个互斥组**，root和MRU都可能混合角色。

`memory-cgroup.c:391–412` 写hard limit，415–439写swappiness；BackgroundLruLimit=80%来自镜像limiter.conf:22，SR的BackgroundLruSwappiness=80来自optimizer.conf:4。数值必须以后回读cgroup节点，不把配置意图当实测值。两版本的分组代码相同，swap管理是否启用会影响相关执行路径，私有版本差异详本地报告。

**源码确认**：两版本src/include均没有写`soft_limit_in_bytes`的实现；v5新增该设置不是对既有设置的简单调参。即使写入，第6项的MGLRU门槛仍会阻断软限制回收。

## 5. 低内存事件与阈值

**源码确认，不是只看MemAvailable。** R `lowmem-monitor.c:42–78` 按编译条件先尝试eBPF，再PSI，再vmpressure；PSI失败才回退。`lowmem-monitor-psi.c:124–157,228,303–333` 对`/proc/pressure/memory`写触发器并epoll：some 30ms/500ms、70ms/1s、100ms/1s，以及full 70ms/1s。vmpressure经memcg事件唤醒，再检查available级别（`lowmem-monitor-vmpressure.c:43–55`）。杀进程循环仍反复读取MemAvailable（第1项）。

R `src/common/procfs/procfs.c:84–104,445–457` 解析MemAvailable，缺字段时才退回free+cached估算；还有可选CMA扣除逻辑。**未确认**：本次不运行程序，不能断言两个镜像此次开机会成功选中哪一监控后端。v5新增PSI反馈需要区分已有PSI唤醒与新的反馈控制策略。

## 6. memcg v1 soft limit与MGLRU

**结论：MGLRU开启时不生效，不是部分生效。** K `mm/memcontrol-v1.c:347–359` 的入口实际名为`memcg1_soft_limit_reclaim()`；在`lru_gen_enabled()`为真时直接return 0。软限制树更新也在该条件下跳过（同文件210附近）。

完整相关调用链（源码确认）：

```text
直接回收：try_to_free_pages (mm/vmscan.c:6504,6539)
  → do_try_to_free_pages (:6271,6289)
  → shrink_zones (:6148,6212)
  → memcg1_soft_limit_reclaim (mm/memcontrol-v1.c:347)
      → MGLRU开启：:358–359 return 0
kswapd：kswapd (mm/vmscan.c:7258)
  → balance_pgdat (:6858,6980)
  → 同一入口，同一return 0

仅在未被上述门槛返回时：
  memcg1_soft_limit_reclaim (:379起，选择超额memcg)
  → mem_cgroup_soft_reclaim (:297,337)
  → mem_cgroup_shrink_node (mm/vmscan.c:6550,6580)
  → shrink_lruvec (:5695起)
```

下游`shrink_lruvec`确实有MGLRU非root memcg分支（vmscan.c:5706→4939），但**软限制入口已经返回，不能据此证明软限制在MGLRU下有效**。全局普通回收仍能走`shrink_node:5962–5970 → lru_gen_shrink_node`，不代表软限制带来了偏向。

两份最终配置均启用LRU_GEN及LRU_GEN_ENABLED；运行时若明确关闭MGLRU，legacy软限制路径才有机会执行，仍是best-effort软限制。**v5 3.14路径A“保持MGLRU、只改v1软限制即可改变回收偏向”被源码推翻**，不能按原方案进入实验。

## 7. zram写回（3.11）

下表均为K源码确认；PAGE_SIZE在两份目标配置中为4KiB。

| 核对项 | 6.12.80实际行为 | 依据 |
|---|---|---|
| 配置依赖 | WRITEBACK与TRACK_ENTRY_ACTIME分别depends on ZRAM；前者不依赖后者；MEMORY_TRACKING会select ACTIME | drivers/block/zram/Kconfig:107–132 |
| 当前配置 | 两镜像WRITEBACK=n、ACTIME=n；不能直接使用写回接口 | 两份最终.config，A:1698–1699，B:1706–1707 |
| backing_dev | O_RDWR/O_EXCL打开，必须S_ISBLK且容量非0；初始化后EBUSY，因此须在disksize初始化之前设置 | zram_drv.c:482–547 |
| loop | 已配置且容量非0的loop是块设备，符合此类型检查；普通文件不符合 | 同上；“loop可通过类型门槛”为推测，未运行loop/文件系统组合 |
| 选择模式 | idle、huge、huge_idle、incompressible、单槽page_index=N；没有新版page_indexes区间接口 | zram_drv.c:622–639 |
| idle时间 | idle=all可用；数字秒数只有ACTIME开启时可用，按boottime减age作cutoff | zram_drv.c:291–352 |
| 写入预算 | writeback_limit_enable控制是否扣减，单位4KiB，每个成功PAGE_SIZE扣PAGE_SIZE/4096；0时拒绝继续，没有自动每小时补充 | zram_drv.c:384–441,665–673,768–770 |
| 写入数据 | 普通压缩槽先zram_read_page(NULL)，从zspool解压；huge槽复制整页；SAME/WB等槽跳过 | zram_drv.c:685–709,1430–1489 |
| I/O提交 | 每次bio加PAGE_SIZE，REQ_SYNC，submit_bio_wait；循环内逐页同步等写完成，没有多请求批处理 | zram_drv.c:717–726 |
| 常规读回 | 已写回槽位→read_from_bdev→read_from_bdev_async，分配子bio、bio_chain到父bio后submit_bio | zram_drv.c:590–600,828–837,1471–1489 |
| 同步读特例 | parent=NULL路径走worker并flush_work；代码要求ZRAM_PARTIAL_IO场景 | zram_drv.c:811–835 |

**v5核对**：3.11“压缩对象解压成整页、按4KiB逐页同步写出、没有批处理”的判断成立（huge原本不压缩，SAME等不写，不应理解成所有槽都先解压）。总量是**成功选中写出的页数×4KiB**，不是压缩长度；文件系统/loop额外I/O不包括在此逻辑页数中。3.11“读回从后备设备同步读取”过于笼统，应改为常规父bio路径异步提交、特定无父bio路径同步等待；缺页线程可能等待数据完成是另一层语义。writeback_limit是可重设的剩余配额，不是自带时间窗的限速器。

## 8. 进程级接口权限与状态（3.10、3.12）

| 接口 | 源码确认的门槛 | 依据 |
|---|---|---|
| process_mrelease | flags=0，有效pidfd/目标mm；task_will_free_mem为真才尝试回收；已处理、无mm、未进入可释放状态分别有不同返回；不保证一次释放全部内存 | K mm/oom_kill.c:1205–1266 |
| 退出状态 | 排除core dump；group exit或单线程PF_EXITING；共享mm的其他使用者也必须处于可释放状态 | mm/oom_kill.c:847–918 |
| mrelease权限 | 该实现及pidfd_get_task路径**没有PTRACE_MODE_ATTACH、CAP_SYS_NICE或CAP_SYS_PTRACE检查**；发送杀信号本身仍有独立权限/LSM限制，不能混为一谈 | mm/oom_kill.c:1218–1256；kernel/pid.c:568–584,629–647 |
| ARM32 syscall号 | pidfd_open=434；process_madvise=440；process_mrelease=448 | arch/arm/tools/syscall.tbl:451,457,465 |
| process_madvise允许值 | COLD、PAGEOUT、WILLNEED、COLLAPSE；不包括POPULATE_READ | mm/madvise.c:1222–1232 |
| 跨进程madvise权限 | mm_access(PTRACE_MODE_READ_FSCREDS)，且目标mm不是当前mm时要求CAP_SYS_NICE；flags必须0 | mm/madvise.c:1491–1545 |
| ptrace访问本身 | 同线程组例外；uid/gid或目标user namespace的CAP_SYS_PTRACE、dumpable及security_ptrace_access_check | kernel/ptrace.c:276–347；kernel/fork.c:1559–1579的mm_access |
| pagemap打开 | proc_mem_open采用PTRACE_MODE_READ加FSCREDS | fs/proc/task_mmu.c:2064；fs/proc/base.c:838–845 |
| swap槽编号可见性 | show_pfn=file_ns_capable(file,init_user_ns,CAP_SYS_ADMIN)；没有此cap时swap type和offset不填，仍能看到PM_SWAP等状态位 | fs/proc/task_mmu.c:1719–1750,1990 |

**v5 3.10.1的“mrelease要求PTRACE_MODE_ATTACH级权限”必须删除并改正。** 先发SIGKILL不等于目标立刻满足task_will_free_mem；需处理EINVAL/ESRCH/EAGAIN/EINTR等竞态，不能把返回0当作“目标已经退出”或释放量证明。3.12的跨进程MADV_WILLNEED则确实需要ptrace READ_FSCREDS和CAP_SYS_NICE，匿名swap预读路径在`mm/madvise.c:171–216,261–273`，不会替代目标全部缺页过程。pagemap的“root可读”应改写为实际capability、proc访问及LSM条件。

## 9. 当前MGLRU的可执行页处理（3.5.3）

**源码确认**：K `mm/vmscan.c:3159–3178` 的`folio_update_gen()`通常直接更新代际；**只对已隔离、没有LRU_GEN_MASK的folio设置PG_referenced**。look-around在4067起，清访问位后在4150调用代际更新，隔离情形4159设置referenced。`shrink_folio_list:1110–1113` 对MGLRU下mapped且referenced的folio有保留路径。这棵6.12树**没有lru_gen_set_refs()**，全树检索已留证。

经典LRU可执行文件保护仍在：`folio_check_references():865–918`，914处VM_EXEC文件首次引用激活，对应[c909e99364c8](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=c909e99364c8)；`shrink_active_list():2108–2123`，2120处对引用过的可执行文件保留active，对应[8cab4754d24a0](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=8cab4754d24a0)。

**v5 3.5.3需改写**：“folio_update_gen只设PG_referenced、第一次使用会被忽略”不是此版本的一般行为。可以确认当前没有新版那种显式executable-file特殊优待，不能直接把2026年的缺陷描述套在6.12、或把新版小补丁视为可直接回移植。是否造成Home代码页过早淘汰仍为**未确认**的性能假设。

## 10. Baolin Wang与Barry Song相关补丁

**公开上游确认（截至本次检索）**：Baolin的最终v4补丁已进入主线，提交[`0ee06ee38aed1a9949510624a1b4abdc7e39815a`](https://github.com/torvalds/linux/commit/0ee06ee38aed1a9949510624a1b4abdc7e39815a)，标题“mm: mglru: promote mapped executable folios after first usage”；作者日期2026-07-20、mm提交日期2026-08-24，经mm-stable合入，首个正式主线版本**7.3**。v7.2/v7.3源码边界核对已留底；同系列先加识别helper的提交为`b64727d26478`，且依赖当时的vma_flags_t/新版refs处理上下文，不能只数补丁行数。

Barry的相关路径要分开记录：[`6cbdd9726fb5`](https://github.com/torvalds/linux/commit/6cbdd9726fb5)改变fault-around页的优先级；针对其回归的“fix using folio_mark_accessed to replace folio_set_active”曾在2026-10-17加入mm-unstable，**同日又以to-be-updated移除**，[维护者移除通知](https://lore.kernel.org/mm-commits/20261017224815.389E61F000C4@smtp.kernel.org/)。[2026-11-05作者讨论](https://lore.kernel.org/linux-mm/CAGsJ_4yb2r2qjYjBLtYpVbQ99Nypp4rg0EuKmdkyFc8C9Tx-Nw@mail.gmail.com/)仍在等待Cassandra复现；本次主线及mm-stable标题检索无该修复，不能写“已合入”。邮件中的f9683205是投稿本地hash，不是已确认的主线SHA。最终替代修复SHA/版本**未确认**。

## 11. MGLRU-FG最新状态

**公开上游确认**：本次检索到的最新完整系列仍是[2026-10-16 v4，17个补丁](https://lore.kernel.org/linux-mm/20261016-mglru-fg-v4-0-2106750c0bfa@tencent.com/)，已移出RFC，11月仍在讨论。核对本次主线HEAD `b3dfbde62cf1981c4638939c159dfd087b7a72e9`及mm-stable的vmscan，没有完整FG的folio_inc_lru_refs路径；**尚未发现完整系列合入主线/mm-stable的证据**，不填最终合入版本。独立flag/计数准备清理不能视为FG已经合入；搜索结果中的其他“v5/v6”系列不能冒充本系列的新版本。回移植可行性、ARM32页标志位压力和收益仍需后续工作，未在本轮试打或编译。

## 12. 2025-05以来zram写回演进与6.12前置依赖

以下为主线最终提交，不使用mm临时补丁hash。版本通过相邻正式tag源文件核对；作者日期、mm提交日期、正式发布版本是不同概念。

| 主线提交 | 内容 | 首个主线正式版本/依赖 |
|---|---|---|
| [cf42d4cccf0d](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=cf42d4cccf0d) | 写回接口现代化：多参数、page_indexes区间，兼容旧格式 | 6.16；作者3月投稿，5月进入该轮合入；依赖pp-slot选择队列 |
| [f405066a1f0d](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f405066a1f0d) | 多个in-flight bio的写回批处理 | 6.19；基于zram_writeback_slots/pp控制器，异步完成处理 |
| [e828cccb72ed](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=e828cccb72ed) | writeback_batch_size设备属性 | 6.19；依赖上一条的请求池 |
| [7c929664fddf](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=7c929664fddf)、[a4f506c569e1](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=a4f506c569e1) | limit写锁及去掉旧wb_limit_lock | 同一6.19批处理系列，涉及并发预算一致性 |
| [e87ddea34567](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=e87ddea34567)、[1b1a4e4d6797](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=1b1a4e4d6797) | backing块分配、slot锁内取块号 | 同一6.19系列，不能只挑性能主补丁忽略竞态 |
| [d38fab605c66](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=d38fab605c66)、[4c1d61389e8e](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=4c1d61389e8e) | 压缩数据写回、writeback_compressed开关 | 7.0；基于批处理、压缩对象读取及读回解压元数据，mm提交在2026-01，作者投稿为2025-12 |
| [ba4c3698e696](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=ba4c3698e696) | 属性改名compressed_writeback | 7.0；不应把两个名字当作两个独立功能 |

**源码确认的前置结构差异**：6.12.80还有UNDER_WB/直接扫描并submit_bio_wait，没有新版`zram_pp_ctl`写回目标队列。历史前置包括`bf779fb9afb5`（PP_SLOT）、`58652f2b6d21`（单一post-processing）、`3f909a60cec1`/`330edc2bc059`（目标选择）、`5e99893444a0`（去UNDER_WB）、`b8d3ff7bb511`（直接读zspool），以及`bd175a1d84e3`（可睡眠entry锁）、`82f91900c722`（zsmalloc映射API）。这些早于主要目标补丁，部分源码差异不能靠机械cherry-pick解决。后续slot API/dev_lock重命名也改变上下文。每个上述短SHA均可在[主线提交查询](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/block/zram)及本地UPSTREAM_EVIDENCE.txt检索。

批处理/压缩回移植还必须审查后续修复：`bf62f69574b1`（endio UAF）、`3e8d8eb8d7f5`（预留块泄漏）、`3bf1c285dc40`（压缩写回尾部字节清零）、`bf989ade270d`（异步读错误传播）、`b0377ee80429`（已写回槽生命周期）。**推测**：可移植功能而不机械搬入每个纯重构，但应保持锁、预算、slot释放、bio完成与错误路径的语义；最小补丁闭包和能否干净应用**未确认**，本轮没有试打/编译。压缩写回也不等于介质字节数必然恰好等于所有压缩长度之和，仍受块对齐和实现布局约束。

## 13. 镜像unit内存限制与systemd v1行为

**镜像/源码确认**：两镜像正常system/user unit及已提取的etc drop-in中均为21项MemoryMax、1项MemoryLimit，MemoryHigh为0；22项完全一致。下表路径均为`/usr/lib/systemd/system/`，行号来自镜像原文件；未把注释、wants链接重复计数。未启动systemd，清单是静态声明，不能证明所有服务已启用或运行。

| unit | 设置 | 镜像文件行号 |
|---|---|---|
| ac.service | MemoryMax=100M | 24 |
| actd.service | MemoryMax=20M | 13 |
| buxton2.service | MemoryMax=50M | 13 |
| contextd.service | MemoryMax=30M | 15 |
| download-provider.service | MemoryMax=100M | 11 |
| engine-loader.service | MemoryMax=30M | 13 |
| esd.service | MemoryMax=100M | 19 |
| focus-server.service | MemoryMax=50M | 8 |
| hal-backend-service.service | MemoryMax=20M | 15 |
| lbs-server.service | MemoryMax=10M | 13 |
| muse-server.service | MemoryMax=300M | 14 |
| pipewire.service | MemoryMax=50M | 40 |
| pkgmgr-info.service | MemoryMax=100M | 16 |
| pushd.service | MemoryMax=10M | 10 |
| resourced.service | MemoryMax=50M | 16 |
| rscmgr-service.service | MemoryMax=10M | 14 |
| sensord.service | MemoryMax=20M | 12 |
| sessiond.service | MemoryMax=20M | 19 |
| stability-monitor.service | MemoryMax=20M | 14 |
| storaged.service | MemoryMax=20M | 14 |
| tizen-action-plugin-launcher.service | MemoryLimit=100M | 13 |
| tizen-watcherd.service | MemoryMax=10M | 13 |

**S源码确认**：`src/core/load-fragment-gperf.gperf.m4:183–186`识别这三个键；`src/core/cgroup.c:1296–1340`在unified模式写memory.high/max，在legacy模式只写memory.limit_in_bytes。若存在unified类型配置，则v1取memory_max，否则取legacy memory_limit（1323–1338）；因此MemoryMax映射硬上限，**MemoryHigh在cgroup v1没有对应软限制作用**（man/systemd.resource-control.xml:106–107亦明确）。只设MemoryHigh还会使`unit_has_unified_memory_config:949–956`成立，不能假设它与旧MemoryLimit任意混用仍符合预期。v5 3.15“MemoryHigh/Max都映射到v1限制”应拆开说明。

## 14. Restart=always/on-failure清单

**镜像确认**：A共45项（system 43、user 2），B共46项，B多出的内部unit仅在本地清单列名；其余一致。排除了Restart=no和on-abnormal，保留模板单元但不推断实例数量；未把该列表当成当前运行/实际重启次数。另只读提取了两镜像隔离目录中的五个通用unit/socket，未发现MemoryMax/MemoryHigh/MemoryLimit或always/on-failure声明，故不改变上述计数；原文随本地清单保存。

| unit路径 | Restart | 行号 |
|---|---|---|
| /usr/lib/systemd/system/ac.service | on-failure | 22 |
| /usr/lib/systemd/system/bluetooth-frwk.service | on-failure | 12 |
| /usr/lib/systemd/system/boot-animation.service | on-failure | 19 |
| /usr/lib/systemd/system/capi-ui-sticker.service | on-failure | 11 |
| /usr/lib/systemd/system/connman.service | on-failure | 14 |
| /usr/lib/systemd/system/console-getty.service | always | 25 |
| /usr/lib/systemd/system/container-getty@.service | always | 30 |
| /usr/lib/systemd/system/contextd.service | on-failure | 13 |
| /usr/lib/systemd/system/cynara.service | always | 11 |
| /usr/lib/systemd/system/debug-shell.service | always | 20 |
| /usr/lib/systemd/system/deviced.service | on-failure | 14 |
| /usr/lib/systemd/system/display-manager-monitor.service | always | 15 |
| /usr/lib/systemd/system/display-manager.service | always | 12 |
| /usr/lib/systemd/system/dlog_logger.service | on-failure | 32 |
| /usr/lib/systemd/system/engine-loader.service | on-failure | 11 |
| /usr/lib/systemd/system/esd.service | on-failure | 17 |
| /usr/lib/systemd/system/feedbackd.service | on-failure | 8 |
| /usr/lib/systemd/system/focus-server.service | always | 6 |
| /usr/lib/systemd/system/getty@.service | always | 40 |
| /usr/lib/systemd/system/hal-backend-service.service | on-failure | 12 |
| /usr/lib/systemd/system/media-server.service | on-failure | 14 |
| /usr/lib/systemd/system/mobileap-agent.service | on-failure | 11 |
| /usr/lib/systemd/system/mtp-responder.service | on-failure | 15 |
| /usr/lib/systemd/system/muse-server.service | always | 13 |
| /usr/lib/systemd/system/net-config.service | on-failure | 12 |
| /usr/lib/systemd/system/pass.service | always | 8 |
| /usr/lib/systemd/system/pipewire.service | always | 27 |
| /usr/lib/systemd/system/pkgmgr-info.service | on-failure | 17 |
| /usr/lib/systemd/system/pushd.service | on-failure | 8 |
| /usr/lib/systemd/system/resourced.service | on-failure | 17 |
| /usr/lib/systemd/system/rscmgr-service.service | always | 13 |
| /usr/lib/systemd/system/security-manager.service | always | 8 |
| /usr/lib/systemd/system/serial-getty@.service | always | 36 |
| /usr/lib/systemd/system/sessiond.service | on-failure | 18 |
| /usr/lib/systemd/system/stability-monitor.service | on-failure | 12 |
| /usr/lib/systemd/system/stc-manager.service | on-failure | 9 |
| /usr/lib/systemd/system/storaged.service | always | 11 |
| /usr/lib/systemd/system/systemd-journald.service | always | 28 |
| /usr/lib/systemd/system/systemd-udevd.service | always | 23 |
| /usr/lib/systemd/system/tizen-action-plugin-launcher.service | on-failure | 11 |
| /usr/lib/systemd/system/tizen-watcherd.service | on-failure | 11 |
| /usr/lib/systemd/system/update-manager.service | on-failure | 12 |
| /usr/lib/systemd/system/wifi-tethering-manager.service | on-failure | 13 |
| /usr/lib/systemd/user/scim.service | on-failure | 8 |
| /usr/lib/systemd/user/starter.service | on-failure | 7 |

源码/文件依据见每行的镜像路径:行号，完整unit原文与可覆盖设置保存在本地`sr_unit_inventory.txt`、`vbase_unit_inventory.txt`。重启成本不是一个固定常数，需要后续事件时间线/内存采样；本轮没有测量。

## 15. 播放场景离线组件（4.8）

**镜像确认**，两镜像所列组件一致：

- GStreamer 1.24.11-42，base/good/good-v4l2/bad/ugly/libav及相关库已安装；`/usr/lib/gstreamer-1.0`实际有128个.so，包括libgstplayback、libgstlibav、libgstvideo4linux2、libgstmpegtsdemux、libgstmpegpsdemux、libgsttizenh264enc。RPM数据库与磁盘列表双重核对，完整清单在本地`*_playback_inventory.txt`。
- 可见`/usr/bin/gst-launch-1.0`、gst-inspect-1.0及capi-media-player-utils的player_simple_test、player_test、player_es_push_test等；libmm-player/mmsvc-player/esplusplayer等库/服务包也存在。**未确认**：一个具有固定输入内容、稳定前台生命周期和可重复首帧标记的完整播放器应用，不能用“装了播放库/测试程序”替代播放场景验收。
- K `.config` A:5705–5708/B:5716–5719启用BCM2835与VIDEO_CODEC_BCM2835、ISP；VIDEO_RPI_HEVC_DEC未启用（A:3825/B:3836）。`drivers/staging/vc04_services/bcm2835-codec/Kconfig:1–11`说明其为VCHIQ/VideoCore固件服务上的V4L2 codec；同目录`bcm2835-v4l2-codec.c:605–632`列H.264/MPEG4/MPEG2格式。不能称为已经可用的V4L2 stateless HEVC/H.264解码方案；具体硬件协商、固件能力及GStreamer选中的decoder须以后上板确认。
- INPUT_UINPUT=y（A .config:2631/B:2642）；安装文件清单和磁盘指定路径检查没有evemu-event/evemu-device或通用uinput注入工具。`hid_keyboard`实际归capi-network-bluetooth-test，不能凭名称当成本地按键注入器。**未确认**其他平台私有API的可用性；阶段0a应把标准本地uinput注入小程序列为后续需授权推送/验证的工具，不声称本轮已可注入。
- Home包为`org.tizen.homescreen 1.0.0-1`，源码H。`HomeScreenApp/HomeScreenApp.cs:28–34`在OnCreate开始写`Program OnCreate`，`Common/Resources.cs:22`的tag为HOMESCREEN；这是启动候选标记，发生在Initialize之前，**不是首帧显示完成**。`Manager/ViewManager.cs:60`的wallpaper日志也不是present完成证明。当前源码未找到可直接等价“Home首帧已上屏”的可靠日志；需后续用渲染完成/present或用户视觉证据校准，标为未确认。

## 评审需要修订的v5判断

1. **3.14路径A不成立**：MGLRU开启时v1软限制回收入口直接返回；只写soft_limit不能实现所述偏向。
2. **3.10.1权限有误**：本树process_mrelease无PTRACE_MODE_ATTACH检查；跨进程madvise和pagemap另有各自权限。发信号后是否已进入退出状态仍须处理竞态。
3. **3.11部分正确**：4KiB逐页解压后同步写、无批处理成立；常规读回是异步子bio，“同步读取”应限定路径；writeback_limit不是每小时限速器。
4. **3.5.3版本套用有误**：本树folio_update_gen不总是只设referenced，也没有新版lru_gen_set_refs；回移植收益与上下文必须重新验证。
5. **3.15现状需补齐**：已有应用/服务memcg限制、128MB服务应用设置与22项unit上限；MemoryHigh在本systemd的v1模式无效，不能与MemoryMax混称。
6. **3.13及4.8不能当成已具备**：freezer插件未安装；播放器场景、通用输入注入和Home首帧标记仍待验证。

所有结果为盘点与评审依据，没有实现上述方案。完整私有版本对照、带行号源码摘录、两镜像清单、命令/退出码、上游查询与清理记录只放本地纯文本审读目录，不打包。
