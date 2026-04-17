# Taal Architecture Overview

**This is a living document.** It describes what the system looks like *right now*, not what it will look like eventually. Updated whenever a task adds a new component, changes a data flow, or introduces a dependency.

For product requirements, see [docs/prd.md](docs/prd.md). For specific contracts, see the [docs/specs/](docs/specs/) directory.

---

## Component Inventory

What currently exists in this repo (updated as code lands). Status is one of: **Implemented**, **Partial**, or **Planned**.

| Component | Location | Status |
|-----------|----------|--------|
| PRD + specs + plans | `docs/`, `plans/` | Implemented |
| Flutter app shell | `lib/features/app_shell/`, `lib/main.dart`, `test/app_shell_test.dart` | Implemented (P1-22 adaptive home/navigation shell with profile switcher, recommended lesson surface, recent practice/streak placeholders, safe placeholders for incomplete sections, and P1-20 Settings destination wiring) |
| Flutter Settings screen | `lib/features/settings/`, `test/settings_*_test.dart` | Implemented (P1-20 profile, MIDI kit profile, manual latency, velocity curve, audio, display, auto-pause, and Practice Mode history preferences backed by Rust-owned persistence) |
| Flutter local profile UI | `lib/features/profiles/` | Implemented (P1-16 create/switch/delete local profiles, experience/avatar selection, preferred view control) |
| Flutter calibration wizard | `lib/features/calibration/`, `test/calibration_*_test.dart` | Implemented (P1-07 100 BPM snare calibration, median offset/jitter result, persisted device-profile offset updates) |
| Flutter note-highway widget | `lib/features/player/note_highway/`, `test/note_highway_test.dart` | Implemented (P1-09 vertical lane painter, timeline-synced note geometry, grade-colored hit markers) |
| Flutter notation view widget | `lib/features/player/notation/`, `test/notation_view_test.dart` | Implemented (P1-10 drum-staff painter, standard 5-piece lane placements, scrolling/page display geometry, grade-colored hit markers) |
| Flutter visual drum kit widget | `lib/features/player/drum_kit/`, `test/drum_kit_test.dart` | Implemented (P1-11 overhead kit painter, standard 5-piece pad geometry, custom layout adaptation, grade-colored hit flashes) |
| Flutter Practice Mode screen | `lib/features/player/practice_mode/`, `test/practice_mode_screen_test.dart` | Implemented (P1-12 transport, tempo, metronome/loop controls, A-B loop state, combo/encouragement display, switchable practice views) |
| Flutter Practice runtime input adapter | `lib/features/player/` + Rust bridge API | Planned (P1-23 clarified by CR-007: route MIDI-derived and touch-generated hits into the same Rust `Session` without moving scoring into Flutter) |
| Flutter Play Mode screen | `lib/features/player/play_mode/`, `test/play_mode_screen_test.dart` | Implemented (P1-13 locked-tempo scored runs, count-in, review handoff, and post-run attempt recording hook) |
| Flutter post-lesson review screen | `lib/features/player/review/`, `test/post_lesson_review_screen_test.dart` | Implemented (P1-14 score/accuracy summary, timing histogram, lane breakdown, best-stat highlight, improvement suggestions, review actions) |
| Rust core engine | `rust/` | Partial (Phase 0 bridge API + runtime session; P1-01 content parsing/validation; P1-02 time indexing/conversion; P1-03 lesson compilation; P1-04 session lifecycle; P1-05 scoring; P1-06 MIDI mapping; P1-16 local profile persistence; P1-08 device profile persistence; P1-21 practice attempt persistence; P1-20 settings persistence) |
| Rust content module | `rust/src/content/`, `rust/tests/content_validation.rs` | Implemented (P1-01 Lesson, InstrumentLayout, and ScoringProfile parsing/validation) |
| Rust compile module | `rust/src/content/compile.rs`, `rust/tests/lesson_compile.rs` | Implemented (P1-03 Lesson + layout + scoring profile to immutable CompiledLesson timeline) |
| Rust time module | `rust/src/time/`, `rust/tests/time_conversion.rs` | Implemented (P1-02 MusicalPos tick arithmetic and TimingIndex musical <-> millisecond conversion) |
| Rust runtime session | `rust/src/runtime/session.rs`, `rust/tests/runtime_session.rs` | Implemented (P1-04 compiled-lesson session lifecycle, hit/miss event emission, summary metrics; P1-15 metronome click schedule events) |
| Rust scoring module | `rust/src/scoring/`, `rust/tests/scoring_behavior.rs` | Implemented (P1-05 profile-driven grades, score normalization, combos, milestones, lane stats) |
| Rust MIDI mapping engine | `rust/src/midi/`, `rust/tests/midi_mapping.rs` | Implemented (P1-06 raw MIDI NoteOn/CC to mapped hits, hi-hat CC4 articulation, calibration offset, dedupe, unmapped-note warnings) |
| Rust local profile storage | `rust/src/storage/profiles.rs`, `rust/tests/local_profiles.rs`, `rust/tests/settings_persistence.rs` | Implemented (P1-16 SQLite-backed player profiles, profile preferences, last-active profile state, cascade delete; P1-20 app/profile settings snapshot and update APIs) |
| Rust device profile storage | `rust/src/storage/device_profiles.rs`, `rust/tests/device_profile_persistence.rs`, `rust/tests/settings_persistence.rs` | Implemented (P1-08 per-player device profile CRUD, last-used reconnect matching, multiple profiles per device; P1-20 manual latency and velocity-curve settings helper) |
| Rust practice attempt storage | `rust/src/storage/practice_attempts.rs`, `rust/tests/practice_attempt_persistence.rs` | Implemented (P1-21 post-session attempt writes from `AttemptSummary + PracticeAttemptContext`, player-owned SQLite rows, history query filters) |
| Bundled standard drum layout | `assets/content/layouts/std-5pc-v1.json`, `rust/tests/bundled_layouts.rs` | Implemented (P1-19 default 5-piece drum layout with visual slots and MIDI hints) |
| Bundled starter lessons | `assets/content/lessons/starter/`, `assets/content/scoring/score-standard-v1.json`, `rust/tests/starter_lessons.rs` | Implemented (P1-18 13 starter lessons that load and compile against the standard layout/scoring profile) |
| Flutter↔Rust bridge | `rust/`, `lib/src/rust/`, `rust_builder/` | Implemented (Phase 0 `greet` bridge) |
| Windows MIDI adapter | `windows/runner/windows_midi_adapter.*`, `lib/platform/midi/windows_midi_adapter.dart`, `native/windows/` | Implemented (Phase 0 NoteOn capture and latency benchmark validated) |
| Windows latency harness | `lib/platform/latency/`, `rust/src/api/simple.rs`, `artifacts/phase-0/` | Implemented (P0-05 release measurement captured) |
| Android MIDI adapter | `android/app/src/main/kotlin/dev/taal/taal/MainActivity.kt`, `lib/platform/midi/android_midi_adapter.dart`, `native/android/` | Implemented (Phase 0 NoteOn capture and latency benchmark validated) |
| Android latency artifact export | `android/app/src/main/kotlin/dev/taal/taal/MainActivity.kt`, `lib/platform/latency/` | Implemented (writes Phase 0 CSV/report to Android Downloads via MediaStore) |
| CI pipeline | `.github/workflows/ci.yml` | Implemented (Rust + Flutter checks/builds, locally validated) |
| Metronome audio output | `lib/platform/audio/`, `windows/runner/windows_metronome_audio.*`, `android/app/src/main/kotlin/dev/taal/taal/MetronomeAudioController.kt`, `android/app/src/main/cpp/` | Implemented (P1-15 scheduled native click playback through WASAPI on Windows and AAudio on Android) |
| SQLite persistence | `rust/src/storage/` | Partial (P1-16 local profiles, P1-08 device profiles, P1-21 practice attempts, and P1-20 settings/preferences implemented) |
| Practice views | `lib/features/player/` | Partial (P1-09 note-highway, P1-10 notation, P1-11 visual drum kit, P1-12 Practice Mode screen, P1-14 review, and P1-13 Play Mode screen implemented; later player capabilities still planned) |
| Lesson Editor | `lib/features/studio/` | Planned (Phase 2) |
| Course Designer | `lib/features/studio/` | Planned (Phase 2) |
| Pack Builder | `lib/features/studio/` | Planned (Phase 2) |
| Analytics engine | `rust/src/analytics/` | Planned (Phase 3) |
| Backing track sync | `rust/` + native audio | Planned (Phase 3) |

