# Agent Prompt Template

Use this template to start a bounded implementation or control-doc run in this repository.

This template is intentionally structured to work with:
- `AGENTS.md` as the canonical execution contract
- `docs/prd.md` as the product source of truth
- `docs/adr/*.md` as architecture decisions
- `docs/specs/*.md` as frozen or partially frozen contract definitions
- `plans/phase-x.md` as the execution contract for a phase or tranche
- `STATUS.md` as the running state file

---

## Generic Prompt Template

Read `AGENTS.md` first and follow it strictly.

Use `docs/prd.md` as the baseline product and architecture source of truth.

Use relevant approved ADRs under `docs/adr/` as authoritative architectural overrides where applicable.

Use relevant specs under `docs/specs/` as authoritative contract definitions where applicable.

Use `plans/<phase-file>.md` as the execution contract for this run.

Use `STATUS.md` as the running project state file to update after each completed task.

Current state for this run:
- <state of completed phases/tasks>
- <state of active phase>
- <repo/runtime assumptions relevant to the run>
- <any approved clarifications already in effect>

Goal of this run:
<one-paragraph summary of the exact goal of the run>

Required scope for this run:
- <specific task(s) or tranche(s) to execute>
- <what must be clarified / implemented / validated>
- <what must remain unchanged>

Files expected to touch:
- <file 1>
- <file 2>
- <file 3>

Important constraints:
- Do not broaden scope beyond this run.
- Do not silently reorder the phase unless a true contradiction forces it.
- Do not introduce hidden tech debt as a workaround.
- Do not widen contracts or interfaces silently.
- Do not create a CR or ADR unless a real contradiction or architectural conflict requires it.
- Keep documentation synchronized with any contract, architecture, or user-visible behavior changes.

Execution rules:
1. Before making changes, restate:
   - task
   - goal summary
   - files expected to touch
   - validation to run
   - acceptance criteria
2. Inspect the current plan, specs, ADRs, and `STATUS.md` before editing.
3. Follow dependency order where stated; task IDs are identifiers, not execution order.
4. Make only the minimum changes needed to satisfy the task.
5. Update documentation as required by `AGENTS.md`, including:
   - `STATUS.md`
   - `ARCHITECTURE.md` when components, flows, boundaries, or ownership shift
   - `CHANGELOG.md` when user-visible behavior lands
   - affected specs when contracts change
6. If you encounter a contradiction or blocker, stop and record:
   - the exact blocker
   - the smallest unblocking decision needed
   - whether it is a plan clarification, spec clarification, CR, or ADR issue

Acceptance criteria:
- <criterion 1>
- <criterion 2>
- <criterion 3>

Validation:
- <targeted validation step 1>
- <targeted validation step 2>
- <consistency checks or tests to run>

At the end, summarize:
- files changed
- validations run
- blockers encountered or not encountered
- whether downstream renumbering/reordering was avoided
- documentation sync status:
  - `STATUS.md`
  - `ARCHITECTURE.md`
  - `CHANGELOG.md`
  - relevant specs
  - `README.md` if applicable
- whether the repo is ready for the next intended task/tranche

---

## Notes for the Human Operator

Use this template for:
- full phase execution
- narrow tranche execution
- control-doc clarification passes
- contract/spec hardening passes
- blocker-resolution passes

Prefer smaller bounded runs over “implement the whole repo” prompts.

When in doubt:
- point the agent at one phase or one narrow tranche
- explicitly state what is out of scope
- explicitly list files expected to change
- explicitly define validation and acceptance