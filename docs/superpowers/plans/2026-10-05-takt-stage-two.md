# Takt Stage Two Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Continue inline without approval pauses as explicitly requested by the user.

**Goal:** Ship user-controlled appearance, backgrounds, layouts and presets.
**Architecture:** Validated profile/draft models feed a shared presentation scope; dedicated editors separate draft state from stored settings. The existing audio analysis is shared by foreground/background visualizers.
**Tech Stack:** Existing Flutter/Dart, window_manager, file_picker, SQLite store.
**Spec:** docs/superpowers/specs/2026-10-05-takt-appearance-design.md

## Global Constraints

Keep Russian/English, Linux/Ubuntu 22.04, current music data and paused restoration. Window opacity 0.25-1, glass opacity 0-1, blur 0-30, radius 0-36, text scale 0.8-1.5. Background visualization off by default. Use existing dependencies and English comments. No external publication during implementation.

## Review Focus

Cancel after a theme/preset switch restores pre-editor state; invalid numeric/JSON inputs never break rendering; image selection remains local and copy errors do not erase prior image; hidden/reordered controls retain accessible play/exit; unsupported native opacity leaves a usable window.

## Tasks

- [x] Task 1: Add failing tests for AppearanceProfile.fromMap validation, AppearanceDraft Save/Cancel and per-theme copy. Implement lib/ui/appearance.dart with toMap, clone and validated accessors. Add presets model with schema 1 import/export and tests; whitelist keys, reject invalid top-level/schema and exclude imported external image paths. Run focused tests.
- [x] Task 2: Add editor widget tests for immediate preview, saved persistence and cancellation. Implement lib/ui/appearance_editor.dart with localized grouped controls, global/per-surface glass, theme copy and section reset; call root preview/apply/cancel callbacks. Include owned text/color controllers and file-choice wallpaper flow. Run tests.
- [x] Task 3: Add background-mode/missing-image tests. Implement lib/ui/backdrop_layers.dart with local image fit/fill/dim/blur and shared-spectrum bars in full/bottom modes. Extend PresentationScope and GlassSurface with profile/surface identity; wire window-manager opacity callback with visible fallback. Run tests and native check.
- [x] Task 4: Add layout validation/reorder/cancel tests. Implement lib/ui/layout_preferences.dart and lib/ui/layout_editor.dart; predefined zones, hideable navigation/optional playback, immutable play/exit access, sizing. Wire layout to root navigation/player composition. Run tests at narrow/wide sizes.
- [x] Task 5: Add preset editor/JSON roundtrip tests. Integrate create/rename/delete/import/export and scope selector Appearance/Layout/Both; preserve library/settings keys. Update documentation; run complete suite, analyzer and native screenshots. Record rulings in stage-one ledger until a dedicated stage-two ledger is opened.

Execution complete in source. Final local verification and package evidence are consolidated in docs/verification/2026-10-06-customization-review.md. Independent review request failed due to service usage limit; this is an explicit verification limitation. No publication performed.
