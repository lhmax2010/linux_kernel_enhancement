# 任务25：制镜服务准入规则的只读核对

2026-11-06。仅分析源码、既有镜像副本并编写方案；未改源码或镜像、未连板、未构建、未推 Gerrit、未调用 sudo 或发送信号。具体内部服务的权限表、方案 diff 与审读包只保存在本地 `vendor_local/task25/`。

## 1. 结论与来源

**这项检查不是“禁止 root 服务”，而是服务身份组合的允许名单检查。** 非 root、显式 SMACK 标签或 capability 声明，都不能替代名单登记。名单匹配之外，还单独禁止 `Exec*=` 使用 `+`、`!`、`!!` 前缀。

核对对象：`platform/core/security/security-config`，提交 `1e550298b147a50f85e188dff15b2c457262c324`。通过现有 SSH 只读拉取；镜像中的 service CSV 与此提交逐字相同，按 COMMON 生成的 service list 也逐字相同。源码原行号见 [规则证据](../evidence/task25/rule_source_excerpts.txt)，来源见 [source_identity.txt](../evidence/task25/source_identity.txt)。

| 环节 | 准确行为 | 源码位置（均为上述提交） |
|---|---|---|
| 安装路径 | `/opt/share/security-config/test` 是指向 `/usr/share/security-config/test` 的链接 | `packaging/security-config.spec:101–106` |
| 顶层入口 | `image_test.sh` 调用新服务检查，再把 service/socket/D-Bus 失败日志汇入总日志 | `test/image_test.sh:69–86`；`test/new_service_test/check_new_service.sh:14–29` |
| 扫描范围 | `/usr/lib/systemd/system/`、`/etc/isu/*/system-services/` 的普通 `*service` 文件；不是完整 systemd 配置合并器 | `check_systemd_service.sh:58–62`；`systemd_test_util:8–17` |
| 身份提取 | grep `User=`、`Group=`、`SmackProcessLabel=`；含 `#` 的行剔除。缺 User/Group 分别按 root；缺标签为空 | `check_systemd_service.sh:14–29,60–62` |
| 名单判定 | 有 `[Service]` 时查 `;basename;user;group;smack;`；无该段的特殊 unit 不追加标签字段 | `check_systemd_service.sh:27–37` |
| 额外限制 | `^Exec[a-zA-Z]*=[!+]` 命中即记录并隔离，不因名单存在而豁免 | `check_systemd_service.sh:44–52,72–73` |
| sockets | 另查 socket 名、SocketUser/Group/Mode、SmackLabelIPIn/Out；不是 service 的身份 tuple | `check_systemd_socket.sh:11–19,69–90` |

service 匹配用普通 `grep`（正则、未锚定），socket 用 `grep -F`；本文静态复核调用平台对应 grep，未把它美化为严格解析器。不得利用正则、改名套用既有服务或 Exec 前缀绕过登记。service 的缺 Group→root 是**检查器规则**；真正 systemd 在显式 User 而缺 Group 时通常用该用户的主组，两者不可混淆。

## 2. 名单文件及隔离副作用

源文件：`test/new_service_test/systemd_service.csv`。格式为：

```text
SERVICE_NAME,USER,GROUP,SMACK,COMMON,TV,COMMON_EMUL
```

profile 位为 `1` 才输出到安装后的 `systemd_service.list`，每行 `;服务名;用户;组;标签;`。`create_list.sh:7–19,32–46` 处理 profile/模拟器；`security-config.spec:106,114,122` 分别在 post 中调用 COMMON/TV。要修改 CSV 并重编相应包，不能只改临时生成的 `.list`。本镜像为 profile_common。

失败后，`systemd_test_util:21–28` 将 unit **移动**到 `/opt/share/security-config/not_permitted_service/<basename>`；写失败路径日志和 `NO` 结果标记（56–65）。它不卸载 RPM，不删除 wants 链接，也不是启动服务后的权限测试。于是 RPM 查询仍可能显示安装正常，但正常 unit 已缺失、wants 链接悬空。重新运行检查前，`init_test:33–51` 会按旧日志恢复被隔离的 unit，再清旧结果。

顶层还运行 ASLR、DEP、路径及文件 capability 等其他测试；最后删测试 utils（`image_test.sh:89–91`）。这条调用链没有把名单失败强制变成制镜命令非零退出，因此 **QB Successful 不等于安全检查全部通过**。本次未执行原始安全脚本，避免它的移动/删除行为。

## 3. 已有服务为什么通过

从 QB1220056 rootfs 的只读副本取 unit，按同一 grep 判定复核，三个均匹配且没有被禁的 Exec 前缀。原文见 [approved_units.txt](../evidence/task25/approved_units.txt)，[判定结果](../evidence/task25/public_unit_predicates.json)。

