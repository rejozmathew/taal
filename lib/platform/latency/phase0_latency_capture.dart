import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/simple.dart';

const phase0LatencyWarmupHits = 10;
const phase0LatencyMeasuredHits = 100;

class Phase0LatencyCapture {
  Phase0LatencyCapture() : _dartClock = Stopwatch()..start();

  static const _artifactChannel = MethodChannel('taal/artifacts');

  final Stopwatch _dartClock;
  final List<Phase0LatencySample> _samples = [];

  MidiInputDevice? _device;
  String? _outputDir;
  String? _artifactStem;
  int _dartToNativeOffsetNs = 0;
  int _calibrationUncertaintyNs = 0;
  bool _active = false;
  bool _complete = false;

  bool get isActive => _active;

  bool get isComplete => _complete;

  int get capturedHits => _samples.length;

  int get totalTargetHits =>
      phase0LatencyWarmupHits + phase0LatencyMeasuredHits;

  String? get outputDir => _outputDir;

  Phase0LatencyProgress start({
    required MidiInputDevice device,
    required String outputDir,
  }) {
    _device = device;
    _outputDir = outputDir;
    _artifactStem = _createArtifactStem();
    _samples.clear();
    _complete = false;
    _active = true;
    _calibrateClock();

    return Phase0LatencyProgress(
      message:
          '$_taskId latency capture started for ${device.name}. '
          'Discarding first $phase0LatencyWarmupHits hits, then recording '
          '$phase0LatencyMeasuredHits measured hits.',
      csvPath: null,
      reportPath: null,
      completed: false,
    );
  }

  Future<Phase0LatencyProgress?> record(MidiNoteOnEvent event) async {
    if (!_active || _complete) {
      return null;
    }

    final rustResult = measurePhase0LatencyHit(
      laneId: 'kick',
      velocity: event.velocity,
      nativeTimestampNs: event.timestampNs,
    );
    final flutterCallbackNs = _flutterClockNs();
    final sampleIndex = _samples.length + 1;
    final isWarmup = sampleIndex <= phase0LatencyWarmupHits;

    final sample = Phase0LatencySample(
      sampleIndex: sampleIndex,
      isWarmup: isWarmup,
      deviceId: event.deviceId,
      channel: event.channel,
      note: event.note,
      velocity: event.velocity,
      nativeTimestampNs: event.timestampNs,
      rustEntryNs: rustResult.rustEntryNs,
      rustExitNs: rustResult.rustExitNs,
      flutterCallbackNs: flutterCallbackNs,
      engineEventCount: rustResult.engineEventCount,
    );
    _samples.add(sample);

    final measuredCount = _samples.where((sample) => !sample.isWarmup).length;
    developer.log(sample.toConsoleLine(), name: 'taal.p0_05');

    if (_samples.length >= totalTargetHits) {
      _active = false;
      _complete = true;
      final paths = await _writeArtifacts();
      return Phase0LatencyProgress(
        message:
            '$_taskId latency capture complete: $measuredCount measured hits '
            'after $phase0LatencyWarmupHits warm-up hits.',
        csvPath: paths.csvPath,
        reportPath: paths.reportPath,
        completed: true,
      );
    }

    return Phase0LatencyProgress(
      message:
          '$_taskId capture progress: ${_samples.length}/$totalTargetHits hits '
          '($measuredCount measured).',
      csvPath: null,
      reportPath: null,
      completed: false,
    );
  }

  void _calibrateClock() {
    final beforeNs = _dartElapsedNs();
    final nativeNs = phase0LatencyClockNs();
    final afterNs = _dartElapsedNs();
    final midpointNs = beforeNs + ((afterNs - beforeNs) ~/ 2);
    _dartToNativeOffsetNs = nativeNs - midpointNs;
    _calibrationUncertaintyNs = afterNs - beforeNs;
  }

  int _flutterClockNs() {
    return _dartElapsedNs() + _dartToNativeOffsetNs;
  }

  int _dartElapsedNs() {
    return _dartClock.elapsedMicroseconds * 1000;
  }

  String _createArtifactStem() {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    return '${_artifactPrefix()}-$timestamp';
  }

