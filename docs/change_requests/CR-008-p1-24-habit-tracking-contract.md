# CR-008: P1-24 Habit Tracking Contract

**Date:** 2026-04-17
**Triggered by:** P1-24 Practice Streaks and Daily Goal Tracking blocker
**Documents affected:** docs/specs/analytics-model.md, docs/specs/engine-api.md, plans/phase-1.md, ARCHITECTURE.md, STATUS.md

## Problem

P1-24 requires daily streaks, configurable daily practice goals, weekly summaries, and streak data stored per player profile in SQLite.

`docs/specs/analytics-model.md` currently defines `PracticeAttempt` storage and query filters, but it does not define a habit/streak summary model, daily-goal model, streak persistence semantics, or a Rust storage/bridge API for P1-24.

`docs/specs/engine-api.md` §10 freezes the current settings model and bridge API, but `ProfileSettings` does not include a daily practice goal. Adding a `daily_goal_minutes` field without a CR would silently widen the frozen settings contract.

The phase plan also says streak data is stored per profile in SQLite, but it does not clarify whether the streak counter should be a derived read model computed from `PracticeAttempt` rows or a separately persisted mutable counter/cache. Guessing either approach would create hidden product and data-model debt.

## Proposed Change

Clarify P1-24 with the smallest contract addition needed to implement the task:

1. Add a P1-24 habit tracking section to `docs/specs/analytics-model.md` defining:
   - `PracticeHabitSnapshot`
   - `PracticeDaySummary`
   - daily streak calculation rules from `PracticeAttempt.started_at_utc` plus local day context
   - weekly summary fields
   - milestone message thresholds
   - whether streak data is derived from attempts, stored as a cache, or stored as authoritative state
2. Add a profile-level daily goal setting to `docs/specs/engine-api.md` §10, including default `10` minutes and validation bounds.
3. Define the Rust storage/bridge API shape for loading the current habit snapshot and updating the daily goal.
4. Update `plans/phase-1.md` P1-24 contract note so the task implements the clarified model rather than inventing storage semantics during implementation.

Preferred narrow decision: make streaks and weekly summaries derived from `PracticeAttempt` rows at read time for Phase 1, with only the daily goal stored in profile settings. This avoids a second authoritative streak counter that can drift from attempt history. If performance later requires caching, add a derived cache in a future CR.

## Impact

- P1-24 becomes implementable without widening frozen settings or analytics contracts silently.
- Practice attempts remain the source of truth for practice history.
- Profile settings gain one user-owned habit preference.
- The app shell home surface can replace its streak placeholder with a Rust-produced habit snapshot.
- No ADR is expected because the existing Rust-owned SQLite persistence boundary is preserved.

## Status
- [x] Proposed
- [ ] Approved
- [ ] Applied
