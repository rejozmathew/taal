# MIDI & Device Mapping Specification

**Companion to:** docs/prd.md Sections 3.2, 4.1.1
**Status:** Contract — struct shapes and behavioral rules are stable. Thresholds may be tuned during implementation.

---

## 1. Device Profile

A device profile stores everything needed to interpret raw MIDI events from a specific physical device.

```rust
pub struct DeviceProfile {
    pub id: Uuid,
    pub name: String,                    // "Roland TD-17KVX (USB)"
    pub instrument_family: String,       // "drums"
    pub layout_id: String,              // "std-5pc-v1"

    // Device identity (for reconnection matching)
    pub device_fingerprint: DeviceFingerprint,

    // Transport
    pub transport: MidiTransport,       // Usb | Bluetooth | Virtual
    pub midi_channel: Option<u8>,       // None = accept all channels

    // Mapping
    pub note_map: Vec<NoteMapping>,

    // Hi-hat model
    pub hihat_model: Option<HiHatModel>,

    // Timing
    pub input_offset_ms: f32,           // Calibration result. Applied as: effective_t = raw_t - offset
    pub dedupe_window_ms: f32,          // Default: 8.0. Suppress duplicate NoteOn within this window.

    // Velocity
    pub velocity_curve: VelocityCurve,  // Linear | Soft | Hard | Custom(Vec<(u8,u8)>)

    // Provenance
    pub preset_origin: Option<String>,  // "roland-td17" if from a preset, None if fully custom
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

pub struct DeviceFingerprint {
    pub vendor_name: Option<String>,
    pub model_name: Option<String>,
    pub platform_id: Option<String>,    // OS-specific device identifier
}

pub enum MidiTransport { Usb, Bluetooth, Virtual }
pub enum VelocityCurve { Linear, Soft, Hard, Custom(Vec<(u8, u8)>) }
pub type DateTime = String;             // RFC 3339 UTC timestamp, e.g. "2026-04-16T12:34:56Z"
```

### Reserved Generic CC Mapping

`cc_map` is reserved for a future generic controller-mapping contract. P1-06 does not define or use a generic `CcMapping` type.

Phase 1 `DeviceProfile` records must omit `cc_map`. Any present `cc_map` field is unsupported for Phase 1 local loading until a future spec revision defines `CcMapping`. Hi-hat openness is not modeled through `cc_map`; it is modeled only by `hihat_model.source_cc`.

### Metadata Timestamp Representation

`DateTime` in this spec is a JSON string containing an RFC 3339 UTC timestamp, e.g. `2026-04-16T12:34:56Z`. It represents wall-clock metadata only and must not be used for MIDI event timing, calibration offsets, grading, or scoring.

For Phase 1 local loading, `created_at` and `updated_at` are required on preset and persisted `DeviceProfile` records. P1-06 mapping behavior must ignore these fields after profile validation. Newly created in-memory profiles must populate both fields before they are persisted.

### Device Identity and Reconnection

Reconnection matching uses: `(vendor_name, model_name)` as primary key. If two identical models are connected simultaneously, `platform_id` disambiguates. If `platform_id` is unavailable or unstable across reconnects (common on some Android devices), fall back to `(vendor_name, model_name)` and use the most-recently-used profile.

### Profile Ownership

Device profiles are **per-player-profile**. Each local player profile owns its own set of device mappings. This allows different users on the same machine to have different calibration offsets and velocity curves for the same physical kit.

### P1-20 Device-Profile Settings

The Settings screen may display the active device profile's mapping state, but the P1-20-owned editable device-profile settings are limited to:

| Field | Owner | Default | P1-20 behavior |
|-------|-------|---------|----------------|
| `input_offset_ms` | Device profile | `0.0` | Manual latency slider writes the effective offset in the range `-50.0..=50.0` ms |
| `dedupe_window_ms` | Device profile | `8.0` | Persisted with the profile; not required as a P1-20 control |
| `velocity_curve` | Device profile | `VelocityCurve::Linear` | Velocity curve selector writes the selected curve |

