// Regression checks for queue; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/core/track.dart';

class TestEngine implements AudioEngine {
  int plays = 0;
  Track? track;
  @override
  Future<void> open(Track value, {bool play = false}) async {
    track = value;
    if (play) plays++;
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
}

class DelayedEngine extends TestEngine {
  final opened = Completer<void>(), release = Completer<void>();
  @override
  Future<void> open(Track value, {bool play = false}) async {
    opened.complete();
    await release.future;
    await super.open(value, play: play);
  }
}

void main() {
  test('seek before queued EOF keeps the chosen track', () async {
    final store = TaktStore.memory();
    addTearDown(store.close);
    final tracks = [
      Track(id: 'a', path: '/a', originalTitle: 'A'),
      Track(id: 'b', path: '/b', originalTitle: 'B'),
    ];
    final queue = TaktQueue(store, TestEngine(), () => tracks);
    await queue.start(['a', 'b'], 'a');
    final seek = queue.seek(Duration.zero), eof = queue.completed('a');
    await Future.wait([seek, eof]);
    expect(queue.currentId, 'a');
    expect(queue.playing, true);
  });

  test(
    'queued EOF cannot override an explicit stop or same-track restart',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final tracks = [
        Track(id: 'a', path: '/a', originalTitle: 'A'),
        Track(id: 'b', path: '/b', originalTitle: 'B'),
      ];
      final queue = TaktQueue(store, TestEngine(), () => tracks);
      await queue.start(['a', 'b'], 'a');
      final stopped = queue.stop(), eof = queue.completed('a');
      await Future.wait([stopped, eof]);
      expect(queue.currentId, 'a');
      expect(queue.playing, false);
      await queue.start(['a', 'b'], 'a');
      final restart = queue.start(['a', 'b'], 'a'),
          stale = queue.completed('a');
      await Future.wait([restart, stale]);
      expect(queue.currentId, 'a');
      expect(queue.playing, true);
    },
  );

  test(
    'removal waits for outstanding open and leaves playback paused',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final track = Track(id: 'a', path: '/a', originalTitle: 'A'),
          engine = DelayedEngine();
      final queue = TaktQueue(store, engine, () => [track]);
      final opening = queue.start(['a'], 'a');
      await engine.opened.future;
      final removal = queue.remove('a');
      engine.release.complete();
      await opening;
      await removal;
      expect(queue.currentId, isNull);
      expect(queue.playing, isFalse);
      expect(queue.ids, isEmpty);
    },
  );
  test(
    'shuffle consumes selected track before first cycle completes',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final tracks = [
        for (final id in ['a', 'b', 'c'])
          Track(id: id, path: '/$id', originalTitle: id),
      ];
      final queue = TaktQueue(store, TestEngine(), () => tracks);
      queue.mode = QueueMode.shuffle;
      await queue.start(['a', 'b', 'c'], 'a');
      final played = <String?>{queue.currentId};
      await queue.next();
      played.add(queue.currentId);
      await queue.next();
      played.add(queue.currentId);
      expect(played.length, 3);
    },
  );

  test(
    'EOF playing=false event still advances the intended playing queue',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final tracks = [
        Track(id: 'a', path: '/a', originalTitle: 'A'),
        Track(id: 'b', path: '/b', originalTitle: 'B'),
      ];
      final queue = TaktQueue(store, TestEngine(), () => tracks);
      await queue.start(['a', 'b'], 'a');
      queue.updatePlaying(false);
      await queue.completed('a');
      expect(queue.currentId, 'b');
    },
  );
  test('filtered queue reorder preserves invisible positions', () {
    final store = TaktStore.memory();
    addTearDown(store.close);
    final queue = TaktQueue(store, TestEngine(), () => []);
    queue.ids = ['a', 'hidden', 'b'];
    queue.reorderVisible(['b', 'a']);
    expect(queue.ids, ['b', 'hidden', 'a']);
  });

  test(
    'rapid track choices keep the last selection and ignore stale completion',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final tracks = [
        Track(id: 'a', path: '/a', originalTitle: 'A'),
        Track(id: 'b', path: '/b', originalTitle: 'B'),
      ];
      final engine = TestEngine();
      final queue = TaktQueue(store, engine, () => tracks);
      await Future.wait([
        queue.start(['a', 'b'], 'a'),
        queue.start(['a', 'b'], 'b'),
      ]);
      expect(queue.currentId, 'b');
      await queue.completed('a');
      expect(queue.currentId, 'b');
      expect(engine.track!.id, 'b');
    },
  );
  test('restore never plays and duplicate queue item is rejected', () async {
    final store = TaktStore.memory();
    addTearDown(store.close);
    final tracks = [
      Track(id: 'a', path: '/a.mp3', originalTitle: 'A'),
      Track(id: 'b', path: '/b.mp3', originalTitle: 'B'),
    ];
    final engine = TestEngine();
    final queue = TaktQueue(store, engine, () => tracks);
    await queue.start(['a', 'b'], 'b');
    await queue.seek(const Duration(seconds: 86));
    queue.save();
    final restored = TaktQueue(store, engine, () => tracks);
    final before = engine.plays;
    await restored.restore();
    expect(engine.plays, before);
    expect(restored.currentId, 'b');
    expect(restored.position.inSeconds, 86);
    expect(restored.add('b'), false);
    expect(restored.ids, ['a', 'b']);
  });
  test('once stops at end and loop returns to first', () async {
    final store = TaktStore.memory();
    addTearDown(store.close);
    final tracks = [
      Track(id: 'a', path: '/a', originalTitle: 'A'),
      Track(id: 'b', path: '/b', originalTitle: 'B'),
    ];
    final queue = TaktQueue(store, TestEngine(), () => tracks);
    await queue.start(['a', 'b'], 'b');
    queue.mode = QueueMode.once;
    await queue.next();
    expect(queue.playing, false);
    queue.mode = QueueMode.loop;
    await queue.next();
    expect(queue.currentId, 'a');
  });
}
