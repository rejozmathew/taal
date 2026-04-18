# AGENTS.md

Universal execution contract for agentic coding. Project-specific rules live in `PROJECT.md`.

---

## Source-of-Truth Hierarchy

When documents conflict, resolve in this order (highest authority first):

1. **AGENTS.md** — execution rules and blocker policy
2. **PROJECT.md** — project-specific contracts and rules
3. **docs/prd.md** — product intent, scope, and system truth
4. **docs/adr/*.md** — architecture decisions (immutable once accepted; only status line changes)
5. **docs/specs/*.md** — contract definitions (struct shapes, invariants, behavioral rules)
6. **plans/phase-X.md** — active execution plan (task ordering, deps, acceptance criteria)
7. **STATUS.md** — current project state

Specs override PRD on exact field definitions. PRD overrides specs on product intent and scope.

---

## Phase Execution Rules

### Before Starting Any Phase

1. Read this file completely
2. Read `PROJECT.md` for project-specific rules
3. Read `STATUS.md` for current project state
4. Read the active `plans/phase-X.md` as the execution contract
5. Read relevant specs referenced by the phase tasks

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
- [ ] All linting tools pass clean (language-appropriate)
- [ ] All existing tests still pass
- [ ] CHANGELOG.md updated if the change is user-visible

---

## Documentation Sync — Update Triggers

Different documents serve different audiences and update at different cadences.

### Per-Task Updates (every task)

| Document | Update Rule |
|----------|------------|
| **STATUS.md** | Mark task complete, update current task, note any blockers discovered |

### Per-Component Updates (when you add/change a component, flow, or boundary)

| Document | Update Rule |
|----------|------------|
| **ARCHITECTURE.md** | Update when a task: adds/removes a component, changes a major data flow, shifts ownership between layers, or changes a key boundary. |
| **Relevant spec** | Update if code changes a contract surface (struct shape, API, behavioral rule) |

### Per-Capability Updates (when a user-visible capability lands)

| Document | Update Rule |
|----------|------------|
| **CHANGELOG.md** | Describe the capability in user-visible language. Not task IDs. |
| **README.md** | Update when a phase completes or a major capability becomes usable. |

### Document Governance

| Artifact | Mutability | Purpose |
|----------|-----------|---------|
| **ARCHITECTURE.md** | Updated when system shape changes | "What the system looks like right now" |
| **README.md** | Updated at phase boundaries | "What the product does" |
| PRD | Edited to reflect current state | "How it works now" |
| ADRs | Immutable (only status line changes) | "Why we decided this" |
| Specs | Edited as models evolve | "What the contracts look like" |
| Phase plans | Updated per phase | "What we're building now" |
| Change Requests | Append-only | "What changed and why" |
| STATUS.md | Updated after each task | "Where we are" |
| CHANGELOG.md | Append-only, user-visible language | "What changed for users" |

---

## UX Quality Gate

For any task that creates or modifies a UI screen or widget, the agent must verify:

1. **Design system:** Screen uses project design tokens (colors, typography, spacing). No raw color literals or arbitrary pixel values outside the design system.
2. **Animations:** Interactive elements have press feedback. Page navigation has transitions. State changes are animated, not instant.
3. **Empty/error states:** Every screen handles "no data" and "error" with a helpful message and a constructive action.
4. **User feedback:** Every state-changing action produces visible feedback. Silent success is not acceptable.
5. **Accessibility:** Interactive elements have semantic labels. Touch targets are minimum 48x48dp.
6. **Responsiveness:** Screen works at the project's minimum supported width.

**"Widget renders correct data" is necessary but not sufficient for UI task acceptance.**

### Evidence Requirements

Every UI-heavy task must include in its end-of-task summary:
- Before/after screenshot or description of visual change
- Verification at minimum supported width
- Manual test of the primary user flow the task affects
- Accessibility check: focus order and semantic labels for interactive elements
- Where relevant: manual no-kit flow test and/or hot-plug/rescan test

Without this evidence, the task is not complete regardless of whether the code compiles.

---

## End-of-Task Summary

At the end of every task run, the agent must output:

```
## Task Complete: [Task ID] [Task Title]

### Code Changes
- [Files created or modified]

### Contract Changes
- [ ] No contract surfaces touched
- [ ] Contract(s) touched: [list]

### Docs Updated
- STATUS.md: [what changed]
- ARCHITECTURE.md: [what changed, or "no change"]
- CHANGELOG.md: [what changed, or "no change"]
- README.md: [what changed, or "no change"]
- Specs: [list, or "no change"]

### UX Evidence (if UI task)
- Screenshot/description: [before → after]
- Width check: [verified at Xpx]
- Manual flow test: [which flow, result]
- Accessibility: [focus order / labels checked]

### Blockers Encountered
- [None, or list]

### Next Task
- [Next task ID per dependency order]
```

**This is not optional.** A task is not complete until this summary is produced.

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
