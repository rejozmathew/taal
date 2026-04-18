# Agent Prompt Examples

These examples show how to use `docs/agent-prompt-template.md` in this repository.

They are intentionally concrete and follow the current document split:
- `AGENTS.md` = execution contract
- `PROJECT.md` = Taal-specific execution rules
- `docs/prd.md` = product requirements and scope
- `plans/phase-x.md` = execution contract for the active phase
- `STATUS.md` = running state file

---

## Example 1 — Continue Active Phase in Execution Order

Read `AGENTS.md` first and follow it strictly.

Read `PROJECT.md` next and follow it for Taal-specific execution rules.

Use `docs/prd.md` as the product requirements and scope source of truth.

Use relevant approved ADRs under `docs/adr/` as authoritative architectural overrides where applicable.

Use relevant specs under `docs/specs/` as authoritative contract definitions where applicable, especially:
- `docs/specs/content-schemas.md`
- `docs/specs/engine-api.md`
- `docs/specs/midi-mapping.md`
- `docs/specs/analytics-model.md`
- `docs/specs/visual-language.md`

Use `plans/phase-1.md` as the execution contract for this run, including its `Execution Order` section.

Use `STATUS.md` as the running project state file to update after each completed task.

Current state for this run:
- Phase 0 is complete.
- Phase 1 is in progress.
- The following Phase 1 tasks are already complete and must not be reworked unless a real blocker requires it:
  - P1-00
  - P1-01
  - P1-02
  - P1-03
  - P1-04
  - P1-05
  - P1-06
  - P1-16
  - P1-08
  - P1-19
  - P1-18
  - P1-15
  - P1-07
  - P1-09
  - P1-10
  - P1-11
  - P1-12
  - P1-14
  - P1-21
  - P1-13
  - P1-22
  - P1-20
  - P1-23
  - P1-24
  - P1-25
  - P1-26
- Per `STATUS.md` and `plans/phase-1.md`, the current execution-order task is `P1-17 Onboarding Flow`.
- No current blockers are recorded.
- P1-17 was started in the prior run and the run ended due to token limits. Partial P1-17 code, tests, and docs may already exist in the repo. Inspect the current repo state first and continue from what is already there. Do not restart P1-17 from scratch or discard in-progress work.

Goal of this run:
Continue Phase 1 from the current repo state by finishing P1-17 cleanly from its current in-progress state. If P1-17 completes cleanly and P1-27 is still execution-order ready, continue to P1-27 in execution order. Stop only on a real blocker, a true contract contradiction, or token limits.

Required scope for this run:
- Execute only remaining Phase 1 tasks.
- Start by inspecting and continuing P1-17 from the current repo state.
- Do not redo already-complete tasks.
- If P1-17 completes cleanly, continue to P1-27 only if dependencies are actually satisfied and no blocker appears.
- Use the `Execution Order` section as the primary run sequence.
- Do not start Phase 2 or later phases.
- Do not renumber tasks or rewrite the phase plan structure in this run.

Files expected to touch:
- `STATUS.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md` when user-visible capability lands
- relevant Rust / Flutter / native source files for P1-17 and, only if reached, P1-27
- focused tests for the task(s) actually reached
- affected specs only if a true contract clarification is strictly required
- `README.md` only if clearly warranted

Important constraints:
- Follow `plans/phase-1.md` `Execution Order` first.
- Task IDs remain stable identifiers and are not themselves the execution order.
- Do not silently widen contracts or interfaces.
- Do not create hidden tech debt as a workaround.
- Do not create a CR or ADR unless a real contradiction or architectural conflict requires it.
- Keep documentation synchronized with any contract, architecture, or user-visible behavior changes.
- If a task reveals a real blocker, stop at that blocker and document the smallest unblocking decision needed instead of freelancing around it.
- Treat partial P1-17 work already in the repo as authoritative current state to continue from, not as disposable draft work.

