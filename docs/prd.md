# Taal (താള്‍)

## Product Requirements, Reference Architecture, and Build Plan

**Version:** 1.9
**Date:** April 15, 2026
**Author:** Rejo Z. Mathew
**Status:** Pre-implementation

---

## Document Revision History

| Version | Date       | Changes |
|---------|------------|---------|
| 1.0     | 2026-04-08 | Initial comprehensive PRD: vision, architecture, product scope, phased delivery |
| 1.1     | 2026-04-09 | Editorial pass: added NFR section, explicit MVP boundary, tightened backing track scope, architecture conditionality, softened competitive claims, moved agentic coding model out of PRD, added spec placeholders |
| 1.2     | 2026-04-09 | Contract hardening pass: fixed numbering bugs, removed external project references, added canonical ownership table, contract-touch and frozen-interface rules, elaborated Phase 3 tasks, added platform latency risk table, distribution/packaging section, backing track behavioral rules, builds in v1 scope, cross-document grade model consistency |
| 1.3     | 2026-04-09 | Dependency audit: fixed all task dependency gaps across Phases 1-3, clarified MVP vs v1.0 release boundary, hardened midi-mapping.md and analytics-model.md to contract-level specs, resolved combo behavior TBD, added Phase 0 spike simplification note |
| 1.4     | 2026-04-10 | Final contract cleanup: fixed remaining dependency gaps (P1-12, P3-09), reconciled all spec status lines, synced coding-model.md with contract rules, added PracticeMode/CompiledLesson/PlayerProfile definitions to engine-api.md, fixed TimingWindows.ok mismatch, aligned AttemptSummary optionality, clarified MetronomeClick semantics, added course model explicit lock, added backing-track import rule, added help/tooltips/about section (4.2.6 + P2-16), added README.md and architecture.md, task ordering clarification |
| 1.5     | 2026-04-15 | Competitive feature pass + final dependency fixes |
| 1.5     | 2026-04-15 | Competitive feature pass: added on-screen tap pads, listen-first mode, speed training, auto-pause, practice streaks/daily goals, latency fine-tuning slider. Added P1-22 app shell, P2-17 course runtime, P2-18 speed training. Fixed P1-21 dep. Aligned platform roadmap. Clarified velocity scoring. |
| 1.6     | 2026-04-15 | Task ownership cleanup: P1-25 listen-first, P1-26 auto-pause, latency slider in P1-20, dep fixes |
| 1.7     | 2026-04-15 | Final dependency pass: fixed P1-25/P1-26/P1-17 deps, added P3-23 relink flow, added P1-27 layout compatibility check, added extra pad documentation, corrected custom layout claims. |
| 1.8     | 2026-04-15 | Layout compatibility refined: required vs optional lanes model |
| 1.9     | 2026-04-15 | Sequencing fix: moved Course Gate compatibility from P1-27 to P2-17, added P1-13/P1-14 deps to P1-27, added partial-compatibility non-qualifying rule, added P1-27 dep to P2-17. Bootstrap: created AGENTS.md, CLAUDE.md, README_BOOTSTRAP.md, repo structure for initial commit.: replaced coverage_pct model with required vs optional lanes (creator-intentional). Added optional_lanes to Lesson struct. Course Gate blocks on missing required lanes. Play Mode marks partial compatibility. Updated P1-27, P2-07, content-schemas.md. |

---

## 1. Executive Summary

Taal (താള്‍, Malayalam for "rhythm / beat") is a free, open-source instrument tutoring platform. It combines a Creator Studio for authoring lessons and courses with a Practice Player for real-time MIDI-connected performance feedback. The platform is instrument-agnostic by design — drums are the first instrument, with keyboard and others planned — and includes a crowdsourced marketplace where creators share lessons, courses, and practice packs.

### Core Value Proposition

**Every serious drum practice app charges $15–30/month.** Melodics, Drumeo, Beatlii, Drumistic — all subscription-based. For a beginner who just bought a $300 e-kit, adding $180–360/year in software subscriptions is a real barrier.

Taal is free. The lesson library is crowdsourced. Creators — teachers, experienced drummers, enthusiasts — build and share lessons. Learners practice with real-time MIDI feedback, accuracy scoring, and progression tracking. An optional AI coaching layer analyzes practice patterns and suggests personalized practice plans.

**What you get:**

- **Practice Player:** Connect your e-kit via USB MIDI. Follow lessons with a note-highway or notation view. Get immediate visual feedback on every hit — perfect, early, late, miss. Track your accuracy, timing bias, and progress over time.
- **Creator Studio:** Design lessons on a multi-lane timeline. Set tempo, sections, practice rules. Stitch lessons into guided courses with progression gates. Export as shareable packs.
- **Marketplace (future):** Browse community-created lessons and courses. Download free packs. Creators can share content tied to their own backing tracks or reference songs (user-provided audio, legally safe).
- **AI Coach (future):** After enough practice sessions, an AI analyzes your timing patterns, identifies weaknesses, and generates a personalized practice plan from available lessons.

### Key Architectural Decisions

*Target architecture — finalized after Phase 0 latency spike. See ADR-001.*

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI framework | Flutter (pending ADR-001 spike) | Single codebase: Windows, Android, iOS, macOS. Strong animation. Tablet-friendly. |
| Core engine | Rust | Deterministic timing/scoring. No GC jitter. Cross-platform compilation. |
| Bridge | flutter_rust_bridge | Mature FFI bridge. Async support. Proven in production apps. |
| Data format | Proprietary JSON (instrument-agnostic) | MusicXML for import/export only. Proprietary format carries tutoring metadata. |
| Time model | Musical time canonical, ms derived | Grid-based authoring. Playback compiles to absolute timestamps. |
| Storage | SQLite (local-first) | Zero-config. Offline. Per-device. No server infrastructure. |
| MIDI transport | USB first, BLE best-effort | USB is reliable and low-latency. BLE adds jitter. |
| Sync | File-based export/import | No cloud accounts required. Privacy-preserving. |
| Auth | Local profiles | "Who's playing?" — no login, no server, no identity infrastructure. |

### Primary Goal

Build a genuinely useful, free drum practice application that competes on openness and community content rather than subscription revenue.

### Secondary Goal

Prove that a crowdsourced, free-to-use model can produce a richer learning ecosystem than subscription-gated content libraries.

---

## 2. Product Vision and User Experience

### 2.1 The Problem

A drummer buys an electronic kit for $300–800. They want structured practice with feedback. Their options:

1. **Melodics** ($15–30/month): Gamified, note-highway style. Good UX. But: no custom phrases, no traditional notation, subscription-only, latency issues reported, covers instead of real songs, no dynamics/velocity scoring.
2. **Drumeo** ($20/month): Video lessons from pro drummers. No real-time MIDI feedback. No interactive scoring.
3. **Beatlii** ($15/month): Note-highway + notation toggle. Newer, smaller library.
4. **Drumistic** (subscription): Limited features.
5. **YouTube + metronome**: Free, but no feedback, no structure, no progress tracking.

The pattern: good interactive practice costs $180–360/year. Free options have no feedback loop. There is no free, full-featured, MIDI-connected drum practice app.

### 2.2 The Solution

Taal fills the gap between expensive subscription apps and structureless free practice. It provides:

- **Real-time MIDI feedback** with timing accuracy scoring (what Melodics does well)
- **Both note-highway AND notation views** (a frequently requested feature in competitor reviews)
- **Custom phrase entry** (consistently cited as a top missing feature across competitors)
- **Velocity/dynamics data capture** (velocity is recorded per hit and displayed; full dynamics scoring is planned post-v1)
- **Creator tools** so anyone can make and share lessons (what makes the library grow without subscription revenue)
- **AI-assisted practice planning** (what no competitor does yet)
- **Free.** No subscription. No paywall. No limited daily practice time.

### 2.3 The Core Practice Loop (Flagship Experience)

This is the primary product experience — the habit loop that must feel excellent.

```
SETUP (one-time):
  1. Install Taal on Windows PC or Android tablet
  2. Connect e-kit via USB MIDI cable
  3. Taal detects the kit: "Roland TD-17 detected"
  4. Quick calibration: "Hit each pad when you hear the click" (30 seconds)
  5. Choose profile: "I'm a beginner" / "I play regularly" / "I'm a teacher"
  6. ✅ Ready

DAILY PRACTICE (the habit loop):
  1. Open Taal → "Welcome back, Rejo. Ready to practice?"
  2. See: recommended next lesson (based on progress + AI suggestion)
     OR browse lesson library / continue current course
  3. Tap "Start" → count-in: 1... 2... 3... 4...
  4. Notes scroll toward the hit line (note-highway view)
     OR notes appear on a staff (notation view — toggle anytime)
  5. Play along:
     → Perfect hit: green flash, pad glows
     → Early hit: blue flash, note marker shifts left
     → Late hit: amber flash, note marker shifts right
     → Miss: dim fade on expected note
  6. Combo counter builds: 8... 12... 16 → "Locked in" 🔥
  7. Section ends → mini-summary:
     "92% accuracy. Snare timing: slightly late (+14ms average).
      Try the A-B loop on bars 5-8."
  8. After full lesson → detailed review:
     - Score: 88/100
     - Timing histogram (early/late distribution)
     - Lane breakdown (kick: great, snare: needs work)
     - "Practice recommendation: Backbeat Timing Drill"
  9. Progress saved locally. Course gate: "Score 85+ to unlock next lesson ✅"
```

**This practice loop IS the product.** Everything else — Studio, marketplace, analytics — exists to feed content into this loop and extract learning insights from it.

