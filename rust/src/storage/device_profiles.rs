use std::error::Error;
use std::fmt::{self, Display};
use std::path::{Path, PathBuf};

use rusqlite::{params, Connection, OptionalExtension};
use uuid::Uuid;

use crate::midi::{DeviceFingerprint, DeviceProfile, MidiMappingError, VelocityCurve};
use crate::storage::profiles::{parse_profile_id, LocalProfileStore, ProfileStorageError};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeviceProfileStorageError {
    Database(String),
    InvalidProfileId(String),
    PlayerNotFound(Uuid),
    DeviceProfileNotFound(Uuid),
    SettingsViolation(String),
    Mapping(MidiMappingError),
    Json(String),
    ProfileStorage(String),
}

impl Display for DeviceProfileStorageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Database(message) => write!(f, "device profile database error: {message}"),
            Self::InvalidProfileId(value) => write!(f, "invalid profile id: {value}"),
            Self::PlayerNotFound(id) => write!(f, "player profile not found: {id}"),
            Self::DeviceProfileNotFound(id) => write!(f, "device profile not found: {id}"),
            Self::SettingsViolation(message) => {
                write!(f, "device profile settings error: {message}")
            }
            Self::Mapping(error) => write!(f, "{error}"),
            Self::Json(message) => write!(f, "device profile JSON error: {message}"),
            Self::ProfileStorage(message) => write!(f, "profile storage error: {message}"),
        }
    }
}

impl Error for DeviceProfileStorageError {}

impl From<rusqlite::Error> for DeviceProfileStorageError {
    fn from(error: rusqlite::Error) -> Self {
        Self::Database(error.to_string())
    }
}

impl From<MidiMappingError> for DeviceProfileStorageError {
    fn from(error: MidiMappingError) -> Self {
        Self::Mapping(error)
    }
}

impl From<serde_json::Error> for DeviceProfileStorageError {
    fn from(error: serde_json::Error) -> Self {
        Self::Json(error.to_string())
    }
}

impl From<ProfileStorageError> for DeviceProfileStorageError {
    fn from(error: ProfileStorageError) -> Self {
        Self::ProfileStorage(error.to_string())
    }
}

#[derive(Debug, Clone)]
pub struct DeviceProfileStore {
    db_path: PathBuf,
}

