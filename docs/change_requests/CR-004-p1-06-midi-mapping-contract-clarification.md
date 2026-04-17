# CR-004: P1-06 MIDI Mapping Contract Clarification

**Date:** 2026-04-16
**Triggered by:** P1-06 pre-implementation contract review
**Documents affected:** docs/specs/midi-mapping.md, STATUS.md

## Problem

P1-06 requires a Rust MIDI mapping engine that consumes `DeviceProfile` records. The authoritative MIDI mapping spec was not complete enough to implement that task without guessing:

- `DeviceProfile` referenced `cc_map: Vec<CcMapping>`, but `CcMapping` was not defined.
- The same profile used `created_at: DateTime` and `updated_at: DateTime`, but `DateTime` had no contract-level representation in this spec.
- The spec did not state whether `created_at` and `updated_at` are required for Phase 1 local loading.

Implementing P1-06 against the previous text would require inventing generic CC mapping behavior or timestamp parsing rules outside the contract.

## Proposed Change

Make the smallest clarifications needed to unblock P1-06:

1. Reserve generic `cc_map` for a future spec revision instead of defining unused Phase 1 behavior.
2. State that P1-06 does not define or use `CcMapping`; hi-hat CC4 behavior is modeled only through `HiHatModel.source_cc`.
3. Define `DateTime` in this spec as an RFC 3339 UTC timestamp string.
4. Clarify that `created_at` and `updated_at` are required on preset and persisted Phase 1 `DeviceProfile` records, but are metadata only and must not affect mapping behavior.

## Impact

P1-06 can proceed using the existing Phase 1 mapping scope: `note_map`, `hihat_model`, `input_offset_ms`, `dedupe_window_ms`, `velocity_curve`, and raw MIDI events.

No product scope is added. Generic CC mapping remains deferred. P1-08 can persist the required timestamp metadata later without changing P1-06 mapping semantics.

## Applied Clarification

`docs/specs/midi-mapping.md` now states:

- `cc_map` is reserved for a future generic controller-mapping contract.
- No `CcMapping` type is part of the Phase 1 contract.
- Phase 1 `DeviceProfile` records must omit `cc_map`; any present `cc_map` field is unsupported until a future spec revision defines it.
- Hi-hat openness is modeled only by `hihat_model.source_cc`.
- `DateTime` is an RFC 3339 UTC timestamp string, for example `2026-04-16T12:34:56Z`.
- `created_at` and `updated_at` are required for Phase 1 preset and persisted profile loading, but must not affect MIDI mapping behavior.

## Status

- [x] Proposed
- [x] Approved
- [x] Applied
