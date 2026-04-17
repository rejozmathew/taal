use std::collections::HashMap;
use std::error::Error;
use std::fmt::{self, Display};
use std::path::{Path, PathBuf};

use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::content::PracticeMode;
use crate::scoring::{AttemptSummary, LaneStats};
use crate::storage::device_profiles::{DeviceProfileStorageError, DeviceProfileStore};
use crate::storage::profiles::{parse_profile_id, LocalProfileStore, ProfileStorageError};

pub type DateTime = String;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PracticeAttempt {
    pub id: Uuid,
    pub player_id: Uuid,
    pub lesson_id: Uuid,
    pub course_id: Option<Uuid>,
    pub course_node_id: Option<String>,
    pub section_id: Option<String>,
    pub mode: PracticeMode,
    pub bpm: f32,
    pub time_sig_num: u8,
    pub time_sig_den: u8,
    pub duration_ms: u64,
    pub device_profile_id: Option<Uuid>,
    pub instrument_family: String,
    pub lesson_title: String,
    pub lesson_difficulty: Option<String>,
    pub lesson_tags: Vec<String>,
    pub lesson_skills: Vec<String>,
    pub started_at_utc: DateTime,
    pub local_hour: u8,
    pub local_dow: u8,
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PracticeAttemptContext {
    pub player_id: Uuid,
    pub course_id: Option<Uuid>,
    pub course_node_id: Option<String>,
    pub section_id: Option<String>,
    pub time_sig_num: u8,
    pub time_sig_den: u8,
    pub device_profile_id: Option<Uuid>,
    pub instrument_family: String,
    pub lesson_title: String,
    pub lesson_difficulty: Option<String>,
    pub lesson_tags: Vec<String>,
    pub lesson_skills: Vec<String>,
    pub started_at_utc: DateTime,
    pub local_hour: u8,
    pub local_dow: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PracticeAttemptQuery {
    pub player_id: Uuid,
    pub lesson_id: Option<Uuid>,
    pub course_id: Option<Uuid>,
    pub started_at_utc_from: Option<DateTime>,
    pub started_at_utc_to: Option<DateTime>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PracticeAttemptStorageError {
    Database(String),
    InvalidId {
        field: &'static str,
        value: String,
    },
    InvalidContext {
        field: &'static str,
        message: String,
    },
    PlayerNotFound(Uuid),
    DeviceProfileNotFound(Uuid),
    Json(String),
    ProfileStorage(String),
    DeviceProfileStorage(String),
}

impl Display for PracticeAttemptStorageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Database(message) => write!(f, "practice attempt database error: {message}"),
            Self::InvalidId { field, value } => write!(f, "invalid {field}: {value}"),
            Self::InvalidContext { field, message } => {
                write!(f, "invalid practice attempt context {field}: {message}")
            }
            Self::PlayerNotFound(id) => write!(f, "player profile not found: {id}"),
            Self::DeviceProfileNotFound(id) => write!(f, "device profile not found: {id}"),
            Self::Json(message) => write!(f, "practice attempt JSON error: {message}"),
            Self::ProfileStorage(message) => write!(f, "profile storage error: {message}"),
            Self::DeviceProfileStorage(message) => {
                write!(f, "device profile storage error: {message}")
            }
        }
    }
}

impl Error for PracticeAttemptStorageError {}

impl From<rusqlite::Error> for PracticeAttemptStorageError {
    fn from(error: rusqlite::Error) -> Self {
        Self::Database(error.to_string())
    }
}

impl From<serde_json::Error> for PracticeAttemptStorageError {
    fn from(error: serde_json::Error) -> Self {
        Self::Json(error.to_string())
    }
}

impl From<ProfileStorageError> for PracticeAttemptStorageError {
    fn from(error: ProfileStorageError) -> Self {
        Self::ProfileStorage(error.to_string())
    }
}

impl From<DeviceProfileStorageError> for PracticeAttemptStorageError {
    fn from(error: DeviceProfileStorageError) -> Self {
        Self::DeviceProfileStorage(error.to_string())
    }
}

#[derive(Debug, Clone)]
pub struct PracticeAttemptStore {
    db_path: PathBuf,
}

impl PracticeAttemptStore {
    pub fn open(db_path: impl Into<PathBuf>) -> Result<Self, PracticeAttemptStorageError> {
        let db_path = db_path.into();
        LocalProfileStore::open(&db_path)?;
        DeviceProfileStore::open(&db_path)?;
        let store = Self { db_path };
        store.with_connection(|conn| {
            apply_schema(conn)?;
            Ok(())
        })?;
        Ok(store)
    }

