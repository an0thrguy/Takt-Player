# Android 0.3.1 verification

- Shared Flutter suite after phone feedback: 96 tests passed.
- Flutter analyze: no issues found.
- Linux release build and native GTK artwork picker/preview checks passed.
- Android signed release build passed with Java 17, SDK 36 and NDK 28.2.
- APK version: 0.3.1, code 5, minimum and target API 36.
- Release APK contains only arm64-v8a native libraries.
- APK signature verified; ZIP alignment verified for 16 KB pages.
- ARM64 ELF libraries have LOAD alignment of at least 16 KB.
- Release signing identity stays local and is excluded from source archives.

## Remaining device checks

Full emulator playback verification was not completed. The emulator crashed under concurrent build load, and the separate x86_64 debug engine download stalled. These initial checks preceded the connected-Poco feedback follow-up below. Do not describe these checks as passed.

On Poco X7 and Samsung Galaxy S24 Ultra with Android 16, check permission denial/grant, MediaStore discovery, actual sound, background/lockscreen controls, interruption/headset pause, recents removal, paused queue/position restoration, artwork preview and customization.

## Poco feedback follow-up

A connected Poco X7 running Android 16 / HyperOS 3 provided two distinct crash traces:

- Android rejected the playback notification because the dynamically referenced small icon was removed by resource shrinking. The release now keeps `ic_notification`; its resource ID was verified in the built APK.
- A libmpv callback fired after Dart had deleted it. The old task-removal path stopped the media service before disposing libmpv; audio_service can destroy the Flutter engine when its service stops with no activity attached. Shutdown now disposes the player before publishing idle to the service.

Phone orientation is restricted to portrait. The timer has wider usable space and separate gaps between switches. FFT batches were reduced from 20 to 4 frames and lookahead from 30 to 8 seconds; Dart interpolates the playback position between sparse player events. MediaStore initially selects one folder, and configured sources can be added and switched without losing saved track edits. Notification permission is requested explicitly. The launcher uses a centered white note.

An updated signed ARM64 APK is being verified on the connected phone. Do not treat remaining phone checks as passed until recorded below.

The first updated APK installed successfully over the original on Poco, with both audio and notification permissions granted. Device logs show libmpv audio callbacks stopping before Flutter teardown; the previous deleted-callback crash did not appear in that session. A visualization timer then exposed a read after database shutdown; sampling now returns immediately once shutdown starts. The final APK includes this guard.

Final APK checks: signature verification and 16 KB ZIP alignment passed; all seven ARM64 ELF libraries have LOAD alignment of at least 16 KB. Version code 5 installed successfully without uninstalling the app. Flutter analyze reported no issues. The connected Poco reported an active PLAYING media session with no error and one active Takt notification during playback. Audible output, theme switching and final recents-removal confirmation still require the user's result.

Additional regression coverage passed: system stop retains the live service, overlapping parent/subfolder sources include the same nested tracks, and scan completion after disposal cannot access a closed database. The themed folder selector can choose indexed Download directly without the system tree-picker restriction. External document providers with unsupported MediaStore volumes are rejected with a localized message. Final focused review found no important remaining issue in these changes.

## Android feedback follow-up, build 6

The user confirmed build 5 works on Poco. Build 6 gives each replacement cover a new cache identity and removes the previous owned image after the new copy succeeds. Folder selection and switching now live in settings. Shuffle stores complete cycles, restores them with the paused session, and uses the same order for both navigation directions. Returning to the preceding cycle does not insert songs added later. Queue edits preserve the current order.

Both visualizers mirror frequency bands horizontally, with bass at the center. Fast attack and a smooth release improve beat response; silence settles gradually. Increased amplitude and thicker line strokes improve visibility without overriding saved colors or opacity. Regression tests cover replacement bytes and cleanup, restored shuffle navigation, cycle-boundary additions, mirrored rendering, attack/release, and Android folder selection through settings.

Build 6 checks: the full Flutter suite passed 102 tests, flutter analyze reported no issues, and the focused reviewer found no remaining important defects after the boundary and artwork-storage corrections. APK and device checks are recorded after packaging.

Build 6 release APK completed successfully. APK signature and 16 KB ZIP alignment passed. Version 0.3.1, code 6, API 36 installed over the existing Poco app without uninstalling it. Launch succeeded and the new process log contained none of the checked Flutter errors or fatal crash markers. The changed interactions and visual motion still need the user's on-device assessment.