impl DeviceProfileStore {
    pub fn open(db_path: impl Into<PathBuf>) -> Result<Self, DeviceProfileStorageError> {
        let db_path = db_path.into();
        LocalProfileStore::open(&db_path)?;
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

    pub fn create_profile(
        &self,
        player_id: Uuid,
        profile: DeviceProfile,
    ) -> Result<DeviceProfile, DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            profile.validate()?;
            let profile_json = serde_json::to_string(&profile)?;
            let profile_id = profile.id;
            let transport_json = serde_json::to_string(&profile.transport)?;
            conn.execute(
                "INSERT INTO device_profiles (
                    id, player_id, name, instrument_family, layout_id,
                    vendor_name, model_name, platform_id, transport, midi_channel,
                    input_offset_ms, preset_origin, profile_json, created_at, updated_at
                 ) VALUES (
                    ?1, ?2, ?3, ?4, ?5,
                    ?6, ?7, ?8, ?9, ?10,
                    ?11, ?12, ?13, ?14, ?15
                 )",
                params![
                    profile_id.to_string(),
                    player_id.to_string(),
                    &profile.name,
                    &profile.instrument_family,
                    &profile.layout_id,
                    profile.device_fingerprint.vendor_name.as_deref(),
                    profile.device_fingerprint.model_name.as_deref(),
                    profile.device_fingerprint.platform_id.as_deref(),
                    transport_json,
                    profile.midi_channel,
                    profile.input_offset_ms,
                    profile.preset_origin.as_deref(),
                    profile_json,
                    &profile.created_at,
                    &profile.updated_at,
                ],
            )?;
            read_profile(conn, player_id, profile_id)
        })
    }

    pub fn update_profile(
        &self,
        player_id: Uuid,
        profile: DeviceProfile,
    ) -> Result<DeviceProfile, DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            profile.validate()?;
            let profile_json = serde_json::to_string(&profile)?;
            let profile_id = profile.id;
            let transport_json = serde_json::to_string(&profile.transport)?;
            let updated = conn.execute(
                "UPDATE device_profiles
                 SET name = ?1,
                     instrument_family = ?2,
                     layout_id = ?3,
                     vendor_name = ?4,
                     model_name = ?5,
                     platform_id = ?6,
                     transport = ?7,
                     midi_channel = ?8,
                     input_offset_ms = ?9,
                     preset_origin = ?10,
                     profile_json = ?11,
                     created_at = ?12,
                     updated_at = ?13
                 WHERE id = ?14 AND player_id = ?15",
                params![
                    &profile.name,
                    &profile.instrument_family,
                    &profile.layout_id,
                    profile.device_fingerprint.vendor_name.as_deref(),
                    profile.device_fingerprint.model_name.as_deref(),
                    profile.device_fingerprint.platform_id.as_deref(),
                    transport_json,
                    profile.midi_channel,
                    profile.input_offset_ms,
                    profile.preset_origin.as_deref(),
                    profile_json,
                    &profile.created_at,
                    &profile.updated_at,
                    profile_id.to_string(),
                    player_id.to_string(),
                ],
            )?;
            if updated == 0 {
                return Err(DeviceProfileStorageError::DeviceProfileNotFound(profile_id));
            }
            read_profile(conn, player_id, profile_id)
        })
    }

    pub fn update_device_profile_settings(
        &self,
        player_id: Uuid,
        device_profile_id: Uuid,
        input_offset_ms: f32,
        velocity_curve: VelocityCurve,
    ) -> Result<DeviceProfile, DeviceProfileStorageError> {
        if !input_offset_ms.is_finite() || !(-50.0..=50.0).contains(&input_offset_ms) {
            return Err(DeviceProfileStorageError::SettingsViolation(
                "input_offset_ms must be finite and in the range -50.0..=50.0".to_owned(),
            ));
        }

        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            let mut profile = read_profile(conn, player_id, device_profile_id)?;
            profile.input_offset_ms = input_offset_ms;
            profile.velocity_curve = velocity_curve;
            profile.updated_at = sqlite_utc_now(conn)?;
            update_profile_row(conn, player_id, profile)
        })
    }

    pub fn list_profiles(
        &self,
        player_id: Uuid,
    ) -> Result<Vec<DeviceProfile>, DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            list_profiles(conn, player_id)
        })
    }

    pub fn read_profile(
        &self,
        player_id: Uuid,
        device_profile_id: Uuid,
    ) -> Result<DeviceProfile, DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            read_profile(conn, player_id, device_profile_id)
        })
    }

    pub fn delete_profile(
        &self,
        player_id: Uuid,
        device_profile_id: Uuid,
    ) -> Result<(), DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            let deleted = conn.execute(
                "DELETE FROM device_profiles WHERE id = ?1 AND player_id = ?2",
                params![device_profile_id.to_string(), player_id.to_string()],
            )?;
            if deleted == 0 {
                return Err(DeviceProfileStorageError::DeviceProfileNotFound(
                    device_profile_id,
                ));
            }
            conn.execute(
                "UPDATE profile_preferences
                 SET active_device_profile_id = NULL
                 WHERE player_id = ?1 AND active_device_profile_id = ?2",
                params![player_id.to_string(), device_profile_id.to_string()],
            )?;
            Ok(())
        })
    }

    pub fn set_last_used_profile(
        &self,
        player_id: Uuid,
        device_profile_id: Uuid,
    ) -> Result<DeviceProfile, DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            let profile = read_profile(conn, player_id, device_profile_id)?;
            let fingerprint = &profile.device_fingerprint;
            let now = sqlite_utc_now(conn)?;
            let sequence = next_last_used_sequence(conn)?;
            conn.execute(
                "INSERT INTO last_used_device_profiles (
                    player_id, vendor_key, model_key, platform_key,
                    profile_id, last_used_at, last_used_seq
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                 ON CONFLICT(player_id, vendor_key, model_key, platform_key)
                 DO UPDATE SET
                    profile_id = excluded.profile_id,
                    last_used_at = excluded.last_used_at,
                    last_used_seq = excluded.last_used_seq",
                params![
                    player_id.to_string(),
                    key_part(&fingerprint.vendor_name),
                    key_part(&fingerprint.model_name),
                    key_part(&fingerprint.platform_id),
                    device_profile_id.to_string(),
                    now,
                    sequence,
                ],
            )?;
            Ok(profile)
        })
    }

    pub fn last_used_profile_for_device(
        &self,
        player_id: Uuid,
        fingerprint: DeviceFingerprint,
    ) -> Result<Option<DeviceProfile>, DeviceProfileStorageError> {
        self.with_connection(|conn| {
            require_player(conn, player_id)?;
            last_used_profile_for_device(conn, player_id, &fingerprint)
        })
    }

    fn with_connection<T>(
        &self,
        f: impl FnOnce(&Connection) -> Result<T, DeviceProfileStorageError>,
    ) -> Result<T, DeviceProfileStorageError> {
        let conn = Connection::open(&self.db_path)?;
        conn.execute_batch("PRAGMA foreign_keys = ON;")?;
        f(&conn)
    }
}

