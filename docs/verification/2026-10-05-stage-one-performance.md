# Stage-one verification

2026-10-05. Local Arch Linux, native Flutter profile mode; synthetic 500-track search/select/scroll scenario. Neither report includes private music metadata.

| Metric | Original | Updated |
|---|---:|---:|
| Search to settled UI | 216.817 ms | 67.809 ms |
| Track tap to updated frames | 49.382 ms | 65.584 ms |
| Median total frame span | 11.789 ms | 11.189 ms |
| p95 total frame span | 20.010 ms | 30.928 ms |
| Samples | 77 | 72 |

These small mixed-workload samples do not prove a universal glass performance improvement: p95 was worse in this run. Further checks on the reporting user's GPU/compositor are needed. A deterministic widget regression proves that position-only events no longer rebuild track rows. Economy skips blur; spectrum refresh is capped at 15/30/60 Hz including smoothing. Audio decoding/playback remains unchanged.

52 Dart tests passed; analyzer clean. GTK preview helper tested scaled decode, dimensions and bad/missing file. Real GTK picker harness tested transient ownership, resizing, preview without apply, explicit Choose, and completion on parent destruction. System image decoder on current Arch uses D-Bus, so native tests run with ordinary desktop access rather than the filesystem sandbox. Actual manual movement depends on the compositor; no new compositor rule is installed.