    pub fn db_path(&self) -> &Path {
        &self.db_path
    }

    pub fn record_practice_attempt(
        &self,
        summary: AttemptSummary,
        context: PracticeAttemptContext,
    ) -> Result<PracticeAttempt, PracticeAttemptStorageError> {
        validate_context(&context)?;
        self.with_connection(|conn| {
            require_player(conn, context.player_id)?;
            if let Some(device_profile_id) = context.device_profile_id {
                require_device_profile(conn, context.player_id, device_profile_id)?;
            }

            let attempt = PracticeAttempt::from_summary_context(summary, context);
            insert_attempt(conn, &attempt)?;
            Ok(attempt)
        })
    }

    pub fn list_attempts(
        &self,
        query: PracticeAttemptQuery,
    ) -> Result<Vec<PracticeAttempt>, PracticeAttemptStorageError> {
        self.with_connection(|conn| {
            require_player(conn, query.player_id)?;
            list_attempts(conn, &query)
        })
    }

    fn with_connection<T>(
        &self,
        f: impl FnOnce(&Connection) -> Result<T, PracticeAttemptStorageError>,
    ) -> Result<T, PracticeAttemptStorageError> {
        let conn = Connection::open(&self.db_path)?;
        conn.execute_batch("PRAGMA foreign_keys = ON;")?;
        f(&conn)
    }
}

impl PracticeAttempt {
    fn from_summary_context(summary: AttemptSummary, context: PracticeAttemptContext) -> Self {
        Self {
            id: Uuid::new_v4(),
            player_id: context.player_id,
            lesson_id: summary.lesson_id,
            course_id: context.course_id,
            course_node_id: normalized_optional_text(context.course_node_id),
            section_id: normalized_optional_text(context.section_id),
            mode: summary.mode,
            bpm: summary.bpm,
            time_sig_num: context.time_sig_num,
            time_sig_den: context.time_sig_den,
            duration_ms: summary.duration_ms,
            device_profile_id: context.device_profile_id,
            instrument_family: context.instrument_family.trim().to_owned(),
            lesson_title: context.lesson_title.trim().to_owned(),
            lesson_difficulty: normalized_optional_text(context.lesson_difficulty),
            lesson_tags: context.lesson_tags,
            lesson_skills: context.lesson_skills,
            started_at_utc: context.started_at_utc.trim().to_owned(),
            local_hour: context.local_hour,
            local_dow: context.local_dow,
            score_total: summary.score_total,
            accuracy_pct: summary.accuracy_pct,
            hit_rate_pct: summary.hit_rate_pct,
            perfect_pct: summary.perfect_pct,
            early_pct: summary.early_pct,
            late_pct: summary.late_pct,
            miss_pct: summary.miss_pct,
            max_streak: summary.max_streak,
            mean_delta_ms: summary.mean_delta_ms,
            std_delta_ms: summary.std_delta_ms,
            median_delta_ms: summary.median_delta_ms,
            p90_abs_delta_ms: summary.p90_abs_delta_ms,
            lane_stats: summary.lane_stats,
        }
    }
}

pub fn parse_attempt_uuid(
    field: &'static str,
    value: &str,
) -> Result<Uuid, PracticeAttemptStorageError> {
    Uuid::parse_str(value).map_err(|_| PracticeAttemptStorageError::InvalidId {
        field,
        value: value.to_owned(),
    })
}

pub fn parse_optional_attempt_uuid(
    field: &'static str,
    value: Option<&str>,
) -> Result<Option<Uuid>, PracticeAttemptStorageError> {
    value.map(|id| parse_attempt_uuid(field, id)).transpose()
}

