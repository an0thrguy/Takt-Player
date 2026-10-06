import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';
import 'package:takt/ui/glass.dart';
import 'package:takt/ui/visualizer.dart' as visuals;

import 'queue_test.dart' show TestEngine;

void main() {
  for (final size in [const Size(1200, 800), const Size(620, 520)]) {
    testWidgets('favorites and settings work at ${size.width} pixels', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TaktStore.memory();
      store.write('settings', {'dark': true, 'locale': 'ru', 'volume': 70.0});
      final library = MusicLibrary(store);
      library.tracks = [
        for (final id in ['a', 'b'])
          Track(id: id, path: '/$id', originalTitle: 'Track $id', seconds: 60),
      ];
      final queue = TaktQueue(store, TestEngine(), () => library.tracks);
      await tester.pumpWidget(
        TaktApp(
          library: library,
          queue: queue,
          store: store,
          amplitudes: () => List.generate(24, (i) => i == 3 ? .7 : .02),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Добавить в избранное'));
      await tester.pumpAndSettle();
      expect(library.favorites, {'a'});
      await tester.tap(find.byIcon(Icons.star_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Track a'), findsOneWidget);
      expect(find.text('Track b'), findsNothing);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-panel')), findsOneWidget);
      if (size.width == 1200) {
        expect(tester.getCenter(find.byIcon(Icons.play_arrow)).dx, 600);
        final visualizerToggle = find.widgetWithText(
          SwitchListTile,
          'Визуализатор',
        );
        await tester.tap(visualizerToggle);
        await tester.pumpAndSettle();
        expect(find.byType(visuals.WaveSignal), findsNothing);
        expect(tester.getCenter(find.byIcon(Icons.play_arrow)).dx, 600);
        await tester.tap(visualizerToggle);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Столбики'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Столбики'));
      await tester.pumpAndSettle();
      expect(store.read('settings')['visualizerStyle'], 'bars');
      expect(
        tester.widget<visuals.WaveSignal>(find.byType(visuals.WaveSignal)).bars,
        true,
      );
      final step = find.text('10 с');
      await tester.ensureVisible(step);
      await tester.tap(step);
      await tester.pumpAndSettle();
      expect(store.read('settings')['seekStep'], 10);
      final language = find.byKey(const Key('language-picker'));
      await tester.ensureVisible(language);
      await tester.pumpAndSettle();
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(store.read('settings')['locale'], 'en');
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();
      expect(store.read('settings')['locale'], 'ru');
      await tester.tap(find.byKey(const Key('close-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-panel')), findsNothing);
      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('volume-slider')), findsOneWidget);
      expect(find.byType(GlassSurface), findsWidgets);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('volume-slider')), findsNothing);
      await tester.ensureVisible(find.byIcon(Icons.playlist_add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.playlist_add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('playlist-create')), 'Road');
      await tester.pump();
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(find.text('Road'), findsNWidgets(2));
      expect(
        find.text('Избранное'),
        size.width == 1200 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      queue.dispose();
      store.close();
    });
  }
}