**Status discipline:**
- **Implemented** — code exists and is passing tests
- **Partial** — code exists but is incomplete or behind feature flag
- **Planned** — referenced but not yet created

*Update this table after any task that creates, modifies, or removes a component, or shifts responsibility between layers.*

---

## System Layers

Taal has three layers with strict ownership boundaries.

```
┌──────────────────────────────────────┐
│           UI Layer (Flutter)          │
│                                      │
│  Screens, widgets, animations,       │
│  navigation, state management        │
│                                      │
│  Owns: all user-visible rendering    │
│  Does NOT own: timing, scoring,      │
│  content validation, persistence     │
└──────────────────▲───────────────────┘
                   │  flutter_rust_bridge (async FFI)
┌──────────────────┴───────────────────┐
│         Core Engine (Rust)            │
│                                      │
│  Content parsing, validation,        │
│  compilation. Session management,    │
│  hit grading, scoring, analytics.    │
│  SQLite persistence.                 │
│                                      │
│  Owns: all timing-critical logic,    │
│  all data models, all persistence    │
│  Does NOT own: rendering, MIDI I/O,  │
│  audio output                        │
└──────────────────▲───────────────────┘
                   │  Platform channels
┌──────────────────┴───────────────────┐
│      Native Platform Layer            │
│                                      │
│  MIDI device discovery/connection,   │
│  event capture with timestamps.      │
│  Low-latency audio output.           │
│                                      │
│  Owns: hardware I/O, OS-specific     │
│  APIs, monotonic timestamps          │
│  Does NOT own: mapping, scoring,     │
│  any business logic                  │
└──────────────────────────────────────┘
```

### Why This Split

- **Flutter** gives a single UI codebase for Windows, Android, iOS, macOS. Strong animation support for the note-highway and timing feedback.
- **Rust** ensures deterministic scoring with no GC pauses. The same compiled logic runs identically on every platform. All timing-sensitive decisions happen here.
- **Native layer** is intentionally thin: it captures MIDI events with the best available timestamp and passes audio scheduling commands to the OS audio API. No business logic.

