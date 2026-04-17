# Phase 3: Analytics + Polish + Backing Tracks + Distribution

**Objective:** The product becomes sticky through progress tracking and insights, gains richer audio via backing tracks, and ships as installable builds for Windows and Android. This completes the v1 product.

**Prerequisite:** Phase 2 complete. Creator Studio functional.

---

## Execution Order

Task IDs remain stable references. Execute Phase 3 in the order below unless a blocker, approved CR, or newly discovered contradiction requires a narrower clarification pass.

1. **P3-01** Practice Attempt Query Layer
2. **P3-03** Performance Theme Detection Engine
3. **P3-04** Theme-to-Learning-Outcome Mapping Config
4. **P3-02** Practice History Dashboard Screen
5. **P3-05** Insights Dashboard — Weekly Summary + Trends
6. **P3-06** Insights Dashboard — Tempo Ceiling Chart
7. **P3-07** Insights Dashboard — Time-of-Day Effectiveness
8. **P3-08** Insights Dashboard — Lane Heatmap + Focus Areas
9. **P3-09** Lesson Recommendations from Themes
10. **P3-14** Profile Export
11. **P3-15** Profile Import
12. **P3-16** Extended Instrument Layout — 7-Piece Kit
13. **P3-17** Extended Starter Content
14. **P3-10** Backing Track — Audio File Loading + Playback
15. **P3-12** Backing Track — Sync Engine
16. **P3-13** Backing Track — Volume Controls + Mute on Tempo Change
17. **P3-11** Backing Track — Beatmap Authoring in Studio
18. **P3-23** Backing Track — Missing-File Detection + Relink Flow
19. **P3-20** Update-Check Notification
20. **P3-18** UI Polish Pass
21. **P3-19** Error States and Empty States
22. **P3-21** Windows Installer Packaging
23. **P3-22** Android Play Store Build + Listing

**Execution notes**
- `P3-01`/`P3-03`/`P3-04` come first because the rest of analytics builds on queryable attempt data and theme mapping.
- `P3-02` follows after the query layer so the first dashboard surface can be built before richer insights panels.
- `P3-14`/`P3-15` and `P3-16`/`P3-17` are independent mid-phase slices that can proceed once the analytics foundation is stable.
- The backing-track tranche is intentionally ordered `P3-10 → P3-12 → P3-13 → P3-11 → P3-23` so sync exists before authoring and relink UX.
- Packaging remains at the end: `P3-21` and `P3-22` should not start until polish/error-state work is complete.

---

## Tasks

### P3-01: Practice Attempt Query Layer

**Deps:** P1-21

**Objective:** Query interface over stored practice attempts for analytics computation.

**Outputs:**
- Rust query functions: by player, by lesson, by date range, by course, by time-of-day bucket
- Rolling window queries: last 7 days, last 30 days
- Aggregation helpers: mean, stddev, percentile across attempts
- Lane-level stat aggregation across multiple attempts

**Acceptance criteria:**
- Query returns correct results for all filter combinations
- Performance acceptable for 1000+ stored attempts (< 100ms)

--- 

### P3-02: Practice History Dashboard Screen

**Deps:** P3-01

**Objective:** Show the learner their practice history.

**Outputs:**
- Flutter screen: list of recent attempts with score, lesson name, date
- Filter by lesson, course, date range
- Tap to see attempt detail (same review screen as post-lesson)
- Summary stats: total practice time, total sessions, average score trend

**Acceptance criteria:**
- Dashboard loads within 1 second for typical history size
- Scores match stored attempt data exactly

--- 

### P3-03: Performance Theme Detection Engine

**Deps:** P3-01

**Objective:** Detect patterns in practice data using deterministic rules.

**Outputs:**
- `rust/src/analytics/themes.rs`: theme detection from rolling attempt data
- Themes detected: timing bias (global/per-lane), inconsistency, tempo plateau, endurance drop
- Each theme has: code, severity (0-1), confidence (0-1), evidence (supporting metrics)
- Minimum attempt thresholds per theme category (avoid false positives)
- Results stored in SQLite, recomputed periodically

