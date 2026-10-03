// Native Linux integration checks; fixtures and reports live in /tmp to keep user data untouched.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/library/library.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    '500 real files scan overlapping sources automatic refresh and restart',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Takt: 500 files scan check')),
          ),
        ),
      );
      final dir = await Directory.systemTemp.createTemp('takt-scan-');
      for (var album = 0; album < 25; album++) {
        final folder = await Directory('${dir.path}/album-$album').create();
        for (var song = 0; song < 20; song++) {
          await File('/tmp/takt-formats/check.flac')
              .copy('${folder.path}/Song-$song.flac');
        }
      }
      final store = TaktStore('${dir.path}/library.sqlite'),
          library = MusicLibrary(store);
      final watch = Stopwatch()..start();
      await library.addSource(dir.path);
      watch.stop();
      expect(library.tracks.length, 500);
      expect(library.tracks.every((t) => t.seconds > 2), isTrue);
      await library.addSource('${dir.path}/album-0');
      expect(library.tracks.length, 500);
      final id = library.tracks.first.id;
      library.rename(id, 'Личное название');
      final playlist = library.createPlaylist('Test');
      library.addToPlaylist(playlist, [id]);
      final refresh = Stopwatch()..start();
      await library.scan();
      refresh.stop();
      await library.start();
      await File('/tmp/takt-formats/check.flac').copy('${dir.path}/new.flac');
      await Future<void>.delayed(const Duration(seconds: 11));
      expect(library.tracks.length, 501);
      library.timer?.cancel();
      library.dispose();
      store.close();
      final reopened = TaktStore('${dir.path}/library.sqlite');
      final restored = MusicLibrary(reopened);
      expect(
        restored.tracks.firstWhere((t) => t.id == id).title,
        'Личное название',
      );
      expect(restored.playlists.single.ids, [id]);
      await File('/tmp/takt-scan-performance.json').writeAsString(
        jsonEncode({
          'files': 500,
          'initialScanMs': watch.elapsedMilliseconds,
          'unchangedRescanMs': refresh.elapsedMilliseconds,
          'automaticAddition': true,
          'overlappingSourcesDeduplicated': true,
          'restartPreservesOverrides': true,
          'method':
              'Native Linux debug; 500 synthetic FLAC files in 25 directories',
        }),
      );
      restored.dispose();
      reopened.close();
      await dir.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