### 2.4 First-Run Experience

The first 2 minutes determine whether a user stays or leaves.

```
INSTALL:
  Windows: Download .exe from taal.app → install → launch
  Android: Install from Play Store → launch

FIRST LAUNCH:
  Screen 1: "Welcome to Taal"
    Clean, dark UI. Animated drum kit illustration.
    "Free drum practice with real-time feedback."
    [Get Started]

  Screen 2: "Who's playing?"
    Create a local profile (name + optional avatar)
    [+ Add another player later]

  Screen 3: "What's your experience?"
    [I'm just starting] → Beginner path
    [I play regularly]  → Intermediate path
    [I teach drums]     → Creator path
    (Affects default content, UI complexity, initial recommendations)

  Screen 4: "Connect your kit"
    Visual: stylized drum kit with USB cable illustration
    Auto-detect: "🎵 Roland TD-17 detected on USB"
    OR: "No MIDI device found. [Connect via USB] [Skip for now]"
    Skipping enters demo mode with on-screen tap pads

  Screen 5: "Quick calibration" (if MIDI connected)
    Metronome plays clicks at 100 BPM
    "Hit the snare in time with each click"
    8 clicks → system measures offset
    "Calibration complete! Your offset: 12ms (excellent)"
    [Recalibrate] [Continue]

  Screen 6: "Let's play!"
    Loads a simple 4-bar rock beat (pre-installed starter lesson)
    Immediate practice with full feedback
    No menus, no settings, no configuration

POST FIRST LESSON:
  "Nice work! Score: 75. That's a great start."
  [Try again] [Next lesson] [Explore library]
```

**Critical UX rule:** A new user must be playing drums with feedback within 90 seconds of first launch (assuming MIDI is connected). Every screen between install and first note is a dropout risk.

### 2.5 Target Users and Personas

**Persona 1: Beginner Learner (primary)**
- Just bought their first e-kit
- Wants guided lessons with clear feedback
- Doesn't read drum notation (prefers note-highway)
- Motivated by progress tracking and encouragement
- Price-sensitive (already spent on the kit)

*Taal for them:* Free practice with structured beginner courses, note-highway view, encouraging feedback, progression gates that prevent overwhelm.

**Persona 2: Practicing Drummer (secondary)**
- Intermediate player, 1-5 years experience
- Wants to improve timing precision and speed
- May read notation; wants both views
- Wants custom phrase practice (specific fills, rudiments)
- Wants detailed analytics on timing bias

*Taal for them:* Accuracy-focused practice, A-B section looping, notation view, detailed timing analytics, custom lesson creation in Studio.

**Persona 3: Drum Teacher / Creator (tertiary)**
- Creates content for students
- Wants to build structured courses
- May want to share via marketplace
- Needs efficient authoring tools

*Taal for them:* Creator Studio with lesson editor, course builder, pack export. Later: marketplace publishing.

### 2.6 Competitive Landscape

| Feature | Melodics | Drumeo | Beatlii | Taal |
|---------|----------|--------|---------|------|
| Price | $15-30/mo | $20/mo | $15/mo | **Free** |
| Real-time MIDI feedback | ✅ | ❌ | ✅ | ✅ |
| Note-highway view | ✅ | ❌ | ✅ | ✅ |
| Traditional notation | ❌ | ❌ | ✅ | ✅ |
| Custom phrase entry | ❌ | ❌ | ❌ | **✅** |
| Velocity/dynamics scoring | Limited | ❌ | ❌ | **Captured (scoring planned)** |
| Lesson creation tools | ❌ | ❌ | ❌ | **✅** |
| Community content | ❌ | ❌ | ❌ | **✅ (marketplace)** |
| AI practice planning | ❌ | ❌ | ❌ | **✅ (planned)** |
| Multi-instrument | Keys, pads | Drums only | Drums only | **Drums first, then keys** |
| Offline capable | ✅ | Partial | ✅ | ✅ |
| Acoustic kit support | ✅ (mic) | N/A | ❌ | ❌ (MIDI only v1) |

**Taal's positioning hypothesis:** A free, open, community-driven practice platform can compete with subscription products by offering creation tools and crowd-sourced content. The bet is that openness (custom content, community marketplace) compensates for a smaller initial library compared to funded competitors.

### 2.7 Non-Goals (v1)

Taal v1 is explicitly NOT:

