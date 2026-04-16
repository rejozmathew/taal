# Phase 2: Creator Studio + Content System

**Objective:** Users can create their own lessons and courses. Content can be shared as packs.

**Prerequisite:** Phase 1 complete. Practice Player functional.

---

## Tasks

### P2-01: Lesson Editor — Grid Canvas and Lane Rendering

**Deps:** P1-01

**Objective:** Build the core editing surface: horizontal timeline with vertical instrument lanes.

**Outputs:**
- Flutter custom painter: horizontal time axis (bars/beats), vertical lane axis
- Grid resolution selector (1/4, 1/8, 1/16, triplets)
- Snap-to-grid enabled by default
- Lane labels from active instrument layout
- Scroll and zoom on timeline

**Acceptance criteria:**
- Grid renders correctly for 4/4 time at various resolutions
- Lanes match the standard 5-piece layout
- Scroll/zoom is smooth (60fps)

---

### P2-02: Lesson Editor — Event CRUD

**Deps:** P2-01

**Objective:** Create, select, move, and delete note events on the grid.

**Outputs:**
- Click/tap to place event at grid position
- Click/tap to select existing event
- Drag event to move in time or across lanes
- Delete key / long-press to remove event
- Visual feedback: selected events highlighted, ghost preview during drag

**Acceptance criteria:**
- Events snap to grid by default
- Events placed at correct musical position (verified by loading lesson in Player)
- Multi-event selection does not cause performance issues (up to 500 events)

---

### P2-03: Lesson Editor — Copy/Paste, Multi-Select, Undo/Redo

**Deps:** P2-02

**Objective:** Productivity editing operations.

**Outputs:**
- Box select (drag to select region)
- Shift-click to add to selection
- Copy/paste selection (same position offset or to cursor)
- Duplicate selection
- Undo/redo stack (minimum 50 levels)

**Acceptance criteria:**
- Copy a 4-bar pattern → paste at bar 5 → events appear correctly
- Undo reverses last N operations accurately
- Redo restores undone operations

---

### P2-04: Lesson Editor — Velocity and Articulation Editing

**Deps:** P2-02

**Objective:** Fine-tune event properties.

**Outputs:**
- Velocity slider/input for selected event(s)
- Articulation dropdown (normal, accent, ghost, rim, open, closed — filtered by lane type)
- Batch velocity adjust (scale or set for multi-selection)
- Visual indication of velocity (opacity or size) and articulation (icon/shape) on grid

**Acceptance criteria:**
- Velocity changes reflected in Player preview (louder/softer hit sounds)
- Articulation changes affect hi-hat behavior correctly

---

### P2-05: Lesson Editor — Sections, Grid Resolution, Tempo

**Deps:** P2-02

**Objective:** Define lesson structure and timing.

**Outputs:**
- Section creation: drag on timeline ruler to create named section
- Section list panel: rename, delete, toggle loopable
- Grid resolution dropdown with instant re-render
- Tempo input (BPM) with instant update
- Time signature selector (4/4, 3/4, 6/8)

**Acceptance criteria:**
- Sections appear as colored overlays on timeline
- Sections cannot have negative or zero length
- Tempo change updates grid spacing immediately
- Section boundaries snap to bar lines

---

### P2-06: Lesson Editor — Preview

**Deps:** P2-05, P1-04, P1-15

**Objective:** Play the lesson-in-progress using the Rust engine with metronome.

**Outputs:**
- Play/pause in editor context
- Playhead cursor on timeline
- Section looping during preview
- Metronome plays during preview
- Synthesized drum sounds for each event (basic GM samples)
- Non-scoring (no attempt stored)

**Acceptance criteria:**
- Preview playback matches what Player would render
- Tempo, sections, and events all correctly previewed
- Can edit while preview is paused without data loss

---

### P2-07: Lesson Editor — Metadata

**Deps:** P2-02

**Objective:** Attach learning outcomes, difficulty, and descriptive metadata.

**Outputs:**
- Metadata panel: title, description, difficulty selector, tags input
- Learning outcomes picker: searchable list from starter taxonomy + custom entry
- Prerequisites field (optional)
- Practice defaults: count-in bars, metronome on/off, start tempo, tempo floor
- Scoring profile selector (default or custom)
- Optional lanes picker: mark specific lanes as optional for compatibility (e.g., cowbell, splash — defaults to all required). Picker only shows lanes that have events in the lesson (prevents marking unused lanes).

