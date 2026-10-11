# Takt for Android 16

## Purpose

Build an installable ARM64 APK for Poco X7 and Samsung S24 Ultra running Android 16. Keep the existing Linux version working. The application remains a local music player with Russian and English interfaces and independent data on each device.

## Mobile interface

Adapt the existing rounded monochrome interface, light and dark themes, accent colors and configurable glass to a phone screen. Use bottom navigation for library, playlists, favorites and settings. Search stays above the track list. A persistent mini player shows artwork, track title and symmetrical previous, play/pause and next controls. Tapping it opens the full player with seeking, queue mode, queue access and visualization.

Keep the existing appearance options where they apply to a phone, including wallpaper, background visualization and separate visualization color. Desktop window geometry and tray settings do not appear on Android. Remove the application's volume button and slider. Physical volume buttons control Android media volume.

Tap a track to play. Long press its row to select. Tap the three-line handle to open actions; hold it to reorder a queue or playlist. Provide animated rounded dialogs and sheets, including playlist creation and artwork preview. Phone layouts respect system bars, the keyboard and gesture navigation.

## Library and personal data

Request audio access and query Android's system media library across accessible shared storage. Do not require unrestricted access to all files. Refresh after media changes and on returning to the application. Explain denied permissions and provide a way to retry. Android does not expose other applications' private storage as a music library.

Keep playlists, favorites, custom titles and custom artwork in application storage. Personal metadata edits never rewrite original music files. Preserve the existing duplicate prevention and queue order rules. Artwork selection includes a preview before confirmation. Device file deletion requires confirmation and Android's own approval when required.

## Playback lifecycle

Restore the queue, current track and position without autoplay. Default to repeating the current queue and retain the other playback modes. Background playback continues with notification and lock-screen previous, play/pause and next controls.

Back from the home screen backgrounds the app. Removing it from recents stops playback, saves the queue and terminates the playback service. Opening it again restores a paused player. Disconnecting headphones, incoming calls and loss of audio focus pause playback without automatic resumption.

Retain the sleep timer. Keep online artwork lookup disabled until the user enables it in settings. Visualizers retain Cava-style bars, linear and solid options. They must represent the playing audio rather than a decorative animation, and stop processing when not needed.

## Platform approach

Extend the existing Flutter application rather than maintain a separate Android app. Reuse track models, queue rules, storage, playlists and appearance settings. Separate Linux startup and integrations from Android startup. Use Android media-library access for discovery, a playback service for background media controls and an Android-compatible analysis implementation instead of Linux subprocesses.

This preserves shared behavior better than a separate Kotlin application. Simply building the current desktop entry point would not provide Android discovery, background lifecycle or a usable phone interface.

## Delivery and verification

Deliver an ARM64 APK and concise installation instructions. Verify Android build configuration, permissions, scanning, persistence, mobile layout, playback controls and the existing Linux tests. Record any behavior requiring a physical device separately from checks performed locally. Installation and real-device testing on both named phones are the final acceptance checks.

Acceptance requires audible playback, paused queue restoration, background controls, correct shutdown after removal from recents, permission recovery, working artwork preview and no application volume control.
