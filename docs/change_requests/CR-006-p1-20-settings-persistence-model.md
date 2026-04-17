# CR-006: P1-20 Settings Persistence Model

**Date:** 2026-04-17
**Triggered by:** P1-20 Settings Screen blocker
**Documents affected:** docs/specs/engine-api.md, docs/specs/midi-mapping.md, docs/specs/analytics-model.md, plans/phase-1.md, STATUS.md

## Problem

P1-20 requires a Settings screen for MIDI, audio, display, profile, and auto-pause controls, and `plans/phase-1.md` requires those settings to persist across app restarts and take effect immediately.

The current authoritative contracts only define scattered persisted fields:

- `PlayerProfile.preferred_view`
- `DeviceProfile.input_offset_ms`
- `DeviceProfile.velocity_curve`
- `DeviceProfile.dedupe_window_ms`
- existing profile/device-profile persistence ownership

No approved contract defines the complete settings ownership split, Phase 1 defaults, or Rust storage/bridge API shape for the remaining Settings screen state. `docs/specs/analytics-model.md` also references a user setting for Practice Mode attempt storage without naming its owner or default.

Implementing P1-20 without this clarification would require guessing which settings are app-level, player-profile-level, or device-profile-level, and would risk silent contract widening.

## Proposed Change

Define the minimum P1-20 settings/preferences contract while preserving the current architecture:

1. Rust remains the owner of all SQLite persistence.
2. Flutter owns rendering and interaction, and applies returned settings to UI/native adapters.
3. App-level settings are limited to installation-wide state that is not owned by a player profile.
4. Profile-level settings hold player preferences, including display, metronome preferences, auto-pause preferences, Practice Mode attempt recording, and active device-profile selection.
5. Device-profile-level settings remain in `DeviceProfile` for calibration, manual latency fine-tuning, dedupe, and velocity curve behavior.
6. P1-20 uses the existing device-profile persistence boundary for device-owned settings and adds a narrow settings/profile bridge shape for app/profile-owned settings.

## Impact

- P1-20 can implement settings persistence without inventing a contract.
- No session lifecycle, grade, `EngineEvent`, `PracticeAttempt`, `RawMidiEvent`, or `MappedHit` contract is changed.
- The manual latency slider writes the existing effective `DeviceProfile.input_offset_ms`; no second manual-offset field is added in Phase 1.
- Auto-pause behavior remains a P1-26 implementation concern. P1-20 only persists the toggle/defaults that P1-26 will read.
- Rust-owned SQLite persistence remains the architectural boundary. No ADR is required.
- No P1-20 implementation code is started by this CR.

## Applied Clarification

`docs/specs/engine-api.md` now defines:

- `AppSettings`
- `ProfileSettings`
- `ProfileSettingsUpdate`
- `SettingsSnapshot`
- `ThemePreference`
- `ClickSoundPreset`
- Phase 1 defaults for app/profile settings
- Rust storage and Flutter bridge API shape for reading and updating settings

`docs/specs/midi-mapping.md` now clarifies the P1-20 device-profile-owned settings and defaults:

- `input_offset_ms` default `0.0`
- `dedupe_window_ms` default `8.0`
- `velocity_curve` default `Linear`
- manual latency fine-tuning updates the existing effective `input_offset_ms`

`docs/specs/analytics-model.md` now identifies `ProfileSettings.record_practice_mode_attempts` as the Practice Mode attempt-storage setting and gives it a default.

`plans/phase-1.md` now links P1-20 to the clarified settings contract.

`STATUS.md` now records CR-006 as applied and marks P1-20 ready to implement.

## Status

- [x] Proposed
- [x] Approved
- [x] Applied
