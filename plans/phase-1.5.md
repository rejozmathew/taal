# Phase 1.5: UX Remediation

**Objective:** Bring Phase 1 features to the visual and interaction quality the PRD intended. Fix broken features, connect disconnected systems, and make every screen feel polished enough that a user would choose Taal over subscription competitors for the free price alone.

**Authorized by:** CR-009

**Scope:** This phase fixes, connects, and polishes what Phase 1 built. No new product features. Speed training remains in Phase 2 where it belongs.

**Structure:** Two tranches. Tranche A makes the app usable (fix what's broken). Tranche B makes it feel premium (visual spectacle, polish). Tranche A must complete before Tranche B begins.

**Visual references:**
- **Melodics** (desktop): Dark UI with gradient backgrounds, glowing note highway, smooth transitions
- **Beatlii** (mobile/desktop): Clean card-based layout, difficulty indicators, color-coded feedback
- **Drumr** (iOS): Activity rings for daily goals, SnapCursor highlighting
- **taal-legacy** (archived repo): Design tokens, practice controls, MIDI handling, count-in overlay — reference for patterns worth preserving, not a copy target

**Task ordering note:** Task IDs are identifiers, not execution order. Dependencies define sequencing.

---

## Execution Order

Task IDs remain stable identifiers. Execute Phase 1.5 in the order below unless a real blocker, approved CR, or newly discovered contradiction requires a narrower clarification pass.

### Tranche A — execute in this order
1. **P1.5-03** Audio Wiring
2. **P1.5-01** Design System Foundation
3. **P1.5-02** Theme Switching Fix
4. **P1.5-05** MIDI Device Lifecycle
5. **P1.5-04** Onboarding Re-Entry + Profile Management
6. **P1.5-06** Error States + Empty States
7. **P1.5-08** Library UX Overhaul
8. **P1.5-07** Settings Screen Restructure
9. **P1.5-09** Onboarding Flow Redesign

### Tranche B — execute only after Tranche A is complete
**Tranche A complete means P1.5-01 through P1.5-09 are complete.**

10. **P1.5-10** Animation Framework
11. **P1.5-12** Drum Kit Visual Overhaul
12. **P1.5-11** Note Highway Visual Overhaul
13. **P1.5-13** Practice Toolbar Redesign
14. **P1.5-14** Combo + Grade Visual Effects
15. **P1.5-16** Daily Goal Ring + Streak Visual
16. **P1.5-15** Review Screen Polish
17. **P1.5-17** Tap Pad Visual + Interaction Polish
18. **P1.5-18** Global Polish Pass

### Execution notes
- `P1.5-03` is first because audible feedback is a core usability blocker.
- `P1.5-01` precedes most UI work because tokens, typography, and theme foundations must exist before broad screen redesign.
- `P1.5-05` precedes `P1.5-09` because onboarding reconnect and rescan must use the same device lifecycle path as the rest of the app.
- `P1.5-07` follows `P1.5-03`, `P1.5-04`, and `P1.5-05` because Settings must surface the real audio, profile, and device flows rather than placeholder controls.
- `P1.5-09` is intentionally last in Tranche A so onboarding hands off into a usable app shell with working theme, audio, profile management, device rescan, library flow, and empty-state handling.
- `P1.5-12` precedes `P1.5-17` so tap-pad polish inherits the improved drum-kit visual language.
- `P1.5-18` is the final consistency, accessibility, and polish sweep after all prior tasks land.

---


---

## Tranche A: Fix Broken (make it usable)

### P1.5-01: Design System Foundation

**Deps:** None

**Objective:** Create a real design system that replaces the auto-generated Material theme.

**Pre-work:** Before designing tokens, review `taal-legacy/crates/ui/src/theme.rs` for the warm/cool accent pattern, Inter font loading, and surface hierarchy decisions. Also review Melodics and Beatlii for contemporary reference. Extract a "reuse / don't regress" checklist of UX patterns from the legacy app (practice controls layout, settings organization, MIDI device handling, count-in overlay).

**Outputs:**
- `lib/design/tokens.dart` — Color palette, spacing scale (4/8/12/16/24/32/48), border radii, elevation levels
- `lib/design/typography.dart` — Type scale with Inter font family (Regular + Bold, loaded from `assets/fonts/`)
- `lib/design/colors.dart` — Semantic color tokens: primary teal, secondary gold accent, grade colors (perfect green, good light-green, early blue, late amber, miss gray), surface hierarchy
- `lib/design/theme.dart` — Two complete `ThemeData` objects (dark + light) built from tokens, not `fromSeed()`
- Inter font files added to `assets/fonts/`

**Acceptance criteria:**
- Both dark and light ThemeData objects exist and render correctly
- Inter font loads and displays
- No raw `Color(0xFF...)` literals outside `lib/design/`
- Legacy "reuse / don't regress" checklist documented in task output

---

### P1.5-02: Theme Switching Fix

**Deps:** P1.5-01

**Objective:** Make the Light/Dark/System theme selector actually work.

**Outputs:**
- `TaalApp` in main.dart accepts `ThemeMode` and provides both `theme` and `darkTheme`
- Settings dropdown persists selection and applies immediately (no restart)
- Light theme has appropriate contrast — not just "dark with inverted colors"

**Acceptance criteria:**
- Select Light → app switches immediately, all screens readable
- Select Dark → app switches immediately
- Select System → follows OS preference
- Persists across app restart
- Verified at 1024px and 1920px

---

### P1.5-03: Audio Wiring

**Deps:** None (independent of design system)

**Objective:** Connect the existing WASAPI audio engine to all places that should produce sound. The synthesis code exists — it just needs to be called.

**Outputs:**
1. **Metronome during practice:** Replace the `break;` handler in `practice_runtime.dart` for `metronomeClick` events. Schedule clicks via `PlatformMetronomeAudioOutput.scheduleClicks()`.
2. **Tap pad sounds:** When a virtual pad is tapped, schedule a drum hit with the appropriate lane_id and velocity to the audio output.
3. **Haptic feedback on tap pads:** Add `HapticFeedback.mediumImpact()` on each tap.
4. **MIDI kit hit sounds:** Off by default (avoids doubled sound from kit module + app). Add a toggle in Settings → Audio: "Play drum sounds on kit hits" (default: off).
5. **Audio output device:** Simplify to "System Default" only. Remove the current fake text field. Device enumeration is future work.

**Acceptance criteria:**
- Practice mode: metronome clicks are audible and in time with the lesson
- Tap pads: each pad produces the correct drum sound + haptic feedback
- Kit-connected MIDI hits: no app sound by default (no doubling)
- Listen-first still works (verify, was already wired)
- Volume respects Settings slider

---

### P1.5-04: Onboarding Re-Entry + Profile Management

**Deps:** None (independent — fixes critical broken flow)

**Objective:** Allow users to return to onboarding and manage profiles properly.

**Outputs:**
- Settings → Profile section: "Re-run setup wizard" button → returns to onboarding step 1
- Settings → Profile section: "Delete profile" with confirmation dialog (code exists but is buried — surface it with a clear red destructive button)
- Settings → Profile section: "Create new profile" button
- Profile switcher on home screen: current profile name/avatar with dropdown to switch

**Acceptance criteria:**
- User can access "Re-run setup" from Settings
- User can delete their profile with confirmation
- User can create a new profile without reinstalling
- Profile switch from home screen works and reloads data

---

### P1.5-05: MIDI Device Lifecycle

**Deps:** None (independent)

**Objective:** Allow MIDI device connection/reconnection after app launch.

**Outputs:**
- Settings → MIDI section: "Scan for devices" button that re-enumerates MIDI devices
- Practice screen: connection status indicator (green = connected, gray = tap pads mode)
- Hot-plug SnackBar: "Roland TD-27 connected" / "MIDI device disconnected"
- Device disconnect during session: pause and show reconnection prompt
- Practice screen: refresh icon in status area to trigger re-enumeration

**Acceptance criteria:**
- Open app without kit → connect kit → tap "Scan for devices" → kit selectable
- Disconnect during practice → session pauses with prompt
- Reconnect → session resumes
- Connection status visible during practice

---

### P1.5-06: Error States + Empty States

**Deps:** P1.5-01

**Objective:** Handle every "nothing to show" and "something went wrong" case.

**Outputs:**
- Library empty: "No lessons match your filters." + reset button
- Practice no lesson: "Choose a lesson from the Library." + Library button
- No MIDI device: "No drum kit connected. Tap pads are active." + Scan button
- Database error: "Something went wrong. Try restarting." + retry
- Empty history: "No practice sessions yet. Start your first lesson!"

**Acceptance criteria:**
- Every screen has a non-blank state when there's no data
- Every error produces a readable message (no crashes, no blank screens)
- Empty states include a constructive action button

---

### P1.5-07: Settings Screen Restructure

**Deps:** P1.5-01, P1.5-02, P1.5-03, P1.5-04, P1.5-05

**Objective:** Transform settings from a scroll dump into organized, scannable sections.

**Outputs:**
- Collapsible/clearly separated sections: Profile, MIDI, Audio, Display, Practice, About
- Profile: name, avatar, re-run setup, delete profile, create new profile
- MIDI: device selector, "Scan for devices" button, calibrate, manual latency slider with preview, velocity curve
- Audio: metronome volume slider (with preview click on change), click sound preset, "Play drum sounds on kit hits" toggle. Output device: "System Default" (no fake enumeration)
- Display: view preference, theme selector (working), reduce motion, high contrast
- Practice: auto-pause toggle + timeout, save practice attempts, daily goal, count-in bars
- About: version, credits, license, GitHub link

**Acceptance criteria:**
- User can find any setting within 5 seconds
- Sections are visually separated
- All settings persist and take effect immediately
- Theme switching works
- MIDI rescan works
- About shows correct version

---

### P1.5-08: Library UX Overhaul

**Deps:** P1.5-01

**Objective:** Transform the library from "one lesson, one button" into a browsable content surface.

**Outputs:**
- Lesson cards: title, difficulty badge (Beginner/Intermediate), BPM, duration, lane icons
- Grouping by difficulty or style
- Search bar: text search by title
- Filter: by difficulty
- Lesson detail: description, skills, best score, Practice/Play buttons
- Cards have hover/press feedback

**Acceptance criteria:**
- All 13 starter lessons visible with difficulty badges
- Search by title works
- Filter by difficulty works
- Tap card → detail → Practice navigates to practice with lesson loaded

---

### P1.5-09: Onboarding Flow Redesign

**Deps:** P1.5-01, P1.5-03, P1.5-05

**Objective:** Make first-run clear, inviting, and functional. The onboarding must transition INTO the app, not embed a practice widget inside the wizard.

**Outputs:**
- Dot-style step indicator (not "Step 3 of 6" text)
- Smooth slide transition between steps
- Welcome: icon/illustration + value prop
- Profile: name entry with initials-in-circle avatar
- Experience: three clear cards (Beginner/Intermediate/Teacher)
- Connect kit: USB illustration, device list, "Skip — use tap pads" prominent, and the same rescan/re-enumeration path introduced by P1.5-05
- Calibrate: only if kit connected, visual metronome indicator
- **Final step transitions to the real app shell** (home screen with "Start your first lesson" CTA). Does NOT embed a PracticeModeScreen inside the wizard card.
- No overlapping elements

**Acceptance criteria:**
- Complete onboarding in < 90 seconds
- Each step is visually distinct with smooth transitions
- No overlapping UI elements
- First practice after onboarding produces sound
- Final step hands off to the real home screen, not an embedded practice widget

---

## Tranche B: Make Premium (visual overhaul + polish)

Tranche A must be complete before starting Tranche B.

### P1.5-10: Animation Framework

**Deps:** Tranche A complete

**Objective:** Establish shared animation patterns.

**Outputs:**
- Page transitions: shared slide + fade between major sections
- Button press: subtle scale feedback
- Card hover/press: elevation + border highlight
- Section reveal: staggered fade-in for list items
- Shared constants in `lib/design/motion.dart`

**Acceptance criteria:**
- Navigation between Home/Practice/Library/Settings has visible transition
- Buttons have tactile press feedback
- Cards respond to hover (desktop) and press (mobile)
- 60fps, no jank

---

### P1.5-11: Note Highway Visual Overhaul

**Deps:** Tranche A complete, P1.5-10

**Objective:** Transform the highway from rectangles to a game-like experience.

**Outputs:**
- Note shape: rounded pills with lane-colored gradient
- Approaching glow: notes brighten near the hit line
- Hit line: pulsing glow line, pulses on beat
- Grade feedback: burst/ripple on hit (color = grade). Perfect = expanding ring. Miss = dim flash + shake.
- Lane backgrounds: subtle top-to-bottom gradient
- Past-window notes: fade out over ~300ms
- Smooth scrolling feel

**Acceptance criteria:**
- Side-by-side with current: visually obviously better
- Hit → burst animation visible
- Miss → visual indication
- Notes gain glow approaching hit line
- 60fps with 20+ notes visible

---

### P1.5-12: Drum Kit Visual Overhaul

**Deps:** Tranche A complete, P1.5-01

**Objective:** Replace geometric primitives with a proper overhead kit visualization.

**Outputs:**
- Overhead 2D kit with recognizable shapes (kick = large circle bottom, snare center-left, hi-hat with pedal indicator, graduated toms, cymbals visually distinct from drums)
- Hit flash: expanding ring + color fill matching grade, smooth fade-out
- Labels positioned outside pad shapes
- Scales for different window sizes

**Acceptance criteria:**
- Kit looks like a drum kit, not rectangles
- Each instrument visually distinguishable without reading labels
- Hit flash is satisfying
- Works at both small (embedded) and large (Kit view tab) sizes

---

### P1.5-13: Practice Toolbar Redesign

**Deps:** Tranche A complete, P1.5-10

**Objective:** Reorganize practice controls from one undifferentiated row into grouped sections.

**Outputs:**
- Transport (left): Play/Pause (large, prominent), Stop
- Mode (center-left): Listen toggle, View selector (Highway/Notation/Kit segmented)
- Practice tools (center-right): Metronome toggle + BPM slider, Loop toggle + section
- Status (right): Combo counter (animated), Kit status indicator
- Groups visually separated
- Count-in: add to Practice Mode (currently Play Mode only). Configurable bars (0-4).
- Responsive: groups stack on narrow windows

**Acceptance criteria:**
- Play/Pause identifiable without reading labels
- Controls logically grouped
- BPM adjustable without entering Settings
- Metronome toggle visible and obvious
- Count-in audible before Practice Mode starts

---

### P1.5-14: Combo + Grade Visual Effects

**Deps:** Tranche A complete, P1.5-10

**Objective:** Make scoring feedback visceral and rewarding.

**Outputs:**
- Combo counter: scales up on increment, shakes on reset, color intensifies at milestones
- Grade flash: brief screen-edge color wash on Perfect/Miss (subtle)
- Encouragement: "Nice!" / "On fire!" at milestones (8, 16, 32). Animated slide-in, auto-dismiss.
- Streak milestone: brief celebration on 7/30/100 day streaks

**Acceptance criteria:**
- 5 Perfects in a row → combo visibly animates
- Miss after combo → visible reset with shake
- Combo 8 → "Nice!" appears and auto-dismisses
- Effects complement, not compete with the highway

---

### P1.5-15: Review Screen Polish

**Deps:** Tranche A complete, P1.5-10, P1.5-14

**Objective:** Make post-lesson review informative and satisfying.

**Outputs:**
- Score animation: counter from 0 → final score with color/scale
- Timing histogram: bar chart with grade colors
- Lane breakdown: per-lane accuracy bars
- Best stat highlighted with glow/badge
- Improvement suggestions as styled cards with icons
- Button hierarchy: Retry = secondary, Next Lesson = primary

**Acceptance criteria:**
- Score animates on entry
- Histogram readable with grade colors
- Lane breakdown shows which instruments need work

---

### P1.5-16: Daily Goal Ring + Streak Visual

**Deps:** Tranche A complete, P1.5-01

**Objective:** Replace LinearProgressIndicator with a visual ring.

**Outputs:**
- Circular progress arc (CustomPainter) showing minutes / goal. Fills teal → gold.
- Streak counter: flame icon + day count
- Weekly summary: 7-day grid (practiced vs skipped)

**Acceptance criteria:**
- Ring fills proportionally on home screen
- Streak counter visible with appropriate visual

---

### P1.5-17: Tap Pad Visual + Interaction Polish

**Deps:** Tranche A complete, P1.5-03, P1.5-12

**Objective:** Make tap pads feel like an instrument.

**Outputs:**
- Layout matches overhead kit visual (P1.5-12 style)
- On tap: pad highlights with grade color + drum sound (P1.5-03) + haptic
- Touch targets large enough for tablet finger drumming
- "Connect your kit for the best experience" banner (dismissible)

**Acceptance criteria:**
- Tap → hear correct sound + see feedback + feel haptic
- Layout intuitive (kick bottom, hi-hat left)

---

### P1.5-18: Global Polish Pass

**Deps:** All previous P1.5 tasks

**Objective:** Final consistency sweep.

**Outputs:**
- Tooltips: minimum 20 across the app on non-obvious controls
- SnackBar feedback: settings saved, profile switched, calibration complete, device connected/disconnected
- Accessibility: semantic labels on all interactive elements
- Keyboard shortcuts (desktop): Space = play/pause, Escape = stop, M = metronome, L = loop, +/- = tempo
- Responsive: verified at 1024px, 1366px, 1920px
- Window title: shows current screen/lesson

**Acceptance criteria:**
- 20+ tooltips
- All state-changing actions produce feedback
- Tab through app with keyboard
- Shortcuts work during practice
- Correct at all three widths

---

## Exit Criteria for Phase 1.5

### Tranche A (Usable)
- [ ] App produces drum sounds when tap pads are tapped
- [ ] Metronome clicks audible during practice
- [ ] Light theme works and looks intentional
- [ ] User can return to onboarding from Settings
- [ ] MIDI device can be connected after app launch via rescan
- [ ] Settings organized into clear sections
- [ ] Library shows all 13 lessons with difficulty badges and is searchable
- [ ] Every screen handles empty/error states
- [ ] Onboarding transitions into real app shell (no embedded practice widget)

### Tranche B (Premium)
- [ ] Note highway has glow effects and grade animations
- [ ] Drum kit looks like a drum kit
- [ ] Practice toolbar controls are grouped
- [ ] Combo counter animates
- [ ] Count-in works in Practice Mode
- [ ] Review screen has animated score and timing histogram
- [ ] Daily goal shows as a ring
- [ ] All major actions produce user feedback
- [ ] Keyboard shortcuts work on desktop
- [ ] A drummer would say "this looks professional" — not "this looks like a prototype"