  Future<Phase0LatencyArtifactPaths> _writeArtifacts() async {
    final outputDir = _outputDir ?? Directory.current.path;
    final artifactStem = _artifactStem ?? _createArtifactStem();
    final csvName = '$artifactStem.csv';
    final reportName = '$artifactStem-summary.md';

    if (Platform.isAndroid) {
      final csvPath = 'Downloads/$outputDir/$csvName';
      final reportPath = 'Downloads/$outputDir/$reportName';
      final result = await _artifactChannel
          .invokeMapMethod<String, String>('writeTextArtifacts', {
            'relative_dir': outputDir,
            'csv_name': csvName,
            'csv_content': _buildCsv(),
            'report_name': reportName,
            'report_content': _buildReport(csvPath),
          });
      return Phase0LatencyArtifactPaths(
        csvPath: result?['csv_path'] ?? csvPath,
        reportPath: result?['report_path'] ?? reportPath,
      );
    }

    final directory = Directory(outputDir);
    directory.createSync(recursive: true);

    final csvPath = _joinPath(outputDir, csvName);
    final reportPath = _joinPath(outputDir, reportName);
    File(csvPath).writeAsStringSync(_buildCsv());
    File(reportPath).writeAsStringSync(_buildReport(csvPath));

    return Phase0LatencyArtifactPaths(csvPath: csvPath, reportPath: reportPath);
  }

  String _buildCsv() {
    final buffer = StringBuffer()
      ..writeln(
        'sample_index,is_warmup,device_id,channel,note,velocity,'
        'native_t0_ns,rust_t1_ns,rust_t2_ns,flutter_t3_ns,'
        'native_to_rust_entry_ns,rust_processing_ns,'
        'rust_exit_to_flutter_ns,total_ns,engine_event_count',
      );
    for (final sample in _samples) {
      buffer.writeln(sample.toCsvRow());
    }
    return buffer.toString();
  }

  String _buildReport(String csvPath) {
    final measured = _samples.where((sample) => !sample.isWarmup).toList();
    final nativeToRust = _percentiles(
      measured.map((sample) => sample.nativeToRustEntryMs).toList(),
    );
    final rustProcessing = _percentiles(
      measured.map((sample) => sample.rustProcessingMs).toList(),
    );
    final rustToFlutter = _percentiles(
      measured.map((sample) => sample.rustExitToFlutterMs).toList(),
    );
    final total = _percentiles(
      measured.map((sample) => sample.totalMs).toList(),
    );
    final device = _device;

    return '''
# $_taskId $_platformName Latency Measurement

**Date:** ${DateTime.now().toIso8601String()}
**Build mode:** Release
**Warm-up hits discarded:** $phase0LatencyWarmupHits
**Measured hits:** ${measured.length}
**Raw CSV:** `$csvPath`

## Hardware / Software Matrix

| Item | Value |
|------|-------|
| Host OS | ${Platform.operatingSystemVersion} |
| MIDI device | ${device?.name ?? 'unknown'} |
| MIDI device id | ${device?.id ?? 'unknown'} |
| Measurement clock | $_clockDescription |
| Dart clock calibration uncertainty | ${_formatNs(_calibrationUncertaintyNs)} |

## Latency Summary

| Segment | p50 ms | p95 ms | p99 ms |
|---------|--------|--------|--------|
| Native T0 -> Rust T1 | ${nativeToRust.p50} | ${nativeToRust.p95} | ${nativeToRust.p99} |
| Rust T1 -> Rust T2 | ${rustProcessing.p50} | ${rustProcessing.p95} | ${rustProcessing.p99} |
| Rust T2 -> Flutter T3 | ${rustToFlutter.p50} | ${rustToFlutter.p95} | ${rustToFlutter.p99} |
| Native T0 -> Flutter T3 total | ${total.p50} | ${total.p95} | ${total.p99} |

## Notes

- Each hit is routed through the Phase 0 Rust runtime skeleton using a pre-resolved `kick` lane.
- Full MIDI note-to-lane mapping remains deferred to Phase 1.
''';
  }

  String get _taskId => Platform.isAndroid ? 'P0-07' : 'P0-05';

  String get _platformName => Platform.isAndroid ? 'Android' : 'Windows';