`input_offset_ms` is the single effective Phase 1 input offset used by the mapper. Auto-calibration and manual fine-tuning both update this same field; Phase 1 does not add a second stored manual-offset field.

The selected active device profile is not stored inside `DeviceProfile`. It is profile-level settings state defined in `engine-api.md`, while reconnect lookup remains the per-player last-used device-profile mapping from P1-08.

---

## 2. Raw MIDI Event (Native → Rust)

The native platform adapter produces this struct. It is the contract between native code and Rust.

```rust
pub struct RawMidiEvent {
    pub event_type: RawMidiEventType,
    pub channel: u8,                    // 0-15
    pub data1: u8,                      // Note number or CC number
    pub data2: u8,                      // Velocity or CC value
    pub timestamp_ns: i128,             // Monotonic, from platform clock
}

pub enum RawMidiEventType { NoteOn, NoteOff, ControlChange }
```

**Timestamp rules:**
- Windows: `QueryPerformanceCounter` converted to nanoseconds
- Android: `System.nanoTime()`
- iOS/macOS (future): `mach_absolute_time()` converted to nanoseconds
- Must be monotonic (never decreasing within a session)
- Captured as close to the OS callback as possible (no buffering, no batching)

---

## 3. Mapping Result (Rust Output)

After mapping, the `MidiMapper` produces:

```rust
pub struct MappedHit {
    pub lane_id: String,
    pub velocity: u8,
    pub articulation: String,           // "normal", "accent", "ghost", "open", "closed", "pedal"
    pub timestamp_ns: i128,
    pub raw_note: u8,                   // Preserved for debugging
}
```

Or a mapping warning:

```rust
pub enum MappingResult {
    Hit(MappedHit),
    Unmapped { note: u8, velocity: u8, timestamp_ns: i128 },
    Suppressed,                          // Deduplication
}
```

### Runtime Session Handoff

`MidiMapper` does not grade or score hits. A Practice Mode runtime adapter converts `MappingResult::Hit(MappedHit)` into the existing `InputHit` contract from `engine-api.md` by copying `lane_id`, `velocity`, and `timestamp_ns`, and setting `midi_note` to the preserved `raw_note`.

Touch input does not flow through `MidiMapper`. The P1-23 tap-pad surface already represents a semantic lane from the active layout, so the runtime adapter creates an `InputHit` with that `lane_id`, a fixed or touch-estimated velocity, the touch input timestamp, and `midi_note: None`. MIDI and touch hits are then submitted to the same Rust `Session`.

---

## 4. Note Mapping

```rust
pub struct NoteMapping {
    pub midi_note: u8,
    pub lane_id: String,
    pub articulation: String,           // "normal", "rim", "open", "closed", etc.
    pub min_velocity: u8,               // Default: 1
    pub max_velocity: u8,               // Default: 127
}
```

**Invariants:**
- Multiple notes can map to the same lane_id (e.g., notes 38 and 40 both → "snare")
- Each (midi_note, articulation) pair should be unique within a profile
- If a note matches multiple mappings, the first match wins (ordered list)

---

## 5. Hi-Hat Openness Model

```rust
pub struct HiHatModel {
    pub source_cc: u8,                  // Usually 4
    pub invert: bool,                   // true if closed = high CC value
    pub thresholds: Vec<HiHatThreshold>,
    pub auto_articulation_notes: Vec<u8>, // Notes that use pedal state for articulation
}

pub struct HiHatThreshold {
    pub max_cc_value: u8,
    pub state: String,                  // "closed", "semi_open", "open", "fully_open"
}
```

**Runtime behavior:**
1. Maintain running `hihat_cc_value: u8` in session state (updated on every CC event for `source_cc`)
2. When a note in `auto_articulation_notes` arrives, resolve state from thresholds
3. Map state to final articulation: `closed → "closed"`, `open → "open"`, etc.
4. If `invert` is true, subtract CC value from 127 before threshold comparison

