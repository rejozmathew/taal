use crate::storage::practice_attempts::{
    parse_attempt_uuid, PracticeAttemptStorageError, PracticeAttemptStore,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PracticeHabitOperationResult {
    pub snapshot_json: Option<String>,
    pub error: Option<String>,
}

impl PracticeHabitOperationResult {
    fn snapshot(snapshot: crate::storage::practice_attempts::PracticeHabitSnapshot) -> Self {
        match serde_json::to_string(&snapshot) {
            Ok(snapshot_json) => Self {
                snapshot_json: Some(snapshot_json),
                error: None,
            },
            Err(error) => Self::err(PracticeAttemptStorageError::Json(error.to_string())),
        }
    }

    fn err(error: PracticeAttemptStorageError) -> Self {
        Self {
            snapshot_json: None,
            error: Some(error.to_string()),
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn load_practice_habit_snapshot(
    database_path: String,
    player_id: String,
    today_local_day_key: String,
) -> PracticeHabitOperationResult {
    match PracticeAttemptStore::open(database_path).and_then(|store| {
        let player_id = parse_attempt_uuid("player_id", &player_id)?;
        store.load_practice_habit_snapshot(player_id, today_local_day_key)
    }) {
        Ok(snapshot) => PracticeHabitOperationResult::snapshot(snapshot),
        Err(error) => PracticeHabitOperationResult::err(error),
    }
}
