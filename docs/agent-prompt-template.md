# Agent Prompt Template

Use this template to start a bounded implementation, control-doc, contract-hardening, or blocker-resolution run in this repository.

This template is intentionally structured to work with the current repo document split:

- `AGENTS.md` — universal execution contract
- `PROJECT.md` — Taal-specific execution rules
- `docs/prd.md` — product requirements and system intent
- `docs/adr/*.md` — architecture decisions
- `docs/specs/*.md` — contract definitions
- `plans/phase-x.md` — execution contract for a phase / tranche
- `STATUS.md` — running state file

---

## Continue-Phase Prompt Template

Read `AGENTS.md` first and follow it strictly.

Read `PROJECT.md` next and follow it for Taal-specific execution rules.

Use `docs/prd.md` as the product requirements and scope source of truth.

Use relevant approved ADRs under `docs/adr/` as authoritative architectural overrides where applicable.

Use relevant specs under `docs/specs/` as authoritative contract definitions where applicable.

Use `plans/<phase-file>.md` as the execution contract for this run, including its `Execution Order` section.

Use `STATUS.md` as the running project state file to update after each completed task.

Current state for this run:
- Active phase: `<phase name>`
- The following tasks are already complete and must not be reworked unless a real blocker requires it:
  - `<completed task list>`
- Per `STATUS.md` and the active phase plan's `Execution Order` section, the current execution-order task is:
  - `<current task>`
- No current blockers are recorded unless explicitly noted in `STATUS.md`.
- Partial work for the current task may already exist in the repo. Inspect the current repo state first and continue from what is already there. Do not restart the active task from scratch or discard in-progress work.

Goal of this run:
`<one-paragraph summary of the exact goal of the run>`

Required scope for this run:
- Execute only remaining tasks in the active phase.
- Start by inspecting and continuing the current execution-order task from the current repo state.
- Do not redo already-complete tasks.
- Continue to the next execution-order task only if dependencies are actually satisfied and no blocker appears.
- Use the active phase plan's `Execution Order` section as the primary run sequence.
- Do not start a later phase.
- Do not renumber tasks or rewrite the phase plan structure in this run.

Files expected to touch:
- `STATUS.md`
- `ARCHITECTURE.md` when a component, flow, boundary, or ownership model changes
- `CHANGELOG.md` when user-visible capability lands
- relevant source files for the task(s) actually reached
- focused tests for the task(s) actually reached
- affected specs only if a true contract clarification is strictly required
- `README.md` only if clearly warranted

Important constraints:
- Follow the active phase plan `Execution Order` first.
- Task IDs remain stable identifiers and are not themselves the execution order.
- Respect tranche / milestone boundaries where the plan defines them.
- Do not silently widen contracts or interfaces.
- Do not create hidden tech debt as a workaround.
- Do not create a CR or ADR unless a real contradiction or architectural conflict requires it.
- Keep documentation synchronized with any contract, architecture, or user-visible behavior changes.
- If a task reveals a real blocker, stop at that blocker and document the smallest unblocking decision needed instead of freelancing around it.
- Treat partial work already in the repo as authoritative current state to continue from, not as disposable draft work.

Execution rules:
1. Before making changes, restate:
   - active phase and starting task
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect the active phase plan, especially the `Execution Order` section, plus relevant requirements / ADRs / specs and `STATUS.md` before editing.
3. Inspect the current repo state for partial work on the active task before changing anything. Determine what is already implemented, what remains incomplete, and what docs / tests / status need to be finished.
4. Start with the current execution-order task and complete it from the current repo state.
5. Before beginning the next task, verify that its dependencies are actually satisfied from the current repo state and that any tranche / milestone gate is satisfied.
6. Make only the minimum changes needed for the active task(s) reached in this run.
7. Update `STATUS.md` after each completed task.
8. Update `ARCHITECTURE.md` whenever a component, flow, boundary, or ownership model becomes concrete or changes.
9. Update `CHANGELOG.md` when a user-visible capability lands.
10. Update affected specs if and only if implementation reveals a real contract clarification that is required.
11. If you encounter a contradiction or blocker, stop and record:
   - the exact blocker
   - the smallest unblocking decision needed
   - whether it is a plan clarification, spec clarification, CR, or ADR issue

UI-heavy task requirements:
For any UI-heavy task reached in this run, satisfy the UX quality gate in `AGENTS.md`.
Do not mark the task complete without:
- before / after screenshots or equivalent visual evidence
- width verification at project-relevant breakpoints
- focused manual flow verification for the affected user path
- accessibility checks for interactive elements where applicable
- where relevant, manual no-kit / disconnected-device / reconnection verification

Acceptance criteria:
- The active task is completed cleanly from the current repo state, or a precise blocker is documented.
- If the active task completes and the next execution-order task is reached, that task is completed in execution order or a precise blocker is documented.
- `STATUS.md` accurately reflects which tasks completed in this run.
- `ARCHITECTURE.md` is updated if new concrete components or flows landed.
- `CHANGELOG.md` is updated for user-visible capabilities that landed.
- No out-of-order or out-of-scope work was started.
- The repo is left ready for the next execution-order task or phase completion.
- For UI-heavy tasks, visual evidence and width / manual verification are captured.

Validation:
- Run focused validation for each completed task in this run.
- Use targeted tests / checks only for the task(s) actually reached.
- Do not run broad future-phase validation unless required.