Execution rules:
1. Before making changes, restate:
   - active phase and starting task
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect `plans/phase-1.md`, especially the `Execution Order` section, plus relevant requirements / ADRs / specs and `STATUS.md` before editing.
3. Inspect the current repo state for partial P1-17 work before changing anything. Determine what is already implemented, what remains incomplete, and what docs / tests / status need to be finished.
4. Start with P1-17 and complete it from the current repo state.
5. Before beginning P1-27, verify that its dependencies are actually satisfied from the current repo state.
6. Make only the minimum changes needed for the active task(s) reached in this run.
7. Update `STATUS.md` after each completed task.
8. Update `ARCHITECTURE.md` whenever a component, flow, boundary, or ownership model becomes concrete or changes.
9. Update `CHANGELOG.md` when a user-visible capability lands.
10. Update affected specs if and only if implementation reveals a real contract clarification that is required.
11. If you encounter a contradiction or blocker, stop and record:
   - the exact blocker
   - the smallest unblocking decision needed
   - whether it is a plan clarification, spec clarification, CR, or ADR issue

Acceptance criteria:
- P1-17 is completed cleanly from the current repo state, or a precise blocker is documented.
- If P1-17 completes and P1-27 is reached, P1-27 is completed in execution order or a precise blocker is documented.
- `STATUS.md` accurately reflects which Phase 1 tasks completed in this run.
- `ARCHITECTURE.md` is updated if new concrete components or flows landed.
- `CHANGELOG.md` is updated for user-visible capabilities that landed.
- No out-of-order or out-of-scope work was started.
- The repo is left ready for the next execution-order Phase 1 task or Phase 1 completion.

Validation:
- Run focused validation for each completed Phase 1 task in this run.
- Use targeted tests / checks only for the task(s) actually reached.
- Do not run broad future-phase validation unless required.

At the end, summarize:
- files changed
- validations run
- which Phase 1 tasks completed in this run
- blockers encountered or not encountered
- whether execution order was followed
- documentation sync status:
  - `STATUS.md`
  - `ARCHITECTURE.md`
  - `CHANGELOG.md`
  - relevant specs
  - `README.md` if applicable
- whether the repo is ready for the next execution-order Phase 1 task or whether Phase 1 is complete

---

## Example 2 — Single Execution-Order Task

Read `AGENTS.md` first and follow it strictly.

Read `PROJECT.md` next and follow it for Taal-specific execution rules.

Use `docs/prd.md` as the product requirements and scope source of truth.

Use relevant approved ADRs under `docs/adr/` as authoritative architectural overrides where applicable.

Use relevant specs under `docs/specs/` as authoritative contract definitions where applicable, especially:
- `docs/specs/engine-api.md`
- `docs/specs/analytics-model.md`
- `docs/specs/visual-language.md`

Use `plans/phase-1.5.md` as the execution contract for this run, including its `Execution Order` section.

Use `STATUS.md` as the running project state file to update after each completed task.

Current state for this run:
- Phase 1 is complete.
- Phase 1.5 is approved and is the active phase for this run.
- Per `STATUS.md` and `plans/phase-1.5.md`, the target task is execution-order ready.
- Target task: `P1.5-03 Audio Wiring`
- No other Phase 1.5 task should be started in this run.
- Partial work for P1.5-03 may already exist in the repo and should be inspected before any edits.

Goal of this run:
Complete `P1.5-03 Audio Wiring` cleanly from the current repo state. Do not continue to any later task after P1.5-03 unless explicitly instructed in a later run. Stop only on a real blocker, a true contract contradiction, or token limits.

Required scope for this run:
- Execute only `P1.5-03`.
- Verify the task is execution-order ready before editing.
- Do not start `P1.5-01` or any later task in this run.
- Use the active phase plan `Execution Order` and the task's acceptance criteria as the governing completion standard.
- Do not renumber tasks or rewrite the phase plan structure in this run.

Files expected to touch:
- `STATUS.md`
- `ARCHITECTURE.md` if any concrete audio flow / ownership becomes clearer
- `CHANGELOG.md` when user-visible audio capability lands
- relevant Flutter / native audio source files for `P1.5-03`
- focused tests for `P1.5-03`
- affected specs only if the new persisted audio toggle or related contract truly requires clarification

Important constraints:
- Confirm `P1.5-03` is execution-order ready before editing.
- Do not silently widen contracts or interfaces.
- Do not create hidden tech debt as a workaround.
- Do not create a CR or ADR unless a real contradiction or architectural conflict requires it.
- Keep documentation synchronized with any contract, architecture, or user-visible behavior changes.
- Treat partial P1.5-03 work already in the repo as authoritative current state to continue from, not as disposable draft work.

