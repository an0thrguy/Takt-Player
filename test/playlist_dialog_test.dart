import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  testWidgets('playlist creation is modal and preserves search on cancel', (
    tester,
  ) async {
    final store = TaktStore.memory();
    store.write('settings', {'locale': 'ru'});
    final library = MusicLibrary(store);
    final queue = TaktQueue(store, TestEngine(), () => library.tracks);
    await tester.pumpWidget(
      TaktApp(library: library, queue: queue, store: store),
    );
    await tester.enterText(
      find.byKey(const Key('track-search')),
      'saved query',
    );
    await tester.tap(find.byKey(const Key('new-playlist')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('track-search')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(library.playlists, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('track-search')))
          .controller!
          .text,
      'saved query',
    );
    await tester.tap(find.byKey(const Key('new-playlist')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('playlist-create')),
      '  My Mix  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(library.playlists.single.name, 'My Mix');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    queue.dispose();
    store.close();
  });
}
