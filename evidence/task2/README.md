# 任务2交付证据

**发布未完成：本轮git push认证失败，以下raw链接当前仍是旧版本或尚不存在；请使用本地文件。**

最新：任务2续二已完成HOME源码审计、工作区配置准备和不依赖构建产物的静态部分；因当前代理不能重设HOME，未运行导出/构建，不是构建成功报告。此前阶段证据保持原样。

- [HOME审计及执行限制](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/home_source_audit.md)
- [LZ4合入检查](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/lz4_merge_check.txt)
- [ARM32元数据计算](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/zram_metadata_calculation.txt)
- [DTS扫描](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/bcm2711_dts_scan.txt)
- 旧build_gcc_log.txt仍是先前exit143的完整日志，不能当成本轮结果；旧配置隔离替代方案已被PM否决。

## 文档与快照raw链接

- [docs/RULES.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/RULES.md)
- [docs/STATUS.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/STATUS.md)
- [docs/01_kernel_inventory.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/01_kernel_inventory.md)
- [docs/02_gerrit_overlap.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/02_gerrit_overlap.md)
- [docs/03_baseline_build.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/03_baseline_build.md)
- [docs/04_zram_static.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/04_zram_static.md)
- [docs/05_kernel_fdo_static.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/docs/05_kernel_fdo_static.md)
- [code_snapshots/INDEX.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/code_snapshots/INDEX.md)
- [code_snapshots/563c53c427bf/mm/memcontrol-v1.c](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/code_snapshots/563c53c427bf/mm/memcontrol-v1.c)
- [config/gbs_gcc.conf](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/config/gbs_gcc.conf)
- [config/gbs_llvm.conf](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/config/gbs_llvm.conf)

## 原始文本/摘要

