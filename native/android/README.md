# Android Native Adapter

Phase 0 Android MIDI capture is implemented in the Flutter Android host app at
`android/app/src/main/kotlin/dev/taal/taal/MainActivity.kt`.

The adapter uses `android.media.midi.MidiManager`:
- enumerates devices with readable output ports
- opens the selected device with `openDevice`
- connects output port 0 to a `MidiReceiver`
- timestamps NoteOn messages with `System.nanoTime()` inside the receiver

Native events are emitted to Dart on `taal/android_midi/events` as structured
`note_on` maps.
