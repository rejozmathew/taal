# CR-003: P1-01 Lesson Ancillary Content Types

**Date:** 2026-04-16
**Triggered by:** P1-01 implementation inspection
**Documents affected:** docs/specs/content-schemas.md, STATUS.md

## Problem

P1-01 still cannot implement strict typed Rust parsing for `Lesson` without guessing. `docs/specs/content-schemas.md` defines the main `Lesson` shape, but several parse-relevant nested types remain undefined:

- `TimeSignature`
- `TempoEntry`
- `MusicalPos`
- `TimeRange`
- `AssetRefs`
- `ContentRefs`
- `PublisherRef`

The timing/range helpers can be inferred from examples, but they are not explicitly defined as contract types. `AssetRefs`, `ContentRefs`, and `PublisherRef` are not sufficiently inferable for a strict parser.

There is also a required-field/default ambiguity: the `Lesson` struct lists `assets: AssetRefs` and `references: ContentRefs`, but the canonical minimal Lesson example omits both fields. P1-01 needs to know whether those fields are required in JSON, required with default empty values, or optional.

## Proposed Change

Define the exact v1 contract shapes for the missing nested types in `docs/specs/content-schemas.md`.

Clarify the JSON absence behavior for `assets` and `references`:

- If they are required fields, update the canonical Lesson example to include valid minimal values.
- If they default when absent, state the default values explicitly.

Clarify how local Phase 1 parsing should treat optional marketplace `publisher` data:

- Either define a concrete `PublisherRef` shape, or
- Explicitly mark the field as ignored/opaque for local content loading.

## Impact

This unblocks P1-01 without changing product scope. The Rust content module can then implement strict deserialization and validation for `Lesson`, `InstrumentLayout`, and `ScoringProfile` without adding hidden fallback behavior or undocumented schema widening.

## Applied Clarification

`docs/specs/content-schemas.md` now explicitly defines:

- `TimeSignature { num, den }`
- `TempoEntry { pos, bpm }`
- `MusicalPos { bar, beat, tick }`
- `TimeRange { start, end }`
- `AssetRefs { backing, artwork }`
- `ContentRefs {}` as an intentionally empty schema version `1.0` object
- `PublisherRef` as an optional JSON object ignored by local Phase 1 loading

Lesson JSON may omit `assets`, `references`, and `optional_lanes`. Strict Rust loading must materialize the documented defaults:

- `assets` -> `AssetRefs { backing: None, artwork: None }`
- `references` -> `ContentRefs {}`
- `optional_lanes` -> `[]`

The minimal Lesson example remains intentionally free of optional ancillary metadata and now includes the required `metadata.prerequisites` field as an empty list.

## Status

- [x] Proposed
- [x] Approved
- [x] Applied
