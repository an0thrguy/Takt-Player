import 'package:flutter/material.dart';
import 'package:takt/platform/android_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  testWidgets('Android can choose the indexed Download folder', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TaktStore.memory();
    store.write('settings', {'locale': 'ru'});
    store.write('android:activeSource', 'external_primary:Music/');
    final library = AndroidMusicLibrary(store, scanner: () async => []);
    library.sources.add('external_primary:Music/');
    library.permissionGranted = true;
    final queue = TaktQueue(store, TestEngine(), () => library.tracks);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidMusicLibrary.channel, (call) async {
          if (call.method == 'folders') {
            return ['external_primary:Music/', 'external_primary:Download/'];
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidMusicLibrary.channel, null),
    );
    await tester.pumpWidget(
      TaktApp(mobile: true, library: library, queue: queue, store: store),
    );
    expect(find.byTooltip('Добавить папку'), findsNothing);
    expect(find.text('Music'), findsNothing);
    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Добавить музыкальную папку'));
    await tester.tap(find.text('Добавить музыкальную папку'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(library.sources, contains('external_primary:Download/'));
    expect(library.activeSource, 'external_primary:Download/');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    queue.dispose();
    store.close();
  });

  testWidgets(
    'Android artwork action opens preview before applying the image',
    (tester) async {
      final store = TaktStore.memory();
      store.write('settings', {'locale': 'ru'});
      final library = MusicLibrary(store);
      library.tracks.add(Track(id: 'a', path: '/a', originalTitle: 'A'));
      final queue = TaktQueue(store, TestEngine(), () => library.tracks);
      await tester.pumpWidget(
        TaktApp(
          mobile: true,
          library: library,
          queue: queue,
          store: store,
          pickImage: () async => '/missing-preview.png',
        ),
      );
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить обложку'));
      await tester.pumpAndSettle();
      expect(find.text('Предпросмотр'), findsOneWidget);
      expect(library.tracks.single.artwork, isNull);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(library.tracks.single.artwork, isNull);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      queue.dispose();
      store.close();
    },
  );

  for (final width in [360.0, 412.0]) {
    testWidgets('phone controls, settings and expanded player fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TaktStore.memory();
      store.write('settings', {'locale': 'ru'});
      final library = MusicLibrary(store);
      library.tracks.add(
        Track(
          id: 'a',
          path: '/a',
          originalTitle: 'A long music title',
          artist: 'Artist',
        ),
      );
      final queue = TaktQueue(store, TestEngine(), () => library.tracks);
      await queue.start(['a'], 'a');
      await tester.pumpWidget(
        TaktApp(library: library, queue: queue, store: store, mobile: true),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
      expect(find.byKey(const Key('mobile-next')), findsOneWidget);
      expect(find.byKey(const Key('mobile-previous')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-full-player')), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('mobile-collapse')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Настройки').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-panel')), findsOneWidget);
      await tester.tap(find.text('Линейный'));
      await tester.pumpAndSettle();
      expect(store.read('settings')['visualizerStyle'], 'linear');
      expect(find.text('Громкость колёсиком'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      queue.dispose();
      store.close();
    });
  }
}
