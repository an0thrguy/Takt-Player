# SDD ledger — plan: docs/superpowers/plans/2026-10-03-takt-implementation.md

Execution authorized: user installed dependencies and said "готово". Linux only.

Pre-flight: tasks 1→2→5 share PlaybackEngine generation/events; preserve one owner. Tasks 3→4→6 share stable TrackId and storage transactions. Tasks 5→7→9→10 consume one QueueController. Tasks 4→11 consume metadata/override priority. No duplicate controllers or path-only identity.

Ruling: protected .git is not a repository; execute in the user's empty project folder and retain this ledger instead of Git-dependent scratch scripts. No protected-directory writes or commits are attempted.

Environment: installed Flutter found at /home/anotherguy/develop/flutter. Sandbox prevents SDK cache writes; run Flutter through the authorized escalation mechanism. Product artifacts remain in the project.

Implementation complete for Linux 0.1.0; platform coverage and remaining unverified cases are recorded in release-checklist.md.

Implementation ruling: use direct sqlite3 with JSON snapshots in atomic transactions instead of drift-generated tables. Scope is hundreds of personal tracks; keep model/playback/library boundaries and stable IDs. SQLite persistence remains local. Files are organized by responsibility with fewer classes than the preliminary plan.

Library refresh ruling: initial Linux version rescans remembered sources every 10 seconds. Async enumeration/hash/ffprobe avoids synchronous audio decoding on the UI thread; filesystem watchers are deferred. Source loss retains identities and personal data.

Playback ruling: media_kit is an audio boundary; application queue is authoritative. All opens, next/previous, pause and removals serialize. Natural completion uses playback intent because media_kit emits playing=false before EOF. The initial failing regression reproduced this ordering, then passed after the fix.

Verification: native Linux smoke passed playback, seek, pause, paused restore, light/dark rendering. Eleven synthetic format samples passed native playback/seek/EOF. Native queue tests passed once/loop/single at real EOF. All 28 unit/widget tests pass. Background playback passed all checks for 900 seconds; restore identified a dependency defect, fixed locally and verified by a separate complete 30-second tray test (details in platforms.md).

Independent review: five findings (EOF ordering, filtered queue reorder, first shuffle cycle, remove/open race, manual-order leakage). Fixes and regressions passed; final reviewer confirmed no remaining concrete P1/P2 blockers before the separately reviewed tray fix.

Performance harness ruling: flutter test has no --profile option in this SDK. Use flutter drive --profile. Its debug fake text-input client (-1) is ignored in profile, so use EditableTextState.updateEditingValue at the TextInputClient boundary; measure IME dispatch separately from rendering. Debug timings are not release/profile results.

Final review: one additional stop/EOF race reproduced red. Completion now rechecks intent and generation inside its serialized action, rejecting completion queued before an explicit stop, reopen or seek. Final full suite and native EOF recheck passed.

Gesture ruling: Tooltip's long-press recognizer consumed the drag. Remove its long-press handler from the handle, keep an explicit accessibility label, and separate body selection from the handle. Regression uses continuous pointer movement (single giant jump skips Flutter's insertion thresholds); menu and full-row drag pass.

Scanning improvement: three concurrent metadata processes and incremental library notifications; 500-file initial pass reduced from 36.7s to18.1s, unchanged rescan343ms. Source discovery obeys XDG user-dirs, canonicalizes the chosen path and avoids treating a disabled XDG Music=Home as a music source.

Tray review: reviewer confirmed activation routing and vendored-build reproducibility; requested preserving the existing null-owner guard during teardown. Guard added. Configured D-Bus menu path is exposed independently of primary-click behavior; the native regression checks that property as well as actual activation. Analyzer reports no issues.

Final sequential native tray regression passed: guarded event handling, menu path, hidden playback, real D-Bus Activate and window restoration. Independent reviewer found no remaining targeted blockers.

Final release build passed. Package contains executable, runtime libraries, assets, license notices and verification documents; no missing shared libraries reported by ldd. Ready release started successfully on Hyprland: mapped Takt window 924x526, no application exception in output. Window retained for user. User-menu installation was not run.

User audio regression: system sink-input had Mute=yes under shared application.id=mpv, despite playback position progressing. Current stream unmuted. MediaEngine sets audio-client-name=Takt before opening audio; independent real native stream regression passed (unmuted and uncorked). Meta+Q full-exit widget regression reproduced failure then passed while search focused. Current Hyprland consumed Meta+Q for ordinary close; user-authorized binding now routes through focused-window tool/super-q.py, with original config backup and graceful SIGTERM handling in Takt.

Final audio/shortcut update: 29 tests pass; analyzer clean; native independent unmuted/uncorked Takt stream passed. Release rebuilt. Actual updated release exited with code0 through the focused-window Super-Q helper (SIGTERM -> shared save/dispose path), then reopened. Current Hyprland uses Lua dispatch syntax; ordinary-window fallback uses hl.dsp.window.close(). No remaining targeted review blockers.
