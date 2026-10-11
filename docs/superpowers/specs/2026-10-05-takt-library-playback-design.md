# Takt library navigation and playback conveniences

Implementation authorized continuously by the user; stage 3.

Recently played records the latest actual play start for each track, not paused selection/restoration, and retains at most 500 IDs. Resume updates recency; position events do not. Missing tracks are not shown. Recently added stores first discovery time on Track, preserves it on file moves, and sorts newest first; existing tracks without timestamps retain stable title ordering behind newly discovered tracks.

Albums group by normalized album plus artist, artists by normalized artist. Missing tags use localized unknown labels. Cards show name, artist where relevant, track count and a local cover; entering a card shows its tracks and a back action. Search on cards matches group labels; track search inside groups retains existing behavior. These sections use the stage-two sidebar visibility/order settings.

Optional playback controls implement favorite toggle, sleep timer, visualizer toggle and compact mode. Favorite acts on the current track and stays synchronized with sidebar favorites. Visualizer toggle changes the foreground visualizer only; background demand stays independent. All controls use the layout zone order/visibility.

Sleep timer accepts minutes 1-240 with quick choices 15/30/60, pause/full-exit actions and optional last-15-second fade. Countdown uses absolute time, so suspension does not extend it. Temporary fade volume does not overwrite the saved user volume. At expiry pause first, restore normal volume, then optionally quit. Cancel restores normal volume; manual volume adjustment during fade cancels the timer without overriding that adjustment. Timer is session-local and does not restart after app relaunch. Cleanup cancels timers and restores temporary volume before normal exit. Async callbacks are generation guarded.

Compact mode reuses the same window and audio queue, initially about 420×240, with artwork/title/progress/previous/play/next/volume, restore-main action and close action. Optional always-on-top applies only while compact. Restore original main-window size and position and previous always-on-top state when leaving. A backend error produces localized feedback and leaves playback accessible. Close retains existing tray/quit policy. No second audio engine or window lifecycle is introduced.

Verification covers timestamp migration/preservation, history deduplication, group keys and missing tags, sleep countdown/fade/cancel/manual change/expiry, compact window restore and current queue continuity. Run all prior tests, native screenshots and release build. Documentation distinguishes compositor limitations and verified platform behavior.