- **An acoustic drum teaching app.** v1 requires an electronic kit with MIDI output. Microphone-based detection (like Melodics' acoustic mode) is a future possibility.
- **A DAW or recording tool.** Taal is for practice and learning, not music production.
- **A video lesson platform.** Taal is interactive MIDI practice, not passive video watching.
- **A social network.** The marketplace is for content distribution, not social features.
- **A music streaming service.** Backing tracks are user-provided. Taal does not distribute copyrighted music.
- **A real-time online multiplayer app.** Practice is local. No latency-sensitive networking.

---

## 3. Architecture Overview

### 3.1 Three-Layer Architecture

```
┌──────────────────────────────────────┐
│           UI Layer (Flutter)          │
│                                      │
│  Creator Studio    Practice Player   │
│  Lesson Editor     Note Highway      │
│  Course Designer   Notation View     │
│  Pack Builder      Visual Drum Kit   │
│  Library Browser   Scoring Overlay   │
│  Insights          Settings          │
│                                      │
│  Shared: Design system, navigation,  │
│  transport controls, animation engine │
└──────────────────▲───────────────────┘
                   │  flutter_rust_bridge
                   │  (async, typed)
┌──────────────────┴───────────────────┐
│         Core Engine (Rust)            │
│                                      │
│  Content: parse, validate, compile   │
│  Runtime: session, grading, scoring  │
│  Analytics: aggregation, themes      │
│  Storage: SQLite, profiles, history  │
│  Time: musical ↔ ms conversion      │
│                                      │
│  Deterministic. No GC. Testable.     │
└──────────────────▲───────────────────┘
                   │  Platform channels
                   │  (thin, per-platform)
┌──────────────────┴───────────────────┐
│      Native Platform Layer            │
│                                      │
│  MIDI: device discovery, connect,    │
│        note events, timestamps       │
│  Audio: low-latency metronome,       │
│         backing track playback       │
│  OS: file access, permissions        │
│                                      │
│  Windows: WinRT MIDI, WASAPI         │
│  Android: MidiManager, AAudio/Oboe   │
│  iOS (later): CoreMIDI, CoreAudio    │
└──────────────────────────────────────┘
```

**Why this architecture:**

- **Flutter** gives one UI for Windows + Android + iOS + macOS. Strong animation performance. Tablet-friendly. Single debug/build workflow.
- **Rust** owns all timing-critical logic. Deterministic scoring. No GC pauses. Cross-compiles to every platform.
- **Native layer** is intentionally thin: only MIDI I/O and audio output using each platform's best API. Timestamps are captured here (monotonic clock, as close to OS callback as possible) and passed to Rust for scoring.

### 3.2 Platform Strategy

| Platform | Priority | UI | MIDI | Audio | Status |
|----------|----------|-----|------|-------|--------|
| Windows | Phase 1 | Flutter | WinRT MIDI / WinMM | WASAPI | Primary target |
| Android tablet | Phase 1 | Flutter | MidiManager (USB) | AAudio/Oboe | Primary target |
| macOS | Phase 4 | Flutter | CoreMIDI | CoreAudio | Natural extension |
| iPadOS | Phase 4 | Flutter | CoreMIDI | CoreAudio | Important form factor |
| Linux | Phase 3 | Flutter | ALSA | ALSA/JACK | Community interest |
| iOS (phone) | Deprioritized | Flutter | CoreMIDI | CoreAudio | Screen too small for ideal UX |

**MIDI transport policy:**
- USB MIDI: required, primary, recommended
- Bluetooth MIDI: best-effort, with latency warning and calibration
- Virtual MIDI: supported (useful for testing, software instruments)

**Platform latency risk assessment:**

| Platform | MIDI Latency Risk | Audio Latency Risk | Notes |
|----------|-------------------|--------------------|-------|
| Windows | Low | Low-Medium | WinRT MIDI is solid; WASAPI exclusive mode is good |
| Android | **Medium** | **Medium** | Device-dependent; AAudio quality varies by manufacturer |
| macOS | Very Low | Very Low | CoreMIDI/CoreAudio is the industry gold standard |
| iPadOS | Very Low | Very Low | Same CoreMIDI/CoreAudio stack as macOS |
| Linux | Low | Low-Medium | ALSA direct is good; user configuration varies |

Android is the highest-risk platform for latency. The Phase 0 spike targets Windows + Android specifically because if those pass, macOS/iPadOS/Linux are lower risk. If Android latency proves unacceptable, the fallback is a platform-specific native MIDI layer for Android (bypassing Flutter's platform channel) while keeping Flutter for UI. This is a contained fix, not an architecture replacement.

### 3.3 Latency Budget

This is the most critical non-functional requirement.

| Segment | Target | Measurement |
|---------|--------|-------------|
| Physical hit → OS MIDI callback | ~1-3ms (hardware/OS) | Not controllable; included in calibration |
| MIDI callback → Rust timestamp | < 1ms | Platform channel overhead |
| Rust grading computation | < 1ms | `session_on_hit` benchmark |
| Rust → Flutter event delivery | < 2ms | Bridge overhead |
| Flutter animation start | < 8ms (next frame at 120fps) | Frame timing |
| **Total: hit → visual feedback** | **< 20ms perceived** | End-to-end benchmark |
| Calibration offset range | 0-50ms | Per-device, measured |

**Phase 0 validation:** Before committing to this architecture, build a spike that measures actual end-to-end latency on Windows (USB MIDI) and Android tablet (USB MIDI). If the spike shows > 25ms after calibration, reconsider the architecture. This is ADR-001's exit condition.

### 3.4 Audio Output Architecture

The MIDI input side is well-specified. Audio output is equally important:

**Metronome click:**
- Must be sample-accurate relative to the lesson timeline
- Uses platform low-latency audio API (WASAPI exclusive on Windows, AAudio on Android)
- Pre-rendered click samples (not synthesized per-beat)
- Volume controllable independently

**Lesson audio preview (in Studio):**
- Synthesized from lesson events using basic GM drum sounds
- Does not need ultra-low latency (editing context, not performance)

**Backing track playback:**
- User-provided audio file (MP3/WAV/FLAC)
- Synchronized to lesson timeline via beatmap + offset
- Volume controllable independently from metronome

**Backing track details:**
- Beatmap is authored in Studio and stored as part of the lesson (not a separate asset). A beatmap defines the tempo map and bar markers for the audio file so the engine can align lesson events to audio playback position.
- Multiple lessons can reference the same audio file with different beatmap offsets (e.g., different sections of a song).
- When the user adjusts practice tempo (Practice Mode), the audio backing track does NOT time-stretch — it is muted or paused. Only the metronome and lesson events adjust tempo. This avoids audio quality degradation and implementation complexity.
- In Play Mode (fixed tempo matching the lesson default), the backing track plays at normal speed.

**Backing track deferred capabilities (not v1):**
- Drum track muting via stem separation
- Creator-supplied backing assets in marketplace packs
- Audio time-stretching for tempo-adjusted backing
- Licensing framework for reference songs

**Backing track import behavior:** When a lesson with a beatmap is imported (via .taalpack) onto a device that does not have the referenced audio file:
- The lesson imports and plays normally (all events, scoring, metronome work)
- The backing track slot shows "Audio file not found — tap to link a local file"
- The beatmap is preserved intact
- The user can manually link a local audio file to the beatmap
- No audio playback until a file is linked; this is not an error condition

### 3.5 Monorepo Structure

```
taal/
├── lib/                          # Flutter UI (Dart)
│   ├── main.dart
│   ├── app/                      # App shell, routing, themes
│   ├── features/
│   │   ├── player/               # Practice Player screens
│   │   ├── studio/               # Creator Studio screens
│   │   ├── library/              # Content browser
│   │   ├── insights/             # Analytics & progress
│   │   ├── settings/             # Settings, profiles, MIDI
│   │   └── onboarding/           # First-run experience
│   ├── widgets/                  # Shared UI components
│   │   ├── timeline/             # Shared timeline/grid widget
│   │   ├── drum_kit/             # Visual drum kit
│   │   ├── transport/            # Play/pause/loop controls
│   │   └── note_highway/         # Scrolling note display
│   └── design/                   # Design system tokens
├── rust/                         # Rust core engine
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── content/              # Parse, validate, compile
│       ├── runtime/              # Session, grading, scoring
│       ├── time/                 # Musical ↔ ms conversion
│       ├── analytics/            # Aggregation, themes
│       ├── midi/                 # MIDI mapping, device profiles
│       └── storage/              # SQLite, profiles, history
├── native/                       # Platform-specific MIDI/audio
│   ├── android/
│   ├── windows/
│   └── ios/                      # Later
├── docs/
│   ├── prd.md                    # This document
│   ├── adr/                      # Architecture Decision Records
│   └── specs/                    # Detailed technical specifications
├── plans/                        # Phase plans with task IDs
├── assets/                       # Bundled starter content
│   ├── lessons/
│   ├── layouts/
│   └── sounds/                   # Metronome clicks, GM drum samples
├── STATUS.md
├── CHANGELOG.md
└── README.md
```

### 3.6 Distribution and Packaging

| Platform | Package Format | Primary Channel | Cost | Phase |
|----------|---------------|-----------------|------|-------|
| Windows | `.exe` installer (Inno Setup) | GitHub Releases / website | Free (unsigned) | 1 |
| Android | AAB (Play Store) + APK (sideload) | Google Play Store + GitHub | $25 one-time | 1 |
| macOS | `.dmg` disk image (notarized) | Website direct download | $99/year Apple Dev | 2 |
| iPadOS | IPA via App Store | Apple App Store | $99/year Apple Dev (shared with macOS) | 2 |
| Linux | AppImage | GitHub Releases + Flathub | Free | 3 |

**v1 distribution:** Direct download (Windows) + Play Store (Android). GitHub Releases hosts both.

**Code signing:** Windows SmartScreen will warn on unsigned executables. Users click "Run anyway." Code signing ($200-400/year) deferred until user base justifies cost. Android Play Store handles signing via Play App Signing.

**Auto-update:** Not in v1. App checks GitHub API for latest release tag on startup and shows a non-blocking notification if an update is available. Manual download to update.

**CI build artifacts:** The GitHub Actions pipeline (P0-08) must produce runnable installers for Windows (`.exe`) and Android (`.apk`/`.aab`) on every tagged release. Flutter supports `flutter build windows` and `flutter build apk` natively.

**Apple platforms (Phase 2):** macOS requires notarization ($99/year Apple Developer account) or Gatekeeper blocks the app. iPadOS requires App Store distribution (same account). Apple review process adds lead time — budget 1-2 weeks for initial submission.

---

## 4. Product Scope

### 4.1 Practice Player

The Practice Player is Taal's core product surface. It is where learners spend their time.

#### 4.1.1 MIDI Mapping and Device Setup

**Purpose:** Map physical e-kit pads to Taal's semantic drum lanes so every hit registers on the correct instrument.

**Functional capabilities:**
- Auto-detect connected MIDI devices (USB preferred)
- Offer preset profiles for common kits (Roland TD series, Yamaha DTX, Alesis)
- **Visual instrument display:** The mapping/calibration screen shows an interactive visual representation of the current instrument — a 2D overhead drum kit for drums, a piano keyboard for keyboard (future). Each pad/key lights up when a MIDI event is received, showing the current mapping visually. This same visual is used across mapping, calibration, and settings screens.
- Tap-to-map mode: UI shows instrument visual → user hits physical pad → corresponding visual element highlights → assignment confirmed
- Hi-hat openness via MIDI CC4 (continuous controller) → articulation resolution (closed/semi-open/open/pedal)
- Per-device calibration wizard (metronome-aligned tap test → input_offset_ms)
- Save multiple device profiles; switch between them
- Velocity curve presets (linear, soft, hard, custom)

**Extra pads on kit (kit is bigger than lesson):**
- Extra pads that send MIDI notes are mapped via the same tap-to-map or preset mechanism. If the pad's MIDI note maps to a lane in the current layout, it scores normally. If the pad's note doesn't map to any lane in the active lesson, it still produces a visual response (drum kit widget flash) but doesn't affect scoring.
- This applies to: splash cymbals, china cymbals, cowbell, aux triggers (e.g., Roland BT-1 bar trigger pad), bell, second crash, extra toms, etc.

**Missing lanes on kit (lesson is bigger than kit):**
- Before starting a lesson, the runtime derives which lanes the lesson uses and compares against the player's active device profile.
- Lessons can mark lanes as **required** (default) or **optional** (set by creator in Studio — e.g., cowbell or splash in a primarily kick/snare groove).
- If only optional lanes are missing: allowed in all modes, missing events excluded from scoring, result marked "full compatibility."
- If any required lanes are missing:
  - **Practice Mode:** Allowed with warning banner listing missing lanes. Missing-lane events shown but not scored.
  - **Play Mode:** Allowed. Result marked "partial compatibility: N lanes unavailable." Missing-lane events excluded from scoring. Review screen states which lanes were excluded.
  - **Course Gate Mode:** **Blocked.** Required lanes must be present for gated progression. The lesson shows a red indicator and explains which lanes are needed.
- UI compatibility indicator before lesson start: Green (all lanes present), Yellow (only optional lanes missing), Red (required lanes missing).

**Partial-compatibility scoring rule:** A Play Mode result marked "partial compatibility" is flagged in the attempt record. Partial results do not qualify as personal bests, do not count toward mastery thresholds for recommendations, and will not qualify for future leaderboard rankings. This prevents deceptively strong scores from reduced-hardware runs being treated as fully comparable.

**Layout extensibility and presets:**
- The layout system is extensible by design. v1 ships preset layouts: standard 5-piece kit (Phase 1) and extended 7-piece kit (Phase 3). The architecture supports additional presets and future user-authored custom layouts, but custom layout creation UI is not in v1 scope.
- Preset layouts define the superset of available lanes. Lessons use a subset of their layout's lanes.

**UX flow:**
First time: auto-detect → preset match → quick verify (hit each pad, confirm mapping) → calibrate → done.
Returning: auto-load last device profile. Re-calibrate available in settings.

**Edge case: MIDI disconnect mid-session.** Pause session immediately. Show reconnection prompt. On reconnect, resume from pause point. No data loss.

**Artifacts used:** Instrument Layout (specs/content-schemas.md), Device Mapping (specs/midi-mapping.md)
**Artifacts produced:** Device profiles (stored in SQLite)

#### 4.1.2 Practice Views

**Note-Highway View (primary for beginners):**
- Vertical scrolling lanes, one per drum piece
- Notes approach a hit line from top to bottom
- Color-coded by instrument lane
- Timing feedback: hit markers offset left (early) or right (late) from center
- Inspired by Guitar Hero / Melodics, but with Taal's visual language

**Notation View (secondary, for experienced players):**
- Standard drum notation on a staff
- Scrolling or page-based (user toggle)
- Current position highlighted
- Same timing feedback overlaid on notation
- Not a full notation editor — read-only during practice

**Both views available as a toggle during practice.** User's preferred default saved in profile.

**On-Screen Tap Pads (no-kit mode):**
- Virtual drum pads on screen for practice without a MIDI device connected
- Touch-responsive with the same timing feedback as MIDI input
- Useful for: rhythm practice on the go, demo mode during onboarding, learning patterns before hitting the kit
- Not a replacement for real kit practice (limited velocity sensitivity from touch input)

**Visual Drum Kit (supplementary):**
- 2D overhead view of a drum kit
- Each pad flashes on hit (color = timing accuracy)
- Serves as MIDI mapping reference and visual feedback reinforcement
- Can be shown alongside note-highway or notation, or hidden

#### 4.1.3 Practice Modes

**Practice Mode (learning-first):**
- Tempo adjustable live (slow down to learn, speed up to challenge)
- Infinite retries
- A-B section looping allowed
- Full visual feedback on every hit
- Encouragement messages enabled
- No gating or scoring pressure
- **"Listen first":** Tap a button to hear the section/lesson played back with synthesized drum sounds before attempting it. Helps users understand what they're aiming for.
- **Auto-pause:** If the player stops hitting during an active playing window for a configurable duration (default 3 seconds), the session pauses automatically. Resume by hitting any pad. Auto-pause is aware of intentional rests in the lesson — it only triggers when expected hits are being missed, not during notated rests or sparse sections. Practice Mode only. Disabled by default; user can enable in settings.

**Speed Training Mode (sub-mode of Practice):**
- Start at a user-set tempo (e.g., 60 BPM)
- On successful loop pass (score ≥ threshold), auto-increase BPM by a configurable increment (default: 5 BPM)
- On failed pass, maintain current tempo (or decrease by increment, user-configurable)
- Visual indicator of current tempo and target ceiling
- Excellent for building speed on rudiments and patterns

**Play Mode (assessment):**
- Fixed tempo (lesson default)
- Full lesson run, no pauses
- Feedback shown but no hints
- Score displayed at end
- Progress saved

**Course Gate Mode (progression):**
- Activated when lesson is part of a course
- Must achieve minimum score to unlock next lesson
- Retry limits configurable per course
- Clear pass/retry/fail outcome
- "Practice first" option available before scored attempt

#### 4.1.4 A-B Section Looping

- Lessons define named sections (Intro, Main Groove, Fill, etc.)
- User can select section from list OR manually drag A-B handles on timeline
- Loop between A and B indefinitely (Practice Mode)
- Section-level stats tracked separately
- Snap to bar/beat boundaries

#### 4.1.5 Timing Feedback and Scoring

**Timing states (emitted by Rust engine, never computed by UI):**

| State | Condition | Color | Animation |
|-------|-----------|-------|-----------|
| Perfect | Within tight window (~20ms) | Green/Teal | Tight pulse + glow |
| Good | Within medium window (~45ms) | Lighter green | Soft pulse |
| Early | Before window, negative delta | Blue | Forward-shifted marker |
| Late | After window, positive delta | Amber/Orange | Trailing echo |
| Miss | No hit registered | Muted gray | Dim fade |

**Scoring per attempt:**
- Overall score (0-100)
- Accuracy percentage
- Hit rate percentage
- Timing bias (mean delta: early vs late)
- Timing consistency (standard deviation)
- Per-lane breakdown
- Max combo/streak

**Combo and encouragement:**
- Combo increments on Perfect/Good hits
- Resets on Miss
- Milestone messages at 8, 16, 32 hits (subtle, not intrusive)
- Example messages: "Nice groove", "Locked in", "Solid timing"
- Suppressible via Focus Mode setting

**Post-lesson review:**
- Score animation
- Best stat highlighted first (positive reinforcement)
- 1-2 specific improvement suggestions
- Timing histogram (visual early/late distribution)
- Lane heatmap (which drums need work)
- Course progress indicator (if applicable)

**Artifacts used:** Scoring Profile (specs/content-schemas.md), Lesson (specs/content-schemas.md)
**Artifacts produced:** Practice Attempt records (specs/analytics-model.md)

#### 4.1.6 Course Progression

When a lesson is part of a course:
- Show course context: name, current position, progress bar
- Gating enforced per course rules (minimum score)
- Locked lessons visually distinct (dimmed, lock icon)
- "Next lesson" CTA on pass
- "Practice more" or "Retry" on fail

#### 4.1.7 Metronome and Audio

- Metronome: always available, toggleable, volume-adjustable
- Click sound: configurable (classic click, woodblock, hi-hat, etc.)
- Count-in: configurable bars (default 1)
- Backing track: loads user-provided audio, synced via beatmap offset
- Separate volume controls for metronome and backing track
- Audio output latency compensated via platform-native low-latency path

#### 4.1.8 Print Sheet Music

**Purpose:** Generate a printable PDF of a lesson's drum notation for offline practice (acoustic kit, away from the app, teacher handouts).

**Scope (limited, not a full notation editor):**
- Render the lesson's notation view to a print-friendly layout
- Standard drum notation on a staff, one or more pages
- Include lesson title, tempo, time signature, section labels
- Export as PDF
- Accessible from both Player (viewing a lesson) and Studio (editing a lesson)

**Constraints:**
- Layout is functional, not publication-quality (not competing with Sibelius/MuseScore)
- No editing in the print view
- No custom notation formatting options in v1
- Depends on the notation view widget existing (Phase 1)

#### 4.1.9 Practice Streaks and Daily Goals

**Purpose:** Drive retention through lightweight gamification and habit tracking.

**Features:**
- Daily practice streak counter (consecutive days with at least one scored session)
- Streak displayed on home screen (e.g., "🔥 5-day streak")
- Configurable daily practice goal (default: 10 minutes)
- Progress ring or bar showing daily goal completion
- Weekly summary: days practiced, total time, lessons completed
- Streak milestone celebrations (7 days, 30 days, 100 days — subtle, encouraging)

**Design principles:**
- Encouraging, not punishing. Missing a day shows "Start a new streak!" not "Streak broken 😢"
- Not competitive (no public leaderboards in v1). Leaderboards are a future/marketplace feature.
- Lightweight: no complex achievement systems. Just streaks + daily goal + weekly summary.

#### 4.1.10 Latency Fine-Tuning

In addition to the calibration wizard (4.1.1), provide a manual latency offset slider in Settings:
- Slider range: -50ms to +50ms
- Allows power users to fine-tune offset beyond what auto-calibration provides
- Real-time preview: user can tap along with a click while adjusting
- Stored in device profile alongside auto-calibration offset

### 4.2 Creator Studio

Creator Studio is where content is authored. It shares visual language with the Practice Player but serves a different job: creation rather than performance.

#### 4.2.1 Lesson Editor

**Purpose:** Create and edit instrument-specific lessons by authoring time-based note events on a musical grid.

**Core responsibilities:**
- Author musical content (lanes + events on a grid)
- Define lesson structure (sections, loops)
- Attach learning outcomes and metadata
- Preview lesson behavior using the Rust core engine

**Functional capabilities:**

Editing:
- Create, select, move, duplicate, and delete note events
- Multi-select operations (box select, shift-click)
- Quantized grid-based placement (snap-to-grid default)
- Manual velocity adjustment per event
- Articulation selection per event (e.g., hi-hat open/closed)
- Copy/paste across sections
- Undo/redo (minimum 50 levels)

Grid and time:
- Musical time representation (bars / beats / ticks)
- Constant tempo per lesson (tempo map support in schema, simple UI in v1)
- Selectable grid resolution: 1/4, 1/8, 1/16, triplets
- Snap-to-grid enabled by default; optional off-grid via modifier

Lanes:
- One lane per instrument piece (defined by instrument layout)
- Visual differentiation per lane (subtle color or label)
- Fixed lane layout per selected instrument layout

Sections and looping:
- Named sections defined as time ranges on the timeline
- Loopable sections (feeds into A-B practice in Player)
- Create section by dragging on timeline ruler

Metadata:
- Learning outcomes (skills taxonomy tags)
- Difficulty level (beginner / intermediate / advanced)
- Tags and descriptive text
- Practice defaults (count-in, metronome, start tempo, tempo floor)

**Preview:**
- Uses the same Rust core engine as Player
- Play with metronome, step through sections
- Timing feedback shown (same semantics, reduced intensity)
- Preview is non-scoring (no attempt stored)

**Constraints (v1):**
- No audio track authoring
- No tempo automation (constant tempo only; schema supports tempo map)
- No swing/humanization
- Lesson Editor must never diverge from Player execution semantics

**Artifacts used:** Instrument Layout, Scoring Profile (specs/content-schemas.md)
**Artifacts produced:** Lesson definitions (specs/content-schemas.md)

#### 4.2.2 Course Designer

**Purpose:** Assemble lessons into structured, guided learning paths with progression rules.

**Conceptual model:** A course is an ordered sequence of lessons (v1) with per-lesson gate rules. The underlying data model supports directed graphs (for future branching), and the long-term UX vision is a visual node-based flow editor (inspired by tools like n8n and Melodics' learning paths) where lessons are nodes and edges represent progression conditions. v1 starts with a simpler ordered-list interface that is still visually appealing and drag-and-drop capable.

**Functional capabilities:**
- Add lessons from library as course steps
- Reorder lessons via drag-and-drop in a visual flow layout
- Define per-lesson gate rules: minimum score, max retries, practice-before-retry
- Set course-level defaults for gates (individual lessons can override)
- Course metadata: title, description, difficulty, learning outcomes, estimated duration
- Validation: warn on missing lessons, unreachable steps, impossible gates
- Visual progress indicator: learners see their position in the course flow with completed/locked/current states

**Preview and simulation:**
- Simulate course flow with hypothetical performance levels
- See which lessons would be locked/unlocked
- No actual performance data generated

**Future capabilities (not v1):**
- Full visual node-graph editor (branching paths, optional side-quests, skill-based routing)
- AI-adaptive learning paths: the AI coach (Phase 4) analyzes learner performance and dynamically adjusts the course path — suggesting easier remedial lessons when the learner struggles, or skipping ahead when mastery is demonstrated. This requires the graph-based course model (already in schema) plus the analytics/theme detection data.
- Auto-generated course suggestions based on learner's weakness profile

**v1 course model lock:** The course schema is graph-capable (nodes + edges), but **Phase 2 implementation authors only the linear subset.** The UI presents courses as an ordered list with progression gates. Edges are always `from: previous → to: next` with no branching. This is an explicit scope decision, not a limitation of the data model. Graph-capable UI (branching, side-quests, adaptive paths) is deferred to Phase 5+.

**Constraints (v1):**
- Linear course flow only (no branching in UI, though schema supports it)
- No adaptive difficulty
- No automatic lesson insertion from recommendations

**Artifacts used:** Lessons (from Lesson Editor)
**Artifacts produced:** Course definitions (specs/content-schemas.md)

#### 4.2.3 Pack Builder

**Purpose:** Bundle lessons, courses, and supporting assets into a validated, distributable unit.

**Conceptual model:** A pack is a read-only distribution artifact. The Pack Builder is a compiler, not an editor. It assembles, validates, versions, and exports.

**Workflow:**
1. Select content scope (lessons, courses, or both)
2. Studio auto-resolves dependencies (required layouts, scoring profiles)
3. Validation runs (schema, referential integrity, instrument consistency)
4. Metadata entry (title, description, difficulty, optional artwork)
5. Export as `.taalpack` (ZIP with deterministic structure)

**Validation levels:**
- Errors (block export): invalid schema, dangling references, instrument mismatch
- Warnings (export allowed): missing artwork, empty description, sparse tags

**Constraints (v1):**
- No marketplace publishing (local export only)
- No partial exports
- No post-export editing

**Artifacts used:** Lessons, Courses, Layouts, Scoring Profiles
**Artifacts produced:** Pack files (.taalpack)

#### 4.2.4 Studio-Wide Behaviors

**Content lifecycle:** Draft → Validated → Exported. Editing a previously exported item creates a new revision.

**Persistence:** All edits autosaved locally. Crash recovery. No manual save required.

**Versioning:** Stable IDs + revision identifiers. Older revisions accessible.

**Reuse:** One lesson can be referenced by multiple courses and included in multiple packs. Studio shows dependency graph ("where is this lesson used?").

**Consistency:** Studio shares visual language with Player — same color semantics, iconography, animation principles, transport controls.

#### 4.2.5 Audio-to-Lesson Extraction (Future — Significant Capability)

**Purpose:** Import an audio recording (e.g., a Led Zeppelin track as MP3) and use ML to automatically extract the drum beat pattern, producing a draft lesson that creators can then review and edit.

**How it works (conceptual):**
1. User imports an audio file into Studio
2. ML pipeline performs: onset detection → drum classification (kick/snare/hat/tom/cymbal) → tempo estimation → quantization to grid
3. System produces a draft lesson with confidence scores per event ("85% confident this is a snare hit")
4. Creator reviews, corrects misidentified hits, adjusts timing, and saves as a normal lesson
5. The original audio is NOT stored in the lesson or distributed — only the extracted beat pattern

**Why this matters:** This is the fastest path from "I want to learn that song's drum part" to a playable lesson. Combined with user-provided backing tracks, it enables practicing along to real music with real feedback.

**Technical approach:**
- Audio source separation (isolate drums from mix) using pre-trained models (e.g., Demucs, Open-Unmix)
- Drum transcription (classify individual hits) using onset detection + ML classification
- Tempo and beat tracking for grid alignment
- Confidence scoring per detected event

**Scope and phasing:** This is a significant ML engineering effort and is explicitly a later-phase capability (Phase 5+). However, the lesson data model already supports it — the output is just a standard lesson with events on lanes. No schema changes needed. The original Taal repo already had a prototype `transcriber` crate exploring this direction.

**Legal note:** The extraction produces a beat pattern (not copyrightable). The audio file itself is never distributed. This is analogous to a human transcribing a drum part by ear — the transcription is original work.

#### 4.2.6 Help, Tooltips, and About

**Purpose:** Provide in-app guidance and product information.

**Tooltips (v1):**
- Contextual tooltips on complex UI elements, especially in Creator Studio (grid resolution, articulation selectors, gate rules, scoring profile fields)
- Brief, non-blocking (hover on desktop, long-press on tablet)
- Not needed on simple/obvious controls

**Help section (accessible from Settings/menu):**
- v1: links to online documentation (GitHub wiki or docs site) + basic FAQ
- v1.1+: searchable in-app help with topic-based articles
- Content written as markdown, rendered in-app or in browser

**About page (accessible from Settings → About):**
- App name and version (from build metadata)
- Developer/project credits
- Open-source license
- Link to project website / GitHub
- Link to community (if applicable)
- Build info (platform, engine version)

**Platform conventions:** About page location follows platform convention:
- Windows: Help → About (menu bar, or Settings → About)
- Android: Settings → About
- macOS/iOS (future): App menu → About

### 4.3 Analytics and Insights

#### 4.3.1 Practice History

Every scored practice attempt is stored locally:
- Attempt-level metrics: score, accuracy, timing bias, consistency, per-lane stats
- Session context: time of day, day of week, duration, mode, device, tempo
- Lesson and course context

This data feeds the Insights dashboard and (later) AI coaching.

#### 4.3.2 Performance Themes (System-Detected)

The system automatically detects patterns in practice data using deterministic rules (no ML required in v1):
- Global timing bias (consistently early or late)
- Lane-specific issues (snare late, hi-hat inconsistent)
- Tempo plateaus (accuracy drops above certain BPM)
- Endurance patterns (performance degrades after N minutes)
- Time-of-day effectiveness (practice better in morning vs evening)

Themes are computed from rolling windows (7-day, 30-day) and require minimum attempt counts for confidence.

#### 4.3.3 Insights Dashboard

Accessible via "Insights" tab in Player mode:
- Weekly practice summary (time, sessions, trend)
- Current focus areas (top themes)
- Tempo progress (ceiling by pattern type)
- Timing consistency over time
- "When you practice best" (time-of-day chart)
- Recommended lessons (tag-based matching against themes)

#### 4.3.4 AI Coach (Future — Data Hooks From Day 1)

After sufficient practice history, an AI (local via Ollama or cloud API) can:
- Generate natural-language coaching summaries
- Create personalized practice plans from available lessons
- Identify recurring weakness patterns across lessons
- Suggest specific exercises for identified weaknesses

**Data prerequisites (collected from day 1):**
- Practice attempt records with full timing metrics
- Learning outcomes metadata on all lessons
- Performance theme detection results
- Session context (time, duration, device)

**This is a planned Phase 4 capability, not a v1 promise.** But the data model supports it from the start.

### 4.4 Marketplace (Future — Schema-Ready, No System in v1)

**Vision:** A community-driven content repository where creators share lessons, courses, and packs. Free content is the default; paid content is a future possibility.

**v1 reality:** No marketplace UI, no publishing flow, no discovery system. Content sharing is via file export/import (.taalpack files).

**Schema readiness:** Content schemas include optional marketplace fields (publisher, rights declaration, licensing). These fields are ignored by local workflows and add no complexity to v1 implementation. They exist so the data model doesn't need breaking changes when the marketplace launches.

### 4.5 Release Boundary

**MVP (Phases 0-2): Playable + Creatable.** A user can practice with real-time feedback and a creator can author and share content. No analytics, no backing tracks, no distribution packaging. Functional but not release-ready.

**v1.0 (Phases 0-3): Releasable product.** Adds analytics, insights, backing tracks, polish, error handling, and packaged distribution for Windows and Android. This is the first version distributed to users.

#### MVP Committed (Phases 0-2)
- Practice Player with note-highway view (primary) and notation view (secondary)
- Real-time MIDI feedback with timing accuracy scoring
- Practice mode (tempo adjust, A-B loop) and Play mode (scored)
- MIDI device setup with visual instrument display and calibration
- Visual drum kit feedback overlay
- Creator Studio: Lesson Editor, Course Designer (linear with gates), Pack Builder
- Local profiles (no login)
- Bundled starter content (10-15 drum lessons)
- MusicXML import (best-effort)
- Metronome with low-latency audio
- Print sheet music (basic PDF export — practice-sheet quality, not engraving-grade)

#### v1.0 Additions (Phase 3 — required for public release)
- Practice history dashboard + insights (trends, tempo ceiling, time-of-day)
- Performance theme detection + lesson recommendations
- Backing track playback (user-provided audio, beatmap sync)
- Profile export/import (file-based device-to-device transfer)
- Extended content (20+ lessons, 2 courses)
- UI polish, error states, empty states
- **Windows build:** `.exe` installer via GitHub Releases
- **Android build:** Play Store AAB + sideload APK

#### v1.0 included but limited:
- Notation view: functional but not as polished as note-highway
- Velocity/dynamics: captured and displayed, but not factored into scoring in v1
- Backing tracks: user-provided audio with manual offset sync; no stem muting
- Course Designer: linear flow with visual layout; no branching or adaptive paths

#### Explicitly deferred (not in v1.0):
- Marketplace UI, publishing flow, discovery, moderation
- AI coach / personalized practice plans / adaptive learning paths
- Audio-to-lesson ML extraction (beat detection from recordings)
- Visual node-graph course editor (n8n-style branching)
- Stem separation for backing tracks
- BLE MIDI support
- macOS / iPadOS / Linux builds
- Cloud sync, user accounts
- Acoustic kit support (microphone-based)
- Multi-language support

**Future cloud stance:** v1 is fully local-first, no account required. Future cloud capabilities (marketplace, optional sync, AI coaching) may introduce optional services but must never block core offline practice.

---

## 5. Content and Data Model

### 5.1 Core Entities

| Entity | Purpose | Defined in |
|--------|---------|------------|
| Lesson | Time-based musical instruction unit | specs/content-schemas.md |
| Course | Ordered sequence of lessons with progression rules | specs/content-schemas.md |
| Pack | Distribution bundle of lessons + courses + assets | specs/content-schemas.md |
| Instrument Layout | Lane definitions, visual mapping, MIDI hints | specs/content-schemas.md |
| Scoring Profile | Timing windows, grade weights, combo rules | specs/content-schemas.md |
| Device Mapping | Physical MIDI → semantic lane mapping | specs/midi-mapping.md |
| Practice Attempt | Recorded performance metrics | specs/analytics-model.md |
| Player Profile | Local user identity, preferences, history | specs/analytics-model.md |

### 5.2 Instrument Abstraction

All content is authored against an **instrument family** (drums, keyboard, etc.) and a specific **instrument layout** (standard 5-piece kit, extended kit, etc.).

Lanes are semantic: `kick`, `snare`, `hihat`, not MIDI note numbers. MIDI mapping is a separate concern handled by device profiles.

This means:
- A drum lesson works with any e-kit once mapped
- A keyboard lesson (future) uses the same content infrastructure
- New instruments require: a layout definition, a visual renderer, and MIDI mapping rules — not engine changes

### 5.3 Hybrid Time Model

**Canonical representation:** Musical time — `{ bar, beat, tick }` with `ticks_per_beat` (default 480, like MIDI PPQ).

**Derived representation:** Absolute milliseconds, computed at load time from the tempo map.

**Why hybrid:** Musical time is intuitive for editing (Studio). Absolute time is required for scoring (Player). The Rust engine compiles a `TimingIndex` on lesson load that provides bidirectional conversion.

### 5.4 Schema Versioning

- Every schema has a `schema_version` field
- Backward compatibility maintained within major versions
- Migration logic in Rust handles version upgrades on load
- Pack validation enforces schema version consistency

Detailed schema definitions are in `specs/content-schemas.md`. The PRD deliberately avoids embedding exact JSON field names — schemas are defined as typed Rust structs and exported as JSON Schema for validation.

---

## 6. UX Principles and Visual Language

### 6.1 Design Principles

- **Latency > beauty:** Animation must never delay feedback
- **Motion explains timing:** Early/late is felt through directional animation, not text
- **Positive first:** Show what's right before what's wrong
- **Low cognitive load during play:** No text spam during dense passages
- **Consistent everywhere:** Studio preview ≈ Player execution; same visual language
- **Dark-first:** Music-friendly, focus-preserving, comfortable for long sessions
- **Tablet-optimized:** Touch targets, landscape layouts, no hover-dependent interactions

### 6.2 Color Semantics

| Token | Meaning | Usage |
|-------|---------|-------|
| `color.hit.perfect` | Spot-on timing | Green/Teal |
| `color.hit.good` | Slight deviation | Lighter green |
| `color.hit.early` | Ahead of beat | Blue |
| `color.hit.late` | Behind beat | Amber/Orange |
| `color.hit.miss` | Missed note | Muted gray |
| `color.neutral` | Expected/upcoming | Subdued neutral |

**Accessibility:** No red/green-only contrast. Early vs Late distinguished by hue, not brightness alone. High-contrast mode available. Reduce-motion mode shortens animations.

### 6.3 Animation Timing

- All per-hit animations: < 150ms duration
- Easing: ease-out (fast start, gentle settle)
- No bounce unless intentional
- Dropped frames must not affect scoring
- Focus Mode: minimal animations, no encouragement text

Detailed visual spec in `specs/visual-language.md`.

---

## 7. Security, Privacy, and Data Governance

### 7.1 Privacy Model

Taal is local-first. No data leaves the device unless the user explicitly exports it.

- No telemetry (or opt-in only, clearly disclosed)
- No user accounts required
- No cloud sync (file-based export/import only)
- Practice history is local SQLite
- No analytics sent to any server

### 7.2 Content Safety

- User-provided audio files are never distributed by Taal
- Beatmaps (tempo/beat markers) are not copyrightable and can be freely shared
- Marketplace (future) requires content ownership declaration by creators
- No DRM

### 7.3 Data Export and Deletion

- Export full profile + history as a portable file
- Delete individual sessions or full history
- Delete profile entirely
- Uninstall removes all local data

---

## 8. Non-Functional Requirements

### 8.1 Latency (see also Section 3.3)

- MIDI hit → visual feedback: ≤ 20ms perceived (after calibration)
- Rust engine `session_on_hit`: < 1ms typical, < 3ms worst-case
- Metronome click: sample-accurate relative to lesson timeline

### 8.2 Startup and Responsiveness

- App cold start to interactive: < 3 seconds (Windows), < 5 seconds (Android)
- Lesson load to playable: < 1 second for typical lesson (< 500 events)
- UI frame rate: 60fps minimum during practice; no dropped frames during hit feedback

### 8.3 Reliability

- Autosave in Studio: continuous, non-blocking. Crash recovery restores last edit.
- MIDI disconnect mid-session: pause immediately, prompt reconnection, resume without data loss
- Corrupt lesson file: graceful error with actionable message, no crash
- Database corruption: detect on startup, offer reset with data loss warning

### 8.4 Offline Behavior

- v1 architectural stance: **local-first, no account required, fully offline-capable**
- All practice, creation, and analytics features work without internet
- Future cloud capabilities (marketplace, sync, AI coach) must not block core offline practice
- Marketplace content, once downloaded, is available offline

### 8.5 Resource Usage

- Memory during active practice: < 200MB (excluding backing track audio buffer)
- CPU during practice: < 25% sustained on mid-range hardware (Intel i5 / Snapdragon 7xx)
- Battery (Android tablet): > 3 hours continuous practice on typical tablet
- Storage: base install < 100MB; practice history grows ~1KB per attempt

### 8.6 Device Disconnect Handling

- USB MIDI disconnect: immediate session pause, visual indicator, reconnection prompt
- Bluetooth MIDI disconnect: same behavior + "reconnecting..." state with timeout
- Audio device disconnect: mute output, continue session (scoring still works without audio)

### 8.7 Accessibility

- Color-blind safe palette (no red/green-only contrast)
- High-contrast mode
- Reduce-motion mode (shorter animations, no glows)
- Minimum touch target: 48dp (Android Material guidelines)
- Keyboard navigation for Studio (desktop)

---

## 9. Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| UI framework | Flutter 3.x (Dart) | All screens, all platforms |
| Core engine | Rust (2021 edition) | Timing, scoring, content, analytics |
| Bridge | flutter_rust_bridge | Flutter ↔ Rust async FFI |
| Database | SQLite (via rusqlite in Rust) | All persistent data |
| MIDI (Windows) | WinRT MIDI / WinMM | Device I/O |
| MIDI (Android) | android.media.midi | Device I/O |
| Audio (Windows) | WASAPI (via cpal/oboe) | Low-latency metronome/backing |
| Audio (Android) | AAudio/Oboe | Low-latency metronome/backing |
| Serialization | serde (Rust), JSON | Content files |
| Testing | Rust: cargo test; Dart: flutter_test | All layers |
| Linting | Rust: clippy; Dart: flutter_lints | Code quality |
| CI | GitHub Actions | Build, test, lint on every push |

---

## 10. Data Models

Data models are defined as typed Rust structs (core engine) and Dart classes (UI layer). JSON Schema is exported from the Rust definitions for validation.

The following are the key model outlines. Full field-level definitions are in the companion specs.

### 10.1 Lesson

```
Lesson {
    id: Uuid
    revision: SemVer
    title: String
    instrument: InstrumentRef { family, variant, layout_id }
    timing: TimingConfig { time_signature, ticks_per_beat, tempo_map }
    lanes: Vec<Lane { lane_id, events: Vec<Event> }>
    sections: Vec<Section { id, label, range, loopable }>
    practice: PracticeDefaults { modes, count_in, metronome, tempo_floor }
    metadata: LessonMeta { difficulty, tags, skills, objectives }
    scoring_profile_id: Option<String>
    assets: AssetRefs { backing, artwork }
    // Optional marketplace fields (ignored locally)
    publisher: Option<PublisherRef>
}
```

### 10.2 Course

```
Course {
    id: Uuid
    revision: SemVer
    title: String
    instrument_family: String
    nodes: Vec<CourseNode { node_id, lesson_id, label }>
    edges: Vec<CourseEdge { from, to, condition }>
    progression: ProgressionConfig { mode, default_gate }
    metadata: CourseMeta { difficulty, tags, skills, estimated_duration }
}
```

### 10.3 Practice Attempt

```
PracticeAttempt {
    id: Uuid
    player_id: Uuid
    lesson_id: Uuid
    mode: PracticeMode
    bpm: f32
    duration_ms: u64
    // Outcomes
    score: f32
    accuracy_pct: f32
    timing_bias_ms: f32  // negative = early
    timing_std_ms: f32
    per_lane_stats: HashMap<String, LaneStats>
    // Context
    started_at: DateTime
    local_hour: u8
    device_profile_id: Option<Uuid>
}
```

### 10.4 Player Profile

```
PlayerProfile {
    id: Uuid
    name: String
    avatar: Option<String>
    experience_level: ExperienceLevel
    preferred_view: PracticeView  // NoteHighway | Notation
    device_profiles: Vec<DeviceProfileRef>
    created_at: DateTime
}
```

Full data model definitions in `specs/content-schemas.md`, `specs/analytics-model.md`, `specs/midi-mapping.md`.

---

## 11. Testing Strategy

### 11.1 Test Layers

| Layer | What | Scope |
|-------|------|-------|
| Unit (Rust) | Scoring logic, time conversion, content validation | All core engine |
| Unit (Dart) | Widget behavior, state management | All UI logic |
| Integration | Rust ↔ Flutter bridge, MIDI → engine → UI pipeline | Cross-layer |
| Content | All bundled lessons/layouts validate against schema | Bundled content |
| Latency | MIDI → Rust → Flutter benchmark | Performance gate |
| Platform | Build + launch on Windows and Android | Smoke test |

### 11.2 Latency Benchmark

Automated test that measures end-to-end latency:
- Injects a synthetic MIDI NoteOn event with a known timestamp
- Measures time to Rust `HitGraded` event emission
- Measures time to Flutter animation scheduling
- Fails build if p95 engine time > 3ms or p95 end-to-end > 20ms

### 11.3 Success Metrics

**Build gates (CI-enforced):**
- All unit tests pass
- All content schema validations pass
- Latency benchmark within threshold
- Lint clean (clippy + flutter_lints)
- Builds successfully on Windows and Android

**Product metrics (human-reviewed):**
- Time from install to first played note (target: < 90 seconds)
- First-session completion rate
- Return rate after first session
- Lessons created by community (marketplace phase)

---

## 12. Phased Delivery Plan

### Phase 0: Foundation + Latency Spike (1-2 sessions)

**Objective:** Prove the architecture works. Measure actual latency. Set up the monorepo.

**Deliverables:**
- Flutter + Rust monorepo scaffold
- flutter_rust_bridge integration (hello world → real FFI call)
- Native MIDI adapter (Windows USB) — detect device, capture NoteOn
- Latency spike: MIDI NoteOn → Rust timestamp → Flutter callback. Measure.
- Basic Rust engine: accept hit, emit grade (hardcoded expected event)
- CI pipeline (build, test, lint)
- ADR-001: Architecture decision with spike results
- README, STATUS.md, CHANGELOG.md

**Task ordering note:** Task IDs are identifiers, not execution order. Dependencies define the real sequencing. Some lower-numbered tasks depend on higher-numbered ones (e.g., P1-07 depends on P1-15). Agents must respect the dependency graph, not numeric order.

**Tasks:**

| ID | Title | Deps |
|----|-------|------|
| P0-01 | Monorepo scaffold (Flutter + Rust + native) | — |
| P0-02 | flutter_rust_bridge integration | P0-01 |
| P0-03 | Windows MIDI adapter (USB NoteOn capture) | P0-01 |
| P0-04 | Rust engine skeleton (accept hit, emit grade) | P0-02 |
| P0-05 | End-to-end latency measurement | P0-03, P0-04 |
| P0-06 | Android MIDI adapter (USB NoteOn capture) | P0-01 |
| P0-07 | Android latency measurement | P0-06, P0-04 |
| P0-08 | CI pipeline | P0-01 |
| P0-09 | ADR-001 (architecture decision with measured data) | P0-05, P0-07 |

**Exit criteria:**
- Measured end-to-end latency on Windows AND Android
- If latency acceptable (< 25ms): proceed with Flutter + Rust
- If latency unacceptable: revisit architecture (ADR-001 documents alternatives)
- CI builds and tests pass

---

### Phase 1: Core Practice Loop (primary phase)

**Objective:** A user can connect their kit, play a lesson, and get real-time feedback. This is the minimum lovable product.

**Deliverables:**
- MIDI device setup with tap-to-map and calibration
- Rust engine: lesson loading, compilation, session management, grading
- Note-highway practice view (primary)
- Notation practice view (secondary)
- Visual drum kit feedback
- Practice mode (tempo adjust, A-B loop, full feedback)
- Play mode (fixed tempo, scored)
- Metronome with low-latency audio output
- Post-lesson review screen
- Scoring profile loading
- Local profiles ("Who's playing?")
- Bundled starter content: 10-15 drum lessons (beginner to intermediate)
- Instrument layout: standard 5-piece kit
- Settings: MIDI, audio, display preferences
- Onboarding flow (connect → calibrate → play)

**Tasks:**

| ID | Title | Deps |
|----|-------|------|
| P1-01 | Rust content module: parse lesson, layout, scoring | P0-04 |
| P1-02 | Rust time module: musical ↔ ms, tempo map | P0-04 |
| P1-19 | Standard 5-piece layout definition | P1-01 |
| P1-18 | Starter lesson content (10-15 lessons) | P1-01, P1-19 |
| P1-03 | Rust compile module: lesson → execution timeline | P1-01, P1-02 |
| P1-04 | Rust runtime: session start/stop/tick/hit/drain | P1-03 |
| P1-05 | Rust scoring: timing windows, grades, combos | P1-04 |
| P1-06 | MIDI mapping engine (note → lane, hi-hat CC4) | P0-03, P0-06 |
| P1-16 | Local profiles (create, switch, persist) | P0-02 |
| P1-08 | Device profile persistence (SQLite) | P1-06, P1-16 |
| P1-15 | Metronome audio output (low-latency) | P0-03 |
| P1-07 | Calibration wizard UI + logic | P1-06, P1-15 |
| P1-09 | Note-highway widget | P0-02 |
| P1-10 | Notation view widget | P0-02 |
| P1-11 | Visual drum kit widget | P0-02 |
| P1-14 | Post-lesson review screen | P1-05 |
| P1-21 | Practice attempt persistence (SQLite) | P1-05, P1-16 |
| P1-12 | Practice mode screen (transport, A-B loop, tempo) | P1-04, P1-09, P1-10, P1-11, P1-15 |
| P1-13 | Play mode screen (fixed tempo, scored run) | P1-12, P1-14, P1-21 |
| P1-20 | Settings screen (MIDI, audio, display, manual latency slider) | P1-08, P1-07, P1-15, P1-16 |
| P1-17 | Onboarding flow (5-screen first-run) | P1-07, P1-16, P1-12, P1-18, P1-23 |
| P1-22 | App shell: home screen, navigation, profile switcher | P1-16 |
| P1-23 | On-screen tap pads (no-kit practice mode) | P0-02, P1-04, P1-12 |
| P1-24 | Practice streaks and daily goal tracking | P1-21, P1-22 |
| P1-25 | Listen-first playback (hear section before playing) | P1-04, P1-12, P1-15 |
| P1-26 | Auto-pause (pause session on player inactivity) | P1-04, P1-12, P1-20 |
| P1-27 | Layout compatibility check + missing-lane handling | P1-03, P1-06, P1-12, P1-13, P1-14 |

**Exit criteria:**
- New user: install → connect → calibrate → play lesson → see score in < 2 minutes
- All three practice views working (note-highway, notation, drum kit)
- Practice and Play modes functional
- A-B loop working
- 10+ starter lessons playable
- Metronome audible with acceptable latency

---

### Phase 2: Creator Studio + Content System

**Objective:** Users can create their own lessons and courses. Content can be shared as packs.

**Deliverables:**
- Lesson Editor (full grid-based authoring)
- Course Designer (ordered list with gate rules)
- Pack Builder (validate + export .taalpack)
- Import: MusicXML drum charts (best-effort; imported lessons may require manual cleanup in Studio)
- Import: .taalpack files
- Content library browser
- Schema validation (strict on export, lenient in workspace)

**Tasks:**

| ID | Title | Deps |
|----|-------|------|
| P2-01 | Lesson Editor: grid canvas, lane rendering | P1-01 |
| P2-02 | Lesson Editor: event CRUD (add, select, move, delete) | P2-01 |
| P2-03 | Lesson Editor: copy/paste, multi-select, undo/redo | P2-02 |
| P2-04 | Lesson Editor: velocity/articulation editing | P2-02 |
| P2-05 | Lesson Editor: sections, grid resolution, tempo | P2-02 |
| P2-06 | Lesson Editor: preview (play with Rust engine) | P2-05, P1-04, P1-15 |
| P2-07 | Lesson Editor: metadata (skills, difficulty, tags, optional lanes) | P2-02 |
| P2-08 | Course Designer: lesson list, reorder, gate rules | P2-07 |
| P2-09 | Course Designer: validation + preview | P2-08 |
| P2-10 | Pack Builder: dependency resolution + validation | P2-09 |
| P2-11 | Pack Builder: export .taalpack | P2-10 |
| P2-12 | MusicXML import | P1-01, P2-02 |
| P2-13 | .taalpack import | P2-11 |
| P2-14 | Content library browser | P1-18, P2-07, P2-13 |
| P2-15 | Print sheet music (PDF export of notation) | P1-10 |
| P2-16 | Help tooltips (Studio complex elements) + About page | P2-01, P1-20 |
| P2-17 | Course runtime in Player: load course, progression, gate enforcement | P2-09, P1-13, P1-21, P1-27 |
| P2-18 | Speed training mode (auto-tempo-ramp on successful loops) | P1-12, P1-14 |

**Exit criteria:**
- Create a lesson from scratch → preview → export as pack → import on another device → practice
- MusicXML import works for standard drum charts (best-effort quality)
- Course with 3+ lessons and gate rules functions end-to-end

---

### Phase 3: Analytics + Polish + Backing Tracks

**Objective:** The product becomes sticky through progress tracking, insights, and richer audio. This completes the v1 product.

**Deliverables:**
- Practice history dashboard
- Performance theme detection (deterministic rules)
- Insights dashboard (trends, time-of-day, tempo ceiling, lane heatmap)
- Learning outcome recommendations (theme-to-outcome mapping)
- Backing track playback (user-provided audio + beatmap sync)
- Backing track volume controls
- Extended starter content (20+ lessons, 2-3 courses)
- Profile export/import (file-based sync between devices)
- Additional instrument layouts (extended kit, e.g., 7-piece with extra cymbals)
- Polish: animations, transitions, error states, empty states
- Update-check notification (app checks GitHub for new release on startup)

**Tasks:**

| ID | Title | Deps |
|----|-------|------|
| P3-01 | Practice attempt persistence and query layer | P1-21 |
| P3-03 | Performance theme detection engine (deterministic rules) | P3-01 |
| P3-04 | Theme-to-learning-outcome mapping config | P3-03 |
| P3-02 | Practice history dashboard screen | P3-01 |
| P3-05 | Insights dashboard: weekly summary + trends | P3-03 |
| P3-06 | Insights dashboard: tempo ceiling chart | P3-03 |
| P3-07 | Insights dashboard: time-of-day effectiveness | P3-01 |
| P3-08 | Insights dashboard: lane heatmap + focus areas | P3-03 |
| P3-09 | Lesson recommendations from themes | P3-03, P3-04, P2-14 |
| P3-10 | Backing track: audio file loading + playback | P1-15 |
| P3-12 | Backing track: sync engine (lesson timeline ↔ audio position) | P3-10 |
| P3-11 | Backing track: beatmap authoring in Studio | P3-12, P2-05 |
| P3-13 | Backing track: volume controls + mute on tempo change | P3-12 |
| P3-23 | Backing track: missing-file detection + relink flow | P3-10, P2-13 |
| P3-14 | Profile export (JSON file with history + settings + device profiles) | P1-16, P1-08, P1-20, P3-01 |
| P3-15 | Profile import (validate + merge/replace) | P3-14 |
| P3-16 | Extended instrument layout: 7-piece kit | P1-19 |
| P3-17 | Extended starter content (10+ additional lessons, 2 courses) | P1-18, P2-08, P2-09, P3-16 |
| P3-20 | Update-check notification on startup | — |
| P3-18 | UI polish pass: animations, transitions, loading states | P3-02, P3-08, P3-13, P2-14 |
| P3-19 | Error states and empty states across all screens | P3-18, P3-15 |
| P3-21 | Windows installer packaging (Inno Setup) | P0-08, P3-19 |
| P3-22 | Android Play Store build + listing | P0-08, P3-19 |

**Exit criteria:**
- Insights dashboard shows meaningful trends after 10+ practice sessions
- Theme detection identifies at least 3 theme categories from real practice data
- Recommendations surface relevant lessons based on detected themes
- Backing track plays in sync with lesson (Play Mode, fixed tempo)
- Profile export → import on a second device preserves history and settings
- Windows `.exe` installer works end-to-end (download → install → launch)
- Android Play Store build passes Google Play review

---

### Phase 4: AI Coach + Marketplace Prep + Multi-Platform

**Objective:** AI-assisted practice planning. Foundation for community marketplace. Additional platforms.

**Deliverables:**
- AI coach integration (local Ollama or cloud API)
- Natural-language coaching summaries
- Personalized practice plan generation
- Marketplace data model and content preparation
- macOS and iPadOS builds
- Community contribution workflow for content

---

### Phase 5+: Marketplace + Keyboard + ML + Community

**Deliverables (future):**
- Full marketplace UI (browse, download, rate)
- Creator publishing flow
- Teacher/classroom mode (virtual classrooms, homework assignment, student progress tracking — inspired by Beatlii's teacher feature)
- Community leaderboards (optional, per-lesson or per-course score rankings)
- Audio-to-lesson ML extraction (beat detection from recordings — see Section 4.2.5)
- Visual node-graph course editor (n8n-style branching paths)
- Keyboard instrument support (new layout, piano-roll view — same repo, different instrument mode)
- BLE MIDI support with latency warnings
- Acoustic kit support (microphone-based detection)
- Stem separation for backing track drum muting (using models like Demucs)
- Multi-language support

---

## 13. Execution Model

Task templates, agent roles, and coding conventions are defined in `docs/coding-model.md` (separate from product requirements).

### 13.1 Canonical Document Ownership

| Document | Owns | Authority |
|----------|------|-----------|
| `docs/prd.md` | Product truth: what we build and why | Final say on scope, features, priorities |
| `docs/adr/` | Decision rationale: why we chose X over Y | Final say on architecture choices |
| `docs/specs/` | Contract details: exact shapes, invariants, rules | Final say on data models, APIs, behavior contracts |
| `plans/` | Task sequence: what we build in what order | Final say on phasing and dependencies |
| `STATUS.md` | Current execution state | Authoritative project checkpoint |
| `CHANGELOG.md` | Change history | Append-only record |
| `docs/coding-model.md` | Agent execution discipline | Task templates, file boundaries |

When documents conflict, ownership determines which is authoritative. Specs override PRD on exact field definitions. PRD overrides specs on product intent.

### 13.2 Document Governance

| Artifact | Mutability | Purpose |
|----------|-----------|---------|
| PRD (`docs/prd.md`) | Edited to reflect current state | "How it works now" |
| ADRs (`docs/adr/`) | Immutable (only status line changes) | "Why we decided this" |
| Specs (`docs/specs/`) | Edited as models evolve | "What the contracts look like" |
| Phase plans (`plans/`) | Updated per phase | "What we're building now" |
| STATUS.md | Updated after each task | "Where we are" |
| CHANGELOG.md | Append-only | "What changed when" |

### 13.3 Contract-Touch Rule

If a task changes any of the following, the relevant spec must be updated in the same changeset:
- Engine API (event types, session lifecycle)
- Content schema (lesson/course/pack structure)
- Device profile structure
- Analytics storage schema

### 13.4 Frozen Interface Rule

When an interface is marked frozen in `STATUS.md`, it must not be changed without:
1. Explicit CR (Change Request) documenting the reason
2. Spec update in the same changeset
3. PRD or ADR update if the change is architectural

### 13.5 Change Requests

When implementation reveals that a PRD decision needs to change:
1. Document the change as a CR in the relevant spec or PRD section
2. If architectural: write an ADR explaining the new decision
3. Update the PRD to reflect current state
4. Update STATUS.md to note the change

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| Lesson | A single unit of practice: tempo, lanes, events, sections, metadata |
| Course | An ordered sequence of lessons with progression gates |
| Pack | A distributable bundle of lessons + courses + supporting data |
| Lane | A single instrument voice in a lesson (e.g., kick, snare, hi-hat) |
| Event | A single expected note in a lane at a specific time position |
| Section | A named time range within a lesson (e.g., "Main Groove", "Fill") |
| Instrument Layout | Definition of available lanes for an instrument family |
| Scoring Profile | Timing window sizes, grade weights, combo rules |
| Device Mapping | Physical MIDI note/CC → semantic lane assignment |
| Practice Attempt | A recorded performance with metrics |
| Player Profile | Local user identity with preferences and history |
| Performance Theme | System-detected pattern in practice data (e.g., "snare consistently late") |
| Learning Outcome | Creator-assigned skill tag on a lesson (e.g., "timing.backbeat") |
| Note Highway | Guitar Hero-style scrolling practice view |
| Hit Grade | Engine-computed timing accuracy: Perfect/Good/Early/Late/Miss |
| Beatmap | Tempo/beat markers for syncing user-provided audio to a lesson |

## Appendix B: Referenced Specifications

| Specification | Path | Contents |
|--------------|------|----------|
| Content Schemas | docs/specs/content-schemas.md | Lesson, Course, Pack, Layout, Scoring Profile |
| Engine API | docs/specs/engine-api.md | Rust engine lifecycle, events, threading |
| MIDI & Device Mapping | docs/specs/midi-mapping.md | Device profiles, hi-hat model, calibration |
| Analytics Model | docs/specs/analytics-model.md | Storage, themes, recommendations |
| Visual Language | docs/specs/visual-language.md | Animation, color tokens, feedback semantics |

## Appendix C: ADR Index

| ADR | Title | Status |
|-----|-------|--------|
| 001 | Platform Architecture: Flutter + Rust | Proposed (pending spike) |
| 002 | Hybrid Time Model | Accepted |
| 003 | Proprietary Format with MusicXML Interchange | Accepted |
| 004 | Local-First SQLite Storage | Accepted |
| 005 | Marketplace-Ready Schemas with Optional Fields | Accepted |
