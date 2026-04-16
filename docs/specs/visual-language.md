# Visual Language Specification

**Companion to:** docs/prd.md Sections 4.1.5, 6
**Status:** Partial contract — grade model, color tokens, combo rules, and responsive layout are frozen. Animation timing details may be refined during implementation.

---

## Overview

This document defines the visual feedback contract between the Rust engine and the Flutter UI: timing states, color tokens, animation semantics, combo/encouragement system, and accessibility rules. Studio preview and Practice Player must use identical visual semantics.

### C.1 Timing State Definitions

The Rust engine emits exactly one grade per expected event. The UI never computes timing — it only renders what the engine says.

**Canonical grade enum (authoritative — must match engine-api.md and analytics-model.md):**

| Grade | Value | Condition |
|-------|-------|-----------|
| Perfect | 0 | Within tight window (~20ms), delta ≈ 0 |
| Good | 1 | Within medium window (~45ms) |
| Early | 2 | Before window, delta < 0 |
| Late | 3 | After window, delta > 0 |
| Miss | 4 | No hit registered within any window |

This is a single enum with five states. Timing direction (early/late) and timing quality (perfect/good) are both encoded in the grade, not as separate dimensions. This keeps the engine→UI contract simple: one grade per event, one color per grade, one animation per grade.

Note: the scoring profile defines the window sizes. The engine applies them. The grade enum itself is fixed.

### C.2 Color Semantic Tokens

Defined as named tokens, not hardcoded hex values. Actual colors chosen during UI implementation.

| Token | Meaning | Suggested Direction |
|-------|---------|-------------------|
| `color.hit.perfect` | Spot-on timing | Green/Teal family |
| `color.hit.good` | Slight deviation | Lighter green |
| `color.hit.early` | Ahead of beat | Blue family |
| `color.hit.late` | Behind beat | Amber/Orange family |
| `color.hit.miss` | Missed note | Muted gray |
| `color.neutral.expected` | Upcoming expected note | Subdued neutral |
| `color.combo.active` | Combo streak active | Warm accent |

Rules:
- No pure red/green contrast (color-blind safety)
- Early and Late must be distinct hues, not just brightness difference
- Miss must be quiet, not alarming
- All colors dark-mode optimized

### C.3 Micro-Feedback Animations (Per Hit)

**On expected note (pre-animation):**
- Subtle neutral pulse on the visual instrument / note highway
- Sets anticipation; very subtle

**On actual hit (state-dependent):**

| State | Animation |
|-------|-----------|
| Perfect | Tight pulse, quick glow expansion, settles cleanly. ~120ms |
| Good | Pulse + softer glow. ~140ms |
| Early | Pulse appears before beat marker, slight forward motion. Blue. |
| Late | Pulse appears after beat marker, slight trailing echo. Amber. |
| Miss | Expected pulse fades to hollow outline / dim ripple. |

**On timeline (both note-highway and notation):**
- Early: hit marker appears left of beat line
- Perfect: centered on beat line
- Late: hit marker appears right of beat line

This directional offset builds rhythmic intuition visually.

### C.4 Combo and Encouragement System

**Combo rules (canonical — must match analytics-model.md and engine-api.md):**
- Increment on Perfect, Good, Early, Late
- Reset on Miss
- Early/Late maintain combo count but do NOT advance encouragement tier
- Only Perfect and Good hits advance the encouragement tier counter
- This means: combo can be 20 (mixed grades) but encouragement milestone requires 8+ Perfect/Good hits within that combo

**Visual treatment:**
- Small combo counter near play area
- Subtle scale-up on milestones
- Never blocks the play area

**Encouragement messages:**
- Triggered at combo milestones (8, 16, 32) and sustained accuracy thresholds
- Short, calm, musical: "Nice groove", "Locked in", "Solid timing"
- Never more than one on screen at a time
- Suppressed during dense passages
- Suppressed in Focus Mode

### C.5 Mode-Specific Feedback Rules

| Mode | Visual Feedback | Encouragement | Combo |
|------|----------------|---------------|-------|
| Practice | Full | On by default | Visible |
| Play | Reduced hints | Off | Visible |
| Course Gate | Minimal during run | On completion only | Hidden |

### C.6 Post-Run Macro Feedback

After a lesson/section run:
- Score animates in (ease-out)
- Best stat highlighted first (positive reinforcement)
- 1-2 specific improvement suggestions (derived from attempt stats)
- Timing histogram (early/late distribution chart)
- Lane heatmap (which drums were weakest)

### C.7 Performance Constraints

- MIDI → animation start: ≤ 16-20ms perceived (within frame budget)
- Animation scheduling must not block MIDI input processing
- Dropped frames must not affect scoring (engine is authoritative)
- All animations cancellable if frame budget exceeded

### C.8 Accessibility

- **Reduce motion:** Shorter animations, no glows, no bounce
- **High contrast:** Stronger outlines, thicker markers
- **Color-blind mode:** Alternative palette ensuring hue distinctness
- **Focus mode:** Minimal visual chrome, no encouragement text, combo hidden
- **Minimum touch targets:** 48dp (Material guidelines)

### C.9 Visual Instrument Displays

**Drum kit (v1):**
- 2D overhead/angled view of a standard drum kit
- Each pad lights up on hit with timing-state color
- Used in: MIDI mapping, calibration, settings, optional practice overlay
- Must match the active instrument layout (5-piece vs extended kit)

**Keyboard (future):**
- Piano keyboard view (horizontal)
- Keys highlight on hit
- Same color semantics as drum kit

The visual instrument adapts to `instrument.family` from the active lesson/layout. Settings and calibration screens always show the instrument visual for the currently selected instrument type.

### C.10 Practice View Equivalence

**The note-highway view and notation view are alternate renderings of the same lesson timeline with identical scoring semantics.** A Perfect hit in note-highway is a Perfect hit in notation. The engine does not know or care which view is active. Both views receive the same `EngineEvent` stream and render it according to their visual paradigm.

This means:
- Scores are comparable regardless of view choice
- Users can switch views mid-lesson without affecting scoring
- Analytics do not need to distinguish which view was used

### C.11 Responsive Layout

| Form Factor | Primary Layout | Notes |
|-------------|----------------|-------|
| Desktop (Windows/macOS) | Landscape, multi-panel | Sidebar + main canvas + inspector |
| Tablet landscape | Landscape, single-focus | Practice: full-screen note highway. Studio: simplified panels. |
| Tablet portrait | Supported but secondary | Reduced UI density. Notation view may be more natural here. |
| Phone | Not a primary target | Minimum viable display. May restrict to Player-only (no Studio). |

Minimum supported screen width: 600dp (standard Android tablet minimum).
Touch targets: 48dp minimum everywhere.
