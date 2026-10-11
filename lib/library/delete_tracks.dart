import 'dart:io';

import 'package:flutter/services.dart';

import '../core/track.dart';

// One result per deletion attempt so partial failures cannot be reported as total success.
class DeleteResult {
  final Track track;
  final String? error;
  const DeleteResult(this.track, [this.error]);
  bool get success => error == null;
}

// Physical deletion requires explicit UI confirmation; mark unavailable only after successful deletion.
Future<List<DeleteResult>> deleteTracks(
  List<Track> tracks, {
  required bool confirmed,
}) async {
  if (!confirmed) return [];
  final results = <DeleteResult>[];
  if (Platform.isAndroid &&
      tracks.every((t) => t.path.startsWith('content://'))) {
    try {
      final approved = await const MethodChannel('takt/android')
          .invokeMethod<bool>('delete', {
            'uris': tracks.map((t) => t.path).toList(),
          });
      for (final track in tracks) {
        if (approved == true) track.available = false;
        results.add(DeleteResult(track, approved == true ? null : 'Cancelled'));
      }
    } catch (error) {
      return tracks.map((t) => DeleteResult(t, error.toString())).toList();
    }
    return results;
  }
  for (final track in tracks) {
    try {
      await File(track.path).delete();
      track.available = false;
      results.add(DeleteResult(track));
    } catch (error) {
      results.add(DeleteResult(track, error.toString()));
    }
  }
  return results;
}