**Acceptance criteria:**
- Given 10+ attempts with consistent snare-late bias → detects `lane.snare.late` theme
- Given attempts where accuracy drops above 110 BPM → detects `tempo.plateau`
- No themes detected with < 5 attempts (insufficient data)
- Severity and confidence values are deterministic for same input

--- 

### P3-04: Theme-to-Learning-Outcome Mapping Config

**Deps:** P3-03

**Objective:** Configuration file that maps detected themes to recommended learning outcomes.

**Outputs:**
- JSON config file: `{ "lane.snare.late": ["timing.backbeat", "coordination.hihat_snare"], ... }`
- Loaded at startup, updatable without code changes
- Covers all themes from starter taxonomy

**Acceptance criteria:**
- Every detected theme maps to at least one learning outcome
- Mapping is editable as a config file (not hardcoded)

--- 

### P3-05: Insights Dashboard — Weekly Summary + Trends

**Deps:** P3-03

**Objective:** Show weekly practice summary and score/accuracy trends.

**Outputs:**
- Weekly summary card: sessions this week, total practice time, average score
- Trend chart: score or accuracy over time (line chart, configurable window)
- Comparison to previous week (arrow up/down)

**Acceptance criteria:**
- Chart renders correctly with 30+ data points
- Trend direction matches actual data

--- 

### P3-06: Insights Dashboard — Tempo Ceiling Chart

**Deps:** P3-03

**Objective:** Show the learner's effective tempo ceiling by pattern type.

**Outputs:**
- Chart: BPM buckets (60-70, 70-80, ..., 150-160) vs average score
- Clear visualization of where accuracy drops off
- Filtered by lesson tags or categories

**Acceptance criteria:**
- Correctly identifies highest BPM bucket with score ≥ 85
- Updates as new attempts are added

--- 

### P3-07: Insights Dashboard — Time-of-Day Effectiveness

**Deps:** P3-01

**Objective:** Show when practice is most effective.

**Outputs:**
- Chart: time-of-day buckets (morning/afternoon/evening/late) vs average accuracy
- Day-of-week chart: Mon-Sun vs average accuracy
- Sample size shown per bucket (confidence indicator)

**Acceptance criteria:**
- Buckets with < 3 attempts show "insufficient data" rather than misleading averages
- Matches stored local_hour data from attempts

--- 

### P3-08: Insights Dashboard — Lane Heatmap + Focus Areas

**Deps:** P3-03

**Objective:** Show which instruments need the most work and current focus areas.

**Outputs:**
- Lane heatmap: per-lane accuracy/timing stats (color-coded from good to needs-work)
- Focus areas: top 2-3 detected themes with severity, displayed as actionable cards
- Each focus area links to recommended lessons

**Acceptance criteria:**
- Heatmap correctly reflects per-lane stats from recent attempts
- Focus areas match highest-severity detected themes

--- 

### P3-09: Lesson Recommendations from Themes

**Deps:** P3-03, P3-04, P2-14

**Objective:** Suggest lessons based on detected weaknesses.

