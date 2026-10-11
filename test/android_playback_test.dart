import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/platform/android_playback.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  test('notification controls share the queue and recents saves paused session', () async {
    final store = TaktStore.memory();
    addTearDown(store.close);
    final tracks = [
      Track(id: 'a', path: '/a', originalTitle: 'A'),
      Track(id: 'b', path: '/b', originalTitle: 'B'),
    ];
    final queue = TaktQueue(store, TestEngine(), () => tracks);
    var quit = false;
    late AndroidAudioHandler handler;
    handler = AndroidAudioHandler(
      queue,
      shutdown: () async {
        // The service must still be alive while the native player is disposed.
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.ready,
        );
        quit = true;
      },
    );
    addTearDown(handler.dispose);
    await queue.start(['a', 'b'], 'a');
    await handler.skipToNext();
    expect(queue.currentId, 'b');
    await handler.skipToPrevious();
    expect(queue.currentId, 'a');
    await handler.seek(const Duration(seconds: 3));
    await handler.stop();
    expect(queue.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    await handler.onTaskRemoved();
    expect(queue.playing, isFalse);
    expect(store.read('session')['position'], 3000);
    expect(quit, isTrue);
  });
}