fn apply_schema(conn: &Connection) -> Result<(), PracticeAttemptStorageError> {
    conn.execute_batch(
        "
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS practice_attempts (
            id TEXT PRIMARY KEY,
            player_id TEXT NOT NULL
                REFERENCES player_profiles(id) ON DELETE CASCADE,
            lesson_id TEXT NOT NULL,
            course_id TEXT,
            course_node_id TEXT,
            section_id TEXT,
            mode TEXT NOT NULL CHECK (
                mode IN ('practice', 'play', 'course_gate')
            ),
            bpm REAL NOT NULL,
            time_sig_num INTEGER NOT NULL CHECK (time_sig_num > 0),
            time_sig_den INTEGER NOT NULL CHECK (time_sig_den > 0),
            duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
            device_profile_id TEXT
                REFERENCES device_profiles(id) ON DELETE SET NULL,
            instrument_family TEXT NOT NULL CHECK (length(trim(instrument_family)) > 0),
            lesson_title TEXT NOT NULL CHECK (length(trim(lesson_title)) > 0),
            lesson_difficulty TEXT,
            lesson_tags_json TEXT NOT NULL,
            lesson_skills_json TEXT NOT NULL,
            started_at_utc TEXT NOT NULL CHECK (length(trim(started_at_utc)) > 0),
            local_hour INTEGER NOT NULL CHECK (local_hour >= 0 AND local_hour <= 23),
            local_dow INTEGER NOT NULL CHECK (local_dow >= 0 AND local_dow <= 6),
            score_total REAL NOT NULL,
            accuracy_pct REAL NOT NULL,
            hit_rate_pct REAL NOT NULL,
            perfect_pct REAL NOT NULL,
            early_pct REAL NOT NULL,
            late_pct REAL NOT NULL,
            miss_pct REAL NOT NULL,
            max_streak INTEGER NOT NULL,
            mean_delta_ms REAL NOT NULL,
            std_delta_ms REAL NOT NULL,
            median_delta_ms REAL,
            p90_abs_delta_ms REAL,
            lane_stats_json TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_practice_attempts_player_started
            ON practice_attempts(player_id, started_at_utc);

        CREATE INDEX IF NOT EXISTS idx_practice_attempts_player_lesson
            ON practice_attempts(player_id, lesson_id);

        CREATE INDEX IF NOT EXISTS idx_practice_attempts_player_hour
            ON practice_attempts(player_id, local_hour);

        CREATE INDEX IF NOT EXISTS idx_practice_attempts_player_course
            ON practice_attempts(player_id, course_id);
        ",
    )?;
    Ok(())
}

fn insert_attempt(
    conn: &Connection,
    attempt: &PracticeAttempt,
) -> Result<(), PracticeAttemptStorageError> {
    let lesson_tags_json = serde_json::to_string(&attempt.lesson_tags)?;
    let lesson_skills_json = serde_json::to_string(&attempt.lesson_skills)?;
    let lane_stats_json = serde_json::to_string(&attempt.lane_stats)?;

    conn.execute(
        "INSERT INTO practice_attempts (
            id, player_id, lesson_id, course_id, course_node_id, section_id,
            mode, bpm, time_sig_num, time_sig_den, duration_ms, device_profile_id,
            instrument_family, lesson_title, lesson_difficulty,
            lesson_tags_json, lesson_skills_json,
            started_at_utc, local_hour, local_dow,
            score_total, accuracy_pct, hit_rate_pct,
            perfect_pct, early_pct, late_pct, miss_pct, max_streak,
            mean_delta_ms, std_delta_ms, median_delta_ms, p90_abs_delta_ms,
            lane_stats_json
         ) VALUES (
            ?1, ?2, ?3, ?4, ?5, ?6,
            ?7, ?8, ?9, ?10, ?11, ?12,
            ?13, ?14, ?15,
            ?16, ?17,
            ?18, ?19, ?20,
            ?21, ?22, ?23,
            ?24, ?25, ?26, ?27, ?28,
            ?29, ?30, ?31, ?32,
            ?33
         )",
        params![
            attempt.id.to_string(),
            attempt.player_id.to_string(),
            attempt.lesson_id.to_string(),
            attempt.course_id.as_ref().map(Uuid::to_string),
            attempt.course_node_id.as_deref(),
            attempt.section_id.as_deref(),
            practice_mode_to_db(attempt.mode),
            attempt.bpm,
            i64::from(attempt.time_sig_num),
            i64::from(attempt.time_sig_den),
            attempt.duration_ms as i64,
            attempt.device_profile_id.as_ref().map(Uuid::to_string),
            &attempt.instrument_family,
            &attempt.lesson_title,
            attempt.lesson_difficulty.as_deref(),
            lesson_tags_json,
            lesson_skills_json,
            &attempt.started_at_utc,
            i64::from(attempt.local_hour),
            i64::from(attempt.local_dow),
            attempt.score_total,
            attempt.accuracy_pct,
            attempt.hit_rate_pct,
            attempt.perfect_pct,
            attempt.early_pct,
            attempt.late_pct,
            attempt.miss_pct,
            i64::from(attempt.max_streak),
            attempt.mean_delta_ms,
            attempt.std_delta_ms,
            attempt.median_delta_ms,
            attempt.p90_abs_delta_ms,
            lane_stats_json,
        ],
    )?;
    Ok(())
}

