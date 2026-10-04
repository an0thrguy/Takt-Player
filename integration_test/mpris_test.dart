// Real session-bus and Serpantinum consumer check, isolated from personal data.
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/platform/mpris.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/playback/queue.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('MPRIS controls real playback and enables Serpantinum Cava', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('takt-mpris-');
    final path = '${dir.path}/tone.wav';
    final generated = await Process.run('ffmpeg', [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=25',
      path,
    ]);
    expect(generated.exitCode, 0);
    final store = TaktStore.memory(), engine = MediaEngine();
    await engine.volume(5);
    final tracks = [
      for (final id in ['a', 'b'])
        Track(
          id: id,
          path: path,
          originalTitle: 'Takt integration $id',
          artist: 'Test fixture',
          seconds: 25,
        ),
    ];
    final queue = TaktQueue(store, engine, () => tracks);
    final playing = engine.player.stream.playing.listen(queue.updatePlaying);
    final position = engine.player.stream.position.listen(queue.updatePosition);
    final mpris = TaktMpris(
      queue,
      raise: () async {},
      quit: () async {},
      volume: () => engine.player.state.volume / 100,
      setVolume: (v) => engine.volume(v * 100),
    );
    final bus = DBusClient.session();
    try {
      await mpris.start();
      await queue.start(['a', 'b'], 'a');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final remote = DBusRemoteObject(
        bus,
        name: 'org.mpris.MediaPlayer2.takt',
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );
      expect(
        (await remote.getProperty(
          TaktMpris.playerInterface,
          'PlaybackStatus',
        )).asString(),
        'Playing',
      );
      final meta = (await remote.getProperty(
        TaktMpris.playerInterface,
        'Metadata',
      )).asStringVariantDict();
      expect(meta['xesam:title']!.asString(), tracks.first.title);
      await remote.callMethod(TaktMpris.playerInterface, 'Pause', []);
      expect(queue.playing, false);
      await remote.callMethod(TaktMpris.playerInterface, 'Play', []);
      await remote.callMethod(TaktMpris.playerInterface, 'Next', []);
      expect(queue.currentId, 'b');
      await remote.callMethod(TaktMpris.playerInterface, 'Previous', []);
      expect(queue.currentId, 'a');
      await remote.callMethod(TaktMpris.playerInterface, 'Seek', [
        DBusInt64(2000000),
      ]);
      expect(queue.position.inSeconds, greaterThanOrEqualTo(2));
      await remote.setProperty(
        TaktMpris.playerInterface,
        'Volume',
        DBusDouble(.2),
      );
      // Use the installed shell's actual MprisController/Cava, with one temporary
      // consumer. No panels or configuration files are created or changed.
      final shellRoot =
          '${Platform.environment['HOME']}/.local/share/serpantinum/src/quickshell';
      if (await File('$shellRoot/singletons/audio/Cava.qml').exists()) {
        final qml = File('${dir.path}/Probe.qml');
        await qml.writeAsString('''
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "file://$shellRoot" as Serp
ShellRoot {
    Component.onCompleted: Serp.Cava.registerConsumer()
    Timer {
        interval: 3000; running: true; repeat: false
        onTriggered: {
            const takt = Mpris.players.values.find(p => p.identity === "Takt")
            console.log("TAKT_PROBE:" + JSON.stringify({
                playing: Serp.MprisController.isPlaying,
                title: Serp.MprisController.trackTitle,
                taktPlaying: takt ? takt.isPlaying : false,
                taktTitle: takt ? takt.trackTitle : "",
                enabled: Serp.Cava.processEnabled,
                peak: Math.max.apply(null, Serp.Cava.barLevels)
            }))
            Serp.Cava.unregisterConsumer()
            Qt.quit()
        }
    }
}
''');
        final result = await Process.run('quickshell', [
          '-p',
          qml.path,
        ]).timeout(const Duration(seconds: 15));
        final output = '${result.stdout}\n${result.stderr}';
        final match = RegExp(r'TAKT_PROBE:(\{[^\n]+\})').firstMatch(output);
        expect(match, isNotNull, reason: output);
        final probe = jsonDecode(match!.group(1)!) as Map;
        await File('/tmp/takt-mpris-probe-output.txt').writeAsString(output);
        await File('/tmp/takt-mpris-serpantinum.json')
            .writeAsString(jsonEncode(probe));
        final audio = await Process.run('pactl', ['list', 'sink-inputs']);
        await File('/tmp/takt-mpris-audio.txt')
            .writeAsString(audio.stdout.toString());
        expect(probe['playing'], true);
        expect(probe['taktPlaying'], true);
        expect(probe['taktTitle'], tracks.first.title);
        expect(probe['enabled'], true);
        expect(probe['peak'] as num, greaterThan(0));
      }
    } finally {
      await mpris.dispose();
      await bus.close();
      await playing.cancel();
      await position.cancel();
      await engine.player.dispose();
      queue.dispose();
      store.close();
      await dir.delete(recursive: true);
    }
  });
}
