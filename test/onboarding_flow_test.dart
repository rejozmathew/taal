import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/onboarding/onboarding_flow.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

void main() {
  test('starter lesson follows selected experience level', () {
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.beginner,
      ).title,
      'Basic Rock Beat',
    );
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.intermediate,
      ).title,
      'Syncopated Kick Push',
    );
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.teacher,
      ).title,
      'Pocket Funk Groove',
    );
  });

  testWidgets('no MIDI user reaches ready step with lesson info', (
    tester,
  ) async {
    rust_profiles.LocalProfileStateDto? completedState;
    final createdProfiles = <rust_profiles.PlayerProfileDto>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          midiAdapter: _FakeMidiAdapter(devices: []),
          onCreateProfile:
              ({required name, required avatar, required experienceLevel}) {
                final profile = rust_profiles.PlayerProfileDto(
                  id: 'player-1',
                  name: name,
                  avatar: avatar,
                  experienceLevel: experienceLevel,
                  preferredView:
                      rust_profiles.ProfilePracticeViewDto.noteHighway,
                  createdAt: '2026-04-18T10:00:00Z',
                  updatedAt: '2026-04-18T10:00:00Z',
                );
                createdProfiles.add(profile);
                return rust_profiles.LocalProfileStateDto(
                  profiles: [profile],
                  activeProfileId: profile.id,
                );
              },
          onComplete: (state) {
            completedState = state;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Dot indicator is visible
    expect(
      find.byKey(const ValueKey('onboarding-dot-indicator')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-get-started')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-profile-name')),
      'Ada',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-profile-next')));
    await tester.pumpAndSettle();

    // Experience step uses cards instead of SegmentedButton
    await tester.tap(find.text('Playing regularly'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-experience-next')));
    await tester.pumpAndSettle();

    expect(createdProfiles.single.name, 'Ada');
    expect(
      createdProfiles.single.experienceLevel,
      rust_profiles.ProfileExperienceLevelDto.intermediate,
    );
    expect(
      find.text('No MIDI device found. Demo mode with tap pads is ready.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-use-tap-pads')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-calibration-next')));
    await tester.pumpAndSettle();

    // Final step shows lesson info and a "Start your first lesson" button
    // (no embedded PracticeModeScreen)
    expect(find.textContaining('Syncopated Kick Push'), findsOneWidget);
    expect(find.text('You\'re all set!'), findsOneWidget);
    expect(find.text('Start your first lesson'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-finish')));

    expect(completedState?.activeProfileId, 'player-1');
  });

  testWidgets('MIDI device path still offers skip-to-demo controls', (
    tester,
  ) async {
    final midi = _FakeMidiAdapter(
      devices: const [
        MidiInputDevice(id: 7, name: 'Roland TD-27', productName: 'TD-27'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          midiAdapter: midi,
          onCreateProfile:
              ({required name, required avatar, required experienceLevel}) {
                final profile = rust_profiles.PlayerProfileDto(
                  id: 'player-1',
                  name: name,
                  avatar: avatar,
                  experienceLevel: experienceLevel,
                  preferredView:
                      rust_profiles.ProfilePracticeViewDto.noteHighway,
                  createdAt: '2026-04-18T10:00:00Z',
                  updatedAt: '2026-04-18T10:00:00Z',
                );
                return rust_profiles.LocalProfileStateDto(
                  profiles: [profile],
                  activeProfileId: profile.id,
                );
              },
          onComplete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-get-started')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-profile-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-experience-next')));
    await tester.pumpAndSettle();

    expect(find.text('1 MIDI device found.'), findsOneWidget);
    expect(find.text('Roland TD-27'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-use-selected-kit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-use-tap-pads')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-use-selected-kit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-calibration-next')));
    await tester.pumpAndSettle();

    // Final step is the ready step, not embedded practice
    expect(find.text('You\'re all set!'), findsOneWidget);
    expect(find.text('Start your first lesson'), findsOneWidget);
  });
}

class _FakeMidiAdapter implements Phase0MidiAdapter {
  _FakeMidiAdapter({required this.devices});

  final List<MidiInputDevice> devices;
  final _events = StreamController<MidiNoteOnEvent>.broadcast();
  int? openedDeviceId;
  var closeCount = 0;

  @override
  String get platformName => 'test';

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents => _events.stream;

  @override
  Future<List<MidiInputDevice>> listDevices() async => devices;

  @override
  Future<void> openDevice(int deviceId) async {
    openedDeviceId = deviceId;
  }

  @override
  Future<void> closeDevice() async {
    closeCount += 1;
  }

  void emit(MidiNoteOnEvent event) {
    _events.add(event);
  }
}
