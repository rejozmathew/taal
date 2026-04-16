# CR-002: P1-01 Content Contract Clarification

**Date:** 2026-04-16
**Triggered by:** P1-01
**Documents affected:** docs/specs/content-schemas.md, plans/phase-1.md, STATUS.md

## Problem

P1-01 requires typed Rust deserialization and validation for `Lesson`, `InstrumentLayout`, and `ScoringProfile`.

The authoritative content spec is not complete enough to implement that task without guessing:

- `docs/specs/content-schemas.md` declares `InstrumentLayout.visual: VisualConfig`, but does not define `VisualConfig`.
- The same spec declares `LaneDefinition.articulations: Option<Vec<ArticulationDef>>`, but does not define `ArticulationDef`.
- The same spec declares `ScoringProfile.grading: GradeWeights`, `combo: ComboConfig`, and `rules: ScoringRules`, but does not define those structs.
- The Standard 5-Piece Layout example in `docs/specs/content-schemas.md` omits the required `visual` field, so the spec is internally inconsistent on whether `visual` is required at load time.
- `plans/phase-1.md` requires P1-01 to ensure "All bundled starter content passes validation" even though the starter layout and starter lessons are scheduled later as P1-19 and P1-18.

Implementing P1-01 right now would require either inventing undocumented field shapes for those nested structs or silently doing out-of-order starter-content work.

## Proposed Change

Make the smallest clarifications needed to unblock P1-01:

1. In `docs/specs/content-schemas.md`, define the exact field-level contracts for:
   - `VisualConfig`
   - `ArticulationDef`
   - `GradeWeights`
   - `ComboConfig`
   - `ScoringRules`
2. Clarify whether `InstrumentLayout.visual` is required or optional at load time, and sync the Standard 5-Piece Layout example to that rule.
3. In `plans/phase-1.md`, narrow the P1-01 acceptance criterion from "all bundled starter content" to validation fixtures/currently bundled content, or move starter-content validation to P1-18/P1-19 where the starter assets are actually introduced.

## Impact

- Unblocks strict Rust implementation of P1-01 without widening contracts.
- Keeps P1-18 and P1-19 as the tasks that actually introduce starter content and the standard layout.
- Prevents hidden tech debt in the content module and avoids speculative JSON shapes that would need later migration.

## Status
- [x] Proposed
- [x] Approved
- [x] Applied
