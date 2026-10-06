import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  testWidgets('standalone close invokes close policy instead of full exit', (
    tester,
  ) async {
    final store = TaktStore.memory();
    final lib = MusicLibrary(store);
    final queue = TaktQueue(store, TestEngine(), () => lib.tracks);
    int closes = 0, exits = 0;
    await tester.pumpWidget(
      TaktApp(
        library: lib,
        queue: queue,
        store: store,
        close: () async {
          closes++;
        },
        exit: () async {
          exits++;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('window-close')));
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(exits, 0);
    await tester.pumpWidget(const SizedBox());
    lib.dispose();
    queue.dispose();
    store.close();
  });
}
