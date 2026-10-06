import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library_views.dart';

void main() {
  test(
    'history is deduplicated, persisted, bounded and filters missing tracks',
    () {
      final store = TaktStore.memory();
      final views = LibraryViews(store);
      final a = Track(id: 'a', path: '/a', originalTitle: 'A');
      final b = Track(id: 'b', path: '/b', originalTitle: 'B');
      views.recordPlay(a);
      views.recordPlay(b);
      views.recordPlay(a);
      expect(views.recent([a, b]).map((t) => t.id), ['a', 'b']);
      b.available = false;
      expect(views.recent([a, b]).map((t) => t.id), ['a']);
      for (int i = 0; i < 501; i++) {
        views.recordPlay(Track(id: '$i', path: '/$i', originalTitle: '$i'));
      }
      expect((store.read('recentlyPlayed') as Map).length, 500);
      store.close();
    },
  );
  test('albums separate artists; unknown tags and timestamp migration are deterministic', () {
    final store = TaktStore.memory();
    final views = LibraryViews(store);
    final tracks = [
      Track(
        id: 'a',
        path: '/a',
        originalTitle: 'A',
        album: 'Same',
        artist: 'One',
        addedAt: 1,
      ),
      Track(
        id: 'b',
        path: '/b',
        originalTitle: 'B',
        album: 'Same',
        artist: 'Two',
        addedAt: 5,
      ),
      Track(id: 'c', path: '/c', originalTitle: 'C'),
    ];
    expect(views.groups(tracks, albums: true).length, 3);
    expect(views.added(tracks).map((t) => t.id), ['b', 'a', 'c']);
    expect(Track.fromJson(tracks.last.toJson()..remove('addedAt')).addedAt, 0);
    store.close();
  });
}