**Acceptance criteria:**
- Metadata saved with lesson
- Skills/tags searchable and multi-select
- Custom skills created inline and persisted

---

### P2-08: Course Designer — Lesson List with Reorder and Gate Rules

**Deps:** P2-07

**Objective:** Build courses as ordered lesson sequences with progression gates.

**Outputs:**
- Course creation screen: title, description, difficulty, instrument family
- Add lessons from library (search/browse)
- Drag-and-drop reorder
- Per-lesson gate configuration: minimum score, max retries, practice-before-retry toggle
- Course-level default gate (applied to all lessons unless overridden)
- Visual progress flow: lessons shown as connected cards with gate indicators

**Acceptance criteria:**
- Reorder persists correctly
- Gate rules validated (score 0-100, retries ≥ 0)
- Course loads in Player and enforces gates correctly

---

### P2-09: Course Designer — Validation and Preview

**Deps:** P2-08

**Objective:** Validate course integrity and simulate learner experience.

**Outputs:**
- Validation checks: all referenced lessons exist, gate thresholds achievable, no empty courses
- Warning/error display with actionable messages
- Preview simulation: select performance level → see which lessons unlock
- Validation runs automatically on save and on pack build

**Acceptance criteria:**
- Missing lesson reference produces clear error
- Impossible gate (score > 100) produces error
- Preview simulation accurately reflects gate logic

---

### P2-10: Pack Builder — Dependency Resolution and Validation

**Deps:** P2-09

**Objective:** Automatically resolve all content dependencies and validate before export.