| unit | 实际/缺省 User、Group、SMACK | CSV 行 | 能力说明 |
|---|---|---:|---|
| resourced.service | root、root、System | 171 | 无 User/Group，由 systemd 按 root 执行；仍是明确登记的组合 |
| stability-monitor.service | stability_monitor、stability_monitor、System | 192 | `Capabilities=cap_sys_ptrace,cap_sys_module,cap_kill=i`，`SecureBits=keep-caps` |
| connman.service | network_fw、network_fw、System | 52 | 声明网络相关 inheritable capabilities 及 DAC override，保留 keep-caps |

另核实同批通用失败项：privilege-checker-integrity、systemd-boot-system-token、systemd-bless-boot、amd-tizen-action-service 对应身份不在生成名单中。**tizen-watcherd.socket 有不同原因**：源 `systemd_socket.csv:70` 的最后一行存在正确记录，但没有末尾换行；`create_list.sh:40` 的 `while read` 没有处理 EOF 残行，漏掉它。平台 bash 仅重放读取/生成片段，结果与镜像 socket list 逐字相同；该行确实缺失。见 [socket_eof.json](../evidence/task25/socket_eof.json)。本任务没有修复这个独立问题。

## 4. set_capability 与最小权限的关系

`config/set_capability` 是制镜时调用的授予脚本：逐个检查可执行文件是否存在，再用 `/usr/sbin/setcap` 写文件 capability。ConnMan 在 187–192 行，stability-monitor 在 712–720 行。后者为 `cap_sys_ptrace,cap_sys_module,cap_kill=ei`。

`=ei` 是文件 inheritable 集合及 effective 标志，不是直接把 permitted 集合赋给所有调用者。它与 unit 的进程 inheritable 集合配合，exec 时才得到相应 permitted/effective 能力。`test/capability_test/check_new_capabilities.sh:35–44,98–124` 另按 set_capability 的 `# Required 路径 : 能力 : 选项` 注释生成期望清单，并对实际 getcap 结果比较。若采用新增文件 capability 的方案，授予与期望记录需一起审核；service 名单本身并不检查能力是否足够。

镜像对应 systemd 提交 `317f5070936f11bea121e1f9fa6c16492b520902` 支持 `AmbientCapabilities=`、`CapabilityBoundingSet=`；`src/core/execute.c:3648–3657` 在降权前设置 SMACK，3680–3735 保留并重建跨 UID 的 ambient 能力。非 root 服务可按具体操作选最小集合，而不必给全局公用工具加文件能力。DAC、Linux capability、SMACK、D-Bus/Cynara 是不同检查层；通过其中一层不表示其他层通过。

## 5. 两种方案的共同前提与建议

- **非 root 方案**：专用系统账号、按 unit 限制 capabilities、明确 SMACK 标签，并在 CSV 登记新的身份组合。还必须核对程序自身是否硬编码 root、跨进程访问的 MAC 规则、用户态权限策略。详细 diff 和仍需运行验证的条件只保存在本地报告；未宣称静态分析能证明运行等价。
- **保留现有身份方案**：仅为两个精确服务 tuple 增加 COMMON 的允许记录，TV/COMMON_EMUL 不放开，不关闭安全测试、不放宽其他服务。需 security-config 的独立内部 sandbox 和 QB 包来源调整；本轮未创建分支或推送。

针对基线对比，建议先采用第二种方案：变量更少，可以保持既有身份和行为；非 root 方案适合另立权限收敛实验。两者都仍须制镜日志、正常 unit/wants 路径及后续运行验收，不能仅凭本次 predicate 匹配宣布部署成功。

PM 本轮明确：wlandrv-plugin-tizen 不在镜像包清单中，不再作为该镜像必需项，任务24这项挂账关闭；服务准入问题尚未实施修复。

## 6. 执行边界与留存

下载、解包、平台 qemu/debugfs、数据库读取和大文件哈希均经 `systemd-run --user --scope -p CPUQuota=400% -p MemoryMax=8G nice -n 10 ionice -c3`；不超过4项并行、未并发大文件解包。临时 ARM 工具取自固定 base `20261030.120529`，先核对仓库 SHA，再 rpm2cpio 解包，未安装、未写 GBS 根。工具包来源见 [tool_packages.json](../evidence/task25/tool_packages.json)、[ffi_package.json](../evidence/task25/ffi_package.json)。只读镜像分析使用副本，原件哈希与任务24记录核对，收尾删除本任务工具和镜像副本；见 [清理与完整性](../evidence/task25/integrity_cleanup.json)。

详细权限表、完整提案、源码片段、静态重放和未知项见本地 `vendor_local/task25/TASK25_REPORT.md`；审读包 `vendor_local/task25/TASK25_REVIEW.tar.gz` 不入库。仅本公开报告、Tizen 通用证据及 STATUS 推送 GitHub main。
