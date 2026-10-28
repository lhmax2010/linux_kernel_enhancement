# 离线审计对照用例（2026-10-28）

实际执行同一脚本的 --audit-only，每个摘要留在temp/audit_fixtures/<用例>.summary.txt；用例是文本，没有执行其中的系统调用。

| 用例 | 预期AUDIT-EXIT | 实际AUDIT-EXIT | 进程退出码 | 判定 | Issues |
| --- | ---: | ---: | ---: | --- | --- |
| [01_external_file_write.trace](audit_fixtures_r6/01_external_file_write.trace) | 1 | 1 | 1 | 符合 | External write/create open: /tmp/lko-audit-negative.txt flags=O_WRONLY\|O_CREAT |
| [02_dev_zero_write.trace](audit_fixtures_r6/02_dev_zero_write.trace) | 1 | 1 | 1 | 符合 | External write/create open: /dev/zero flags=O_RDWR |
| [03_dev_null_wrong_device.trace](audit_fixtures_r6/03_dev_null_wrong_device.trace) | 1 | 1 | 1 | 符合 | External write/create open: /dev/null flags=O_RDWR |
| [04_external_gbp_config.trace](audit_fixtures_r6/04_external_gbp_config.trace) | 1 | 1 | 1 | 符合 | External config: /etc/git-buildpackage/gbp.conf；Unapproved external open: /etc/git-buildpackage/gbp.conf flags=O_RDONLY\|O_CLOEXEC |
| [05_external_mkdir_success.trace](audit_fixtures_r6/05_external_mkdir_success.trace) | 1 | 1 | 1 | 符合 | External mkdir attempt: /tmp/lko-audit-negative-dir |
| [06_external_mkdir_eexist.trace](audit_fixtures_r6/06_external_mkdir_eexist.trace) | 1 | 1 | 1 | 符合 | External mkdir attempt: /tmp/lko-audit-negative-dir |
| [07_tmp_readwrite.trace](audit_fixtures_r6/07_tmp_readwrite.trace) | 1 | 1 | 1 | 符合 | External write/create open: /tmp flags=O_RDWR |
| [08_split_external_write.trace](audit_fixtures_r6/08_split_external_write.trace) | 1 | 1 | 1 | 符合 | External write/create open: /tmp/lko-audit-negative.txt flags=O_WRONLY |
| [09_split_allowed.trace](audit_fixtures_r6/09_split_allowed.trace) | 0 | 0 | 0 | 符合 | 无 |
| [10_split_regex_reconstruction.trace](audit_fixtures_r6/10_split_regex_reconstruction.trace) | 0 | 0 | 0 | 符合 | 无 |

8个负对照、要求的正对照及附加的正则重建正对照全部符合预期。
09只包含真实拆开的合法只读调用和/dev/null读写打开；计数1、首次第3行。
10另外覆盖拆开的clone/chdir/mkdir/mkdirat及返回FD，相对chdir同时验证fork后cwd继承；生成目录仅为trace文本；解析的child/at-child均在预期工作区路径。

用例10最终摘要为temp/audit_fixtures/10_split_regex_reconstruction.trace.final.summary.txt；旧摘要保留。

用例来源与改写说明见[PROVENANCE](audit_fixtures_r6/PROVENANCE.txt)。
