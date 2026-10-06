import 'dart:convert';

import '../core/store.dart';
import '../core/track.dart';

class LibraryGroup {
  final String id, name, artist;
  final List<Track> tracks;
  LibraryGroup(this.id, this.name, this.artist, this.tracks);
}

// Derived views never change library or playlist ordering.
class LibraryViews {
  final TaktStore store;
  LibraryViews(this.store);
  void recordPlay(Track track) {
    if (!track.available) return;
    final raw = store.read('recentlyPlayed');
    final history = <String, int>{
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: entry.value as int,
    };
    int latest = 0;
    for (final value in history.values) {
      if (value > latest) latest = value;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    history[track.id] = now > latest ? now : latest + 1;
    final entries = history.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    store.write('recentlyPlayed', {
      for (final e in entries.take(500)) e.key: e.value,
    });
  }

  List<Track> recent(List<Track> tracks) {
    final raw = store.read('recentlyPlayed');
    if (raw is! Map) return [];
    final available = {
      for (final t in tracks)
        if (t.available) t.id: t,
    };
    final entries =
        raw.entries
            .where((e) => e.value is int && available.containsKey(e.key))
            .toList()
          ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    return [for (final e in entries) available[e.key]!];
  }

  List<Track> added(List<Track> tracks) =>
      tracks.where((t) => t.available).toList()..sort((a, b) {
        final time = b.addedAt.compareTo(a.addedAt);
        return time != 0
            ? time
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  List<LibraryGroup> groups(List<Track> tracks, {required bool albums}) {
    final grouped = <String, List<Track>>{};
    for (final track in tracks.where((t) => t.available)) {
      final artist = track.artist.trim().toLowerCase(),
          album = track.album.trim().toLowerCase();
      final id = albums ? jsonEncode([artist, album]) : artist;
      grouped.putIfAbsent(id, () => []).add(track);
    }
    final result = [
      for (final entry in grouped.entries)
        LibraryGroup(
          entry.key,
          albums
              ? entry.value.first.album.trim()
              : entry.value.first.artist.trim(),
          albums ? entry.value.first.artist.trim() : '',
          entry.value..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          ),
        ),
    ];
    result.sort((a, b) {
      final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return name != 0
          ? name
          : a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
    });
    return result;
  }
}
