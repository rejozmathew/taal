# CR-009: Phase 1 UX Remediation

**Date:** 2026-04-18
**Triggered by:** User testing of Phase 1 deliverable
**Documents affected:** plans/ (new phase-1.5.md), AGENTS.md, PROJECT.md (new), STATUS.md

## Problem

Phase 1 code is functionally complete but UI/UX quality is far below PRD intent. User testing revealed: no audio output during practice (metronome events silently discarded), broken light theme, no MIDI device re-detection after launch, no way to return to onboarding, no design system (raw Material auto-theme), minimal animations (9 usages in 10K+ lines), practice screen cramped by embedding full practice widget inside onboarding wizard, library shows one lesson with one button, settings is an unsectioned scroll dump.

The taal-legacy prototype (2,947 lines) had more intentional UX than the current 50K-line codebase: custom design tokens, themed visuals, live MIDI device enumeration, count-in overlay, richer practice controls.

Backend is sound and should be preserved: Rust engine (scoring, grading, session management), MIDI adapters (Windows + Android), WASAPI audio synthesis engine (per-lane drum sounds), content pipeline (13 lessons), SQLite persistence.

## Proposed Change

Insert **Phase 1.5 (UX Remediation)** between Phase 1 and Phase 2, organized as:

- **Tranche A (Fix Broken):** Design system, theme switching, audio wiring, onboarding re-entry, MIDI lifecycle, error states, settings restructure, library overhaul, onboarding redesign
- **Tranche B (Make Premium):** Animation framework, note highway overhaul, drum kit overhaul, practice toolbar redesign, combo/grade effects, review polish, daily goal visuals, tap pad polish, global polish pass

Additionally:
- Split AGENTS.md into reusable core + PROJECT.md for taal-specific rules
- Add UX quality gate with evidence requirements to prevent recurrence
- Speed training remains in Phase 2 (not pulled into remediation)

## Impact

- New: `plans/phase-1.5.md`, `PROJECT.md`
- Modified: `AGENTS.md` (reusable), `CLAUDE.md`, `STATUS.md`
- Phase 2+ timeline shifts by Phase 1.5 duration
- No PRD changes (PRD already specifies desired quality)
- No ADR changes (architecture is correct)

## Status
- [x] Proposed
- [ ] Approved
- [ ] Applied
