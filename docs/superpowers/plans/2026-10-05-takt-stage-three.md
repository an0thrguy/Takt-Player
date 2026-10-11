# Takt Stage Three Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline. User explicitly authorized continuous execution.

**Goal:** Add library navigation, optional controls, sleep timer and compact player.
**Architecture:** Focused library view/history service and sleep timer service feed existing queue/UI. A tested window boundary changes size/state for the single compact window.
**Tech Stack:** Existing Flutter/Dart, SQLite store, window_manager, media_kit.
**Spec:** docs/superpowers/specs/2026-10-05-takt-library-playback-design.md

## Global Constraints

Russian/English, Ubuntu 22.04 baseline, no autoplay on restoration, one audio engine. History max 500. Sleep timer 1-240 minutes, optional final 15-second fade, session-local. Compact starts 420×240, preserves main window state. No publishing without a separate request.

## Review Focus

Position notifications do not reorder history; identical album names by different artists do not merge; missing timestamps and tags have deterministic fallback; manual volume adjustment/cancel during async fade cannot trigger late exit; compact failure still restores accessible controls and window state.

## Tasks

- [x] Task 1: Write failing tests for LibraryViews history dedup/limit, group identity and recently-added sorting. Add Track.addedAt with backward-compatible JSON; set on first scan and retain on moves. Implement lib/library/library_views.dart with recordPlay, recent, added, groups and grouped-track methods. Wire actual-play transitions and cards into sidebar views. Run library/shell/history tests.
- [x] Task 2: Write SleepTimer tests using an injected clock and explicit tick for 15-second fade, expiry pause-before-restore/quit, cancel and generation guards. Implement lib/playback/sleep_timer.dart, owned by main with widget fallback for tests. Add localized timer dialog and optional playback actions. Keep fade volume temporary and cancel on manual volume change. Run timer/queue/MPRIS tests.
- [x] Task 3: Write compact boundary fake-window tests for enter/leave restoring geometry/top state and partial-failure rollback. Implement lib/platform/compact_window.dart and lib/ui/compact_player.dart; share current queue and volume. Add always-on-top preference and optional compact control. Run compact tests and native smoke.
- [x] Task 4: Run analyzer, full suite, native all-stage screenshots and Linux release build. Request one independent final review covering all three stages and ledger rulings. Address material findings with reproductions and rerun relevant/full checks. Update user/install/code docs and give local build/results with verified limits; do not claim untested remote Arch lag issue fixed.

Execution complete in source. Final local verification and package evidence are consolidated in docs/verification/2026-10-06-customization-review.md. Independent review request failed due to service usage limit; this is an explicit verification limitation. No publication performed.
