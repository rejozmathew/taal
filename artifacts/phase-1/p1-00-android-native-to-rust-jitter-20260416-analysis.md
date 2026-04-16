# P1-00 Android Native-to-Rust Jitter Investigation

**Date:** 2026-04-16
**Status:** Completed with caveat
**Source measurement:** `artifacts/phase-0/p0-07-android-latency-20260416T084225229443.csv`
**Source summary:** `artifacts/phase-0/p0-07-android-latency-20260416T084225229443-summary.md`

## Scope

P1-00 exists to characterize the marginal Android p99 tail from Phase 0 before Phase 1 Practice Mode depends on the Android MIDI hot path.

The Phase 1 plan allows the investigation to use the existing Phase 0 latency harness or the first available Phase 1 MIDI path. At the time of this investigation, the Phase 1 MIDI mapper/runtime path does not exist yet, so the valid Android release-mode P0-07 artifact is the authoritative measurement input.

A fresh Android run was prepared on the same Samsung Fold 4 target:

- `adb devices -l` detected `SM-F936U1`, Android 16 / API 36.
- `flutter build apk --release` succeeded.
- `adb install -r build/app/outputs/flutter-apk/app-release.apk` succeeded.
- The release app was launched with `adb shell monkey -p dev.taal.taal 1`.
- `adb shell dumpsys midi` initially reported no connected Android MIDI devices while the phone was connected to the PC, so the first analysis used the existing release artifact.

The user then disconnected the phone, connected the Roland TD-27 through the Android USB path, captured a second 100-hit measured run, and reconnected the phone. The repeat raw artifacts were pulled into:

- `artifacts/phase-1/p1-00-android-repeat-latency-20260416T102923960859.csv`
- `artifacts/phase-1/p1-00-android-repeat-latency-20260416T102923960859-summary.md`

## Measured Path

The source artifact measured this path:

1. Android `MidiReceiver.onSend` filters NoteOn and records T0 with `System.nanoTime()`.
2. Native adapter posts the event to the Android main looper and emits it through the Flutter `EventChannel`.
3. Dart receives the event and immediately calls Rust through the synchronous `flutter_rust_bridge` latency function.
4. Rust records T1 with `clock_gettime(CLOCK_MONOTONIC)`, submits the pre-resolved `kick` hit to the Phase 0 runtime skeleton, drains events, then records T2.
5. Dart records T3 from a calibrated `Stopwatch` clock after the Rust call returns.

The measured `Native T0 -> Rust T1` segment includes Android main-thread scheduling, EventChannel delivery, Dart stream dispatch, and bridge entry. The current CSV does not split native-to-Dart delivery from Dart-to-Rust bridge entry.

## Segment Results

### Original CR-001 Source Run

100 measured hits, after 10 warm-up hits.

| Segment | Mean ms | p50 ms | p90 ms | p95 ms | p99 ms | Max ms |
|---------|---------|--------|--------|--------|--------|--------|
| Native T0 -> Rust T1 | 3.567 | 2.137 | 7.243 | 14.121 | 25.133 | 30.943 |
| Rust T1 -> Rust T2 | 0.014 | 0.011 | 0.020 | 0.022 | 0.072 | 0.085 |
| Rust T2 -> Flutter T3 | 0.030 | 0.026 | 0.051 | 0.071 | 0.099 | 0.107 |
| Native T0 -> Flutter T3 total | 3.611 | 2.218 | 7.293 | 14.180 | 25.161 | 30.982 |

### Repeat P1-00 Run

100 measured hits, after 10 warm-up hits.

| Segment | Mean ms | p50 ms | p90 ms | p95 ms | p99 ms | Max ms |
|---------|---------|--------|--------|--------|--------|--------|
| Native T0 -> Rust T1 | 5.809 | 2.295 | 20.955 | 23.010 | 28.851 | 31.314 |
| Rust T1 -> Rust T2 | 0.014 | 0.014 | 0.020 | 0.021 | 0.035 | 0.088 |
| Rust T2 -> Flutter T3 | 0.028 | 0.025 | 0.040 | 0.045 | 0.097 | 0.104 |
| Native T0 -> Flutter T3 total | 5.851 | 2.345 | 20.994 | 23.053 | 28.873 | 31.348 |

### Combined View

200 measured hits across the two Android release runs.

| Segment | Mean ms | p50 ms | p90 ms | p95 ms | p99 ms | Max ms |
|---------|---------|--------|--------|--------|--------|--------|
| Native T0 -> Rust T1 | 4.688 | 2.244 | 13.681 | 22.357 | 28.851 | 31.314 |
| Rust T1 -> Rust T2 | 0.014 | 0.012 | 0.020 | 0.021 | 0.072 | 0.088 |
| Rust T2 -> Flutter T3 | 0.029 | 0.025 | 0.042 | 0.064 | 0.099 | 0.107 |
| Native T0 -> Flutter T3 total | 4.731 | 2.300 | 13.740 | 22.385 | 28.873 | 31.348 |

