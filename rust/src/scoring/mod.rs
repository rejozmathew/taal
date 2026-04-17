use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::content::{GradeWeights, PracticeMode, ScoringProfile, TimingWindows};
use crate::runtime::session::Grade;

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct AttemptSummary {
    pub lesson_id: Uuid,
    pub mode: PracticeMode,
    pub bpm: f32,
    pub duration_ms: u64,
    pub score_total: f32,
    pub accuracy_pct: f32,
    pub hit_rate_pct: f32,
    pub perfect_pct: f32,
    pub early_pct: f32,
    pub late_pct: f32,
    pub miss_pct: f32,
    pub max_streak: u32,
    pub mean_delta_ms: f32,
    pub std_delta_ms: f32,
    pub median_delta_ms: Option<f32>,
    pub p90_abs_delta_ms: Option<f32>,
    pub lane_stats: HashMap<String, LaneStats>,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct LaneStats {
    pub hit_rate_pct: f32,
    pub miss_pct: f32,
    pub mean_delta_ms: f32,
    pub std_delta_ms: f32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ScoringUpdate {
    pub combo: u32,
    pub streak: u32,
    pub score_running: f32,
    pub milestone: Option<MilestoneUpdate>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MilestoneUpdate {
    pub combo: u32,
    pub message_id: String,
    pub text: String,
}

#[derive(Debug, Clone)]
pub struct ScoringEngine {
    profile: ScoringProfile,
    total_expected: u32,
    score_accumulated: f32,
    combo: u32,
    encouragement_streak: u32,
    max_combo: u32,
    grade_counts: GradeCounts,
    deltas_ms: Vec<f32>,
    lane_accumulators: HashMap<String, LaneAccumulator>,
}

#[derive(Debug, Default, Clone)]
struct GradeCounts {
    perfect: u32,
    good: u32,
    early: u32,
    late: u32,
    miss: u32,
}

#[derive(Debug, Clone)]
struct LaneAccumulator {
    expected: u32,
    hits: u32,
    misses: u32,
    deltas_ms: Vec<f32>,
}

impl ScoringEngine {
    pub fn new(profile: &ScoringProfile, lane_expected_counts: HashMap<String, u32>) -> Self {
        let total_expected = lane_expected_counts.values().sum();
        let lane_accumulators = lane_expected_counts
            .into_iter()
            .map(|(lane_id, expected)| {
                (
                    lane_id,
                    LaneAccumulator {
                        expected,
                        hits: 0,
                        misses: 0,
                        deltas_ms: Vec::new(),
                    },
                )
            })
            .collect();

        Self {
            profile: profile.clone(),
            total_expected,
            score_accumulated: 0.0,
            combo: 0,
            encouragement_streak: 0,
            max_combo: 0,
            grade_counts: GradeCounts::default(),
            deltas_ms: Vec::new(),
            lane_accumulators,
        }
    }

    pub fn record_hit(&mut self, lane_id: &str, grade: Grade, delta_ms: f32) -> ScoringUpdate {
        self.record_grade_count(grade);
        self.score_accumulated += grade_weight(grade, &self.profile.grading);
        self.record_combo(grade);

        if let Some(lane) = self.lane_accumulators.get_mut(lane_id) {
            lane.hits += 1;
            lane.deltas_ms.push(delta_ms);
        }
        self.deltas_ms.push(delta_ms);

        self.update_for_grade(grade)
    }

    pub fn record_miss(&mut self, lane_id: &str) -> ScoringUpdate {
        self.record_grade_count(Grade::Miss);
        self.score_accumulated += grade_weight(Grade::Miss, &self.profile.grading);
        self.combo = 0;
        self.encouragement_streak = 0;

        if let Some(lane) = self.lane_accumulators.get_mut(lane_id) {
            lane.misses += 1;
        }

        ScoringUpdate {
            combo: self.combo,
            streak: self.encouragement_streak,
            score_running: self.score_running(),
            milestone: None,
        }
    }

    pub fn score_running(&self) -> f32 {
        if self.total_expected == 0 {
            return 0.0;
        }

        ((self.score_accumulated / self.total_expected as f32) * 100.0).clamp(0.0, 100.0)
    }

    pub fn summary(
        &self,
        lesson_id: Uuid,
        mode: PracticeMode,
        bpm: f32,
        duration_ms: u64,
    ) -> AttemptSummary {
        let total = self.total_expected as f32;
        let total_hits = self.grade_counts.perfect
            + self.grade_counts.good
            + self.grade_counts.early
            + self.grade_counts.late;
        let score_total = self.score_running();
        let (mean_delta_ms, std_delta_ms) = mean_std(&self.deltas_ms);

        AttemptSummary {
            lesson_id,
            mode,
            bpm,
            duration_ms,
            score_total,
            accuracy_pct: score_total,
            hit_rate_pct: pct(total_hits as f32, total),
            perfect_pct: pct(self.grade_counts.perfect as f32, total),
            early_pct: pct(self.grade_counts.early as f32, total),
            late_pct: pct(self.grade_counts.late as f32, total),
            miss_pct: pct(self.grade_counts.miss as f32, total),
            max_streak: self.max_combo,
            mean_delta_ms,
            std_delta_ms,
            median_delta_ms: median(&self.deltas_ms),
            p90_abs_delta_ms: p90_abs(&self.deltas_ms),
            lane_stats: self
                .lane_accumulators
                .iter()
                .map(|(lane_id, lane)| (lane_id.clone(), lane.to_stats()))
                .collect(),
        }
    }

    fn record_grade_count(&mut self, grade: Grade) {
        match grade {
            Grade::Perfect => self.grade_counts.perfect += 1,
            Grade::Good => self.grade_counts.good += 1,
            Grade::Early => self.grade_counts.early += 1,
            Grade::Late => self.grade_counts.late += 1,
            Grade::Miss => self.grade_counts.miss += 1,
        }
    }

    fn record_combo(&mut self, grade: Grade) {
        match grade {
            Grade::Miss => {
                self.combo = 0;
                self.encouragement_streak = 0;
            }
            Grade::Perfect | Grade::Good | Grade::Early | Grade::Late => {
                self.combo += 1;
                self.max_combo = self.max_combo.max(self.combo);
                if matches!(grade, Grade::Perfect | Grade::Good) {
                    self.encouragement_streak += 1;
                }
            }
        }
    }

    fn update_for_grade(&self, grade: Grade) -> ScoringUpdate {
        ScoringUpdate {
            combo: self.combo,
            streak: self.encouragement_streak,
            score_running: self.score_running(),
            milestone: milestone_for_grade(
                grade,
                self.encouragement_streak,
                &self.profile.combo.encouragement_milestones,
            ),
        }
    }
}

impl LaneAccumulator {
    fn to_stats(&self) -> LaneStats {
        let total = self.expected as f32;
        let (mean_delta_ms, std_delta_ms) = mean_std(&self.deltas_ms);

        LaneStats {
            hit_rate_pct: pct(self.hits as f32, total),
            miss_pct: pct(self.misses as f32, total),
            mean_delta_ms,
            std_delta_ms,
        }
    }
}

pub fn grade_delta_ms(delta_ms: f32, windows: &TimingWindows) -> Grade {
    let abs_delta = delta_ms.abs();
    if abs_delta <= windows.perfect_ms {
        Grade::Perfect
    } else if abs_delta <= windows.good_ms {
        Grade::Good
    } else if abs_delta <= windows.outer_ms && delta_ms < 0.0 {
        Grade::Early
    } else if abs_delta <= windows.outer_ms {
        Grade::Late
    } else {
        Grade::Miss
    }
}

pub fn grade_weight(grade: Grade, weights: &GradeWeights) -> f32 {
    match grade {
        Grade::Perfect => weights.perfect,
        Grade::Good => weights.good,
        Grade::Early => weights.early,
        Grade::Late => weights.late,
        Grade::Miss => weights.miss,
    }
}

fn milestone_for_grade(
    grade: Grade,
    encouragement_streak: u32,
    milestones: &[u32],
) -> Option<MilestoneUpdate> {
    if !matches!(grade, Grade::Perfect | Grade::Good) || !milestones.contains(&encouragement_streak)
    {
        return None;
    }

    Some(MilestoneUpdate {
        combo: encouragement_streak,
        message_id: format!("combo-{encouragement_streak}"),
        text: encouragement_text(encouragement_streak).to_owned(),
    })
}

fn encouragement_text(milestone: u32) -> &'static str {
    match milestone {
        8 => "Nice groove",
        16 => "Locked in",
        32 => "Solid timing",
        _ => "Keep it steady",
    }
}

fn pct(numerator: f32, denominator: f32) -> f32 {
    if denominator <= 0.0 {
        0.0
    } else {
        (numerator / denominator) * 100.0
    }
}

fn mean_std(values: &[f32]) -> (f32, f32) {
    if values.is_empty() {
        return (0.0, 0.0);
    }

    let mean = values.iter().sum::<f32>() / values.len() as f32;
    let variance = values
        .iter()
        .map(|value| {
            let diff = value - mean;
            diff * diff
        })
        .sum::<f32>()
        / values.len() as f32;

    (mean, variance.sqrt())
}

fn median(values: &[f32]) -> Option<f32> {
    if values.is_empty() {
        return None;
    }

    let mut sorted = values.to_vec();
    sorted.sort_by(|left, right| left.total_cmp(right));
    let mid = sorted.len() / 2;
    if sorted.len().is_multiple_of(2) {
        Some((sorted[mid - 1] + sorted[mid]) / 2.0)
    } else {
        Some(sorted[mid])
    }
}

fn p90_abs(values: &[f32]) -> Option<f32> {
    if values.is_empty() {
        return None;
    }

    let mut sorted = values.iter().map(|value| value.abs()).collect::<Vec<_>>();
    sorted.sort_by(|left, right| left.total_cmp(right));
    let rank = ((sorted.len() as f32) * 0.9).ceil() as usize;
    Some(sorted[rank.saturating_sub(1)])
}
