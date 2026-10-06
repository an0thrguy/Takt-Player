import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';
import 'package:takt/ui/compact_player.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  Future<(TaktStore, MusicLibrary, TaktQueue)> mount(
    WidgetTester tester,
    Size size, {
    Map<String, dynamic> settings = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TaktStore.memory();
    store.write('settings', {'locale': 'en', 'volume': 70, ...settings});
    final lib = MusicLibrary(store)
      ..tracks = [
        Track(id: 'a', path: '/a', originalTitle: 'Song', seconds: 100),
      ];
    final queue = TaktQueue(store, TestEngine(), () => lib.tracks);
    await tester.pumpWidget(TaktApp(store: store, library: lib, queue: queue));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      queue.dispose();
      lib.dispose();
      store.close();
    });
    return (store, lib, queue);
  }

  testWidgets(
    'appearance cancel discards preview and save persists only appearance',
    (tester) async {
      final (store, _, queue) = await mount(tester, const Size(1200, 850));
      await queue.start(['a'], 'a');
      queue.updatePosition(const Duration(seconds: 20));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final appearance = find.text('Appearance and presets');
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      final opacity = find.byKey(const Key('appearance-glassOpacity'));
      await tester.ensureVisible(opacity);
      await tester.drag(opacity, const Offset(-100, 0));
      await tester.pump();
      await tester.tap(find.byKey(const Key('appearance-cancel')));
      await tester.pumpAndSettle();
      expect(store.read('settings')['appearanceLight'], isNull);
      expect(queue.position, const Duration(seconds: 20));
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      await tester.ensureVisible(opacity);
      await tester.drag(opacity, const Offset(-100, 0));
      await tester.pump();
      await tester.tap(find.byKey(const Key('appearance-save')));
      await tester.pumpAndSettle();
      expect(
        store.read('settings')['appearanceLight']['glassOpacity'],
        lessThan(.84),
      );
      expect(store.read('settings')['volume'], 70);
    },
  );
  testWidgets(
    'main edit cancel restores collapse state and width at minimum window',
    (tester) async {
      final (store, _, _) = await mount(tester, const Size(620, 520));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final edit = find.text('Edit interface');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Editing interface'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.read('settings')['layout'], isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('timer dialog validates minutes, starts and can be cancelled', (
    tester,
  ) async {
    final (_, _, _) = await mount(
      tester,
      const Size(1200, 850),
      settings: {
        'layout': {'hiddenControls': []},
      },
    );
    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('sleep-minutes')), '0');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('sleep-start')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(ActionChip, '15'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sleep-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep-minutes')), findsNothing);
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel timer'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('maximum appearance values still allow narrow layout editing', (
    tester,
  ) async {
    final (_, _, _) = await mount(
      tester,
      const Size(620, 520),
      settings: {
        'appearanceLight': {'textScale': 1.5},
        'layout': {'playerHeight': 280, 'hiddenControls': []},
      },
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final edit = find.text('Edit interface');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(420, 240), const Size(320, 200)]) {
    testWidgets('compact shares playback and restores at $size', (
      tester,
    ) async {
      final (store, _, queue) = await mount(
        tester,
        const Size(1200, 850),
        settings: {
          'layout': {'hiddenControls': []},
        },
      );
      await queue.start(['a'], 'a');
      queue.updatePosition(const Duration(seconds: 22));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Compact mode'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.byType(CompactPlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('compact-play')));
      await tester.pumpAndSettle();
      expect(queue.playing, false);
      expect(queue.position, const Duration(seconds: 22));
      await tester.tap(find.byKey(const Key('compact-restore')));
      tester.view.physicalSize = const Size(1200, 850);
      await tester.pumpAndSettle();
      expect(find.byType(CompactPlayer), findsNothing);
      expect(queue.ids, ['a']);
      expect(store.read('settings')['volume'], 70);
    });
  }
}
