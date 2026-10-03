// Regression checks for analysis; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/analysis/audio_analysis.dart';

void main() {
  test('PCM silence is flat and signal has nonzero energy', () {
    expect(AudioAnalysis.envelope(Int16List(800)).every((v) => v == 0), true);
    final values = AudioAnalysis.envelope(
      Int16List.fromList(List.filled(800, 16384)),
    );
    expect(values.length, 2);
    expect(values.first, closeTo(.5, .01));
  });
}
