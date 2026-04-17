# CR-007: P1-23 Touch Input Scoring Integration

**Date:** 2026-04-17
**Triggered by:** P1-23 On-Screen Tap Pads blocker
**Documents affected:** docs/specs/engine-api.md, docs/specs/midi-mapping.md, plans/phase-1.md, ARCHITECTURE.md, STATUS.md

## Problem

P1-23 requires no-kit touch practice to use the same timing feedback and scoring as MIDI input. `plans/phase-1.md` already says taps generate `InputHit` events and that scoring works using touch input only.

The current P1-12 Practice Mode implementation is a UI surface that consumes prepared timeline notes and engine feedback markers. `ARCHITECTURE.md` explicitly leaves the Rust session and MIDI mapper wiring to a later runtime adapter. As written, P1-23 could be interpreted as only a reusable tap-pad widget, which would not satisfy the P1-23 acceptance criteria and would force a later unnamed dependency for scoring integration.

The engine API also describes `InputHit` in MIDI-specific wording even though the struct shape already supports pre-resolved lane hits. Implementing touch scoring without clarifying that source-neutral meaning would risk silently widening a frozen runtime contract.

## Proposed Change

Clarify P1-23 as the narrow owner of both:

1. The reusable touch-responsive tap-pad input surface.
2. The thin Flutter-facing Practice Mode runtime-session adapter/bridge needed to route input into the Rust `Session`.

The adapter scope is limited to orchestration:

- MIDI path: native MIDI event -> Rust `MidiMapper` -> `MappedHit` -> existing `InputHit` -> Rust `Session`.
- Touch path: tap-pad lane selection + touch timestamp/velocity -> existing `InputHit` with `midi_note: None` -> Rust `Session`.
- Both paths drain the same Rust `EngineEvent` stream for feedback and stop the same Rust session for `AttemptSummary`.

Flutter remains responsible for UI rendering, touch interaction, and bridge calls. Rust remains responsible for mapping MIDI, session lifecycle, timing, grading, scoring, summaries, and persistence APIs. No scoring, grade computation, combo logic, or attempt-summary computation moves into Flutter.

## Impact

- P1-23 is implementable without inventing an unnamed later runtime-session dependency.
- The frozen `InputHit`, `EngineEvent`, session lifecycle, and `AttemptSummary` shapes remain unchanged.
- `InputHit` wording becomes source-neutral: it represents a semantic lane hit from MIDI mapping or touch input, with a monotonic timestamp aligned to the session clock.
- MIDI mapping ownership remains unchanged. Touch pads do not use `MidiMapper`; they already know the selected semantic lane from the UI layout.
- No ADR is required because the accepted Flutter + Rust + native ownership split is preserved.
- No P1-23 implementation code is started by this CR.

## Applied Clarification

`plans/phase-1.md` now states that P1-23 includes the tap-pad surface plus the thin Practice Mode runtime-session adapter/bridge for both MIDI-derived and touch-generated hits.

`docs/specs/engine-api.md` now clarifies that `InputHit` is source-neutral after lane resolution and that touch hits use `midi_note: None`.

`docs/specs/midi-mapping.md` now clarifies that the runtime adapter converts `MappedHit` values into `InputHit` values, while touch input bypasses `MidiMapper` and submits already selected lane hits.

`ARCHITECTURE.md` now names the P1-23 Practice runtime input adapter and records the MIDI/touch input flow into the Rust session.

`STATUS.md` now records CR-007 as applied and marks P1-23 ready to implement, with implementation still not started.

## Status
- [x] Proposed
- [x] Approved
- [x] Applied
