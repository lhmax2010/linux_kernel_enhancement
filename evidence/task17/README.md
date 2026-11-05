# Task17 evidence

- sr/ and vbase/: sanitized QB text/variables, selected source manifest, exact RPM identity, full boot/headed package inventories, image sizes/checksums, platform commands, kernel/config/module counts, resourced symbol/section checks.
- Generic analysis implementations are retained as .py.txt. Executed with matching GBS-root ARM Python via qemu-arm/bwrap; no host compiler/binutils or build.
- Detailed vbase config/symbol CRC values remain local only; public results are counts/conclusions.
- all_image_artifacts.json distinguishes 4 actually downloaded archives from 8 additional archives whose published sizes/hashes were recorded only.
- QB end is calculated from displayed begin+duration. Page timezone is unspecified; UTC is an inference cross-checked with package logs.
- No account/password/cookie/token/browser profile included. Full downloads in temp/task17; confidential analysis in vendor_local/task17.
- evidence_manifest.json excludes itself and final_checks.json to avoid recursive hashing.
