// Regression checks for analysis; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/analysis/audio_analysis.dart';

void main() {
  test('desktop spectrum interpolates between fifty-millisecond frames', () {
    final analysis = AudioAnalysis(now: () => Duration.zero);
    analysis.spectra.addAll([
      [.01, .5],
      [.4, .5],
      [.8, .5],
    ]);
    final start = analysis.frame(Duration.zero, true).first;
    final middle = analysis.frame(const Duration(milliseconds: 25), true).first;
    expect(middle, greaterThan(start));
    expect(
      analysis.frame(const Duration(milliseconds: 50), true).first,
      greaterThan(middle),
    );
    analysis.dispose();
  });
  test(
    'desktop spectrum advances on its clock and reanchors after pause or seek',
    () {
      var clock = Duration.zero;
      final analysis = AudioAnalysis(now: () => clock);
      analysis.spectra.addAll([
        [.01, .5],
        [.2, .5],
        [.4, .5],
        [.5, .5],
      ]);
      final first = analysis.frame(Duration.zero, true).first;
      clock = const Duration(milliseconds: 75);
      expect(analysis.frame(Duration.zero, true).first, greaterThan(first));
      expect(analysis.frame(Duration.zero, false), isEmpty);
      clock = const Duration(seconds: 2);
      expect(analysis.frame(Duration.zero, true).first, closeTo(first, .001));
      expect(
        analysis.frame(const Duration(milliseconds: 100), true).first,
        greaterThan(first),
      );
      analysis.dispose();
    },
  );
  test('PCM silence is flat and signal has nonzero energy', () {
    expect(AudioAnalysis.envelope(Int16List(800)).every((v) => v == 0), true);
    final values = AudioAnalysis.envelope(
      Int16List.fromList(List.filled(800, 16384)),
    );
    expect(values.length, 2);
    expect(values.first, closeTo(.5, .01));
  });
}
