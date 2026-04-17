# Analytics Model Specification

**Companion to:** docs/prd.md Sections 4.3, 10, 11
**Status:** Contract — storage schema and theme taxonomy are stable. Detection thresholds are TBD (marked explicitly).

---

## 1. Practice Attempt Storage

One row per scored run of a lesson or section. This is the primary fact table for all analytics.

```rust
pub struct PracticeAttempt {
    pub id: Uuid,
    pub player_id: Uuid,

    // Content context
    pub lesson_id: Uuid,
    pub course_id: Option<Uuid>,
    pub course_node_id: Option<String>,
    pub section_id: Option<String>,       // If A-B loop on specific section

    // Session context
    pub mode: PracticeMode,               // Practice | Play | CourseGate
    pub bpm: f32,
    pub time_sig_num: u8,
    pub time_sig_den: u8,
    pub duration_ms: u64,
    pub device_profile_id: Option<Uuid>,
    pub instrument_family: String,        // "drums"

    // Snapshot fields (copied at time of attempt, stable for analytics)
    pub lesson_title: String,
    pub lesson_difficulty: Option<String>,
    pub lesson_tags: Vec<String>,
    pub lesson_skills: Vec<String>,

    // Time context (for time-of-day analytics)
    pub started_at_utc: DateTime,
    pub local_hour: u8,                   // 0-23
    pub local_dow: u8,                    // 0=Sun, 6=Sat

    // Outcome metrics
    pub score_total: f32,                 // 0-100
    pub accuracy_pct: f32,               // 0-100
    pub hit_rate_pct: f32,               // 0-100
    pub perfect_pct: f32,
    pub early_pct: f32,
    pub late_pct: f32,
    pub miss_pct: f32,
    pub max_streak: u32,

    // Timing stats (ms; negative = early)
    pub mean_delta_ms: f32,
    pub std_delta_ms: f32,
    pub median_delta_ms: Option<f32>,
    pub p90_abs_delta_ms: Option<f32>,

    // Per-lane summary
    pub lane_stats: HashMap<String, LaneStats>,
}

pub struct LaneStats {
    pub hit_rate_pct: f32,
    pub miss_pct: f32,
    pub mean_delta_ms: f32,
    pub std_delta_ms: f32,
}

pub struct PracticeAttemptContext {
    pub player_id: Uuid,

    // Content context not produced by AttemptSummary
    pub course_id: Option<Uuid>,
    pub course_node_id: Option<String>,
    pub section_id: Option<String>,

    // Session context not produced by AttemptSummary
    pub time_sig_num: u8,
    pub time_sig_den: u8,
    pub device_profile_id: Option<Uuid>,
    pub instrument_family: String,

    // Snapshot fields copied at time of attempt
    pub lesson_title: String,
    pub lesson_difficulty: Option<String>,
    pub lesson_tags: Vec<String>,
    pub lesson_skills: Vec<String>,

    // Wall-clock context for history and analytics
    pub started_at_utc: DateTime,
    pub local_hour: u8,
    pub local_dow: u8,
}
```

**Storage:** SQLite table. `lane_stats` stored as JSON column.

**Write timing:** Written by a Rust storage API immediately after a successful `session_stop()`, not inside the session lifecycle call. `session_stop()` remains the source of `AttemptSummary`; `PracticeAttemptContext` supplies the player, course/section, device, lesson snapshot, and wall-clock context needed to complete the `PracticeAttempt` row.

```rust
fn record_practice_attempt(
    summary: AttemptSummary,
    context: PracticeAttemptContext,
) -> Result<PracticeAttempt, StorageError>
```

The storage API generates `PracticeAttempt.id` for new local attempts, copies outcome metrics from `AttemptSummary`, copies context fields from `PracticeAttemptContext`, and writes the SQLite row. It may be exposed to Flutter through `flutter_rust_bridge` like the existing profile and device-profile storage APIs. Play Mode must call it after a successful stop; Practice Mode calls it only when the user's setting allows storing practice attempts.

The Practice Mode storage setting is `ProfileSettings.record_practice_mode_attempts` from `engine-api.md` P1-20 settings persistence. Its default is `true`. Play Mode, CourseGate, and future gated assessment modes always record completed attempts regardless of this preference; the preference only controls optional Practice Mode attempt rows.

`session_stop()` must not perform SQLite I/O and must not accept persistence context. This keeps timing/session lifecycle behavior separate from post-session storage.

**Indexes:** `(player_id, started_at_utc)`, `(player_id, lesson_id)`, `(player_id, local_hour)`.

**Retention:** All attempts retained indefinitely by default. User can delete individual attempts, all history for a lesson, or all history entirely.

### Raw Hit Retention (v1 decision)

**v1: raw per-hit events are NOT stored by default.** Attempt-level aggregates provide sufficient signal for all v1 analytics features.

