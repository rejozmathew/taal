import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taal/platform/latency/phase0_latency_capture.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/simple.dart';
import 'package:taal/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const TaalPhase0App());
}

class TaalPhase0App extends StatefulWidget {
  const TaalPhase0App({super.key});

  @override
  State<TaalPhase0App> createState() => _TaalPhase0AppState();
}

class _TaalPhase0AppState extends State<TaalPhase0App> {
  final _midi = createPhase0MidiAdapter();
  final _latencyCapture = Phase0LatencyCapture();
  final _events = <MidiNoteOnEvent>[];

  StreamSubscription<MidiNoteOnEvent>? _subscription;
  List<MidiInputDevice> _devices = const [];
  MidiInputDevice? _selected;
  String? _status;
  String? _latencyStatus;

  @override
  void initState() {
    super.initState();
    _subscription = _midi.noteOnEvents.listen((event) async {
      debugPrint(
        'MIDI NoteOn: device=${event.deviceId} channel=${event.channel} '
        'note=${event.note} velocity=${event.velocity} '
        'timestamp_ns=${event.timestampNs}',
      );
      final latencyProgress = await _latencyCapture.record(event);
      if (!mounted) {
        return;
      }
      setState(() {
        _events.insert(0, event);
        if (_events.length > 20) {
          _events.removeLast();
        }
        if (latencyProgress != null) {
          _latencyStatus = latencyProgress.message;
          if (latencyProgress.completed) {
            _latencyStatus =
                '${latencyProgress.message}\n'
                'CSV: ${latencyProgress.csvPath}\n'
                'Report: ${latencyProgress.reportPath}';
          }
        }
      });
    });
    _refreshDevices();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _midi.closeDevice();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    try {
      final devices = await _midi.listDevices();
      setState(() {
        _devices = devices;
        _selected = devices.isEmpty ? null : devices.first;
        _status = devices.isEmpty
            ? 'No ${_midi.platformName} MIDI input devices found.'
            : null;
      });
    } on Object catch (error) {
      setState(() {
        _status = 'MIDI device scan failed: $error';
      });
    }
  }

  Future<void> _openSelected() async {
    final selected = _selected;
    if (selected == null) {
      setState(() {
        _status = 'Select a MIDI input device first.';
      });
      return;
    }

    try {
      await _midi.openDevice(selected.id);
      final latencyProgress = _latencyCapture.start(
        device: selected,
        outputDir: _latencyOutputDir(),
      );
      setState(() {
        _status = 'Listening to ${selected.name}. Hit a pad to log NoteOn.';
        _latencyStatus = latencyProgress.message;
        _events.clear();
      });
    } on Object catch (error) {
      setState(() {
        _status = 'MIDI open failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = greet(name: 'Taal');

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Taal Phase 0')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rust bridge: $greeting'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<MidiInputDevice>(
                      isExpanded: true,
                      value: _selected,
                      hint: const Text('No MIDI input selected'),
                      items: [
                        for (final device in _devices)
                          DropdownMenuItem(
                            value: device,
                            child: Text('${device.id}: ${device.name}'),
                          ),
                      ],
                      onChanged: (device) {
                        setState(() {
                          _selected = device;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _refreshDevices,
                    child: const Text('Scan'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _openSelected,
                    child: const Text('Open'),
                  ),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!),
              ],
              if (_latencyStatus != null) ...[
                const SizedBox(height: 12),
                Text(_latencyStatus!),
              ],
              const SizedBox(height: 24),
              Text('${_midi.platformName} MIDI NoteOn events'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Text(
                      'device=${event.deviceId} channel=${event.channel} '
                      'note=${event.note} velocity=${event.velocity} '
                      'timestamp_ns=${event.timestampNs}',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _latencyOutputDir() {
    if (Platform.isAndroid) {
      return 'Taal/phase-0';
    }
    final configured = Platform.environment['TAAL_LATENCY_OUTPUT_DIR'];
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return [
      Directory.current.path,
      'artifacts',
      'phase-0',
    ].join(Platform.pathSeparator);
  }
}
