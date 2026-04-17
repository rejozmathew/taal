use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use crate::midi::MidiMapper;

use super::session::Session;

#[derive(Debug)]
pub(crate) struct PracticeRuntimeSession {
    pub(crate) session: Session,
    pub(crate) mapper: Option<MidiMapper>,
}

pub(crate) fn insert_runtime_session(runtime: PracticeRuntimeSession) -> Result<u32, String> {
    let mut registry = registry()
        .lock()
        .map_err(|_| "practice runtime registry lock was poisoned".to_owned())?;
    registry.insert(runtime)
}

pub(crate) fn with_runtime_session<T>(
    session_id: u32,
    f: impl FnOnce(&mut PracticeRuntimeSession) -> Result<T, String>,
) -> Result<T, String> {
    let mut registry = registry()
        .lock()
        .map_err(|_| "practice runtime registry lock was poisoned".to_owned())?;
    let runtime = registry
        .sessions
        .get_mut(&session_id)
        .ok_or_else(|| format!("practice runtime session {session_id} was not found"))?;
    f(runtime)
}

pub(crate) fn remove_runtime_session(session_id: u32) -> Result<(), String> {
    let mut registry = registry()
        .lock()
        .map_err(|_| "practice runtime registry lock was poisoned".to_owned())?;
    registry.sessions.remove(&session_id);
    Ok(())
}

fn registry() -> &'static Mutex<PracticeRuntimeRegistry> {
    static REGISTRY: OnceLock<Mutex<PracticeRuntimeRegistry>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(PracticeRuntimeRegistry::default()))
}

#[derive(Debug, Default)]
struct PracticeRuntimeRegistry {
    next_id: u32,
    sessions: HashMap<u32, PracticeRuntimeSession>,
}

impl PracticeRuntimeRegistry {
    fn insert(&mut self, runtime: PracticeRuntimeSession) -> Result<u32, String> {
        self.next_id = self
            .next_id
            .checked_add(1)
            .ok_or_else(|| "practice runtime session id space is exhausted".to_owned())?;
        self.sessions.insert(self.next_id, runtime);
        Ok(self.next_id)
    }
}
