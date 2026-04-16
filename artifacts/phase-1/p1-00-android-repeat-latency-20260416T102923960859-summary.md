# P0-07 Android Latency Measurement

**Date:** 2026-04-16T10:29:42.018690
**Build mode:** Release
**Warm-up hits discarded:** 10
**Measured hits:** 100
**Raw CSV:** `Downloads/Taal/phase-0/p0-07-android-latency-20260416T102923960859.csv`

## Hardware / Software Matrix

| Item | Value |
|------|-------|
| Host OS | BP2A.250605.031.A3.F936U1UES9IZC1 |
| MIDI device | Roland TD-27 |
| MIDI device id | 5 |
| Measurement clock | Android System.nanoTime; Flutter T3 calibrated from Dart Stopwatch |
| Dart clock calibration uncertainty | 0.029 ms |

## Latency Summary

| Segment | p50 ms | p95 ms | p99 ms |
|---------|--------|--------|--------|
| Native T0 -> Rust T1 | 2.295 | 23.010 | 28.851 |
| Rust T1 -> Rust T2 | 0.014 | 0.021 | 0.035 |
| Rust T2 -> Flutter T3 | 0.025 | 0.045 | 0.097 |
| Native T0 -> Flutter T3 total | 2.345 | 23.053 | 28.873 |

## Notes

- Each hit is routed through the Phase 0 Rust runtime skeleton using a pre-resolved `kick` lane.
- Full MIDI note-to-lane mapping remains deferred to Phase 1.
