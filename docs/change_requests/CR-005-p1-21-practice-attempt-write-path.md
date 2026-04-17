# CR-005: P1-21 Practice Attempt Write Path

**Date:** 2026-04-17
**Triggered by:** P1-21 Practice Attempt Persistence blocker
**Documents affected:** docs/specs/analytics-model.md, docs/specs/engine-api.md, plans/phase-1.md, STATUS.md

## Problem

P1-21 requires persistence of `PracticeAttempt` records in SQLite, and `plans/phase-1.md` says to write on `session_stop`. `docs/specs/analytics-model.md` also says attempts are written by the Rust engine on `session_stop()`, while the frozen `docs/specs/engine-api.md` session lifecycle defines `session_stop(session) -> Result<AttemptSummary, SessionError>` with no persistence context.

`PracticeAttempt` requires fields that are not produced by `AttemptSummary`, including `player_id`, course/section context, device profile, lesson metadata snapshots, and wall-clock/local-time context. Widening `session_stop` would change a frozen lifecycle API and mix SQLite I/O into the session lifecycle boundary.

## Proposed Change

Preserve the frozen `session_stop(session) -> Result<AttemptSummary, SessionError>` signature and define a separate post-`session_stop` Rust storage API for P1-21:

```rust
fn record_practice_attempt(
    summary: AttemptSummary,
    context: PracticeAttemptContext,
) -> Result<PracticeAttempt, StorageError>
```

Define `PracticeAttemptContext` in `analytics-model.md` as the caller-supplied context needed to complete a `PracticeAttempt` record from an `AttemptSummary`.

Clarify that "write on session_stop" means "write immediately after a successful `session_stop`, using its `AttemptSummary`", not "perform SQLite persistence inside the session lifecycle call."

## Impact

- The frozen session lifecycle API remains unchanged.
- P1-21 is implementable without guessing or adding hidden fallback behavior.
- Persistence remains Rust-owned and SQLite-backed, consistent with the PRD and existing profile/device-profile storage ownership.
- No ADR is required because this does not change the accepted Flutter + Rust architecture or storage ownership; it clarifies a contract-level write path.
- No P1-21 implementation code is started by this CR.

## Status
- [x] Proposed
- [x] Approved
- [x] Applied
