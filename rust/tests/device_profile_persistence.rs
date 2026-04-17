use std::fs;
use std::path::PathBuf;

use taal_core::midi::{
    DeviceFingerprint, DeviceProfile, MidiTransport, NoteMapping, VelocityCurve,
};
use taal_core::storage::device_profiles::DeviceProfileStore;
use taal_core::storage::profiles::{CreateProfileRequest, ExperienceLevel, LocalProfileStore};
use uuid::Uuid;

#[test]
fn saved_device_profile_survives_reopen() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = DeviceProfileStore::open(&db_path).unwrap();
    let profile = device_profile("Practice Kit", platform("winmm:0"));

    let saved = store.create_profile(player_id, profile.clone()).unwrap();
    assert_eq!(saved, profile);

    let reopened = DeviceProfileStore::open(&db_path).unwrap();
    let profiles = reopened.list_profiles(player_id).unwrap();
    assert_eq!(profiles, vec![profile.clone()]);
    assert_eq!(
        reopened.read_profile(player_id, profile.id).unwrap(),
        profile
    );

    cleanup(db_path);
}

#[test]
fn device_profiles_are_owned_by_player_profile() {
    let db_path = test_db_path();
    let first_player = create_player(&db_path, "Rejo");
    let second_player = create_player(&db_path, "Anya");
    let store = DeviceProfileStore::open(&db_path).unwrap();

    let first_profile = device_profile("Rejo Kit", platform("winmm:0"));
    let second_profile = device_profile("Anya Kit", platform("winmm:0"));
    store
        .create_profile(first_player, first_profile.clone())
        .unwrap();
    store
        .create_profile(second_player, second_profile.clone())
        .unwrap();

    assert_eq!(
        store.list_profiles(first_player).unwrap(),
        vec![first_profile]
    );
    assert_eq!(
        store.list_profiles(second_player).unwrap(),
        vec![second_profile]
    );

    cleanup(db_path);
}

#[test]
fn update_and_delete_device_profile_are_persistent() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = DeviceProfileStore::open(&db_path).unwrap();
    let mut profile = device_profile("Practice Kit", platform("winmm:0"));
    let profile_id = profile.id;

    store.create_profile(player_id, profile.clone()).unwrap();

    profile.name = "Performance Kit".to_owned();
    profile.input_offset_ms = 14.5;
    profile.updated_at = "2026-04-17T12:00:00Z".to_owned();
    let updated = store.update_profile(player_id, profile.clone()).unwrap();
    assert_eq!(updated.name, "Performance Kit");
    assert_eq!(updated.input_offset_ms, 14.5);

    store.delete_profile(player_id, profile_id).unwrap();
    assert!(store.list_profiles(player_id).unwrap().is_empty());
    assert!(store.read_profile(player_id, profile_id).is_err());

    cleanup(db_path);
}

#[test]
fn switching_last_used_profile_supports_multiple_profiles_for_same_device() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = DeviceProfileStore::open(&db_path).unwrap();
    let fingerprint = platform("winmm:0");
    let mut practice = device_profile("Practice Mapping", fingerprint.clone());
    let performance = device_profile("Performance Mapping", fingerprint.clone());
    practice.input_offset_ms = 5.0;

    store.create_profile(player_id, practice.clone()).unwrap();
    store
        .create_profile(player_id, performance.clone())
        .unwrap();

    assert_eq!(
        store
            .set_last_used_profile(player_id, practice.id)
            .unwrap()
            .name,
        "Practice Mapping"
    );
    assert_eq!(
        store
            .last_used_profile_for_device(player_id, fingerprint.clone())
            .unwrap()
            .unwrap()
            .id,
        practice.id
    );

    store
        .set_last_used_profile(player_id, performance.id)
        .unwrap();
    assert_eq!(
        store
            .last_used_profile_for_device(player_id, fingerprint)
            .unwrap()
            .unwrap()
            .id,
        performance.id
    );

    cleanup(db_path);
}

#[test]
fn reconnect_matching_uses_platform_exact_then_vendor_model_fallback() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = DeviceProfileStore::open(&db_path).unwrap();
    let windows_profile = device_profile("Windows Port", platform("winmm:0"));
    let android_profile = device_profile("Android Port", platform("android:2"));

    store
        .create_profile(player_id, windows_profile.clone())
        .unwrap();
    store
        .create_profile(player_id, android_profile.clone())
        .unwrap();
    store
        .set_last_used_profile(player_id, windows_profile.id)
        .unwrap();
    store
        .set_last_used_profile(player_id, android_profile.id)
        .unwrap();

    let exact = store
        .last_used_profile_for_device(player_id, platform("winmm:0"))
        .unwrap()
        .unwrap();
    assert_eq!(exact.id, windows_profile.id);

    let fallback = store
        .last_used_profile_for_device(
            player_id,
            DeviceFingerprint {
                vendor_name: Some("Roland".to_owned()),
                model_name: Some("TD-27".to_owned()),
                platform_id: None,
            },
        )
        .unwrap()
        .unwrap();
    assert_eq!(fallback.id, android_profile.id);

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

fn device_profile(name: &str, fingerprint: DeviceFingerprint) -> DeviceProfile {
    DeviceProfile {
        id: Uuid::new_v4(),
        name: name.to_owned(),
        instrument_family: "drums".to_owned(),
        layout_id: "std-5pc-v1".to_owned(),
        device_fingerprint: fingerprint,
        transport: MidiTransport::Usb,
        midi_channel: Some(9),
        note_map: vec![NoteMapping {
            midi_note: 38,
            lane_id: "snare".to_owned(),
            articulation: "normal".to_owned(),
            min_velocity: 1,
            max_velocity: 127,
        }],
        hihat_model: None,
        input_offset_ms: 0.0,
        dedupe_window_ms: 8.0,
        velocity_curve: VelocityCurve::Linear,
        preset_origin: Some("test".to_owned()),
        created_at: "2026-04-17T10:00:00Z".to_owned(),
        updated_at: "2026-04-17T10:00:00Z".to_owned(),
    }
}

fn platform(platform_id: &str) -> DeviceFingerprint {
    DeviceFingerprint {
        vendor_name: Some("Roland".to_owned()),
        model_name: Some("TD-27".to_owned()),
        platform_id: Some(platform_id.to_owned()),
    }
}

fn test_db_path() -> PathBuf {
    std::env::temp_dir().join(format!(
        "taal-device-profile-persistence-{}.sqlite",
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
