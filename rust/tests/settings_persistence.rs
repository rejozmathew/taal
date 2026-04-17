use std::fs;
use std::path::PathBuf;

use taal_core::midi::{
    DeviceFingerprint, DeviceProfile, MidiTransport, NoteMapping, VelocityCurve,
};
use taal_core::storage::device_profiles::DeviceProfileStore;
use taal_core::storage::profiles::{
    AppSettings, ClickSoundPreset, CreateProfileRequest, ExperienceLevel, LocalProfileStore,
    PracticeView, ProfileSettingsUpdate, ThemePreference,
};
use uuid::Uuid;

#[test]
fn settings_snapshot_loads_cr006_defaults() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = LocalProfileStore::open(&db_path).unwrap();

    let snapshot = store.load_settings_snapshot(player_id).unwrap();

    assert_eq!(snapshot.app.last_active_profile_id, Some(player_id));
    assert_eq!(snapshot.app.audio_output_device_id, None);
    assert_eq!(snapshot.profile.player_id, player_id);
    assert_eq!(snapshot.profile.preferred_view, PracticeView::NoteHighway);
    assert_eq!(snapshot.profile.theme, ThemePreference::System);
    assert!(!snapshot.profile.reduce_motion);
    assert!(!snapshot.profile.high_contrast);
    assert_eq!(snapshot.profile.metronome_volume, 0.8);
    assert_eq!(
        snapshot.profile.metronome_click_sound,
        ClickSoundPreset::Classic
    );
    assert!(!snapshot.profile.auto_pause_enabled);
    assert_eq!(snapshot.profile.auto_pause_timeout_ms, 3000);
    assert!(snapshot.profile.record_practice_mode_attempts);
    assert_eq!(snapshot.profile.active_device_profile_id, None);

    cleanup(db_path);
}

#[test]
fn profile_settings_persist_per_player_and_validate_active_device_owner() {
    let db_path = test_db_path();
    let first_player = create_player(&db_path, "Rejo");
    let second_player = create_player(&db_path, "Anya");
    let device_store = DeviceProfileStore::open(&db_path).unwrap();
    let first_device = device_profile("Rejo Kit");
    let second_device = device_profile("Anya Kit");
    device_store
        .create_profile(first_player, first_device.clone())
        .unwrap();
    device_store
        .create_profile(second_player, second_device.clone())
        .unwrap();

    let store = LocalProfileStore::open(&db_path).unwrap();
    let updated = store
        .update_profile_settings(
            first_player,
            ProfileSettingsUpdate {
                preferred_view: PracticeView::Notation,
                theme: ThemePreference::Dark,
                reduce_motion: true,
                high_contrast: true,
                metronome_volume: 0.35,
                metronome_click_sound: ClickSoundPreset::HiHat,
                auto_pause_enabled: true,
                auto_pause_timeout_ms: 4500,
                record_practice_mode_attempts: false,
                active_device_profile_id: Some(first_device.id),
            },
        )
        .unwrap();

    assert_eq!(updated.preferred_view, PracticeView::Notation);
    assert_eq!(updated.theme, ThemePreference::Dark);
    assert_eq!(updated.active_device_profile_id, Some(first_device.id));

    let reopened = LocalProfileStore::open(&db_path).unwrap();
    let snapshot = reopened.load_settings_snapshot(first_player).unwrap();
    assert_eq!(snapshot.profile.metronome_volume, 0.35);
    assert_eq!(
        snapshot.profile.metronome_click_sound,
        ClickSoundPreset::HiHat
    );
    assert_eq!(snapshot.profile.auto_pause_timeout_ms, 4500);
    assert!(!snapshot.profile.record_practice_mode_attempts);

    let wrong_owner = reopened
        .update_profile_settings(
            first_player,
            ProfileSettingsUpdate {
                active_device_profile_id: Some(second_device.id),
                ..settings_update()
            },
        )
        .unwrap_err();
    assert_eq!(
        wrong_owner.to_string(),
        format!("device profile not found: {}", second_device.id)
    );

    cleanup(db_path);
}

