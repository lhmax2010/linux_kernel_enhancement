# 任务2交付证据

最新：2026-10-28用户启动e028a072后，export/GCC/LLVM全部成功；日志封存、实际编译器、四配置、大小与ACTIME布局已核验。05明确平台llvm-bolt/create_llvm_prof缺失，BOLT架构无法实测。详见03及STATUS。历史失败/离线审计证据保留。

- [用户执行脚本](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/scripts/run_baseline_build.sh)
- [正常环境补发结果](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/publication_r3_initial.txt)
- [sudo源码核对](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/sudo_call_audit.txt)
- [静态语法验证](https://raw.githubusercontent.com/lhmax2010/linux_kernel_enhancement/main/evidence/task2/script_static_validation.txt)
- 旧认证失败、旧GCC中断、之前未构建记录保留作历史证据，不代表本轮构建结果。

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

以下清单为本目录全部证据文件（不含本索引自身）；每个文件均为UTF-8文本且小于1 MB。完整trace、日志、ELF、RPM和构建目录留在工作区temp。`completed_*`为本次成功运行封存，旧attempt/validation记录按文件名对应历史尝试。

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| [aapcs32_reference.txt](aapcs32_reference.txt) | 415 | `b0a3b345565db376b5f48c336fb6cb78bfdbfcd8977db5643e554f5da5bc31b5` |
| [actual_config_source_lines.txt](actual_config_source_lines.txt) | 2512 | `a673d046a74361d015d7a7b5e26b1445e205bc8c803ff3b95d5fea07b92055f7` |
| [artifact_identity_and_source_state.txt](artifact_identity_and_source_state.txt) | 6039 | `7cb032eb3142cf45615faa467a4b1bdf0cf74c956a1c0fc3ae0b6762187ef102` |
| [artifact_measurements.txt](artifact_measurements.txt) | 11039 | `7a8fe14f9a02d07d3ccd351ec5a0ab49ae350c35b8c899834978ab6e11e5d93a` |
| [artifact_review_validation.txt](artifact_review_validation.txt) | 1281 | `b937f01487be7fbe3ef2cb65b21650beb924d8e0e480f0aafbd2e6a614762ac7` |
| [attempt_1801_archive.txt](attempt_1801_archive.txt) | 3961 | `f3ecf3e9d89df7250225379af9663698c5c22e178df5b08de4867d7490b0e611` |
| [attempt_2041_archive.txt](attempt_2041_archive.txt) | 4294 | `fb3048a113b7805275992494baaa0bfe68ba612266667eee9af8e6750ed85345` |
| [audit_fixture_results_r6.md](audit_fixture_results_r6.md) | 2508 | `1215db5e0e502fa54b28e44d4b11be9cd2846b76ee1c649f6edcf19b76cb2fd8` |
| [audit_fixtures_r6/01_external_file_write.trace](audit_fixtures_r6/01_external_file_write.trace) | 478 | `60f06ba4adcefaa237a6a76292a172a7c539465c8ecfcb99d70621dbcec9782a` |
| [audit_fixtures_r6/02_dev_zero_write.trace](audit_fixtures_r6/02_dev_zero_write.trace) | 436 | `c2bf0705fb33e685147312637db5d3b6f0484a71dec5830a42c98854a4184404` |
| [audit_fixtures_r6/03_dev_null_wrong_device.trace](audit_fixtures_r6/03_dev_null_wrong_device.trace) | 436 | `17068eea3c0739311310e71318cd666d436195b95c5b666c9ac4e6254b4c3f50` |
| [audit_fixtures_r6/04_external_gbp_config.trace](audit_fixtures_r6/04_external_gbp_config.trace) | 480 | `a5788e4d5c6d7202c6dd2dc7966c521c2cbc584f5ca17514b0e70c02c3ec4382` |
| [audit_fixtures_r6/05_external_mkdir_success.trace](audit_fixtures_r6/05_external_mkdir_success.trace) | 348 | `6424ce87ac791b06c047d87e5dfb63885de9adcac064109547650ffd58413f8d` |
| [audit_fixtures_r6/06_external_mkdir_eexist.trace](audit_fixtures_r6/06_external_mkdir_eexist.trace) | 370 | `c57dce6fda66c7276715163895cee163141598c246e3d0ae7068d2ab928fe417` |
| [audit_fixtures_r6/07_tmp_readwrite.trace](audit_fixtures_r6/07_tmp_readwrite.trace) | 416 | `22638566cd02b082e86eace3541177b374ef1c5ef5eccf388a2cd66ebe481379` |
| [audit_fixtures_r6/08_split_external_write.trace](audit_fixtures_r6/08_split_external_write.trace) | 511 | `617f2b2c4d2fb003c31d8f7c5d019137601fac9cc875fccf23baa9bbf7488110` |
| [audit_fixtures_r6/09_split_allowed.trace](audit_fixtures_r6/09_split_allowed.trace) | 440 | `a285ef5a22026833f31b25edc35eeef5ee151f50c5d5e041f6833f6a74008214` |
| [audit_fixtures_r6/10_split_regex_reconstruction.trace](audit_fixtures_r6/10_split_regex_reconstruction.trace) | 960 | `419a952b5636d13f3388e6b1f62fddd0c8027e86d2cba5ffa545c89d47d7479d` |
| [audit_fixtures_r6/PROVENANCE.txt](audit_fixtures_r6/PROVENANCE.txt) | 1087 | `b718a6a234c113a6c8e0c479a6329e5be21ec2657752a30551c4201ce93afbcb` |
| [audit_validation_r6.txt](audit_validation_r6.txt) | 562 | `0e11122d8b9c74730228117c289c010152117a21eafcae5a3051e9733d166bed` |
| [base_amend_r2.txt](base_amend_r2.txt) | 1457 | `ec79fd4d20857b5f36e7d9d89c08902157cd33966a16a5358c6aacb3f4ec621e` |
| [base_commit.txt](base_commit.txt) | 995 | `a51d2f03f8799984aaa29864a2d9bcdb02f6f409b9d0c3272d628991c2ea51ac` |
| [base_diff.txt](base_diff.txt) | 1601 | `f616a14626c1bb8030fab784f330f307b36a739d3f51f606265c2ead6b2d17b3` |
| [base_diff_stat.txt](base_diff_stat.txt) | 105 | `9321a9d6061b3ca2a2fa0d0f470beb80c8f22a7f8e72d782f2933ff0523ae363` |
| [bcm2711_dts_scan.txt](bcm2711_dts_scan.txt) | 1330 | `54d6fefd19eaeaba0a1b2ec103551002cbfac8a4ea473b0ceb7b2041ebfbed05` |
| [bloat_arm-rpi4-rt_top30.txt](bloat_arm-rpi4-rt_top30.txt) | 3937 | `abb69c24358afb1d485b73cf2c7f9b37eafafbb7a2b569791a5e985f94fa75a8` |
| [bloat_arm-rpi4_top30.txt](bloat_arm-rpi4_top30.txt) | 3931 | `9187a5851e7ba1d3fa0f92dfdb2bd13e9ff454955d62cc21aba2c70222e66e09` |
| [build_closure_recheck.txt](build_closure_recheck.txt) | 875 | `edbc2e0925b1029393ca9106dc7a49c8c8a62e65d18bd02dae1589b416b14500` |
| [build_gcc_last50.txt](build_gcc_last50.txt) | 4433 | `72c5809ecd256a0340dfb34a76d56d39b06f87136d3f679dabfdc7a158b4ee9e` |
| [build_gcc_log.txt](build_gcc_log.txt) | 48259 | `3157116b9e9b5f8d6822103ff5adf4d4e1b6f2f8fa13ff2dae277bc82bfc401a` |
| [build_gcc_result.json](build_gcc_result.json) | 595 | `4f6572af261ef1993d476f1b2135ae795fcc967677ce898f9c52e9e942b2f95e` |
| [build_stop_reason.txt](build_stop_reason.txt) | 1169 | `9f739c517e92e332ac21c7a4d659a7425c57d7123b5ad8a10191b5d0382f5c08` |
| [commands.txt](commands.txt) | 2350 | `5ee71377d1916acabc30ddcbaf2b52ccf314415ef493cf0ef5d8d9593d6e2c18` |
| [compiler_actual.txt](compiler_actual.txt) | 23130 | `c4d7d8f3a1ac90a07fa73fa7f3b8721e995f9bc5ee773a957b9940146051dd19` |
| [completed_build_gcc_last100.txt](completed_build_gcc_last100.txt) | 11282 | `422d9f97bb983a023e1e1e84ce69b05c68e62af441d4e9c6f61d038ee6c48c79` |
| [completed_build_llvm_last100.txt](completed_build_llvm_last100.txt) | 9689 | `411d019efb02d2560443f9bfce046bcf30a4c5c2c194d91c06517b48a1ff0ec7` |
| [completed_export_check_home.txt](completed_export_check_home.txt) | 928601 | `e9638e9bc013652851316f27b1c0cc1dd24d139d20aa9a99a0060ec0af378190` |
| [completed_export_processes_summary.txt](completed_export_processes_summary.txt) | 856 | `6aaf402342d16904ad8e10499c9729c3e4029c12ca49dcda3c624636dfc9b892` |
| [completed_gcc_processes_summary.txt](completed_gcc_processes_summary.txt) | 666 | `c6830fc2f34b88293eca77c504b3e4877fd99af1812e67b5be01bc92182f135b` |
| [completed_gcc_r2.external_review.txt](completed_gcc_r2.external_review.txt) | 1654 | `c7c1ff8a0a3391f07f530ae042cee48df05fd4ca6f07552bea684abeb675fffa` |
| [completed_llvm_processes_summary.txt](completed_llvm_processes_summary.txt) | 670 | `f7dad6cb61f64c944ef92ee8a104589d94972fdfaf14f766252af9349f51e563` |
| [completed_llvm_r2.external_review.txt](completed_llvm_r2.external_review.txt) | 2814 | `b9e200f46f8e8be1d49d35842a60fcce7926b22bdbe23ab80b9e7e1c78604b4e` |
| [completed_log_integrity.txt](completed_log_integrity.txt) | 1602 | `ffeb08e5c0d763c99c976012f13483ac87e012871d7d2032f0c44d522bc687b1` |
| [completed_monitor.log](completed_monitor.log) | 6588 | `d87e85d7d0a6908239c678eaf30f50a17ddf34464ff8bc8ce2f01dfb040b0084` |
| [completed_run_baseline_build.status](completed_run_baseline_build.status) | 483 | `14e13e86f3666496b20285765712d66716d5207292f500b2859fb823f5e4a65d` |
| [config_gcc_arm-rpi4-rt.txt](config_gcc_arm-rpi4-rt.txt) | 194971 | `87623c5e041a5420b6be82642d46ccf4852bdf22edecb89b329079960ae151c3` |
| [config_gcc_arm-rpi4.txt](config_gcc_arm-rpi4.txt) | 195191 | `d3a72c62ee73d50ca53b021b9e72af478b3db463206cb5e246773ad5521ea244` |
| [config_inventory_comparison.md](config_inventory_comparison.md) | 12169 | `c7854201b213e25f9e5f4363833157dd03dec2b2e9dec210ea00223af5de3f7f` |
| [config_key_actual.md](config_key_actual.md) | 5479 | `9e0c7b9609b8a6b0e2854db6d95ef7f4e23bb32623269e7385aff836a3adf820` |
| [config_llvm_arm-rpi4-rt.txt](config_llvm_arm-rpi4-rt.txt) | 194771 | `df7b9388a4e1b5cc40fef81e7da3259ffb0591e8d0b52e003deecf617b8b88b8` |
| [config_llvm_arm-rpi4.txt](config_llvm_arm-rpi4.txt) | 194991 | `688e66c3d0c2e31c09fb563d9905420475319787c4d6764cd7b7e210a4f6d33c` |
| [diffconfig_arm-rpi4-rt.txt](diffconfig_arm-rpi4-rt.txt) | 1871 | `66737d9296423541f8ca9fbf7c9ad2d5fc5b9e8938ef405a0ed43bdebe50a437` |
| [diffconfig_arm-rpi4.txt](diffconfig_arm-rpi4.txt) | 1865 | `1b5fa68ffdb608478c65bb488a0ce44f5f6faf32555b0865a3fa10e435a53756` |
| [disk_gcc.txt](disk_gcc.txt) | 1210 | `54fa1e125559438652c18f957b815aa07de03e88ff53bba7f0b11254d132b389` |
| [disk_llvm.txt](disk_llvm.txt) | 1598 | `32f8060dcf04a319f9e2fda390098a6369e515baa15f0e7463e01127b53d2ecb` |
| [existing_project_gbs_r2.txt](existing_project_gbs_r2.txt) | 476 | `320e39b4399778cc7940c05b990a7a6ad0e081ad9e165c3af501f13bdc4c73aa` |
| [export_attempt_1801_summary.txt](export_attempt_1801_summary.txt) | 3888 | `16ff78bf3ebc27500f5bee22e044e4276dbff29cee70c25d803ed67635dfade0` |
| [export_attempt_2041_failure.txt](export_attempt_2041_failure.txt) | 2741 | `f9257adae86120af565fab0261d1b046ea6f430827b3b5aa85084d498d522e62` |
| [export_trace_open_analysis.txt](export_trace_open_analysis.txt) | 17306 | `225e31fa5f305075e50d4305cd73955ddb150d776b446ed3a49f12ef7414f2d1` |
| [external_gbs_keys_r2.txt](external_gbs_keys_r2.txt) | 184 | `c6aafcab4dee2b2888e50da9a45799537c1f33a1c4ea692fbfe78cb3e36ca003` |
| [fdo_platform_actual.txt](fdo_platform_actual.txt) | 10154 | `f6bfcc8d018288fbc66b4b245aabf30c8fcf7e0809336f294da1f6072429df25` |
| [fdo_symbol_search.txt](fdo_symbol_search.txt) | 343 | `bf58b41fd67a716d088e2eab5d15a777235393553ed54f2ce57cec13863dc877` |
| [final_kernel_state.txt](final_kernel_state.txt) | 218 | `a92ad3e3e8d582a584e4430f224911f18e47368d805b429cd9abfa56c42e7730` |
| [gbp_audit.md](gbp_audit.md) | 3657 | `904a24c8c7f23a13efc076f26ae90422a01f45a60edcfd8e4839b14fa2dd311f` |
| [gbp_source_lines.txt](gbp_source_lines.txt) | 19945 | `134c11e13bc151039b087bd43a194d007a26bad493f5401c3c04398c7f71dd44` |
| [gbp_system_config.txt](gbp_system_config.txt) | 396 | `544d115eb21ad6640e453bebbee49914bec139a8dd980929562b2b434ddb0900` |
| [gbs_config_audit_r2.md](gbs_config_audit_r2.md) | 9582 | `bbe261daf18f9b3492ece278ce1db91632a4e1aa5ad31c5cdd1d961515b8c352` |
| [gbs_config_source_r2.txt](gbs_config_source_r2.txt) | 24097 | `895680385a2a7f0802bec1064937edf0b154fa995b1fb8a48ada39566dd82af4` |
| [gbs_export_root_cause.txt](gbs_export_root_cause.txt) | 6077 | `040ccc1cc5997ae1365f17c45cb0ac14acca11c5c454b442a67e0097b24c0b37` |
| [gbs_tempdir_adjustment.txt](gbs_tempdir_adjustment.txt) | 1884 | `746d5a6db3cdd13a88da9db46ddd473f70e1b115c3a2132470fca2f162bcf0a4` |
| [gerrit_raw_integrity.txt](gerrit_raw_integrity.txt) | 289 | `4b7b8a0ba997fdb1baeb18d1c33aaed47b099b78f71f43feb091e88f1628eefe` |
| [gerrit_ssh_queries.txt](gerrit_ssh_queries.txt) | 668 | `1fb406bd26758e40b61ee6cf1dd1a0ee2926fdc0899438256c134b7c40fb49df` |
| [gerrit_ssh_summary.txt](gerrit_ssh_summary.txt) | 3172 | `9f2e4f715f90bbc3d79964a6a516755c670cbef44cc5ae2ac8481d9249f2bb40` |
| [home_preparation.txt](home_preparation.txt) | 481 | `533b8c55786bac5bfcdbe932eeffb7cd6b7ecc87dffe8b5dbba5d6a3b161c25f` |
| [home_source_audit.md](home_source_audit.md) | 4652 | `a479d4292b0dadb3d6459eb3e2e836b8d1e2be63560879cb958e466aeaec16e4` |
| [home_source_lines.txt](home_source_lines.txt) | 15146 | `d46a724c4e1b2d0fd2825f1501c05ad3d9b415e6725c9644c6613a14e68e830b` |
| [home_source_search.txt](home_source_search.txt) | 9041 | `552fb0aca4b849807625e733508c97d8e7680b567f9f4361cf871b1c2ea1702a` |
| [initial_state.txt](initial_state.txt) | 106 | `2efa94402f0d9eada2df4456e3dc034e6b58a842e5eba44da178b4d90a7cf728` |
| [kallsyms_ftrace_measurements.txt](kallsyms_ftrace_measurements.txt) | 5789 | `bc4049e7f3b3516153c4f919368685ea041c11c5474f68836dbbea1e11f716a4` |
| [log_integrity.txt](log_integrity.txt) | 280 | `8002db2e281644d1a30460c81d9f34592a812417cf814397ab9c41449ad3aa91` |
| [lz4_merge_check.txt](lz4_merge_check.txt) | 7089 | `79940499f5915ebb558b5824e0b9e05fa2bdf2a65b937ae3623259aa2901f6c3` |
| [modules_rpm_contents.txt](modules_rpm_contents.txt) | 21562 | `8167eb525b2d177f2d04de3bb02e00178df50de5b084993c630501000ae87834` |
| [offline_audit_r6_summary.txt](offline_audit_r6_summary.txt) | 3424 | `379b03fced7d3d14623f03ef80821c0b507e8f1036ae6bbe7000a150f9c02025` |
| [platform_tools_pending.txt](platform_tools_pending.txt) | 219 | `aa4b91efec868d97751b3920b6754124ac472013c3c1be614f38e2f8350611fc` |
| [publication_home_attempt.txt](publication_home_attempt.txt) | 420 | `45dc619aa3b254229aa405f57360ccb756a07dfb86289b89bc81516c1dec5d85` |
| [publication_r3_initial.txt](publication_r3_initial.txt) | 95 | `08aea3a962e7feab7f35ab6464ae1431b714e01273f4ccbaa1ee08f27cb29cd7` |
| [residual_state.txt](residual_state.txt) | 462 | `c6df5f38d5127af7d1ba2484d0c6b9f65f0cf3f5bb143054b5df588438fd5bcf` |
| [script_static_validation.txt](script_static_validation.txt) | 735 | `bbc77c3d8e9d46fec4ff9d2e5a65d3f4311ee56445b6204ef5840e2659e0c884` |
| [script_static_validation_null_exception.txt](script_static_validation_null_exception.txt) | 6935 | `ea843f583ac5d70931e4bb1903e827ce56509bb5732f5ca6e6cb0fee792f842b` |
| [script_static_validation_r5.txt](script_static_validation_r5.txt) | 717 | `2d9c3e0323826e3e1e5a4216434190d1560cd62cb338acea103cea086e3206e6` |
| [sections_gcc_arm-rpi4-rt.txt](sections_gcc_arm-rpi4-rt.txt) | 4954 | `8bb646db701e8fd1abc57e7ebfa38f65170d96b4043f1ce7c97e2719b1d1e603` |
| [sections_gcc_arm-rpi4.txt](sections_gcc_arm-rpi4.txt) | 4951 | `f7dde3c10971c5a26a25c436ab84802e5875e1e059f181b2e37bbe1e4eca71a7` |
| [sections_llvm_arm-rpi4-rt.txt](sections_llvm_arm-rpi4-rt.txt) | 5269 | `6ac1f77cb8824d59324c644f3609f8d425c24bd52bc8e3382beca6c081c2d63b` |
| [sections_llvm_arm-rpi4.txt](sections_llvm_arm-rpi4.txt) | 5266 | `3715c586d22835a9030a3315d632b2381c41d5ffe68c072bc3e07b8407a88a5c` |
| [size_gcc_arm-rpi4-rt.txt](size_gcc_arm-rpi4-rt.txt) | 2870 | `6ffde3200a85e7d60a077cdb068efeffcccfd2067754e30f9cc33600fd094d52` |
| [size_gcc_arm-rpi4.txt](size_gcc_arm-rpi4.txt) | 2864 | `01a72d0965bbc710b5f32610554aec1af3de221c153e6e61c642dcc22108574c` |
| [size_llvm_arm-rpi4-rt.txt](size_llvm_arm-rpi4-rt.txt) | 3035 | `60a51521314125b99d0a6e20de93010e82debbaa59ec34b97ae4f82c5653d833` |
| [size_llvm_arm-rpi4.txt](size_llvm_arm-rpi4.txt) | 3029 | `0627fc785c2bc2141a41e0528914423ed0faf1d545597506a7188fd58050f87a` |
| [static_source_lines.txt](static_source_lines.txt) | 42156 | `3d59342f258144ab1c4a3a5a3040d5829725a30d11a161380a465a96a7870646` |
| [sudo_call_audit.txt](sudo_call_audit.txt) | 2553 | `aab5f012f9c4d7e67551378914dd1e86b1d0c844f70c9a0e8d4341383ed13c29` |
| [symbols_gcc_arm-rpi4-rt.txt](symbols_gcc_arm-rpi4-rt.txt) | 2200 | `cc0cc05569817c757d016f8b9c42f894da61202b247f85ed851e354aea0b2296` |
| [symbols_gcc_arm-rpi4.txt](symbols_gcc_arm-rpi4.txt) | 2197 | `0909686bda8c4fcb8858c88c9f7ff32113293ccf235da8f5195181410b315278` |
| [symbols_llvm_arm-rpi4-rt.txt](symbols_llvm_arm-rpi4-rt.txt) | 2154 | `9528c3c53bbf98353e790570184f8877f2d1fcfde33b3076d5f440dc27ae74eb` |
| [symbols_llvm_arm-rpi4.txt](symbols_llvm_arm-rpi4.txt) | 2151 | `c6c1f8d8e80ec3ee9947e4feac8eecfcfe352656834fa16f4af1ab993ff326f9` |
| [tmp_directory_library_analysis.txt](tmp_directory_library_analysis.txt) | 7052 | `02cf8f32b47940a89ab30dbb46c73eb2e8a84a98f238132636ed598c7512dfcf` |
| [validation.txt](validation.txt) | 608 | `650b7deecef20b2419a568497e27999b318fac5f2ab808749590f58d499956cb` |
| [validation_home_static.txt](validation_home_static.txt) | 395 | `35ef2af6a2f314a4ca650839dc6a1c996c7ef873c981e2ce03d1eb6e76064a37` |
| [validation_r2.txt](validation_r2.txt) | 711 | `380f036d7a477d71884aee17ea510d8dec08b8bddf55b233e0499e410fc576cd` |
| [zram_branch_config_diff.txt](zram_branch_config_diff.txt) | 1486 | `6821b71429f4813048f41f111e33aa19ceae1ca023d3a0292a8a0030b17c7cbd` |
| [zram_layout_baseline.txt](zram_layout_baseline.txt) | 4817 | `72dfd39a793face9662bdf8125278ba59b5edd2747983748e396b3af200174fa` |
| [zram_layout_probe.c.txt](zram_layout_probe.c.txt) | 751 | `5ad5b05bc37ba0d961d7b42ab71fa94f4244cc98f4a38a73f9b483fedef13b5e` |
| [zram_layout_probe.txt](zram_layout_probe.txt) | 26105 | `7e9ac6f68d9e0df0ad51439a05e2766a6fee8f45cce5aa5d895a168f172b5397` |
| [zram_metadata_calculation.txt](zram_metadata_calculation.txt) | 401 | `1cab4aa21bc58cdd61f401b17922a10949ec0b6a5d64ca5f1cbcb1aff28af339` |
