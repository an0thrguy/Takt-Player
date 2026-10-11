# Takt Stage One Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve Linux responsiveness and six interaction flows while preserving the existing player and its data.

**Architecture:** Add a validated presentation-preference model and inherited presentation scope; extract playlist creation, sidebar sizing and volume widgets from the root UI. Retain the existing GTK artwork picker and desktop lifecycle. Measure glass performance before applying rendering optimizations.

**Tech Stack:** Flutter 3.47.6, Dart 3.13.5, GTK 3/C++17, current SQLite/media_kit/libmpv services.

**Spec:** `docs/superpowers/specs/2026-10-05-takt-customization-design.md` (stage 1 only).

## Global Constraints

- Linux first; preserve Ubuntu 22.04 / GLib 2.72 compatibility and Arch support.
- Keep music, queue, playlists, favorites and existing preferences on upgrade.
- Russian and English remain supported; comments in English.
- Quality/Balanced/Economy: blur sigma 18/10/0 and visualization refresh ceilings 60/30/15 Hz; default Balanced.
- Sidebar: default 178, expanded 150-320, collapsed 62; leave at least 360 logical pixels for content.
- Artwork picker initially 800×600, resizable, monitor-clamped and transient to its parent.
- Animations Fast/Normal/Smooth: 120/220/320 ms; default Normal; disabled is zero duration.
- No new streaming service, second audio player or unrequested dependency. Stage 2/3 features are outside this plan.
- Do not change the published v0.2.0 tag or upload another release as part of implementation. Local `.git` is protected; record local changes without bypassing protections or publishing intermediate commits.

## Review Focus

- Malformed or missing saved preference values must not crash the UI or discard unrelated settings (task 1).
- Rapid plus/menu clicks and cancellation during reverse animation must not stack dialogs or dispose a live controller (tasks 1, 3).
- Fractional trackpad scrolling, external MPRIS updates and slider drag must share bounded, current volume (task 4).
- Narrow windows and resizing during a drag must not overflow or replace the user's preferred width (task 5).
- Corrupt/deleted/very large images and picker dismissal must not apply artwork or strand a pending platform call (task 6).

## File responsibilities

- `lib/ui/presentation_preferences.dart`: validated values, enum choices, durations and numeric limits.
- `lib/ui/presentation_scope.dart`: inherited presentation configuration for surfaces and transitions.
- `lib/ui/glass.dart`: glass and shared transitions, driven by scope rather than fixed constants.
- `lib/ui/playlist_dialog.dart`: owned text-controller lifecycle and creation dialog.
- `lib/ui/volume_control.dart`: popover/inline volume UI, wheel accumulation and one callback.
- `lib/ui/resizable_sidebar.dart`: bounded drag/collapse state and commit-on-drag-end.
- `lib/ui/app.dart`: compose widgets, map callbacks into library/queue/store; keep search and navigation.
- `lib/ui/settings_panel.dart`: localized preference controls using the existing save path.
- `lib/ui/visualizer.dart`, `lib/main.dart`: profile-driven presentation refresh with playback unchanged.
- `lib/platform/desktop.dart`: existing close-policy owner; route new close button through it.
- `linux/runner/artwork_picker.h`: GTK browse/preview window and response ownership.
- New focused tests plus current suite and native integration checks verify the corresponding flows.

### Task 1: Presentation preferences and animation scope

**Interfaces:** `PresentationPreferences.fromMap(Map<String, dynamic>)`; getters `double blurSigma`, `int visualizerHz`, `Duration transitionDuration`, `bool volumeWheel`, `bool volumeInline`, `bool closeOnHover`, `double sidebarWidth`, `bool sidebarCollapsed`. `PresentationScope(preferences: ..., child: ...)` with `PresentationScope.of(BuildContext)` returning defaults when absent. Persist keys `performanceMode`, `animationsEnabled`, `animationSpeed`, `volumeWheel`, `volumeInline`, `closeOnHover`, `sidebarWidth`, `sidebarCollapsed` alongside existing settings.