pub fn parse_player_or_device_profile_id(value: &str) -> Result<Uuid, DeviceProfileStorageError> {
    parse_profile_id(value).map_err(|_| DeviceProfileStorageError::InvalidProfileId(value.into()))
}

fn apply_schema(conn: &Connection) -> Result<(), DeviceProfileStorageError> {
    conn.execute_batch(
        "
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS device_profiles (
            id TEXT PRIMARY KEY,
            player_id TEXT NOT NULL
                REFERENCES player_profiles(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            instrument_family TEXT NOT NULL,
            layout_id TEXT NOT NULL,
            vendor_name TEXT,
            model_name TEXT,
            platform_id TEXT,
            transport TEXT NOT NULL,
            midi_channel INTEGER,
            input_offset_ms REAL NOT NULL,
            preset_origin TEXT,
            profile_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_device_profiles_player
            ON device_profiles(player_id);

        CREATE INDEX IF NOT EXISTS idx_device_profiles_reconnect
            ON device_profiles(player_id, vendor_name, model_name, platform_id);

        CREATE TABLE IF NOT EXISTS last_used_device_profiles (
            player_id TEXT NOT NULL
                REFERENCES player_profiles(id) ON DELETE CASCADE,
            vendor_key TEXT NOT NULL,
            model_key TEXT NOT NULL,
            platform_key TEXT NOT NULL,
            profile_id TEXT NOT NULL
                REFERENCES device_profiles(id) ON DELETE CASCADE,
            last_used_at TEXT NOT NULL,
            last_used_seq INTEGER NOT NULL,
            PRIMARY KEY(player_id, vendor_key, model_key, platform_key)
        );

        CREATE INDEX IF NOT EXISTS idx_last_used_device_profiles_lookup
            ON last_used_device_profiles(player_id, vendor_key, model_key, last_used_at);
        ",
    )?;
    Ok(())
}

fn require_player(conn: &Connection, player_id: Uuid) -> Result<(), DeviceProfileStorageError> {
    let exists: Option<i32> = conn
        .query_row(
            "SELECT 1 FROM player_profiles WHERE id = ?1",
            params![player_id.to_string()],
            |row| row.get(0),
        )
        .optional()?;
    exists
        .map(|_| ())
        .ok_or(DeviceProfileStorageError::PlayerNotFound(player_id))
}

fn list_profiles(
    conn: &Connection,
    player_id: Uuid,
) -> Result<Vec<DeviceProfile>, DeviceProfileStorageError> {
    let mut stmt = conn.prepare(
        "SELECT profile_json FROM device_profiles
         WHERE player_id = ?1
         ORDER BY updated_at DESC, name COLLATE NOCASE ASC",
    )?;
    let rows = stmt.query_map(params![player_id.to_string()], |row| {
        row.get::<_, String>(0)
    })?;

    let mut profiles = Vec::new();
    for row in rows {
        profiles.push(profile_from_json(&row?)?);
    }
    Ok(profiles)
}

fn read_profile(
    conn: &Connection,
    player_id: Uuid,
    device_profile_id: Uuid,
) -> Result<DeviceProfile, DeviceProfileStorageError> {
    let profile_json: Option<String> = conn
        .query_row(
            "SELECT profile_json FROM device_profiles
             WHERE id = ?1 AND player_id = ?2",
            params![device_profile_id.to_string(), player_id.to_string()],
            |row| row.get(0),
        )
        .optional()?;
    profile_json
        .map(|json| profile_from_json(&json))
        .transpose()?
        .ok_or(DeviceProfileStorageError::DeviceProfileNotFound(
            device_profile_id,
        ))
}

fn update_profile_row(
    conn: &Connection,
    player_id: Uuid,
    profile: DeviceProfile,
) -> Result<DeviceProfile, DeviceProfileStorageError> {
    profile.validate()?;
    let profile_json = serde_json::to_string(&profile)?;
    let profile_id = profile.id;
    let transport_json = serde_json::to_string(&profile.transport)?;
    let updated = conn.execute(
        "UPDATE device_profiles
         SET name = ?1,
             instrument_family = ?2,
             layout_id = ?3,
             vendor_name = ?4,
             model_name = ?5,
             platform_id = ?6,
             transport = ?7,
             midi_channel = ?8,
             input_offset_ms = ?9,
             preset_origin = ?10,
             profile_json = ?11,
             created_at = ?12,
             updated_at = ?13
         WHERE id = ?14 AND player_id = ?15",
        params![
            &profile.name,
            &profile.instrument_family,
            &profile.layout_id,
            profile.device_fingerprint.vendor_name.as_deref(),
            profile.device_fingerprint.model_name.as_deref(),
            profile.device_fingerprint.platform_id.as_deref(),
            transport_json,
            profile.midi_channel,
            profile.input_offset_ms,
            profile.preset_origin.as_deref(),
            profile_json,
            &profile.created_at,
            &profile.updated_at,
            profile_id.to_string(),
            player_id.to_string(),
        ],
    )?;
    if updated == 0 {
        return Err(DeviceProfileStorageError::DeviceProfileNotFound(profile_id));
    }
    read_profile(conn, player_id, profile_id)
}

fn profile_from_json(json: &str) -> Result<DeviceProfile, DeviceProfileStorageError> {
    let profile = serde_json::from_str::<DeviceProfile>(json)?;
    profile.validate()?;
    Ok(profile)
}

fn last_used_profile_for_device(
    conn: &Connection,
    player_id: Uuid,
    fingerprint: &DeviceFingerprint,
) -> Result<Option<DeviceProfile>, DeviceProfileStorageError> {
    let vendor_key = key_part(&fingerprint.vendor_name);
    let model_key = key_part(&fingerprint.model_name);
    let platform_key = key_part(&fingerprint.platform_id);

    if !platform_key.is_empty() {
        if let Some(profile) = last_used_profile_by_keys(
            conn,
            player_id,
            &vendor_key,
            &model_key,
            Some(&platform_key),
        )? {
            return Ok(Some(profile));
        }
    }

    last_used_profile_by_keys(conn, player_id, &vendor_key, &model_key, None)
}

fn last_used_profile_by_keys(
    conn: &Connection,
    player_id: Uuid,
    vendor_key: &str,
    model_key: &str,
    platform_key: Option<&str>,
) -> Result<Option<DeviceProfile>, DeviceProfileStorageError> {
    let sql = match platform_key {
        Some(_) => {
            "SELECT dp.profile_json
             FROM last_used_device_profiles last
             JOIN device_profiles dp
               ON dp.id = last.profile_id AND dp.player_id = last.player_id
             WHERE last.player_id = ?1
               AND last.vendor_key = ?2
               AND last.model_key = ?3
               AND last.platform_key = ?4
             ORDER BY last.last_used_seq DESC
             LIMIT 1"
        }
        None => {
            "SELECT dp.profile_json
             FROM last_used_device_profiles last
             JOIN device_profiles dp
               ON dp.id = last.profile_id AND dp.player_id = last.player_id
             WHERE last.player_id = ?1
               AND last.vendor_key = ?2
               AND last.model_key = ?3
             ORDER BY last.last_used_seq DESC
             LIMIT 1"
        }
    };

    let mut stmt = conn.prepare(sql)?;
    let profile_json: Option<String> = match platform_key {
        Some(platform_key) => stmt
            .query_row(
                params![player_id.to_string(), vendor_key, model_key, platform_key],
                |row| row.get(0),
            )
            .optional()?,
        None => stmt
            .query_row(
                params![player_id.to_string(), vendor_key, model_key],
                |row| row.get(0),
            )
            .optional()?,
    };

    profile_json
        .map(|json| profile_from_json(&json))
        .transpose()
}

fn sqlite_utc_now(conn: &Connection) -> Result<String, DeviceProfileStorageError> {
    conn.query_row("SELECT strftime('%Y-%m-%dT%H:%M:%SZ', 'now')", [], |row| {
        row.get(0)
    })
    .map_err(DeviceProfileStorageError::from)
}

fn next_last_used_sequence(conn: &Connection) -> Result<i64, DeviceProfileStorageError> {
    conn.query_row(
        "SELECT COALESCE(MAX(last_used_seq), 0) + 1 FROM last_used_device_profiles",
        [],
        |row| row.get(0),
    )
    .map_err(DeviceProfileStorageError::from)
}

fn key_part(value: &Option<String>) -> String {
    value
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("")
        .to_owned()
}
