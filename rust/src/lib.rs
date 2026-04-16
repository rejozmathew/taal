pub mod api;
pub mod content;
mod frb_generated;
pub mod runtime;

#[cfg(test)]
mod tests {
    #[test]
    fn greet_reports_expected_message() {
        assert_eq!(crate::api::simple::greet("Taal".to_owned()), "Hello, Taal!");
    }
}