**Key invariant:** Scoring correctness does not depend on UI frame rate. If Flutter drops to 30fps, visual feedback lags but grades are still computed correctly from native timestamps.

---

## App Shell and Navigation

The P1-22 app shell is now the `MaterialApp.home` entry point. It opens the Rust-backed local profile store, resolves the active player, and provides the top-level landing surface and navigation frame.

```
main.dart
       |
TaalAppShell
       |
LocalProfileStore -> Rust profile storage bridge -> SQLite
       |
Home, Practice, Library, Studio, Insights, Settings destinations
```

The shell adapts navigation by available width:

| Surface | Navigation |
|---------|------------|
| Narrow / mobile | Bottom `NavigationBar` |
| Wide / desktop | `NavigationRail` |

The home destination shows the active profile greeting, recommended next lesson, recent-practice placeholder, streak placeholder, and profile switcher. Practice, Library, Studio, Insights, and Settings are reachable from the home surface and the top-level navigation. Studio and Insights are intentionally safe placeholders until their later phase work lands. Settings now mounts the concrete P1-20 settings screen and uses the same active profile state as the shell.

Profile switching remains Rust-owned for persistence. Flutter requests `setActiveLocalProfile` through `LocalProfileStore`, updates the active profile state, and profile-specific home content changes immediately.

## Settings and Preferences

The P1-20 Settings screen is a Flutter renderer over Rust-owned settings persistence. It does not own persistence semantics and does not add settings fields beyond the CR-006 model.

```
TaalAppShell Settings destination
       |
TaalSettingsScreen
       |
RustSettingsStore -> flutter_rust_bridge
       |
LocalProfileStore / DeviceProfileStore -> SQLite
```

Settings are split by owner:

| Level | Rust storage owner | Flutter behavior |
|-------|--------------------|------------------|
| App-level | `app_settings` key/value rows | Audio output device ID is edited in Settings; last-active profile remains driven by profile switching. |
| Profile-level | `profile_preferences` plus `player_profiles.preferred_view/name` | Display, metronome, auto-pause defaults, Practice Mode attempt recording, active device profile, and profile name changes update through Rust and are reflected immediately in the Settings UI. |
| Device-profile-level | `device_profiles.profile_json` | Manual latency writes the existing `DeviceProfile.input_offset_ms`; velocity curve writes the existing `DeviceProfile.velocity_curve`. |

The Settings screen applies metronome volume/click-sound changes to the Flutter native-audio adapter after Rust returns the updated profile settings. Audio output device selection is persisted as `AppSettings.audio_output_device_id`; native output-device switching remains limited to what the current audio adapter exposes.

Auto-pause behavior is not implemented in P1-20. Settings only persists `auto_pause_enabled` and `auto_pause_timeout_ms` for the later P1-26 Practice Mode behavior.

---

## Data Flow: Hit → Feedback

This is the critical path — the one that must complete in < 20ms perceived.

```
1. Drummer hits pad
       ↓
2. E-kit sends MIDI NoteOn via USB
       ↓
3. Native adapter captures event
   - Attaches monotonic timestamp (QueryPerformanceCounter / System.nanoTime)
   - Sends RawMidiEvent to Dart via platform channel
       ↓
4. Dart forwards to Rust via flutter_rust_bridge
       ↓
5. Rust MidiMapper resolves note → lane_id using DeviceProfile
   - Applies hi-hat CC4 state for articulation
   - Applies calibration offset
   - Deduplicates if needed
       ↓
6. Rust Session grades hit against nearest expected event
   - Computes delta_ms
   - Assigns Grade (Perfect/Good/Early/Late/Miss)
   - Updates combo, score, lane stats
   - Emits HitGraded event to event buffer
       ↓
7. Flutter drains event buffer on next frame (~16ms at 60fps)
   - Triggers animation on note-highway / notation / drum kit widget
   - Updates combo counter, score display
       ↓
8. User sees and feels the feedback
```

**Latency budget:**

| Segment | Target |
|---------|--------|
| Pad → OS MIDI callback | ~1-3ms (hardware) |
| MIDI callback → Rust | < 1ms |
| Rust grading | < 1ms |
| Rust → Flutter event | < 2ms |
| Flutter next frame | < 8ms (at 120fps) |
| **Total perceived** | **< 20ms** |

See [ADR-001](docs/adr/001-platform-architecture.md) for the latency spike that validates this.

### Current Phase 0 Bridge Flow

The implemented bridge scaffold proves the Flutter-to-Rust call path before the MIDI spike:

```
Flutter test / app
       ↓
lib/src/rust/frb_generated.dart
       ↓
rust_builder Cargokit plugin
       ↓
rust/src/api/simple.rs::greet(name)
       ↓
Dart receives "Hello, {name}!"
```

Flutter tests load the Rust release library from `rust/target/release/`, so CI builds that library before running `flutter test`.

### Current Phase 0 Runtime Skeleton

The implemented Rust runtime skeleton lives in `rust/src/runtime/session.rs`. It is intentionally narrow:

