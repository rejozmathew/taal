use std::error::Error;
use std::fmt::{self, Display};
use std::path::{Path, PathBuf};

use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub type DateTime = String;

const ACTIVE_PROFILE_KEY: &str = "last_active_profile_id";
const AUDIO_OUTPUT_DEVICE_KEY: &str = "audio_output_device_id";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ExperienceLevel {
    Beginner,
    Intermediate,
    Teacher,
}

impl ExperienceLevel {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Beginner => "beginner",
            Self::Intermediate => "intermediate",
            Self::Teacher => "teacher",
        }
    }

    pub fn parse_db_value(value: &str) -> Result<Self, ProfileStorageError> {
        match value {
            "beginner" => Ok(Self::Beginner),
            "intermediate" => Ok(Self::Intermediate),
            "teacher" => Ok(Self::Teacher),
            other => Err(ProfileStorageError::InvalidEnumValue {
                field: "experience_level",
                value: other.to_owned(),
            }),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PracticeView {
    NoteHighway,
    Notation,
}

impl PracticeView {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::NoteHighway => "note_highway",
            Self::Notation => "notation",
        }
    }

    pub fn parse_db_value(value: &str) -> Result<Self, ProfileStorageError> {
        match value {
            "note_highway" => Ok(Self::NoteHighway),
            "notation" => Ok(Self::Notation),
            other => Err(ProfileStorageError::InvalidEnumValue {
                field: "preferred_view",
                value: other.to_owned(),
            }),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct PlayerProfile {
    pub id: Uuid,
    pub name: String,
    pub avatar: Option<String>,
    pub experience_level: ExperienceLevel,
    pub preferred_view: PracticeView,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalProfileState {
    pub profiles: Vec<PlayerProfile>,
    pub active_profile_id: Option<Uuid>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct AppSettings {
    pub last_active_profile_id: Option<Uuid>,
    pub audio_output_device_id: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemePreference {
    System,
    Light,
    Dark,
}

impl ThemePreference {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::System => "system",
            Self::Light => "light",
            Self::Dark => "dark",
        }
    }

    pub fn parse_db_value(value: &str) -> Result<Self, ProfileStorageError> {
        match value {
            "system" => Ok(Self::System),
            "light" => Ok(Self::Light),
            "dark" => Ok(Self::Dark),
            other => Err(ProfileStorageError::InvalidEnumValue {
                field: "theme",
                value: other.to_owned(),
            }),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ClickSoundPreset {
    Classic,
    Woodblock,
    HiHat,
}

impl ClickSoundPreset {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Classic => "classic",
            Self::Woodblock => "woodblock",
            Self::HiHat => "hi_hat",
        }
    }

    pub fn parse_db_value(value: &str) -> Result<Self, ProfileStorageError> {
        match value {
            "classic" => Ok(Self::Classic),
            "woodblock" => Ok(Self::Woodblock),
            "hi_hat" | "hihat" => Ok(Self::HiHat),
            other => Err(ProfileStorageError::InvalidEnumValue {
                field: "metronome_click_sound",
                value: other.to_owned(),
            }),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct ProfileSettings {
    pub player_id: Uuid,
    pub preferred_view: PracticeView,
    pub theme: ThemePreference,
    pub reduce_motion: bool,
    pub high_contrast: bool,
    pub metronome_volume: f32,
    pub metronome_click_sound: ClickSoundPreset,
    pub auto_pause_enabled: bool,
    pub auto_pause_timeout_ms: u32,
    pub record_practice_mode_attempts: bool,
    pub daily_goal_minutes: u32,
    pub play_kit_hit_sounds: bool,
    pub active_device_profile_id: Option<Uuid>,
    pub updated_at: DateTime,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct ProfileSettingsUpdate {
    pub preferred_view: PracticeView,
    pub theme: ThemePreference,
    pub reduce_motion: bool,
    pub high_contrast: bool,
    pub metronome_volume: f32,
    pub metronome_click_sound: ClickSoundPreset,
    pub auto_pause_enabled: bool,
    pub auto_pause_timeout_ms: u32,
    pub record_practice_mode_attempts: bool,
    pub daily_goal_minutes: u32,
    pub play_kit_hit_sounds: bool,
    pub active_device_profile_id: Option<Uuid>,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct SettingsSnapshot {
    pub app: AppSettings,
    pub profile: ProfileSettings,
}

impl LocalProfileState {
    pub fn active_profile(&self) -> Option<&PlayerProfile> {
        let active_id = self.active_profile_id?;
        self.profiles.iter().find(|profile| profile.id == active_id)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateProfileRequest {
    pub name: String,
    pub avatar: Option<String>,
    pub experience_level: ExperienceLevel,
}

type ProfileDbRow = (
    String,
    String,
    Option<String>,
    String,
    String,
    String,
    String,
);

type ProfileSettingsDbRow = (
    String,
    i64,
    i64,
    f32,
    String,
    i64,
    u32,
    i64,
    u32,
    i64,
    Option<String>,
    String,
);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProfileStorageError {
    Database(String),
    InvalidName,
    InvalidProfileId(String),
    InvalidEnumValue {
        field: &'static str,
        value: String,
    },
    InvalidRange {
        field: &'static str,
        message: String,
    },
    ProfileNotFound(Uuid),
    DeviceProfileNotFound(Uuid),
}

impl Display for ProfileStorageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Database(message) => write!(f, "profile storage database error: {message}"),
            Self::InvalidName => write!(f, "profile name must not be empty"),
            Self::InvalidProfileId(value) => write!(f, "invalid profile id: {value}"),
            Self::InvalidEnumValue { field, value } => {
                write!(f, "invalid {field} value: {value}")
            }
            Self::InvalidRange { field, message } => {
                write!(f, "invalid {field}: {message}")
            }
            Self::ProfileNotFound(id) => write!(f, "profile not found: {id}"),
            Self::DeviceProfileNotFound(id) => write!(f, "device profile not found: {id}"),
        }
    }
}

impl Error for ProfileStorageError {}

impl From<rusqlite::Error> for ProfileStorageError {
    fn from(error: rusqlite::Error) -> Self {
        Self::Database(error.to_string())
    }
}

#[derive(Debug, Clone)]
pub struct LocalProfileStore {
    db_path: PathBuf,
}

impl LocalProfileStore {
    pub fn open(db_path: impl Into<PathBuf>) -> Result<Self, ProfileStorageError> {
        let store = Self {
            db_path: db_path.into(),
        };
        store.with_connection(|conn| {
            apply_schema(conn)?;
            Ok(())
        })?;
        Ok(store)
    }

    pub fn db_path(&self) -> &Path {
        &self.db_path
    }

    pub fn state(&self) -> Result<LocalProfileState, ProfileStorageError> {
        self.with_connection(state)
    }

    pub fn create_profile(
        &self,
        request: CreateProfileRequest,
    ) -> Result<LocalProfileState, ProfileStorageError> {
        let name = validate_name(&request.name)?;
        let avatar = request.avatar.and_then(normalize_optional_text);

        self.with_connection(|conn| {
            let id = Uuid::new_v4();
            let now = sqlite_utc_now(conn)?;

            conn.execute(
                "INSERT INTO player_profiles (
                    id, name, avatar, experience_level, preferred_view, created_at, updated_at
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)",
                params![
                    id.to_string(),
                    name,
                    avatar,
                    request.experience_level.as_str(),
                    PracticeView::NoteHighway.as_str(),
                    now,
                ],
            )?;
            conn.execute(
                "INSERT INTO profile_preferences (player_id, created_at, updated_at)
                 VALUES (?1, ?2, ?2)",
                params![id.to_string(), now],
            )?;
            set_active_profile_id(conn, Some(id))?;
            state(conn)
        })
    }

    pub fn set_active_profile(
        &self,
        profile_id: Uuid,
    ) -> Result<LocalProfileState, ProfileStorageError> {
        self.with_connection(|conn| {
            require_profile(conn, profile_id)?;
            set_active_profile_id(conn, Some(profile_id))?;
            state(conn)
        })
    }

    pub fn update_preferred_view(
        &self,
        profile_id: Uuid,
        preferred_view: PracticeView,
    ) -> Result<LocalProfileState, ProfileStorageError> {
        self.with_connection(|conn| {
            require_profile(conn, profile_id)?;
            let now = sqlite_utc_now(conn)?;
            conn.execute(
                "UPDATE player_profiles
                 SET preferred_view = ?1, updated_at = ?2
                 WHERE id = ?3",
                params![preferred_view.as_str(), now, profile_id.to_string()],
            )?;
            ensure_profile_preferences_row(conn, profile_id)?;
            conn.execute(
                "UPDATE profile_preferences
                 SET updated_at = ?1
                 WHERE player_id = ?2",
                params![now, profile_id.to_string()],
            )?;
            state(conn)
        })
    }

    pub fn update_profile_name(
        &self,
        profile_id: Uuid,
        name: String,
    ) -> Result<PlayerProfile, ProfileStorageError> {
        let name = validate_name(&name)?;
        self.with_connection(|conn| {
            require_profile(conn, profile_id)?;
            let now = sqlite_utc_now(conn)?;
            conn.execute(
                "UPDATE player_profiles
                 SET name = ?1, updated_at = ?2
                 WHERE id = ?3",
                params![name, now, profile_id.to_string()],
            )?;
            read_profile(conn, profile_id)
        })
    }

    pub fn load_settings_snapshot(
        &self,
        player_id: Uuid,
    ) -> Result<SettingsSnapshot, ProfileStorageError> {
        self.with_connection(|conn| {
            require_profile(conn, player_id)?;
            ensure_profile_preferences_row(conn, player_id)?;
            Ok(SettingsSnapshot {
                app: app_settings(conn)?,
                profile: profile_settings(conn, player_id)?,
            })
        })
    }

    pub fn update_app_settings(
        &self,
        settings: AppSettings,
    ) -> Result<AppSettings, ProfileStorageError> {
        self.with_connection(|conn| {
            if let Some(profile_id) = settings.last_active_profile_id {
                require_profile(conn, profile_id)?;
            }

            set_active_profile_id(conn, settings.last_active_profile_id)?;
            set_app_setting(
                conn,
                AUDIO_OUTPUT_DEVICE_KEY,
                settings
                    .audio_output_device_id
                    .and_then(normalize_optional_text),
            )?;
            app_settings(conn)
        })
    }

    pub fn update_profile_settings(
        &self,
        player_id: Uuid,
        update: ProfileSettingsUpdate,
    ) -> Result<ProfileSettings, ProfileStorageError> {
        validate_profile_settings_update(&update)?;
        self.with_connection(|conn| {
            require_profile(conn, player_id)?;
            ensure_profile_preferences_row(conn, player_id)?;
            if let Some(device_profile_id) = update.active_device_profile_id {
                require_owned_device_profile(conn, player_id, device_profile_id)?;
            }

            let now = sqlite_utc_now(conn)?;
            conn.execute(
                "UPDATE player_profiles
                 SET preferred_view = ?1, updated_at = ?2
                 WHERE id = ?3",
                params![update.preferred_view.as_str(), now, player_id.to_string()],
            )?;
            conn.execute(
                "UPDATE profile_preferences
                 SET theme = ?1,
                     reduce_motion = ?2,
                     high_contrast = ?3,
                     metronome_volume = ?4,
                     metronome_click_sound = ?5,
                     auto_pause_enabled = ?6,
                     auto_pause_timeout_ms = ?7,
                     record_practice_mode_attempts = ?8,
                     daily_goal_minutes = ?9,
                     play_kit_hit_sounds = ?10,
                     active_device_profile_id = ?11,
                     updated_at = ?12
                 WHERE player_id = ?13",
                params![
                    update.theme.as_str(),
                    bool_to_db(update.reduce_motion),
                    bool_to_db(update.high_contrast),
                    update.metronome_volume,
                    update.metronome_click_sound.as_str(),
                    bool_to_db(update.auto_pause_enabled),
                    update.auto_pause_timeout_ms,
                    bool_to_db(update.record_practice_mode_attempts),
                    update.daily_goal_minutes,
                    bool_to_db(update.play_kit_hit_sounds),
                    update.active_device_profile_id.map(|id| id.to_string()),
                    now,
                    player_id.to_string(),
                ],
            )?;
            profile_settings(conn, player_id)
        })
    }

    pub fn delete_profile(
        &self,
        profile_id: Uuid,
    ) -> Result<LocalProfileState, ProfileStorageError> {
        self.with_connection(|conn| {
            let deleted = conn.execute(
                "DELETE FROM player_profiles WHERE id = ?1",
                params![profile_id.to_string()],
            )?;
            if deleted == 0 {
                return Err(ProfileStorageError::ProfileNotFound(profile_id));
            }

            let active = active_profile_id(conn)?;
            if active == Some(profile_id) {
                let replacement = most_recent_profile_id(conn)?;
                set_active_profile_id(conn, replacement)?;
            }

            state(conn)
        })
    }

    fn with_connection<T>(
        &self,
        f: impl FnOnce(&Connection) -> Result<T, ProfileStorageError>,
    ) -> Result<T, ProfileStorageError> {
        if let Some(parent) = self.db_path.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|err| ProfileStorageError::Database(err.to_string()))?;
        }

        let conn = Connection::open(&self.db_path)?;
        conn.execute_batch("PRAGMA foreign_keys = ON;")?;
        f(&conn)
    }
}

pub fn parse_profile_id(value: &str) -> Result<Uuid, ProfileStorageError> {
    Uuid::parse_str(value).map_err(|_| ProfileStorageError::InvalidProfileId(value.to_owned()))
}

fn apply_schema(conn: &Connection) -> Result<(), ProfileStorageError> {
    conn.execute_batch(
        "
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS player_profiles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL CHECK (length(trim(name)) > 0),
            avatar TEXT,
            experience_level TEXT NOT NULL CHECK (
                experience_level IN ('beginner', 'intermediate', 'teacher')
            ),
            preferred_view TEXT NOT NULL CHECK (
                preferred_view IN ('note_highway', 'notation')
            ),
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS profile_preferences (
            player_id TEXT PRIMARY KEY NOT NULL
                REFERENCES player_profiles(id) ON DELETE CASCADE,
            theme TEXT NOT NULL DEFAULT 'system' CHECK (
                theme IN ('system', 'light', 'dark')
            ),
            reduce_motion INTEGER NOT NULL DEFAULT 0 CHECK (reduce_motion IN (0, 1)),
            high_contrast INTEGER NOT NULL DEFAULT 0 CHECK (high_contrast IN (0, 1)),
            metronome_volume REAL NOT NULL DEFAULT 0.8 CHECK (
                metronome_volume >= 0.0 AND metronome_volume <= 1.0
            ),
            metronome_click_sound TEXT NOT NULL DEFAULT 'classic' CHECK (
                metronome_click_sound IN ('classic', 'woodblock', 'hi_hat')
            ),
            auto_pause_enabled INTEGER NOT NULL DEFAULT 0 CHECK (auto_pause_enabled IN (0, 1)),
            auto_pause_timeout_ms INTEGER NOT NULL DEFAULT 3000 CHECK (
                auto_pause_timeout_ms > 0
            ),
            record_practice_mode_attempts INTEGER NOT NULL DEFAULT 1 CHECK (
                record_practice_mode_attempts IN (0, 1)
            ),
            daily_goal_minutes INTEGER NOT NULL DEFAULT 10 CHECK (
                daily_goal_minutes > 0
            ),
            play_kit_hit_sounds INTEGER NOT NULL DEFAULT 0 CHECK (
                play_kit_hit_sounds IN (0, 1)
            ),
            active_device_profile_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        PRAGMA user_version = 2;
        ",
    )?;
    ensure_profile_preferences_columns(conn)?;
    Ok(())
}

fn state(conn: &Connection) -> Result<LocalProfileState, ProfileStorageError> {
    let profiles = list_profiles(conn)?;
    let stored_active_profile_id = active_profile_id(conn)?;
    let active_profile_id =
        stored_active_profile_id.filter(|id| profiles.iter().any(|profile| profile.id == *id));

    if active_profile_id != stored_active_profile_id {
        set_active_profile_id(conn, active_profile_id)?;
    }

    Ok(LocalProfileState {
        profiles,
        active_profile_id,
    })
}

fn list_profiles(conn: &Connection) -> Result<Vec<PlayerProfile>, ProfileStorageError> {
    let mut stmt = conn.prepare(
        "SELECT id, name, avatar, experience_level, preferred_view, created_at, updated_at
         FROM player_profiles
         ORDER BY created_at ASC, name COLLATE NOCASE ASC",
    )?;
    let rows = stmt.query_map([], |row| {
        let id_text: String = row.get(0)?;
        let experience_text: String = row.get(3)?;
        let preferred_view_text: String = row.get(4)?;
        Ok((
            id_text,
            row.get::<_, String>(1)?,
            row.get::<_, Option<String>>(2)?,
            experience_text,
            preferred_view_text,
            row.get::<_, String>(5)?,
            row.get::<_, String>(6)?,
        ))
    })?;

    let mut profiles = Vec::new();
    for row in rows {
        let (id_text, name, avatar, experience_text, preferred_view_text, created_at, updated_at) =
            row?;
        profiles.push(PlayerProfile {
            id: parse_profile_id(&id_text)?,
            name,
            avatar,
            experience_level: ExperienceLevel::parse_db_value(&experience_text)?,
            preferred_view: PracticeView::parse_db_value(&preferred_view_text)?,
            created_at,
            updated_at,
        });
    }
    Ok(profiles)
}

fn read_profile(conn: &Connection, profile_id: Uuid) -> Result<PlayerProfile, ProfileStorageError> {
    let row: Option<ProfileDbRow> = conn
        .query_row(
            "SELECT id, name, avatar, experience_level, preferred_view, created_at, updated_at
             FROM player_profiles
             WHERE id = ?1",
            params![profile_id.to_string()],
            |row| {
                Ok((
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                    row.get(5)?,
                    row.get(6)?,
                ))
            },
        )
        .optional()?;

    let Some((id_text, name, avatar, experience_text, preferred_view_text, created_at, updated_at)) =
        row
    else {
        return Err(ProfileStorageError::ProfileNotFound(profile_id));
    };

    Ok(PlayerProfile {
        id: parse_profile_id(&id_text)?,
        name,
        avatar,
        experience_level: ExperienceLevel::parse_db_value(&experience_text)?,
        preferred_view: PracticeView::parse_db_value(&preferred_view_text)?,
        created_at,
        updated_at,
    })
}

fn app_settings(conn: &Connection) -> Result<AppSettings, ProfileStorageError> {
    let stored_active_profile_id = active_profile_id(conn)?;
    let last_active_profile_id = match stored_active_profile_id {
        Some(profile_id) if profile_exists(conn, profile_id)?.is_some() => Some(profile_id),
        Some(_) => {
            set_active_profile_id(conn, None)?;
            None
        }
        None => None,
    };

    Ok(AppSettings {
        last_active_profile_id,
        audio_output_device_id: get_app_setting(conn, AUDIO_OUTPUT_DEVICE_KEY)?,
    })
}

fn profile_settings(
    conn: &Connection,
    player_id: Uuid,
) -> Result<ProfileSettings, ProfileStorageError> {
    ensure_profile_preferences_row(conn, player_id)?;
    let profile = read_profile(conn, player_id)?;
    let (
        theme_text,
        reduce_motion,
        high_contrast,
        metronome_volume,
        click_sound_text,
        auto_pause_enabled,
        auto_pause_timeout_ms,
        record_practice_mode_attempts,
        daily_goal_minutes,
        play_kit_hit_sounds,
        active_device_profile_text,
        updated_at,
    ): ProfileSettingsDbRow = conn.query_row(
        "SELECT theme,
                    reduce_motion,
                    high_contrast,
                    metronome_volume,
                    metronome_click_sound,
                    auto_pause_enabled,
                    auto_pause_timeout_ms,
                    record_practice_mode_attempts,
                    daily_goal_minutes,
                    play_kit_hit_sounds,
                    active_device_profile_id,
                    updated_at
             FROM profile_preferences
             WHERE player_id = ?1",
        params![player_id.to_string()],
        |row| {
            Ok((
                row.get(0)?,
                row.get(1)?,
                row.get(2)?,
                row.get(3)?,
                row.get(4)?,
                row.get(5)?,
                row.get(6)?,
                row.get(7)?,
                row.get(8)?,
                row.get(9)?,
                row.get(10)?,
                row.get(11)?,
            ))
        },
    )?;

    let mut active_device_profile_id = active_device_profile_text
        .map(|id| parse_profile_id(&id))
        .transpose()?;
    if let Some(device_profile_id) = active_device_profile_id {
        if !device_profile_owned_by(conn, player_id, device_profile_id)? {
            conn.execute(
                "UPDATE profile_preferences
                 SET active_device_profile_id = NULL
                 WHERE player_id = ?1",
                params![player_id.to_string()],
            )?;
            active_device_profile_id = None;
        }
    }

    Ok(ProfileSettings {
        player_id,
        preferred_view: profile.preferred_view,
        theme: ThemePreference::parse_db_value(&theme_text)?,
        reduce_motion: db_to_bool(reduce_motion),
        high_contrast: db_to_bool(high_contrast),
        metronome_volume,
        metronome_click_sound: ClickSoundPreset::parse_db_value(&click_sound_text)?,
        auto_pause_enabled: db_to_bool(auto_pause_enabled),
        auto_pause_timeout_ms,
        record_practice_mode_attempts: db_to_bool(record_practice_mode_attempts),
        daily_goal_minutes,
        play_kit_hit_sounds: db_to_bool(play_kit_hit_sounds),
        active_device_profile_id,
        updated_at,
    })
}

fn validate_name(value: &str) -> Result<String, ProfileStorageError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(ProfileStorageError::InvalidName);
    }
    Ok(trimmed.to_owned())
}

fn normalize_optional_text(value: String) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}

fn validate_profile_settings_update(
    update: &ProfileSettingsUpdate,
) -> Result<(), ProfileStorageError> {
    if !update.metronome_volume.is_finite()
        || update.metronome_volume < 0.0
        || update.metronome_volume > 1.0
    {
        return Err(ProfileStorageError::InvalidRange {
            field: "metronome_volume",
            message: "must be finite and in the range 0.0..=1.0".to_owned(),
        });
    }

    if update.auto_pause_timeout_ms == 0 {
        return Err(ProfileStorageError::InvalidRange {
            field: "auto_pause_timeout_ms",
            message: "must be greater than 0".to_owned(),
        });
    }

    if update.daily_goal_minutes == 0 {
        return Err(ProfileStorageError::InvalidRange {
            field: "daily_goal_minutes",
            message: "must be greater than 0".to_owned(),
        });
    }

    Ok(())
}

fn bool_to_db(value: bool) -> i64 {
    if value {
        1
    } else {
        0
    }
}

fn db_to_bool(value: i64) -> bool {
    value != 0
}

fn sqlite_utc_now(conn: &Connection) -> Result<String, ProfileStorageError> {
    conn.query_row("SELECT strftime('%Y-%m-%dT%H:%M:%SZ', 'now')", [], |row| {
        row.get(0)
    })
    .map_err(ProfileStorageError::from)
}

fn require_profile(conn: &Connection, profile_id: Uuid) -> Result<(), ProfileStorageError> {
    profile_exists(conn, profile_id)?
        .map(|_| ())
        .ok_or(ProfileStorageError::ProfileNotFound(profile_id))
}

fn profile_exists(conn: &Connection, profile_id: Uuid) -> Result<Option<i32>, ProfileStorageError> {
    conn.query_row(
        "SELECT 1 FROM player_profiles WHERE id = ?1",
        params![profile_id.to_string()],
        |row| row.get(0),
    )
    .optional()
    .map_err(ProfileStorageError::from)
}

fn require_owned_device_profile(
    conn: &Connection,
    player_id: Uuid,
    device_profile_id: Uuid,
) -> Result<(), ProfileStorageError> {
    if device_profile_owned_by(conn, player_id, device_profile_id)? {
        Ok(())
    } else {
        Err(ProfileStorageError::DeviceProfileNotFound(
            device_profile_id,
        ))
    }
}

fn device_profile_owned_by(
    conn: &Connection,
    player_id: Uuid,
    device_profile_id: Uuid,
) -> Result<bool, ProfileStorageError> {
    if !table_exists(conn, "device_profiles")? {
        return Ok(false);
    }

    let exists: Option<i32> = conn
        .query_row(
            "SELECT 1 FROM device_profiles WHERE id = ?1 AND player_id = ?2",
            params![device_profile_id.to_string(), player_id.to_string()],
            |row| row.get(0),
        )
        .optional()?;
    Ok(exists.is_some())
}

fn ensure_profile_preferences_row(
    conn: &Connection,
    profile_id: Uuid,
) -> Result<(), ProfileStorageError> {
    let now = sqlite_utc_now(conn)?;
    conn.execute(
        "INSERT INTO profile_preferences (player_id, created_at, updated_at)
         VALUES (?1, ?2, ?2)
         ON CONFLICT(player_id) DO NOTHING",
        params![profile_id.to_string(), now],
    )?;
    Ok(())
}

fn active_profile_id(conn: &Connection) -> Result<Option<Uuid>, ProfileStorageError> {
    let value: Option<String> = conn
        .query_row(
            "SELECT value FROM app_settings WHERE key = ?1",
            params![ACTIVE_PROFILE_KEY],
            |row| row.get(0),
        )
        .optional()?;
    value.map(|id| parse_profile_id(&id)).transpose()
}

fn get_app_setting(conn: &Connection, key: &str) -> Result<Option<String>, ProfileStorageError> {
    conn.query_row(
        "SELECT value FROM app_settings WHERE key = ?1",
        params![key],
        |row| row.get(0),
    )
    .optional()
    .map_err(ProfileStorageError::from)
}

fn set_app_setting(
    conn: &Connection,
    key: &str,
    value: Option<String>,
) -> Result<(), ProfileStorageError> {
    match value {
        Some(value) => {
            conn.execute(
                "INSERT INTO app_settings (key, value)
                 VALUES (?1, ?2)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                params![key, value],
            )?;
        }
        None => {
            conn.execute("DELETE FROM app_settings WHERE key = ?1", params![key])?;
        }
    }
    Ok(())
}

fn set_active_profile_id(
    conn: &Connection,
    profile_id: Option<Uuid>,
) -> Result<(), ProfileStorageError> {
    match profile_id {
        Some(id) => {
            conn.execute(
                "INSERT INTO app_settings (key, value)
                 VALUES (?1, ?2)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                params![ACTIVE_PROFILE_KEY, id.to_string()],
            )?;
        }
        None => {
            conn.execute(
                "DELETE FROM app_settings WHERE key = ?1",
                params![ACTIVE_PROFILE_KEY],
            )?;
        }
    }
    Ok(())
}

fn ensure_profile_preferences_columns(conn: &Connection) -> Result<(), ProfileStorageError> {
    ensure_column(
        conn,
        "profile_preferences",
        "theme",
        "ALTER TABLE profile_preferences ADD COLUMN theme TEXT NOT NULL DEFAULT 'system'",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "metronome_volume",
        "ALTER TABLE profile_preferences ADD COLUMN metronome_volume REAL NOT NULL DEFAULT 0.8",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "metronome_click_sound",
        "ALTER TABLE profile_preferences ADD COLUMN metronome_click_sound TEXT NOT NULL DEFAULT 'classic'",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "auto_pause_enabled",
        "ALTER TABLE profile_preferences ADD COLUMN auto_pause_enabled INTEGER NOT NULL DEFAULT 0",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "auto_pause_timeout_ms",
        "ALTER TABLE profile_preferences ADD COLUMN auto_pause_timeout_ms INTEGER NOT NULL DEFAULT 3000",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "record_practice_mode_attempts",
        "ALTER TABLE profile_preferences ADD COLUMN record_practice_mode_attempts INTEGER NOT NULL DEFAULT 1",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "daily_goal_minutes",
        "ALTER TABLE profile_preferences ADD COLUMN daily_goal_minutes INTEGER NOT NULL DEFAULT 10",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "play_kit_hit_sounds",
        "ALTER TABLE profile_preferences ADD COLUMN play_kit_hit_sounds INTEGER NOT NULL DEFAULT 0",
    )?;
    ensure_column(
        conn,
        "profile_preferences",
        "active_device_profile_id",
        "ALTER TABLE profile_preferences ADD COLUMN active_device_profile_id TEXT",
    )?;
    Ok(())
}

fn ensure_column(
    conn: &Connection,
    table: &str,
    column: &str,
    alter_sql: &str,
) -> Result<(), ProfileStorageError> {
    if !column_exists(conn, table, column)? {
        conn.execute_batch(alter_sql)?;
    }
    Ok(())
}

fn column_exists(
    conn: &Connection,
    table: &str,
    column: &str,
) -> Result<bool, ProfileStorageError> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let rows = stmt.query_map([], |row| row.get::<_, String>(1))?;
    for row in rows {
        if row? == column {
            return Ok(true);
        }
    }
    Ok(false)
}

fn table_exists(conn: &Connection, table: &str) -> Result<bool, ProfileStorageError> {
    let exists: Option<i32> = conn
        .query_row(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?1",
            params![table],
            |row| row.get(0),
        )
        .optional()?;
    Ok(exists.is_some())
}

fn most_recent_profile_id(conn: &Connection) -> Result<Option<Uuid>, ProfileStorageError> {
    let value: Option<String> = conn
        .query_row(
            "SELECT id FROM player_profiles
             ORDER BY updated_at DESC, created_at DESC, name COLLATE NOCASE ASC
             LIMIT 1",
            [],
            |row| row.get(0),
        )
        .optional()?;
    value.map(|id| parse_profile_id(&id)).transpose()
}
