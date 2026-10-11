# Three-stage customization verification

Local Arch Linux / Hyprland. Update changes remain local, version 0.3.0+3. Git metadata is not usable in this session; original source copies under /tmp/takt-customization-baseline were used to compare behavior. No GitHub publish, system compositor rules or user library modifications.

The initial all-stage suite passed 72 tests. Additional race and dialog regressions added afterwards; final checks are recorded below when complete.

Manual source review identified and reproduced overlapping compact resize calls and missing maximized-state restoration. Serialized transition chain and maximize restoration implemented with red/green tests. Timer manual adjustment during expiry is guarded; temporary volume remains session-local. Live appearance changes and cancellation, narrow layout editing and 320x200 compact queue continuity have dedicated root tests.

An independent fresh reviewer was requested through the requesting-code-review workflow. The reviewer service failed before inspecting code due to an account usage limit. Do not represent this update as independently reviewed. Parent source review and automated checks continue.

Native compositor caveat: current tiled Hyprland ignored requested 420x240 window dimensions. The compact UI itself renders at 420x240/320x200, but floating mode is required for the compositor to honor window sizing. No compositor configuration is changed. Native opacity/always-on-top support is similarly compositor-dependent.

Performance: see 2026-10-05-stage-one-performance.md. Original/updated mixed benchmark results do not establish a universal glass performance improvement; avoid claiming that a remote user's GPU lag has been verified fixed.

Final source checks: 78 tests passed in /tmp/takt-tests-complete.log; additional extreme text/panel settings regression passed in /tmp/takt-extreme-red2.log (passed immediately; no corrective code needed). Analyzer clean in /tmp/takt-analyze-complete.log. Native UI final pass in /tmp/takt-native-complete.log; synthetic screenshots copied to docs/screenshots/customization-*.png. GTK helper/picker script returned exit 0. Actual libmpv fade/pause/restore passed using a silent WAV and isolated store in /tmp/takt-sleep-native.log. Compositor report /tmp/takt-window-geometry.json confirms tiled Hyprland kept 924x1064; requested compact 420x240 is not honored in that mode.

Final completion evidence:
- Full suite: 79 tests passed, /tmp/takt-tests-release.log.
- Final analyzer: no issues, /tmp/takt-analyze-release.log.
- Linux release build: exit 0, /tmp/takt-release-build.log.
- Nine ELF files checked with ldd: no missing system libraries. Local artifacts reference GLIBC 2.38 and GLIBCXX 3.4.32 symbols; this local archive is not Ubuntu 22.04 compatible. Wider distribution requires the separate configured Ubuntu CI build.
- Archive checksum verified; isolated extraction and installation (including a path with spaces) passed. 104 third-party license files included. Packaging check exposed an outdated Flutter-engine license filename; collector updated to the pinned SDK's LICENSE.flutter_gtk.md and archive rechecked.
- Extracted release starts with a fresh isolated XDG data/config and empty Music folder, remains alive, handles SIGTERM with exit 0 and saves its own temporary SQLite database. No private music or settings used.
- Archive: dist/Takt-0.3.0-linux-x86_64.tar.gz; checksum: dist/SHA256SUMS.txt. No external publication.
