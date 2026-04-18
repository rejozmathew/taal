import 'package:flutter/services.dart';

enum ClickSoundPreset {
  classic('classic'),
  woodblock('woodblock'),
  hihat('hihat');

  const ClickSoundPreset(this.channelValue);

  final String channelValue;
}

class ScheduledMetronomeClick {
  const ScheduledMetronomeClick({required this.tMs, required this.accent});

  final int tMs;
  final bool accent;

  Map<String, Object?> toChannelMap() {
    return {'t_ms': tMs, 'accent': accent};
  }
}

class ScheduledDrumHit {
  const ScheduledDrumHit({
    required this.tMs,
    required this.laneId,
    required this.velocity,
    this.articulation = 'normal',
  }) : assert(tMs >= 0, 'tMs must be non-negative'),
       assert(velocity >= 1 && velocity <= 127, 'velocity must be 1..127');

  final int tMs;
  final String laneId;
  final int velocity;
  final String articulation;

  Map<String, Object?> toChannelMap() {
    return {
      't_ms': tMs,
      'lane_id': laneId,
      'velocity': velocity,
      'articulation': articulation,
    };
  }
}

class MetronomeAudioSettings {
  const MetronomeAudioSettings({required this.volume, required this.preset});

  final double volume;
  final ClickSoundPreset preset;
}

abstract class MetronomeAudioOutput {
  Future<void> configure(MetronomeAudioSettings settings);

  Future<void> scheduleClicks({
    required int sessionStartTimeNs,
    required List<ScheduledMetronomeClick> clicks,
  });

  Future<void> scheduleDrumHits({
    required int sessionStartTimeNs,
    required List<ScheduledDrumHit> hits,
  });

  Future<void> stop();
}

class PlatformMetronomeAudioOutput implements MetronomeAudioOutput {
  PlatformMetronomeAudioOutput({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const _channelName = 'taal/metronome_audio';

  final MethodChannel _channel;

  @override
  Future<void> configure(MetronomeAudioSettings settings) async {
    _validateVolume(settings.volume);
    await _channel.invokeMethod<void>('configure', {
      'volume': settings.volume,
      'preset': settings.preset.channelValue,
    });
  }

  @override
  Future<void> scheduleClicks({
    required int sessionStartTimeNs,
    required List<ScheduledMetronomeClick> clicks,
  }) async {
    await _channel.invokeMethod<void>('scheduleClicks', {
      'session_start_time_ns': sessionStartTimeNs,
      'clicks': clicks
          .map((click) => click.toChannelMap())
          .toList(growable: false),
    });
  }

  @override
  Future<void> scheduleDrumHits({
    required int sessionStartTimeNs,
    required List<ScheduledDrumHit> hits,
  }) async {
    await _channel.invokeMethod<void>('scheduleDrumHits', {
      'session_start_time_ns': sessionStartTimeNs,
      'hits': hits.map((hit) => hit.toChannelMap()).toList(growable: false),
    });
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  void _validateVolume(double volume) {
    if (volume < 0 || volume > 1) {
      throw RangeError.range(volume, 0, 1, 'volume');
    }
  }
}
