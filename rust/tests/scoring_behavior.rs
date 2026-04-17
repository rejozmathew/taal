use std::collections::HashMap;

use taal_core::content::{
    ComboConfig, GradeWeights, PracticeMode, ScoringProfile, ScoringRules, TimingWindows,
};
use taal_core::runtime::session::Grade;
use taal_core::scoring::{grade_delta_ms, ScoringEngine};
use uuid::Uuid;

#[test]
fn grade_matches_window_boundaries() {
    let windows = TimingWindows {
        perfect_ms: 20.0,
        good_ms: 45.0,
        outer_ms: 120.0,
    };

    assert_eq!(grade_delta_ms(0.0, &windows), Grade::Perfect);
    assert_eq!(grade_delta_ms(20.0, &windows), Grade::Perfect);
    assert_eq!(grade_delta_ms(20.001, &windows), Grade::Good);
    assert_eq!(grade_delta_ms(-45.0, &windows), Grade::Good);
    assert_eq!(grade_delta_ms(-45.001, &windows), Grade::Early);
    assert_eq!(grade_delta_ms(45.001, &windows), Grade::Late);
    assert_eq!(grade_delta_ms(-120.0, &windows), Grade::Early);
    assert_eq!(grade_delta_ms(120.0, &windows), Grade::Late);
    assert_eq!(grade_delta_ms(120.001, &windows), Grade::Miss);
}

#[test]
fn score_formula_is_normalized_to_zero_to_one_hundred() {
    let mut scoring = ScoringEngine::new(&profile(20.0, 45.0, 120.0, &[8]), lanes(&[("kick", 2)]));

    scoring.record_hit("kick", Grade::Perfect, 0.0);
    scoring.record_miss("kick");

    let summary = scoring.summary(Uuid::nil(), PracticeMode::Practice, 120.0, 1000);
    assert_close(summary.score_total, 50.0);
    assert_close(summary.accuracy_pct, 50.0);
    assert_close(summary.hit_rate_pct, 50.0);

    let mut boosted = ScoringEngine::new(
        &profile_with_weights(
            TimingWindows {
                perfect_ms: 20.0,
                good_ms: 45.0,
                outer_ms: 120.0,
            },
            GradeWeights {
                perfect: 2.0,
                good: 1.0,
                early: 0.5,
                late: 0.5,
                miss: 0.0,
            },
            &[8],
        ),
        lanes(&[("kick", 1)]),
    );
    boosted.record_hit("kick", Grade::Perfect, 0.0);

    assert_close(boosted.score_running(), 100.0);
}

#[test]
fn combo_milestones_emit_encouragement_for_configured_thresholds() {
    let mut scoring = ScoringEngine::new(&profile(20.0, 45.0, 120.0, &[2]), lanes(&[("kick", 3)]));

    let first = scoring.record_hit("kick", Grade::Perfect, 0.0);
    assert_eq!(first.combo, 1);
    assert_eq!(first.streak, 1);
    assert!(first.milestone.is_none());

    let early = scoring.record_hit("kick", Grade::Early, -60.0);
    assert_eq!(early.combo, 2);
    assert_eq!(early.streak, 1);
    assert!(early.milestone.is_none());

    let second_tier_hit = scoring.record_hit("kick", Grade::Good, 12.0);
    assert_eq!(second_tier_hit.combo, 3);
    assert_eq!(second_tier_hit.streak, 2);
    let milestone = second_tier_hit.milestone.expect("milestone should trigger");
    assert_eq!(milestone.combo, 2);
    assert_eq!(milestone.message_id, "combo-2");
    assert_eq!(milestone.text, "Keep it steady");
}

#[test]
fn different_profiles_grade_same_delta_differently() {
    let tight = profile(10.0, 20.0, 100.0, &[8]);
    let loose = profile(30.0, 45.0, 120.0, &[8]);

    assert_eq!(grade_delta_ms(25.0, &tight.timing_windows_ms), Grade::Late);
    assert_eq!(
        grade_delta_ms(25.0, &loose.timing_windows_ms),
        Grade::Perfect
    );
}

fn profile(perfect_ms: f32, good_ms: f32, outer_ms: f32, milestones: &[u32]) -> ScoringProfile {
    profile_with_weights(
        TimingWindows {
            perfect_ms,
            good_ms,
            outer_ms,
        },
        GradeWeights {
            perfect: 1.0,
            good: 0.75,
            early: 0.5,
            late: 0.5,
            miss: 0.0,
        },
        milestones,
    )
}

fn profile_with_weights(
    timing_windows_ms: TimingWindows,
    grading: GradeWeights,
    milestones: &[u32],
) -> ScoringProfile {
    ScoringProfile {
        id: "test-scoring".to_owned(),
        schema_version: "1.0".to_owned(),
        timing_windows_ms,
        grading,
        combo: ComboConfig {
            encouragement_milestones: milestones.to_vec(),
        },
        rules: ScoringRules {},
    }
}

fn lanes(entries: &[(&str, u32)]) -> HashMap<String, u32> {
    entries
        .iter()
        .map(|(lane_id, count)| ((*lane_id).to_owned(), *count))
        .collect()
}

fn assert_close(actual: f32, expected: f32) {
    assert!(
        (actual - expected).abs() < 0.001,
        "expected {expected}, got {actual}"
    );
}
