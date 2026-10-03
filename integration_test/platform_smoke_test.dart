// Native Linux integration checks; fixtures and reports live in /tmp to keep user data untouched.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:takt/core/store.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Linux native playback, seek, pause, restore and UI', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('takt-native-');
    await File('/tmp/takt-smoke.wav').copy('${dir.path}/Тест.wav');
    final store = TaktStore('${dir.path}/state.sqlite');
    store.write('settings', {'locale': 'ru', 'volume': 70.0});
    final library = MusicLibrary(store);
    await library.addSource(dir.path);
    final engine = MediaEngine(),
        queue = TaktQueue(store, MediaEngine(), () => library.tracks);
    final audio = queue.engine as MediaEngine;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TaktApp(library: library, queue: queue, store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Тест'), findsOneWidget);
    await tester.tap(find.text('Тест'));
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(audio.player.state.playing, isTrue);
    expect(audio.player.state.position.inMilliseconds, greaterThan(500));
    await queue.seek(const Duration(seconds: 8));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(audio.player.state.position.inSeconds, greaterThanOrEqualTo(7));
    await queue.toggle();
    expect(audio.player.state.playing, isFalse);
    queue.save();
    final restored = TaktQueue(store, audio, () => library.tracks);
    await restored.restore();
    expect(restored.playing, isFalse);
    expect(audio.player.state.playing, isFalse);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.volume_up_outlined));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 70);
    await tester.tapAt(
      tester.getTopLeft(find.byType(Slider)) + const Offset(20, 20),
    );
    await tester.pumpAndSettle();
    expect((store.read('settings')['volume'] as num), lessThan(70));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Волнистая шкала'));
    await tester.pumpAndSettle();
    expect(store.read('settings')['wave'], true);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/takt-linux-light.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    final dark =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final darkBytes = await dark.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/takt-linux-dark.png')
        .writeAsBytes(darkBytes!.buffer.asUint8List());
    dark.dispose();
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    queue.dispose();
    restored.dispose();
    await audio.player.dispose();
    await engine.player.dispose();
    store.close();
    await dir.delete(recursive: true);
  });
}
