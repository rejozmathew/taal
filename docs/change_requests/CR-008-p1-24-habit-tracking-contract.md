# CR-008: P1-24 Practice Habit Tracking Contract

**Date:** 2026-04-17
**Triggered by:** P1-24 Practice Streaks and Daily Goal Tracking blocker
**Documents affected:** docs/specs/analytics-model.md, docs/specs/engine-api.md, plans/phase-1.md, STATUS.md

## Problem

P1-24 requires a daily streak counter, a configurable daily practice goal, a home-screen progress indicator, a weekly summary, and per-profile persistence semantics.

The current authoritative contracts do not define the minimum data model needed to implement those behaviors cleanly.

`docs/specs/engine-api.md` §10 freezes the current settings contract, but `ProfileSettings` and `ProfileSettingsUpdate` do not include a daily practice goal field. Adding one during implementation without a CR would silently widen a frozen settings interface.

`docs/specs/analytics-model.md` defines `PracticeAttempt` storage and query behavior, but it does not define a habit snapshot model, weekly summary semantics, or a read API for habit tracking.

There is also a specific ambiguity in the current `PracticeAttempt` contract: it stores `started_at_utc`, `local_hour`, and `local_dow`, but not a canonical local calendar-day field for consecutive-day streak and weekly summary calculations.

Finally, `plans/phase-1.md` requires daily goal progress to update in real time during practice, while `PracticeAttempt` rows are only written after a successful `session_stop()`. Without clarification, implementation would have to guess whether to introduce mid-session persistence or keep that progress display-only.

## Proposed Change

Define the minimum P1-24 contract while preserving the current architecture:

1. Rust remains the owner of SQLite persistence. Flutter owns rendering and interaction.
2. Phase 1 habit tracking is a derived read model from scored `PracticeAttempt` rows. There is no separate authoritative streak table or mutable streak counter in Phase 1.
3. Add `local_day_key` to `PracticeAttempt` and `PracticeAttemptContext` as the canonical local calendar-day field for streak and weekly-summary calculations.
4. Add `daily_goal_minutes` to `ProfileSettings` and `ProfileSettingsUpdate` through the existing settings persistence boundary.
5. Define the minimum P1-24 read-model contract in `docs/specs/analytics-model.md`, including:
   - `PracticeDaySummary`
   - `PracticeWeekSummary`
   - `PracticeHabitSnapshot`
   - streak state / milestone semantics
   - a Rust storage API and Flutter bridge shape for loading the current habit snapshot
6. Clarify that a qualifying practice day is any local day with at least one scored `PracticeAttempt`.
7. Clarify that the weekly summary uses a rolling 7-day local-day window inclusive of today.
8. Clarify that section-only scored attempts still count toward qualifying a day and daily/weekly practice minutes, while weekly lesson completions count only scored attempts where `section_id == None`.
9. Clarify that live daily-goal progress during an active session is a UI-composed value from persisted habit data plus in-memory session elapsed time, not a mid-session SQLite write.
10. Update `plans/phase-1.md` so P1-24 points to the clarified derived-model contract.

## Impact

- P1-24 becomes implementable without guessing streak persistence semantics.
- `PracticeAttempt` remains the source of truth for scored practice history.
- Profile settings gain one user-owned habit preference (`daily_goal_minutes`) without adding a second write path.
- No session lifecycle, grade, `EngineEvent`, `PracticeAttempt` outcome, `RawMidiEvent`, or `MappedHit` contract is changed.
- Rust-owned SQLite persistence remains the architectural boundary. No ADR is required.
- No P1-24 implementation code is started by this CR.

## Status

- [x] Proposed
- [x] Approved
- [x] Applied
