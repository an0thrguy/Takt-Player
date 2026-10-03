// Native Linux integration checks; fixtures and reports live in /tmp to keep user data untouched.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/playback/queue.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Linux format playback seek EOF and queue modes', (tester) async {
    MediaKit.ensureInitialized();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Takt: audio format checks')),
      ),
    );
    final engine = MediaEngine();
    await engine.volume(0);
    final results = <Map<String, Object?>>[];
    final files = await Directory('/tmp/takt-formats')
        .list()
        .where((f) => f is File)
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final errors = <String>[];
      final subscription = engine.player.stream.error.listen(errors.add);
      await engine.open(
        Track(id: file.path, path: file.path, originalTitle: file.path),
        play: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(engine.player.state.playing, isTrue, reason: file.path);
      expect(
        engine.player.state.position.inMilliseconds,
        greaterThan(100),
        reason: file.path,
      );
      await engine.seek(const Duration(milliseconds: 1200));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        engine.player.state.position.inMilliseconds,
        greaterThanOrEqualTo(1000),
        reason: file.path,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(engine.player.state.completed, isTrue, reason: file.path);
      expect(errors, isEmpty, reason: file.path);
      results.add({
        'file': file.path.split('/').last,
        'play': true,
        'seek': true,
        'end': true,
      });
      await subscription.cancel();
    }
    final store = TaktStore.memory();
    final tracks = [
      for (final id in ['a', 'b'])
        Track(id: id, path: '/tmp/takt-formats/check.flac', originalTitle: id),
    ];
    final queue = TaktQueue(store, engine, () => tracks);
    final playing = engine.player.stream.playing.listen(queue.updatePlaying),
        completed = engine.player.stream.completed.listen((value) {
          if (value) queue.completed(queue.currentId);
        });
    queue.mode = QueueMode.once;
    await queue.start(['a', 'b'], 'a');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(queue.currentId, 'b');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(queue.playing, isFalse);
    queue.mode = QueueMode.loop;
    await queue.start(['a', 'b'], 'b');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(queue.currentId, 'a');
    queue.mode = QueueMode.single;
    await queue.start(['a', 'b'], 'b');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(queue.currentId, 'b');
    expect(queue.playing, isTrue);
    final corrupt = await File('/tmp/takt-corrupt.mp3').writeAsBytes([1, 2, 3]);
    tracks.add(
      Track(id: 'corrupt', path: corrupt.path, originalTitle: 'Corrupt'),
    );
    final errors = <String>[];
    final onError = engine.player.stream.error.listen((error) {
      errors.add(error);
      queue.stop();
    });
    await queue.start(['corrupt'], 'corrupt');
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(errors, isNotEmpty);
    expect(queue.playing, isFalse);
    await onError.cancel();
    await corrupt.delete();
    await engine.pause();
    await playing.cancel();
    await completed.cancel();
    queue.dispose();
    store.close();
    await engine.player.dispose();
    await File('/tmp/takt-format-results.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
