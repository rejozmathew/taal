# AGENTS.md

This is the canonical execution contract for all coding agents working on Taal. Follow it strictly.

---

## Source-of-Truth Hierarchy

When documents conflict, resolve in this order (highest authority first):

1. **AGENTS.md** — execution rules and blocker policy
2. **docs/prd.md** — product intent, scope, and system truth
3. **docs/adr/*.md** — architecture decisions (immutable once accepted; only status line changes)
4. **docs/specs/*.md** — contract definitions (struct shapes, invariants, behavioral rules)
5. **plans/phase-X.md** — active execution plan (task ordering, deps, acceptance criteria)
6. **STATUS.md** — current project state

Specs override PRD on exact field definitions. PRD overrides specs on product intent and scope.

---

## Phase Execution Rules

### Before Starting Any Phase

1. Read this file completely
2. Read `STATUS.md` for current project state
3. Read the active `plans/phase-X.md` as the execution contract
4. Read relevant specs referenced by the phase tasks

### Execution Model

- Execute one phase (or one clearly bounded tranche within a phase) per run
- Follow **dependency order**, not task ID order. Task IDs are identifiers, not execution sequence.
- Before changing any files, restate:
  - **Task:** ID and title
  - **Goal:** what this task produces
  - **Files to touch:** which files will be created or modified
  - **Validation:** how to verify the task is correct
  - **Acceptance criteria:** from the phase plan
- Complete each task fully before moving to the next
- Update `STATUS.md` after each completed task

### What You Must Not Do

- Do not broadly reorder a phase unless a true contradiction forces it
- Do not start future-phase tasks opportunistically
- Do not pull in adjacent polish unless required for acceptance
- Do not implement features not specified in the active phase plan
- Do not use Taskmaster or any external task management system

---

## Blocker Policy

**This is the most important section.**

If a task is blocked by:
- A missing prerequisite that should exist but doesn't
- Contradictory documentation across PRD/specs/plans
- A contract ambiguity that would require guessing
- An architecture mismatch between spec and reality

**Stop immediately.** Do not patch over blockers with hidden tech debt.

Instead:
1. Explain the blocker clearly
2. Identify which documents conflict (with line references if possible)
3. Propose the **smallest** unblocking action:
   - A narrow plan clarification (preferred)
   - A small Change Request in `docs/change_requests/`
   - An ADR only if the decision is architectural
4. Wait for guidance before proceeding

**Never** silently work around a blocker by:
- Adding undocumented fallback behavior
- Widening an interface without updating the spec
- Deferring a required capability to "fix later"
- Inventing a contract that doesn't exist in the specs

---

## Contract Integrity Rules

### Frozen Interfaces

Interfaces marked frozen in `STATUS.md` must not be changed without:
1. Explicit Change Request documenting the reason
2. Spec update in the same changeset
3. PRD or ADR update if the change is architectural
4. STATUS.md updated to note the modification

### No Silent Contract Widening

Agents may not add fields, events, states, or enum variants to frozen contracts without an explicit CR. This includes "optional" fields — optional fields still widen the contract.

### Spec-Sync Checklist

For any task that touches a contract surface, verify before marking complete:
- [ ] Relevant spec updated if contract changed
- [ ] STATUS.md updated with task completion
- [ ] Phase plan acceptance criteria met
- [ ] No new warnings from `cargo clippy` or `flutter analyze`
- [ ] All existing tests still pass
- [ ] CHANGELOG.md updated if the change is user-visible

---

## Documentation Sync — Update Triggers

Different documents serve different audiences and update at different cadences. This prevents the Kaval problem where STATUS.md stays current but everything else goes stale.

### Per-Task Updates (every task)

| Document | Update Rule |
|----------|------------|
| **STATUS.md** | Mark task complete, update current task, note any blockers discovered |

### Per-Component Updates (when you add/change a component, flow, or boundary)

| Document | Update Rule |
|----------|------------|
| **ARCHITECTURE.md** | Update component inventory, data flow diagrams, or boundary descriptions whenever a task: adds a new component, removes a component, changes a major data flow, shifts ownership between Flutter/Rust/native layers, or changes a key boundary. This is the living technical record of what the system looks like *right now*. |
| **Relevant spec** | Update if code changes a contract surface (struct shape, API, behavioral rule) |

### Per-Capability Updates (when a user-visible capability lands)

| Document | Update Rule |
|----------|------------|
| **CHANGELOG.md** | Describe the capability in user-visible language: "Added real-time MIDI feedback with timing grades" — not "Completed P1-05." Group entries by what the user gains, not by task ID. |
| **README.md** | Update the feature description and install instructions when a phase completes or a major capability becomes usable. README is the product page — it describes what taal *does*, not what phase it's in. |

### Rarely Updated

| Document | Update Rule |
|----------|------------|
| **AGENTS.md** | Only when execution rules need to change |
| **ADRs** | Immutable once accepted (only status line changes) |
| **PRD** | Updated to reflect current state when scope or product rules change |
| **Phase plans** | Updated when tasks need revision (via CR) |

### Document Governance

| Artifact | Mutability | Purpose |
|----------|-----------|---------|
| **ARCHITECTURE.md** | Updated when system shape changes | "What the system looks like right now" |
| **README.md** | Updated at phase boundaries | "What taal does" (product page) |
| PRD (`docs/prd.md`) | Edited to reflect current state | "How it works now" |
| ADRs (`docs/adr/`) | Immutable (only status line changes) | "Why we decided this" |
| Specs (`docs/specs/`) | Edited as models evolve | "What the contracts look like" |
| Phase plans (`plans/`) | Updated per phase | "What we're building now" |
| Change Requests (`docs/change_requests/`) | Append-only | "What changed and why" |
| STATUS.md | Updated after each task | "Where we are" |
| CHANGELOG.md | Append-only, user-visible language | "What changed for users" |

---

## Taal-Specific Rules

### Timing and Scoring

- Latency-sensitive paths are sacred. Never add unnecessary indirection to the hit → grade → feedback pipeline.
- Rust core is authoritative for timing, scoring, and runtime semantics. Flutter UI renders what the engine tells it.
- Scoring correctness must not depend on UI frame rate.
- UI must not redefine engine behavior.

### Content Contracts

- Lesson/Course/Pack contracts must remain aligned with `docs/specs/content-schemas.md`
- Device mapping behavior must remain aligned with `docs/specs/midi-mapping.md`
- The canonical Grade enum, session state machine, and EngineEvent types are frozen (see `docs/specs/engine-api.md`)

### Platform Rules

- Phase 0 uses a simplified hit contract for timing measurement only (pre-resolved lane_id, not full MIDI pipeline)
- Android is the highest latency risk platform — treat its measurements with extra scrutiny
- Audio output latency is a Phase 1 concern (P1-15), not Phase 0

---

## Validation

Run only the validations required by the active task. Prefer focused validation:

1. Unit/contract tests for touched modules
2. Targeted integration checks
3. Full-suite runs only when the phase requires them

For Phase 0 latency measurements specifically:
- Release build only (not debug)
- 100+ sample minimum
- Raw timing logs as CSV artifacts
- Hardware/OS matrix documented

---

## End-of-Task Summary

At the end of every task run, the agent must output a summary in this exact format:

```
## Task Complete: [Task ID] [Task Title]

### Code Changes
- [Files created or modified, one per line]

### Contract Changes
- [ ] No contract surfaces touched
- [ ] Contract(s) touched: [list which specs]

### Docs Updated
- STATUS.md: [what changed, or "no change"]
- ARCHITECTURE.md: [what changed, or "no change — no component/flow/boundary changes"]
- CHANGELOG.md: [what changed, or "no change — no user-visible capability"]
- README.md: [what changed, or "no change"]
- Specs: [list, or "no change"]

### Blockers Encountered
- [None, or list]

### Next Task
- [Next task ID per dependency order]
```

**This is not optional.** A task is not complete until this summary is produced. If a doc that should have been updated wasn't, the summary must say so explicitly — silent skips are drift.

---

## Change Request Format

When a CR is needed, create a file in `docs/change_requests/` with:

```
# CR-NNN: [Short Title]

**Date:** YYYY-MM-DD
**Triggered by:** [Task ID or observation]
**Documents affected:** [list]

## Problem
[What contradicts or is missing]

## Proposed Change
[Smallest fix that unblocks]

## Impact
[What else changes as a result]

## Status
- [ ] Proposed
- [ ] Approved
- [ ] Applied
```
