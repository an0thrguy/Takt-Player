import 'dart:math' as math;
import 'dart:typed_data';

// Hann-windowed FFT with 24 logarithmic bands, low frequencies on the left.
// Work runs in the analysis isolate; no audio or microphone is captured here.
class FrequencySpectrum {
  static const sampleRate = 22050, window = 2048, bands = 24;
  static final _hann = List.generate(
    window,
    (i) => .5 - .5 * math.cos(2 * math.pi * i / (window - 1)),
  );
  static List<double> analyze(Int16List samples) {
    final real = Float64List(window), imag = Float64List(window);
    final count = math.min(samples.length, window);
    double mean = 0;
    for (int i = 0; i < count; i++) {
      mean += samples[i] / 32768;
    }
    mean /= math.max(1, count);
    for (int i = 0; i < count; i++) {
      real[i] = (samples[i] / 32768 - mean) * _hann[i];
    }
    for (int i = 1, j = 0; i < window; i++) {
      int bit = window >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final a = real[i];
        real[i] = real[j];
        real[j] = a;
      }
    }
    for (int length = 2; length <= window; length <<= 1) {
      final angle = -2 * math.pi / length;
      final wr = math.cos(angle), wi = math.sin(angle);
      for (int start = 0; start < window; start += length) {
        double r = 1, im = 0;
        for (int j = 0; j < length ~/ 2; j++) {
          final a = start + j, b = a + length ~/ 2;
          final br = real[b] * r - imag[b] * im;
          final bi = real[b] * im + imag[b] * r;
          real[b] = real[a] - br;
          imag[b] = imag[a] - bi;
          real[a] += br;
          imag[a] += bi;
          final next = r * wr - im * wi;
          im = r * wi + im * wr;
          r = next;
        }
      }
    }
    return List.generate(bands, (band) {
      final low = 50 * math.pow(200, band / bands);
      final high = 50 * math.pow(200, (band + 1) / bands);
      final first = math.max(1, (low * window / sampleRate).floor());
      final last = math.min(
        window ~/ 2 - 1,
        math.max(first, (high * window / sampleRate).ceil() - 1),
      );
      double energy = 0;
      for (int i = first; i <= last; i++) {
        energy += real[i] * real[i] + imag[i] * imag[i];
      }
      final value = math.sqrt(energy) * 4 / window;
      return value < .0001 ? 0 : value;
    });
  }
}

// Fast sensitivity reduction on peaks, slow recovery for quieter passages.
// Soft compression and a 20% margin prevent loud music from filling the panel.
class SpectrumScaler {
  double _peak = .08;
  List<double> scale(List<double> values, {double sensitivity = 1}) {
    final peak = values.isEmpty ? 0.0 : values.reduce(math.max);
    _peak = math.max(.02, math.max(peak, _peak * .985));
    return values.map((value) {
      if (value <= .0001) return 0.0;
      final normalized = value / _peak * sensitivity.clamp(.25, 2.5);
      return .8 * (1 - math.exp(-normalized * 1.8));
    }).toList();
  }

  void reset() {
    _peak = .08;
  }
}
