# Agent Prompt Examples

These examples show how to use `docs/agent-prompt-template.md` in this repository.

They are intentionally concrete and follow the execution model defined in `AGENTS.md`.

---

## Example 1 — Full Phase Execution (Phase 0)

Read `AGENTS.md` first and follow it strictly.

Use `docs/prd.md` as the baseline product and architecture source of truth.

Use `docs/adr/001-platform-architecture.md` as the authoritative architecture decision for this run.

Use the relevant frozen or partial contract specs under `docs/specs/`, especially:
- `docs/specs/engine-api.md`
- `docs/specs/midi-mapping.md`
- `docs/specs/content-schemas.md`

Use `plans/phase-0.md` as the execution contract for this run.

Use `STATUS.md` as the running project state file to update after each completed task.

Current state for this run:
- This is a docs-first bootstrap repo.
- No application code is implemented yet.
- Phase 0 has not started.
- The goal is to establish the monorepo scaffold and validate the end-to-end latency-critical technical spike.
- Do not start Phase 1 in this run.

Goal of this run:
Execute Phase 0 in the plan's `Execution Order` section, using dependency notes to confirm readiness as you go. Establish the initial Flutter + Rust + native-adapter scaffold, prove the MIDI → Rust → UI feedback loop on the target platforms defined in the plan, and finalize the platform architecture decision only if the Phase 0 acceptance criteria are met.

Required scope for this run:
- Execute only Phase 0 tasks.
- Follow the phase plan's `Execution Order` section first, then use dependency notes to confirm readiness.
- Finalize ADR-001 only if the spike results justify it.
- Do not begin any Phase 1 feature implementation.

Files expected to touch:
- `plans/phase-0.md`
- `STATUS.md`
- `ARCHITECTURE.md`
- code/scaffold files required by Phase 0
- any directly affected spec files if a frozen or partial contract must be clarified

Important constraints:
- Do not broaden into Phase 1.
- Do not add speculative product features.
- Do not silently change contract definitions unless the Phase 0 spike forces a clarification.
- Stop on blockers; do not paper over them.

Execution rules:
1. Before making changes, restate:
   - task: execute Phase 0
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect `plans/phase-0.md`, ADR-001, relevant specs, and `STATUS.md` before editing.
3. Execute Phase 0 in the plan's `Execution Order` section, using dependency notes to confirm readiness.
4. Update `STATUS.md` after each completed task.
5. Update `ARCHITECTURE.md` whenever a component, boundary, or ownership model becomes concrete.
6. Update specs only when required by code or contract clarification.
7. If the spike fails the latency or platform assumptions, stop and report the smallest architectural decision needed.

Acceptance criteria:
- Phase 0 tasks are completed or an explicit blocker is documented.
- The MIDI → Rust → UI path is validated per the plan.
- ADR-001 is either confirmed or a precise blocker is documented.
- `STATUS.md` and `ARCHITECTURE.md` reflect the new repo reality.

Validation:
- Run the targeted Phase 0 validation steps from `plans/phase-0.md`.
- Use focused build/test/benchmark checks only.
- Do not start broad regression validation for future phases.

At the end, summarize:
- files changed
- validations run
- whether Phase 0 acceptance criteria were met
- whether ADR-001 was finalized
- documentation sync status
- whether the repo is ready for Phase 1

---

## Example 2 — Narrow Control-Doc Clarification Pass

Read `AGENTS.md` first and follow it strictly.

Use `docs/prd.md` as the baseline product and architecture source of truth.

Use relevant approved ADRs under `docs/adr/` as authoritative overrides where applicable.

Use `plans/phase-2.md` as the execution contract for this run.

Use `STATUS.md` as the running project state file.

Current state for this run:
- Phase 1 is complete from the current repo state.
- Phase 2 has not started.
- I want a narrow clarification to the Phase 2 plan only.
- I do not want feature implementation in this run.

Goal of this run:
Apply a minimal control-doc clarification to the Phase 2 plan so that the intended execution order and dependency posture are explicit. Do not implement any code or feature work.

Required scope for this run:
- Clarify only the specified task ordering/dependency wording in `plans/phase-2.md`.
- Update `STATUS.md` only as needed to reflect the clarified execution posture.
- Do not touch product scope.
- Do not touch code.

Files expected to touch:
- `plans/phase-2.md`
- `STATUS.md`

Important constraints:
- Control-doc clarification only.
- Do not implement features.
- Do not create a CR or ADR unless a real contradiction forces it.
- Preserve task numbering and overall phase order unless a tiny wording adjustment is strictly necessary.

Execution rules:
1. Before making changes, restate:
   - task
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect the current Phase 2 plan and `STATUS.md`.
3. Make only the minimum edits needed.
4. Keep `STATUS.md` minimal and append-only where possible.
5. Stop if a true contradiction is found.

