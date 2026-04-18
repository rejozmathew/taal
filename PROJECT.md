# PROJECT.md — Taal-Specific Rules

This file contains project-specific execution rules for Taal. Referenced by `AGENTS.md`.

---

## Timing and Scoring

- Latency-sensitive paths are sacred. Never add unnecessary indirection to the hit → grade → feedback pipeline.
- Rust core is authoritative for timing, scoring, and runtime semantics. Flutter UI renders what the engine tells it.
- Scoring correctness must not depend on UI frame rate.
- UI must not redefine engine behavior.

## Content Contracts

- Lesson/Course/Pack contracts must remain aligned with `docs/specs/content-schemas.md`
- Device mapping behavior must remain aligned with `docs/specs/midi-mapping.md`
- The canonical Grade enum, session state machine, and EngineEvent types are frozen (see `docs/specs/engine-api.md`)

## Platform Rules

- Android is the highest latency risk platform — treat its measurements with extra scrutiny
- Audio output: WASAPI on Windows, AAudio on Android
- MIDI hit sounds from the app are **off by default** for kit-connected users (avoids doubled sound from module + app). On by default for tap pads and listen-first mode.
- Audio output device selection: "System Default" only in v1. Device enumeration is future work. Do not expose a fake device text field.

## UX Minimum Width

- Desktop: 1024px minimum, comfortable at 1920px
- Tablet: 600px minimum (Android tablet portrait)
- Verify at 1024px, 1366px, and 1920px for desktop tasks

## Reference Material

When implementing UI screens, reference these sources for visual quality targets:
- **Melodics** (desktop app): Dark UI with gradient backgrounds, glowing note highway, smooth transitions, polished onboarding
- **Beatlii** (mobile/desktop): Clean card-based layout, difficulty indicators, note highway with color-coded lanes
- **Drumr** (iOS): Activity rings for daily goals, clean notation rendering, SnapCursor note highlighting
- **taal-legacy** (`taal-legacy` repo): Review `crates/ui/src/theme.rs` for design token patterns, `apps/desktop/src/main.rs` for practice controls, MIDI device handling, and count-in overlay. Not a UI target to copy, but contains good UX ideas that should not be regressed.

## Onboarding Rule

The onboarding flow must transition INTO the real app shell when complete — not embed a practice screen inside the wizard. The final onboarding step should hand off to the home screen, which then shows "Start your first lesson" as a CTA.
