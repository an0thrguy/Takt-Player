# Frameless Linux window

Native bootstrap keeps the Takt title for task switching/rules but no longer creates GtkHeaderBar and disables window decorations. WindowOptions explicitly requests hidden title bars so window_manager cannot restore them. DragToMoveArea wraps the existing content heading for floating-window movement. Super+Q and tray behavior remain unchanged.

Verification: analyzer clean; shortcut/desktop tests pass (4 tests).
