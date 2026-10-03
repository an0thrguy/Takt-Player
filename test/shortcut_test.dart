// Regression checks for shortcut; use independent local fixtures and mocked boundaries where appropriate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
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
}
