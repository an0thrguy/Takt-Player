// Regression checks for shortcut; use independent local fixtures and mocked boundaries where appropriate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  testWidgets('Super Q exits even with search focused and tray enabled', (
    tester,
  ) async {
    final store = TaktStore.memory();
    store.write('settings', {'closeToTray': true});
    final library = MusicLibrary(store);
    final queue = TaktQueue(store, TestEngine(), () => library.tracks);
    var exits = 0;
    await tester.pumpWidget(
      TaktApp(
        library: library,
        queue: queue,
        store: store,
        exit: () async {
          exits++;
        },
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    library.dispose();
    store.close();
  });
  testWidgets('playback keys seek, change track and leave typing untouched', (
    tester,
  ) async {
    final store = TaktStore.memory();
    store.write('settings', {'seekStep': 10, 'volume': 70.0});
    final library = MusicLibrary(store);
    library.tracks = [
      for (final id in ['a', 'b'])
        Track(id: id, path: '/$id', originalTitle: id, seconds: 60),
    ];
    final queue = TaktQueue(store, TestEngine(), () => library.tracks);
    await queue.start(['a', 'b'], 'a');
    await tester.pumpWidget(
      TaktApp(library: library, queue: queue, store: store),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(queue.position, const Duration(seconds: 10));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(queue.currentId, 'b');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(queue.playing, false);
    await tester.tap(find.byKey(const Key('track-search')));
    await tester.pump();
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.space),
      false,
      reason: 'Space must reach text input rather than be consumed',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(queue.playing, false);
    expect(queue.position, Duration.zero);
    await tester.tap(find.byKey(const Key('new-playlist')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playlist-create')));
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.space), false);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    queue.dispose();
    store.close();
  });
}
