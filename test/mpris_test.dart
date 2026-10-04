import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/platform/mpris.dart';
import 'package:takt/playback/queue.dart';

import 'queue_test.dart' show TestEngine;

void main() {
  test(
    'MPRIS publishes real state and routes controls through the queue',
    () async {
      final store = TaktStore.memory();
      addTearDown(store.close);
      final tracks = [
        Track(
          id: 'a',
          path: '/music/a.flac',
          originalTitle: 'First',
          artist: 'Artist',
          seconds: 60,
        ),
        Track(
          id: 'b',
          path: '/music/b.flac',
          originalTitle: 'Second',
          seconds: 60,
        ),
      ];
      final queue = TaktQueue(store, TestEngine(), () => tracks);
      final mpris = TaktMpris(
        queue,
        raise: () async {},
        quit: () async {},
        volume: () => .7,
        setVolume: (_) async {},
      );
      expect(mpris.playerProperties['PlaybackStatus'], DBusString('Stopped'));
      await queue.start(['a', 'b'], 'a');
      expect(mpris.playerProperties['PlaybackStatus'], DBusString('Playing'));
      expect(mpris.metadata['xesam:title'], DBusString('First'));
      expect(mpris.metadata['mpris:length'], DBusInt64(60000000));
      await mpris.handleMethodCall(
        DBusMethodCall(
          sender: ':1.1',
          interface: TaktMpris.playerInterface,
          name: 'Pause',
          values: [],
        ),
      );
      expect(queue.playing, false);
      await mpris.handleMethodCall(
        DBusMethodCall(
          sender: ':1.1',
          interface: TaktMpris.playerInterface,
          name: 'Next',
          values: [],
        ),
      );
      expect(queue.currentId, 'b');
      final response = await mpris.handleMethodCall(
        DBusMethodCall(
          sender: ':1.1',
          interface: TaktMpris.playerInterface,
          name: 'SetPosition',
          values: [DBusObjectPath('/takt/track/stale'), DBusInt64(10000000)],
        ),
      );
      expect(response, isA<DBusMethodSuccessResponse>());
      expect(queue.position, Duration.zero);
      final invalid = await mpris.handleMethodCall(
        DBusMethodCall(
          sender: ':1.1',
          interface: TaktMpris.playerInterface,
          name: 'Seek',
          values: [DBusString('wrong')],
        ),
      );
      expect(invalid, isA<DBusMethodErrorResponse>());
    },
  );
}
