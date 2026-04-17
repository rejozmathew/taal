use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

use taal_core::content::PracticeMode;
use taal_core::scoring::{AttemptSummary, LaneStats};
use taal_core::storage::practice_attempts::{
    PracticeAttemptContext, PracticeAttemptQuery, PracticeAttemptStorageError, PracticeAttemptStore,
};
use taal_core::storage::profiles::{CreateProfileRequest, ExperienceLevel, LocalProfileStore};
use uuid::Uuid;

const LESSON_A: &str = "550e8400-e29b-41d4-a716-446655440101";
const LESSON_B: &str = "550e8400-e29b-41d4-a716-446655440102";
const COURSE_A: &str = "550e8400-e29b-41d4-a716-446655440201";
const COURSE_B: &str = "550e8400-e29b-41d4-a716-446655440202";

#[test]
fn recorded_attempt_survives_reopen_and_copies_summary_context() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = PracticeAttemptStore::open(&db_path).unwrap();
    let summary = summary(LESSON_A, PracticeMode::Play, 92.5);
    let context = context(player_id, Some(COURSE_A), "2026-04-17T14:00:00Z");

    let saved = store
        .record_practice_attempt(summary.clone(), context.clone())
        .unwrap();

    assert_ne!(saved.id, Uuid::nil());
    assert_eq!(saved.player_id, player_id);
    assert_eq!(saved.lesson_id, summary.lesson_id);
    assert_eq!(saved.course_id, context.course_id);
    assert_eq!(saved.course_node_id.as_deref(), Some("lesson-1"));
    assert_eq!(saved.section_id.as_deref(), Some("verse-a"));
    assert_eq!(saved.mode, PracticeMode::Play);
    assert_eq!(saved.score_total, 92.5);
    assert_eq!(saved.lesson_title, "Eight Beat Check");
    assert_eq!(saved.lesson_tags, vec!["rock", "timing"]);
    assert_eq!(saved.lane_stats["snare"].hit_rate_pct, 100.0);

    let reopened = PracticeAttemptStore::open(&db_path).unwrap();
    let attempts = reopened
        .list_attempts(PracticeAttemptQuery {
            player_id,
            lesson_id: None,
            course_id: None,
            started_at_utc_from: None,
            started_at_utc_to: None,
        })
        .unwrap();
    assert_eq!(attempts, vec![saved]);

    cleanup(db_path);
}

#[test]
fn queries_filter_by_player_lesson_date_and_course() {
    let db_path = test_db_path();
    let first_player = create_player(&db_path, "Rejo");
    let second_player = create_player(&db_path, "Anya");
    let store = PracticeAttemptStore::open(&db_path).unwrap();

    let first = store
        .record_practice_attempt(
            summary(LESSON_A, PracticeMode::Play, 95.0),
            context(first_player, Some(COURSE_A), "2026-04-17T10:00:00Z"),
        )
        .unwrap();
    let second = store
        .record_practice_attempt(
            summary(LESSON_B, PracticeMode::Practice, 81.0),
            context(first_player, Some(COURSE_B), "2026-04-18T10:00:00Z"),
        )
        .unwrap();
    store
        .record_practice_attempt(
            summary(LESSON_A, PracticeMode::Play, 75.0),
            context(second_player, Some(COURSE_A), "2026-04-17T10:00:00Z"),
        )
        .unwrap();

    let by_lesson = store
        .list_attempts(PracticeAttemptQuery {
            player_id: first_player,
            lesson_id: Some(uuid(LESSON_A)),
            course_id: None,
            started_at_utc_from: None,
            started_at_utc_to: None,
        })
        .unwrap();
    assert_eq!(by_lesson, vec![first.clone()]);

    let by_course = store
        .list_attempts(PracticeAttemptQuery {
            player_id: first_player,
            lesson_id: None,
            course_id: Some(uuid(COURSE_B)),
            started_at_utc_from: None,
            started_at_utc_to: None,
        })
        .unwrap();
    assert_eq!(by_course, vec![second.clone()]);

    let by_date = store
        .list_attempts(PracticeAttemptQuery {
            player_id: first_player,
            lesson_id: None,
            course_id: None,
            started_at_utc_from: Some("2026-04-18T00:00:00Z".to_owned()),
            started_at_utc_to: Some("2026-04-18T23:59:59Z".to_owned()),
        })
        .unwrap();
    assert_eq!(by_date, vec![second]);

    cleanup(db_path);
}

