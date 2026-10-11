import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/store.dart';
import '../core/track.dart';
import 'discover_music.dart';

// Library, sources and playlists. This is the data layer; presentation lives in ui/app.dart.
class MusicLibrary extends ChangeNotifier {
  final TaktStore store;
  final String? artworkDirectory;
  late List<Track> tracks;
  late List<String> sources;
  late List<Playlist> playlists;
  late Set<String> favorites;
  bool scanning = false;
  String? error;
  void reportError(String value) {
    error = value;
    notifyListeners();
  }

  Timer? timer;
  MusicLibrary(this.store, {this.artworkDirectory}) {
    favorites = Set<String>.from(store.read('favorites') ?? []);
    tracks = [
      for (final j in store.read('tracks') ?? [])
        Track.fromJson(Map<String, dynamic>.from(j)),
    ];
    sources = List<String>.from(store.read('sources') ?? []);
    playlists = [
      for (final j in store.read('playlists') ?? [])
        Playlist.fromJson(Map<String, dynamic>.from(j)),
    ];
  }
  // Atomically save related snapshots and notify the interface of changes.
  void persist() {
    store.transaction(() {
      store.write('tracks', tracks.map((t) => t.toJson()).toList());
      store.write('sources', sources);
      store.write('favorites', favorites.toList());
      store.write('playlists', playlists.map((p) => p.toJson()).toList());
    });
    notifyListeners();
  }

  // Batch add/remove is reversible and never edits or duplicates media files.
  void toggleFavorite(Iterable<String> ids) {
    final valid = ids.where((id) => tracks.any((t) => t.id == id)).toSet();
    if (valid.isEmpty) return;
    if (valid.every(favorites.contains)) {
      favorites.removeAll(valid);
    } else {
      favorites.addAll(valid);
    }
    persist();
  }

  // Canonical paths prevent reconnecting the same directory through symbolic links.
  Future<void> addSource(String path) async {
    final canonical = await Directory(path).resolveSymbolicLinks();
    if (!sources.contains(canonical)) sources.add(canonical);
    await scan();
  }

