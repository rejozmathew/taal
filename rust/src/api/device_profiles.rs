use crate::midi::{load_device_profile, DeviceFingerprint, DeviceProfile, VelocityCurve};
use crate::storage::device_profiles::{
    parse_player_or_device_profile_id, DeviceProfileStorageError, DeviceProfileStore,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VelocityCurveDto {
    Linear,
    Soft,
    Hard,
}

impl From<VelocityCurveDto> for VelocityCurve {
    fn from(value: VelocityCurveDto) -> Self {
        match value {
            VelocityCurveDto::Linear => Self::Linear,
            VelocityCurveDto::Soft => Self::Soft,
            VelocityCurveDto::Hard => Self::Hard,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceProfileOperationResult {
    pub profile_json: Option<String>,
    pub profiles_json: Vec<String>,
    pub error: Option<String>,
}

impl DeviceProfileOperationResult {
    fn profile(profile: DeviceProfile) -> Self {
        match serde_json::to_string(&profile) {
            Ok(profile_json) => Self {
                profile_json: Some(profile_json),
                profiles_json: Vec::new(),
                error: None,
            },
            Err(error) => Self::err(DeviceProfileStorageError::Json(error.to_string())),
        }
    }

    fn profiles(profiles: Vec<DeviceProfile>) -> Self {
        let mut profiles_json = Vec::with_capacity(profiles.len());
        for profile in profiles {
            match serde_json::to_string(&profile) {
                Ok(json) => profiles_json.push(json),
                Err(error) => {
                    return Self::err(DeviceProfileStorageError::Json(error.to_string()));
                }
            }
        }
        Self {
            profile_json: None,
            profiles_json,
            error: None,
        }
    }

    fn empty() -> Self {
        Self {
            profile_json: None,
            profiles_json: Vec::new(),
            error: None,
        }
    }

    fn err(error: DeviceProfileStorageError) -> Self {
        Self {
            profile_json: None,
            profiles_json: Vec::new(),
            error: Some(error.to_string()),
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_persisted_device_profiles(
    database_path: String,
    player_id: String,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        store
            .list_profiles(player_id)
            .map(DeviceProfileOperationResult::profiles)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_persisted_device_profile(
    database_path: String,
    player_id: String,
    profile_json: String,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        let profile = load_device_profile(&profile_json)?;
        store
            .create_profile(player_id, profile)
            .map(DeviceProfileOperationResult::profile)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_persisted_device_profile(
    database_path: String,
    player_id: String,
    profile_json: String,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        let profile = load_device_profile(&profile_json)?;
        store
            .update_profile(player_id, profile)
            .map(DeviceProfileOperationResult::profile)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_device_profile_settings(
    database_path: String,
    player_id: String,
    device_profile_id: String,
    input_offset_ms: f32,
    velocity_curve: VelocityCurveDto,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        let device_profile_id = parse_player_or_device_profile_id(&device_profile_id)?;
        store
            .update_device_profile_settings(
                player_id,
                device_profile_id,
                input_offset_ms,
                velocity_curve.into(),
            )
            .map(DeviceProfileOperationResult::profile)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn delete_persisted_device_profile(
    database_path: String,
    player_id: String,
    device_profile_id: String,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        let device_profile_id = parse_player_or_device_profile_id(&device_profile_id)?;
        store.delete_profile(player_id, device_profile_id)?;
        Ok(DeviceProfileOperationResult::empty())
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_last_used_device_profile(
    database_path: String,
    player_id: String,
    device_profile_id: String,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        let device_profile_id = parse_player_or_device_profile_id(&device_profile_id)?;
        store
            .set_last_used_profile(player_id, device_profile_id)
            .map(DeviceProfileOperationResult::profile)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn last_used_device_profile_for_device(
    database_path: String,
    player_id: String,
    vendor_name: Option<String>,
    model_name: Option<String>,
    platform_id: Option<String>,
) -> DeviceProfileOperationResult {
    run(database_path, |store| {
        let player_id = parse_player_or_device_profile_id(&player_id)?;
        let fingerprint = DeviceFingerprint {
            vendor_name,
            model_name,
            platform_id,
        };
        match store.last_used_profile_for_device(player_id, fingerprint)? {
            Some(profile) => Ok(DeviceProfileOperationResult::profile(profile)),
            None => Ok(DeviceProfileOperationResult::empty()),
        }
    })
}

fn run(
    database_path: String,
    f: impl FnOnce(
        &DeviceProfileStore,
    ) -> Result<DeviceProfileOperationResult, DeviceProfileStorageError>,
) -> DeviceProfileOperationResult {
    match DeviceProfileStore::open(database_path).and_then(|store| f(&store)) {
        Ok(result) => result,
        Err(error) => DeviceProfileOperationResult::err(error),
    }
}
