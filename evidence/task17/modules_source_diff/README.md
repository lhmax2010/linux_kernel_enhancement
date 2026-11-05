# Task17 supplement: external module source comparison

- remote_fetch.txt / relationship.txt: all remote heads fetched read-only into remote-tracking refs, exact contains/ancestry/count output.
- commits.txt / *_show.txt / diff.txt / stat.txt: complete two-commit difference; public Tizen packaging source only.
- *_spec_numbered.txt: line-numbered fixed-commit sources for citations.
- source_invariants.json: all 15 non-spec entries unchanged; %prep/%build text identical.
- *_rpm_queries.txt / rpm_comparison.json: actual image-selected RPM identity, scripts, file list, requirements and source-package file digests.
- *_platform_sections.txt / binary_diff.json: platform size -A -d and readelf -SW output for every module; deltas are vbase minus SR.
- content_comparison.json / section_hashes_platform.py.txt: section byte comparison via corresponding GBS-root ARM Python; no build, no board, no sudo.
- conclusion.json / worktree_unchanged.json / validation.json: decision and checks. The original evidence/task17 evidence_manifest.json is historical and intentionally unchanged; this folder has its own manifest.
