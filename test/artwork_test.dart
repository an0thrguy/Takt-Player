// Regression checks for artwork; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/artwork/artwork.dart';
import 'package:takt/core/track.dart';

void main() {
  test(
    'permission revoked during metadata response prevents image request',
    () async {
      final dir = await Directory.systemTemp.createTemp('takt-http-');
      addTearDown(() => dir.delete(recursive: true));
      final requested = <Uri>[],
          started = Completer<void>(),
          response = Completer<http.Response>();
      final art = ArtworkService(
        dir.path,
        clientFactory: () => MockClient((request) {
          requested.add(request.url);
          started.complete();
          return response.future;
        }),
      );
      final future = art.resolve(
        Track(
          id: 'a',
          path: '/missing',
          originalTitle: 'A',
          artist: 'Test Artist',
          album: 'Test Album',
        ),
        online: true,
      );
      await started.future;
      art.cancel();
      response.complete(
        http.Response('{"releases":[{"id":"test","score":100}]}', 200),
      );
      expect(await future, isNull);
      expect(requested.length, 1);
      expect(requested.single.host, 'musicbrainz.org');
    },
  );
  test('ambiguous releases leave placeholder without cover request', () async {
    final dir = await Directory.systemTemp.createTemp('takt-http-');
    addTearDown(() => dir.delete(recursive: true));
    var calls = 0;
    final art = ArtworkService(
      dir.path,
      clientFactory: () => MockClient((request) async {
        calls++;
        return http.Response(
          '{"releases":[{"id":"one","score":100},{"id":"two","score":100}]}',
          200,
        );
      }),
    );
    expect(
      await art.resolve(
        Track(
          id: 'a',
          path: '/missing',
          originalTitle: 'A',
          artist: 'Artist',
          album: 'Album',
        ),
        online: true,
      ),
      isNull,
    );
    expect(calls, 1);
  });

  test('disabled online lookup never invokes provider', () async {
    final dir = await Directory.systemTemp.createTemp('takt-art-');
    int calls = 0;
    final art = ArtworkService(
      dir.path,
      lookup: (track) async {
        calls++;
        return null;
      },
    );
    final track = Track(id: 'a', path: '/missing', originalTitle: 'A');
    await art.resolve(track, online: false);
    expect(calls, 0);
    await dir.delete(recursive: true);
  });
  test('late artwork response is discarded when permission revoked', () async {
    final dir = await Directory.systemTemp.createTemp('takt-art-');
    final started = Completer<void>(), response = Completer<List<int>?>();
    final art = ArtworkService(
      dir.path,
      lookup: (track) {
        started.complete();
        return response.future;
      },
    );
    final future = art.resolve(
      Track(id: 'a', path: '/missing', originalTitle: 'A'),
      online: true,
    );
    await started.future;
    art.cancel();
    response.complete([1, 2, 3]);
    expect(await future, isNull);
    expect(await File('${dir.path}/a.jpg').exists(), isFalse);
    await dir.delete(recursive: true);
  });
}