  // Initial load and periodic refresh. Change the polling interval in Timer.periodic below.
  Future<void> start() async {
    if (sources.isEmpty) {
      final path = await discoverMusic();
      if (path != null) sources.add(path);
    }
    await scan();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => scan());
  }

  // Non-overlapping scan: enumerate files, recognize moves, and read metadata for new tracks.
  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    error = null;
    notifyListeners();
    final found = <String>{};
    final pending = <String>[];
    // Scanner extensions; actual decoding support depends on installed libmpv/FFmpeg codecs.
    const extensions = {
      'mp3',
      'flac',
      'wav',
      'aiff',
      'aif',
      'm4a',
      'aac',
      'ogg',
      'opus',
      'wma',
      'ape',
      'wv',
      'mpc',
      'mka',
      'ac3',
      'dts',
      'dsf',
      'dff',
      'oga',
      'alac',
    };
    try {
      for (final source in sources) {
        if (!await Directory(source).exists()) continue;
        try {
          await for (final entity in Directory(
            source,
          ).list(recursive: true, followLinks: false)) {
            if (entity is! File ||
                !extensions.contains(
                  entity.path.split('.').last.toLowerCase(),
                )) {
              continue;
            }
            final path = await entity.resolveSymbolicLinks();
            if (found.add(path) && !tracks.any((t) => t.path == path)) {
              pending.add(path);
            }
          }
        } on FileSystemException catch (e) {
          error = e.message;
        }
      }
      for (final t in tracks) {
        t.available = found.contains(t.path);
      }
      // Full SHA-256 is computed only for new paths to help recognize moved media.
      final candidates = <String, List<String>>{};
      for (final path in pending) {
        try {
          final hash = (await sha256.bind(File(path).openRead()).first)
              .toString();
          candidates.putIfAbsent(hash, () => []).add(path);
        } on FileSystemException catch (e) {
          error = e.message;
        }
      }
      final additions = <(String, String)>[];
      for (final entry in candidates.entries) {
        for (final path in entry.value) {
          final old = tracks
              .where((t) => !t.available && t.signature == entry.key)
              .toList();
          // Accept only unambiguous moves; identical copies must not be collapsed into one track.
          if (old.length == 1 &&
              entry.value.length == 1 &&
              tracks.where((t) => t.signature == entry.key).length == 1) {
            old.single.path = path;
            old.single.available = true;
          } else {
            additions.add((path, entry.key));
          }
        }
      }
      // Run at most three ffprobe processes concurrently; incremental snapshots populate the UI early.
      for (var offset = 0; offset < additions.length; offset += 3) {
        final batch = additions.skip(offset).take(3).toList();
        final metadata = await Future.wait(
          batch.map((item) => _metadata(item.$1)),
        );
        for (var i = 0; i < batch.length; i++) {
          final path = batch[i].$1, hash = batch[i].$2, tags = metadata[i];
          final filename = path.split('/').last,
              dot = filename.lastIndexOf('.');
          tracks.add(
            Track(
              id: sha256
                  .convert(
                    utf8.encode(
                      '$path:${DateTime.now().microsecondsSinceEpoch}',
                    ),
                  )
                  .toString(),
              path: path,
              originalTitle:
                  tags['title'] ??
                  (dot > 0 ? filename.substring(0, dot) : filename),
              artist: tags['artist'] ?? '',
              album: tags['album'] ?? '',
              seconds: double.tryParse(tags['duration'] ?? '') ?? 0,
              signature: hash,
              addedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
        if (offset % 24 == 0) persist();
      }
      persist();
    } catch (e) {
      error = e.toString();
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  // Read tags and duration using ffprobe; failures fall back to the filename.
  Future<Map<String, String>> _metadata(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'quiet',
        '-show_entries',
        'format=duration:format_tags=title,artist,album',
        '-of',
        'json',
        path,
      ]).timeout(const Duration(seconds: 5));
      final j = jsonDecode(result.stdout as String) as Map;
      final format = j['format'] as Map? ?? {};
      final tags = format['tags'] as Map? ?? {};
      return {
        for (final e in tags.entries)
          e.key.toString().toLowerCase(): e.value.toString(),
        'duration': format['duration']?.toString() ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  // Change only the personal display title; an empty value restores the original title.
  void rename(String id, String value) {
    tracks.firstWhere((t) => t.id == id).customTitle = value.trim().isEmpty
        ? null
        : value.trim();
    persist();
  }

  // Copy personal artwork into app storage so it survives removal of the source image.
  Future<void> setArtwork(String id, String path) async {
    final previous = tracks.firstWhere((t) => t.id == id).artwork;
    final directory = artworkDirectory;
    if (directory == null) {
      tracks.firstWhere((t) => t.id == id).artwork = path;
    } else {
      await Directory(directory).create(recursive: true);
      final extension = path.split('.').last.toLowerCase();
      // A new identity also invalidates Flutter and notification artwork caches.
      final destination =
          '$directory/$id-custom-${DateTime.now().microsecondsSinceEpoch}.$extension';
      await File(path).copy(destination);
      tracks.firstWhere((t) => t.id == id).artwork = destination;
    }
    persist();
    // Delete only this track's superseded app-owned image, after copying succeeds.
    if (directory != null &&
        previous != null &&
        File(previous).parent.path == Directory(directory).path &&
        previous.split('/').last.startsWith('$id-custom-') &&
        previous != tracks.firstWhere((t) => t.id == id).artwork) {
      try {
        await File(previous).delete();
      } on FileSystemException {
        /* Already removed. */
      }
    }
  }

  // Create an empty playlist with an independent ID; its name is not its identity.
  String createPlaylist(String name) {
    if (name.trim().isEmpty) throw ArgumentError('Empty name');
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    playlists.add(Playlist(id, name.trim(), []));
    persist();
    return id;
  }

  // Delete only the playlist, never its tracks or media files.
  void deletePlaylist(String id) {
    playlists.removeWhere((p) => p.id == id);
    persist();
  }

  // Rename without changing the playlist ID or membership; empty names are ignored.
  void renamePlaylist(String id, String name) {
    if (name.trim().isEmpty) return;
    playlists.firstWhere((p) => p.id == id).name = name.trim();
    persist();
  }

  // Return the number of additions; duplicates are skipped and reported by the UI.
  int addToPlaylist(String id, List<String> values) {
    final p = playlists.firstWhere((p) => p.id == id);
    int count = 0;
    for (final value in values) {
      if (!p.ids.contains(value)) {
        p.ids.add(value);
        count++;
      }
    }
    persist();
    return count;
  }

  // Remove references from one playlist without changing the shared library.
  void removeFromPlaylist(String id, List<String> values) {
    playlists.firstWhere((p) => p.id == id).ids.removeWhere(values.contains);
    persist();
  }

  // With filtering, baseOrder retains hidden track slots; global and playlist orders are independent.
  void reorder(
    List<String> ids, {
    String? playlist,
    List<String>? baseOrder,
    bool favoritesOnly = false,
  }) {
    if (baseOrder != null) {
      var index = 0;
      ids = baseOrder
          .map((id) => ids.contains(id) ? ids[index++] : id)
          .toList();
    }
    if (favoritesOnly) {
      store.write('order:favorites', [
        ...ids,
        ...favorites.where((id) => !ids.contains(id)),
      ]);
    } else if (playlist != null) {
      final p = playlists.firstWhere((p) => p.id == playlist);
      p.ids = [...ids, ...p.ids.where((id) => !ids.contains(id))];
    } else {
      store.write('order', [
        ...ids,
        ...tracks.map((t) => t.id).where((id) => !ids.contains(id)),
      ]);
    }
    persist();
  }

  // UI filters and sorting. Titles are the default; manual uses the saved order.
  List<Track> visible({
    String query = '',
    String? playlist,
    String? folder,
    bool manual = false,
    bool favoritesOnly = false,
  }) {
    final ids = favoritesOnly
        ? List<String>.from(store.read('order:favorites') ?? [])
        : playlist == null
        ? List<String>.from(store.read('order') ?? [])
        : playlists.firstWhere((p) => p.id == playlist).ids;
    final list = tracks
        .where(
          (t) =>
              t.available &&
              (!favoritesOnly || favorites.contains(t.id)) &&
              (playlist == null || ids.contains(t.id)) &&
              (folder == null || t.path.startsWith('$folder/')) &&
              '${t.title} ${t.artist} ${t.album} ${t.path}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    list.sort((a, b) {
      if (manual) {
        final ai = ids.indexOf(a.id), bi = ids.indexOf(b.id);
        if (ai != bi) {
          return (ai < 0 ? 1 << 30 : ai).compareTo(bi < 0 ? 1 << 30 : bi);
        }
      }
      final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
