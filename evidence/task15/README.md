# Task15 evidence

- `remote_before.txt` / `fetch_tizen.txt` / `source_base.json`: fixed tizen and absent sandbox before local source edits.
- `source_commits.txt`, `source_stat.txt`, `source_excerpt.txt`: nine public resourced commits, statistics and numbered source references.
- `source_diff_check.txt`, `static_review.json`: pre-build static checks; these do not claim compilation passed.
- `kernel_algorithm_excerpt.txt`: public kernel 0fac5de6 source for zram selection and compaction input semantics. Force-reclaim dispatch references remain in task14.
- `patches.sha256`: format-patch checksums.
- `runner_vs_task12.diff.txt`, `script_static_check.txt`, `launch.json`: single-package runner adaptation, syntax check and tmux launch.
- `baseline_rpm_downloads.json`: only armv7l packages from the fixed QB1211696 image; downloaded bytes/SHA match existing metadata. Packages are not installed.

No board data are included here. Earlier authentication-wait evidence is retained as history; the following continuation evidence records successful completion after user authentication in the same session.

- `resume_gate.json`, `resume_monitor.log`, `monitor_final.json`, `process_group_summary.txt`: live-group gate, ten-minute snapshots and final no-residual check (unrelated host process rows omitted).
- `build_status_final.txt`, `build_resourced*_last100.txt`, `full_log_manifest.json`: ALL-END/BUILD-END, log tails and complete local log hashes.
- `build_validation_excerpt.txt`, `build_warnings.txt`: numbered source-log extracts, expanded make -j10, tests, warnings and time -v.
- `test_results.json`, `ctest_LastTest_0.txt`, `test_and_binary_mapping.txt`: two CTest rounds with skips explicitly separated, final retained cmocka cases and test registration/source mapping.
- `rpm_inventory.json`, `source_rpm.json`, `source_rpm_query.txt`: 17 binary RPMs plus source RPM and five old image RPMs, metadata and SHA-256.
- `rpm_file_comparison.json`, `file_attribution.json`, `inherited_vs_local_changes.txt`, `changed_text_files.diff.txt`: image file differences and source attribution boundaries.
- `tool_versions.json`, `platform_queries.txt`, `payload_commands.json`, `payload_inspection.json`, `debuglink_commands.json`, `debuglink_comparison.json`: buildroot tool queries, extraction and ELF verification; six changed files identical after removing debuglink.
- `resume_resourced.external_*`, `resume_resourced.observed_outside.txt`: limited external-path observations; concurrent paths cannot be attributed.
- `source_after_build.txt`, `resume_verification_summary.json`: unchanged source HEAD/worktree and final verification summary.
- `manifest.sha256`: checksums of this text evidence directory, excluding itself. Full logs and RPM payloads remain under temp/task15; no RPM installation or deployment occurred.

Raw output excerpts preserve original trailing whitespace, empty TSV fields, and unified-diff context prefixes; git whitespace warnings on those evidence files are expected. Markdown documentation passes git diff --check.
