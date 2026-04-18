use std::collections::{BTreeMap, BTreeSet, HashMap};
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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PracticeStreakState {
    Active,
    AtRisk,
    Reset,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PracticeDaySummary {
    pub local_day_key: String,
    pub minutes_completed: u32,
    pub scored_attempt_count: u32,
    pub full_lesson_completions: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PracticeWeekSummary {
    pub start_local_day_key: String,
    pub end_local_day_key: String,
    pub days_practiced: u8,
    pub total_minutes_completed: u32,
    pub scored_attempt_count: u32,
    pub full_lesson_completions: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PracticeHabitSnapshot {
    pub player_id: Uuid,
    pub today_local_day_key: String,
    pub daily_goal_minutes: u32,
    pub today_minutes_completed: u32,
    pub today_goal_met: bool,
    pub current_streak_days: u32,
    pub longest_streak_days: u32,
    pub streak_state: PracticeStreakState,
    pub streak_message: Option<String>,
    pub milestone_message: Option<String>,
    pub last_practice_day_key: Option<String>,
    pub today: PracticeDaySummary,
    pub week: PracticeWeekSummary,
}

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
    pub local_day_key: String,
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
    pub local_day_key: String,
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
    InvalidLocalDayKey {
        field: &'static str,
        value: String,
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
            Self::InvalidLocalDayKey { field, value } => {
                write!(f, "invalid {field}: {value}")
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

    pub fn load_practice_habit_snapshot(
        &self,
        player_id: Uuid,
        today_local_day_key: String,
    ) -> Result<PracticeHabitSnapshot, PracticeAttemptStorageError> {
        let today = LocalDay::parse("today_local_day_key", &today_local_day_key)?;
        let daily_goal_minutes = LocalProfileStore::open(&self.db_path)?
            .load_settings_snapshot(player_id)?
            .profile
            .daily_goal_minutes;

        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            load_habit_snapshot(conn, player_id, today, daily_goal_minutes)
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
            local_day_key: context.local_day_key.trim().to_owned(),
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
            local_day_key TEXT NOT NULL CHECK (length(local_day_key) = 10),
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
    ensure_practice_attempt_columns(conn)?;
    conn.execute_batch(
        "
        CREATE INDEX IF NOT EXISTS idx_practice_attempts_player_day
            ON practice_attempts(player_id, local_day_key);
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
            started_at_utc, local_day_key, local_hour, local_dow,
            score_total, accuracy_pct, hit_rate_pct,
            perfect_pct, early_pct, late_pct, miss_pct, max_streak,
            mean_delta_ms, std_delta_ms, median_delta_ms, p90_abs_delta_ms,
            lane_stats_json
         ) VALUES (
            ?1, ?2, ?3, ?4, ?5, ?6,
            ?7, ?8, ?9, ?10, ?11, ?12,
            ?13, ?14, ?15,
            ?16, ?17,
            ?18, ?19, ?20, ?21,
            ?22, ?23, ?24,
            ?25, ?26, ?27, ?28, ?29,
            ?30, ?31, ?32, ?33,
            ?34
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
            &attempt.local_day_key,
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
            started_at_utc, local_day_key, local_hour, local_dow,
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
    let lane_stats_json: String = row.get(33)?;

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
        local_day_key: row.get(18)?,
        local_hour: parse_db_u8("local_hour", row.get(19)?)?,
        local_dow: parse_db_u8("local_dow", row.get(20)?)?,
        score_total: row.get(21)?,
        accuracy_pct: row.get(22)?,
        hit_rate_pct: row.get(23)?,
        perfect_pct: row.get(24)?,
        early_pct: row.get(25)?,
        late_pct: row.get(26)?,
        miss_pct: row.get(27)?,
        max_streak: parse_db_u32("max_streak", row.get(28)?)?,
        mean_delta_ms: row.get(29)?,
        std_delta_ms: row.get(30)?,
        median_delta_ms: row.get(31)?,
        p90_abs_delta_ms: row.get(32)?,
        lane_stats: parse_json_column("lane_stats_json", &lane_stats_json)?,
    })
}

#[derive(Debug, Clone, Default)]
struct DayAggregate {
    duration_ms: u64,
    scored_attempt_count: u32,
    full_lesson_completions: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
struct LocalDay {
    ordinal: i64,
}

impl LocalDay {
    fn parse(field: &'static str, value: &str) -> Result<Self, PracticeAttemptStorageError> {
        let trimmed = value.trim();
        let bytes = trimmed.as_bytes();
        if bytes.len() != 10 || bytes[4] != b'-' || bytes[7] != b'-' {
            return Err(PracticeAttemptStorageError::InvalidLocalDayKey {
                field,
                value: value.to_owned(),
            });
        }
        let year = parse_i32_digits(&bytes[0..4]).ok_or_else(|| {
            PracticeAttemptStorageError::InvalidLocalDayKey {
                field,
                value: value.to_owned(),
            }
        })?;
        let month = parse_u8_digits(&bytes[5..7]).ok_or_else(|| {
            PracticeAttemptStorageError::InvalidLocalDayKey {
                field,
                value: value.to_owned(),
            }
        })?;
        let day = parse_u8_digits(&bytes[8..10]).ok_or_else(|| {
            PracticeAttemptStorageError::InvalidLocalDayKey {
                field,
                value: value.to_owned(),
            }
        })?;
        if !(1..=12).contains(&month) || day == 0 || day > days_in_month(year, month) {
            return Err(PracticeAttemptStorageError::InvalidLocalDayKey {
                field,
                value: value.to_owned(),
            });
        }
        Ok(Self {
            ordinal: days_from_civil(year, month, day),
        })
    }

    fn add_days(self, days: i64) -> Self {
        Self {
            ordinal: self.ordinal + days,
        }
    }

    fn key(self) -> String {
        let (year, month, day) = civil_from_days(self.ordinal);
        format!("{year:04}-{month:02}-{day:02}")
    }
}

fn load_habit_snapshot(
    conn: &Connection,
    player_id: Uuid,
    today: LocalDay,
    daily_goal_minutes: u32,
) -> Result<PracticeHabitSnapshot, PracticeAttemptStorageError> {
    let week_start = today.add_days(-6);
    let today_key = today.key();
    let week_start_key = week_start.key();
    let mut qualifying_days = BTreeSet::new();
    let mut week_days: BTreeMap<i64, DayAggregate> = BTreeMap::new();

    let mut stmt = conn.prepare(
        "SELECT local_day_key, duration_ms, section_id
         FROM practice_attempts
         WHERE player_id = ?1
           AND local_day_key <= ?2
         ORDER BY local_day_key ASC, started_at_utc ASC, id ASC",
    )?;
    let rows = stmt.query_map(params![player_id.to_string(), &today_key], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, i64>(1)?,
            row.get::<_, Option<String>>(2)?,
        ))
    })?;

    for row in rows {
        let (local_day_key, duration_ms, section_id) = row?;
        let day = LocalDay::parse("local_day_key", &local_day_key)?;
        qualifying_days.insert(day.ordinal);

        if day.ordinal >= week_start.ordinal && day.ordinal <= today.ordinal {
            let aggregate = week_days.entry(day.ordinal).or_default();
            aggregate.duration_ms = aggregate
                .duration_ms
                .saturating_add(parse_db_u64("duration_ms", duration_ms)?);
            aggregate.scored_attempt_count = aggregate.scored_attempt_count.saturating_add(1);
            if section_id.is_none() {
                aggregate.full_lesson_completions =
                    aggregate.full_lesson_completions.saturating_add(1);
            }
        }
    }

    let today_aggregate = week_days.get(&today.ordinal).cloned().unwrap_or_default();
    let today_minutes_completed = duration_ms_to_minutes(today_aggregate.duration_ms);
    let week_duration_ms = week_days
        .values()
        .fold(0_u64, |total, day| total.saturating_add(day.duration_ms));
    let week_scored_attempt_count = week_days.values().fold(0_u32, |total, day| {
        total.saturating_add(day.scored_attempt_count)
    });
    let week_full_lesson_completions = week_days.values().fold(0_u32, |total, day| {
        total.saturating_add(day.full_lesson_completions)
    });

    let has_today = qualifying_days.contains(&today.ordinal);
    let has_yesterday = qualifying_days.contains(&(today.ordinal - 1));
    let (streak_state, streak_anchor) = if has_today {
        (PracticeStreakState::Active, Some(today.ordinal))
    } else if has_yesterday {
        (PracticeStreakState::AtRisk, Some(today.ordinal - 1))
    } else {
        (PracticeStreakState::Reset, None)
    };
    let current_streak_days = streak_anchor
        .map(|anchor| count_streak_ending_at(&qualifying_days, anchor))
        .unwrap_or(0);
    let longest_streak_days = longest_streak(&qualifying_days);
    let last_practice_day_key = qualifying_days
        .iter()
        .next_back()
        .map(|day| LocalDay { ordinal: *day }.key());

    Ok(PracticeHabitSnapshot {
        player_id,
        today_local_day_key: today_key.clone(),
        daily_goal_minutes,
        today_minutes_completed,
        today_goal_met: today_minutes_completed >= daily_goal_minutes,
        current_streak_days,
        longest_streak_days,
        streak_state,
        streak_message: streak_message(streak_state, current_streak_days),
        milestone_message: milestone_message(streak_state, current_streak_days),
        last_practice_day_key,
        today: PracticeDaySummary {
            local_day_key: today_key.clone(),
            minutes_completed: today_minutes_completed,
            scored_attempt_count: today_aggregate.scored_attempt_count,
            full_lesson_completions: today_aggregate.full_lesson_completions,
        },
        week: PracticeWeekSummary {
            start_local_day_key: week_start_key,
            end_local_day_key: today_key,
            days_practiced: week_days.len() as u8,
            total_minutes_completed: duration_ms_to_minutes(week_duration_ms),
            scored_attempt_count: week_scored_attempt_count,
            full_lesson_completions: week_full_lesson_completions,
        },
    })
}

fn count_streak_ending_at(days: &BTreeSet<i64>, anchor: i64) -> u32 {
    let mut count = 0_u32;
    let mut day = anchor;
    while days.contains(&day) {
        count = count.saturating_add(1);
        day -= 1;
    }
    count
}

fn longest_streak(days: &BTreeSet<i64>) -> u32 {
    let mut longest = 0_u32;
    let mut current = 0_u32;
    let mut previous: Option<i64> = None;

    for day in days {
        current = if previous == Some(day - 1) {
            current.saturating_add(1)
        } else {
            1
        };
        longest = longest.max(current);
        previous = Some(*day);
    }

    longest
}

fn streak_message(state: PracticeStreakState, current_streak_days: u32) -> Option<String> {
    match state {
        PracticeStreakState::Active if current_streak_days == 1 => {
            Some("Nice start. One practice day logged.".to_owned())
        }
        PracticeStreakState::Active => {
            Some(format!("{current_streak_days} practice days in a row."))
        }
        PracticeStreakState::AtRisk => Some(format!(
            "Practice today to keep your {current_streak_days}-day streak."
        )),
        PracticeStreakState::Reset => {
            Some("Start a new streak with one practice today.".to_owned())
        }
    }
}

fn milestone_message(state: PracticeStreakState, current_streak_days: u32) -> Option<String> {
    if state != PracticeStreakState::Active {
        return None;
    }
    match current_streak_days {
        7 => Some("Seven days in rhythm.".to_owned()),
        30 => Some("Thirty days of steady practice.".to_owned()),
        100 => Some("One hundred days. That habit is real.".to_owned()),
        _ => None,
    }
}

fn duration_ms_to_minutes(duration_ms: u64) -> u32 {
    (duration_ms / 60_000).min(u64::from(u32::MAX)) as u32
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
    LocalDay::parse("local_day_key", &context.local_day_key)?;
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

fn parse_i32_digits(bytes: &[u8]) -> Option<i32> {
    let mut value = 0_i32;
    for byte in bytes {
        if !byte.is_ascii_digit() {
            return None;
        }
        value = value * 10 + i32::from(*byte - b'0');
    }
    Some(value)
}

fn parse_u8_digits(bytes: &[u8]) -> Option<u8> {
    let mut value = 0_u8;
    for byte in bytes {
        if !byte.is_ascii_digit() {
            return None;
        }
        value = value.checked_mul(10)?.checked_add(*byte - b'0')?;
    }
    Some(value)
}

fn days_in_month(year: i32, month: u8) -> u8 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if is_leap_year(year) => 29,
        2 => 28,
        _ => 0,
    }
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

fn days_from_civil(year: i32, month: u8, day: u8) -> i64 {
    let mut y = i64::from(year);
    let m = i64::from(month);
    let d = i64::from(day);
    y -= if m <= 2 { 1 } else { 0 };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let month_prime = m + if m > 2 { -3 } else { 9 };
    let doy = (153 * month_prime + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let mut y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    y += if m <= 2 { 1 } else { 0 };
    (y, m, d)
}

fn ensure_practice_attempt_columns(conn: &Connection) -> Result<(), PracticeAttemptStorageError> {
    ensure_column(
        conn,
        "practice_attempts",
        "local_day_key",
        "ALTER TABLE practice_attempts ADD COLUMN local_day_key TEXT NOT NULL DEFAULT '1970-01-01'",
    )?;
    conn.execute(
        "UPDATE practice_attempts
         SET local_day_key = substr(started_at_utc, 1, 10)
         WHERE local_day_key = '1970-01-01'
           AND length(started_at_utc) >= 10",
        [],
    )?;
    Ok(())
}

fn ensure_column(
    conn: &Connection,
    table: &str,
    column: &str,
    alter_sql: &str,
) -> Result<(), PracticeAttemptStorageError> {
    if !column_exists(conn, table, column)? {
        conn.execute_batch(alter_sql)?;
    }
    Ok(())
}

fn column_exists(
    conn: &Connection,
    table: &str,
    column: &str,
) -> Result<bool, PracticeAttemptStorageError> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let rows = stmt.query_map([], |row| row.get::<_, String>(1))?;
    for row in rows {
        if row? == column {
            return Ok(true);
        }
    }
    Ok(false)
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
