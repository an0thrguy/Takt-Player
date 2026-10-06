import 'dart:async';

import 'package:flutter/foundation.dart';

// A session-local timer. Fade volume is never persisted as a user preference.
class SleepTimer extends ChangeNotifier {
  final Future<void> Function() pause, quit;
  final Future<void> Function(double) setVolume;
  final double Function() getVolume;
  final DateTime Function() now;
  final void Function(Object)? onError;
  SleepTimer({
    required this.pause,
    required this.quit,
    required this.setVolume,
    required this.getVolume,
    DateTime Function()? now,
    this.onError,
  }) : now = now ?? DateTime.now;
  Timer? _timer;
  DateTime? deadline;
  bool fade = false, exitWhenDone = false;
  double? _baseline, currentVolume;
  int _generation = 0;
  Future<void>? _operation;
  bool _disposed = false, _quitting = false;
  bool get active => deadline != null;
  bool get fading => _baseline != null;
  Duration get remaining {
    final duration = deadline?.difference(now()) ?? Duration.zero;
    return duration.isNegative ? Duration.zero : duration;
  }

  Future<void> start(
    Duration duration, {
    bool fade = false,
    bool exitWhenDone = false,
  }) async {
    if (duration <= Duration.zero || duration > const Duration(hours: 4)) {
      throw ArgumentError('Duration must be positive and at most four hours');
    }
    await cancel();
    if (_disposed) return;
    this.fade = fade;
    this.exitWhenDone = exitWhenDone;
    deadline = now().add(duration);
    _generation++;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(
        tick().catchError((Object error) {
          onError?.call(error);
        }),
      ),
    );
    notifyListeners();
  }

  Future<void> tick() {
    if (!active || _disposed) return Future.value();
    if (_operation != null) return _operation!;
    final operation = _tick(_generation);
    _operation = operation;
    operation.then(
      (_) {
        if (identical(_operation, operation)) _operation = null;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_operation, operation)) _operation = null;
        _timer?.cancel();
        deadline = null;
        if (!_disposed) notifyListeners();
      },
    );
    return operation;
  }

  Future<void> _tick(int generation) async {
    if (remaining == Duration.zero) {
      _timer?.cancel();
      _timer = null;
      deadline = null;
      await pause();
      if (_disposed || generation != _generation) return;
      if (_baseline != null) {
        await setVolume(_baseline!);
        if (_disposed || generation != _generation) return;
      }
      _baseline = null;
      currentVolume = null;
      notifyListeners();
      if (exitWhenDone) {
        _quitting = true;
        try {
          await quit();
        } finally {
          _quitting = false;
        }
      }
      return;
    }
    if (fade && remaining <= const Duration(seconds: 15)) {
      _baseline ??= getVolume().clamp(0, 100);
      final next = _baseline! * remaining.inMilliseconds / 15000;
      await setVolume(next);
      if (_disposed || generation != _generation) return;
      currentVolume = next;
    }
    if (!_disposed && generation == _generation) notifyListeners();
  }

  Future<void> cancel({bool restore = true}) async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    deadline = null;
    final operation = _operation;
    if (operation != null && !_quitting) {
      try {
        await operation;
      } catch (_) {}
    }
    final baseline = _baseline;
    _baseline = null;
    currentVolume = null;
    if (restore && baseline != null) await setVolume(baseline);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
