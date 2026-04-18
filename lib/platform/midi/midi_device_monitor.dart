import 'dart:async';

import 'package:taal/platform/midi/midi_adapter.dart';

enum MidiConnectionState { connected, disconnected }

enum MidiDeviceChangeType { connected, disconnected }

class MidiDeviceChange {
  const MidiDeviceChange({required this.type, required this.device});

  final MidiDeviceChangeType type;
  final MidiInputDevice device;
}

class MidiDeviceMonitor {
  MidiDeviceMonitor(this._adapter, {Duration? pollInterval})
    : _pollInterval = pollInterval ?? const Duration(seconds: 2);

  final Phase0MidiAdapter _adapter;
  final Duration _pollInterval;

  Timer? _pollTimer;
  List<MidiInputDevice> _knownDevices = const [];
  MidiConnectionState _connectionState = MidiConnectionState.disconnected;
  int? _openDeviceId;

  final _deviceChangeController = StreamController<MidiDeviceChange>.broadcast(
    sync: true,
  );
  final _connectionStateController =
      StreamController<MidiConnectionState>.broadcast(sync: true);

  Stream<MidiDeviceChange> get deviceChanges => _deviceChangeController.stream;
  Stream<MidiConnectionState> get connectionStateChanges =>
      _connectionStateController.stream;

  MidiConnectionState get connectionState => _connectionState;
  List<MidiInputDevice> get knownDevices => List.unmodifiable(_knownDevices);
  int? get openDeviceId => _openDeviceId;

  Phase0MidiAdapter get adapter => _adapter;

  void startMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<List<MidiInputDevice>> scanDevices() async {
    final devices = await _adapter.listDevices();
    _diffAndEmit(devices);
    return devices;
  }

  Future<void> openDevice(int deviceId) async {
    await _adapter.openDevice(deviceId);
    _openDeviceId = deviceId;
    _setConnectionState(MidiConnectionState.connected);
  }

  Future<void> closeDevice() async {
    await _adapter.closeDevice();
    _openDeviceId = null;
    _setConnectionState(MidiConnectionState.disconnected);
  }

  Future<void> reconnect() async {
    final deviceId = _openDeviceId;
    if (deviceId == null) return;

    final devices = await _adapter.listDevices();
    final stillPresent = devices.any((d) => d.id == deviceId);
    if (stillPresent) {
      await _adapter.openDevice(deviceId);
      _setConnectionState(MidiConnectionState.connected);
    }
  }

  void dispose() {
    stopMonitoring();
    _deviceChangeController.close();
    _connectionStateController.close();
  }

  void _setConnectionState(MidiConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    _connectionStateController.add(state);
  }

  Future<void> _poll() async {
    try {
      final devices = await _adapter.listDevices();
      _diffAndEmit(devices);

      if (_openDeviceId != null) {
        final stillPresent = devices.any((d) => d.id == _openDeviceId);
        if (!stillPresent) {
          _openDeviceId = null;
          _setConnectionState(MidiConnectionState.disconnected);
        }
      }
    } on Object {
      // Polling failure — keep previous state.
    }
  }

  void _diffAndEmit(List<MidiInputDevice> newDevices) {
    final oldIds = {for (final d in _knownDevices) d.id};
    final newIds = {for (final d in newDevices) d.id};

    for (final device in newDevices) {
      if (!oldIds.contains(device.id)) {
        _deviceChangeController.add(
          MidiDeviceChange(
            type: MidiDeviceChangeType.connected,
            device: device,
          ),
        );
      }
    }

    for (final device in _knownDevices) {
      if (!newIds.contains(device.id)) {
        _deviceChangeController.add(
          MidiDeviceChange(
            type: MidiDeviceChangeType.disconnected,
            device: device,
          ),
        );
      }
    }

    _knownDevices = newDevices;
  }
}
