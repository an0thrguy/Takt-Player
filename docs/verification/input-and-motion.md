# Input and motion update - 2026-10-04

Playback activators decline matching while EditableText owns focus. Returning early from a CallbackShortcuts callback was insufficient: the matched shortcut had already consumed Space. Regression observes the hardware-key handled result for both search and playlist name, while preserving playback controls and global Super+Q.

Internal navigation, playlist-create/search forms, settings drawer, dialog routes and popup menus use 220ms transitions. Outgoing navigation pages cannot receive pointer events or appear in accessibility semantics. Native system/file/tray menus retain system-managed presentation. Language uses the shared rounded monochrome glass popup; both locale choices persist. Common dialog and input shapes follow the theme. Text dialog controllers remain alive until the outgoing transition completes.

Verification: 43 unit/widget tests pass; analyzer reports no issues. Native approved_update integration test passes in dark/light themes. Fresh source review found no important issues.