At the end, summarize:
- files changed
- validations run
- which tasks completed in this run
- blockers encountered or not encountered
- whether execution order was followed
- whether tranche / milestone boundaries were respected
- whether visual evidence was captured for each UI-heavy task completed
- whether width checks were performed
- documentation sync status:
  - `STATUS.md`
  - `ARCHITECTURE.md`
  - `CHANGELOG.md`
  - relevant specs
  - `README.md` if applicable
- whether the repo is ready for the next execution-order task or whether the phase is complete

---

## Single-Task Prompt Template

Read `AGENTS.md` first and follow it strictly.

Read `PROJECT.md` next and follow it for Taal-specific execution rules.

Use `docs/prd.md` as the product requirements and scope source of truth.

Use relevant approved ADRs under `docs/adr/` as authoritative architectural overrides where applicable.

Use relevant specs under `docs/specs/` as authoritative contract definitions where applicable.

Use `plans/<phase-file>.md` as the execution contract for this run, including its `Execution Order` section.

Use `STATUS.md` as the running project state file to update after each completed task.

Current state for this run:
- Active phase: `<phase name>`
- Target task: `<task ID and title>`
- Per `STATUS.md` and the active phase plan `Execution Order` section, the target task is execution-order ready.
- The following prior tasks are already complete and must not be reworked unless a real blocker requires it:
  - `<completed task list>`
- Partial work for the target task may already exist in the repo. Inspect the current repo state first and continue from what is already there.

Goal of this run:
Complete the target task cleanly from the current repo state. Do not continue to another task unless explicitly instructed to do so after finishing this one. Stop only on a real blocker, a true contract contradiction, or token limits.

Required scope for this run:
- Execute only the target task.
- Do not redo already-complete tasks.
- Do not start the next task in execution order unless explicitly instructed.
- Use the active phase plan `Execution Order` and target-task acceptance criteria as the governing sequence and completion standard.
- Do not start a later phase.
- Do not renumber tasks or rewrite the phase plan structure in this run.

Files expected to touch:
- `STATUS.md`
- `ARCHITECTURE.md` if a component, flow, boundary, or ownership model changes
- `CHANGELOG.md` when user-visible capability lands
- relevant source files for the target task
- focused tests for the target task
- affected specs only if a true contract clarification is strictly required
- `README.md` only if clearly warranted

Important constraints:
- Confirm the target task is actually execution-order ready before editing.
- Respect tranche / milestone boundaries where the plan defines them.
- Do not silently widen contracts or interfaces.
- Do not create hidden tech debt as a workaround.
- Do not create a CR or ADR unless a real contradiction or architectural conflict requires it.
- Keep documentation synchronized with any contract, architecture, or user-visible behavior changes.
- Treat partial task work already in the repo as authoritative current state to continue from, not as disposable draft work.

Execution rules:
1. Before making changes, restate:
   - active phase and target task
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect the active phase plan, especially the `Execution Order` section and the target task definition, plus relevant requirements / ADRs / specs and `STATUS.md` before editing.
3. Inspect the current repo state for partial work on the target task before changing anything. Determine what is already implemented, what remains incomplete, and what docs / tests / status need to be finished.
4. Verify that all target-task dependencies are satisfied from the current repo state before implementation.
5. Make only the minimum changes needed for the target task.
6. Update `STATUS.md` after the task completes.
7. Update `ARCHITECTURE.md` whenever a component, flow, boundary, or ownership model becomes concrete or changes.
8. Update `CHANGELOG.md` when a user-visible capability lands.
9. Update affected specs if and only if implementation reveals a real contract clarification that is required.
10. If you encounter a contradiction or blocker, stop and record:
   - the exact blocker
   - the smallest unblocking decision needed
   - whether it is a plan clarification, spec clarification, CR, or ADR issue

UI-heavy task requirements:
For any UI-heavy target task, satisfy the UX quality gate in `AGENTS.md`.
Do not mark the task complete without:
- before / after screenshots or equivalent visual evidence
- width verification at project-relevant breakpoints
- focused manual flow verification for the affected user path
- accessibility checks for interactive elements where applicable
- where relevant, manual no-kit / disconnected-device / reconnection verification

Acceptance criteria:
- The target task is completed cleanly from the current repo state, or a precise blocker is documented.
- `STATUS.md` accurately reflects the task completion or blocker state.
- `ARCHITECTURE.md` is updated if new concrete components or flows landed.
- `CHANGELOG.md` is updated for user-visible capabilities that landed.
- No out-of-order or out-of-scope work was started.
- For UI-heavy tasks, visual evidence and width / manual verification are captured.

Validation:
- Run focused validation for the target task only.
- Use targeted tests / checks only for the target task.
- Do not run broad future-phase validation unless required.

At the end, summarize:
- files changed
- validations run
- whether the target task completed or was blocked
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

## Notes for the Human Operator

Use these templates for:
- continuing an active phase from the current repo state
- completing a single execution-order task
- narrow control-doc clarification passes
- contract / spec hardening passes
- blocker-resolution passes

Prefer smaller bounded runs over “implement the whole repo” prompts.

When in doubt:
- point the agent at one active phase or one narrow tranche
- explicitly state what is out of scope
- explicitly list files expected to change
- explicitly define validation and acceptance
- explicitly say whether the run is “continue phase” or “single task”
