# Takt appearance and layout customization

Status: implementation authorized by the user's continuous-execution instruction. Stage 2 of the agreed update.

## Behavior

Keep data and playback settings intact. Appearance settings operate on a draft: edits preview live; Save persists; Cancel or dismiss discards the draft. A theme switch changes which appearance profile is edited. Light and dark profiles store background color, window opacity, glass color/opacity/blur/border, wallpaper and background visualizer settings separately. Copy from other theme copies appearance only, never theme identity or playback settings. Existing theme/accent/glass choices remain the migration fallback.

Provide global glass settings and opt-in overrides for sidebar, player and menus. Foreground text uses contrast derived from the selected theme; icons remain crisp. Wallpaper is local, copied into application-managed storage after Save, with fit/fill, dimming, blur and opacity. Background visualization reuses the existing spectral sample provider; no second decoder. Full-window bars and bottom-growing bars are independent of the playback visualization. Both can coexist with wallpaper. Default background visualization disabled.

Window opacity is distinct from internal background/glass opacity. Set native window opacity where the window manager supports it; backend errors keep the window visible and produce a localized status message. Do not promise that every Wayland compositor implements native opacity. Internal colors/opacity continue working without that feature. Clamp window opacity to 0.25-1 so the main window cannot become inaccessible; glass opacity 0-1; blur 0-30; corner radius 0-36; text scale 0.8-1.5; row density Compact/Normal/Comfortable. Performance mode caps actual blur/refresh to protect responsiveness.

Edit interface mode works within predefined zones. Sidebar section order/visibility, optional playback-control order/visibility, sidebar width and panel sizes form the layout profile. Keep play/pause and exit accessible. Drag handles are editing controls, never substitute for ordinary playback buttons. Done applies; Cancel restores; Reset layout restores defaults. Save layout with appearance or separately in a named preset. On narrow windows adapt safely; do not persist temporary constraints.

Presets store Appearance, Layout or Both. Create/rename/delete locally, export/import JSON through an explicit file choice. Imported values are validated and unknown keys ignored; do not import filesystem locations from untrusted presets or execute anything. Images are not embedded in JSON; local image paths remain local and missing images fall back to plain background. Reset per appearance section is supported. Selecting presets inside the appearance editor previews them until Save.

## Components and checks

Use a validated AppearanceProfile model and AppearanceDraft controller; AppearanceEditor owns draft lifecycle. BackdropLayers renders wallpaper and bars independently behind content. PresentationScope distributes appearance plus stage-1 motion/performance preferences. GlassSurface accepts a surface identity to resolve overrides. Layout model centralizes zone order and mandatory elements; LayoutEditor manipulates a draft. PresetRepository uses existing store and validates import schema version 1.

Tests prove Save/Cancel/dismiss, separate themes/copy, profile numeric validation, preset roundtrip without library mutation, reorder/hide with mandatory controls, missing-wallpaper fallback and both background modes. Run existing playback tests, analysis and native light/dark/narrow screenshots. Record native transparency limitations honestly.
