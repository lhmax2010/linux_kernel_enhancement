# 任务8：实验内核构建与部署准备

日期：2026-11-03。仅在开发机读取公开源码、同次QB仓库元数据及既有证据，执行版本字符串计算和spec解析。未连接开发板、未触发Quickbuild、未推Gerrit、未完整构建内核；没有读取或使用vendor_local内的资料。linux-rpi保持`0fac5de6a63091d141ad1cd3ed9d9e92b8dde708`且工作区干净。

## 1. 结论与授权更新

六个指定树外模块均已找到：二进制提供包是`linux-tizen-modules-rpi4-11.0.0-0.armv7l.rpm`，其构建源码包是`linux-tizen-modules-11.0.0-0.src.rpm`；真正模块C源码由另一个`linux-tizen-modules-source-11.0.0-0`包提供。两者不是同一个源码仓库。来源以QB1211696的固定提交、同次发布元数据、RPM及源RPM交叉确认，没有拿现在的主线代替当时版本。

`make kernelrelease`已验证普通版精确输出`6.12.80-arm-rpi4-v7l-lko-base01`；RT和第二个后缀的字符串计算也通过。仅生成/计算发布字符串，不代表新zImage、模块或ABI已验证。部署容量按任务7实测：每套版本目录约4,424 KiB，保留原厂再增加两套后约余5,800 KiB，初步足够；新产物需在任务9实测后再决定部署。

RULES已按PM原文补充：第5项说明重启后根分区默认ro，所有授权范围内根写入须先remount rw、结束恢复ro并回读；第10项授权实验时stop及mask --runtime显示服务、记录前后状态并在结束unmask --runtime回读。本次只登记，没有执行任何板上命令。根ro依据：[任务7 r6的03_display_inspect](../evidence/task7/r4/03_display_inspect.transport.txt)；本阶段不做图形场景，RPi4启动比较不包含窗口管理器启动。

## 2. 六个模块的来源及核验链

### 2.1 固定源码与包版本

| 用途 | 源码项目 / 固定提交 | 版本 / spec |
|---|---|---|
| 按目标内核构建、安装并打包.ko | platform/kernel/linux-tizen-modules @ `36d0925699ac0ffc1ce3854ed838a48d24a56c28` | 11.0.0-0；packaging/linux-tizen-modules.spec |
| C源码、Kbuild及公共头文件 | platform/kernel/linux-tizen-modules-source @ `25797e8af7ed95a5783bbe84c11959560aaf7e92` | 11.0.0-0；packaging/linux-tizen-modules-source.spec |

