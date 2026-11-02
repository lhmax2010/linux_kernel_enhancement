# PB1 脱敏证据索引

报告：[13_product_board_probe.md](../../docs/13_product_board_probe.md)。主采集2026-11-02 23:15:41–23:15:52 +0800，补充读取至23:32。只有只读探测，最终uid5001。

- `00_connection_and_commands.json`：初始失败、授权重连与所有逐命令退出码；不含设备列表原始身份文本。
- `01_*`、`r2_identity_os_release.txt`：身份、编译器与脱敏镜像信息。
- `02_*`：配置缺失证据、149项UNKNOWN与RPi最终配置对照、USB类别统计。
- `03_*`：内存/zone/buddy/pagetype/iomem；dmesg仅匹配行且带原文行号；vmalloc按调用者前20、slab按厂商memory_usage前30。
- `04_*`：swap、zram、所有VM参数的逐项返回、PSI、MGLRU、vmstat。
- `05_*`、`06_*`：模块/BTF、文件系统/挂载/容量/USB/分区。
- `07_*`、`08_*`：tracing/profiler限制、CPU/频率/事件源。
- `09_*`：仅代号的进程前20及全体合计；补充负载与CPU活动量，不能作为空闲基准。
- `10_*`：已有开机target时刻、dmesg时间范围（03中）、journal缺失、结束uptime。
- `99_*`：root off/owner核对与发布前脱敏扫描。

每份命令证据的RAW_SHA256指向temp内原始字节，不能拿脱敏文本去验证该哈希。REMOTE_EXIT是外层命令返回；循环内的CMD/RC才是每项读取返回。ENOENT、Permission denied与transport失败分开保留。

原始日志/进程对照/分析脚本均仅在`temp/pb1/`；不入库。匹配真实进程名称的技术字段也以代号替换，可能影响可读性，以报告明确引用的原始数字与接口状态为准。不对产品未知配置作默认值推断。

入库文本另统一删除行末空白和末尾空行；temp原始字节及其哈希不变。
