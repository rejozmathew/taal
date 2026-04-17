import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/profiles.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Dart calls Rust local profile persistence through the bridge',
    () async {
      await RustLib.init();

      final tempDir = await Directory.systemTemp.createTemp(
        'taal_profile_bridge_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final databasePath = [
        tempDir.path,
        'profiles.sqlite',
      ].join(Platform.pathSeparator);

      final initial = localProfileState(databasePath: databasePath);
      expect(initial.error, isNull);
      expect(initial.state!.profiles, isEmpty);

      final created = createLocalProfile(
        databasePath: databasePath,
        name: 'Rejo',
        avatar: 'sticks',
        experienceLevel: ProfileExperienceLevelDto.beginner,
      );
      expect(created.error, isNull);
      expect(created.state!.profiles.single.name, 'Rejo');
      expect(created.state!.activeProfileId, created.state!.profiles.single.id);

      final second = createLocalProfile(
        databasePath: databasePath,
        name: 'Anya',
        avatar: 'snare',
        experienceLevel: ProfileExperienceLevelDto.intermediate,
      );
      final firstId = created.state!.profiles.single.id;
      final secondId = second.state!.activeProfileId!;
      expect(secondId, isNot(firstId));

      final switched = setActiveLocalProfile(
        databasePath: databasePath,
        profileId: firstId,
      );
      expect(switched.error, isNull);
      expect(switched.state!.activeProfileId, firstId);

      final deleted = deleteLocalProfile(
        databasePath: databasePath,
        profileId: secondId,
      );
      expect(deleted.error, isNull);
      expect(deleted.state!.profiles.single.id, firstId);
    },
  );
}
