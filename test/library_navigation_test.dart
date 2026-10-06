import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  testWidgets(
    'actual playback records history and album cards lead to tracks',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TaktStore.memory();
      store.write('settings', {'locale': 'en'});
      final lib = MusicLibrary(store);
      lib.tracks = [
        Track(
          id: 'a',
          path: '/a',
          originalTitle: 'Track A',
          artist: 'Artist A',
          album: 'Album A',
        ),
      ];
      final queue = TaktQueue(store, TestEngine(), () => lib.tracks);
      await tester.pumpWidget(
        TaktApp(library: lib, queue: queue, store: store),
      );
      await queue.start(['a'], 'a');
      await tester.pumpAndSettle();
      expect((store.read('recentlyPlayed') as Map?)?.containsKey('a'), true);
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(find.text('Album A'), findsOneWidget);
      await tester.tap(find.text('Album A'));
      await tester.pumpAndSettle();
      expect(find.text('Track A'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      lib.dispose();
      queue.dispose();
      store.close();
    },
  );
  test('queue reports the completed opening state', () async {
    final store = TaktStore.memory();
    final t = Track(id: 'a', path: '/a', originalTitle: 'A');
    final queue = TaktQueue(store, TestEngine(), () => [t]);
    final states = <bool>[];
    queue.addListener(() => states.add(queue.opening));
    await queue.start(['a'], 'a');
    expect(states.last, false);
    queue.dispose();
    store.close();
  });
}
