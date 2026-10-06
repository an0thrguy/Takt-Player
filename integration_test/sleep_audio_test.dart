// Actual libmpv check with silence and an isolated in-memory store.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/playback/sleep_timer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native sleep fade restores volume and pauses shared engine', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final dir = await Directory.systemTemp.createTemp('takt-sleep-audio-');
    final bytes = Uint8List(44 + 44100 * 2 * 15);
    final data = ByteData.sublistView(bytes);
    void word(int offset, String value) {
      bytes.setRange(offset, offset + value.length, value.codeUnits);
    }

    word(0, 'RIFF');
    data.setUint32(4, bytes.length - 8, Endian.little);
    word(8, 'WAVE');
    word(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, 44100, Endian.little);
    data.setUint32(28, 88200, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    word(36, 'data');
    data.setUint32(40, bytes.length - 44, Endian.little);
    final file = await File('${dir.path}/silence.wav').writeAsBytes(bytes);
    final store = TaktStore.memory()..write('settings', {'volume': 70});
    final engine = MediaEngine();
    final track = Track(
      id: 'silent',
      path: file.path,
      originalTitle: 'Silent native probe',
    );
    final queue = TaktQueue(store, engine, () => [track]);
    var now = DateTime(2026);
    final timer = SleepTimer(
      now: () => now,
      pause: queue.stop,
      quit: () async {},
      setVolume: engine.volume,
      getVolume: () => engine.player.state.volume,
    );
    try {
      await engine.volume(70);
      await queue.start([track.id], track.id);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(engine.player.state.playing, true);
      await timer.start(const Duration(seconds: 20), fade: true);
      now = now.add(const Duration(seconds: 10));
      await timer.tick();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(engine.player.state.volume, closeTo(70 * 10 / 15, .5));
      expect(store.read('settings')['volume'], 70);
      now = now.add(const Duration(seconds: 10));
      await timer.tick();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(engine.player.state.playing, false);
      expect(engine.player.state.volume, closeTo(70, .5));
      expect(queue.ids, [track.id]);
    } finally {
      await timer.cancel();
      timer.dispose();
      queue.dispose();
      await engine.player.dispose();
      store.close();
      await dir.delete(recursive: true);
    }
  });
}
