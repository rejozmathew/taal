# Changelog

User-visible changes to Taal, described in terms of what users and contributors gain. Task IDs are omitted — see STATUS.md and plans/ for internal tracking.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Local player profiles with create, switch, delete, preferred practice view, and last-active profile memory backed by local SQLite storage.
- Persistent device profiles for MIDI mappings and calibration offsets, including per-player ownership and last-used profile recall for reconnecting kits.
- Bundled standard 5-piece drum layout for starter lessons, visual drum-kit mapping, and common MIDI note hints.
- Thirteen bundled starter drum lessons with beginner, intermediate, and variety grooves that validate and compile against the standard layout.
- Native metronome audio output on Windows and Android with scheduled click playback, independent volume, and classic, woodblock, and hi-hat click sounds.
- Calibration wizard for measuring snare timing against a click and saving each kit profile's input offset.
- Note-highway practice view component with scrolling lanes, lane-colored notes, and grade-colored hit markers.
- Notation practice view component with a standard drum staff, scrolling/page display modes, current-position highlighting, and grade-colored hit markers.
- Visual drum kit practice component with standard 5-piece pad geometry, custom layout support, and grade-colored hit flashes.
- Practice Mode screen with transport controls, tempo and loop controls, combo feedback, and switchable note-highway, notation, and drum-kit views.
- Post-lesson review screen with score, accuracy, timing distribution, lane breakdowns, positive highlights, improvement suggestions, and retry/next actions.
- Local practice history storage for scored attempts, including lesson, player, course, time-of-day, score, accuracy, and per-lane summary data for future progress and insights views.
- Play Mode scored lesson runs with a count-in, locked lesson tempo, post-run review, and local history recording hook.
- App shell with home, Practice, Library, Studio, Insights, and Settings navigation plus profile switching from home and settings.
- Settings screen for profile, MIDI kit profile, manual latency, velocity curve, metronome, output device, display, auto-pause, and Practice Mode history preferences, backed by local Rust-owned persistence.
- On-screen drum pads for no-kit practice, with touch and MIDI hits routed through the same Rust scoring session and feedback stream.
- Tap pad haptic feedback on hit.
- Metronome clicks scheduled through the native audio output during practice sessions when the metronome is enabled.
- "Play drum sounds on kit hits" setting (off by default for MIDI kit users) with per-profile persistence and settings toggle.
- Runtime adapter exposes `scheduleDrumHitSound()` for tap-pad and MIDI-originated drum hit audio, gated by the kit-hit-sounds setting.
- Audio output device display simplified to read-only "System Default" (v1 scope).
- Practice habit tracking with per-profile streaks, daily goal progress, rolling weekly summaries, and display-only in-session goal progress.
- Listen-first playback in Practice Mode, with whole-lesson or selected-section drum audio preview that follows the current tempo and scrolls the visual timeline without scoring.
- Auto-pause in Practice Mode, with default-off settings, dense-miss inactivity detection, rest-aware behavior, and resume on the next touch or MIDI hit.
- First-run onboarding for creating a local profile, choosing experience level, connecting or skipping a MIDI kit, and starting the first lesson with tap-pad or MIDI feedback.
- Layout compatibility checks that warn when a lesson uses lanes unavailable on the current kit, keep those notes visible, adjust scoring fairly, and flag required-lane Play results as partial compatibility.

### Documentation
- Complete product requirements (PRD v1.9) with 77 tasks across 4 phases
- Technical specifications for content schemas, engine API, MIDI mapping, analytics model, and visual language
- Architecture decision record for platform choice (Flutter + Rust, pending validation)
- Phase execution plans with dependency-ordered tasks and acceptance criteria
- Agent execution contract (AGENTS.md) with blocker policy and contract integrity rules
- Living architecture document (ARCHITECTURE.md) with component inventory