| Function | Purpose |
|----------|---------|
| `start_session()` | Creates a session with one hardcoded expected `kick` event at 1s |
| `submit_hit(session, InputHit)` | Grades a pre-resolved lane hit and queues `EngineEvent::HitGraded` |
| `session_tick(session, now_ns)` | Emits `EngineEvent::Missed` after the miss window if no hit was graded |
| `drain_events(session, max)` | Drains queued engine events for the UI/bridge harness |

The Phase 0 `InputHit` path bypasses MIDI note mapping and uses a pre-resolved `lane_id`, matching the spike constraint. The Rust enum definitions follow the frozen `engine-api.md` Grade and EngineEvent shapes even though only `HitGraded`, `Missed`, and `Warning` are used by the skeleton.

### Current Phase 0 Latency Harness

The latency harness records the P0-05/P0-07 measurement path in release builds:

```
Native MIDI callback
       ↓  T0: platform monotonic timestamp
Dart EventChannel listener
       ↓
flutter_rust_bridge synchronous call
       ↓  T1: Rust platform monotonic timestamp
Phase 0 Rust runtime skeleton submit_hit + drain_events
       ↓  T2: Rust platform monotonic timestamp
Flutter callback resumes
       ↓  T3: Dart Stopwatch timestamp calibrated to platform monotonic clock
CSV + summary report written under artifacts/phase-0/
```

On Windows, T0/T1/T2 use `QueryPerformanceCounter`. On Android, T0 is `System.nanoTime()` and Rust T1/T2 use `clock_gettime(CLOCK_MONOTONIC)`, matching the Android monotonic clock domain. T3 is calibrated from Dart `Stopwatch` to the platform monotonic clock for both platforms.

The harness uses a pre-resolved `kick` lane for every hit. It measures bridge and engine-path latency only; full MIDI note-to-lane mapping remains owned by the Rust MIDI mapping engine planned for Phase 1. Android release builds export CSV and summary artifacts to `Downloads/Taal/phase-0` via MediaStore so ADB can retrieve the measured data.

---

## Native MIDI Adapters

### Windows

The Phase 0 Windows MIDI adapter uses WinMM in the Flutter Windows runner. It exposes:

| Channel | Direction | Purpose |
|---------|-----------|---------|
| `taal/windows_midi` | Dart method channel | `listDevices`, `openDevice`, `closeDevice` |
| `taal/windows_midi/events` | Native event channel | Streams structured `note_on` maps |

The native callback filters MIDI NoteOn messages (`0x90` with velocity > 0), captures a monotonic `QueryPerformanceCounter` timestamp converted to nanoseconds, and posts the event to the runner window so Dart receives events on the Flutter platform thread.

Current validation status: the adapter compiles in the Windows release build. Runtime NoteOn validation passed with a Roland TD-27 exposed by WinMM as input device `0`; the Flutter Windows app received NoteOn events with channel, note, velocity, and monotonic nanosecond timestamps. P0-05 release measurement with 100 measured hits reported total native-to-Flutter latency p50 0.154 ms, p95 1.006 ms, p99 2.064 ms.

### Android

The Phase 0 Android MIDI adapter uses `android.media.midi.MidiManager` in the Flutter Android host activity. It exposes:

| Channel | Direction | Purpose |
|---------|-----------|---------|
| `taal/android_midi` | Dart method channel | `listDevices`, `openDevice`, `closeDevice` |
| `taal/android_midi/events` | Native event channel | Streams structured `note_on` maps |

The adapter enumerates MIDI devices with readable output ports, opens output port 0, connects it to a `MidiReceiver`, filters MIDI NoteOn messages (`0x90` with velocity > 0), and timestamps events with `System.nanoTime()` inside the receiver before posting structured events to Dart.

Current validation status: the adapter compiles in the Android release APK. Runtime NoteOn validation passed on a Samsung Fold 4 (`SM-F936U1`, Android 16/API 36) with a Roland TD-27 connected through USB-C OTG; the Flutter Android app received NoteOn events with device id, channel, note, velocity, and `System.nanoTime()` nanosecond timestamps. P0-07 release measurement with 100 measured hits reported total native-to-Flutter latency p50 2.218 ms, p95 14.180 ms, p99 25.161 ms.

---

## Native Metronome Audio

Metronome timing remains engine-owned. `session_tick()` emits `EngineEvent::MetronomeClick { t_ms, accent }` for beats that enter `SessionOpts.lookahead_ms`; Flutter forwards those scheduled timeline clicks to native audio through `PlatformMetronomeAudioOutput`.

| Channel | Direction | Purpose |
|---------|-----------|---------|
| `taal/metronome_audio` | Dart method channel | `configure`, `scheduleClicks`, `stop` |

The Dart adapter serializes only audio settings and click schedules:

| Method | Payload |
|--------|---------|
| `configure` | `volume` from 0.0 to 1.0 plus `preset` (`classic`, `woodblock`, `hihat`) |
| `scheduleClicks` | `session_start_time_ns` plus a list of `{ t_ms, accent }` click entries |
| `stop` | Clears pending native clicks |

Native output owns rendering, not timing policy. Both platforms pre-render click samples when configured and mix those samples into low-latency output callbacks by sample frame:

| Platform | Implementation | Audio API |
|----------|----------------|-----------|
| Windows | `WindowsMetronomeAudio` in the Flutter Windows runner | WASAPI exclusive event-driven render stream |
| Android | `MetronomeAudioController` Kotlin channel + `taal_metronome` JNI library | AAudio low-latency output stream |

