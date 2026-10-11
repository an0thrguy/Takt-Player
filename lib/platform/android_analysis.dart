import 'dart:async';

import 'package:flutter/services.dart';

import '../analysis/audio_analysis.dart';
import '../analysis/spectrum.dart';

// Native decoding supplies timestamped FFT bands, without microphone permission.
class AndroidAnalysis extends AudioAnalysis {
  final Future<void> Function(String, Map<String, dynamic>) invoke;
  StreamSubscription<dynamic>? _subscription;
  final _frames = <int, List<double>>{};
  final _scaler = SpectrumScaler();
  final Duration Function() now;
  int? _reportedPosition;
  Duration _reportedAt = Duration.zero;
  int _generation = 0;
  String? _uri;
  int _lastPosition = 0;
  int _sentPosition = -1000;
  bool _active = true;
  AndroidAnalysis({
    bool connect = true,
    Duration Function()? now,
    Future<void> Function(String, Map<String, dynamic>)? invoke,
  }) : now =
           now ??
           (() {
             final clock = Stopwatch()..start();
             return () => clock.elapsed;
           })(),
       invoke =
           invoke ??
           ((method, data) =>
               const MethodChannel('takt/android')
                   .invokeMethod<void>(method, data)) {
    if (connect) {
      _subscription = const EventChannel('takt/spectrum')
          .receiveBroadcastStream()
          .listen(
            (event) {
              final value = Map<Object?, Object?>.from(event as Map);
              acceptBatch(
                value['generation'] as int,
                value['index'] as int,
                (value['frames'] as List)
                    .map(
                      (frame) => (frame as List)
                          .cast<num>()
                          .map((v) => v.toDouble())
                          .toList(),
                    )
                    .toList(),
              );
            },
            onError: (Object _) {
              _frames.clear();
            },
          );
    }
  }
  void acceptBatch(int generation, int index, List<List<double>> frames) {
    if (generation != _generation) return;
    for (var i = 0; i < frames.length; i++) {
      _frames[index + i] = frames[i];
    }
  }

  @override
  Future<void> load(String path) async {
    _uri = path;
    _lastPosition = 0;
    _reportedPosition = null;
    _sentPosition = -1000;
    _generation++;
    _frames.clear();
    _scaler.reset();
    await invoke('analyze', {'uri': path, 'generation': _generation});
  }

  @override
  void setActive(bool value) {
    if (_active == value) return;
    _active = value;
    _reportedPosition = null;
    unawaited(invoke('analysisActive', {'active': value}));
  }

  @override
  List<double> frame(
    Duration position,
    bool playing, {
    double sensitivity = 1,
  }) {
    if (!playing || !_active) {
      _reportedPosition = null;
      return [];
    }
    final milliseconds = position.inMilliseconds;
    final time = now();
    if (_reportedPosition != milliseconds) {
      _reportedPosition = milliseconds;
      _reportedAt = time;
    }
    // Audio position events are sparse; interpolate samples using a monotonic clock.
    final projected =
        milliseconds + (time - _reportedAt).inMilliseconds.clamp(0, 250);
    final index = projected ~/ 50;
    final jumped = (milliseconds - _lastPosition).abs() > 2000;
    _lastPosition = milliseconds;
    if ((milliseconds - _sentPosition).abs() >= 200) {
      _sentPosition = milliseconds;
      unawaited(invoke('analysisPosition', {'position': milliseconds}));
    }
    var bands = _frames[index];
    final next = _frames[index + 1];
    if (bands != null && next != null && bands.length == next.length) {
      final fraction = (projected % 50) / 50;
      bands = List.generate(
        bands.length,
        (i) => bands![i] + (next[i] - bands[i]) * fraction,
      );
    }
    if (bands == null && jumped && _uri != null) {
      _generation++;
      _frames.clear();
      _scaler.reset();
      unawaited(
        invoke('analyze', {
          'uri': _uri,
          'generation': _generation,
          'position': milliseconds,
        }),
      );
    }
    // Bound the cache to three seconds behind and twelve ahead.
    _frames.removeWhere(
      (frame, _) => frame < index - 60 || frame > index + 240,
    );
    return bands == null ? [] : _scaler.scale(bands, sensitivity: sensitivity);
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _frames.clear();
    unawaited(invoke('analysisCancel', {}));
    super.dispose();
  }
}