#[test]
fn app_settings_store_audio_output_and_last_active_profile() {
    let db_path = test_db_path();
    let first_player = create_player(&db_path, "Rejo");
    let second_player = create_player(&db_path, "Anya");
    let store = LocalProfileStore::open(&db_path).unwrap();

    let updated = store
        .update_app_settings(AppSettings {
            last_active_profile_id: Some(first_player),
            audio_output_device_id: Some("wasapi:headphones".to_owned()),
        })
        .unwrap();
    assert_eq!(updated.last_active_profile_id, Some(first_player));
    assert_eq!(
        updated.audio_output_device_id.as_deref(),
        Some("wasapi:headphones")
    );

    let reopened = LocalProfileStore::open(&db_path).unwrap();
    let snapshot = reopened.load_settings_snapshot(second_player).unwrap();
    assert_eq!(snapshot.app.last_active_profile_id, Some(first_player));
    assert_eq!(
        snapshot.app.audio_output_device_id.as_deref(),
        Some("wasapi:headphones")
    );

    cleanup(db_path);
}

#[test]
fn device_profile_settings_update_effective_offset_and_velocity_curve() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let store = DeviceProfileStore::open(&db_path).unwrap();
    let profile = device_profile("TD-27");
    let profile_id = profile.id;
    store.create_profile(player_id, profile).unwrap();

    let updated = store
        .update_device_profile_settings(player_id, profile_id, -12.5, VelocityCurve::Hard)
        .unwrap();
    assert_eq!(updated.input_offset_ms, -12.5);
    assert_eq!(updated.velocity_curve, VelocityCurve::Hard);

    let error = store
        .update_device_profile_settings(player_id, profile_id, 75.0, VelocityCurve::Soft)
        .unwrap_err();
    assert!(error.to_string().contains("-50.0..=50.0"));

    cleanup(db_path);
}

#[test]
fn deleted_active_device_profile_is_cleared_from_settings() {
    let db_path = test_db_path();
    let player_id = create_player(&db_path, "Rejo");
    let device_store = DeviceProfileStore::open(&db_path).unwrap();
    let profile = device_profile("TD-27");
    let profile_id = profile.id;
    device_store.create_profile(player_id, profile).unwrap();

    let profile_store = LocalProfileStore::open(&db_path).unwrap();
    profile_store
        .update_profile_settings(
            player_id,
            ProfileSettingsUpdate {
                active_device_profile_id: Some(profile_id),
                ..settings_update()
            },
        )
        .unwrap();

    device_store.delete_profile(player_id, profile_id).unwrap();

    let snapshot = profile_store.load_settings_snapshot(player_id).unwrap();
    assert_eq!(snapshot.profile.active_device_profile_id, None);

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

fn settings_update() -> ProfileSettingsUpdate {
    ProfileSettingsUpdate {
        preferred_view: PracticeView::NoteHighway,
        theme: ThemePreference::System,
        reduce_motion: false,
        high_contrast: false,
        metronome_volume: 0.8,
        metronome_click_sound: ClickSoundPreset::Classic,
        auto_pause_enabled: false,
        auto_pause_timeout_ms: 3000,
        record_practice_mode_attempts: true,
        active_device_profile_id: None,
    }
}

fn device_profile(name: &str) -> DeviceProfile {
    DeviceProfile {
        id: Uuid::new_v4(),
        name: name.to_owned(),
        instrument_family: "drums".to_owned(),
        layout_id: "std-5pc-v1".to_owned(),
        device_fingerprint: DeviceFingerprint {
            vendor_name: Some("Roland".to_owned()),
            model_name: Some("TD-27".to_owned()),
            platform_id: Some("winmm:0".to_owned()),
        },
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

fn test_db_path() -> PathBuf {
    std::env::temp_dir().join(format!("taal-settings-{}.sqlite", Uuid::new_v4()))
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