Android metronome audio sets the app minimum SDK to 26 because AAudio is the Phase 1 audio output requirement. Current validation status: focused Rust scheduling tests pass, Dart channel serialization tests pass, `flutter analyze` passes, Windows debug build compiles with WASAPI, and Android debug APK builds with the AAudio JNI library. Hardware audible sync and latency measurement still need to be checked on target Windows/Android devices when the calibration and practice UI invoke this path.

---

## Calibration Flow

The P1-07 calibration wizard is a Flutter feature component that coordinates existing engine/native boundaries without redefining scoring. It uses the persisted `DeviceProfile.note_map` only to identify snare MIDI notes for the calibration prompt, then writes the measured `input_offset_ms` back to the same profile. The Rust `MidiMapper` remains the place where the stored offset is applied to subsequent hits.

```
User selects kit profile + MIDI input
       ↓
Flutter reads snare note(s) from DeviceProfile.note_map
       ↓
Flutter schedules 8 native metronome clicks at 100 BPM
       - session_start_time_ns is taken from the platform monotonic Rust clock
       - clicks are rendered by the P1-15 native audio path
       ↓
Native MIDI adapter streams NoteOn timestamps in the same monotonic clock domain
       ↓
Flutter records snare hits near each expected click
       ↓
CalibrationSession computes median offset and jitter
       ↓
DeviceProfileCalibrationStore updates input_offset_ms through the Rust SQLite bridge
```

The wizard can also skip calibration, which stores `input_offset_ms = 0` on the selected profile. Recalibration overwrites the previous offset because the persisted `DeviceProfile` is replaced via the existing P1-08 update operation.

---

## Practice View Components

The P1-09 note-highway widget is a reusable Flutter `CustomPainter` surface. It does not own runtime state or scoring; it renders a provided lane list, expected note timeline, current lesson time, and hit feedback markers.

```
Compiled/runtime timeline adapter (P1-12)
       ↓
NoteHighwayWidget
       - lane IDs + labels + lane colors
       - expected notes with absolute t_ms
       - currentTimeMs from Practice Mode transport
       - HitGraded/Missed feedback mapped to NoteHighwayGrade
       ↓
CustomPainter geometry
       - notes move top-to-bottom toward fixed hit line
       - early markers sit left of lane center
       - late markers sit right of lane center
       - grade colors follow visual-language timing semantics
```

Frame-rate validation on target hardware remains deferred to the first integrated animated Practice Mode path because P1-09 only provides the reusable painter and deterministic geometry tests.

The P1-10 notation view widget is also a reusable Flutter `CustomPainter` surface. It renders expected timeline events onto a drum staff using the standard 5-piece layout lane IDs (`kick`, `snare`, `hihat`, `ride`, `crash`, `tom_high`, `tom_low`, `tom_floor`) and preserves scoring ownership in Rust by accepting already-produced feedback markers.

```
Compiled/runtime timeline adapter (P1-12)
       ↓
NotationViewWidget
       - expected notes with lane IDs, articulation, and absolute t_ms
       - currentTimeMs from Practice Mode transport
       - display mode: scrolling or page
       - HitGraded/Missed feedback mapped to NoteHighwayGrade-compatible colors
       ↓
CustomPainter geometry
       - snare on the third staff line, kick on the space below the staff
       - current playback position highlighted as the playhead
       - early markers sit left of the notation beat position
       - late markers sit right of the notation beat position
       - page-mode geometry remaps time across a fixed staff window without owning session state
```

Frame-rate validation on target hardware remains deferred to the first integrated animated Practice Mode path because P1-10 only provides the reusable painter and deterministic geometry tests.

The P1-11 visual drum kit widget is a reusable Flutter `CustomPainter` surface for mapping, calibration, settings, and optional practice feedback. It renders an overhead standard 5-piece kit by default and can be supplied a custom pad list derived from an active layout's `visual.lane_slots`, so extended layouts can add pads without changing the painter contract.

```
Active instrument layout / runtime feedback adapter
       ↓
VisualDrumKitWidget
       - pads with lane_id, slot_id, label, normalized position, and pad kind
       - active hits with lane_id, grade, and flash progress
       ↓
CustomPainter geometry
       - standard 5-piece slots map to visible kit pads
       - mapped hits light the matching pad with grade color
       - unmapped lane IDs are ignored by the active-hit lookup
       - custom pad lists allow extended layouts to render additional pads
```

The widget does not read MIDI directly and does not compute grade state. Parent screens feed mapped lane IDs and engine-produced grades, preserving the native/Rust/Flutter ownership split.

The P1-12 Practice Mode screen is the first integrated player surface. It owns only UI transport state, view selection, tempo control state, metronome/loop toggles, A-B loop ranges, and display of combo/encouragement values. It does not compile lessons, map MIDI, grade hits, or compute scores.

```
Runtime/content adapter (P1-23 for scored Practice Mode input)
       ↓
PracticeModeController
       - play/pause/resume transport state
       - tempo BPM and next-beat effective timestamp
       - metronome toggle and loop toggle
       - selected section or manual A-B range
       - selected view: note-highway, notation, or drum kit
       ↓
PracticeModeScreen
       - compact transport bar
       - active practice view renderer
       - section selector and manual loop range slider
       - combo and encouragement display fed by runtime events
```

