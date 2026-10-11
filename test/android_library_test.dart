import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/platform/android_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'scan finishing after shutdown cannot touch the closed database',
    () async {
      final store = TaktStore.memory();
      final result = Completer<List<Track>?>();
      final library = AndroidMusicLibrary(store, scanner: () => result.future);
      final pending = library.scan();
      library.dispose();
      store.close();
      result.complete([
        Track(id: 'late', path: 'content://late', originalTitle: 'Late'),
      ]);
      await expectLater(pending, completes);
    },
  );
  test(
    'configured sources are sent to scanner and switching survives restart',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final requests = <List<String>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidMusicLibrary.channel, (call) async {
            expect(call.method, 'scan');
            final sources = List<String>.from(call.arguments['sources']);
            requests.add(sources);
            final selected = sources.isEmpty
                ? ['external_primary:Music/']
                : sources;
            return {
              'sources': selected,
              'tracks': [
                {
                  'id': 'a',
                  'path': 'content://a',
                  'title': 'A',
                  'source': selected.first,
                },
                if (selected.length > 1)
                  {
                    'id': 'b',
                    'path': 'content://b',
                    'title': 'B',
                    'source': selected.last,
                  },
              ],
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidMusicLibrary.channel, null),
      );
      final library = AndroidMusicLibrary(store);
      await library.scan();
      expect(library.sources, ['external_primary:Music/']);
      await library.addSource('external_primary:Download/');
      expect(requests.last, [
        'external_primary:Music/',
        'external_primary:Download/',
      ]);
      expect(library.inActiveSource(library.tracks.first), isFalse);
      expect(library.inActiveSource(library.tracks.last), isTrue);
      library.selectSource(library.sources.first);
      final restored = AndroidMusicLibrary(store);
      expect(restored.inActiveSource(restored.tracks.first), isTrue);
      expect(restored.inActiveSource(restored.tracks.last), isFalse);
      expect(restored.tracks.every((track) => track.available), isTrue);
    },
  );

  test(
    'nested sources include their tracks without hiding them from the parent',
    () {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final library = AndroidMusicLibrary(store);
      library.sources.addAll([
        'external_primary:Music/',
        'external_primary:Music/Rock/',
      ]);
      final track = Track(
        id: 'rock',
        path: 'content://rock',
        originalTitle: 'Rock',
      );
      library.trackSources[track.id] = 'external_primary:Music/Rock/';
      library.selectSource('external_primary:Music/Rock/');
      expect(library.inActiveSource(track), isTrue);
      library.selectSource('external_primary:Music/');
      expect(library.inActiveSource(track), isTrue);
    },
  );
  test(
    'denied audio permission retains saved metadata and playlists',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final library = AndroidMusicLibrary(store, scanner: () async => null);
      library.tracks.add(
        Track(id: 'a', path: 'content://a', originalTitle: 'A'),
      );
      library.favorites.add('a');
      library.createPlaylist('Personal');
      await library.scan();
      expect(library.tracks.single.available, isTrue);
      expect(library.favorites, contains('a'));
      expect(library.playlists.single.name, 'Personal');
      expect(library.permissionGranted, isFalse);
    },
  );
  test(
    'scan merges stable media IDs and retains custom title and artwork',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      var found = [
        Track(id: 'a', path: 'content://a', originalTitle: 'New tags'),
      ];
      final library = AndroidMusicLibrary(store, scanner: () async => found);
      library.tracks.add(
        Track(
          id: 'a',
          path: 'content://old',
          originalTitle: 'Old',
          customTitle: 'Personal',
          artwork: '/personal.png',
        ),
      );
      await library.scan();
      expect(library.tracks.single.title, 'Personal');
      expect(library.tracks.single.originalTitle, 'New tags');
      expect(library.tracks.single.artwork, '/personal.png');
      expect(library.tracks.single.path, 'content://a');
      found = [];
      await library.scan();
      expect(library.tracks.single.available, isFalse);
      found = [Track(id: 'a', path: 'content://a', originalTitle: 'Back')];
      await library.scan();
      expect(library.tracks.single.available, isTrue);
      expect(library.tracks.single.title, 'Personal');
    },
  );
}
