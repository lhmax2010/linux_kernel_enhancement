# SR 基线出镜像说明

任务16已核实并推送配套resourced源码；本任务不触发Quickbuild、不部署镜像。SR基线由固定内核提交和配套resourced修复组成，不能仅选择内核sandbox分支的最新值。

## 1. 固定源码来源

|组件|项目|分支|必须使用的提交|
|---|---|---|---|
|内核|`platform/kernel/linux-rpi`|`sandbox/lhmax2025/kernel_optimization`|`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`|
|resourced|`platform/core/system/resourced`|`sandbox/lhmax2025/kernel_optimization`|`94d346c306233803661e8eab8557596549d82be4`|

**内核分支最新提交已是类产品基线，SR必须显式指定0fac5de6，不能取branch tip。** 该固定提交包含force_reclaim修复和PMU配置，与QB1211696的内核源码一致，release为`6.12.80-arm-rpi4-v7l`，不含本地实验后缀。来源依据：[08](08_sandbox_baseline.md)、[09来源闭合](09_board_rpi4_readonly.md)、[本次resourced推后核对](../evidence/task16/remote_after.txt)。

resourced基于tizen `82e79c09ea80c1977dfb27d3752577c74340f9bc`的九个修复，任务15已构建及执行新增测试；任务16helper核对未改源码。说明与边界见[17第5节](17_resourced_fix.md#5-pm-审核任务16)。

## 2. 构建与镜像包选择

基于上述resourced提交重新构建，替换镜像中以下五个包，保持同一构建的配套关系：

- `resourced`
- `resourced-bin`
- `resourced-config`
- `resourced-isu`
- `resourced-watchdog-handler`

任务15本地产物Version-Release仍为10.0.0-1，**只看版本号不能区分新旧修复**。出镜像时保存BUILD_PKG_LIST中的源码SHA、实际RPM文件名/NVR、SHA-256和镜像manifest；不要把镜像构建的RPM哈希强行等同于本地构建哈希。旧新载荷差异见[任务15包对比](../evidence/task15/rpm_file_comparison.json)。

`linux-tizen-modules`沿用QB1211696/对应仓库的现成配套包；固定内核源码与当前镜像相同，此SR方案无需为内核语义变更重编该包。此结论不适用于类产品基线或其他内核SHA/配置/版本后缀；不能误用本地base01/vbase01的模块RPM。

## 3. 上板后首先核对（后续任务执行，本轮未执行）

1. 核对镜像来源manifest、内核SHA；`uname -r`应为`6.12.80-arm-rpi4-v7l`，记录`/proc/version`。uname相同本身不能证明源码相同。
2. 查询上述五个resourced包的实际版本并与镜像包清单、构建源码SHA及RPM哈希链核对，确认不是仍使用旧10.0.0-1。
3. 读取resourced启动日志和zram的`comp_algorithm`。SR内核只有LZO后端，配置请求zstd不可用时应记录保留内核选中算法（默认lzo-rle），不能再硬编码尝试不存在的lz4。
4. 读取`/proc/swaps`及swap相关日志，确认实际开启状态与日志一致；不能仅凭SWAP_ON标志判成功。
5. 在另行安排的受控回收验证中核对`memory.force_reclaim`写入成功/错误传播及swap行为，保留write返回值与errno；用户态成功返回通常是写入字节数，内核回调0经cgroup分派转换，不能要求用户态write返回0。单次提交、不重试短写；正返回不代表回收页数已被准确量化。

第5项会触发回收，本说明不是对产品板执行写操作的授权。本轮仅提供镜像准备与验收清单，没有触发构建、改板上状态或执行回收。
