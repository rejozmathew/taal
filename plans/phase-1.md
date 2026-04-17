# Phase 1: Core Practice Loop

**Objective:** A user can connect their kit, play a lesson, and get real-time feedback. This is the minimum lovable product for the Practice Player.

**Prerequisite:** Phase 0 complete. ADR-001 accepted with conditional caveat per CR-001.

---

## Execution Order

Task IDs remain stable references. Execute Phase 1 in the order below unless a blocker, approved CR, or newly discovered contradiction requires a narrower clarification pass.

### Completed execution order to date
1. **P1-00** Android Native-to-Rust Jitter Investigation
2. **P1-01** Rust Content Module — Parse Lesson, Layout, Scoring Profile
3. **P1-02** Rust Time Module — Musical ↔ Millisecond Conversion
4. **P1-03** Rust Compile Module — Lesson to Execution Timeline
5. **P1-04** Rust Runtime — Session Lifecycle
6. **P1-05** Rust Scoring — Timing Windows, Grades, Combos
7. **P1-06** MIDI Mapping Engine — Note to Lane, Hi-Hat CC4

### Recommended remaining execution order
8. **P1-16** Local Profiles
9. **P1-08** Device Profile Persistence
10. **P1-19** Standard 5-Piece Layout Definition
11. **P1-18** Starter Lesson Content
12. **P1-15** Metronome Audio Output
13. **P1-07** Calibration Wizard UI + Logic
14. **P1-09** Note-Highway Widget
15. **P1-10** Notation View Widget
16. **P1-11** Visual Drum Kit Widget
17. **P1-12** Practice Mode Screen
18. **P1-14** Post-Lesson Review Screen
19. **P1-21** Practice Attempt Persistence
20. **P1-13** Play Mode Screen
21. **P1-22** App Shell — Home Screen, Navigation, Profile Switcher
22. **P1-20** Settings Screen
23. **P1-23** On-Screen Tap Pads (No-Kit Practice Mode)
24. **P1-24** Practice Streaks and Daily Goal Tracking
25. **P1-25** Listen-First Playback
26. **P1-26** Auto-Pause on Player Inactivity
27. **P1-17** Onboarding Flow
28. **P1-27** Layout Compatibility Check + Missing-Lane Handling

**Execution notes**
- `P1-07` stays after `P1-15` because calibration depends on actual metronome audio.
- `P1-08` stays after `P1-16` because device profiles are owned by local profiles.
- `P1-18` stays after `P1-19` because starter lessons reference the standard layout.
- `P1-13` stays after `P1-14` and `P1-21` because Play Mode needs review and attempt persistence to be real.
- `P1-17` is intentionally late because onboarding depends on calibration, starter content, practice mode, and tap pads.
- `P1-27` is intentionally late because it crosses compile, mapping, practice, play, and review behavior.

---

## Tasks

### P1-00: Android Native-to-Rust Jitter Investigation

**Deps:** P0-07

**Objective:** Characterize the Android p99 jitter seen in Phase 0 before relying on the Android MIDI hot path for user-facing Practice Mode flows.

**Outputs:**
- Repeat or targeted release-mode measurements on Android using the existing Phase 0 latency harness or the first available Phase 1 MIDI path
- Segment-level analysis for native MIDI callback -> Dart event delivery -> Rust bridge entry -> Rust processing -> Flutter callback return
- Recommendation: keep the current Android platform-channel path with documented caveat, or file a targeted implementation task for Native-to-Rust hot-path optimization
- STATUS.md updated with the investigation result before calibration and Practice Mode rely on Android latency behavior

**Acceptance criteria:**
- Android p99 jitter source is documented by segment or dominant suspected segment
- Decision recorded on whether the current Android path is acceptable for Phase 1 Practice Mode
- No UI framework, Rust-core ownership, or overall platform architecture decision is reopened
- Frame-drop validation remains deferred to the first real animated Practice Mode path

### P1-01: Rust Content Module — Parse Lesson, Layout, Scoring Profile

**Deps:** P0-04

**Objective:** Load and validate content files from JSON into typed Rust structs.

**Outputs:**
- `rust/src/content/lesson.rs`: deserialize Lesson from JSON, validate schema
- `rust/src/content/layout.rs`: deserialize InstrumentLayout
- `rust/src/content/scoring.rs`: deserialize ScoringProfile
- Validation: required fields present, lane_ids unique, section ranges valid, events sorted by position
- Unit tests for valid and invalid content

