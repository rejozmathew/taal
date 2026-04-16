# Windows Native Adapter

Phase 0 Windows MIDI capture is implemented in the Flutter Windows runner under
`windows/runner/windows_midi_adapter.*` so it can register platform channels
directly with the desktop Flutter engine.

The adapter uses WinMM MIDI input APIs for the spike:
- `midiInGetNumDevs` / `midiInGetDevCapsW` for enumeration
- `midiInOpen` / `midiInStart` for capture
- `QueryPerformanceCounter` converted to nanoseconds at the MIDI callback

Native events are posted back to the runner window and emitted to Dart on the
`taal/windows_midi/events` event channel as structured `note_on` maps.