fn list_attempts(
    conn: &Connection,
    query: &PracticeAttemptQuery,
) -> Result<Vec<PracticeAttempt>, PracticeAttemptStorageError> {
    let lesson_id = query.lesson_id.as_ref().map(Uuid::to_string);
    let course_id = query.course_id.as_ref().map(Uuid::to_string);
    let mut stmt = conn.prepare(
        "SELECT
            id, player_id, lesson_id, course_id, course_node_id, section_id,
            mode, bpm, time_sig_num, time_sig_den, duration_ms, device_profile_id,
            instrument_family, lesson_title, lesson_difficulty,
            lesson_tags_json, lesson_skills_json,
            started_at_utc, local_hour, local_dow,
            score_total, accuracy_pct, hit_rate_pct,
            perfect_pct, early_pct, late_pct, miss_pct, max_streak,
            mean_delta_ms, std_delta_ms, median_delta_ms, p90_abs_delta_ms,
            lane_stats_json
         FROM practice_attempts
         WHERE player_id = ?1
           AND (?2 IS NULL OR lesson_id = ?2)
           AND (?3 IS NULL OR course_id = ?3)
           AND (?4 IS NULL OR started_at_utc >= ?4)
           AND (?5 IS NULL OR started_at_utc <= ?5)
         ORDER BY started_at_utc DESC, id ASC",
    )?;

    let rows = stmt.query_map(
        params![
            query.player_id.to_string(),
            lesson_id,
            course_id,
            query.started_at_utc_from.as_deref(),
            query.started_at_utc_to.as_deref(),
        ],
        row_to_attempt,
    )?;

    let mut attempts = Vec::new();
    for row in rows {
        attempts.push(row?);
    }
    Ok(attempts)
}

fn row_to_attempt(row: &rusqlite::Row<'_>) -> Result<PracticeAttempt, rusqlite::Error> {
    let id_text: String = row.get(0)?;
    let player_id_text: String = row.get(1)?;
    let lesson_id_text: String = row.get(2)?;
    let course_id_text: Option<String> = row.get(3)?;
    let mode_text: String = row.get(6)?;
    let device_profile_id_text: Option<String> = row.get(11)?;
    let lesson_tags_json: String = row.get(15)?;
    let lesson_skills_json: String = row.get(16)?;
    let lane_stats_json: String = row.get(32)?;

    Ok(PracticeAttempt {
        id: parse_db_uuid("id", &id_text)?,
        player_id: parse_db_uuid("player_id", &player_id_text)?,
        lesson_id: parse_db_uuid("lesson_id", &lesson_id_text)?,
        course_id: parse_db_optional_uuid("course_id", course_id_text)?,
        course_node_id: row.get(4)?,
        section_id: row.get(5)?,
        mode: parse_practice_mode_db(&mode_text)?,
        bpm: row.get(7)?,
        time_sig_num: parse_db_u8("time_sig_num", row.get(8)?)?,
        time_sig_den: parse_db_u8("time_sig_den", row.get(9)?)?,
        duration_ms: parse_db_u64("duration_ms", row.get(10)?)?,
        device_profile_id: parse_db_optional_uuid("device_profile_id", device_profile_id_text)?,
        instrument_family: row.get(12)?,
        lesson_title: row.get(13)?,
        lesson_difficulty: row.get(14)?,
        lesson_tags: parse_json_column("lesson_tags_json", &lesson_tags_json)?,
        lesson_skills: parse_json_column("lesson_skills_json", &lesson_skills_json)?,
        started_at_utc: row.get(17)?,
        local_hour: parse_db_u8("local_hour", row.get(18)?)?,
        local_dow: parse_db_u8("local_dow", row.get(19)?)?,
        score_total: row.get(20)?,
        accuracy_pct: row.get(21)?,
        hit_rate_pct: row.get(22)?,
        perfect_pct: row.get(23)?,
        early_pct: row.get(24)?,
        late_pct: row.get(25)?,
        miss_pct: row.get(26)?,
        max_streak: parse_db_u32("max_streak", row.get(27)?)?,
        mean_delta_ms: row.get(28)?,
        std_delta_ms: row.get(29)?,
        median_delta_ms: row.get(30)?,
        p90_abs_delta_ms: row.get(31)?,
        lane_stats: parse_json_column("lane_stats_json", &lane_stats_json)?,
    })
}