**Acceptance criteria:**
- Valid lesson JSON loads successfully
- Invalid lesson JSON (missing fields, duplicate lane_ids, overlapping sections) produces clear error
- P1-01 validation fixtures for lesson/layout/scoring-profile deserialization pass validation; bundled starter content validation is completed in P1-18/P1-19

---

### P1-02: Rust Time Module — Musical ↔ Millisecond Conversion

**Deps:** P0-04

**Objective:** Bidirectional conversion between musical positions (bar/beat/tick) and absolute milliseconds using a tempo map.

**Outputs:**
- `rust/src/time/mod.rs`: `MusicalPos`, `TimingIndex`
- `TimingIndex::from_tempo_map()` builds lookup from tempo entries
- `pos_to_ms()` and `ms_to_pos()` conversions
- Handles constant tempo (single entry) and multi-tempo (future)
- Unit tests including edge cases (first beat, last beat, between tempo changes)

**Acceptance criteria:**
- Constant 120 BPM: bar 1, beat 1, tick 0 = 0ms; bar 2, beat 1, tick 0 = 2000ms
- Subdivision accuracy: 480 ticks per beat at 120 BPM = 1.04ms per tick
- Round-trip: pos → ms → pos is lossless for grid-aligned positions

---

### P1-03: Rust Compile Module — Lesson to Execution Timeline

**Deps:** P1-01, P1-02

**Objective:** Compile a Lesson + ScoringProfile into an optimized runtime representation with events indexed by absolute time.

**Outputs:**
- `rust/src/content/compile.rs`: `compile_lesson()` → `CompiledLesson`
- `CompiledLesson` contains: events sorted by `t_ms`, section ranges in ms, lane index
- Each compiled event has both musical position and absolute time

**Acceptance criteria:**
- Compiled lesson events are sorted by t_ms
- Section boundaries correctly converted to ms ranges
- Compilation is deterministic: same input → identical output

---

### P1-04: Rust Runtime — Session Lifecycle

**Deps:** P1-03

**Objective:** Implement the real-time session that accepts hits, grades them, and emits events.

**Outputs:**
- `rust/src/runtime/session.rs`: `Session` with start/stop/tick/on_hit/drain_events
- Session state machine: `Ready → Running → Paused → Stopped`
- `on_hit(InputHit)`: matches hit to nearest expected event within window, emits `HitGraded`
- `tick(now_ns)`: advances time, detects misses past window, emits `Missed` events
- `drain_events(max)`: returns batched `EngineEvent` list
- `stop()`: returns `AttemptSummary` with all scoring metrics