**Default thresholds (Roland-style):**
| Max CC Value | State |
|-------------|-------|
| 15 | closed |
| 50 | semi_open |
| 90 | open |
| 127 | fully_open |

**Calibration for hi-hat:**
- "Press pedal fully closed" → record CC value → this is closed_max
- "Release pedal fully" → record CC value → this is open_min
- If closed_max > open_min → set `invert: true`
- Generate thresholds scaled between endpoints

---

## 6. Deduplication Rules

Some e-kits send duplicate NoteOn bursts for a single physical hit.

**Suppression rule:** If the same `midi_note` arrives within `dedupe_window_ms` of the previous event for that note, and velocity is within 10 of the previous:
- **Suppress the second event** (return `MappingResult::Suppressed`)
- First event wins (it has the earliest timestamp)
- Configurable per device profile (`dedupe_window_ms`, default 8ms)

**Flam protection:** Intentional rapid hits on the same pad (flams) must NOT be suppressed. Flams typically have:
- Different velocity (harder grace note vs accent)
- Or timing gap > dedupe_window

The velocity tolerance (within 10) and short window (8ms) protect against false suppression of intentional playing.

---

## 7. Articulation Scope (v1 vs Deferred)

| Articulation | v1 Support | Notes |
|-------------|-----------|-------|
| Hi-hat closed/open/pedal | ✅ Supported | Via CC4 model |
| Snare center/rim | ✅ Supported | Via note mapping (different MIDI notes) |
| Cymbal bow/edge/bell | ❌ Deferred | Would need positional sensing or zone mapping |
| Cymbal choke | ❌ Deferred | Requires aftertouch or specific note handling |
| Dual-zone pad detection | ❌ Deferred | Handled by note mapping if kit sends different notes |
| Positional sensing | ❌ Deferred | Would need CC interpretation per pad |

Deferred articulations are not scored or displayed in v1 but the mapping infrastructure supports them via additional `NoteMapping` entries.

---

## 8. Calibration

**Offset meaning:** `input_offset_ms` represents the consistent delay between when a physical hit occurs and when the app timestamps it. After calibration, the engine applies: `effective_timestamp = raw_timestamp - (input_offset_ms * 1_000_000)` (converting ms to ns).

**Calibration is per device profile.** Recalibrating overwrites the previous offset. The old offset is not retained (no history).

**Calibration invalidation:** A stored offset remains valid across app restarts for the same device. If the user switches USB ports or changes audio buffer size, they should recalibrate (the app can suggest this but does not force it).

---

## 9. Platform Adapter Contract

Each platform's native MIDI adapter must:

1. Enumerate connected MIDI devices (name, vendor, model where available)
2. Request OS permissions (Android: USB host permission)
3. Open connection and subscribe to NoteOn, NoteOff, ControlChange
4. Produce `RawMidiEvent` structs with monotonic timestamps
5. Pass events to Dart via platform channel immediately (no buffering)
6. Emit device connect/disconnect events

The adapter does NOT: perform lane mapping, do scoring, buffer events, or make UI decisions.

---

## 10. Preset Profiles

Shipped presets for common kits:

| Preset ID | Kit Family | Notes |
|-----------|-----------|-------|
| `roland-td07` | Roland TD-07 | Basic mapping |
| `roland-td17` | Roland TD-17 series | Includes dual-zone snare |
| `roland-td27` | Roland TD-27 | Extended zones |
| `yamaha-dtx` | Yamaha DTX series | Standard mapping |
| `alesis-nitro` | Alesis Nitro Mesh | Budget kit mapping |
| `alesis-surge` | Alesis Surge | Mid-range |
| `gm-drums` | General MIDI | Fallback for unknown kits |

Users can customize any preset or create from scratch via tap-to-map. Customized presets are stored as new profiles (preset is not modified).