Practice Mode consumes prepared timeline notes and engine feedback markers as inputs. CR-007 assigns the minimum scored Practice Mode runtime adapter to P1-23, so the tap-pad task wires the existing Rust session and MIDI mapper into this screen without changing the practice-view widgets. This keeps Rust authoritative for scoring and timing semantics while Flutter owns rendering, touch interaction, and bridge calls.

P1-23's runtime input adapter has two input paths that converge before scoring:

```
Native MIDI adapter -> RawMidiEvent -> Rust MidiMapper -> MappedHit
       |                                            |
       v                                            v
       Flutter bridge/orchestration                 InputHit { lane_id, velocity, timestamp_ns, midi_note: Some(raw_note) }

Touch tap pad -> selected lane_id + touch timestamp/velocity
       |
       v
       InputHit { lane_id, velocity, timestamp_ns, midi_note: None }

InputHit -> Rust Session::on_hit -> EngineEvent stream -> Practice Mode feedback renderers
```

The adapter may own session handles, ticking/draining cadence, and conversion between bridge DTOs and the existing Rust contracts. It must not compute grades, score, combo, misses, or attempt summaries in Flutter.

The P1-13 Play Mode screen reuses the same practice-view renderers for scored assessment runs. It removes Practice Mode's operator controls that would change assessment conditions: no pause/resume, no tempo slider, no metronome toggle, and no A-B loop controls.

```
Lesson/runtime adapter
       ↓
PlayModeController
       - lesson default BPM only
       - count-in state
       - full-run progress until lesson end
       - selected view: note-highway, notation, or drum kit
       ↓
PlayModeScreen
       - locked-tempo assessment controls
       - active player view renderer
       - completion handoff to post-lesson review
       ↓
Post-run persistence
       - caller supplies AttemptSummary JSON + PracticeAttemptContext JSON
       - Rust practice-attempt bridge records history through P1-21 storage
```

Play Mode still does not grade hits or compute scores in Flutter. A runtime adapter is responsible for stopping the Rust session, converting the returned `AttemptSummary` into the review model, and passing the same summary/context pair to the Rust practice-attempt storage API after the run.

The P1-14 post-lesson review screen is a Flutter summary renderer for completed attempts. It consumes an AttemptSummary-shaped Dart model and does not recompute score, accuracy, or lane metrics.

```
Rust session_stop() / attempt summary adapter
       ↓
PostLessonReviewScreen
       - score, accuracy, hit rate, max streak, BPM
       - timing distribution: early, perfect, late, miss
       - timing bias and spread from summary fields
       - per-lane hit rate and mean timing
       ↓
Review presentation
       - best stat appears before suggestions
       - 1-2 deterministic prompts derived from summary values
       - Retry, Next Lesson, and Back to Library action callbacks
```

The screen's suggestion helper ranks existing summary values for user-facing copy only. It does not change scoring semantics or write analytics data.

The P1-21 attempt persistence path now stores the same Rust-produced summary after a successful stop:

```
Rust session_stop() -> AttemptSummary
       +
Caller PracticeAttemptContext
       ↓
Rust PracticeAttemptStore
       - generates attempt id
       - copies summary metrics and context snapshots
       - writes player-owned SQLite row
       - serves player, lesson, date-range, and course filters
```

This preserves `session_stop()` as a summary-only lifecycle operation. SQLite I/O stays outside the timing-sensitive session path.

---

## Content Model

All content (lessons, courses, packs) is defined by typed Rust structs and serialized as JSON.

### Key Entities

| Entity | What It Is | Defined In |
|--------|-----------|------------|
| Lesson | Timeline of expected musical events + metadata | [content-schemas.md](docs/specs/content-schemas.md) |
| Course | Ordered sequence of lessons with progression gates | [content-schemas.md](docs/specs/content-schemas.md) |
| Pack | Distribution bundle (.taalpack ZIP) | [content-schemas.md](docs/specs/content-schemas.md) |
| Instrument Layout | Lane definitions + visual mapping + MIDI hints | [content-schemas.md](docs/specs/content-schemas.md) |
| Scoring Profile | Timing windows, grade weights, combo rules | [content-schemas.md](docs/specs/content-schemas.md) |
| Device Profile | MIDI note→lane mapping, calibration, velocity curve | [midi-mapping.md](docs/specs/midi-mapping.md) |

The implemented Rust content module currently loads and validates `Lesson`, `InstrumentLayout`, and `ScoringProfile` JSON. It materializes the documented Lesson defaults for `assets`, `references`, and `optional_lanes`, and validates the P1-01-owned schema invariants.

The bundled P1-19 standard drum layout lives at `assets/content/layouts/std-5pc-v1.json`. It defines the default kit lanes, visual drum-kit slots, hi-hat articulations, and common MIDI note/CC hints.

The bundled P1-18 starter content lives under `assets/content/lessons/starter/` with the shared scoring profile at `assets/content/scoring/score-standard-v1.json`. The current starter set contains 13 lessons: 5 beginner, 5 intermediate, and 3 variety lessons. Focused tests load every lesson and compile each one against the standard layout and scoring profile.

