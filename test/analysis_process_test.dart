// Regression checks for analysis process; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/analysis/audio_analysis.dart';

void main() {
  test('real decoded tone drives envelope and pause is flat', () async {
    final dir = await Directory.systemTemp.createTemp('takt-analysis-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/tone.wav';
    final result = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-y',
      path,
    ]);
    expect(result.exitCode, 0);
    final analysis = AudioAnalysis();
    addTearDown(analysis.dispose);
    await analysis.load(path);
    expect(analysis.values.length, 20);
    expect(
      analysis.frame(const Duration(milliseconds: 500), true).any((v) => v > 0),
      isTrue,
    );
    expect(analysis.frame(const Duration(milliseconds: 500), false), isEmpty);
  });
}