**Future option:** An optional diagnostic mode may retain per-hit data for the last N attempts (configurable, default 5). This enables future replay, AI coaching deep analysis, and debugging. The schema reserves this capability but v1 does not implement it:

```rust
// Future — not implemented in v1
pub struct HitLog {
    pub attempt_id: Uuid,
    pub events: Vec<HitLogEntry>,       // Ordered by timestamp
}
pub struct HitLogEntry {
    pub expected_id: String,
    pub lane_id: String,
    pub grade: Grade,
    pub delta_ms: f32,
    pub velocity: u8,
    pub timestamp_ms: i64,
}
```

---

## 2. Performance Themes (System Taxonomy)

Themes are patterns detected from practice data. They are system-internal constructs, never displayed to users directly (the UI shows human-readable summaries derived from themes).

### Theme Structure

```rust
pub struct PerformanceTheme {
    pub theme_id: Uuid,
    pub player_id: Uuid,

    pub theme_code: String,              // e.g., "timing.late.global"
    pub severity: f32,                   // 0.0 - 1.0 (impact magnitude)
    pub confidence: f32,                 // 0.0 - 1.0 (data sufficiency)

    pub evidence: ThemeEvidence,         // Supporting metrics
    pub computed_window_days: u16,       // 7 or 30
    pub computed_at: DateTime,
}

pub struct ThemeEvidence {
    pub attempt_count: u32,              // How many attempts contributed
    pub key_metric: f32,                 // The primary metric that triggered detection
    pub metric_unit: String,             // "ms", "pct", "bpm"
    pub description: String,            // "Mean snare delta: +22ms over 18 attempts"
}
```

**Severity:** Measures impact magnitude. Higher = worse problem.
- `0.0-0.3`: mild (noticeable but not impacting playing quality)
- `0.3-0.6`: moderate (affecting timing accuracy)
- `0.6-1.0`: significant (consistent problem area)

**Confidence:** Measures data sufficiency. Higher = more reliable.
- Based on attempt count: `confidence = clamp(ln(1 + N) / ln(1 + 20), 0, 1)` where N = attempt count
- Approaches 1.0 as N approaches 20 relevant attempts
- Themes with confidence < 0.3 are not surfaced to the user

### Theme Taxonomy

| Code | Category | Trigger | Severity Formula |
|------|----------|---------|-----------------|
| `timing.early.global` | Timing | mean_delta < -threshold | `clamp(abs(mean_delta) / 40, 0, 1)` |
| `timing.late.global` | Timing | mean_delta > +threshold | `clamp(abs(mean_delta) / 40, 0, 1)` |
| `timing.inconsistent.global` | Timing | std_delta > threshold | `clamp((std - 25) / 40, 0, 1)` |
| `lane.<id>.early` | Lane | lane mean_delta < -threshold | `clamp(abs(mean) / 50, 0, 1)` |
| `lane.<id>.late` | Lane | lane mean_delta > +threshold | `clamp(abs(mean) / 50, 0, 1)` |
| `lane.<id>.inconsistent` | Lane | lane std_delta > threshold | `clamp((std - 30) / 50, 0, 1)` |
| `accuracy.low.global` | Accuracy | accuracy_pct < threshold | `clamp((80 - acc) / 30, 0, 1)` |
| `misses.high.global` | Accuracy | miss_pct > threshold | `clamp((miss - 10) / 20, 0, 1)` |
| `tempo.plateau` | Tempo | accuracy drops in higher BPM buckets | `clamp(drop_points / 25, 0, 1)` |
| `endurance.drop_late` | Endurance | performance worse in late-session attempts | Based on score difference |
| `habits.best_time.<bucket>` | Habits | one time-of-day bucket significantly better | `clamp(diff / 15, 0, 1)` |

**Detection thresholds (TBD — to be tuned during Phase 3 implementation):**

| Parameter | Placeholder Value | Notes |
|-----------|------------------|-------|
| Global timing bias trigger | ±12ms mean delta | May need adjustment based on real user data |
| Lane timing bias trigger | ±15ms lane mean delta | Per-lane, requires ≥5 attempts with that lane |
| Inconsistency trigger | 35ms std delta | Global |
| Lane inconsistency trigger | 40ms lane std delta | Per-lane |
| Accuracy low trigger | < 80% | May vary by difficulty level later |
| Miss rate high trigger | > 10% | |
| Minimum attempts for global themes | 5 | |
| Minimum attempts for lane themes | 5 (with that lane active) | |
| Tempo plateau detection | ≥3 attempts per BPM bucket, ≥10 point score drop | |
| Time-of-day significance | ≥5 attempts in bucket, ≥4 point accuracy difference | |

---

## 3. Learning Outcome Taxonomy (Creator-Facing)

These are tags that creators attach to lessons. They are separate from performance themes.

### Starter Taxonomy

