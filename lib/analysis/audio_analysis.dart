import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;

import 'spectrum.dart';

// Decode the current file independently; an isolate keeps FFT work off the UI.
class AudioAnalysis {
  List<double> values = [];
  final List<List<double>> spectra = [];
  final _scaler = SpectrumScaler();
  SendPort? _control;
  void Function()? _cancel;
  int _generation = 0;
  bool _active = true;
  int _lastFrame = -1;
  double _lastSensitivity = -1;
  List<double> _lastValues = [];
  void setActive(bool value) {
    if (value == _active) return;
    _active = value;
    _control?.send(['active', value]);
  }

  // Legacy RMS utility remains useful for PCM regression checks.
  static List<double> envelope(Int16List samples) {
    final result = <double>[];
    for (int start = 0; start < samples.length; start += 400) {
      double sum = 0;
      final end = math.min(samples.length, start + 400);
      for (int i = start; i < end; i++) {
        final v = samples[i] / 32768;
        sum += v * v;
      }
      result.add(math.sqrt(sum / (end - start)));
    }
    return result;
  }

  Future<void> load(String path) async {
    _cancel?.call();
    final generation = ++_generation;
    _control = null;
    values = [];
    spectra.clear();
    _scaler.reset();
    _lastFrame = -1;
    final port = ReceivePort(), done = Completer<void>();
    bool cancelled = false;
    void finish() {
      if (!done.isCompleted) done.complete();
      port.close();
    }

    _cancel = () {
      cancelled = true;
      _control?.send(['cancel']);
    };
    port.listen((message) {
      if (message is SendPort) {
        if (cancelled || generation != _generation) {
          message.send(['cancel']);
        } else {
          _control = message;
          message.send(['active', _active]);
        }
      } else {
        final data = message as List;
        if (data[0] == 'done') {
          finish();
          return;
        }
        if (generation == _generation && !cancelled && data[0] == 'data') {
          values.addAll((data[1] as List).cast<double>());
          spectra.addAll(
            (data[2] as List).map((v) => (v as List).cast<double>()),
          );
        }
      }
    });
    try {
      await Isolate.spawn(_decode, [path, port.sendPort, _active]);
      await done.future;
    } catch (_) {
      finish();
    }
    if (generation == _generation) {
      _control = null;
      _cancel = null;
    }
  }

  List<double> frame(
    Duration position,
    bool playing, {
    double sensitivity = 1,
  }) {
    if (!playing || spectra.isEmpty) return [];
    final index = position.inMilliseconds ~/ 50;
    if (index < 0 || index >= spectra.length) return [];
    if (_lastFrame != index || _lastSensitivity != sensitivity) {
      _lastFrame = index;
      _lastSensitivity = sensitivity;
      _lastValues = _scaler.scale(spectra[index], sensitivity: sensitivity);
    }
    return _lastValues;
  }

  void dispose() {
    _cancel?.call();
    _generation++;
    _control = null;
  }
}

// The worker owns its FFmpeg process and handles cancellation even during startup.
Future<void> _decode(List arguments) async {
  final path = arguments[0] as String, output = arguments[1] as SendPort;
  bool active = arguments[2] as bool, cancelled = false;
  Process? process;
  final controls = ReceivePort();
  controls.listen((message) {
    final command = message as List;
    if (command[0] == 'cancel') {
      cancelled = true;
      process?.kill(ProcessSignal.sigcont);
      process?.kill();
    } else {
      active = command[1] as bool;
      process?.kill(active ? ProcessSignal.sigcont : ProcessSignal.sigstop);
    }
  });
  output.send(controls.sendPort);
  try {
    process = await Process.start('ffmpeg', [
      '-v',
      'error',
      '-i',
      path,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '${FrequencySpectrum.sampleRate}',
      '-f',
      's16le',
      'pipe:1',
    ]);
    if (cancelled) {
      process.kill();
      await process.exitCode;
      return;
    }
    if (!active) process.kill(ProcessSignal.sigstop);
    unawaited(process.stderr.drain<void>());
    final ring = Int16List(FrequencySpectrum.window);
    int written = 0, hop = 0, total = 0, rmsFrames = 0;
    double energy = 0;
    int? carry;
    await for (final chunk in process.stdout) {
      if (cancelled) break;
      final rms = <double>[], frames = <List<double>>[];
      void sample(int value) {
        if (value >= 32768) value -= 65536;
        ring[written] = value;
        written = (written + 1) % ring.length;
        energy += (value / 32768) * (value / 32768);
        hop++;
        total++;
        // Integer sample rate has alternating 1102/1103-sample 50ms windows.
        final boundary =
            ((rmsFrames + frames.length + 1) *
                    FrequencySpectrum.sampleRate /
                    20)
                .floor();
        if (total >= boundary) {
          rms.add(math.sqrt(energy / hop));
          hop = 0;
          energy = 0;
          final ordered = Int16List(ring.length);
          for (int i = 0; i < ring.length; i++) {
            ordered[i] = ring[(written + i) % ring.length];
          }
          frames.add(FrequencySpectrum.analyze(ordered));
        }
      }

      int i = 0;
      if (carry != null && chunk.isNotEmpty) {
        sample(carry | chunk[0] << 8);
        carry = null;
        i = 1;
      }
      for (; i + 1 < chunk.length; i += 2) {
        sample(chunk[i] | chunk[i + 1] << 8);
      }
      if (i < chunk.length) carry = chunk[i];
      rmsFrames += frames.length;
      if (frames.isNotEmpty) output.send(['data', rms, frames]);
    }
    if (cancelled) {
      process.kill(ProcessSignal.sigcont);
      process.kill();
    }
    await process.exitCode;
  } catch (_) {
    /* Playback remains usable when optional analysis fails. */
  } finally {
    controls.close();
    output.send(['done']);
  }
}