| raw文件 | bytes | SHA-256 |
| --- | ---: | --- |
| [aapcs32_reference.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/aapcs32_reference.txt) | 415 | `b0a3b345565db376b5f48c336fb6cb78bfdbfcd8977db5643e554f5da5bc31b5` |
| [base_amend_r2.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/base_amend_r2.txt) | 1457 | `ec79fd4d20857b5f36e7d9d89c08902157cd33966a16a5358c6aacb3f4ec621e` |
| [base_commit.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/base_commit.txt) | 995 | `a51d2f03f8799984aaa29864a2d9bcdb02f6f409b9d0c3272d628991c2ea51ac` |
| [base_diff.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/base_diff.txt) | 1601 | `f616a14626c1bb8030fab784f330f307b36a739d3f51f606265c2ead6b2d17b3` |
| [base_diff_stat.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/base_diff_stat.txt) | 105 | `9321a9d6061b3ca2a2fa0d0f470beb80c8f22a7f8e72d782f2933ff0523ae363` |
| [bcm2711_dts_scan.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/bcm2711_dts_scan.txt) | 1330 | `54d6fefd19eaeaba0a1b2ec103551002cbfac8a4ea473b0ceb7b2041ebfbed05` |
| [build_closure_recheck.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/build_closure_recheck.txt) | 875 | `edbc2e0925b1029393ca9106dc7a49c8c8a62e65d18bd02dae1589b416b14500` |
| [build_gcc_last50.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/build_gcc_last50.txt) | 4433 | `72c5809ecd256a0340dfb34a76d56d39b06f87136d3f679dabfdc7a158b4ee9e` |
| [build_gcc_log.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/build_gcc_log.txt) | 48259 | `3157116b9e9b5f8d6822103ff5adf4d4e1b6f2f8fa13ff2dae277bc82bfc401a` |
| [build_gcc_result.json](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/build_gcc_result.json) | 595 | `4f6572af261ef1993d476f1b2135ae795fcc967677ce898f9c52e9e942b2f95e` |
| [build_stop_reason.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/build_stop_reason.txt) | 1169 | `9f739c517e92e332ac21c7a4d659a7425c57d7123b5ad8a10191b5d0382f5c08` |
| [commands.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/commands.txt) | 2350 | `5ee71377d1916acabc30ddcbaf2b52ccf314415ef493cf0ef5d8d9593d6e2c18` |
| [existing_project_gbs_r2.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/existing_project_gbs_r2.txt) | 476 | `320e39b4399778cc7940c05b990a7a6ad0e081ad9e165c3af501f13bdc4c73aa` |
| [external_gbs_keys_r2.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/external_gbs_keys_r2.txt) | 184 | `c6aafcab4dee2b2888e50da9a45799537c1f33a1c4ea692fbfe78cb3e36ca003` |
| [fdo_symbol_search.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/fdo_symbol_search.txt) | 343 | `bf58b41fd67a716d088e2eab5d15a777235393553ed54f2ce57cec13863dc877` |
| [final_kernel_state.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/final_kernel_state.txt) | 218 | `a92ad3e3e8d582a584e4430f224911f18e47368d805b429cd9abfa56c42e7730` |
| [gbs_config_audit_r2.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gbs_config_audit_r2.md) | 9582 | `bbe261daf18f9b3492ece278ce1db91632a4e1aa5ad31c5cdd1d961515b8c352` |
| [gbs_config_source_r2.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gbs_config_source_r2.txt) | 24097 | `895680385a2a7f0802bec1064937edf0b154fa995b1fb8a48ada39566dd82af4` |
| [gbs_export_root_cause.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gbs_export_root_cause.txt) | 6077 | `040ccc1cc5997ae1365f17c45cb0ac14acca11c5c454b442a67e0097b24c0b37` |
| [gbs_tempdir_adjustment.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gbs_tempdir_adjustment.txt) | 1884 | `746d5a6db3cdd13a88da9db46ddd473f70e1b115c3a2132470fca2f162bcf0a4` |
| [gerrit_raw_integrity.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gerrit_raw_integrity.txt) | 289 | `4b7b8a0ba997fdb1baeb18d1c33aaed47b099b78f71f43feb091e88f1628eefe` |
| [gerrit_ssh_queries.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gerrit_ssh_queries.txt) | 668 | `1fb406bd26758e40b61ee6cf1dd1a0ee2926fdc0899438256c134b7c40fb49df` |
| [gerrit_ssh_summary.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/gerrit_ssh_summary.txt) | 3172 | `9f2e4f715f90bbc3d79964a6a516755c670cbef44cc5ae2ac8481d9249f2bb40` |
| [home_preparation.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/home_preparation.txt) | 481 | `533b8c55786bac5bfcdbe932eeffb7cd6b7ecc87dffe8b5dbba5d6a3b161c25f` |
| [home_source_audit.md](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/home_source_audit.md) | 4652 | `a479d4292b0dadb3d6459eb3e2e836b8d1e2be63560879cb958e466aeaec16e4` |
| [home_source_lines.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/home_source_lines.txt) | 15146 | `d46a724c4e1b2d0fd2825f1501c05ad3d9b415e6725c9644c6613a14e68e830b` |
| [home_source_search.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/home_source_search.txt) | 9041 | `552fb0aca4b849807625e733508c97d8e7680b567f9f4361cf871b1c2ea1702a` |
| [initial_state.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/initial_state.txt) | 106 | `2efa94402f0d9eada2df4456e3dc034e6b58a842e5eba44da178b4d90a7cf728` |
| [log_integrity.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/log_integrity.txt) | 280 | `8002db2e281644d1a30460c81d9f34592a812417cf814397ab9c41449ad3aa91` |
| [lz4_merge_check.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/lz4_merge_check.txt) | 7089 | `79940499f5915ebb558b5824e0b9e05fa2bdf2a65b937ae3623259aa2901f6c3` |
| [platform_tools_pending.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/platform_tools_pending.txt) | 219 | `aa4b91efec868d97751b3920b6754124ac472013c3c1be614f38e2f8350611fc` |
| [publication_home_attempt.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/publication_home_attempt.txt) | 420 | `45dc619aa3b254229aa405f57360ccb756a07dfb86289b89bc81516c1dec5d85` |
| [residual_state.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/residual_state.txt) | 462 | `c6df5f38d5127af7d1ba2484d0c6b9f65f0cf3f5bb143054b5df588438fd5bcf` |
| [static_source_lines.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/static_source_lines.txt) | 42156 | `3d59342f258144ab1c4a3a5a3040d5829725a30d11a161380a465a96a7870646` |
| [validation.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/validation.txt) | 608 | `650b7deecef20b2419a568497e27999b318fac5f2ab808749590f58d499956cb` |
| [validation_home_static.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/validation_home_static.txt) | 395 | `35ef2af6a2f314a4ca650839dc6a1c996c7ef873c981e2ce03d1eb6e76064a37` |
| [validation_r2.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/validation_r2.txt) | 711 | `380f036d7a477d71884aee17ea510d8dec08b8bddf55b233e0499e410fc576cd` |
| [zram_branch_config_diff.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/zram_branch_config_diff.txt) | 1486 | `6821b71429f4813048f41f111e33aa19ceae1ca023d3a0292a8a0030b17c7cbd` |
| [zram_metadata_calculation.txt](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/zram_metadata_calculation.txt) | 401 | `1cab4aa21bc58cdd61f401b17922a10949ec0b6a5d64ca5f1cbcb1aff28af339` |
