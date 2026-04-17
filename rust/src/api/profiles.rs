use crate::storage::profiles::{
    parse_profile_id, CreateProfileRequest, ExperienceLevel, LocalProfileState, LocalProfileStore,
    PlayerProfile, PracticeView, ProfileStorageError,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProfileExperienceLevelDto {
    Beginner,
    Intermediate,
    Teacher,
}

impl From<ProfileExperienceLevelDto> for ExperienceLevel {
    fn from(value: ProfileExperienceLevelDto) -> Self {
        match value {
            ProfileExperienceLevelDto::Beginner => Self::Beginner,
            ProfileExperienceLevelDto::Intermediate => Self::Intermediate,
            ProfileExperienceLevelDto::Teacher => Self::Teacher,
        }
    }
}

impl From<ExperienceLevel> for ProfileExperienceLevelDto {
    fn from(value: ExperienceLevel) -> Self {
        match value {
            ExperienceLevel::Beginner => Self::Beginner,
            ExperienceLevel::Intermediate => Self::Intermediate,
            ExperienceLevel::Teacher => Self::Teacher,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProfilePracticeViewDto {
    NoteHighway,
    Notation,
}

impl From<ProfilePracticeViewDto> for PracticeView {
    fn from(value: ProfilePracticeViewDto) -> Self {
        match value {
            ProfilePracticeViewDto::NoteHighway => Self::NoteHighway,
            ProfilePracticeViewDto::Notation => Self::Notation,
        }
    }
}

impl From<PracticeView> for ProfilePracticeViewDto {
    fn from(value: PracticeView) -> Self {
        match value {
            PracticeView::NoteHighway => Self::NoteHighway,
            PracticeView::Notation => Self::Notation,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlayerProfileDto {
    pub id: String,
    pub name: String,
    pub avatar: Option<String>,
    pub experience_level: ProfileExperienceLevelDto,
    pub preferred_view: ProfilePracticeViewDto,
    pub created_at: String,
    pub updated_at: String,
}

impl From<PlayerProfile> for PlayerProfileDto {
    fn from(value: PlayerProfile) -> Self {
        Self {
            id: value.id.to_string(),
            name: value.name,
            avatar: value.avatar,
            experience_level: value.experience_level.into(),
            preferred_view: value.preferred_view.into(),
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalProfileStateDto {
    pub profiles: Vec<PlayerProfileDto>,
    pub active_profile_id: Option<String>,
}

impl From<LocalProfileState> for LocalProfileStateDto {
    fn from(value: LocalProfileState) -> Self {
        Self {
            profiles: value.profiles.into_iter().map(Into::into).collect(),
            active_profile_id: value.active_profile_id.map(|id| id.to_string()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalProfileOperationResult {
    pub state: Option<LocalProfileStateDto>,
    pub error: Option<String>,
}

impl LocalProfileOperationResult {
    fn ok(state: LocalProfileState) -> Self {
        Self {
            state: Some(state.into()),
            error: None,
        }
    }

    fn err(error: ProfileStorageError) -> Self {
        Self {
            state: None,
            error: Some(error.to_string()),
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn local_profile_state(database_path: String) -> LocalProfileOperationResult {
    run(database_path, |store| store.state())
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_local_profile(
    database_path: String,
    name: String,
    avatar: Option<String>,
    experience_level: ProfileExperienceLevelDto,
) -> LocalProfileOperationResult {
    run(database_path, |store| {
        store.create_profile(CreateProfileRequest {
            name,
            avatar,
            experience_level: experience_level.into(),
        })
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_active_local_profile(
    database_path: String,
    profile_id: String,
) -> LocalProfileOperationResult {
    run(database_path, |store| {
        let profile_id = parse_profile_id(&profile_id)?;
        store.set_active_profile(profile_id)
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_local_profile_preferred_view(
    database_path: String,
    profile_id: String,
    preferred_view: ProfilePracticeViewDto,
) -> LocalProfileOperationResult {
    run(database_path, |store| {
        let profile_id = parse_profile_id(&profile_id)?;
        store.update_preferred_view(profile_id, preferred_view.into())
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_player_profile_name(
    database_path: String,
    profile_id: String,
    name: String,
) -> LocalProfileOperationResult {
    run(database_path, |store| {
        let profile_id = parse_profile_id(&profile_id)?;
        store.update_profile_name(profile_id, name)?;
        store.state()
    })
}

#[flutter_rust_bridge::frb(sync)]
pub fn delete_local_profile(
    database_path: String,
    profile_id: String,
) -> LocalProfileOperationResult {
    run(database_path, |store| {
        let profile_id = parse_profile_id(&profile_id)?;
        store.delete_profile(profile_id)
    })
}

fn run(
    database_path: String,
    f: impl FnOnce(&LocalProfileStore) -> Result<LocalProfileState, ProfileStorageError>,
) -> LocalProfileOperationResult {
    match LocalProfileStore::open(database_path).and_then(|store| f(&store)) {
        Ok(state) => LocalProfileOperationResult::ok(state),
        Err(error) => LocalProfileOperationResult::err(error),
    }
}
