// Regression checks for library; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/library/library.dart';

void main() {
  test(
    'artwork override is copied and survives original image removal',
    () async {
      final dir = await Directory.systemTemp.createTemp('takt-cover-');
      final store = TaktStore.memory();
      addTearDown(() async {
        store.close();
        await dir.delete(recursive: true);
      });
      final library = MusicLibrary(
        store,
        artworkDirectory: '${dir.path}/cache',
      );
      await File('${dir.path}/a.wav').writeAsBytes([1]);
      await library.addSource(dir.path);
      final image = await File('${dir.path}/source.png')
          .writeAsBytes([2, 3, 4]);
      await library.setArtwork(library.tracks.single.id, image.path);
      await image.delete();
      expect(await File(library.tracks.single.artwork!).readAsBytes(), [
        2,
        3,
        4,
      ]);
      final restored = MusicLibrary(store);
      expect(restored.tracks.single.artwork, library.tracks.single.artwork);
      library.dispose();
      restored.dispose();
    },
  );
  test(
    'ambiguous identical copies never inherit another tracks overrides',
    () async {
      final dir = await Directory.systemTemp.createTemp('takt-copies-');
      final store = TaktStore.memory();
      addTearDown(() async {
        store.close();
        await dir.delete(recursive: true);
      });
      final library = MusicLibrary(store);
      final original = await File('${dir.path}/a.wav').writeAsBytes([1, 2]);
      await original.copy('${dir.path}/b.wav');
      await library.addSource(dir.path);
      final a = library.tracks.firstWhere((t) => t.path == original.path);
      library.rename(a.id, 'Private name');
      await original.delete();
      await File('${dir.path}/b.wav').copy('${dir.path}/c.wav');
      await library.scan();
      final c = library.tracks.firstWhere((t) => t.path.endsWith('/c.wav'));
      expect(c.id, isNot(a.id));
      expect(c.title, isNot('Private name'));
      expect(a.available, isFalse);
      library.dispose();
    },
  );

  test('scan handles nested files and preserves overrides on rename', () async {
    final temp = await Directory.systemTemp.createTemp('takt-test-');
    final store = TaktStore.memory();
    addTearDown(() async {
      store.close();
      await temp.delete(recursive: true);
    });
    final folder = await Directory('${temp.path}/album').create();
    final file = await File('${folder.path}/Song.mp3').writeAsBytes([1, 2, 3]);
    final library = MusicLibrary(store);
    await library.addSource(temp.path);
    expect(library.tracks.length, 1);
    final id = library.tracks.single.id;
    library.rename(id, 'Мой трек');
    await file.rename('${folder.path}/Renamed.mp3');
    await library.scan();
    expect(library.tracks.single.id, id);
    expect(library.tracks.single.title, 'Мой трек');
    library.dispose();
  });

  test(
    'playlists reject duplicates and deleting playlist keeps file',
    () async {
      final temp = await Directory.systemTemp.createTemp('takt-test-');
      final store = TaktStore.memory();
      addTearDown(() async {
        store.close();
        await temp.delete(recursive: true);
      });
      final file = await File('${temp.path}/Song.flac').writeAsBytes([4, 5]);
      final library = MusicLibrary(store);
      await library.addSource(temp.path);
      final playlist = library.createPlaylist('Вечер');
      final id = library.tracks.single.id;
      expect(library.addToPlaylist(playlist, [id]), 1);
      expect(library.addToPlaylist(playlist, [id]), 0);
      library.deletePlaylist(playlist);
      expect(await file.exists(), true);
      library.dispose();
    },
  );

  test('missing source retains track identity and overrides', () async {
    final temp = await Directory.systemTemp.createTemp('takt-test-');
    final store = TaktStore.memory();
    final library = MusicLibrary(store);
    await File('${temp.path}/Song.wav').writeAsBytes([7]);
    await library.addSource(temp.path);
    final id = library.tracks.single.id;
    library.rename(id, 'Сохранить');
    await temp.delete(recursive: true);
    await library.scan();
    expect(library.tracks.single.available, false);
    expect(library.tracks.single.title, 'Сохранить');
    library.dispose();
    store.close();
  });
}