The implemented Rust MIDI mapping module defines the Phase 1 `DeviceProfile`, `RawMidiEvent`, `MappedHit`, and `MappingResult` contracts in code. `MidiMapper` consumes raw native MIDI events, applies channel filtering, note-to-lane mapping, hi-hat `hihat_model.source_cc` state, calibration offset, and duplicate NoteOn suppression before producing mapped hit or warning results. Generic `cc_map` remains unsupported per CR-004 and is rejected during Phase 1 profile loading.

### Content Representations

Content exists in three forms:

| Form | Context | Validation | Events Sorted? |
|------|---------|-----------|----------------|
| **Authoring** | Studio workspace | Lenient (drafts OK) | No |
| **Compiled** | Player runtime | Strict (all resolved) | Yes (by ms) |
| **Exported** | .taalpack file | Strict (schema-compliant) | Yes (by position) |

The `compile_lesson()` function transforms authoring → compiled form. This is a one-way, deterministic transformation.

The implemented Rust compile module resolves a validated lesson against an instrument layout and scoring profile, builds a `TimingIndex`, converts every expected event and section boundary into absolute milliseconds, sorts events by `t_ms`, rejects duplicate compiled lane/time pairs, and returns the immutable `CompiledLesson` runtime representation consumed by sessions.

### Time Model

- **Canonical:** Musical time — `{ bar, beat, tick }` with 480 ticks per beat
- **Derived:** Absolute milliseconds, computed from tempo map at load time
- **Authoring** uses musical time (intuitive for editing)
- **Playback** uses compiled ms times (required for scoring)

The implemented Rust time module reuses the content schema's `MusicalPos`, `TimeSignature`, and `TempoEntry` structs. It provides tick-based musical-position arithmetic and a `TimingIndex` that converts musical positions to floating-point milliseconds and converts milliseconds back to the nearest tick-aligned musical position. The index supports constant-tempo maps and multiple tempo entries; later lesson compilation will use it to produce runtime `t_ms` values.

---

## Engine API

The Rust engine exposes a minimal, well-defined API surface. See [engine-api.md](docs/specs/engine-api.md) for the full contract.

### Session Lifecycle

```
Ready → Running → Paused → Running → Stopped
              ↘              ↗
               → Stopped (also valid from Running)
```

### Key Functions

```
compile_lesson(lesson, layout, scoring) → CompiledLesson
session_start(compiled, opts) → Session
session_on_hit(session, hit) → Result // Submit a MIDI hit while Running
session_tick(session, now_ns) → Result // Advance time and detect misses while Running
drain_events(session, max) → Vec<EngineEvent>  // Pull events for UI
session_stop(session) → Result<AttemptSummary> // End session, get results
```

The implemented runtime session owns a cloned immutable `CompiledLesson` for the attempt. `SessionOpts.start_time_ns` anchors native monotonic hit timestamps to the compiled millisecond timeline. `tick` emits expected pulses for events entering the configured look-ahead window and misses after the outer window expires. Hits are matched to the nearest pending expected event in the same lane within the scoring profile's outer window. Stop is idempotent once the session reaches `Stopped`.

The implemented scoring module owns grade-window evaluation, score normalization to 0-100, combo and encouragement-tier tracking, combo milestone messages, aggregate timing statistics, and per-lane summary metrics. Runtime sessions call this module after every hit or miss and translate milestone updates into `ComboMilestone` and `Encouragement` engine events.

### Canonical Grade Model

```rust
pub enum Grade {
    Perfect = 0,  // Within tight window
    Good    = 1,  // Within medium window
    Early   = 2,  // Before window
    Late    = 3,  // After window
    Miss    = 4,  // No hit registered
}
```

This enum is the same everywhere: engine, UI, analytics, visual language.

---

## Storage

All data is stored locally in SQLite, managed by the Rust engine. No cloud infrastructure.

| Data | Owner | Lifetime |
|------|-------|----------|
| Lessons, courses, layouts | Content system | Until user deletes |
| Device profiles | Per player profile | Until profile deleted |
| Practice attempts | Per player profile | Until user deletes |
| Performance themes | Derived from attempts | Recomputed periodically |
| Player profiles | Local | Until user deletes |

The implemented P1-16 storage path opens a local SQLite database from Flutter's application-support directory and passes the database path into Rust through flutter_rust_bridge. Rust owns the schema and all writes. The current schema contains:

| Table | Purpose |
|-------|---------|
| `player_profiles` | Local `PlayerProfile` records with name, optional avatar, experience level, preferred view, and metadata timestamps |
| `profile_preferences` | Profile-owned settings row with display, metronome, auto-pause, Practice Mode history, active-device-profile, timestamps, and foreign-key cascade on profile deletion |
| `app_settings` | App-level key/value settings, currently `last_active_profile_id` and `audio_output_device_id` |

The implemented P1-08 device-profile storage adds:

| Table | Purpose |
|-------|---------|
| `device_profiles` | Per-player persisted `DeviceProfile` records. The validated profile JSON is stored as the source payload, with indexed reconnect metadata copied into columns. |
| `last_used_device_profiles` | Per-player last-used mapping from a device fingerprint key to the chosen profile ID. Exact `(vendor_name, model_name, platform_id)` lookup is attempted before vendor/model fallback. |