- [ ] Write `test/presentation_preferences_test.dart` assertions: defaults sigma 10 / 30 Hz / 220 ms; Quality 18/60, Economy 0/15; Fast 120, Smooth 320, disabled zero. Unknown strings, wrong types, NaN and infinite width fall back safely; widths clamp 150-320; existing volume/theme values are not mutated.
- [ ] Run `flutter test test/presentation_preferences_test.dart`; confirm failure before implementation.
- [ ] Implement preference parsing and scope in the two new files; wrap UI below MaterialApp so overlays inherit it. Read durations in `animatedPage`, `showTaktDialog`, `showGlassMenu` and settings drawer transitions. Use theme motion duration where applicable. Do not dispose dialog controllers with a fixed 300 ms delay; prefer ownership by dialog state.
- [ ] Add `test/presentation_motion_test.dart`: disabling animation reveals and dismisses menus immediately; rapid open/close leaves one overlay and no exceptions; setting speed takes effect on subsequent transitions. Add localized settings selectors and toggles.
- [ ] Run both focused tests and `flutter analyze`; record passed results and changed files.

### Task 2: Glass profiling and render isolation

**Consumes:** task 1 profile getters. **Produces:** profile-driven `GlassSurface` and visualizer refresh without changing audio analysis semantics.

- [ ] Capture baseline profile frame timings using the same scripted 500-track scroll, popup and active-spectrum scenario, glass on/off; record renderer, GPU, session type and scale in `docs/verification/2026-10-05-stage-one-performance.md`. Run without logging personal track metadata. Treat lack of the affected machine as a verification limit.
- [ ] Add rendering tests: foreground icon/text stay outside blur filter content, Economy creates no BackdropFilter, disabled glass remains opaque, and all profiles preserve theme contrast.
- [ ] Apply scoped blur sigma to `GlassSurface`; skip BackdropFilter at zero. Add RepaintBoundary around changing visualizer content only where measured invalidation crosses static controls. Inspect the current main refresh timer before replacing it with the selected 60/30/15 Hz ceiling; retain pause/hidden-window behavior.
- [ ] Ensure smoothing does not cause intermediate visualizer paints above the chosen ceiling: use a localized scheduled repaint/interpolation rather than an unrestricted animation ticker in low-frequency profiles. Test with a fake clock that notifications do not exceed the ceiling and pause reaches a flat signal.
- [ ] Repeat matching profile runs and compare p50/p95 timings; run existing spectrum/analysis tests and rendering tests. Document evidence without claiming a fix on an untested Arch machine.

### Task 3: Playlist creation dialog

**Interface:** `Future<String?> showPlaylistDialog({required BuildContext context, required bool dark, required bool glass, required bool english})`; returns trimmed nonempty name or null. The dialog owns its TextEditingController until disposed.

- [ ] Update `test/shell_test.dart` and add `test/playlist_dialog_test.dart`: search is still present after plus; both plus and sidebar open one dialog; spaces type normally; Enter on `  Mix  ` creates/selects `Mix`; empty input creates nothing; Escape/Cancel leave playlists unchanged; rapid clicks do not duplicate overlays; 620×520 layout fits.
- [ ] Run those tests to observe the old inline flow failing the new contract.
- [ ] Implement the focused dialog with common glass, theme and animation scope. Replace `creating`/`playlistName` and inline form in app.dart with one guarded async open method. Reuse `MusicLibrary.createPlaylist` and current navigation selection rules; do not change duplicate-name behavior.
- [ ] Run focused tests plus shortcut tests and both-theme native checks; record results.

### Task 4: Unified volume controls

**Interface:** `VolumeControl({required double value, required ValueChanged<double> onChanged, required bool inline, required bool wheelEnabled, required bool dark, required bool glass, required bool english})`. App callback uses one `Future<void> setVolume(double value)` path for storage and `queue.engine.volume`; external MPRIS changes remain authoritative.

- [ ] Add `test/volume_control_test.dart`: click popover default, inline choice, 5-point wheel detents, 0/100 bounds, wheel-disabled behavior, fractional accumulation without a large jump, outside-area scrolling unaffected, live external value while popover open. Verify displayed and engine/stored values agree through an app-level test.
- [ ] Run tests and confirm the missing wheel/inline behavior fails.
- [ ] Implement wheel distance accumulation (100 logical scroll units per 5-point detent, carrying remainder); map downward wheel movement to volume decrease. Extract existing popover and slider; use a state guard against duplicate popovers. Remove the unused `volumeOpen` field if no longer needed.
- [ ] Wire localized settings, tooltips and semantics. Make inline slider responsive to playback space instead of overflowing. Route keyboard adjustment through the same app setVolume path.
- [ ] Run focused volume, shortcut, MPRIS and update UI tests.

