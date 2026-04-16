use std::error::Error;
use std::fmt::{self, Display};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ContentError {
    InvalidJson(String),
    SchemaViolation { field: String, message: String },
    InvariantViolation { rule: String, message: String },
    UnsupportedSchemaVersion { found: String, supported: String },
}

impl ContentError {
    pub(crate) fn schema(field: impl Into<String>, message: impl Into<String>) -> Self {
        Self::SchemaViolation {
            field: field.into(),
            message: message.into(),
        }
    }

    pub(crate) fn invariant(rule: impl Into<String>, message: impl Into<String>) -> Self {
        Self::InvariantViolation {
            rule: rule.into(),
            message: message.into(),
        }
    }
}

impl Display for ContentError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidJson(message) => write!(f, "invalid JSON: {message}"),
            Self::SchemaViolation { field, message } => {
                write!(f, "schema violation at {field}: {message}")
            }
            Self::InvariantViolation { rule, message } => {
                write!(f, "content invariant '{rule}' failed: {message}")
            }
            Self::UnsupportedSchemaVersion { found, supported } => {
                write!(
                    f,
                    "unsupported schema_version '{found}', supported version is '{supported}'"
                )
            }
        }
    }
}

impl Error for ContentError {}
