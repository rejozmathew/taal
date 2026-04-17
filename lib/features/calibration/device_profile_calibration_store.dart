import 'dart:convert';

import 'package:taal/src/rust/api/device_profiles.dart' as rust_device_profiles;

class DeviceProfileCalibrationStore {
  DeviceProfileCalibrationStore({
    required this.databasePath,
    required this.playerId,
    DeviceProfilePersistenceGateway? gateway,
  }) : gateway = gateway ?? RustDeviceProfilePersistenceGateway();

  final String databasePath;
  final String playerId;
  final DeviceProfilePersistenceGateway gateway;

  List<DeviceProfileCalibrationTarget> listTargets() {
    final result = gateway.listProfiles(
      databasePath: databasePath,
      playerId: playerId,
    );
    _throwIfError(result);
    return result.profilesJson
        .map(DeviceProfileCalibrationTarget.fromProfileJson)
        .toList(growable: false);
  }

  DeviceProfileCalibrationTarget saveOffset({
    required String profileJson,
    required double offsetMs,
    DateTime? now,
  }) {
    final updatedJson = calibratedDeviceProfileJson(
      profileJson: profileJson,
      offsetMs: offsetMs,
      updatedAt: now ?? DateTime.now().toUtc(),
    );
    final result = gateway.updateProfile(
      databasePath: databasePath,
      playerId: playerId,
      profileJson: updatedJson,
    );
    _throwIfError(result);
    final persistedJson = result.profileJson;
    if (persistedJson == null) {
      throw DeviceProfileCalibrationException(
        'Device profile update returned no profile.',
      );
    }
    final target = DeviceProfileCalibrationTarget.fromProfileJson(
      persistedJson,
    );
    final lastUsedResult = gateway.setLastUsedProfile(
      databasePath: databasePath,
      playerId: playerId,
      deviceProfileId: target.id,
    );
    _throwIfError(lastUsedResult);
    return target;
  }

  DeviceProfileCalibrationTarget skip({
    required String profileJson,
    DateTime? now,
  }) {
    return saveOffset(profileJson: profileJson, offsetMs: 0, now: now);
  }

  void _throwIfError(rust_device_profiles.DeviceProfileOperationResult result) {
    final error = result.error;
    if (error != null) {
      throw DeviceProfileCalibrationException(error);
    }
  }
}

abstract class DeviceProfilePersistenceGateway {
  rust_device_profiles.DeviceProfileOperationResult listProfiles({
    required String databasePath,
    required String playerId,
  });

  rust_device_profiles.DeviceProfileOperationResult updateProfile({
    required String databasePath,
    required String playerId,
    required String profileJson,
  });

  rust_device_profiles.DeviceProfileOperationResult setLastUsedProfile({
    required String databasePath,
    required String playerId,
    required String deviceProfileId,
  });
}

class RustDeviceProfilePersistenceGateway
    implements DeviceProfilePersistenceGateway {
  @override
  rust_device_profiles.DeviceProfileOperationResult listProfiles({
    required String databasePath,
    required String playerId,
  }) {
    return rust_device_profiles.listPersistedDeviceProfiles(
      databasePath: databasePath,
      playerId: playerId,
    );
  }

  @override
  rust_device_profiles.DeviceProfileOperationResult updateProfile({
    required String databasePath,
    required String playerId,
    required String profileJson,
  }) {
    return rust_device_profiles.updatePersistedDeviceProfile(
      databasePath: databasePath,
      playerId: playerId,
      profileJson: profileJson,
    );
  }

  @override
  rust_device_profiles.DeviceProfileOperationResult setLastUsedProfile({
    required String databasePath,
    required String playerId,
    required String deviceProfileId,
  }) {
    return rust_device_profiles.setLastUsedDeviceProfile(
      databasePath: databasePath,
      playerId: playerId,
      deviceProfileId: deviceProfileId,
    );
  }
}

class DeviceProfileCalibrationTarget {
  DeviceProfileCalibrationTarget._({
    required this.id,
    required this.name,
    required this.profileJson,
    required this.snareMidiNotes,
    required this.inputOffsetMs,
  });

  factory DeviceProfileCalibrationTarget.fromProfileJson(String profileJson) {
    final decoded = jsonDecode(profileJson);
    if (decoded is! Map<String, Object?>) {
      throw DeviceProfileCalibrationException(
        'Device profile JSON must be an object.',
      );
    }
    final id = decoded['id'] as String?;
    final name = decoded['name'] as String?;
    final noteMap = decoded['note_map'];
    if (id == null || name == null || noteMap is! List) {
      throw DeviceProfileCalibrationException(
        'Device profile is missing id, name, or note_map.',
      );
    }

    final snareNotes = <int>{};
    for (final rawMapping in noteMap) {
      if (rawMapping is! Map) {
        continue;
      }
      if (rawMapping['lane_id'] != 'snare') {
        continue;
      }
      final note = rawMapping['midi_note'];
      if (note is int) {
        snareNotes.add(note);
      }
    }
    if (snareNotes.isEmpty) {
      throw DeviceProfileCalibrationException(
        'Device profile "$name" has no snare note mapping.',
      );
    }

    final inputOffset = decoded['input_offset_ms'];
    return DeviceProfileCalibrationTarget._(
      id: id,
      name: name,
      profileJson: profileJson,
      snareMidiNotes: Set.unmodifiable(snareNotes),
      inputOffsetMs: inputOffset is num ? inputOffset.toDouble() : 0,
    );
  }

  final String id;
  final String name;
  final String profileJson;
  final Set<int> snareMidiNotes;
  final double inputOffsetMs;
}

String calibratedDeviceProfileJson({
  required String profileJson,
  required double offsetMs,
  required DateTime updatedAt,
}) {
  final decoded = jsonDecode(profileJson);
  if (decoded is! Map<String, Object?>) {
    throw DeviceProfileCalibrationException(
      'Device profile JSON must be an object.',
    );
  }
  decoded['input_offset_ms'] = double.parse(offsetMs.toStringAsFixed(3));
  decoded['updated_at'] = _formatUtc(updatedAt);
  return jsonEncode(decoded);
}

String _formatUtc(DateTime dateTime) {
  return dateTime.toUtc().toIso8601String();
}

class DeviceProfileCalibrationException implements Exception {
  DeviceProfileCalibrationException(this.message);

  final String message;

  @override
  String toString() => message;
}
