use serde::Serialize;

use crate::storage::profiles::{
    parse_profile_id, AppSettings, LocalProfileStore, ProfileSettingsUpdate, ProfileStorageError,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SettingsOperationResult {
    pub settings_json: Option<String>,
    pub error: Option<String>,
}

impl SettingsOperationResult {
    fn settings<T: Serialize>(settings: T) -> Self {
        match serde_json::to_string(&settings) {
            Ok(settings_json) => Self {
                settings_json: Some(settings_json),
                error: None,
            },
            Err(error) => Self::err(ProfileStorageError::Database(error.to_string())),
        }
    }

    fn err(error: ProfileStorageError) -> Self {
        Self {
            settings_json: None,
            error: Some(error.to_string()),
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn load_settings_snapshot(database_path: String, player_id: String) -> SettingsOperationResult {
    run(database_path, |store| {
        let player_id = parse_profile_id(&player_id)?;
        store
            .load_settings_snapshot(player_id)
            .map(SettingsOperationResult::settings)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_app_settings(
    database_path: String,
    settings_json: String,
) -> SettingsOperationResult {
    run(database_path, |store| {
        let settings = serde_json::from_str::<AppSettings>(&settings_json)
            .map_err(|error| ProfileStorageError::Database(error.to_string()))?;
        store
            .update_app_settings(settings)
            .map(SettingsOperationResult::settings)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_profile_settings(
    database_path: String,
    player_id: String,
    settings_update_json: String,
) -> SettingsOperationResult {
    run(database_path, |store| {
        let player_id = parse_profile_id(&player_id)?;
        let update = serde_json::from_str::<ProfileSettingsUpdate>(&settings_update_json)
            .map_err(|error| ProfileStorageError::Database(error.to_string()))?;
        store
            .update_profile_settings(player_id, update)
            .map(SettingsOperationResult::settings)
    })
}

fn run(
    database_path: String,
    f: impl FnOnce(&LocalProfileStore) -> Result<SettingsOperationResult, ProfileStorageError>,
) -> SettingsOperationResult {
    match LocalProfileStore::open(database_path).and_then(|store| f(&store)) {
        Ok(result) => result,
        Err(error) => SettingsOperationResult::err(error),
    }
}
