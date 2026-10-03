import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/track.dart';

// Priority: personal artwork, cache, embedded cover, nearby image, then permitted online lookup.
class ArtworkService {
  final String directory;
  final Future<List<int>?> Function(Track)? lookup;
  http.Client? _pendingClient;
  final http.Client Function() clientFactory;
  int _generation = 0;
  ArtworkService(
    this.directory, {
    this.lookup,
    http.Client Function()? clientFactory,
  }) : clientFactory = clientFactory ?? http.Client.new;
  // Revoking permission closes the HTTP client and invalidates late responses.
  void cancel() {
    _generation++;
    _pendingClient?.close();
    _pendingClient = null;
  }

  // The caller supplies online permission; no network access occurs without it.
  Future<String?> resolve(Track track, {required bool online}) async {
    // Generation follows user permission and is checked again before saving network results.
    final generation = _generation;
    if (track.artwork != null && await File(track.artwork!).exists()) {
      return track.artwork;
    }
    final cache = File('$directory/${track.id}.jpg');
    if (await cache.exists()) return cache.path;
    await cache.parent.create(recursive: true);
    if (await File(track.path).exists()) {
      try {
        final result = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-i',
          track.path,
          '-an',
          '-frames:v',
          '1',
          '-y',
          '${cache.path}.tmp.jpg',
        ]).timeout(const Duration(seconds: 8));
        final temp = File('${cache.path}.tmp.jpg');
        if (result.exitCode == 0 &&
            await temp.exists() &&
            await temp.length() > 0) {
          await temp.rename(cache.path);
          return cache.path;
        }
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      for (final name in ['cover.jpg', 'folder.jpg', 'cover.png']) {
        final file = File('${File(track.path).parent.path}/$name');
        if (await file.exists()) {
          await file.copy(cache.path);
          return cache.path;
        }
      }
    }
    if (!online || generation != _generation) return null;
    final bytes = lookup == null
        ? await _online(track, () => generation == _generation)
        : await lookup!(track);
    if (bytes == null || generation != _generation) return null;
    await cache.parent.create(recursive: true);
    await cache.writeAsBytes(bytes);
    return cache.path;
  }

  // Shared MusicBrainz request throttle across service instances.
  static DateTime? _lastRequest;
  // MusicBrainz finds a confident artist/album release; CAA supplies a small cover image.
  Future<List<int>?> _online(Track track, bool Function() allowed) async {
    final client = clientFactory();
    _pendingClient = client;
    if (track.artist.isEmpty || track.album.isEmpty) {
      client.close();
      _pendingClient = null;
      return null;
    }
    const headers = {
      'User-Agent': 'Takt/0.1 (personal local music player)',
      'Accept': 'application/json',
    };
    try {
      final elapsed = _lastRequest == null
          ? 1100
          : DateTime.now().difference(_lastRequest!).inMilliseconds;
      if (elapsed < 1100) {
        await Future<void>.delayed(Duration(milliseconds: 1100 - elapsed));
      }
      if (!allowed()) return null;
      _lastRequest = DateTime.now();
      final escapedArtist = track.artist.replaceAll('"', ''),
          escapedAlbum = track.album.replaceAll('"', '');
      final response = await client
          .get(
            Uri.https('musicbrainz.org', '/ws/2/release/', {
              'query': 'artist:"$escapedArtist" AND release:"$escapedAlbum"',
              'fmt': 'json',
              'limit': '2',
            }),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
      if (!allowed() || response.statusCode != 200) return null;
      final releases = (jsonDecode(response.body)['releases'] as List? ?? []);
      // Ambiguous matches retain the placeholder rather than applying a potentially incorrect cover.
      if (releases.length != 1 ||
          (int.tryParse(releases.single['score'].toString()) ?? 0) < 95) {
        return null;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!allowed()) return null;
      final image = await client
          .get(
            Uri.https(
              'coverartarchive.org',
              '/release/${releases.single['id']}/front-250',
            ),
          )
          .timeout(const Duration(seconds: 10));
      // Accept only reasonably sized images; provider failures must not interrupt music playback.
      if (image.statusCode != 200 ||
          image.bodyBytes.length > 5 * 1024 * 1024 ||
          !(image.headers['content-type'] ?? '').startsWith('image/')) {
        return null;
      }
      return image.bodyBytes;
    } catch (_) {
      return null;
    } finally {
      client.close();
      if (identical(_pendingClient, client)) _pendingClient = null;
    }
  }
}