#[test]
fn practice_attempts_are_owned_by_player_profile() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let profile_store = LocalProfileStore::open(&db_path).unwrap();
    let store = PracticeAttemptStore::open(&db_path).unwrap();

    store
        .record_practice_attempt(
            summary(LESSON_A, PracticeMode::Play, 88.0),
            context(player_id, None, "2026-04-17T10:00:00Z"),
        )
        .unwrap();
    assert_eq!(
        store
            .list_attempts(PracticeAttemptQuery {
                player_id,
                lesson_id: None,
                course_id: None,
                started_at_utc_from: None,
                started_at_utc_to: None,
            })
            .unwrap()
            .len(),
        1
    );

    profile_store.delete_profile(player_id).unwrap();

    let conn = rusqlite::Connection::open(&db_path).unwrap();
    let count: i64 = conn
        .query_row("SELECT COUNT(*) FROM practice_attempts", [], |row| {
            row.get(0)
        })
        .unwrap();
    assert_eq!(count, 0);
    drop(conn);

    cleanup(db_path);
}

#[test]
fn invalid_context_and_unknown_player_are_rejected() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = PracticeAttemptStore::open(&db_path).unwrap();
    let mut invalid_context = context(player_id, None, "2026-04-17T10:00:00Z");
    invalid_context.local_hour = 24;

    let error = store
        .record_practice_attempt(summary(LESSON_A, PracticeMode::Play, 88.0), invalid_context)
        .unwrap_err();
    assert!(matches!(
        error,
        PracticeAttemptStorageError::InvalidContext {
            field: "local_hour",
            ..
        }
    ));

    let error = store
        .record_practice_attempt(
            summary(LESSON_A, PracticeMode::Play, 88.0),
            context(Uuid::new_v4(), None, "2026-04-17T10:00:00Z"),
        )
        .unwrap_err();
    assert!(matches!(
        error,
        PracticeAttemptStorageError::PlayerNotFound(_)
    ));

    cleanup(db_path);
}

fn create_player(db_path: &PathBuf, name: &str) -> Uuid {
    let store = LocalProfileStore::open(db_path).unwrap();
    let state = store
        .create_profile(CreateProfileRequest {
            name: name.to_owned(),
            avatar: None,
            experience_level: ExperienceLevel::Beginner,
        })
        .unwrap();
    state.active_profile_id.unwrap()
}

fn summary(lesson_id: &str, mode: PracticeMode, score_total: f32) -> AttemptSummary {
    let mut lane_stats = HashMap::new();
    lane_stats.insert(
        "snare".to_owned(),
        LaneStats {
            hit_rate_pct: 100.0,
            miss_pct: 0.0,
            mean_delta_ms: -2.0,
            std_delta_ms: 6.5,
        },
    );
    lane_stats.insert(
        "kick".to_owned(),
        LaneStats {
            hit_rate_pct: 85.0,
            miss_pct: 15.0,
            mean_delta_ms: 4.0,
            std_delta_ms: 9.0,
        },
    );

    AttemptSummary {
        lesson_id: uuid(lesson_id),
        mode,
        bpm: 120.0,
        duration_ms: 64_000,
        score_total,
        accuracy_pct: score_total,
        hit_rate_pct: 93.0,
        perfect_pct: 60.0,
        early_pct: 15.0,
        late_pct: 10.0,
        miss_pct: 15.0,
        max_streak: 32,
        mean_delta_ms: 1.5,
        std_delta_ms: 8.0,
        median_delta_ms: Some(0.5),
        p90_abs_delta_ms: Some(18.0),
        lane_stats,
    }
}

fn context(
    player_id: Uuid,
    course_id: Option<&str>,
    started_at_utc: &str,
) -> PracticeAttemptContext {
    PracticeAttemptContext {
        player_id,
        course_id: course_id.map(uuid),
        course_node_id: Some("lesson-1".to_owned()),
        section_id: Some("verse-a".to_owned()),
        time_sig_num: 4,
        time_sig_den: 4,
        device_profile_id: None,
        instrument_family: "drums".to_owned(),
        lesson_title: "Eight Beat Check".to_owned(),
        lesson_difficulty: Some("beginner".to_owned()),
        lesson_tags: vec!["rock".to_owned(), "timing".to_owned()],
        lesson_skills: vec!["timing.onbeat".to_owned()],
        started_at_utc: started_at_utc.to_owned(),
        local_hour: 9,
        local_dow: 5,
    }
}

fn uuid(value: &str) -> Uuid {
    Uuid::parse_str(value).unwrap()
}

fn test_db_path() -> PathBuf {
    std::env::temp_dir().join(format!(
        "taal-practice-attempt-persistence-{}.sqlite",
        Uuid::new_v4()
    ))
}

fn cleanup(db_path: PathBuf) {
    match fs::remove_file(&db_path) {
        Ok(()) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(error) => panic!(
            "failed to remove test database {}: {error}",
            db_path.display()
        ),
    }
}
