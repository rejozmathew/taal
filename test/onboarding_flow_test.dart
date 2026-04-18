import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/onboarding/onboarding_flow.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

void main() {
  test('starter lesson follows selected experience level', () {
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.beginner,
      ).title,
      'Basic Rock Beat 1',
    );
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.intermediate,
      ).title,
      'Syncopated 16ths',
    );
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.teacher,
      ).title,
      'Teacher Demo Groove',
    );
  });

  testWidgets('no MIDI user reaches demo lesson with tap pads', (tester) async {
    rust_profiles.LocalProfileStateDto? completedState;
    final createdProfiles = <rust_profiles.PlayerProfileDto>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          midiAdapter: const _FakeMidiAdapter(devices: []),
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

    await tester.tap(find.byKey(const ValueKey('onboarding-get-started')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-profile-name')),
      'Ada',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-profile-next')));
    await tester.pumpAndSettle();

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

    expect(find.text('Syncopated 16ths'), findsOneWidget);
    expect(find.text('Demo mode with tap pads is on.'), findsOneWidget);
    expect(find.byType(TapPadSurface), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tap-pad-kick')));
    await tester.pump();
    expect(find.text('Last pad: kick'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-finish')));

    expect(completedState?.activeProfileId, 'player-1');
  });

  testWidgets('MIDI device path still offers skip-to-demo controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          midiAdapter: const _FakeMidiAdapter(
            devices: [
              MidiInputDevice(
                id: 7,
                name: 'Roland TD-27',
                productName: 'TD-27',
              ),
            ],
          ),
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
  });
}

class _FakeMidiAdapter implements Phase0MidiAdapter {
  const _FakeMidiAdapter({required this.devices});

  final List<MidiInputDevice> devices;

  @override
  String get platformName => 'test';

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents => const Stream.empty();

  @override
  Future<List<MidiInputDevice>> listDevices() async => devices;

  @override
  Future<void> openDevice(int deviceId) async {}

  @override
  Future<void> closeDevice() async {}
}