fn require_player(conn: &Connection, player_id: Uuid) -> Result<(), PracticeAttemptStorageError> {
    let exists: Option<i32> = conn
        .query_row(
            "SELECT 1 FROM player_profiles WHERE id = ?1",
            params![player_id.to_string()],
            |row| row.get(0),
        )
        .optional()?;
    exists
        .map(|_| ())
        .ok_or(PracticeAttemptStorageError::PlayerNotFound(player_id))
}

fn require_device_profile(
    conn: &Connection,
    player_id: Uuid,
    device_profile_id: Uuid,
) -> Result<(), PracticeAttemptStorageError> {
    let exists: Option<i32> = conn
        .query_row(
            "SELECT 1 FROM device_profiles WHERE id = ?1 AND player_id = ?2",
            params![device_profile_id.to_string(), player_id.to_string()],
            |row| row.get(0),
        )
        .optional()?;
    exists
        .map(|_| ())
        .ok_or(PracticeAttemptStorageError::DeviceProfileNotFound(
            device_profile_id,
        ))
}

fn validate_context(context: &PracticeAttemptContext) -> Result<(), PracticeAttemptStorageError> {
    if context.time_sig_num == 0 {
        return invalid_context("time_sig_num", "must be greater than 0");
    }
    if context.time_sig_den == 0 {
        return invalid_context("time_sig_den", "must be greater than 0");
    }
    if context.local_hour > 23 {
        return invalid_context("local_hour", "must be in 0..=23");
    }
    if context.local_dow > 6 {
        return invalid_context("local_dow", "must be in 0..=6");
    }
    if context.instrument_family.trim().is_empty() {
        return invalid_context("instrument_family", "must not be empty");
    }
    if context.lesson_title.trim().is_empty() {
        return invalid_context("lesson_title", "must not be empty");
    }
    if context.started_at_utc.trim().is_empty() {
        return invalid_context("started_at_utc", "must not be empty");
    }
    Ok(())
}

fn invalid_context<T>(
    field: &'static str,
    message: impl Into<String>,
) -> Result<T, PracticeAttemptStorageError> {
    Err(PracticeAttemptStorageError::InvalidContext {
        field,
        message: message.into(),
    })
}

fn practice_mode_to_db(mode: PracticeMode) -> &'static str {
    match mode {
        PracticeMode::Practice => "practice",
        PracticeMode::Play => "play",
        PracticeMode::CourseGate => "course_gate",
    }
}

fn parse_practice_mode_db(value: &str) -> Result<PracticeMode, rusqlite::Error> {
    match value {
        "practice" => Ok(PracticeMode::Practice),
        "play" => Ok(PracticeMode::Play),
        "course_gate" => Ok(PracticeMode::CourseGate),
        other => Err(invalid_column(format!("invalid practice mode: {other}"))),
    }
}

fn parse_db_uuid(field: &'static str, value: &str) -> Result<Uuid, rusqlite::Error> {
    parse_profile_id(value).map_err(|_| invalid_column(format!("invalid {field}: {value}")))
}

fn parse_db_optional_uuid(
    field: &'static str,
    value: Option<String>,
) -> Result<Option<Uuid>, rusqlite::Error> {
    value.map(|id| parse_db_uuid(field, &id)).transpose()
}

fn parse_db_u8(field: &'static str, value: i64) -> Result<u8, rusqlite::Error> {
    u8::try_from(value).map_err(|_| invalid_column(format!("invalid {field}: {value}")))
}

fn parse_db_u32(field: &'static str, value: i64) -> Result<u32, rusqlite::Error> {
    u32::try_from(value).map_err(|_| invalid_column(format!("invalid {field}: {value}")))
}

fn parse_db_u64(field: &'static str, value: i64) -> Result<u64, rusqlite::Error> {
    u64::try_from(value).map_err(|_| invalid_column(format!("invalid {field}: {value}")))
}

fn parse_json_column<T>(field: &'static str, value: &str) -> Result<T, rusqlite::Error>
where
    T: for<'de> Deserialize<'de>,
{
    serde_json::from_str(value).map_err(|error| invalid_column(format!("invalid {field}: {error}")))
}

fn invalid_column(message: String) -> rusqlite::Error {
    rusqlite::Error::FromSqlConversionFailure(
        0,
        rusqlite::types::Type::Text,
        Box::new(PracticeAttemptStorageError::Database(message)),
    )
}

fn normalized_optional_text(value: Option<String>) -> Option<String> {
    value
        .map(|text| text.trim().to_owned())
        .filter(|text| !text.is_empty())
}