## Tail Distribution

### Original CR-001 Source Run

| Threshold | Native -> Rust count | Total count |
|-----------|----------------------|-------------|
| > 1 ms | 86 / 100 | 87 / 100 |
| > 2 ms | 56 / 100 | 60 / 100 |
| > 5 ms | 11 / 100 | 11 / 100 |
| > 10 ms | 8 / 100 | 8 / 100 |
| > 15 ms | 5 / 100 | 5 / 100 |
| > 20 ms | 4 / 100 | 4 / 100 |
| > 25 ms | 2 / 100 | 2 / 100 |

### Repeat P1-00 Run

| Threshold | Native -> Rust count | Total count |
|-----------|----------------------|-------------|
| > 1 ms | 93 / 100 | 95 / 100 |
| > 2 ms | 66 / 100 | 67 / 100 |
| > 5 ms | 24 / 100 | 24 / 100 |
| > 10 ms | 20 / 100 | 20 / 100 |
| > 15 ms | 14 / 100 | 14 / 100 |
| > 20 ms | 11 / 100 | 11 / 100 |
| > 25 ms | 5 / 100 | 5 / 100 |
| > 40 ms | 0 / 100 | 0 / 100 |

### Combined View

| Threshold | Native -> Rust count | Total count |
|-----------|----------------------|-------------|
| > 10 ms | 28 / 200 | 28 / 200 |
| > 15 ms | 19 / 200 | 19 / 200 |
| > 20 ms | 15 / 200 | 15 / 200 |
| > 25 ms | 7 / 200 | 7 / 200 |
| > 30 ms | 2 / 200 | 2 / 200 |
| > 40 ms | 0 / 200 | 0 / 200 |

## Largest Outliers

| Sample | Note | Velocity | Native -> Rust ms | Rust processing ms | Rust -> Flutter ms | Total ms | Native share |
|--------|------|----------|-------------------|--------------------|--------------------|----------|--------------|
| 34 | 44 | 42 | 30.943 | 0.013 | 0.026 | 30.982 | 99.9% |
| 41 | 45 | 62 | 25.133 | 0.009 | 0.019 | 25.161 | 99.9% |
| 101 | 46 | 9 | 24.099 | 0.026 | 0.038 | 24.164 | 99.7% |
| 84 | 36 | 30 | 22.426 | 0.016 | 0.030 | 22.472 | 99.8% |
| 26 | 36 | 33 | 16.767 | 0.007 | 0.015 | 16.788 | 99.9% |

## Characterization

The Android p99 tail is localized before Rust entry.

In the original run, `Native T0 -> Rust T1` accounts for 25.133 ms of the 25.161 ms total at p99. In the repeat run, it accounts for 28.851 ms of the 28.873 ms total at p99. Across both runs, Rust processing and Rust-to-Flutter return are stable and remain below 0.11 ms even at their maximum observed values.

The dominant suspected segment is Android event delivery before Rust entry: `mainHandler.post`, Flutter `EventChannel` delivery, Dart stream dispatch, and the immediate bridge call into Rust. The current artifact does not isolate those subsegments, so the precise sub-cause inside the pre-Rust segment is not proven.

## Decision

The current Android platform-channel path is acceptable for continuing Phase 1 with a stronger documented caveat.

Reasons:

- p50 remains low across both runs: 2.218 ms original, 2.345 ms repeat.
- p95 remains below 25 ms across both runs: 14.180 ms original, 23.053 ms repeat.
- p99 is above the strict Phase 0 go line in both runs: 25.161 ms original, 28.873 ms repeat.
- The max observed total was 31.348 ms across both runs, below the 40 ms no-go line.
- Across 200 measured hits, 7 exceeded 25 ms and 0 exceeded 40 ms.
- Rust processing is not the source of the Android tail.
- No evidence requires reopening Flutter UI, Rust core ownership, or ADR-001's overall architecture decision.

No direct Android Native-to-Rust JNI optimization task is required now. The repeat run makes the Android caveat more concrete: this path is usable for Phase 1, but later full-path Android measurements should split the pre-Rust segment before calibration and animated Practice Mode depend on it.

A narrowly bounded optimization task should be created if a later full Phase 1 measurement, after MIDI mapping and real Practice Mode rendering exist, shows sustained p99 above 30 ms, total latency above 40 ms, or consistent frame drops on Android.

Frame-drop validation remains deferred to the first real animated Practice Mode path, as required by CR-001.

## Follow-Up Guidance

- Continue Phase 1.
- Do not broaden architecture work.
- When P1-06 adds Rust MIDI mapping, keep mapping work allocation-free on the hot path and remeasure if new Android tail behavior appears.
- On the next Android latency measurement task, add one extra timestamp at Dart event receipt to split `Native callback -> Dart delivery` from `Dart -> Rust entry`.
