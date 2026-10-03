// Regression checks for delete; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/delete_tracks.dart';

void main() {
  test(
    'OS permission denial preserves the file and its availability',
    () async {
      final dir = await Directory.systemTemp.createTemp('takt-permission-');
      final file = await File('${dir.path}/song.wav').writeAsBytes([1]);
      final track = Track(id: 'a', path: file.path, originalTitle: 'A');
      await Process.run('chmod', ['500', dir.path]);
      try {
        final result = await deleteTracks([track], confirmed: true);
        expect(result.single.success, false);
        expect(result.single.error, isNotNull);
        expect(await file.exists(), true);
        expect(track.available, true);
      } finally {
        await Process.run('chmod', ['700', dir.path]);
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'cancel never deletes; partial failure preserves failed track',
    () async {
      final dir = await Directory.systemTemp.createTemp('takt-delete-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/song.wav').writeAsBytes([1]);
      final a = Track(id: 'a', path: file.path, originalTitle: 'A'),
          b = Track(
            id: 'b',
            path: '${dir.path}/missing.wav',
            originalTitle: 'B',
          );
      expect(await deleteTracks([a], confirmed: false), isEmpty);
      expect(await file.exists(), isTrue);
      final results = await deleteTracks([a, b], confirmed: true);
      expect(results.first.success, isTrue);
      expect(results.last.success, isFalse);
      expect(a.available, isFalse);
      expect(b.available, isTrue);
    },
  );
}
