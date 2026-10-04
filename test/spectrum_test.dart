import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/analysis/spectrum.dart';

Int16List tone(double hz, double amplitude) => Int16List.fromList(
  List.generate(
    2048,
    (i) => (math.sin(2 * math.pi * hz * i / 22050) * amplitude * 32767).round(),
  ),
);
void main() {
  test('silence stays flat and bass and treble occupy distinct bands', () {
    expect(FrequencySpectrum.analyze(Int16List(2048)), everyElement(0));
    final bass = FrequencySpectrum.analyze(tone(100, .5));
    final treble = FrequencySpectrum.analyze(tone(5000, .5));
    final low = bass.indexOf(bass.reduce(math.max));
    final high = treble.indexOf(treble.reduce(math.max));
    expect(low, lessThan(8));
    expect(high, greaterThan(18));
  });
  test('adaptive scaling keeps loud peaks below available height', () {
    final scaler = SpectrumScaler();
    final result = scaler.scale(List.filled(24, 1.0), sensitivity: 1);
    expect(result, everyElement(lessThan(.85)));
    expect(scaler.scale(List.filled(24, 0.0)), everyElement(0));
    final spectrum = FrequencySpectrum.analyze(tone(100, 1));
    expect(scaler.scale(spectrum).where((v) => v > .1).length, lessThan(12));
  });
}
