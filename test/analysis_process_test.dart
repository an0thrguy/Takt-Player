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
  test(
    'analysis can be replaced and disposed while startup is suspended',
    () async {
      final dir = await Directory.systemTemp.createTemp('takt-cancel-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/tone.wav';
      final result = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=100:duration=1',
        path,
      ]);
      expect(result.exitCode, 0);
      final analysis = AudioAnalysis();
      analysis.setActive(false);
      final first = analysis.load(path);
      final second = analysis.load(path);
      analysis.setActive(true);
      await Future.wait([first, second]).timeout(const Duration(seconds: 10));
      expect(analysis.spectra.length, 20);
      analysis.setActive(false);
      final cancelled = analysis.load(path);
      analysis.dispose();
      await cancelled.timeout(const Duration(seconds: 10));
    },
  );
}
