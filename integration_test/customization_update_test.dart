// Native screenshots of the approved design; personal files/settings stay untouched.
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';
import 'package:takt/platform/compact_window.dart';

import '../test/queue_test.dart' show TestEngine;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'appearance, editing, library, timer and compact render natively',
    (tester) async {
      await windowManager.ensureInitialized();
      await windowManager.setMinimumSize(const Size(1200, 800));
      await windowManager.setMaximumSize(const Size(1200, 800));
      await windowManager.setSize(const Size(1200, 800));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final initialNativeSize = await windowManager.getSize();
      final store = TaktStore.memory();
      store.write('settings', {
        'dark': true,
        'locale': 'ru',
        'volume': 75.0,
        'wave': true,
        'appearanceDark': {
          'backgroundVisualizer': true,
          'backgroundOpacity': .2,
        },
        'layout': {'hiddenControls': []},
      });
      final library = MusicLibrary(store);
      library.tracks = [
        Track(
          id: 'a',
          path: '/fixture/a.flac',
          originalTitle: 'Ночной маршрут',
          artist: 'Takt Sessions',
          album: 'City Sessions',
          seconds: 210,
        ),
        Track(
          id: 'b',
          path: '/fixture/b.flac',
          originalTitle: 'Тихий город',
          artist: 'Takt Sessions',
          album: 'City Sessions',
          seconds: 180,
        ),
        Track(
          id: 'c',
          path: '/fixture/c.flac',
          originalTitle: 'Горизонты',
          artist: 'Takt Sessions',
          album: 'City Sessions',
          seconds: 195,
        ),
      ];
      final queue = TaktQueue(store, TestEngine(), () => library.tracks);
      await queue.start(['a', 'b', 'c'], 'a');
      queue.updatePosition(const Duration(seconds: 52));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TaktApp(
            library: library,
            queue: queue,
            store: store,
            onCompactChanged: CompactWindowController(DesktopCompactWindow())
                .change,
            amplitudes: () => List.generate(
              24,
              (i) => .08 + .6 * math.pow(math.sin(i / 4), 8).toDouble(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/takt-customization-$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      await capture('dark');
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await capture('dark-settings');
      await tester.tap(find.byKey(const Key('close-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await capture('dark-track-menu');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pumpAndSettle();
      await capture('dark-volume');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();
      await capture('light');
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await capture('light-settings');
      final appearance = find.text('Оформление и пресеты');
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      await capture('appearance');
      await tester.tap(find.byKey(const Key('appearance-cancel')));
      await tester.pumpAndSettle();
      final edit = find.text('Редактировать интерфейс');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await capture('layout-edit');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Альбомы'));
      await tester.pumpAndSettle();
      await capture('albums');
      await tester.tap(find.byTooltip('Таймер сна'));
      await tester.pumpAndSettle();
      await capture('timer');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await windowManager.setMaximumSize(const Size(4000, 4000));
      await tester.tap(find.byTooltip('Компактный режим'));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(420, 240));
      await capture('compact');
      final compactNativeSize = await windowManager.getSize();
      if (initialNativeSize == const Size(1200, 800)) {
        expect(compactNativeSize, const Size(420, 240));
      }
      await tester.tap(find.byKey(const Key('compact-restore')));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpAndSettle();
      final restoredNativeSize = await windowManager.getSize();
      await File('/tmp/takt-window-geometry.json').writeAsString(
        jsonEncode({
          'initial': initialNativeSize.toString(),
          'compact': compactNativeSize.toString(),
          'restored': restoredNativeSize.toString(),
          'sizeHonored': compactNativeSize == const Size(420, 240),
        }),
      );
      if (initialNativeSize == const Size(1200, 800)) {
        expect(restoredNativeSize, initialNativeSize);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      queue.dispose();
      store.close();
    },
  );
}
