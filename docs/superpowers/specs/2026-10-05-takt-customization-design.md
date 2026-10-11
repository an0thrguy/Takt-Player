# Takt: customizable interface update

Status: awaiting review of this written specification. Product code has not been changed for this update.

## Intent and agreed sequence

Keep the rounded monochrome glass identity while improving responsiveness and letting users customize appearance and controls. Target Linux first, including Arch and the Ubuntu 22.04 release baseline. Preserve music, queue, playlists, favorites and existing preferences on upgrade. Russian and English remain supported. A report of icons lagging with glass is a symptom to investigate, not an established diagnosis.

Deliver three independently verified stages. This document defines stage 1 in detail and records the agreed scope of stages 2 and 3; those stages require their own detailed specifications before implementation. Do not add unrequested SoundCloud services or streaming: the reference concerns visual hierarchy and controls only.

## Stage 1: responsiveness and controls

### Glass performance

Reproduce the report with glass enabled and disabled, during scrolling, opening menus and playback with the visualizer active. Compare profile-mode frame timings; collect GPU, session type, compositor and scaling information when the affected machine becomes available. Do not call a guessed optimization a confirmed fix for that machine.

The current `GlassSurface` clips and blurs its backdrop with a fixed sigma of 18. Keep sharp foreground icons and text, constrain blurred areas, and isolate frequently repainted visualizers where measurements justify it. Do not blur icon content. Add manual Quality/Balanced/Economy profiles, default Balanced: respectively blur sigma 18/10/0 and visualization refresh ceilings 60/30/15 Hz, without changing audio playback. Preserve the existing glass-enabled preference. Existing adaptive amplitude handling remains.

### Playlist creation

Both the plus button and sidebar action open the same centered dialog. Replace the inline creation field; the track search remains present. Use the common rounded monochrome glass styling and opening/closing animation. Autofocus the name field; Enter creates a nonempty trimmed name, Escape or Cancel dismisses without changes. Match current playlist naming rules rather than adding new duplicate-name restrictions. Successful creation selects the new playlist. Prevent multiple dialogs from repeated clicks. Clamp dialog width to the available window; small windows must remain usable.

### Volume

Default behavior combines click-to-open slider and mouse wheel over the volume control. A settings choice enables a permanently visible slider; wheel adjustment can be independently enabled or disabled. Clamp 0-100; use the existing 5-point keyboard step for wheel detents. Trackpads accumulate scroll distance to avoid abrupt changes. All methods use one existing volume update path and stay synchronized with MPRIS. Scrolling elsewhere continues to scroll the track list. Tooltip and accessible labels report volume.

### Sidebar resize

At desktop widths, drag a visible-on-hover boundary handle to resize the sidebar. Persist the final width, not every pointer event. Default expanded width remains 178 logical pixels; supported range 150-320, further constrained so the content keeps at least 360 pixels. Provide a collapse control; collapsed width 62. When the window is too narrow, temporarily use the collapsed layout without overwriting the user's saved expanded width. Resizing is bounded by the current window and does not alter track ordering or playback.

### Artwork picker

Extend the existing parented native artwork picker to a resizable, movable window with an initial 800×600 size, clamped to the monitor. It stays above its parent on X11 and Wayland through transient/modal ownership, without a global always-on-top setting. Browse folders on the left; show the selected image, filename and dimensions in a large preview on the right. Preserve image aspect ratio and load a bounded-size preview rather than decoding full-size pixels unnecessarily. Selection previews only; application requires an explicit Choose action. Double-clicking a folder navigates; double-clicking an image previews it. Choose is disabled for folders, invalid images and no selection. Cancel, Escape or window close leave the artwork unchanged. Missing/unreadable files show a localized message, and later selection still works. Reuse the existing copy-to-app-storage behavior when confirmed. Match light/dark monochrome styling as closely as the GTK implementation allows; document any native styling limit.

### Close button

Place a standalone close icon at the upper-right inside the main content. Do not restore the system title bar. Default visible; an option reveals it on pointer hover or keyboard focus. Touch interaction must still have a visible close action. Route it through the existing close policy: tray hiding where available, configured full exit otherwise, with the existing no-tray safeguard. Preserve Super+Q explicit exit. Exclude the button from the draggable heading area.

### Animations

One enabled switch and Fast/Normal/Smooth speed preference control shared internal transitions, default Normal. Durations: 120/220/320 ms. Disabled uses zero-duration transitions. Input remains available promptly; dismissal reverses cleanly and rapid toggles do not stack overlays. Native picker window movement remains compositor-controlled; do not promise Flutter animations for OS-level movement.

### Structure, settings and verification

Keep playback/library behavior in current core services. Extract focused dialog and resizable-sidebar widgets from the large `lib/ui/app.dart` as needed for these flows, without unrelated restructuring. Centralize presentation preference defaults and validation; missing keys retain prior behavior except explicitly agreed new defaults. Keep comments in English. The GTK picker stays behind `takt/artwork_picker`; preview state stays local until confirmation.

Tests cover dialog cancellation/creation and text input, volume bounds and MPRIS synchronization, resize persistence and narrow-window behavior, close-policy routing and animation disablement. Run analysis and relevant existing tests, native light/dark checks, and Ubuntu 22.04 compilation. Verify picker preview, cancellation and ownership manually on Linux. Compare frame timings in matching scenarios before/after; absence of reproduction is a recorded limit, not proof that every Arch system is fixed. Release publication is a separate action after verification; do not overwrite v0.2.0.

## Stage 2: appearance and editing (agreed scope)

- Settings adjust appearance and behavior; a dedicated Edit interface mode rearranges controls within sidebar, main area and playback zones with alignment constraints. Done commits; Cancel restores; Reset restores the layout. Essential playback access remains available.
- Global glass color, opacity, blur and border; per-surface overrides for sidebar, playback panel and menus. Separate window opacity/background color from internal glass opacity. Native window transparency requires compositor/backend verification before promising support.
- Separate light/dark appearance profiles with a Copy from other theme action. Customize rounding, text size and row density.
- Wallpapers support fit/fill, dimming, blur and opacity. A disabled-by-default background frequency-bar visualizer supports full-window and bottom-growing layouts, independent height/color/opacity/sensitivity/smoothing. Wallpaper, background visualizer and foreground panels can coexist. Reuse the spectrum analysis; do not decode the track a second time for each visualizer.
- Live appearance preview with Save/Cancel restores the pre-edit state on cancellation. Exact persistence and external-change handling belong to the stage 2 specification.
- Named presets save Appearance, Layout or Both, with export/import and section-specific resets. Validate imported data; theme presets do not modify the library or playback queue.

## Stage 3: library navigation and playback (agreed scope)

- Sidebar sections: Recently played, Recently added, Albums and Artists, all hideable and reorderable. Detailed grouping and history rules belong to the stage 3 specification.
- Optional playback controls: favorite toggle, sleep timer, visualizer toggle and compact-mode toggle. Hideable/reorderable within their zone.
- Sleep timer offers pause or full exit and optional gradual volume reduction. Restore-volume and timer-lifecycle rules must be specified before implementation.
- Compact mode provides a small player window with artwork, title, controls and progress, plus optional always-on-top. Share one playback state; do not spawn a second audio player. Window lifecycle and layout constraints need a stage 3 design.

## Review criteria

Stage 1 is complete when the six UI improvements work in both languages/themes, persisted settings survive restart, the release baseline compiles, current playback tests stay green, and performance evidence is recorded with its limits. Stages 2 and 3 remain scheduled scope, not implicit unfinished work in the stage 1 release. No implementation plan or product changes are approved merely by the creation of this document.