公开Git地址分别为[linux-tizen-modules](https://review.tizen.org/git/platform/kernel/linux-tizen-modules.git)和[linux-tizen-modules-source](https://review.tizen.org/git/platform/kernel/linux-tizen-modules-source.git)。HTTPS gitweb本轮返回403，因此使用已有SSH身份只读fetch这两个**确切提交**，没有push。仓库、浏览链接和SHA记录在[source_provenance.json](../evidence/task8/source_provenance.json)。

二进制包的[primary摘录](../evidence/task8/primary_selected.xml.txt)、[filelists摘录](../evidence/task8/filelists_selected.json)与[RPM查询](../evidence/task8/modules_rpm_metadata.txt)一致。元数据压缩文件和解压内容的SHA-256均与repomd对应值相等；两个二进制RPM的SHA-256又与primary一致。[元数据校验](../evidence/task8/metadata_hashes.json)、[RPM校验](../evidence/task8/rpm_metadata_checksums.json)、[下载URL与哈希](../evidence/task8/downloads.json)、[包括源RPM的哈希](../evidence/task8/downloaded_rpm_hashes.json)。源RPM spec比Git原文仅多一条构建系统注入的VCS字段，去掉这一行后逐字相同；不是未经解释的源码漂移。[比对](../evidence/task8/srpm_spec_comparison.json)。源码二进制包所载所有普通源文件也与固定Git提交逐字相同。[文件哈希与比对](../evidence/task8/source_payload_comparison.json)。

以下路径均相对`/lib/modules/6.12.80-arm-rpi4-v7l/`；板上`/lib -> usr/lib`，实际落在module_a。每一行的打包者均为上面的linux-tizen-modules，C源码提供者均为linux-tizen-modules-source。

| 模块 | RPM所载文件 | source仓库位置 | 选择入口 |
|---|---|---|---|
| kdbus | extra/kdbus/kdbus.ko | kernel/kdbus/ | BUILD_kdbus=m |
| logger | extra/logger.ko | kernel/logger.c | BUILD_logger=m |
| dm-bow | extra/dm-bow.ko | kernel/dm-bow.c | BUILD_dm_bow=m |
| inform-reboot | extra/inform-reboot.ko | kernel/inform-reboot.c | BUILD_inform_reboot=m |
| extcon-usb-fixed | extra/extcon-usb-fixed.ko | kernel/extcon-usb-fixed.c | BUILD_extcon_usb_fixed=m |
| proc-tsm | extra/proc-tsm.ko | kernel/proc-tsm.c | BUILD_proc_tsm=m |

映射由[source Kbuild:26–40](../evidence/task8/external_kbuild_sources.txt)和[打包spec:254–281、454–501](../evidence/task8/external_module_spec_sources.txt)共同证明；不是仅凭相同文件名猜测。RPM另含`extra/zlogger/zlogger.ko`（BUILD_zlogger=m），任务7未见它加载，但本次不裁剪，准备时一起重编/保留，共7个.ko。[完整RPM文件表](../evidence/task8/modules_rpm_files.txt)。

LLVM GBS buildroot的平台modinfo对7个包内.ko读得相同vermagic：

```text
6.12.80-arm-rpi4-v7l SMP mod_unload modversions ARMv7 p2v8
```

逐文件命令和退出码均为0：[vermagic证据](../evidence/task8/module_vermagic.txt)。它证明这些发布包与旧release字符串相符，不代替板上逐文件哈希或新实验ABI检查；本轮没有连接板子。任务7的RPM数据库查询无归属与镜像制作中安装这些RPM并把模块分区作为文件系统镜像发布并不矛盾；不把“发布包提供这些文件”改写为“板上RPM数据库登记了该包”。

### 2.2 如何取得头文件、版本与符号CRC

1. armv7l下，打包spec:37–41的BuildRequires为`arm-rpi4-linux-kernel-devel`、`arm-rpi4-linux-kernel-modules`及对应`arm-rpi4-rt-*`两包；spec:24还依赖`linux-tizen-modules-source`。这些依赖**没有版本约束**。[spec证据](../evidence/task8/external_module_spec_sources.txt)。
2. source包spec:47–51把模块源文件、Kbuild及include复制到`/usr/src/linux-tizen-modules-source`；打包spec:168再复制到构建目录`./kernel`。[source spec](../evidence/task8/external_source_spec_sources.txt)。
3. RPi构建通过`KERNELDIR=/boot/kernel/devel/kernel-devel-arm-rpi4`或RT目录选择devel树；source的kernel/Makefile:42–49调用`make -C $(KERNELDIR) M=$(PWD) ... modules/modules_install`，不是读取宿主uname。Clang条件分支在打包spec:266–273设置LLVM=1并处理两个不识别的警告选项。[Kbuild](../evidence/task8/external_kbuild_sources.txt)。
4. 内核Makefile:356–357从`include/config/kernel.release`读KERNELRELEASE；外部模块分支:1802使用该值；vermagic.h:42–43把生成的UTS_RELEASE拼入VERMAGIC_STRING。`include/generated/utsrelease.h`、`.config`、`include/generated/*`、`Module.symvers`和对应Kbuild工具必须来自同一次实验内核完整构建。[版本来源](../evidence/task8/kbuild_release_sources.txt)、[vermagic](../evidence/task8/vermagic_sources.txt)。
5. QB最终配置MODVERSIONS=y、MODULE_SIG=n、MODULE_COMPRESS=n；因此匹配字符串只是必要条件，不能改vermagic字符串或目录名冒充重编，符号CRC/配置/ABI也须匹配。[QB配置](../evidence/task5b/qb_arm-rpi4.config)。[内核文档:34–41](../evidence/task8/modules_prepare_limitation.txt)明确：仅modules_prepare不能代替完整构建生成的Module.symvers。新后缀必须先落实到内核，再以新devel树重新构建所有extra模块。

本次还发现：旧QB普通版devel内`localversion-tizen`内容为`-arm-rpi4-rt`，但其`include/config/kernel.release`和`utsrelease.h`仍正确为普通版。这来自spec先完成普通/RT构建、再从共享源码复制devel的布局；以下方案在每个安装循环中重新写入当前target标记，避免把该不一致继续带入新devel。外部模块使用缓存的release/生成头，并不因此自动变成RT；不将这个静态发现说成旧模块已构建错误。[devel一致性证据](../evidence/task8/devel_release_state.txt)。

## 3. modules.img 的实际生产者

同一QB的[镜像包清单](../evidence/task8/qb_image_packages_excerpt.txt)明确列出内核包来自0fac5de6、树外模块来自36d09256。[实际kickstart摘录](../evidence/task8/qb_image_ks_excerpt.txt)第1行为MIC loop打包选项，第12行：

```text
part /lib/modules --fstype="ext4" --size=32 --ondisk=mmcblk0 --active --label modules --fsoptions=defaults,noatime
```

第31–33行选择arm-rpi4-linux-kernel、arm-rpi4-linux-kernel-modules、linux-tizen-modules-rpi4。同次[制作日志](../evidence/task8/qb_image_log_excerpt.txt):1017–1018安装树外模块RPM，1065–1070检查modules.img、记录镜像大小25,133,056 B，并将它与boot.img/hal.img打进镜像tar。这里不是在本机执行这些命令；它们是下载的历史制作日志。

**没有找到独立提供modules.img的RPM或其spec；实际闭合路径是MIC根据KS生成。** 遍历该仓库filelists未见modules.img/module.img提供者，结果见[文件搜索](../evidence/task8/module_image_file_search.json)。相关工具源码/包：

- `platform/upstream/mic@c446578d87b055984e5eeca04e2f485436f55759`，mic 2.1.0-0，`packaging/mic.spec`。其`mic/imager/loop.py:144–167`由分区label产生`<label>.img`和挂载点/大小；:487–521负责检查/处理镜像。[MIC spec](../evidence/task8/mic_spec_sources.txt)、[生成逻辑](../evidence/task8/mic_image_sources.txt)。
- `platform/upstream/image-configurations@c54ac43af03c802e164560fc431509bdad950cfc`，image-configurations 102-1，`packaging/image-configurations.spec`。它依赖meta-generic/meta-common、kickstarter，生成并安装KS，而不是直接产出模块分区镜像。[spec](../evidence/task8/image_config_spec_sources.txt)。本次使用的实际生成KS已下载；其上游meta模板具体文件未继续定位，不猜模板路径。

公开发布目录为[同次boot镜像目录](http://download.tizen.org/RBS/TIZEN/Tizen/Tizen-Unified-Toolchain/tizen-unified-toolchain_20261028.105834/images/standard/tizen-boot-armv7l-rpi/)，[下载与哈希](../evidence/task8/image_downloads.json)。PM已明确不整块重写模块分区，所以任务9无须重跑MIC；只准备新版本目录。历史镜像文件大小、GPT分区大小与板上df可用空间不是同一口径。

## 4. 独立后缀的具体方案（未应用）

目标普通版`6.12.80-arm-rpi4-v7l-lko-base01`，RT对应`6.12.80-arm-rpi4-rt-v7l-lko-base01`。不改上游Version=6.12.80，不改defconfig的`CONFIG_LOCALVERSION="-v7l"`。按setlocalversion:174–208的顺序，release由版本、localversion文件、CONFIG_LOCALVERSION、显式LOCALVERSION和可选SCM部分拼接；LOCALVERSION_AUTO关闭，显式LOCALVERSION防止未设置变量时追加`+`。[源码](../evidence/task8/setlocalversion_sources.txt)。

下面两个diff使用零行上下文（复用时需git apply --unidiff-zero），仅供PM审阅，存为报告文字和temp候选文件；**没有应用到linux-rpi，也没有向任何源码仓库提交**。保留原spec的普通/RT流程，当前验证范围仅armv7l；其他架构分支未构建验证。

### 4.1 内核spec

在%build和%install都显式export LOCALVERSION，使所有make调用一致；modules_install随KERNELRELEASE创建独立目录。安装循环恢复当前target的localversion-tizen；devel目录追加同一后缀，%files使用准确的目标路径，避免匹配其他版本。

```diff
--- a/packaging/linux-rpi.spec
+++ b/packaging/linux-rpi.spec
@@ -11,0 +12 @@
+%define lko_suffix -lko-base01
@@ -161,0 +163 @@
+export LOCALVERSION=%{lko_suffix}
@@ -231,0 +234 @@
+export LOCALVERSION=%{lko_suffix}
@@ -262,0 +266 @@
+    echo "-${target}" > localversion-tizen
@@ -303 +307 @@
-    mkdir -p %{buildroot}/boot/kernel/devel/kernel-devel-${target}
+    mkdir -p %{buildroot}/boot/kernel/devel/kernel-devel-${target}%{lko_suffix}
@@ -327 +331 @@
-	  ./ build/${target}/ %{buildroot}/boot/kernel/devel/kernel-devel-${target}
+	  ./ build/${target}/ %{buildroot}/boot/kernel/devel/kernel-devel-${target}%{lko_suffix}
@@ -330 +334 @@
-    find %{buildroot}/boot/kernel/devel/kernel-devel-${target} -type f \
+    find %{buildroot}/boot/kernel/devel/kernel-devel-${target}%{lko_suffix} -type f \
@@ -353,3 +357,3 @@
-/lib/modules/*%{variant}-v8/
-%else
-/lib/modules/*%{variant}-v7l/
+/lib/modules/%{version}-%{variant}-v8%{lko_suffix}/
+%else
+/lib/modules/%{version}-%{variant}-v7l%{lko_suffix}/
@@ -360,3 +364,3 @@
-/lib/modules/*%{variant}-rt-v8/
-%else
-/lib/modules/*%{variant}-rt-v7l/
+/lib/modules/%{version}-%{variant}-rt-v8%{lko_suffix}/
+%else
+/lib/modules/%{version}-%{variant}-rt-v7l%{lko_suffix}/
@@ -366 +370 @@
-/boot/kernel/devel/*%{variant}/
+/boot/kernel/devel/kernel-devel-%{variant}%{lko_suffix}/
@@ -369 +373 @@
-/boot/kernel/devel/*%{variant}-rt/
+/boot/kernel/devel/kernel-devel-%{variant}-rt%{lko_suffix}/
```

本方案的devel位置为`/boot/kernel/devel/kernel-devel-arm-rpi4-lko-base01`（RT多一个`-rt`）。这是构建root内的开发包路径，**不部署到板上boot_a**；不是把整套头文件搬到板上。

### 4.2 树外模块spec

构建入口指向新devel位置；RPI阶段传同一LOCALVERSION；%files匹配带后缀版本目录；%post的depmod从“find第一个extra”改为准确release，避免并存时索引错误版本。

```diff
--- a/packaging/linux-tizen-modules.spec
+++ b/packaging/linux-tizen-modules.spec
@@ -1,0 +2,7 @@
+%define lko_suffix -lko-base01
+%define lko_kversion 6.12.80
+%ifarch aarch64
+%define lko_ksuffix v8
+%else
+%define lko_ksuffix v7l
+%endif
@@ -255,0 +263 @@
+export LOCALVERSION=%{lko_suffix}
@@ -275,7 +283,7 @@
-make -C kernel clean KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4
-make -C kernel KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4
-make -C kernel modules_install KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4 INSTALL_MOD_STRIP=1 INSTALL_MOD_DIR=extra
-
-make -C kernel clean KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4-rt
-make -C kernel KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4-rt
-make -C kernel modules_install KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4-rt INSTALL_MOD_STRIP=1 INSTALL_MOD_DIR=extra
+make -C kernel clean KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4%{lko_suffix}
+make -C kernel KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4%{lko_suffix}
+make -C kernel modules_install KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4%{lko_suffix} INSTALL_MOD_STRIP=1 INSTALL_MOD_DIR=extra
+
+make -C kernel clean KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4-rt%{lko_suffix}
+make -C kernel KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4-rt%{lko_suffix}
+make -C kernel modules_install KERNELDIR=/boot/kernel/devel/kernel-devel-%{buildarch}-rpi4-rt%{lko_suffix} INSTALL_MOD_STRIP=1 INSTALL_MOD_DIR=extra
@@ -284,0 +293 @@
+unset LOCALVERSION
@@ -398 +407 @@
-RELEASEVERSION=$(basename $(dirname `find /lib/modules -name extra | head -1`))
+RELEASEVERSION=%{lko_kversion}-%{buildarch}-rpi4-%{lko_ksuffix}%{lko_suffix}
@@ -402 +411 @@
-RELEASEVERSION=$(basename $(dirname `find /lib/modules -name extra | head -1`))
+RELEASEVERSION=%{lko_kversion}-%{buildarch}-rpi4-rt-%{lko_ksuffix}%{lko_suffix}
@@ -459,7 +468,7 @@
-%{KMOD_PATH}/*rpi4-v8/extra/dm-bow.ko
-%{KMOD_PATH}/*rpi4-v8/extra/extcon-usb-fixed.ko
-%{KMOD_PATH}/*rpi4-v8/extra/proc-tsm.ko
-%{KMOD_PATH}/*rpi4-v8/extra/inform-reboot.ko
-%{KMOD_PATH}/*rpi4-v8/extra/kdbus/kdbus.ko
-%{KMOD_PATH}/*rpi4-v8/extra/logger.ko
-%{KMOD_PATH}/*rpi4-v8/extra/zlogger/zlogger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/dm-bow.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/extcon-usb-fixed.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/proc-tsm.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/inform-reboot.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/kdbus/kdbus.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/logger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v8%{lko_suffix}/extra/zlogger/zlogger.ko
@@ -467,7 +476,7 @@
-%{KMOD_PATH}/*rpi4-v7l/extra/dm-bow.ko
-%{KMOD_PATH}/*rpi4-v7l/extra/extcon-usb-fixed.ko
-%{KMOD_PATH}/*rpi4-v7l/extra/proc-tsm.ko
-%{KMOD_PATH}/*rpi4-v7l/extra/inform-reboot.ko
-%{KMOD_PATH}/*rpi4-v7l/extra/kdbus/kdbus.ko
-%{KMOD_PATH}/*rpi4-v7l/extra/logger.ko
-%{KMOD_PATH}/*rpi4-v7l/extra/zlogger/zlogger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/dm-bow.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/extcon-usb-fixed.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/proc-tsm.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/inform-reboot.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/kdbus/kdbus.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/logger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-v7l%{lko_suffix}/extra/zlogger/zlogger.ko
@@ -482,7 +491,7 @@
-%{KMOD_PATH}/*rpi4-rt-v8/extra/dm-bow.ko
-%{KMOD_PATH}/*rpi4-rt-v8/extra/extcon-usb-fixed.ko
-%{KMOD_PATH}/*rpi4-rt-v8/extra/proc-tsm.ko
-%{KMOD_PATH}/*rpi4-rt-v8/extra/inform-reboot.ko
-%{KMOD_PATH}/*rpi4-rt-v8/extra/kdbus/kdbus.ko
-%{KMOD_PATH}/*rpi4-rt-v8/extra/logger.ko
-%{KMOD_PATH}/*rpi4-rt-v8/extra/zlogger/zlogger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/dm-bow.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/extcon-usb-fixed.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/proc-tsm.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/inform-reboot.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/kdbus/kdbus.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/logger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v8%{lko_suffix}/extra/zlogger/zlogger.ko
@@ -490,7 +499,7 @@
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/dm-bow.ko
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/extcon-usb-fixed.ko
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/proc-tsm.ko
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/inform-reboot.ko
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/kdbus/kdbus.ko
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/logger.ko
-%{KMOD_PATH}/*rpi4-rt-v7l/extra/zlogger/zlogger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/dm-bow.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/extcon-usb-fixed.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/proc-tsm.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/inform-reboot.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/kdbus/kdbus.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/logger.ko
+%{KMOD_PATH}/%{lko_kversion}-%{buildarch}-rpi4-rt-v7l%{lko_suffix}/extra/zlogger/zlogger.ko
```

这两个diff没有更改RPM包名或NEVRA，因此任务9须使用独立构建root/本地仓库，确保BuildRequires实际解析到**本次生成**的普通/RT devel+modules RPM并核对包哈希，不能使用旧缓存的同名包。也可在任务9明确采用唯一Release以区分构建轮次，但不能假定仅改uname后缀就会改变RPM版本。构建前硬断言新KERNELDIR、缓存kernel.release、utsrelease.h和Module.symvers；不满足就停止。旧的`fullVersion=%{version}_%{buildarch}_%{target_board}`是RPM能力标签，不是运行时uname，不能拿它校验ABI。

### 4.3 depmod 与最终合并目录

内核Makefile:1111的MODLIB为`$(INSTALL_MOD_PATH)/lib/modules/$(KERNELRELEASE)`；scripts/depmod.sh:30–34使用`-b INSTALL_MOD_PATH`并显式传release。[安装路径](../evidence/task8/module_install_sources.txt)、[depmod包装器](../evidence/task8/depmod_sources.txt)。内核modules_install时extra尚未加入，所以其索引不能作为最终部署索引。树外模块RPM的%install只收集.ko和共享配置，不包含最终合并后的完整索引。

任务9在开发机的对应GBS buildroot中，用平台depmod对**新建的合并暂存根**重新生成索引，明确指定完整release；示意（本次未执行）：

```sh
# STAGE必须是WS/temp/task9内新建的暂存根；其中lib/modules包含新版本目录。
# SYSTEM_MAP来自同一次实验内核构建。这里的depmod是对应buildroot平台工具。
depmod -b "$STAGE" -a -e -F "$SYSTEM_MAP" 6.12.80-arm-rpi4-v7l-lko-base01
```

应同时核对Module.symvers/模块CRC及未解析符号；`-F System.map`不是CRC验证替代。最终modules.dep(.bin)、modules.alias(.bin)、modules.symbols(.bin)、modules.softdep等必须覆盖kernel/与extra/两部分。由内核提供的modules.order、modules.builtin、modules.builtin.modinfo等也要保留。板上不安装RPM、不运行RPM脚本；正式部署步骤由PM后续下发。

### 4.4 小型验证与边界

所有输出位于temp/task8/kernelrelease。以已有LLVM GBS root为只读根，经其qemu-arm运行平台make，linux-rpi只读绑定；复制任务4普通/RT的.config和include/config/auto.conf到新的输出目录，写当前target的localversion-tizen。命令核心为：

```sh
make -s -C <只读sandbox源码> O=<WS/temp/task8/kernelrelease输出目录>     ARCH=arm LLVM=1 LOCALVERSION=-lko-base01 -j1 kernelrelease
```

真实namespace/qemu命令和退出码见[普通版](../evidence/task8/kernelrelease_arm-rpi4-lko-base01.txt)、[RT版](../evidence/task8/kernelrelease_arm-rpi4-rt-lko-base01.txt)。结果：

| 检查 | stdout | exit | 耗时 |
|---|---|---:|---:|
| 普通版 | 6.12.80-arm-rpi4-v7l-lko-base01 | 0 | 2.881秒 |
| RT版 | 6.12.80-arm-rpi4-rt-v7l-lko-base01 | 0 | 0.297秒 |
| 普通版第二后缀（仅字符串） | 6.12.80-arm-rpi4-v7l-lko-vbase01 | 0 | 0.292秒 |

无.o生成，源树HEAD/status前后一致，总耗时远低于10分钟。[结果](../evidence/task8/kernelrelease_results.json)、[完整性](../evidence/task8/kernelrelease_integrity.json)。另用同一平台rpmspec --target armv7l -P解析两份temp候选spec，Clang分支也验证了LLVM=1、新KERNELDIR、%files和depmod的展开值：[内核解析](../evidence/task8/rpmspec_kernel_summary.txt)、[模块解析](../evidence/task8/rpmspec_modules_summary.txt)。初次Clang解析因隔离HOME缺toolchain_is宏失败，随后从已有LLVM root复制其原始.rpmmacros到WS内隔离HOME再解析通过；没有伪造宏或修改安装工具。[宏来源](../evidence/task8/rpm_macro_provenance.json)。RPM解包最初因平台cpio不支持-D报错，改用namespace的chdir后成功；原始失败日志保留temp。

未来第二个“类产品基线”的`-lko-vbase01`可用同一后缀机制；本轮只验证字符串，没有叠加任何内部代码。该变体的源码、补丁、提交说明及详细报告必须全部留vendor_local；通用命名方法不豁免保密规则，也不证明内部改动的ABI与干净基线相同。两者都必须各自产出完整devel、内置模块和重编extra模块。

## 5. 部署产物及容量预算

遵循[11中PM审核结论（2026-11-02）](11_board_boot_chain.md#pm审核结论2026-11-02)：不tryboot、不切A/B、不整块刷模块分区；zImage.orig保留原厂，实验映像仍叫zImage。设备树/overlays在本次后缀方案中没有改动，保持原厂文件。ramdisk无带版本号的模块目录，按名字modprobe，适合内核release决定的版本目录。[任务7 ramdisk证据](../evidence/task7/ramdisk_references.txt)。

| 产物 | 板上目标 | 处理 |
|---|---|---|
| 普通版zImage | boot_a（p1）根目录/zImage | 部署前按PM方案备份原厂为zImage.orig并核对哈希；不要用另一个内核文件名启动 |
| 内核树内模块 | module_a（p6）上的/usr/lib/modules/6.12.80-arm-rpi4-v7l-lko-base01/kernel/ | 同次构建、安装时strip的产物，保持目录结构 |
| 树外模块 | 同一版本目录的extra/ | 六个指定模块加zlogger，保留kdbus/、zlogger/子目录；禁止挪用旧vermagic的.ko |
| 索引和内置清单 | 同一版本目录的modules.* | 以完整kernel+extra合并暂存根运行depmod；保留modules.order、modules.builtin及相关元数据 |
| DTB、overlays、boot配置 | 保持原有路径/内容 | 当前变体未改设备树，不部署新DTB/overlay，不改cmdline/config.txt |
| devel、Module.symvers、System.map、vmlinux、.config | 开发机保留 | 用于重编/核验；不占用板上小容量模块分区；build/source开发链接不作为运行依赖 |

`/usr/lib/modules/modprobe.d/tizen-modprobe-rpi4.conf`与`/usr/lib/modules/modules-load.d/tizen-modules-rpi4.conf`在版本目录**之外共用**。任务7 r3的[实际读取](../evidence/task7/10_readonly_finish.transport.txt):1–11与RPM文件表、spec:352–361一致。前者设置proc-tsm选项，后者加载dm-bow、extcon-usb-fixed、inform-reboot、logger、kdbus；本阶段不改这两份共享配置。原厂目录保持完整，不用新版本索引覆盖原厂索引。

容量仅按任务7[板上df/du](../evidence/task7/03_modules_initial.transport.txt)估算，不是新构建实测：

| 项目 | KiB |
|---|---:|
| 原厂版本目录（每套估算依据） | 4,424 |
| 其中kernel / extra | 3,428 / 328 |
| 其余索引、目录等差额 | 668 |
| 当前Available（已经保留原厂） | 14,648 |
| 再加干净基线+第二基线两套 | 8,848 |
| 三套总占用估算 / 增加两套后Available | 13,272 / **5,800** |
| 纯算术再容纳三套新目录，即连原厂共四套后的余量 | 1,376 |

**原厂+干净基线+第二基线三套，按当前每套大小估算够用。** 纯算术上可再加3套（总4套），但只剩1,376 KiB，不作为建议容量；实际模块、BTF、strip方式、索引、文件系统分配及新增驱动均可能改变体积。空闲inode8,054也需部署前复核。宿主同次RPM解出的extra目录du为288 KiB，与板上328 KiB不一致；未做板上逐文件哈希/块分配比对，不据此减小预算，仍用板上较大值。[宿主du](../evidence/task8/external_modules_disk_usage.txt)。df与du的旧差异不强行归因；模块空间充足也不替代boot_a备份和空间检查。

## 6. 已搜索位置、未找到项与限制

- 已核对：任务5b既有RPM/公开目录索引、任务7模块/ramdisk/容量证据、linux-rpi跟踪文件、同次仓库primary/filelists及二进制/源RPM、两个固定模块Git提交、同次boot镜像KS/包清单/制作日志、MIC与image-configurations的固定提交/spec。[本地搜索记录](../evidence/task8/local_source_search.txt)。没有遍历或读取vendor_local。
- 六个模块来源没有“未找到”项；zlogger也有同包来源。独立modules.img提供RPM/spec**未找到**，现有证据明确由MIC+KS生成；不能杜撰另一个模块镜像源码包。
- 未定位生成KS的上游meta-common具体模板文件；实际发布KS已取得，足以确认本镜像的分区与包选择。HTTPS gitweb访问失败有记录，改用同一公开项目的只读SSH fetch；首次repodata请求漏了packages/得到404，修正后全部校验通过。
- 未构建新内核/树外模块，未验证新符号CRC、加载结果或实际新目录体积；这些属于任务9及后续部署。没有连接现在线上的产品板；RPi4接回后才可能按PM后续任务做部署验收。

## 7. 任务9建议步骤与预计耗时（未执行）

1. 固定干净源码0fac5de6及两个模块项目提交，在独立本地实验副本应用经PM审阅的spec调整。普通/RT均保持本轮后缀规则，保留来源、diff、配置和包哈希；不推Gerrit、不触发QB。使用独立构建root/输出目录，避免旧同NEVRA包混入。
2. 先构建LLVM armv7l内核及其modules/devel RPM，沿用受控资源规则和工作区HOME/GBP配置隔离；每次构建检查本次进程组、完整日志末尾/退出码和工作区外写入。默认仍按原spec构建普通+RT；若要删去RT或perf等步骤，另行评审，不能沿用本次耗时估计。
3. 把本次内核devel+modules RPM放入专用本地依赖仓库，显式核对实际解析的RPM哈希和新devel路径，随后重编linux-tizen-modules（source包使用已固定11.0.0-0源文件）。验证普通/RT各自所有7个.ko的vermagic和符号CRC，不能跨变体混用。
4. 解包普通版kernel/modules及对应树外模块到WS/temp/task9的合并暂存根，生成最终depmod索引；核对System.map/Module.symvers、modules.dep(.bin)涵盖extra和kernel，检查未解析符号、包文件列表、所有哈希、strip状态与精确du/inode预算。此步不安装到板上。
5. 交付zImage、完整新版本目录、来源/编译器/配置/哈希清单、回退包及容量结论，由PM确认后另行下发部署。板上用户态、共享模块配置、DTB/overlays、启动参数保持原状；不把本任务作为部署授权。

耗时仅估算：依赖准备约5–15分钟；按任务2同类LLVM普通+RT构建实测36分50秒，内核阶段预留35–60分钟；树外模块重编预计3–10分钟（未实测）；解包、索引、ABI/哈希/容量核对约10–20分钟。缓存正常时总计约**60–100分钟**，冷缓存、网络和其他任务负载可能更久。这是开发机构建准备估计，不是板上启动或运行性能。