### Task 5: Resizable sidebar and standalone close button

**Interface:** `ResizableSidebar({required double preferredWidth, required bool collapsed, required double availableWidth, required Widget child, required ValueChanged<double> onResizeEnd, required ValueChanged<bool> onCollapsedChanged})`. Reserve the existing 20-pixel content gap in width constraints. Add optional `Future<void> Function()? close` to TaktApp, supplied by main via the existing desktop close policy; `exit` remains explicit full quit.

- [ ] Add `test/sidebar_test.dart`: drag from 178 to 240 persists only on release; limits 150/320 and available content; collapse uses 62; narrow window temporarily collapses then restores saved 240; window width changing mid-drag cannot overflow. Include focusable collapse action and resize cursor checks.
- [ ] Run the new tests; confirm failure before replacing fixed sidebar width. Implement bounded sizing in the new widget and save final values through existing settings.
- [ ] Add close-button widget tests for default visibility, hover/focus visibility, pointer touch visibility, one close callback per click and no draggable-heading capture. Extend `test/desktop_test.dart` if policy coverage needs it; retain accessible-tray/no-tray behavior.
- [ ] Implement an in-content close icon, separate from DragToMoveArea, and localized hover preference. Use keyboard focus and media input capability for touch accessibility. Route to existing lifecycle, never directly to exit when close-to-tray is set.
- [ ] Run sidebar, desktop, shortcut, shell and update UI tests at 620 and 1200 pixels.

### Task 6: Artwork preview window

**Interface:** keep `takt/artwork_picker.pick` return type String?; extend arguments with current theme and localized preview/error labels. Picker returns an image path only after Choose; Dart library still copies the selected artwork into application storage.

- [ ] Create native test fixtures in a temporary directory: valid wide and tall PNGs, corrupt image, disappearing file, large image and empty folder. Document failing baseline: 400×400 fixed size, no preview and image activation currently accepts directly.
- [ ] Extend ArtworkPicker state with preview widget, selected path and response guard. Create 800×600 resizable transient dialog, bounded by monitor work area, with browse/preview panes. Decode scaled preview preserving aspect ratio; show filename and original dimensions. Clear old preview before an unsuccessful selection; disable Choose unless a readable image is selected.
- [ ] Change image row activation to preview; folder activation navigates. Respond exactly once and clean references on Cancel/Escape/delete-event/parent close. Handle invalid folder entry and read errors with localized feedback, preserving subsequent navigation.
- [ ] Pass dark/light styling and labels from app.dart; apply GTK CSS scoped to this dialog, without globally changing desktop GTK preferences. Keep native window movement under compositor control.
- [ ] Build and manually verify valid preview, aspect ratio, corrupt/deleted file, cancellation, explicit apply, resizing, parent ownership in floating main window and both themes. Record any GTK/compositor limitation.

### Task 7: Final integration and review

- [ ] Run `flutter analyze`, `flutter test`, and `flutter test integration_test/approved_update_test.dart -d linux`. Update old integration expectations only where an approved behavior changed.
- [ ] Run `flutter build linux --release`; validate Ubuntu 22.04 build using the existing compatible release workflow only when execution has authorized external source publication, otherwise record that CI verification awaits publication.
- [ ] Exercise every flow with Russian/English, light/dark, narrow/wide windows and restored old settings; verify queue does not autoplay after restart and volume/tray policies persist.
- [ ] Update README, code guide and verification report for stage 1 only. Do not claim wallpaper/presets/compact mode shipped.
- [ ] Request one independent final code review and address material findings; confirm tests after any fixes. Keep the existing user installation unchanged unless requested; deliver local build path and remaining platform verification limits.

## Plan review

Self-review: stage 1 requirements map to tasks 1-6; review-focus inputs map to named tests/manual scenarios. Interfaces use one presentation scope and existing data services. Stage 2 and stage 3 remain outside this execution. Native execution in this session is recommended because the UI tasks share settings, scope and root composition; one final independent review checks their integration. Implementation awaits review of this plan and execution-method selection.

Execution complete in source. Final local verification and package evidence are consolidated in docs/verification/2026-10-06-customization-review.md. Independent review request failed due to service usage limit; this is an explicit verification limitation. No publication performed.
