# Approved Takt update implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the user-approved visual, playback and safety updates.
**Architecture:** Keep queue/library as data owners. Add pure frequency and audio-route units, then bind persisted options and focused UI components to them.
**Tech Stack:** Flutter/Dart, FFmpeg, PulseAudio-compatible pactl/PipeWire, existing SQLite.
**Spec:** docs/superpowers/specs/2026-10-04-approved-update.md

## Global Constraints
- Linux current target; English source comments, Russian/English UI.
- Preserve native artwork picker, tray and MPRIS. No notifications.
- In-place authorized workspace; protected .git has no usable repository. No commits/pushes for this task.

## Review Focus
- Loud/silent audio and frequency isolation: preserve a bounded waveform rather than clipping a rectangle.
- Headphone initialization, manual route changes and failed probes must not pause unrelated playback.
- Text input must retain arrows/space and Ctrl navigation.
- Favorites must survive reload, missing tracks and duplicate actions.
- Narrow windows and menu dismissal must retain accessible playback controls.

### Task 1: Spectrum
**Files:** lib/analysis/spectrum.dart, lib/analysis/audio_analysis.dart; test/spectrum_test.dart, existing analysis tests.
**Interfaces:** FrequencySpectrum.analyze(Int16List) -> List<double>; AudioAnalysis.frame(position, playing, sensitivity) -> normalized 24 bands.
- [x] Test silence, bass/treble separation and loud headroom; observe failure.
- [x] Implement FFT/Hann/log bands and adaptive bounded scaling, preserve cancellation/hidden pause.
- [x] Verify tests and actual FFmpeg tone.

### Task 2: Headphone pause
**Files:** lib/platform/audio_routes.dart, lib/main.dart; test/audio_routes_test.dart.
**Interfaces:** AudioRouteSnapshot.fromSinks(defaultSink, sinks); disconnectedFrom(previous) -> bool; HeadphoneMonitor callback/setting.
- [x] Test unplug, Bluetooth removal, initial/manual routing, failed query/no-change.
- [x] Implement event-driven pactl queries with polling fallback and lifecycle cleanup.
- [x] Verify pure cases; inspect actual device data without changing it.

### Task 3: Favorites and shortcuts
**Files:** lib/library/library.dart, lib/ui/app.dart; test/favorites_test.dart, test/shortcut_test.dart.
**Interfaces:** library.favorites Set<String>, toggleFavorite(ids); settings seekStep/volume.
- [x] Test persistence/duplicates and focused keyboard behavior.
- [x] Implement filtered Favorites view, star/check menu actions and appended queue additions.
- [x] Verify queue stays authoritative and existing selection/drag tests pass.

### Task 4: UI and settings
**Files:** lib/ui/glass.dart, lib/ui/visualizer.dart, lib/ui/app.dart, lib/main.dart; test/update_ui_test.dart.
**Interfaces:** GlassSurface(child, dark, radius), WaveSignal(values,color,bars,smoothness); persisted visualizerEnabled/style/sensitivity/smoothness/color and pauseOnHeadphonesDisconnect.
- [x] Test drawer dismissal/options persistence and both visualizer modes at narrow/wide sizes.
- [x] Implement right drawer, glass popups, independent color and geometry.
- [x] Run full tests/analyzer, native integration and screenshot checks in both themes; build release.
- [x] Fresh whole-change review; fix meaningful findings before completion.