**Outputs:**
- Select lessons/courses for inclusion
- Auto-include required instrument layouts and scoring profiles
- Run strict validation: schema, referential integrity, instrument consistency
- Display validation results: errors (block) and warnings (allow)
- Dependency tree visualization (what's included and why)

**Acceptance criteria:**
- Missing layout dependency auto-included
- Dangling reference (course → deleted lesson) produces blocking error
- Instrument family mismatch (drum course referencing keyboard lesson) produces blocking error

---

### P2-11: Pack Builder — Export .taalpack

**Deps:** P2-10

**Objective:** Produce a validated, portable distribution bundle.

**Outputs:**
- Generate `pack.json` manifest
- Assemble deterministic directory structure inside ZIP
- Compute content hash (SHA-256)
- Assign version/revision
- Write `.taalpack` file to user-chosen location

**Pack structure:**
```
my-pack.taalpack (ZIP)
├── pack.json
├── lessons/
│   ├── lesson-1.json
│   └── lesson-2.json
├── courses/
│   └── course-1.json
├── layouts/
│   └── std-5pc-v1.json
├── scoring/
│   └── score-standard-v1.json
└── assets/
    └── artwork/ (optional)
```

**Acceptance criteria:**
- Exported pack validates when re-imported
- Content hash matches on re-export of identical content
- Pack can be imported on a different device running Taal

---

### P2-12: MusicXML Import

**Deps:** P1-01, P2-02

**Objective:** Import standard MusicXML drum charts as draft lessons for editing.

**Outputs:**
- File picker for `.musicxml` / `.xml` files
- Parser: extract note events, map to semantic lanes using instrument/notehead heuristics
- Tempo extraction from MusicXML
- Output: draft Lesson in workspace (requires manual review/cleanup)
- Warning on ambiguous mappings

**Acceptance criteria:**
- Standard MusicXML drum chart imports with correct kick/snare/hat mapping
- Ambiguous or unusual notation produces warnings, not crashes
- Imported lesson opens in Lesson Editor for cleanup
- This is best-effort: complex or non-standard files may import partially

---

### P2-13: .taalpack Import

**Deps:** P2-11

**Objective:** Import packs created by other users or on other devices.

**Outputs:**
- File picker for `.taalpack` files
- Validate: schema version, integrity hash, content references
- Install: add lessons/courses/layouts to local library
- Conflict handling: prompt if lesson IDs already exist (replace/skip/rename)

**Acceptance criteria:**
- Valid pack imports successfully and content appears in library
- Invalid pack shows clear error and does not partially install
- Duplicate content handled gracefully

---

### P2-14: Content Library Browser

**Deps:** P1-18, P2-07, P2-13

**Objective:** Browse all available lessons, courses, and packs.

**Outputs:**
- Library screen: tabs for Lessons / Courses / Packs
- Search by title, tags, difficulty
- Filter by instrument family
- Sort by date, difficulty, name
- Tap to open (lesson → Player or Editor; course → Player or Designer)
- Installed pack indicator

**Acceptance criteria:**
- All content (bundled + imported + user-created) searchable
- Filter and sort work correctly
- Navigation to Player/Editor from library is seamless

---

### P2-15: Print Sheet Music (PDF Export)

**Deps:** P1-10

**Objective:** Generate a printable PDF of a lesson's notation for offline practice.

**Outputs:**
- Render notation view to print-friendly layout (A4/Letter page size)
- Include: title, tempo, time signature, section labels, bar numbers
- Export as PDF to user-chosen location
- Accessible from Player (viewing) and Studio (editing)

**Acceptance criteria:**
- PDF is legible and correctly represents the lesson's notation
- Practice-sheet quality (not engraving-grade — this is not MuseScore)
- Works for lessons up to 100 bars

---

### P2-16: Help Tooltips and About Page

**Deps:** P2-01, P1-20

**Objective:** Add contextual help and product information.

**Outputs:**
- Tooltips on complex Studio UI elements (grid resolution, articulation selectors, gate rules, scoring profile fields)
- Tooltips: hover on desktop, long-press on tablet
- About page accessible from Settings: app name, version, developer credits, license, links
- About page follows platform convention (Settings → About on Android, Help → About on Windows)

**Acceptance criteria:**
- At least 10 Studio elements have contextual tooltips
- About page shows correct version from build metadata
- License text accessible

---

### P2-17: Course Runtime and Progression in Player

**Deps:** P2-09, P1-13, P1-21, P1-27

**Objective:** Enable courses to be played in the Practice Player with progression tracking and gate enforcement, including layout compatibility checks.

**Outputs:**
- Load a course in the Player: show course context (title, progress, current lesson)
- Track current lesson position within the course per player profile
- After a scored attempt: evaluate gate rules (min score, max retries)
- On pass: unlock next lesson, show "Next Lesson" CTA
- On fail: show "Retry" or "Practice more" options
- Persist course progress per profile in SQLite
- Locked lessons visually distinct (dimmed, lock icon) in course view
- **Layout compatibility in Course Gate Mode:** block lesson start if any required lanes are missing from the player's kit. Allow if only optional lanes are missing. Show clear message: "This lesson requires [lane names] — connect a kit with those pads or remap your device profile."
- Handle edge cases: all lessons complete, course reset option

**Acceptance criteria:**
- Play through a 3-lesson course with gates: pass first → unlocks second → pass second → unlocks third
- Fail a gate: next lesson stays locked, retry works
- Progress persists across app restarts
- Different player profiles have independent course progress
- Course lesson with missing required lane → blocked with explanation
- Course lesson with missing optional lane → allowed, scoring adjusted

---

### P2-18: Speed Training Mode

**Deps:** P1-12, P1-14

**Objective:** Auto-tempo-ramp practice mode for building speed.

**Outputs:**
- Sub-mode within Practice: user selects "Speed Training"
- Configure: start BPM, increment per successful loop (default: 5 BPM), success threshold (default: score ≥ 80)
- On successful loop pass: auto-increase BPM by increment
- On failed loop pass: maintain current tempo (or decrease by increment — configurable)
- Visual indicator: current BPM, highest BPM reached, progress toward ceiling
- Session ends when user stops or reaches a configurable ceiling BPM

**Acceptance criteria:**
- Start at 70 BPM → pass 3 loops → BPM is now 85 (3 × 5 increment)
- Fail a loop → BPM stays at current value
- Highest BPM reached is recorded and shown in review

---

## Exit Criteria for Phase 2

- [ ] Create a lesson from scratch in Studio with events, sections, metadata
- [ ] Preview lesson in Studio matches Player rendering
- [ ] Create a course with 3+ lessons and gate rules
- [ ] Export as .taalpack → import on another device → practice
- [ ] MusicXML import produces usable draft lesson (standard charts)
- [ ] Library browser shows all content with search/filter
- [ ] Print sheet music produces legible PDF
- [ ] Undo/redo works correctly in Lesson Editor
- [ ] Studio elements have contextual tooltips
- [ ] About page shows version and credits
- [ ] Course runtime: play through a gated course end-to-end
- [ ] Speed training mode: auto-tempo-ramp works correctly