**Outputs:**
- Recommendation engine: theme → outcomes → matching lessons (by skills metadata)
- Ranking: match score, recency penalty (don't re-recommend just-practiced lessons), difficulty alignment
- Display: "Recommended for you" section on home screen and insights dashboard
- Each recommendation includes brief "why" text

**Acceptance criteria:**
- Recommendations change when themes change
- Recently mastered lessons (score ≥ 92, last 3 attempts) are deprioritized
- Recommendations only appear when sufficient data exists (5+ attempts)

--- 

### P3-10: Backing Track — Audio File Loading + Playback

**Deps:** P1-15

**Objective:** Load and play user-provided audio files.

**Outputs:**
- File picker for MP3/WAV/FLAC
- Audio decoding (via platform or Rust audio library)
- Playback through low-latency audio output
- Volume control (independent from metronome)
- Play/pause/seek aligned with lesson transport

**Acceptance criteria:**
- Supported formats load and play without audible artifacts
- Volume adjustable without audio glitch
- Playback does not affect MIDI input latency

--- 

### P3-11: Backing Track — Beatmap Authoring in Studio

**Deps:** P3-12, P2-05

**Objective:** Allow creators to define the beat alignment for a backing track.

**Outputs:**
- Beatmap editor: set start offset (ms), confirm tempo alignment
- Preview: play audio with metronome overlay to verify sync
- Beatmap stored as part of lesson (tempo_map + audio offset)
- Simple workflow: user taps beat along with audio → system estimates offset

**Acceptance criteria:**
- Beatmap sync is perceptibly accurate (clicks align with audio beats)
- Offset adjustable in fine increments (1ms steps)
- Multiple lessons can reference same audio with different offsets

--- 

### P3-12: Backing Track — Sync Engine

**Deps:** P3-10

**Objective:** Keep audio playback synchronized with lesson timeline.

**Outputs:**
- Sync module: align audio playback position with lesson current time
- Handle drift correction (audio clock vs system clock)
- Behavior on tempo change (Practice Mode): mute audio, continue metronome + lesson at new tempo

**Acceptance criteria:**
- Audio stays in sync for full lesson duration (no perceptible drift over 5 minutes)
- Tempo change mutes audio cleanly (no click/pop)

--- 

### P3-13: Backing Track — Volume Controls + Mute on Tempo Change

**Deps:** P3-12

**Objective:** User controls for backing track audio.

**Outputs:**
- Backing track volume slider in transport bar
- Auto-mute indicator when tempo differs from lesson default
- Manual mute/unmute toggle
- Metronome volume remains independent

**Acceptance criteria:**
- Volume changes are smooth (no stepping artifacts)
- Mute/unmute transition is click-free

--- 

### P3-23: Backing Track — Missing-File Detection + Relink Flow

**Deps:** P3-10, P2-13

**Objective:** Handle the case where a lesson with a beatmap is imported but the referenced audio file is not present on the device.

**Outputs:**
- On lesson load: detect if backing track audio file is missing
- Show clear UI: "Audio file not found — tap to link a local file"
- File picker to select a local audio file as replacement
- Beatmap preserved intact when relinking
- Lesson remains fully playable without backing track (metronome + events still work)

**Acceptance criteria:**
- Import a .taalpack with a beatmap → audio missing → lesson loads and plays without audio
- User links a local file → backing track plays with correct beatmap sync
- No error or crash when audio is missing — graceful degradation

--- 

### P3-14: Profile Export

**Deps:** P1-16, P1-08, P1-20, P3-01

**Objective:** Export a player's profile, history, device profiles, and settings as a portable file.

**Outputs:**
- Export function: produces a `.taalprofile` file (JSON inside ZIP)
- Contains: player profile, all practice attempts, device profiles, preferences
- Privacy note shown before export ("this file contains your practice history")

**Acceptance criteria:**
- Export produces valid file that can be imported
- File size reasonable (< 5MB for 1000 attempts + profiles)

--- 

### P3-15: Profile Import

**Deps:** P3-14

**Objective:** Import a profile on another device.

**Outputs:**
- File picker for `.taalprofile`
- Import options: create new profile / merge into existing / replace existing
- Validation before import (schema version check)
- Conflict resolution for device profiles (different hardware)

**Acceptance criteria:**
- Export from device A → import on device B → history and settings preserved
- Merge mode combines attempt history without duplicates

--- 

### P3-16: Extended Instrument Layout — 7-Piece Kit

**Deps:** P1-19

**Objective:** Add a more complete drum kit layout.

**Outputs:**
- Layout definition: standard 5-piece + extra crash + extra tom + china/splash
- MIDI hints for extended kits (Roland TD-27/50 dual-zone pads)
- Visual drum kit widget adapts to show extra pads

**Acceptance criteria:**
- Layout validates against schema
- Visual kit shows all pads correctly
- Mapping works for extended kits

--- 

### P3-17: Extended Starter Content

**Deps:** P1-18, P2-08, P2-09, P3-16

**Objective:** Expand the bundled lesson library.

**Outputs:**
- 10+ additional lessons covering new styles and techniques
- 2 courses: "Beginner Rock Drumming" (5-6 lessons) and "Intermediate Grooves" (5-6 lessons)
- Courses use gate rules (score ≥ 80 to progress)
- All content tagged with learning outcomes

**Acceptance criteria:**
- All content validates against schema
- Courses playable end-to-end with correct gating
- Content covers diverse styles (rock, funk, blues, at minimum)

--- 

### P3-18: UI Polish Pass

**Deps:** P3-02, P3-08, P3-13, P2-14

**Objective:** Animation, transition, and visual refinement across all screens.

**Outputs:**
- Screen transition animations (consistent, not jarring)
- Loading states for content operations
- Skeleton screens where appropriate
- Consistent spacing, typography, color usage
- Dark theme refinement

**Acceptance criteria:**
- No visual rough edges on primary flows (onboarding, practice, review, library)
- Animations maintain 60fps

--- 

### P3-19: Error States and Empty States

**Deps:** P3-18, P3-15

**Objective:** Handle all error and empty conditions gracefully.

**Outputs:**
- Empty library: "No lessons yet. Import a pack or create your own."
- Empty history: "Start practicing to see your progress here."
- No MIDI device: clear guidance with illustration
- Corrupt lesson file: error with option to delete or report
- Database error: recovery prompt
- Network unavailable (future-proofing): offline indicator

**Acceptance criteria:**
- Every screen has a defined empty state
- No blank screens or cryptic error messages
- Error recovery does not lose user data

--- 

### P3-20: Update-Check Notification

**Deps:** —

**Objective:** Notify users when a new version is available.

**Outputs:**
- On startup, check GitHub Releases API for latest version tag
- If newer than installed: show non-blocking banner ("Update available: v1.1")
- Link to download page
- Dismissable, does not block app usage
- Respects offline (skip check silently if no network)

**Acceptance criteria:**
- Notification appears only when a genuine update exists
- Does not slow app startup
- Works offline (no error, just skips)

--- 

### P3-21: Windows Installer Packaging

**Deps:** P0-08, P3-19

**Objective:** Produce a distributable Windows installer.

**Outputs:**
- Inno Setup script producing `.exe` installer
- Includes: Flutter app bundle, Rust native library, bundled content, metronome samples
- Desktop shortcut creation
- Uninstaller that removes all app data (with confirmation)
- CI integration: GitHub Actions produces installer on tagged release

**Acceptance criteria:**
- Fresh Windows 10/11 machine: download → install → launch → functional
- Uninstall removes app cleanly
- Installer size < 100MB

--- 

### P3-22: Android Play Store Build + Listing

**Deps:** P0-08, P3-19

**Objective:** Produce and publish an Android build on Google Play Store.

**Outputs:**
- AAB build signed via Play App Signing
- Play Store listing: screenshots, description, feature graphic
- APK also available on GitHub Releases for sideloading
- Minimum API level: Android 10 (API 29)
- CI integration: GitHub Actions produces AAB on tagged release

**Acceptance criteria:**
- Passes Google Play Store review
- Installs and runs on at least 2 Android tablet models
- USB MIDI works on installed Play Store build (not just debug)

--- 

## Exit Criteria for Phase 3 (v1 Release)

- [ ] Insights dashboard shows meaningful trends after 10+ practice sessions
- [ ] Theme detection identifies at least 3 theme categories from real practice data
- [ ] Recommendations surface relevant lessons based on detected themes
- [ ] Backing track plays in sync with lesson (Play Mode, fixed tempo)
- [ ] Backing track mutes cleanly on tempo change (Practice Mode)
- [ ] Profile export → import on a second device preserves history and settings
- [ ] Windows `.exe` installer works end-to-end (download → install → launch → practice)
- [ ] Android Play Store build passes review and installs correctly
- [ ] All error/empty states handled gracefully
- [ ] 20+ lessons and 2+ courses bundled
- [ ] No critical bugs in primary flows (onboarding, practice, review, Studio, library)
