import 'dart:io';

import 'package:taal/platform/midi/android_midi_adapter.dart';
import 'package:taal/platform/midi/windows_midi_adapter.dart';

abstract class Phase0MidiAdapter {
  String get platformName;

  Stream<MidiNoteOnEvent> get noteOnEvents;

  Future<List<MidiInputDevice>> listDevices();

  Future<void> openDevice(int deviceId);

  Future<void> closeDevice();
}

Phase0MidiAdapter createPhase0MidiAdapter() {
  if (Platform.isAndroid) {
    return AndroidMidiAdapter();
  }
  if (Platform.isWindows) {
    return WindowsMidiAdapter();
  }
  return UnsupportedMidiAdapter(Platform.operatingSystem);
}

class MidiInputDevice {
  const MidiInputDevice({
    required this.id,
    required this.name,
    this.manufacturerId,
    this.productId,
    this.driverVersion,
    this.manufacturerName,
    this.productName,
    this.inputPortCount,
    this.outputPortCount,
  });

  factory MidiInputDevice.fromMap(Map<dynamic, dynamic> map) {
    return MidiInputDevice(
      id: map['id'] as int,
      name: map['name'] as String,
      manufacturerId: map['manufacturer_id'] as int?,
      productId: map['product_id'] as int?,
      driverVersion: map['driver_version'] as int?,
      manufacturerName: map['manufacturer_name'] as String?,
      productName: map['product_name'] as String?,
      inputPortCount: map['input_port_count'] as int?,
      outputPortCount: map['output_port_count'] as int?,
    );
  }

  final int id;
  final String name;
  final int? manufacturerId;
  final int? productId;
  final int? driverVersion;
  final String? manufacturerName;
  final String? productName;
  final int? inputPortCount;
  final int? outputPortCount;
}

class MidiNoteOnEvent {
  const MidiNoteOnEvent({
    required this.deviceId,
    required this.channel,
    required this.note,
    required this.velocity,
    required this.timestampNs,
  });

  factory MidiNoteOnEvent.fromMap(Map<dynamic, dynamic> map) {
    return MidiNoteOnEvent(
      deviceId: map['device_id'] as int,
      channel: map['channel'] as int,
      note: map['note'] as int,
      velocity: map['velocity'] as int,
      timestampNs: map['timestamp_ns'] as int,
    );
  }

  final int deviceId;
  final int channel;
  final int note;
  final int velocity;
  final int timestampNs;
}

class UnsupportedMidiAdapter implements Phase0MidiAdapter {
  const UnsupportedMidiAdapter(this.platformName);

  @override
  final String platformName;

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents => const Stream.empty();

  @override
  Future<List<MidiInputDevice>> listDevices() async => const [];

  @override
  Future<void> openDevice(int deviceId) async {
    throw UnsupportedError(
      'MIDI capture is not implemented for $platformName.',
    );
  }

  @override
  Future<void> closeDevice() async {}
}