**Acceptance criteria:**
- Hit near expected event → `HitGraded` with correct grade and delta_ms
- No hit after window → `Missed` emitted on next tick
- Combo increments on Perfect/Good, resets on Miss
- `AttemptSummary` contains: score, accuracy, timing bias, per-lane stats
- State transitions enforced (can't submit hits when Stopped)
- All unit tests pass

---

### P1-05: Rust Scoring — Timing Windows, Grades, Combos

**Deps:** P1-04

**Objective:** Implement the scoring logic driven by ScoringProfile.

**Outputs:**
- Grade computation from delta_ms against timing windows
- Score accumulation formula
- Combo/streak tracking with milestone detection
- Per-lane statistics accumulation
- Configurable via ScoringProfile (window sizes, grade weights)

**Acceptance criteria:**
- Grade matches expected for delta values at window boundaries
- Score formula produces 0-100 range
- Combo milestones emit Encouragement events at configured thresholds
- Different ScoringProfiles produce different grades for same delta

---

### P1-06: MIDI Mapping Engine — Note to Lane, Hi-Hat CC4

**Deps:** P0-03, P0-06, P1-00

**Objective:** Map raw MIDI note/CC events to semantic lane_ids using a device profile.

**Outputs:**
- `rust/src/midi/mapping.rs`: `MidiMapper` that takes raw MIDI + device profile → `MappedHit { lane_id, velocity, articulation, timestamp_ns }`
- Hi-hat CC4 state tracking with threshold-based articulation resolution
- Unmapped note handling: emit warning, don't crash
- Deduplication: suppress duplicate NoteOn within configurable window

**Acceptance criteria:**
- MIDI note 38 with snare mapping → `lane_id: "snare"`
- Hi-hat note with CC4=10 (closed) → `articulation: "closed"`
- Hi-hat note with CC4=100 (open) → `articulation: "open"`
- Unknown note → warning event, not error
- Rapid duplicate notes within 8ms → second suppressed

---

### P1-07: Calibration Wizard UI + Logic

**Deps:** P1-06, P1-15

**Objective:** Guide the user through measuring and storing their device's input latency offset.

**Outputs:**
- Flutter screen: visual metronome + instruction text
- Plays clicks at fixed tempo (100 BPM)
- Captures user hits (snare) for 8-16 beats
- Computes median offset between expected and actual timestamps
- Stores `input_offset_ms` in device profile
- Shows result with quality indicator ("12ms — excellent", "35ms — usable, consider USB")

**Acceptance criteria:**
- Calibration produces a stable offset value (low variance across hits)
- Offset is applied to all subsequent hits from this device
- Recalibration overwrites previous offset
- User can skip calibration (offset defaults to 0)

---

### P1-08: Device Profile Persistence

**Deps:** P1-06, P1-16

**Objective:** Save and load device profiles (mapping + calibration + velocity curve) in SQLite.

**Outputs:**
- SQLite table for device profiles
- CRUD operations: create, read, update, delete profiles
- Auto-load last-used profile on device reconnection
- Multiple profiles per device (e.g., different mapping for practice vs performance)

**Acceptance criteria:**
- Save profile → close app → reopen → profile loaded
- Switch between profiles without restarting session
- Delete profile removes it permanently

---

### P1-09: Note-Highway Widget

**Deps:** P0-02

**Objective:** Build the primary practice view — vertical scrolling lanes with notes approaching a hit line.

**Outputs:**
- Flutter custom painter: vertical lanes per drum piece
- Notes scroll top-to-bottom toward a fixed hit line
- Scroll speed adjustable (tied to tempo)
- Color-coded by lane
- Hit feedback overlaid: timing-state color on hit marker
- Smooth 60fps rendering

**Acceptance criteria:**
- Notes visually approach hit line in sync with lesson timeline
- Hit markers appear at correct offset from center (early=left, late=right)
- Colors match canonical grade semantics (specs/visual-language.md)
- No frame drops during normal practice (verified on target hardware)

---

### P1-10: Notation View Widget

**Deps:** P0-02

**Objective:** Build the secondary practice view — standard drum notation on a staff.

**Outputs:**
- Flutter custom painter: drum staff with standard notation
- Scrolling (current position highlighted) or page-based (user toggle)
- Same timing feedback overlay as note-highway (hit markers with grade colors)
- Renders from same compiled lesson as note-highway

**Acceptance criteria:**
- Correct drum notation rendering (kick on space below, snare on 3rd line, etc.)
- Current playback position clearly indicated
- Scoring semantics identical to note-highway (same engine events, same grades)
- Toggle between views mid-lesson without losing state

---

### P1-11: Visual Drum Kit Widget

**Deps:** P0-02

**Objective:** Interactive 2D drum kit display used for mapping, calibration, and practice feedback.

**Outputs:**
- Flutter widget: overhead/angled drum kit view
- Each pad animates on MIDI input (flash with grade color)
- Adapts to active instrument layout (shows correct pads for 5-piece vs extended)
- Used in: MIDI mapping screen (tap-to-map), calibration, settings, optional practice overlay

**Acceptance criteria:**
- Pad lights up within one frame of MIDI event arrival
- Correct pad lights up for mapped note
- Unmapped notes produce no visual (or subtle indicator)
- Layout adapts when instrument layout changes

---

### P1-12: Practice Mode Screen

**Deps:** P1-04, P1-09, P1-10, P1-11, P1-15

**Objective:** The main practice screen combining transport controls, view selector, and real-time feedback.

**Outputs:**
- Transport bar: play/pause, tempo slider, metronome toggle, loop toggle
- View selector: note-highway / notation / drum kit (toggle)
- A-B loop: section selector dropdown + manual drag handles on timeline
- Tempo adjustment (live, non-destructive)
- Combo counter display
- Encouragement message overlay (subtle, auto-dismiss)

**Acceptance criteria:**
- User can start/pause/resume a practice session
- Tempo change takes effect immediately (next beat)
- A-B loop repeats selected section indefinitely
- All three views available and switchable mid-session

---

### P1-13: Play Mode Screen

**Deps:** P1-12, P1-14, P1-21

**Objective:** Scored assessment mode — fixed tempo, full lesson run, score at end.

**Outputs:**
- Same visual layout as Practice Mode but: tempo locked, no A-B loop, no hints
- Count-in before start
- Post-run: triggers review screen with attempt summary

**Acceptance criteria:**
- Tempo matches lesson default (not adjustable)
- Full lesson plays through without user-initiated pauses
- AttemptSummary correctly populated at end
- Score stored in practice history

---

### P1-14: Post-Lesson Review Screen

**Deps:** P1-05

**Objective:** Display detailed performance feedback after a lesson attempt.

**Outputs:**
- Score display with animation (ease-in)
- Accuracy percentage
- Timing histogram (early/late distribution chart)
- Per-lane breakdown (heatmap or bar chart)
- 1-2 textual improvement suggestions (based on lane stats)
- Buttons: Retry / Next Lesson / Back to Library
- Course progress indicator (if applicable)

**Acceptance criteria:**
- All metrics match AttemptSummary values
- Positive reinforcement shown first (best stat highlighted)
- Timing histogram visually communicates early/late bias

---

### P1-15: Metronome Audio Output

**Deps:** P0-03

**Objective:** Low-latency metronome click synchronized to lesson timeline.

**Outputs:**
- Platform-native audio output (WASAPI on Windows, AAudio on Android)
- Pre-rendered click samples (accent on beat 1, normal on other beats)
- Sample-accurate scheduling relative to lesson tempo
- Volume control (independent from backing track)
- Click sound presets (classic, woodblock, hi-hat)

**Acceptance criteria:**
- Click is audibly in time with note-highway scroll
- No perceptible drift over a 4-minute lesson
- Volume adjustable without audio glitch
- Acceptable latency on both Windows and Android

---

### P1-16: Local Profiles

**Deps:** P0-02

**Objective:** "Who's playing?" — local user profiles without login.

**Outputs:**
- Profile creation screen (name, optional avatar selection, experience level)
- Profile switcher (accessible from home screen)
- Each profile owns: practice history, device profiles, preferences, preferred view
- SQLite-backed persistence

**Acceptance criteria:**
- Create profile → switch profile → data is separate
- Deleting a profile removes all its data
- App remembers last-active profile

---

### P1-17: Onboarding Flow

**Deps:** P1-07, P1-16, P1-12, P1-18, P1-23

**Objective:** First-run experience as specified in PRD Section 2.4.

**Outputs:**
- 5-6 screen flow: Welcome → Profile → Experience → Connect Kit → Calibrate → First Lesson
- Graceful handling of no MIDI device (demo mode with on-screen tap pads)
- Skip options at each step
- Transitions to first playable lesson within 90 seconds

**Acceptance criteria:**
- New user with MIDI connected: install → playing with feedback in < 90 seconds
- New user without MIDI: reaches demo mode with tap pads
- Experience level selection affects which starter lesson loads first

---

### P1-18: Starter Lesson Content

**Deps:** P1-01, P1-19

**Objective:** 10-15 bundled drum lessons covering beginner to intermediate.

**Outputs:**
- 5 beginner lessons (basic rock beat, simple fills, 8th-note patterns)
- 5 intermediate lessons (16th-note patterns, syncopation, dynamics)
- 3-5 additional variety lessons (blues shuffle, funk groove, etc.)
- All lessons validated against content schema
- Each lesson tagged with learning outcomes from starter taxonomy

**Acceptance criteria:**
- All lessons load and play correctly
- Difficulty progression is sensible (beginner → intermediate)
- At least 3 lessons are genuinely fun to play repeatedly

---

### P1-19: Standard 5-Piece Layout Definition

**Deps:** P1-01

**Objective:** Define the default drum kit instrument layout.

**Outputs:**
- Layout JSON: kick, snare, hi-hat (closed/open/pedal), ride, crash, high tom, low tom, floor tom
- MIDI hints for General MIDI and common kits (Roland, Yamaha, Alesis)
- Visual slot mapping (for drum kit widget)

**Acceptance criteria:**
- Layout validates against InstrumentLayout schema
- All starter lessons reference this layout
- MIDI hints match actual note assignments on test kits

---

### P1-20: Settings Screen

**Deps:** P1-08, P1-07, P1-15, P1-16

**Objective:** User-accessible configuration for MIDI, audio, display, and profile.

**Outputs:**
- MIDI section: device selection, mapping view, recalibrate button, velocity curve
- MIDI section: manual latency offset slider (-50ms to +50ms) with real-time preview tap-along
- Audio section: metronome volume, click sound, output device
- Display section: preferred view (note-highway/notation), theme, reduce motion, high contrast
- Profile section: edit name, switch profile, manage profiles
- Auto-pause toggle (default: off)

**Acceptance criteria:**
- All settings persist across app restarts
- Settings changes take effect immediately (no restart required)
- MIDI recalibration accessible without leaving settings
- Manual latency slider adjusts offset and stores in device profile

**Contract note (CR-006):**
- P1-20 settings persistence follows `docs/specs/engine-api.md` §10.
- Device-profile-owned settings follow `docs/specs/midi-mapping.md` §1 "P1-20 Device-Profile Settings."
- Auto-pause behavior is still implemented in P1-26; P1-20 only persists the toggle/default settings that P1-26 reads.

---

### P1-21: Practice Attempt Persistence

**Deps:** P1-05, P1-16

**Objective:** Store every scored attempt in SQLite for analytics (Phase 3) and progress tracking.

**Outputs:**
- SQLite table matching PracticeAttempt struct
- Write immediately after successful `session_stop`, using the returned `AttemptSummary` plus caller-supplied `PracticeAttemptContext`
- Query: by player, by lesson, by date range, by course
- Indexed for dashboard queries (player + time, player + lesson)

**Acceptance criteria:**
- Every Play Mode completion creates an attempt record
- Practice Mode attempts optionally stored (user setting)
- Query returns correct results for date/lesson/player filters
- Storage size reasonable (~1KB per attempt)
- `session_stop(session) -> Result<AttemptSummary, SessionError>` remains unchanged; P1-21 uses the separate Rust storage API from `analytics-model.md`

---

### P1-22: App Shell — Home Screen, Navigation, Profile Switcher

**Deps:** P1-16

**Objective:** The top-level application structure that all other screens plug into.

**Outputs:**
- Home screen / landing surface showing: welcome message, recommended next lesson, recent practice summary, streak counter
- Top-level navigation between: Practice, Library, Studio (placeholder), Insights (placeholder), Settings
- Profile switcher accessible from home screen or settings
- Navigation adapts to platform (bottom tabs on Android/tablet, sidebar on desktop)

**Acceptance criteria:**
- All major sections reachable from home screen
- Profile switcher works (swap profiles, see different data)
- Navigation is consistent and does not break when screens are incomplete (placeholder screens OK)

---

### P1-23: On-Screen Tap Pads (No-Kit Practice Mode)

**Deps:** P0-02, P1-04, P1-12

**Objective:** Allow practice without a MIDI device using virtual drum pads on screen.

**Outputs:**
- Touch-responsive drum pad layout on screen (kick, snare, hi-hat, toms, cymbals)
- Taps generate the same InputHit events as MIDI (with touch timestamp)
- Same timing feedback and scoring as MIDI input
- Available when no MIDI device is connected, or as a user-selected mode
- Velocity: fixed or estimated from touch pressure (platform-dependent)

**Acceptance criteria:**
- Practice a lesson using only touch input — scoring works
- Feedback animations identical to MIDI input
- Usable on tablet (touch targets large enough)
- Not a replacement for real kit (noted in UI: "Connect your kit for the best experience")

---

### P1-24: Practice Streaks and Daily Goal Tracking

**Deps:** P1-21, P1-22

**Objective:** Lightweight gamification to drive daily practice habit.

**Outputs:**
- Daily streak counter: consecutive days with at least one scored session
- Configurable daily practice goal (default: 10 minutes)
- Progress indicator on home screen (ring or bar)
- Weekly summary: days practiced, total time, lessons completed
- Streak milestone messages (7, 30, 100 days — encouraging, not punishing)
- Streak data stored per player profile in SQLite

**Acceptance criteria:**
- Streak increments correctly across days
- Missing a day resets streak with encouraging message
- Daily goal progress updates in real-time during practice
- Streak data is per-profile (not global)

---

### P1-25: Listen-First Playback

**Deps:** P1-04, P1-12, P1-15

**Objective:** Let users hear a section/lesson played back with synthesized drum sounds before attempting it.

**Outputs:**
- "Listen" button in Practice Mode (per-section and whole lesson)
- Plays the lesson events through GM drum samples via metronome audio path
- Visual: note-highway or notation scrolls without scoring active
- Playback respects current tempo setting
- Button toggles: Listen → Stop Listening → Play

**Acceptance criteria:**
- User taps Listen → hears the pattern with correct timing and sounds
- Visual scroll matches audio
- No scoring during listen mode
- Works at adjusted tempo (not just default)

---

### P1-26: Auto-Pause on Player Inactivity

**Deps:** P1-04, P1-12, P1-20

**Objective:** Automatically pause practice when the player stops playing during an active section.

**Outputs:**
- Detect inactivity: no hits received while expected hits are occurring, for configurable duration (default 3 seconds)
- Pause session and show "Paused — tap any pad to resume"
- Resume on next hit (or resume button)
- **Does NOT trigger during intentional rests** — only when expected notes are being missed
- Practice Mode only (not Play Mode or Course Gate)
- Disabled by default; enabled via Settings toggle

**Acceptance criteria:**
- During a dense pattern, stopping for 3 seconds triggers auto-pause
- During a lesson with a 4-beat rest, auto-pause does NOT trigger
- Disabled by default; toggling on in settings takes effect immediately
- Pausing and resuming does not lose session state

---

### P1-27: Layout Compatibility Check + Missing-Lane Handling

**Deps:** P1-03, P1-06, P1-12, P1-13, P1-14

**Objective:** Before a lesson starts, check whether the player's kit can cover all lesson lanes. Handle mismatches gracefully in Practice and Play modes. (Course Gate enforcement is integrated in P2-17.)

**Outputs:**
- On lesson load: derive `lesson_lanes` from compiled events, split into `required_lanes` and `optional_lanes` (from lesson metadata), compare against `mapped_lanes` from active device profile
- Compatibility indicator: green (all present), yellow (only optional missing), red (required lanes missing)
- Practice Mode: always allow with warning banner listing missing lanes; missing-lane events shown but not scored
- Play Mode: allow; result marked "partial compatibility: N lanes unavailable"; missing events excluded from score denominator; review screen states "Scoring adjusted: N lanes unavailable"
- Default: all lanes required (empty `optional_lanes` list means everything is required)

**Acceptance criteria:**
- Load a lesson with cowbell (marked optional) on a kit without cowbell → yellow indicator, cowbell events visible but not scored, score denominator adjusted
- Load a lesson with snare (required) on a kit without snare mapped → red indicator, Practice allowed with warning, Play result marked "partial compatibility"
- All-lanes-present kit → green indicator, normal behavior
- Review screen explicitly names excluded lanes
- Partial-compatibility Play Mode results are flagged and do not qualify as personal bests

---

## Exit Criteria for Phase 1

- [ ] New user: install → connect → calibrate → play lesson → see score in < 2 minutes
- [ ] Note-highway view functional with real-time hit feedback at 60fps
- [ ] Notation view functional with same scoring semantics
- [ ] Visual drum kit responds to MIDI hits with correct grade colors
- [ ] Practice Mode: tempo adjust + A-B loop working
- [ ] Play Mode: scored run with post-lesson review
- [ ] Metronome audible with acceptable sync
- [ ] 10+ starter lessons playable
- [ ] Local profiles: create, switch, separate data
- [ ] Onboarding flow complete
- [ ] Device profiles persist across app restarts
- [ ] Practice attempts stored in SQLite
- [ ] App shell with working navigation between all sections
- [ ] On-screen tap pads functional for no-kit practice
- [ ] Practice streak counter visible on home screen
- [ ] Listen-first playback works for any section
- [ ] Auto-pause triggers correctly (active sections only, not during rests)
- [ ] Manual latency slider in settings adjusts offset
- [ ] Layout compatibility check warns on missing lanes and adjusts scoring
