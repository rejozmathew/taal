import 'package:flutter/services.dart';
import 'package:taal/platform/midi/midi_adapter.dart';

class AndroidMidiAdapter implements Phase0MidiAdapter {
  AndroidMidiAdapter();

  static const _methods = MethodChannel('taal/android_midi');
  static const _events = EventChannel('taal/android_midi/events');

  @override
  String get platformName => 'Android';

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents {
    return _events
        .receiveBroadcastStream()
        .where((event) {
          final map = event as Map<dynamic, dynamic>;
          return map['type'] == 'note_on';
        })
        .map((event) {
          return MidiNoteOnEvent.fromMap(event as Map<dynamic, dynamic>);
        });
  }

  @override
  Future<List<MidiInputDevice>> listDevices() async {
    final devices = await _methods.invokeListMethod<dynamic>('listDevices');
    return (devices ?? const <dynamic>[])
        .cast<Map<dynamic, dynamic>>()
        .map(MidiInputDevice.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> openDevice(int deviceId) async {
    await _methods.invokeMethod<void>('openDevice', deviceId);
  }

  @override
  Future<void> closeDevice() async {
    await _methods.invokeMethod<void>('closeDevice');
  }
}
