import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';

void main() {
  test('favorite ordering preserves library and hidden favorite positions', () {
    final store = TaktStore.memory();
    final library = MusicLibrary(store);
    library.tracks = [
      for (final id in ['a', 'b', 'c', 'd'])
        Track(id: id, path: '/$id', originalTitle: id),
    ];
    library.toggleFavorite(['a', 'b', 'c']);
    library.reorder(['d', 'c', 'b', 'a']);
    library.reorder(
      ['c', 'a'],
      favoritesOnly: true,
      baseOrder: ['a', 'b', 'c'],
    );
    expect(store.read('order'), ['d', 'c', 'b', 'a']);
    expect(
      library.visible(favoritesOnly: true, manual: true).map((t) => t.id),
      ['c', 'b', 'a'],
    );
    final restored = MusicLibrary(store);
    expect(
      restored.visible(favoritesOnly: true, manual: true).map((t) => t.id),
      ['c', 'b', 'a'],
    );
    restored.dispose();
    library.dispose();
    store.close();
  });
  test(
    'favorites persist without duplicates and can be removed reversibly',
    () {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final library = MusicLibrary(store);
      library.tracks = [Track(id: 'a', path: '/a', originalTitle: 'A')];
      library.toggleFavorite(['a', 'a']);
      expect(library.favorites, {'a'});
      final restored = MusicLibrary(store);
      expect(restored.favorites, {'a'});
      restored.toggleFavorite(['a']);
      expect(restored.favorites, isEmpty);
      expect(restored.tracks.single.id, 'a');
      restored.dispose();
      library.dispose();
    },
  );
}
