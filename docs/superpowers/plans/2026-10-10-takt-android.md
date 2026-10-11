# Takt Android implementation plan

> For agentic workers: use superpowers:executing-plans to implement the tasks in this session.

Goal: build Android 16 ARM64 and Linux 0.3.1 release artifacts with readable installation instructions.

Architecture: preserve the shared library, queue and settings. Add Android MediaStore discovery and audio-service integration, a phone layout, and decoded-audio visualization without Linux subprocesses.

Tech stack: Flutter, media_kit, audio_service, audio_session, Kotlin MediaStore and MediaCodec.

Spec: ../specs/2026-10-10-takt-android-design.md

## Global constraints

- Android 16, Poco X7 and Samsung S24 Ultra, ARM64 APK.
- Queue restores paused; removal from recents stops playback and saves state.
- No app volume control; retain applicable Linux appearance settings.
- English code comments, RU/EN interface, short hyphens in documentation.
- Never publish signing keys or private music, settings or credentials.

## Review focus

- Permission denial must not erase saved library or personal metadata.
- MediaStore disappearance and rescans must retain playlist IDs and personal edits.
- Narrow screens and large text must not overflow playback controls.
- Audio focus interruption must pause without automatic resume.
- Queue deletion and recents dismissal must checkpoint before service shutdown.

## Task 1: Android build and media library

Files: android/, lib/platform/android_library.dart, test/android_library_test.dart.
Interface: AndroidMusicLibrary extends MusicLibrary, overrides scan/start/addSource; accepts a Future<List<Track>?> scanner. A null scan means permission denied, not an empty library.

- [x] Test denied permission, stable-ID merge, vanished tracks and favorites preservation.
- [x] Implement native audio permission, MediaStore query and embedded artwork extraction.
- [x] Prepare SDK, compatible JDK and Android 16 build configuration.
- [x] Run library tests.

## Task 2: Playback and lifecycle

Files: lib/platform/android_playback.dart, lib/platform/android_startup.dart, lib/main.dart, android manifest.
Interface: AndroidAudioHandler wraps the shared queue; publishes metadata, queue and position; handles play/pause/previous/next/seek/onTaskRemoved. Startup wires MediaEngine streams to TaktQueue.

- [x] Test notification actions and shutdown checkpoint with a fake AudioEngine.
- [x] Add audio_service and audio_session; configure mediaPlayback service and audio focus.
- [x] Branch Linux/Android startup; pause for interruptions and unplug events.
- [x] Run lifecycle tests and existing queue tests.

## Task 3: Phone UI and settings

Files: lib/ui/app.dart, lib/ui/mobile_shell.dart, lib/ui/settings_panel.dart, test/mobile_ui_test.dart.
Interface: TaktApp mobile flag selects phone layout while retaining shared actions and settings.

- [x] Test phone navigation, mini-player controls, absence of app volume and narrow-screen layout.
- [x] Add bottom navigation and expanding player; reuse search, rows, menus and dialogs.
- [x] Adapt settings, image preview and layout editing to phone; use system Back for backgrounding.
- [x] Run mobile and existing widget tests.

## Task 4: Android visualizer and file operations

Files: lib/platform/android_analysis.dart, android Kotlin bridge, lib/library/delete_tracks.dart.
Interface: native PCM analysis reports timestamped spectra; AndroidAnalysis.frame shares SpectrumScaler behavior. Native deletion requests Android approval.

- [x] Test spectrum timing, cancellation and stopped playback.
- [x] Decode with MediaCodec on a worker; compute FFT from decoded music, with bounded batches.
- [x] Add system-approved deletion and previewed artwork selection.
- [x] Verify analysis tests and Android compilation.

## Task 5: Release artifacts and documentation

Files: README.md, docs/install-android.md, docs/releases/v0.3.1.md, tool/ scripts and workflows.

- [x] Analyze and run the complete Flutter suite, build signed release ARM64 APK and Linux archive.
- [x] Check APK signature, Android version floor, archive contents and checksums.
- [x] Document installation, supported devices, permissions and physical-device checks still needed.
- [x] Prepare both assets for one GitHub 0.3.1 release; publish only verified artifacts.
