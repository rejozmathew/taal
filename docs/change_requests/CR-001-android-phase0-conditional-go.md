# CR-001: Android Phase 0 Conditional Go

**Date:** 2026-04-16
**Triggered by:** P0-09 ADR-001 finalization
**Documents affected:** docs/adr/001-platform-architecture.md, plans/phase-1.md, STATUS.md

## Problem

Phase 0 produced valid Windows and Android latency measurements for the MIDI input -> Rust -> Flutter feedback path.

Windows is a clean pass:
- Device: Roland TD-27 on Windows
- Total latency: p50 0.154 ms, p95 1.006 ms, p99 2.064 ms
- Result: comfortably below the strict `< 25ms` go criterion

Android is acceptable but marginal:
- Device: Roland TD-27 on Samsung Fold 4 (`SM-F936U1`, Android 16/API 36)
- Total latency: p50 2.218 ms, p95 14.180 ms, p99 25.161 ms
- Result: 0.161 ms above the strict `< 25ms` go criterion, but far below the `> 40ms` no-go line

ADR-001 also names a frame-drop / animation check as part of the spike requirements, but `plans/phase-0.md` did not include a Phase 0 task for a real animated Practice Mode path. Phase 0 did not build the animated Practice Mode surface, so that criterion cannot be honestly closed in Phase 0 without expanding scope.

## Proposed Change

Accept the Flutter + Rust platform architecture as a Phase 0 conditional go:

- Keep Flutter + Rust as the selected architecture.
- Do not reopen architecture selection.
- Do not broadly loosen the latency criteria.
- Record Android p99 `25.161 ms` as a marginal Phase 0 miss against the strict `< 25ms` line.
- Require an early Phase 1 Android Native-to-Rust jitter investigation before relying on the Android MIDI hot path for user-facing Practice Mode flows.
- Defer the frame-drop / animation criterion out of Phase 0 and validate it on the first real animated Practice Mode path, using the existing Phase 1 visual practice tasks.
- Update ADR-001 status line only to reflect acceptance with this conditional caveat.

## Impact

- P0-09 can complete without inventing a new architecture alternative.
- Phase 1 receives a narrow early task to characterize Android p99 jitter.
- The Phase 1 jitter task is a targeted follow-up, not a fallback architecture investigation.
- The frame-drop requirement remains valid, but it is validated when the real animated Practice Mode surface exists.
- No implementation starts as part of this CR.

## Status

- [x] Proposed
- [x] Approved
- [x] Applied
