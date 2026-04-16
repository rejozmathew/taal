# ADR-001: Platform Architecture — Flutter + Rust Core

**Status:** Proposed (pending Phase 0 latency spike)
**Date:** 2026-04-08
**Decision Makers:** Rejo Z. Mathew

## Context

Taal is a cross-platform instrument tutoring app where low-latency MIDI input processing and smooth visual feedback are the core product requirements. The app must run on Windows (desktop) and Android (tablet) initially, with macOS and iPadOS as Phase 2 targets.

The key architectural tension is: **UI framework flexibility vs. MIDI/audio latency requirements vs. cross-platform reuse.**

## Options Considered

### Option A: Flutter + Rust Core (RECOMMENDED)
- **UI:** Flutter (Dart) — single codebase for all platforms
- **Engine:** Rust — timing, scoring, content, analytics
- **Bridge:** flutter_rust_bridge (mature async FFI)
- **MIDI/Audio:** Platform channels to native APIs

**Pros:**
- One UI codebase for Windows, Android, iOS, macOS, Linux
- Strong animation framework (custom painters, 60fps+ compositing)
- Mature Flutter ↔ Rust bridge
- Rust core is the Tauri backend equivalent without Tauri's limitations
- Tablet-optimized touch interactions built-in
- Single build system, single debug workflow

**Cons:**
- Flutter MIDI plugin ecosystem less mature than native
- Dart is not as widely known as JS/TS
- flutter_rust_bridge adds build complexity
- Flutter desktop is newer than Flutter mobile (but stable since Flutter 3.x)

**Risk:** MIDI plugin maturity on Windows and Android. Mitigated by Phase 0 spike.

### Option B: Tauri v2 (desktop) + React Native (mobile) + Rust Core
- **Desktop UI:** Tauri v2 + React
- **Mobile UI:** React Native
- **Engine:** Rust shared via FFI/JNI

**Pros:**
- Rust is native to Tauri (no bridge on desktop)
- React ecosystem is very mature
- RN has large community

**Cons:**
- Two UI runtimes, two app shells, two debugging worlds
- RN ↔ Rust bridge requires custom JNI (Android) and Swift FFI (iOS)
- Three separate build toolchains
- UI consistency between web-based (Tauri) and native (RN) is hard
- Tauri mobile is beta-quality

**Risk:** Integration complexity. Product feels like two apps pretending to be one.

### Option C: React Native (all platforms) + Rust Core
- **UI:** React Native for mobile + RN Windows
- **Engine:** Rust via react-native-rust / JNI

**Pros:**
- React ecosystem, large community
- RN Windows maintained by Microsoft

**Cons:**
- RN Windows is less polished than Flutter desktop
- Rust bridge requires per-platform native module work
- Animation performance historically lower than Flutter for custom surfaces

### Option D: Web App (PWA) + Rust (WASM)
- **UI:** React web app
- **Engine:** Rust compiled to WASM

**Pros:**
- Zero install friction
- Works everywhere with a browser

**Cons:**
- WebMIDI has real latency limitations (especially on Android/iOS)
- No native audio API access (higher audio output latency)
- Cannot meet the < 20ms feedback target reliably

## Decision

**Adopt Flutter + Rust Core** as the target architecture, **conditional on passing a Phase 0 latency spike.**

## Spike Requirements (Phase 0)

Before this decision is final, build and measure:

1. **Windows USB MIDI:** Detect device → capture NoteOn → pass to Rust → return to Flutter. Measure end-to-end latency.
2. **Android USB MIDI:** Same test on an Android tablet.
3. **Rust bridge overhead:** flutter_rust_bridge async call round-trip time.
4. **Animation test:** Render timing feedback at 60fps while ingesting MIDI hits. Measure frame drops.

**Go criterion:** End-to-end latency < 25ms on both platforms after calibration.
**No-go criterion:** If latency > 40ms or consistent frame drops during hit feedback, revisit architecture.

### Measurement Methodology

Measurements must be taken under the following conditions to be valid:

**Hardware:**
- Windows: modern desktop or laptop (Intel i5+ or AMD equivalent, 8GB+ RAM)
- Android: mid-range tablet (e.g., Samsung Galaxy Tab S series, Lenovo Tab P11). Document exact model.
- MIDI device: any USB MIDI controller. Document make/model.

**Software:**
- Windows: Windows 10 or 11, latest stable
- Android: Android 10+ (API 29+)
- Flutter: latest stable release
- Build: **release mode** (not debug — debug mode adds significant overhead on both platforms)

**Protocol:**
- Warm up: discard first 10 hits (JIT/cache warming)
- Sample size: minimum 100 hits after warm-up
- Measure at constant tempo (120 BPM, 8th-note pattern = ~4 hits/second)
- Record timestamps at each boundary: T0 (native MIDI callback), T1 (Rust entry), T2 (Rust exit), T3 (Flutter callback)
- Report: p50, p95, p99 for each segment and total
- Include hardware/software matrix in results

**Required artifacts:**
- CSV or JSON raw timing logs (all timestamps, all hits)
- Summary report (p50/p95/p99 per segment)
- Hardware/software matrix
- Screenshot or recording of animation test (frame drops visible)

### Bounded Fallback (if Android underperforms)

If Android USB MIDI latency exceeds threshold but Windows passes:

1. **Keep Flutter UI** on all platforms (do not reopen the UI framework decision)
2. **Keep Rust core engine** (no changes)
3. **Replace only the Android MIDI transport path:** bypass Flutter's platform channel for MIDI events and use a direct JNI bridge from Android's MidiManager callback to Rust, skipping the Dart layer for the hot path
4. This is a contained platform-specific optimization, not an architecture replacement
5. Document as ADR-002 if triggered

Do not reopen the entire architecture unless both Windows AND Android fail the latency threshold.

### Frame-Rate Acceptance

- Android: stable 60fps during active hit feedback (no visible stutters during 30-second practice)
- Windows: 60fps minimum; higher frame rates allowed but not required
- **Scoring correctness must not depend on UI frame rate.** If the UI drops to 30fps temporarily, grades must still be computed correctly from native timestamps. Only visual feedback may lag.

## Consequences

- All UI is Dart/Flutter
- All timing-critical logic is Rust
- MIDI and audio I/O use platform channels to native code
- Build pipeline needs Flutter + Rust + platform toolchains
- Team needs Dart + Rust competency (agent-coded, so this is manageable)
