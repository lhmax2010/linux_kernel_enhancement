# QB 1220056 刷机材料清单（离线阶段）

**离线验收未通过，暂不建议刷机开始基线测量。** 两项不符见报告；本清单不构成刷机通过结论。尚未连接开发板。

## 两个归档

### tizen-unified-toolchain_20261105.134728_tizen-boot-armv7l-rpi.tar.gz

- URL：https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261105.134728/images/standard/tizen-boot-armv7l-rpi/tizen-unified-toolchain_20261105.134728_tizen-boot-armv7l-rpi.tar.gz
- 本地完整路径：`/home/linhao/Toolchain/development/linux_kernel_optimization/vendor_local/task24/download/tizen-unified-toolchain_20261105.134728_tizen-boot-armv7l-rpi.tar.gz`
- 大小：28,707,458 B
- SHA-256：`ac024be4b7a1b5401ac041c487c9ebaf038120c1a598c9ebd09b8e0b3e010a40`；与站点校验值一致。

### tizen-unified-toolchain_20261105.134728_tizen-headed-armv7l.tar.gz

- URL：https://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261105.134728/images/standard/tizen-headed-armv7l/tizen-unified-toolchain_20261105.134728_tizen-headed-armv7l.tar.gz
- 本地完整路径：`/home/linhao/Toolchain/development/linux_kernel_optimization/vendor_local/task24/download/tizen-unified-toolchain_20261105.134728_tizen-headed-armv7l.tar.gz`
- 大小：555,272,491 B
- SHA-256：`92eef40309b651d06fdba1202cb57310a187ec496abc410dab13af61bd6c2aaf`；与站点校验值一致。

## 内部分区镜像

下列是本次 XML/KS 的用途与制镜挂载点，不据此擅自指定刷写工具或物理槽位。RPi4 历史运行记录中 `/lib/modules` 对应 `/usr/lib/modules`；boot 通常不常驻挂载，ramdisk 两项是启动加载镜像。

| 归档 | 文件 | 大小 B | 用途/挂载点 | SHA-256 |
|---|---|---:|---|---|
| boot | modules.img | 25,133,056 | modules / `/lib/modules` | `8269d15520527e1e9ab9858eb0a943e22235351f56480e3ffea2cea77d6ab9ec` |
| boot | boot.img | 67,108,864 | boot / `/boot` | `eddc40edee7271c196408b4b66cb5c329abbad88845d2c741b591ea6bd360447` |
| boot | hal.img | 107,610,112 | hal / `/hal` | `3492acfe1785fa106948de8bd6589029fbe71db53ace08e2d8767734fc7a8f1e` |
| headed | system-data.img | 69,980,160 | system-data / `/opt` | `2c93a32a2d366332ed61ae915bd7fa5e22349f3b8eb5984eadbbe9506220e8e8` |
| headed | user.img | 524,288,000 | user / `/opt/usr` | `e4a209b84376271477e6ed487422a8469d5fd9d22d6b600c9e54397ea337f591` |
| headed | rootfs.img | 1,240,371,200 | rootfs / `/` | `4d633fcc181cc4902ca1a75d47196a5ace8e97dce1707e187789e43b542a13f6` |
| headed | ramdisk-recovery.img | 13,448,355 | ramdisk-recovery / `/mnt/initrd-recovery` | `bc935d04b698f6f55b81a91bcdd2a832b490e0f5fa4d773dc2080cba4a5f065b` |
| headed | ramdisk.img | 7,632,978 | ramdisk / `/mnt/initrd` | `e888b812a9de2a70ce5e0dd287041ac25f384b7317b5d477aadd33ead0c575b9` |

所有8个img的哈希来自平台Python流式遍历已验站点SHA的归档。5个img另行解出，debugfs仅打开副本；原件检查前后SHA一致。

## 后续门槛

先由PM处理离线验收不符项。用户明确回复“已刷好”后，才可开始B0；先只读断言身份、BUILD_ID及图形组件状态，再按批准流程准备。板子准备不卸载coregl、HAL mesa或wlandrv-plugin-tizen。B1–B3及审读包运行时部分尚未执行。
