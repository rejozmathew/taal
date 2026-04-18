# Changelog

User-visible changes to Taal, described in terms of what users and contributors gain. Task IDs are omitted — see STATUS.md and plans/ for internal tracking.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Post-lesson review screen polish: score header now animates in with a scale effect and color-codes by performance (green for 90%+, teal for 70%+, gold for 50%+), best stat displayed as a trophy badge, lane breakdown bars colored by hit rate, improvement suggestions shown as styled cards with lightbulb icons, and "Next Lesson" promoted to primary button with "Retry" as secondary.
- Animated combo counter in Practice Mode: scales up on each increment, shakes on combo reset, and color intensifies at milestones (8 = green, 16 = gold, 32 = perfect green). Combo milestones display with extra-bold weight.
- Grade flash overlay during practice: a brief screen-edge color wash on Perfect hits (green) and Misses (gray) provides instant visual feedback without blocking the play surface.
- Animated encouragement messages that slide in from the right with a fade when milestone text appears (e.g., "Great streak!").
- Daily goal progress ring replacing the previous linear progress bar: a circular arc rendered with CustomPainter that fills from teal to gold as you approach your daily practice goal, shown on both the home screen and practice toolbar.
- Streak counter with flame icon and day count on the home screen, replacing the plain text metric panel.
- Weekly practice summary as a 7-day grid of practiced vs. skipped day indicators on the home screen.
- Practice toolbar redesign with grouped layout: Transport section (large Play/Pause with icon, Stop button), Mode section (Listen toggle, scope selector, view switcher), Practice Tools section (Metronome, BPM slider, Loop), and Status section (Combo, MIDI indicator, alerts, daily goal). Groups wrap responsively on narrow windows. Toolbar height is constrained with scroll for tight layouts.
- Count-in support for Practice Mode: configurable 0–4 bars of count-in before playback begins. A count-in chip selector in the transport group lets you choose the number of bars. The count-in beat number displays prominently during the countdown. Count-in can be cancelled via Play/Pause toggle.
- Animation framework with shared motion tokens (durations, curves, press scale, hover elevation) in the design system, smooth crossfade+slide transitions when switching between Home, Practice, Library, and Settings, subtle scale feedback on button presses, interactive cards that respond to hover (desktop) and press (mobile) with elevation and border highlight, staggered fade-in for list items, and slide+fade page transitions for Navigator-pushed routes.
- Drum kit visual overhaul with distinct shapes for cymbals (metallic fill, groove rings, bell dot), drums (rim highlight, tension cross-hairs), and kick (concentric rings, beater patch). Cymbals are now visually distinguishable from drums without reading labels. Hi-hat shows a pedal indicator. Hit feedback uses an expanding ring plus grade-colored fill flash.
- Note highway visual overhaul with lane-colored top-to-bottom gradients, approaching glow halos that brighten notes near the hit line, gradient-filled rounded pill note shapes, a soft glow band on the hit line, grade-specific feedback markers (Perfect = expanding double ring, Good = solid core + ring, Early/Late = offset dot, Miss = hollow outline + cross), and smooth fade-out for past-window notes.
- Design system with semantic color tokens, spacing/radius/elevation tokens, Inter font (Regular + Bold), and complete dark and light themes built from tokens instead of `ColorScheme.fromSeed()`.
- Working Light / Dark / System theme selector in Settings that applies immediately without restart and persists across sessions.
- MIDI device lifecycle management with "Scan for devices" in Settings, connection status indicator in Practice Mode, hot-plug SnackBar notifications, disconnect-during-session pause with reconnection prompt, and refresh icon for manual re-enumeration.
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
- Onboarding re-entry from Settings via "Re-run setup wizard" button, returning to onboarding step 1.
- Profile deletion from Settings with a destructive-red button and confirmation dialog.
- Create new profile from Settings without reinstalling the app.
- Profile switcher on the home screen with dropdown showing profile name and avatar initial.
- Every screen now shows a helpful empty state with icon and constructive action when no data is present: Practice shows "Choose a lesson from the Library" with an Open Library button, Insights shows "No practice sessions yet" with a Go to Library button, Library shows a lesson icon.
- Error banners across the app now include an icon and retry action for database or loading failures instead of text-only messages.
- MIDI status banner in Practice showing "No drum kit connected. Tap pads are active." with a Scan for devices button when no kit is connected.
- Browsable lesson library with all 13 starter lessons displayed as cards with title, difficulty badge, BPM, estimated duration, and lane icons.
- Lesson search by title in the Library.
- Difficulty filter (All, Beginner, Intermediate, Variety) in the Library with a "No lessons match your filters" empty state and reset button.
- Lesson detail view with skills, objectives, tags, and a Practice button that navigates to Practice Mode.
- Settings organized into collapsible sections (Profile, MIDI, Audio, Display, Practice, About) with icons and ExpansionTile expand/collapse.
- About section in Settings showing version, credits, and license information.
- Runtime adapter exposes `scheduleDrumHitSound()` for tap-pad and MIDI-originated drum hit audio, gated by the kit-hit-sounds setting.
- Audio output device display simplified to read-only "System Default" (v1 scope).
- Practice habit tracking with per-profile streaks, daily goal progress, rolling weekly summaries, and display-only in-session goal progress.
- Listen-first playback in Practice Mode, with whole-lesson or selected-section drum audio preview that follows the current tempo and scrolls the visual timeline without scoring.
- Auto-pause in Practice Mode, with default-off settings, dense-miss inactivity detection, rest-aware behavior, and resume on the next touch or MIDI hit.
- First-run onboarding for creating a local profile, choosing experience level, connecting or skipping a MIDI kit, and starting the first lesson with tap-pad or MIDI feedback.
- Onboarding redesign with animated dot step indicator, slide transitions between steps, experience-level cards with icons and descriptions, avatar preview during profile creation, and a ready step that hands off to the real app shell instead of embedding a practice screen inside the wizard.
- Layout compatibility checks that warn when a lesson uses lanes unavailable on the current kit, keep those notes visible, adjust scoring fairly, and flag required-lane Play results as partial compatibility.

### Documentation
- Complete product requirements (PRD v1.9) with 77 tasks across 4 phases
- Technical specifications for content schemas, engine API, MIDI mapping, analytics model, and visual language
- Architecture decision record for platform choice (Flutter + Rust, pending validation)
- Phase execution plans with dependency-ordered tasks and acceptance criteria
- Agent execution contract (AGENTS.md) with blocker policy and contract integrity rules
- Living architecture document (ARCHITECTURE.md) with component inventory
