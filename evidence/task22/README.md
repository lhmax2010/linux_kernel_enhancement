# Task22 evidence

All analysis is read-only; no repair/deployment/reboot occurred. Report: [docs/22](../../docs/22_base01_coregl_diagnosis.md).

- `archive_identity.json`, `system_data_identity.json`, `tool_packages.json`: verified input identities and authorized ARM tool package sources/checksums.
- `base_archive_members.json`, `module_image_comparison.json`, `module_comparison_summary.json`: exact base01 archive versus SR modules.img inventory, sizes/hashes and modes. The RPM-only extraction was not used as the official installed index/mode reference.
- `*_modprobe_*.txt`, `*_depmod_excerpt.txt`, `*_proc_tsm_*.txt`, `proc_tsm_crc_check.json`: platform-only dry-run/ABI checks; no module was loaded. Full output hashes are in `raw_output_manifest.json`.
- `deployment_mode_provenance.txt`, `dac_cause.json`, `stability_error_candidates.txt`: source of mode preservation and nonroot access failure. Error strings are candidates, not a captured failing syscall.
- `*_coregl_and_rpmdb_image.txt`, `*_rpmdb_coregl.txt`, `*_image_packages.txt`, `image_package_comparison.json`: coregl actually present in both final images; RPM database is in the separate system-data partition.
- `*_headed_kickstart_numbered.txt`, `kickstart_log_matches.json`: all headed post sections, including --nochroot, plus package-install log references.
- `board_commands.jsonl`, `board_*.txt`, `board_log_search_summary.json`: D collection only, identity, search scope, gaps, final state and owner restoration. Unrelated full journal/directory listings remain local.
- `recorded_command_audit.json`: 555 recorded commands / 10 JSONL files, no erase or direct library deletion candidate; not a claim about unrecorded actions.
- `post_analysis_hashes.json`, `cleanup.json`: original image contents unchanged, temporary tools and extracted binary copies removed. Task9/17 originals retained.

`debugfs rdump` reported ownership restoration errors in the unprivileged user namespace. Original ownership/modes were read using image `stat`; all 73 module file hashes matched the previous board inventory. Queries on extracted RPM database copies succeeded. Some board searches returned 2 for missing paths/dangling links; their scope is stated in the report rather than claimed complete.

Published text removes trailing whitespace; raw outputs and their recorded SHA-256 remain in temp/task22. Original source line numbers are retained.
