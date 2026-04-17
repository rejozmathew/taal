use std::fs;
use std::path::PathBuf;

use rusqlite::{params, Connection};
use taal_core::storage::profiles::{
    CreateProfileRequest, ExperienceLevel, LocalProfileStore, PracticeView,
};
use uuid::Uuid;

#[test]
fn create_and_switch_profiles_remembers_last_active_profile() {
    let db_path = test_db_path();
    let store = LocalProfileStore::open(&db_path).unwrap();

    let first_state = store.create_profile(profile_request("Rejo")).unwrap();
    let rejo = first_state.active_profile().unwrap().clone();
    assert_eq!(rejo.name, "Rejo");

    let second_state = store.create_profile(profile_request("Anya")).unwrap();
    let anya = second_state.active_profile().unwrap().clone();
    assert_eq!(anya.name, "Anya");
    assert_ne!(rejo.id, anya.id);

    let switched = store.set_active_profile(rejo.id).unwrap();
    assert_eq!(switched.active_profile_id, Some(rejo.id));

    let reopened = LocalProfileStore::open(&db_path).unwrap().state().unwrap();
    assert_eq!(reopened.active_profile_id, Some(rejo.id));

    cleanup(db_path);
}

#[test]
fn profile_preferences_are_separate_per_profile() {
    let db_path = test_db_path();
    let store = LocalProfileStore::open(&db_path).unwrap();

    let first = store.create_profile(profile_request("Rejo")).unwrap();
    let first_id = first.active_profile_id.unwrap();
    let second = store.create_profile(profile_request("Anya")).unwrap();
    let second_id = second.active_profile_id.unwrap();

    let updated = store
        .update_preferred_view(first_id, PracticeView::Notation)
        .unwrap();

    let first_profile = updated
        .profiles
        .iter()
        .find(|profile| profile.id == first_id)
        .unwrap();
    let second_profile = updated
        .profiles
        .iter()
        .find(|profile| profile.id == second_id)
        .unwrap();

    assert_eq!(first_profile.preferred_view, PracticeView::Notation);
    assert_eq!(second_profile.preferred_view, PracticeView::NoteHighway);

    cleanup(db_path);
}

#[test]
fn deleting_profile_cascades_owned_data_and_selects_remaining_profile() {
    let db_path = test_db_path();
    let store = LocalProfileStore::open(&db_path).unwrap();

    let first = store.create_profile(profile_request("Rejo")).unwrap();
    let first_id = first.active_profile_id.unwrap();
    let second = store.create_profile(profile_request("Anya")).unwrap();
    let second_id = second.active_profile_id.unwrap();

    assert_eq!(profile_preference_count(&db_path, second_id), 1);

    let after_delete = store.delete_profile(second_id).unwrap();

    assert_eq!(profile_preference_count(&db_path, second_id), 0);
    assert_eq!(after_delete.active_profile_id, Some(first_id));
    assert_eq!(after_delete.profiles.len(), 1);
    assert_eq!(after_delete.profiles[0].id, first_id);

    cleanup(db_path);
}

#[test]
fn deleting_last_profile_clears_active_profile() {
    let db_path = test_db_path();
    let store = LocalProfileStore::open(&db_path).unwrap();

    let state = store.create_profile(profile_request("Rejo")).unwrap();
    let profile_id = state.active_profile_id.unwrap();

    let empty = store.delete_profile(profile_id).unwrap();

    assert!(empty.profiles.is_empty());
    assert_eq!(empty.active_profile_id, None);

    cleanup(db_path);
}

#[test]
fn blank_profile_name_is_rejected() {
    let db_path = test_db_path();
    let store = LocalProfileStore::open(&db_path).unwrap();

    let error = store
        .create_profile(CreateProfileRequest {
            name: "  ".to_owned(),
            avatar: None,
            experience_level: ExperienceLevel::Beginner,
        })
        .unwrap_err();

    assert_eq!(error.to_string(), "profile name must not be empty");

    cleanup(db_path);
}

fn profile_request(name: &str) -> CreateProfileRequest {
    CreateProfileRequest {
        name: name.to_owned(),
        avatar: Some("sticks".to_owned()),
        experience_level: ExperienceLevel::Beginner,
    }
}

fn profile_preference_count(db_path: &PathBuf, profile_id: Uuid) -> i64 {
    let conn = Connection::open(db_path).unwrap();
    conn.execute_batch("PRAGMA foreign_keys = ON;").unwrap();
    conn.query_row(
        "SELECT COUNT(*) FROM profile_preferences WHERE player_id = ?1",
        params![profile_id.to_string()],
        |row| row.get(0),
    )
    .unwrap()
}

fn test_db_path() -> PathBuf {
    std::env::temp_dir().join(format!("taal-local-profiles-{}.sqlite", Uuid::new_v4()))
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
