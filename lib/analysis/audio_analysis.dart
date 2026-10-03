import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

// Visualizer derived from actual file PCM, not a microphone; FFmpeg analyzes separately from playback.
class AudioAnalysis {
  List<double> values = [];
  Process? _process;
  int _generation = 0;
  bool _active = true;
  // Pause the Linux analysis process while playback is paused or the window is hidden.
  void setActive(bool value) {
    if (value == _active) return;
    _active = value;
    _process?.kill(value ? ProcessSignal.sigcont : ProcessSignal.sigstop);
  }

  // RMS over 400 samples: at 8 kHz, each point represents 50 ms of audio.
  static List<double> envelope(Int16List samples) {
    final result = <double>[];
    for (int start = 0; start < samples.length; start += 400) {
      double sum = 0;
      final end = math.min(samples.length, start + 400);
      for (int i = start; i < end; i++) {
        final value = samples[i] / 32768;
        sum += value * value;
      }
      result.add(math.sqrt(sum / (end - start)));
    }
    return result;
  }

  // Loading a file cancels old analysis; generation guards discard late data from the old process.
  Future<void> load(String path) async {
    final generation = ++_generation;
    _process?.kill(ProcessSignal.sigcont);
    _process?.kill();
    values = [];
    try {
      final process = await Process.start('ffmpeg', [
        '-v',
        'error',
        '-i',
        path,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '8000',
        '-f',
        's16le',
        'pipe:1',
      ]);
      if (generation != _generation) {
        process.kill();
        return;
      }
      _process = process;
      if (!_active) process.kill(ProcessSignal.sigstop);
      process.stderr.drain<void>();
      // A stdout chunk can split a 16-bit sample; carry its remaining byte into the next chunk.
      int? carry;
      int samples = 0;
      double sum = 0;
      await for (final chunk in process.stdout) {
        if (generation != _generation) break;
        int i = 0;
        if (carry != null && chunk.isNotEmpty) {
          int sample = carry | chunk[0] << 8;
          if (sample >= 32768) sample -= 65536;
          sum += math.pow(sample / 32768, 2);
          samples++;
          if (samples == 400) {
            values.add(math.sqrt(sum / 400));
            samples = 0;
            sum = 0;
          }
          carry = null;
          i = 1;
        }
        for (; i + 1 < chunk.length; i += 2) {
          int sample = chunk[i] | chunk[i + 1] << 8;
          if (sample >= 32768) sample -= 65536;
          sum += math.pow(sample / 32768, 2);
          samples++;
          if (samples == 400) {
            values.add(math.sqrt(sum / 400));
            samples = 0;
            sum = 0;
          }
        }
        if (i < chunk.length) carry = chunk[i];
      }
      await process.exitCode;
    } catch (_) {
      if (generation == _generation) values = [];
    }
  }

  // 24 amplitude points around the current position; adjust visual detail and gain here.
  List<double> frame(Duration position, bool playing) {
    if (!playing || values.isEmpty) return [];
    final index = position.inMilliseconds ~/ 50;
    return List.generate(24, (i) {
      final j = index + i - 12;
      return j >= 0 && j < values.length
          ? (values[j] * 3).clamp(0, 1).toDouble()
          : 0;
    });
  }

  // Resume a SIGSTOP process before terminating it so it can handle the termination signal.
  void dispose() {
    _generation++;
    _process?.kill(ProcessSignal.sigcont);
    _process?.kill();
  }
}
