use crate::scoring::AttemptSummary;
use crate::storage::practice_attempts::{
    parse_attempt_uuid, parse_optional_attempt_uuid, PracticeAttempt, PracticeAttemptContext,
    PracticeAttemptQuery, PracticeAttemptStorageError, PracticeAttemptStore,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PracticeAttemptOperationResult {
    pub attempt_json: Option<String>,
    pub attempts_json: Vec<String>,
    pub error: Option<String>,
}

impl PracticeAttemptOperationResult {
    fn attempt(attempt: PracticeAttempt) -> Self {
        match serde_json::to_string(&attempt) {
            Ok(attempt_json) => Self {
                attempt_json: Some(attempt_json),
                attempts_json: Vec::new(),
                error: None,
            },
            Err(error) => Self::err(PracticeAttemptStorageError::Json(error.to_string())),
        }
    }

    fn attempts(attempts: Vec<PracticeAttempt>) -> Self {
        let mut attempts_json = Vec::with_capacity(attempts.len());
        for attempt in attempts {
            match serde_json::to_string(&attempt) {
                Ok(json) => attempts_json.push(json),
                Err(error) => {
                    return Self::err(PracticeAttemptStorageError::Json(error.to_string()));
                }
            }
        }
        Self {
            attempt_json: None,
            attempts_json,
            error: None,
        }
    }

    fn err(error: PracticeAttemptStorageError) -> Self {
        Self {
            attempt_json: None,
            attempts_json: Vec::new(),
            error: Some(error.to_string()),
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn record_practice_attempt(
    database_path: String,
    summary_json: String,
    context_json: String,
) -> PracticeAttemptOperationResult {
    run(database_path, |store| {
        let summary = serde_json::from_str::<AttemptSummary>(&summary_json)?;
        let context = serde_json::from_str::<PracticeAttemptContext>(&context_json)?;
        store
            .record_practice_attempt(summary, context)
            .map(PracticeAttemptOperationResult::attempt)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_practice_attempts(
    database_path: String,
    player_id: String,
    lesson_id: Option<String>,
    course_id: Option<String>,
    started_at_utc_from: Option<String>,
    started_at_utc_to: Option<String>,
) -> PracticeAttemptOperationResult {
    run(database_path, |store| {
        let query = PracticeAttemptQuery {
            player_id: parse_attempt_uuid("player_id", &player_id)?,
            lesson_id: parse_optional_attempt_uuid("lesson_id", lesson_id.as_deref())?,
            course_id: parse_optional_attempt_uuid("course_id", course_id.as_deref())?,
            started_at_utc_from,
            started_at_utc_to,
        };
        store
            .list_attempts(query)
            .map(PracticeAttemptOperationResult::attempts)
    })
}

fn run(
    database_path: String,
    f: impl FnOnce(
        &PracticeAttemptStore,
    ) -> Result<PracticeAttemptOperationResult, PracticeAttemptStorageError>,
) -> PracticeAttemptOperationResult {
    match PracticeAttemptStore::open(database_path).and_then(|store| f(&store)) {
        Ok(result) => result,
        Err(error) => PracticeAttemptOperationResult::err(error),
    }
}
