import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  testWidgets('position changes refresh player without rebuilding track rows', (
    tester,
  ) async {
    final store = TaktStore.memory();
    final lib = MusicLibrary(store);
    lib.tracks = [
      Track(id: 'a', path: '/a', originalTitle: 'Stable row', seconds: 90),
    ];
    final queue = TaktQueue(store, TestEngine(), () => lib.tracks);
    await tester.pumpWidget(TaktApp(library: lib, queue: queue, store: store));
    final before = tester.widget<Text>(find.text('Stable row'));
    queue.updatePosition(const Duration(seconds: 10));
    await tester.pump();
    expect(
      identical(before, tester.widget<Text>(find.text('Stable row'))),
      true,
    );
    await tester.pumpWidget(const SizedBox());
    lib.dispose();
    queue.dispose();
    store.close();
  });
}