P1-20 adds settings-specific updates over the existing profile/device-profile tables. `LocalProfileStore::load_settings_snapshot()` returns the app/profile settings snapshot for a player, and `update_profile_settings()` validates and persists profile-owned settings without entering the timing-sensitive session path. `DeviceProfileStore::update_device_profile_settings()` updates only the existing `input_offset_ms` and `velocity_curve` fields inside the stored `DeviceProfile` JSON and preserves all mapping/calibration contract fields.

The implemented P1-21 practice-attempt storage adds:

| Table | Purpose |
|-------|---------|
| `practice_attempts` | Per-player scored-attempt records built after `session_stop()` from `AttemptSummary + PracticeAttemptContext`. Outcome metrics are stored in queryable columns, while `lane_stats`, `lesson_tags`, and `lesson_skills` are stored as JSON columns. |

Practice-attempt persistence is post-session storage, not part of the session lifecycle hot path. Flutter or a later runtime adapter calls the Rust bridge after a successful `session_stop()`, passing the returned `AttemptSummary` and caller-owned context for player, lesson snapshot, device profile, course/section, and wall-clock fields. Rust writes and queries the SQLite rows through `PracticeAttemptStore`.

Practice-attempt indexes support `(player_id, started_at_utc)`, `(player_id, lesson_id)`, `(player_id, local_hour)`, and `(player_id, course_id)` lookups. Deleting a player profile deletes its owned preference, device-profile, and practice-attempt rows through SQLite foreign-key cascade. Deleting a device profile removes last-used reconnect pointers and sets existing attempt `device_profile_id` references to null.

---

## Repository Structure

```
taal/
├── lib/                    # Flutter UI (Dart)
│   ├── features/           # App shell, Profiles, Player, Studio, Library, Insights, Settings, Onboarding
│   ├── widgets/            # Shared: timeline, drum kit, transport, note highway
│   └── design/             # Design system tokens
├── android/                # Flutter Android host app
├── windows/                # Flutter Windows host app
├── rust/                   # Rust core engine crate
│   ├── Cargo.toml
│   └── src/
│       ├── api/            # Phase 0 bridge API surface
│       ├── content/        # P1-01 content schemas/validation + P1-03 lesson compilation
│       ├── midi/           # P1-06 MIDI note/CC mapping to semantic hits
│       ├── runtime/        # P1-04 compiled-lesson session lifecycle
│       ├── scoring/        # P1-05 grade, score, combo, and summary metrics
│       ├── storage/        # P1-16/P1-08/P1-21/P1-20 SQLite persistence
│       ├── time/           # P1-02 musical time arithmetic and TimingIndex
│       ├── frb_generated.rs
│       └── lib.rs
├── rust_builder/           # Cargokit Flutter plugin glue for Rust builds
├── native/                 # Platform-specific MIDI/audio
│   ├── android/
│   ├── windows/
│   └── ios/                # Future
├── docs/                   # Documentation
│   ├── prd.md              # Product requirements
│   ├── architecture.md     # This document
│   ├── adr/                # Architecture decisions
│   ├── specs/              # Technical specifications
│   └── coding-model.md     # Agent execution model
├── plans/                  # Phase execution plans
├── assets/                 # Bundled content + sounds
│   └── content/
│       ├── layouts/        # P1-19 standard drum layout
│       ├── lessons/        # P1-18 starter lessons
│       └── scoring/        # P1-18 standard scoring profile
├── STATUS.md               # Project state
├── CHANGELOG.md            # Change log
└── README.md               # Public-facing description
```

---

## Key Design Decisions

All major decisions are documented as ADRs in [docs/adr/](docs/adr/).

| Decision | Choice | ADR |
|----------|--------|-----|
| Platform architecture | Flutter + Rust (accepted with conditional caveat) | [001](docs/adr/001-platform-architecture.md) |
| Time representation | Musical time canonical, ms derived | 002 (planned) |
| Content format | Proprietary JSON, MusicXML for import/export | 003 (planned) |
| Storage | Local-first SQLite | 004 (planned) |
| Marketplace fields | Optional in schema, no system in v1 | 005 (planned) |

---

## Development Workflow

See [coding-model.md](docs/coding-model.md) for task templates, contract rules, and execution discipline.

**Key rules:**
- Task IDs are identifiers, not execution order. Respect the dependency graph.
- If you change a contract surface (engine API, schema, device profile), update the relevant spec in the same changeset.
- Frozen interfaces in STATUS.md cannot be changed without an explicit Change Request.
- Rust structs are canonical. JSON examples in docs are illustrative.

---

## Platform-Specific Notes

### Windows
- MIDI: WinRT MIDI API (or WinMM fallback)
- Audio: WASAPI exclusive mode for low-latency metronome
- Distribution: `.exe` installer via Inno Setup

### Android
- MIDI: `android.media.midi.MidiManager` (USB host mode)
- Audio: AAudio low-latency output
- App minimum SDK: 26 for Phase 1 AAudio output
- Distribution: Play Store AAB + sideload APK
- USB permission prompt required on first device connection
- Highest latency risk platform — validated by Phase 0 spike

### macOS / iOS (Future)
- MIDI: CoreMIDI
- Audio: CoreAudio
- Expected to have the best latency characteristics
