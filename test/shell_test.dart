// Regression checks for shell; use independent local fixtures and mocked boundaries where appropriate.
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
    'tap handle opens menu, long row selects and handle hold reorders whole row',
    (tester) async {
      final store = TaktStore.memory();
      store.write('settings', {'locale': 'ru'});
      final library = MusicLibrary(store);
      library.tracks = [
        Track(id: 'a', path: '/a', originalTitle: 'A'),
        Track(id: 'b', path: '/b', originalTitle: 'B'),
      ];
      final engine = TestEngine();
      final queue = TaktQueue(store, engine, () => library.tracks);
      await tester.pumpWidget(
        TaktApp(library: library, queue: queue, store: store),
      );
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      expect(find.text('Играть следующим'), findsOneWidget);
      expect(store.read('manual:all'), isNull);
      await tester.tap(find.text('Выделить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(queue.currentId, isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.menu).first),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump();
      for (var step = 0; step < 10; step++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(store.read('manual:all'), true);
      expect(library.visible(manual: true).map((t) => t.id), ['b', 'a']);
      expect(engine.plays, 0);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      queue.dispose();
      store.close();
    },
  );

  testWidgets('search filters 500 rows and preserves playback snapshot', (
    tester,
  ) async {
    final store = TaktStore.memory(),
        library = MusicLibrary(TaktStore.memory());
    library.tracks = [
      for (var i = 0; i < 500; i++)
        Track(id: '$i', path: '/$i.wav', originalTitle: 'Song $i'),
    ];
    final queue = TaktQueue(store, TestEngine(), () => library.tracks);
    await tester.pumpWidget(
      TaktApp(library: library, queue: queue, store: store),
    );
    await tester.enterText(find.byKey(const Key('track-search')), '499');
    await tester.pumpAndSettle();
    expect(find.text('Song 499'), findsOneWidget);
    await tester.tap(find.text('Song 499'));
    await tester.pumpAndSettle();
    expect(queue.ids, ['499']);
    await tester.enterText(find.byKey(const Key('track-search')), '');
    await tester.pumpAndSettle();
    expect(queue.ids, ['499']);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    library.store.close();
    queue.dispose();
    store.close();
  });

  testWidgets('search shown first and playlist form opens only on request', (
    tester,
  ) async {
    final store = TaktStore.memory();
    store.write('settings', {'locale': 'ru'});
    final library = MusicLibrary(store);
    final queue = TaktQueue(store, TestEngine(), () => library.tracks);
    await tester.pumpWidget(
      TaktApp(library: library, queue: queue, store: store),
    );
    expect(find.byKey(const Key('track-search')), findsOneWidget);
    expect(find.byKey(const Key('playlist-create')), findsNothing);
    await tester.tap(find.byKey(const Key('new-playlist')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playlist-create')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('playlist-create')), 'Вечер');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(library.playlists.single.name, 'Вечер');
    expect(find.byKey(const Key('track-search')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    queue.dispose();
    store.close();
  });
}
