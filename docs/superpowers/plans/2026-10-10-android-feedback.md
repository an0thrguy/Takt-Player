# Android phone feedback fixes

Scope: Android update of 0.3.1; no publication until the user tests the APK.

1. Investigate native crashes using a connected Poco or emulator; retain a clear unverified status if device logs are unavailable.
2. Add an explicit notification permission request and verify media-session notification controls.
3. Lock phone UI to portrait orientation and simplify track selection.
4. Make timer controls fit narrow screens and larger text.
5. Interpolate the visualizer playback clock, reduce analysis batching/lookahead and bound work.
6. Discover one music source initially; support adding and switching configured folders without losing metadata or playlists.
7. Replace Android adaptive artwork with a centered white music note.
8. Run regression tests, analyze, compile/sign ARM64 APK with the existing key; do not publish.
