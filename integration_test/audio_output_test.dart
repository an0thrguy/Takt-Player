// Native Linux integration checks; fixtures and reports live in /tmp to keep user data untouched.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:takt/core/track.dart';
import 'package:takt/playback/engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Takt owns an independent unmuted system audio stream', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final engine = MediaEngine();
    try {
      await engine.volume(1);
      await engine.open(
        Track(
          id: 'probe',
          path: '/tmp/takt-smoke.wav',
          originalTitle: 'Audio output check',
        ),
        play: true,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      final result = await Process.run('pactl', [
        '--format=json',
        'list',
        'sink-inputs',
      ]);
      expect(result.exitCode, 0);
      final streams = (jsonDecode(result.stdout as String) as List)
          .where((s) => s['properties']['application.name'] == 'Takt')
          .toList();
      expect(streams, hasLength(1));
      expect(streams.single['mute'], false);
      expect(streams.single['corked'], false);
      expect(engine.player.state.volume, 1);
    } finally {
      await engine.player.dispose();
    }
  });
}