  String _artifactPrefix() {
    return Platform.isAndroid
        ? 'p0-07-android-latency'
        : 'p0-05-windows-latency';
  }

  String get _clockDescription {
    if (Platform.isAndroid) {
      return 'Android System.nanoTime; Flutter T3 calibrated from Dart Stopwatch';
    }
    if (Platform.isWindows) {
      return 'Windows QueryPerformanceCounter; Flutter T3 calibrated from Dart Stopwatch';
    }
    return 'Platform monotonic clock; Flutter T3 calibrated from Dart Stopwatch';
  }
}

class Phase0LatencySample {
  const Phase0LatencySample({
    required this.sampleIndex,
    required this.isWarmup,
    required this.deviceId,
    required this.channel,
    required this.note,
    required this.velocity,
    required this.nativeTimestampNs,
    required this.rustEntryNs,
    required this.rustExitNs,
    required this.flutterCallbackNs,
    required this.engineEventCount,
  });

  final int sampleIndex;
  final bool isWarmup;
  final int deviceId;
  final int channel;
  final int note;
  final int velocity;
  final int nativeTimestampNs;
  final int rustEntryNs;
  final int rustExitNs;
  final int flutterCallbackNs;
  final int engineEventCount;

  int get nativeToRustEntryNs => rustEntryNs - nativeTimestampNs;

  int get rustProcessingNs => rustExitNs - rustEntryNs;

  int get rustExitToFlutterNs => flutterCallbackNs - rustExitNs;

  int get totalNs => flutterCallbackNs - nativeTimestampNs;

  double get nativeToRustEntryMs => nativeToRustEntryNs / 1000000.0;

  double get rustProcessingMs => rustProcessingNs / 1000000.0;

  double get rustExitToFlutterMs => rustExitToFlutterNs / 1000000.0;

  double get totalMs => totalNs / 1000000.0;

  String toCsvRow() {
    return [
      sampleIndex,
      isWarmup,
      deviceId,
      channel,
      note,
      velocity,
      nativeTimestampNs,
      rustEntryNs,
      rustExitNs,
      flutterCallbackNs,
      nativeToRustEntryNs,
      rustProcessingNs,
      rustExitToFlutterNs,
      totalNs,
      engineEventCount,
    ].join(',');
  }

  String toConsoleLine() {
    final phase = isWarmup ? 'warmup' : 'measured';
    return 'P0-05,$sampleIndex,$phase,note=$note,velocity=$velocity,'
        't0=$nativeTimestampNs,t1=$rustEntryNs,t2=$rustExitNs,'
        't3=$flutterCallbackNs,total_ns=$totalNs';
  }
}

class Phase0LatencyProgress {
  const Phase0LatencyProgress({
    required this.message,
    required this.csvPath,
    required this.reportPath,
    required this.completed,
  });

  final String message;
  final String? csvPath;
  final String? reportPath;
  final bool completed;
}

class Phase0LatencyArtifactPaths {
  const Phase0LatencyArtifactPaths({
    required this.csvPath,
    required this.reportPath,
  });

  final String csvPath;
  final String reportPath;
}

class _Percentiles {
  const _Percentiles({required this.p50, required this.p95, required this.p99});

  final String p50;
  final String p95;
  final String p99;
}

_Percentiles _percentiles(List<double> values) {
  if (values.isEmpty) {
    return const _Percentiles(p50: 'n/a', p95: 'n/a', p99: 'n/a');
  }
  final sorted = [...values]..sort();
  return _Percentiles(
    p50: _formatMs(_nearestRank(sorted, 0.50)),
    p95: _formatMs(_nearestRank(sorted, 0.95)),
    p99: _formatMs(_nearestRank(sorted, 0.99)),
  );
}

double _nearestRank(List<double> sorted, double percentile) {
  final index = (sorted.length * percentile).ceil() - 1;
  return sorted[index.clamp(0, sorted.length - 1)];
}

String _formatMs(double value) => value.toStringAsFixed(3);

String _formatNs(int value) => '${(value / 1000000.0).toStringAsFixed(3)} ms';

String _joinPath(String directory, String fileName) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$fileName';
  }
  return '$directory${Platform.pathSeparator}$fileName';
}
