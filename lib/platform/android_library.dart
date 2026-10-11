import 'dart:async';

import 'package:flutter/services.dart';

import '../core/track.dart';
import '../library/library.dart';

// MediaStore IDs preserve personal edits and playlists across incremental scans.
class AndroidMusicLibrary extends MusicLibrary {
  static const channel = MethodChannel('takt/android');
  final Future<List<Track>?> Function()? scanner;
  bool permissionGranted = false;
  bool _disposed = false;
  late Map<String, String> trackSources = Map<String, String>.from(
    store.read('android:trackSources') as Map? ?? {},
  );
  String? get activeSource =>
      _disposed ? null : store.read('android:activeSource') as String?;
  void selectSource(String source) {
    if (_disposed || !sources.contains(source)) return;
    store.write('android:activeSource', source);
    notifyListeners();
  }

  bool inActiveSource(Track track) =>
      activeSource == null ||
      (trackSources[track.id]?.startsWith(activeSource!) ?? false);

  AndroidMusicLibrary(super.store, {super.artworkDirectory, this.scanner});

  Future<List<Track>?> _read(bool requestPermission) async {
    if (scanner != null) return scanner!();
    final response = await channel.invokeMapMethod<String, dynamic>('scan', {
      'artworkDirectory': artworkDirectory,
      'requestPermission': requestPermission,
      'sources': sources,
    });
    if (_disposed || response == null) return null;
    sources = List<String>.from(response['sources'] as List);
    final rows = response['tracks'] as List;
    for (final row in rows) {
      trackSources[row['id'] as String] = row['source'] as String;
    }
    store.write('android:trackSources', trackSources);
    if (!sources.contains(activeSource)) {
      store.write(
        'android:activeSource',
        sources.isEmpty ? null : sources.first,
      );
    }
    return rows
        .map((row) => Track.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<void> scan({bool requestPermission = false}) async {
    if (_disposed || scanning) return;
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final found = await _read(requestPermission);
      if (_disposed) return;
      permissionGranted = found != null;
      // Denied access is not evidence that previously discovered files disappeared.
      if (found == null) return;
      final previous = {for (final track in tracks) track.id: track};
      for (final track in tracks) {
        track.available = false;
      }
      for (final fresh in found) {
        final old = previous[fresh.id];
        if (old == null) {
          fresh.addedAt = DateTime.now().millisecondsSinceEpoch;
          tracks.add(fresh);
        } else {
          old.path = fresh.path;
          old.originalTitle = fresh.originalTitle;
          old.artist = fresh.artist;
          old.album = fresh.album;
          old.seconds = fresh.seconds;
          old.available = true;
          old.artwork ??= fresh.artwork;
        }
      }
      persist();
    } catch (e) {
      if (!_disposed) reportError(e.toString());
    } finally {
      scanning = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  Future<void> start() async {
    await scan(requestPermission: true);
    if (_disposed) return;
    timer = Timer.periodic(const Duration(seconds: 15), (_) => scan());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Future<void> addSource(String path) async {
    if (_disposed) return;
    if (!sources.contains(path)) sources.add(path);
    store.write('android:activeSource', path);
    persist();
    await scan(requestPermission: true);
  }
}
