# Editing Takt

The application source has English comments describing responsibilities, customization points and important invariants. Comments describe behavior; the tests verify it. Start with this map before editing individual widgets.

## File map

| Area | File | What to change here |
| --- | --- | --- |
| Startup and shutdown | `lib/main.dart` | Window dimensions, event wiring, paused restoration, save interval, full exit |
| Interface | `lib/ui/app.dart` | Layout, colors, translations, menus, dialogs and gestures |
| Track and playlist data | `lib/core/track.dart` | Metadata fields and JSON defaults |
| Persistence | `lib/core/store.dart` | SQLite snapshots, transactions and migrations |
| Sources and library | `lib/library/library.dart` | Scan interval, supported extensions, title sorting, playlists |
| First-launch discovery | `lib/library/discover_music.dart` | XDG Music and fallback directory discovery |
| Physical deletion | `lib/library/delete_tracks.dart` | Confirmed deletion and per-file error handling |
| Playback adapter | `lib/playback/engine.dart` | libmpv integration and independent Takt audio profile |
| Queue | `lib/playback/queue.dart` | Playback modes, duplicate prevention, shuffle and transitions |
| Visualizer data | `lib/analysis/audio_analysis.dart` | PCM sample rate, RMS window, amplitude gain and sample count |
| Covers | `lib/artwork/artwork.dart` | Local cover priority, network lookup, limits and cancellation |
| Linux tray | `lib/platform/desktop.dart` | Tray icon/menu, close behavior and host availability |
| Hyprland shortcut | `tool/super-q.py` | Focused-window full exit; current Lua-based Hyprland dispatch |
| Linux bootstrap | `linux/runner/` | GTK application startup and native window setup |
| Launch/install/package | `tool/*.sh` | Release launcher, optional user installation, portable archive |

## Interface customization

In `lib/ui/app.dart`:

- `initState`: first-launch settings; existing saved values take precedence.
- `build`: light/dark surfaces, font, outer padding and panel arrangement.
- `_glass`: blur strength, opacity and corner radius.
- `_sidebar` / `_nav`: left panel size, buttons and settings placement.
- `_body` / `_tab`: heading, theme switch, playlists, search and reorder animation.
- `_row` / `_art`: track row spacing, artwork, selection and drag handle.
- `_player`: bottom artwork, title, transport controls and visualizer arrangement.
- `_seek` / `SeekPainter`: pointer-to-time mapping and straight/wavy timeline geometry.
- `_volume` / `_settings`: popup controls and persisted preferences.
- `WavePainter` / `WaveSignal` / `SignalTween`: solid visualizer shape and smoothing.

Settings keys are `dark`, `locale`, `accent`, `volume`, `closeToTray`, `onlineArtwork` and `wave`. Keep their meaning consistent across UI, startup and desktop lifecycle. `tr(ru, en)` supplies both translations. Changing a default affects new installations; it does not overwrite existing preferences.

## Invariants to preserve

1. Restoring a session never starts playback automatically.
2. Track IDs, not paths or titles, connect playlists and queue entries.
3. `_serial` in the queue prevents overlapping playback commands; generation checks reject obsolete EOF events.
4. Rename/artwork changes are local overrides, not media-tag edits.
5. File deletion requires confirmation and reports each failure separately.
6. Online artwork is disabled by default; revocation cancels pending requests.
7. The drag handle must not have a competing long-press tooltip recognizer.
8. Takt's dedicated audio-client name must be set before opening the first file.
9. Normal window close can hide to tray; Super+Q/SIGTERM use the shared full-exit routine.

For new formats, add the extension in `library.dart`, then add a synthetic codec fixture in `tool/generate_fixtures.py` where FFmpeg supports its encoder. A recognized extension does not guarantee decoding support.

## Dependencies and generated files

`third_party/cnativeapi` is a vendored dependency, not application UI code. Its original comments and licenses are retained. Takt's Linux tray changes are described in `third_party/README.md`. Generated bindings and Flutter-generated Linux registrants should not be edited by hand. Change their upstream configuration or narrowly documented native patch instead.

## Verify an edit

```sh
flutter analyze
flutter test
flutter build linux --release
```

Use `integration_test/audio_output_test.dart` for the real system audio stream and the other native checks in `integration_test/` when changing playback or tray behavior. These tests require Linux desktop/audio services. The background test normally takes 15 minutes.

`./tool/package.sh` creates the local release archive. `./tool/install.sh` optionally installs the bundle into the current user's application menu. The Hyprland helper is tied to a configured script path; update that path if moving the checkout.
