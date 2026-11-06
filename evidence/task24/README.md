# 任务24离线证据

截至2026-11-06只做开发机核对，未连接或修改开发板。离线验收未通过，原因与边界见docs/24_qb1220056_baseline.md。

- offline_summary.json：白名单式生成的中性结果；不含内部组件名称、配置或日志。
- flashing_checklist.md、archive_checksums.json、partition_images.json：公开归档来源和实测SHA、内部分区用途。
- image_integrity.json：检查后原镜像/只读副本SHA与解包时哈希一致。
- resource_limit_probe.txt、resource_limiter.sh：实际资源约束及统一入口。
- tool_packages.json：固定快照临时ARM工具包的NVR、URL、元数据和下载SHA；只解包未安装。
- browser_cleanup.json、cleanup.json：浏览器会话及临时工具/副本清理记录。

完整命令、输出和退出码因包含内部内容保存在vendor_local/task24/logs/；公共摘要不替代原始证据。工具链路径为任务12构建根，平台命令由vendor_local/task24/platform_tools.py统一经bwrap+qemu-arm执行，并继承外层资源限制。关键原始命令类型：

```text
rpm -qp --qf NAME/VERSION/RELEASE/ARCH/VCS/SOURCERPM <RPM>
debugfs -R 'stat <path>' <image-copy>                  # 无-w
debugfs -R 'ls -p <directory>' <image-copy>
debugfs -R 'dump/rdump <path> <workspace-output>' <image-copy>
rpm --dbpath <exported-db-copy> -qa/-q --qf ...
modinfo -F vermagic <actual-image-module.ko>
modprobe --show-modversions <actual-image-module.ko>    # 不加载
sha256sum <image-original-or-copy>
```

内部完整性/ABI逐项结果、包清单差异、私有元数据基准均在本地审读包中。原SR模块元数据基准保持未改。
