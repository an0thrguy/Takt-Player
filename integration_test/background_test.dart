// Native Linux integration checks; fixtures and reports live in /tmp to keep user data untouched.
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:window_manager/window_manager.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/platform/desktop.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/playback/queue.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('15 minutes playback while hidden in real Linux tray', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    await windowManager.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('takt-tray-');
    final fixture = '${dir.path}/long.wav';
    final generated = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=220:duration=950',
      '-ar',
      '8000',
      '-y',
      fixture,
    ]);
    expect(generated.exitCode, 0);
    final store = TaktStore.memory(), engine = MediaEngine();
    await engine.volume(0);
    final tracks = [
      Track(
        id: 'long',
        path: fixture,
        originalTitle: 'Background test',
        seconds: 950,
      ),
    ];
    final queue = TaktQueue(store, engine, () => tracks);
    var quit = false;
    final desktop = DesktopLifecycle(store, () async {
      quit = true;
    }, queue.toggle);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Takt: background playback check')),
        ),
      ),
    );
    await desktop.initialize(dir.path);
    expect(desktop.icon, isNotNull);
    expect(await desktop.hasHost(), isTrue);
    final menuProperty = await Process.run('gdbus', [
      'call',
      '--session',
      '--dest',
      'org.kde.StatusNotifierItem-$pid-1',
      '--object-path',
      '/StatusNotifierItem',
      '--method',
      'org.freedesktop.DBus.Properties.Get',
      'org.kde.StatusNotifierItem',
      'Menu',
    ]);
    expect(menuProperty.exitCode, 0);
    expect(
      menuProperty.stdout.toString(),
      contains('/StatusNotifierItem/Menu'),
    );
    await queue.start(['long'], 'long');
    desktop.onWindowClose();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await windowManager.isVisible(), isFalse);
    expect(quit, isFalse);
    const intervals = int.fromEnvironment('TRAY_INTERVALS', defaultValue: 30);
    for (var interval = 0; interval < intervals; interval++) {
      await Future<void>.delayed(const Duration(seconds: 30));
      expect(engine.player.state.playing, isTrue);
      expect(
        engine.player.state.position.inSeconds,
        greaterThan(interval * 30),
      );
      debugPrint('Takt background: ${(interval + 1) * 30}/900 seconds');
    }
    await File('/tmp/takt-background.json').writeAsString(
      jsonEncode({
        'seconds': intervals * 30,
        'playingDuringEveryCheck': true,
        'hidden': true,
        'positionSeconds': engine.player.state.position.inSeconds,
      }),
    );
    final activate = await Process.run('gdbus', [
      'call',
      '--session',
      '--dest',
      'org.kde.StatusNotifierItem-$pid-1',
      '--object-path',
      '/StatusNotifierItem',
      '--method',
      'org.kde.StatusNotifierItem.Activate',
      '0',
      '0',
    ]);
    expect(activate.exitCode, 0);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await windowManager.isVisible(), isTrue);
    expect(
      engine.player.state.position.inSeconds,
      greaterThanOrEqualTo(intervals * 30 - 5),
    );
    await File('/tmp/takt-background.json').writeAsString(
      jsonEncode({
        'seconds': intervals * 30,
        'playingDuringEveryCheck': true,
        'hidden': true,
        'restoredByTrayActivate': true,
        'positionSeconds': engine.player.state.position.inSeconds,
      }),
    );
    await engine.pause();
    desktop.dispose();
    queue.dispose();
    await engine.player.dispose();
    store.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 18)));
}
