# rw且无noexec的全部挂载点

筛选自03_mounts.transport.txt的/proc/mounts：选项含rw且不含noexec。此列表不等于每一项都适合写入；未选根文件系统、设备/伪文件系统或既有用户目录。

| 挂载点 | 来源 | 类型 | 本次选择 |
|---|---|---|---|
| `/dev` | `devtmpfs` | devtmpfs | 未使用 |
| `/` | `/dev/mmcblk0p2` | ext4 | 未使用 |
| `/opt` | `/dev/mmcblk0p3` | ext4 | 未使用 |
| `/hal` | `/dev/mmcblk0p10` | ext4 | 未使用 |
| `/proc/sys/fs/binfmt_misc` | `systemd-1` | autofs | 未使用 |
| `/mnt/inform` | `/dev/mmcblk0p9` | ext4 | 未使用 |
| `/opt/usr` | `/dev/mmcblk0p5` | f2fs | 选用：独立F2FS数据分区 |
| `/opt/media` | `tmpfs` | tmpfs | 未使用 |
| `/dev/usb-funcs/sdb/default` | `sdb.default` | functionfs | 未使用 |
| `/dev/usb-funcs/mtp/default` | `mtp.default` | functionfs | 未使用 |
| `/opt/usr/home/owner/media` | `/dev/mmcblk0p5` | f2fs | 未使用 |
| `/opt/usr/home/owner/subsession/__templ_acct_fix__` | `/dev/loop0` | ext4 | 未使用 |
| `/opt/usr/home/owner/subsession/__templ_prof_fix__` | `/dev/loop1` | ext4 | 未使用 |

选定/opt/usr（/dev/mmcblk0p5），根文件系统/则为/dev/mmcblk0p2。/opt/usr不是符号链接；父目录UID:GID=0:0、权限0755，专用目录原先不存在，新建后UID:GID=0:0、权限0777、SMACK标签User::Shell（继承创建环境，未改安全策略）。
开始df：总116404224 KiB，已用983204 KiB，可用115421020 KiB；空间足够。仅写/opt/usr/lko_task5c。
