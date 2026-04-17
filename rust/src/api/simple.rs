use crate::runtime::session::{drain_events, start_session, submit_hit, InputHit};

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Phase0LatencyRustResult {
    pub native_timestamp_ns: i64,
    pub rust_entry_ns: i64,
    pub rust_exit_ns: i64,
    pub engine_event_count: u32,
}

#[flutter_rust_bridge::frb(sync)]
pub fn phase0_latency_clock_ns() -> i64 {
    monotonic_now_ns()
}

#[flutter_rust_bridge::frb(sync)]
pub fn measure_phase0_latency_hit(
    lane_id: String,
    velocity: u8,
    native_timestamp_ns: i64,
) -> Phase0LatencyRustResult {
    let rust_entry_ns = monotonic_now_ns();

    let mut session = start_session();
    submit_hit(
        &mut session,
        InputHit::new(lane_id, velocity, i128::from(native_timestamp_ns)),
    );
    let engine_event_count = drain_events(&mut session, 8).len() as u32;

    let rust_exit_ns = monotonic_now_ns();

    Phase0LatencyRustResult {
        native_timestamp_ns,
        rust_entry_ns,
        rust_exit_ns,
        engine_event_count,
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(windows)]
pub(crate) fn monotonic_now_ns() -> i64 {
    use std::sync::OnceLock;

    #[link(name = "kernel32")]
    unsafe extern "system" {
        fn QueryPerformanceCounter(lp_performance_count: *mut i64) -> i32;
        fn QueryPerformanceFrequency(lp_frequency: *mut i64) -> i32;
    }

    fn frequency() -> i64 {
        static FREQUENCY: OnceLock<i64> = OnceLock::new();
        *FREQUENCY.get_or_init(|| {
            let mut frequency = 0_i64;
            let ok = unsafe { QueryPerformanceFrequency(&mut frequency) };
            assert!(ok != 0, "QueryPerformanceFrequency failed");
            frequency
        })
    }

    let mut counter = 0_i64;
    let ok = unsafe { QueryPerformanceCounter(&mut counter) };
    assert!(ok != 0, "QueryPerformanceCounter failed");

    ((counter as i128 * 1_000_000_000_i128) / i128::from(frequency())) as i64
}

#[cfg(target_os = "android")]
pub(crate) fn monotonic_now_ns() -> i64 {
    #[repr(C)]
    struct Timespec {
        tv_sec: i64,
        tv_nsec: i64,
    }

    unsafe extern "C" {
        fn clock_gettime(clock_id: i32, timespec: *mut Timespec) -> i32;
    }

    const CLOCK_MONOTONIC: i32 = 1;

    let mut timespec = Timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    let ok = unsafe { clock_gettime(CLOCK_MONOTONIC, &mut timespec) };
    assert!(ok == 0, "clock_gettime(CLOCK_MONOTONIC) failed");

    timespec.tv_sec * 1_000_000_000 + timespec.tv_nsec
}

#[cfg(all(not(windows), not(target_os = "android")))]
pub(crate) fn monotonic_now_ns() -> i64 {
    use std::sync::OnceLock;
    use std::time::Instant;

    static START: OnceLock<Instant> = OnceLock::new();
    START.get_or_init(Instant::now).elapsed().as_nanos() as i64
}
