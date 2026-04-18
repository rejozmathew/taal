import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/platform/midi/midi_device_monitor.dart';

class FakeMidiAdapter implements Phase0MidiAdapter {
  List<MidiInputDevice> devices = [];
  bool openCalled = false;
  bool closeCalled = false;
  int? openedDeviceId;

  @override
  String get platformName => 'Fake';

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents => const Stream.empty();

  @override
  Future<List<MidiInputDevice>> listDevices() async => devices;

  @override
  Future<void> openDevice(int deviceId) async {
    openCalled = true;
    openedDeviceId = deviceId;
  }

  @override
  Future<void> closeDevice() async {
    closeCalled = true;
  }
}

const _device1 = MidiInputDevice(id: 0, name: 'Roland TD-27');
const _device2 = MidiInputDevice(id: 1, name: 'Alesis Nitro');

void main() {
  group('MidiDeviceMonitor', () {
    late FakeMidiAdapter adapter;
    late MidiDeviceMonitor monitor;

    setUp(() {
      adapter = FakeMidiAdapter();
      monitor = MidiDeviceMonitor(
        adapter,
        pollInterval: const Duration(milliseconds: 50),
      );
    });

    tearDown(() {
      monitor.dispose();
    });

    test('initial state is disconnected', () {
      expect(monitor.connectionState, MidiConnectionState.disconnected);
      expect(monitor.openDeviceId, isNull);
      expect(monitor.knownDevices, isEmpty);
    });

    test('scanDevices returns and stores device list', () async {
      adapter.devices = [_device1];
      final result = await monitor.scanDevices();
      expect(result, hasLength(1));
      expect(result.first.name, 'Roland TD-27');
      expect(monitor.knownDevices, hasLength(1));
    });

    test('scanDevices emits connected event for new devices', () async {
      adapter.devices = [];
      await monitor.scanDevices();

      adapter.devices = [_device1];
      final changes = <MidiDeviceChange>[];
      monitor.deviceChanges.listen(changes.add);
      await monitor.scanDevices();

      expect(changes, hasLength(1));
      expect(changes.first.type, MidiDeviceChangeType.connected);
      expect(changes.first.device.name, 'Roland TD-27');
    });

    test('scanDevices emits disconnected event for removed devices', () async {
      adapter.devices = [_device1];
      await monitor.scanDevices();

      adapter.devices = [];
      final changes = <MidiDeviceChange>[];
      monitor.deviceChanges.listen(changes.add);
      await monitor.scanDevices();

      expect(changes, hasLength(1));
      expect(changes.first.type, MidiDeviceChangeType.disconnected);
      expect(changes.first.device.name, 'Roland TD-27');
    });

    test('openDevice sets connected state', () async {
      await monitor.openDevice(0);
      expect(monitor.connectionState, MidiConnectionState.connected);
      expect(monitor.openDeviceId, 0);
      expect(adapter.openCalled, isTrue);
    });

    test('closeDevice sets disconnected state', () async {
      await monitor.openDevice(0);
      await monitor.closeDevice();
      expect(monitor.connectionState, MidiConnectionState.disconnected);
      expect(monitor.openDeviceId, isNull);
      expect(adapter.closeCalled, isTrue);
    });

    test('connectionStateChanges stream emits state transitions', () async {
      final states = <MidiConnectionState>[];
      monitor.connectionStateChanges.listen(states.add);

      await monitor.openDevice(0);
      await monitor.closeDevice();

      expect(states, [
        MidiConnectionState.connected,
        MidiConnectionState.disconnected,
      ]);
    });

    test('reconnect re-opens device if still present', () async {
      await monitor.openDevice(0);
      adapter.devices = [_device1];
      adapter.openCalled = false;
      await monitor.reconnect();
      expect(adapter.openCalled, isTrue);
      expect(monitor.connectionState, MidiConnectionState.connected);
    });

    test('reconnect does nothing if no device was open', () async {
      adapter.devices = [_device1];
      await monitor.reconnect();
      expect(adapter.openCalled, isFalse);
    });

    test('polling detects device arrival', () async {
      adapter.devices = [];
      await monitor.scanDevices(); // seed empty list
      final changes = <MidiDeviceChange>[];
      monitor.deviceChanges.listen(changes.add);

      adapter.devices = [_device1];
      monitor.startMonitoring();

      // Wait for at least one poll cycle
      await Future<void>.delayed(const Duration(milliseconds: 120));
      monitor.stopMonitoring();

      expect(
        changes.any((c) => c.type == MidiDeviceChangeType.connected),
        isTrue,
      );
    });

    test(
      'polling detects device disconnect and updates connection state',
      () async {
        adapter.devices = [_device1];
        await monitor.scanDevices();
        await monitor.openDevice(0);

        final states = <MidiConnectionState>[];
        monitor.connectionStateChanges.listen(states.add);

        adapter.devices = [];
        monitor.startMonitoring();

        await Future<void>.delayed(const Duration(milliseconds: 120));
        monitor.stopMonitoring();

        expect(monitor.connectionState, MidiConnectionState.disconnected);
        expect(states.contains(MidiConnectionState.disconnected), isTrue);
      },
    );

    test('multiple device changes detected in single scan', () async {
      adapter.devices = [_device1];
      await monitor.scanDevices();

      adapter.devices = [_device2];
      final changes = <MidiDeviceChange>[];
      monitor.deviceChanges.listen(changes.add);
      await monitor.scanDevices();

      expect(changes, hasLength(2)); // 1 disconnected + 1 connected
      final types = changes.map((c) => c.type).toSet();
      expect(types, contains(MidiDeviceChangeType.connected));
      expect(types, contains(MidiDeviceChangeType.disconnected));
    });
  });

  group('PracticeModeController MIDI disconnect', () {
    // These tests are in practice_mode_screen_test via existing test infrastructure
    // but we verify the disconnect/reconnect logic here for completeness.
  });
}