| Category | Outcomes |
|----------|---------|
| Timing | `timing.onbeat`, `timing.backbeat`, `timing.consistency`, `subdivision.8ths`, `subdivision.16ths`, `subdivision.triplets` |
| Feel | `feel.swing`, `feel.shuffle` |
| Coordination | `independence.kick_snare`, `independence.hihat_snare`, `independence.kick_hihat`, `independence.4limb_basic` |
| Groove | `groove.rock_basic`, `groove.funk_basic`, `groove.blues_shuffle`, `groove.jazz_swing_basic` |
| Technique | `rudiments.single_stroke`, `rudiments.double_stroke`, `rudiments.paradiddle`, `rudiments.flam`, `stick_control.basic`, `foot_control.basic` |
| Dynamics | `dynamics.accents`, `dynamics.ghost_notes`, `hihat.open_close_control` |
| Fills | `fills.basic`, `fills.16ths_basic`, `transitions.crash_on_1` |
| Endurance | `tempo.building`, `endurance.basic` |

Creators can add custom outcomes (prefixed `custom.`). Built-in outcomes are highlighted in the taxonomy picker.

---

## 4. Theme-to-Outcome Mapping

A JSON configuration file that maps detected themes to recommended learning outcomes. This is the bridge between analytics and recommendations.

```json
{
  "lane.snare.late": ["timing.backbeat", "timing.consistency", "independence.hihat_snare"],
  "timing.inconsistent.global": ["timing.consistency", "subdivision.8ths", "subdivision.16ths"],
  "tempo.plateau": ["tempo.building", "timing.consistency", "stick_control.basic"],
  "lane.hihat.inconsistent": ["subdivision.8ths", "independence.hihat_snare"],
  "accuracy.low.global": ["timing.onbeat", "subdivision.8ths", "stick_control.basic"],
  "endurance.drop_late": ["endurance.basic", "tempo.building"]
}
```

This file is loaded at startup and can be updated without code changes.

---

## 5. Recommendation Ranking

When themes are detected, the system recommends lessons that match the associated learning outcomes.

### Ranking Inputs
- Theme severity × confidence (weighted importance)
- Lesson skill tag overlap with target outcomes
- Lesson focus_lanes matching theme lane (if lane-specific)
- Lesson difficulty alignment with player's current level

### Ranking Adjustments
- **Recency penalty:** Lessons practiced in the last 3 days are deprioritized (weight × 0.5)
- **Mastery deprioritization:** Lessons with score ≥ 92 on last 3 attempts are strongly deprioritized (weight × 0.1)
- **Course context boost:** Lessons in the player's active course are slightly boosted (weight × 1.2)
- **Minimum evidence:** Recommendations only appear when ≥5 attempts exist and at least one theme has confidence ≥ 0.3

### Output
Top 5 recommendations, each with:
- Lesson reference (id, title)
- Reason text: "Recommended because you tend to hit snare late (+22ms avg)"
- Relevance score (internal, for ordering)

---

## 6. Insights Dashboard Data Sources

| Dashboard Section | Data Source | Computation |
|-------------------|------------|-------------|
| Weekly summary | PracticeAttempt (last 7 days) | Count, sum duration, mean score |
| Score/accuracy trend | PracticeAttempt (configurable window) | Time-series of score/accuracy |
| Tempo ceiling | PracticeAttempt bucketed by BPM | Mean score per 10-BPM bucket |
| Time-of-day | PracticeAttempt grouped by local_hour bucket | Mean accuracy per bucket |
| Lane heatmap | PracticeAttempt.lane_stats (rolling 30 days) | Mean timing stats per lane |
| Focus areas | PerformanceTheme (top 3 by severity × confidence) | Computed themes |
| Recommendations | Recommendation ranking output | Theme → outcome → lesson matching |

---

## 7. Export/Import Semantics

When a player profile is exported:
- All `PracticeAttempt` records are included
- All `PerformanceTheme` records are **not** included (they are derived data, recomputed on import)
- Device profiles are included (but calibration offset may not be valid on new hardware — app shows warning)

When imported:
- Attempts are inserted with original timestamps and IDs
- Duplicate detection by attempt ID (skip if already exists)
- Themes are recomputed from the merged attempt set
- Device profiles imported but marked "needs recalibration" if hardware differs

---

## 8. Combo Behavior (Canonical — must match engine-api.md and visual-language.md)

| Hit Grade | Combo Effect |
|-----------|-------------|
| Perfect | Increment |
| Good | Increment |
| Early | Increment (does not advance encouragement tier) |
| Late | Increment (does not advance encouragement tier) |
| Miss | **Reset to 0** |

**Encouragement tiers:** Messages triggered at combo milestones 8, 16, 32. Only Perfect and Good hits advance the tier counter. Early/Late maintain the combo number but do not trigger milestone messages.

This means: you can build a combo of 20 with a mix of Perfect/Good/Early/Late, but if only 6 of those were Perfect/Good, you haven't reached the 8-combo encouragement yet.