Execution rules:
1. Before making changes, restate:
   - active phase and target task
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect `plans/phase-1.5.md`, especially the `Execution Order` section and the `P1.5-03` task definition, plus relevant requirements / ADRs / specs and `STATUS.md` before editing.
3. Inspect the current repo state for partial `P1.5-03` work before changing anything. Determine what is already implemented, what remains incomplete, and what docs / tests / status need to be finished.
4. Verify that all `P1.5-03` dependencies are satisfied from the current repo state before implementation.
5. Make only the minimum changes needed for `P1.5-03`.
6. Update `STATUS.md` after the task completes.
7. Update `ARCHITECTURE.md` whenever a concrete audio flow, boundary, or ownership model becomes clearer or changes.
8. Update `CHANGELOG.md` when user-visible audio behavior lands.
9. Update affected specs if and only if implementation reveals a real contract clarification that is required.
10. If you encounter a contradiction or blocker, stop and record:
   - the exact blocker
   - the smallest unblocking decision needed
   - whether it is a plan clarification, spec clarification, CR, or ADR issue

UI-heavy task requirements:
For UI-heavy parts of this task, satisfy the UX quality gate in `AGENTS.md`.
Do not mark the task complete without:
- before / after screenshots or equivalent visual evidence where the UI changes
- width verification at project-relevant breakpoints where applicable
- focused manual flow verification for the affected user path
- accessibility checks for interactive elements where applicable
- where relevant, manual no-kit / disconnected-device / reconnection verification

Acceptance criteria:
- `P1.5-03` is completed cleanly from the current repo state, or a precise blocker is documented.
- `STATUS.md` accurately reflects the task completion or blocker state.
- `ARCHITECTURE.md` is updated if new concrete audio components or flows landed.
- `CHANGELOG.md` is updated for user-visible audio capabilities that landed.
- No out-of-order or out-of-scope work was started.
- The repo is left ready for the next execution-order Phase 1.5 task.
- For any UI-heavy portion of the task, visual evidence and width / manual verification are captured.

Validation:
- Run focused validation for `P1.5-03` only.
- Use targeted tests / checks only for `P1.5-03`.
- Do not run broad future-phase validation unless required.

At the end, summarize:
- files changed
- validations run
- whether `P1.5-03` completed or was blocked
- blockers encountered or not encountered
- whether execution-order readiness was verified before starting
- whether visual evidence was captured for the task where applicable
- whether width checks were performed
- documentation sync status:
  - `STATUS.md`
  - `ARCHITECTURE.md`
  - `CHANGELOG.md`
  - relevant specs
  - `README.md` if applicable
- whether the repo is ready for the next execution-order task

---

## Example 3 — Narrow Control-Doc Clarification Pass

Read `AGENTS.md` first and follow it strictly.

Read `PROJECT.md` next and follow it for Taal-specific execution rules.

Use `docs/prd.md` as the product requirements and scope source of truth.

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
- Clarify only the specified task ordering / dependency wording in `plans/phase-2.md`.
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
- whether renumbering / reordering was avoided
- whether `STATUS.md` reflects the clarified posture

---

## Example 4 — Blocker Resolution Pass

Read `AGENTS.md` first and follow it strictly.

Read `PROJECT.md` next and follow it for Taal-specific execution rules.

Use `docs/prd.md` as the product requirements and scope source of truth.

Use relevant ADRs and specs as authoritative references.

Use `plans/phase-1.md` as the execution contract context for this run.

Use `STATUS.md` as the running state file.

Current state for this run:
- Phase 1 is in progress.
- A blocker has been found between the active implementation and the current docs / contracts.
- I do not want the blocker patched over with hidden tech debt.

Goal of this run:
Analyze the blocker, identify the smallest unblocking decision needed, and apply only the minimum documentation / plan / spec change necessary if the contradiction is clear. Do not opportunistically continue adjacent implementation work.

Required scope for this run:
- Investigate the blocker.
- Determine whether it is:
  - a plan clarification issue
  - a spec clarification issue
  - a CR issue
  - an ADR issue
- Apply only the smallest justified fix.

Files expected to touch:
- only the specific docs / specs / plans needed to resolve the blocker
- `STATUS.md`

Important constraints:
- Do not workaround the blocker in code without documentation alignment.
- Do not broaden scope.
- Do not continue implementation beyond the blocker resolution.

Execution rules:
1. Before making changes, restate:
   - the blocker
   - affected tasks / contracts
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
- Check that the blocker is genuinely resolved at the document / contract level.

At the end, summarize:
- blocker identified
- files changed
- exact unblocking decision made
- whether a CR / ADR was required
- whether implementation can resume safely
