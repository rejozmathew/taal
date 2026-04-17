import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

class LocalProfileStore {
  LocalProfileStore._(this.databasePath);

  final String databasePath;

  static Future<LocalProfileStore> open() async {
    final directory = await getApplicationSupportDirectory();
    final databasePath = [
      directory.path,
      'taal.sqlite',
    ].join(Platform.pathSeparator);
    return LocalProfileStore._(databasePath);
  }

  rust_profiles.LocalProfileStateDto load() {
    return _unwrap(rust_profiles.localProfileState(databasePath: databasePath));
  }

  rust_profiles.LocalProfileStateDto createProfile({
    required String name,
    String? avatar,
    required rust_profiles.ProfileExperienceLevelDto experienceLevel,
  }) {
    return _unwrap(
      rust_profiles.createLocalProfile(
        databasePath: databasePath,
        name: name,
        avatar: avatar,
        experienceLevel: experienceLevel,
      ),
    );
  }

  rust_profiles.LocalProfileStateDto switchProfile(String profileId) {
    return _unwrap(
      rust_profiles.setActiveLocalProfile(
        databasePath: databasePath,
        profileId: profileId,
      ),
    );
  }

  rust_profiles.LocalProfileStateDto setPreferredView({
    required String profileId,
    required rust_profiles.ProfilePracticeViewDto preferredView,
  }) {
    return _unwrap(
      rust_profiles.updateLocalProfilePreferredView(
        databasePath: databasePath,
        profileId: profileId,
        preferredView: preferredView,
      ),
    );
  }

  rust_profiles.LocalProfileStateDto deleteProfile(String profileId) {
    return _unwrap(
      rust_profiles.deleteLocalProfile(
        databasePath: databasePath,
        profileId: profileId,
      ),
    );
  }

  rust_profiles.LocalProfileStateDto _unwrap(
    rust_profiles.LocalProfileOperationResult result,
  ) {
    final state = result.state;
    if (state != null) {
      return state;
    }
    throw LocalProfileStoreException(
      result.error ?? 'Profile operation failed.',
    );
  }
}

class LocalProfileStoreException implements Exception {
  LocalProfileStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