Acceptance criteria:
- The intended execution posture is explicit.
- Phase order still reads coherently.
- No implementation has started.
- `STATUS.md` reflects the clarification without falsely implying Phase 2 has begun.

Validation:
- Focused consistency review only.
- Check dependency coherence, task ordering wording, and `STATUS.md` consistency.

At the end, summarize:
- files changed
- wording clarified
- whether renumbering/reordering was avoided
- whether `STATUS.md` reflects the clarified posture

---

## Example 3 — Contract / Spec Hardening Pass

Read `AGENTS.md` first and follow it strictly.

Use `docs/prd.md` as the baseline product and architecture source of truth.

Use relevant ADRs under `docs/adr/` as authoritative overrides.

Use the following specs as authoritative contract sources for this run:
- `docs/specs/content-schemas.md`
- `docs/specs/engine-api.md`
- `docs/specs/midi-mapping.md`

Use `plans/phase-1.md` as the execution contract context for this run.

Use `STATUS.md` as the running state file.

Current state for this run:
- Phase 0 is complete.
- Phase 1 has not started.
- Before coding Phase 1, I want to harden the contracts that Phase 1 depends on.
- This is a docs/spec pass only.

Goal of this run:
Tighten and synchronize the contract docs needed for Phase 1 so the implementation phase does not invent missing details. Do not implement application code.

Required scope for this run:
- Clarify and freeze the contract details needed for the targeted Phase 1 tasks.
- Keep the PRD and specs aligned.
- Update `ARCHITECTURE.md` only if the contract clarification changes component boundaries or ownership.

Files expected to touch:
- `docs/specs/content-schemas.md`
- `docs/specs/engine-api.md`
- `docs/specs/midi-mapping.md`
- `ARCHITECTURE.md` only if needed
- `STATUS.md`

Important constraints:
- No feature implementation.
- No broad PRD rewrite.
- No silent widening of interfaces.
- Stop if a true contradiction between PRD, ADR, and spec is discovered.

Execution rules:
1. Restate the task, goal, files, validation, and acceptance criteria.
2. Inspect relevant Phase 1 tasks before editing specs.
3. Clarify only what Phase 1 needs.
4. Keep terminology and shapes aligned across all touched specs.
5. Update `STATUS.md` and `ARCHITECTURE.md` if needed.

Acceptance criteria:
- The targeted Phase 1 contracts are explicit enough to implement.
- Cross-spec terminology is aligned.
- No contradictions remain in the touched contract areas.
- The repo is more implementation-ready without changing scope.

Validation:
- Focused consistency review only.
- Check schema/API shape alignment and cross-reference consistency.

At the end, summarize:
- files changed
- contracts hardened
- any blockers found
- whether `ARCHITECTURE.md` needed updates
- whether the repo is ready for the targeted Phase 1 tranche

---

## Example 4 — Blocker Resolution Pass

Read `AGENTS.md` first and follow it strictly.

Use `docs/prd.md` as the baseline product and architecture source of truth.

Use relevant ADRs and specs as authoritative references.

Use `plans/phase-1.md` as the execution contract context for this run.

Use `STATUS.md` as the running state file.

Current state for this run:
- Phase 1 is in progress.
- A blocker has been found between the active implementation and the current docs/contracts.
- I do not want the blocker patched over with hidden tech debt.

Goal of this run:
Analyze the blocker, identify the smallest unblocking decision needed, and apply only the minimum documentation/plan/spec change necessary if the contradiction is clear. Do not opportunistically continue adjacent implementation work.

Required scope for this run:
- Investigate the blocker.
- Determine whether it is:
  - a plan clarification issue
  - a spec clarification issue
  - a CR issue
  - an ADR issue
- Apply only the smallest justified fix.

Files expected to touch:
- only the specific docs/specs/plans needed to resolve the blocker
- `STATUS.md`

Important constraints:
- Do not workaround the blocker in code without documentation alignment.
- Do not broaden scope.
- Do not continue implementation beyond the blocker resolution.

Execution rules:
1. Restate:
   - the blocker
   - affected tasks/contracts
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect the exact contradiction before editing.
3. Prefer the smallest unblocking change.
4. Stop if the issue is architectural and needs a real ADR decision.

Acceptance criteria:
- The blocker is clearly explained.
- The smallest unblocking change is applied or explicitly deferred for decision.
- No hidden tech debt is introduced.
- `STATUS.md` reflects the blocker resolution state.

Validation:
- Focused consistency review only.
- Check that the blocker is genuinely resolved at the document/contract level.

At the end, summarize:
- blocker identified
- files changed
- exact unblocking decision made
- whether a CR/ADR was required
- whether implementation can resume safely
