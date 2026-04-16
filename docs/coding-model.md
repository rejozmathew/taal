# Agentic Coding Operating Model

This document defines how coding agents execute against the Taal PRD and specs.

---

## Task Ordering

**Task IDs are identifiers, not execution order.** Dependencies define the real sequencing. Some lower-numbered tasks depend on higher-numbered ones (e.g., P1-07 depends on P1-15). Agents must respect the dependency graph, not numeric order.

Before starting any task, verify all listed dependencies are complete.

---

## Task Template

```
Task ID: P1-04
Task Title: Rust runtime session management
Bounded Objective: Implement session start/stop/tick/hit/drain
  lifecycle that accepts timestamped MIDI hits, grades them against
  compiled lesson events, and emits EngineEvents for the UI.

Inputs / Referenced Contracts:
  - specs/engine-api.md §3 (Session state machine)
  - specs/engine-api.md §4.5 (EngineEvent types)
  - specs/content-schemas.md (CompiledLesson via compile step)
  - rust/src/runtime/ (module boundary)

Files Allowed to Change:
  - rust/src/runtime/session.rs
  - rust/src/runtime/mod.rs
  - rust/tests/runtime/

Files Forbidden to Change:
  - rust/src/content/ (dependency)
  - rust/src/time/ (dependency)

Required Tests:
  - Unit: single hit graded correctly against expected event
  - Unit: miss detected when no hit in window
  - Unit: combo increments on consecutive good hits
  - Unit: session_stop returns correct AttemptSummary

Acceptance Criteria:
  - Session accepts hits and emits HitGraded events
  - Tick advances time and detects misses
  - drain_events returns batched events
  - All tests pass, clippy clean
```

---

## Contract-Touch Rule

If a task changes any of the following, the relevant spec must be updated in the same changeset:

- Engine API (event types, session lifecycle, grade model)
- Content schema (lesson/course/pack structure, invariants)
- Device profile structure (mapping, calibration)
- Analytics storage schema (attempt fields, theme taxonomy)
- Visual language (grade semantics, color tokens, combo rules)

The spec is the source of truth. Code implements the spec. If the spec needs to change, change it first (or simultaneously), not after the fact.

---

## Frozen Interface Rule

When an interface is marked frozen in `STATUS.md`, it must not be changed without:

1. Explicit CR (Change Request) documenting the reason
2. Spec update in the same changeset
3. PRD or ADR update if the change is architectural
4. STATUS.md updated to note the interface was modified

**No silent contract widening:** Agents may not add fields, events, states, or enum variants to frozen contracts without an explicit CR. This includes adding "optional" fields — optional fields still widen the contract.

---

## Document Governance

| Artifact | Mutability | Purpose |
|----------|-----------|---------|
| PRD (`docs/prd.md`) | Edited to reflect current state | "How it works now" |
| ADRs (`docs/adr/`) | Immutable (only status line changes) | "Why we decided this" |
| Specs (`docs/specs/`) | Edited as models evolve | "What the contracts look like" |
| Phase plans (`plans/`) | Updated per phase | "What we're building now" |
| STATUS.md | Updated after each task | "Where we are" |
| CHANGELOG.md | Append-only | "What changed when" |

When documents conflict, ownership hierarchy applies:
- Specs override PRD on exact field definitions
- PRD overrides specs on product intent and scope

---

## Change Requests

When implementation reveals that a PRD decision needs to change:
1. Document the change as a CR in the relevant spec or PRD section
2. If architectural: write an ADR explaining the new decision
3. Update the PRD to reflect current state
4. Update STATUS.md to note the change
5. Update CHANGELOG.md if externally meaningful

---

## Spec-Sync Checklist

For any task that touches a contract surface, the agent must verify before marking complete:

- [ ] Relevant spec updated if contract changed
- [ ] STATUS.md updated with task completion
- [ ] Phase plan acceptance criteria met
- [ ] No new warnings from `cargo clippy` or `flutter analyze`
- [ ] All existing tests still pass
- [ ] CHANGELOG.md updated if the change is user-visible
