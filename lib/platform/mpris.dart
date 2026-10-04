import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';

import '../playback/queue.dart';

// Standard Linux media interface used by Serpantinum, playerctl and media keys.
// The queue remains the single owner of playback; the shell never opens files itself.
class TaktMpris extends DBusObject {
  static const rootInterface = 'org.mpris.MediaPlayer2';
  static const playerInterface = 'org.mpris.MediaPlayer2.Player';
  final TaktQueue queue;
  final Future<void> Function() raise, quit;
  final double Function() volume;
  final Future<void> Function(double) setVolume;
  DBusClient? _bus;
  Map<String, DBusValue> _last = {};
  bool _disposed = false;
  bool _stopped = false;

  TaktMpris(
    this.queue, {
    required this.raise,
    required this.quit,
    required this.volume,
    required this.setVolume,
  }) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  // Encode arbitrary persisted IDs as legal, stable D-Bus path components.
  DBusObjectPath get trackPath => DBusObjectPath(
    queue.currentId == null
        ? '/org/mpris/MediaPlayer2/TrackList/NoTrack'
        : '/takt/track/t${utf8.encode(queue.currentId!).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
  );
  Map<String, DBusValue> get metadata {
    final track = queue.current;
    if (track == null) return {};
    return {
      'mpris:trackid': trackPath,
      'mpris:length': DBusInt64((track.seconds * 1000000).round()),
      'xesam:title': DBusString(track.title),
      'xesam:artist': DBusArray.string(
        track.artist.isEmpty ? [] : [track.artist],
      ),
      'xesam:album': DBusString(track.album),
      'xesam:url': DBusString(Uri.file(track.path).toString()),
      if (track.artwork != null)
        'mpris:artUrl': DBusString(Uri.file(track.artwork!).toString()),
    };
  }

  Map<String, DBusValue> get rootProperties => {
    'Identity': DBusString('Takt'),
    'DesktopEntry': DBusString('takt'),
    'CanQuit': DBusBoolean(true),
    'CanRaise': DBusBoolean(true),
    'HasTrackList': DBusBoolean(false),
    'SupportedUriSchemes': DBusArray.string(['file']),
    'SupportedMimeTypes': DBusArray.string([
      'audio/mpeg',
      'audio/flac',
      'audio/ogg',
      'audio/wav',
      'audio/mp4',
    ]),
  };
  Map<String, DBusValue> get playerProperties => {
    'PlaybackStatus': DBusString(
      queue.playing
          ? 'Playing'
          : queue.current == null || _stopped
          ? 'Stopped'
          : 'Paused',
    ),
    'LoopStatus': DBusString(
      queue.mode == QueueMode.single
          ? 'Track'
          : queue.mode == QueueMode.once
          ? 'None'
          : 'Playlist',
    ),
    'Shuffle': DBusBoolean(queue.mode == QueueMode.shuffle),
    'Metadata': DBusDict.stringVariant(metadata),
    'Position': DBusInt64(queue.position.inMicroseconds),
    'Volume': DBusDouble(volume()),
    'Rate': DBusDouble(1),
    'MinimumRate': DBusDouble(1),
    'MaximumRate': DBusDouble(1),
    'CanGoNext': DBusBoolean(queue.ids.isNotEmpty),
    'CanGoPrevious': DBusBoolean(queue.ids.isNotEmpty),
    'CanPlay': DBusBoolean(
      queue.current?.available == true || queue.ids.isNotEmpty,
    ),
    'CanPause': DBusBoolean(queue.current != null),
    'CanSeek': DBusBoolean(queue.current?.available == true),
    'CanControl': DBusBoolean(true),
  };

  Future<void> start() async {
    if (_disposed) return;
    final bus = _bus = DBusClient.session();
    try {
      await bus.registerObject(this);
      final reply = await bus.requestName(
        'org.mpris.MediaPlayer2.takt',
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply == DBusRequestNameReply.exists) {
        await bus.requestName(
          'org.mpris.MediaPlayer2.takt.instance$pid',
          flags: {DBusRequestNameFlag.doNotQueue},
        );
      }
      if (_disposed) {
        await bus.close();
        return;
      }
      queue.addListener(refresh);
      refresh();
    } catch (_) {
      await bus.close();
      _bus = null;
      rethrow;
    }
  }

  // Position is queried by clients; MPRIS forbids PropertiesChanged for it.
  // Compare values to avoid emitting at every engine position notification.
  void refresh() {
    if (_disposed || _bus == null) return;
    if (queue.playing) _stopped = false;
    final values = playerProperties..remove('Position');
    final changed = <String, DBusValue>{
      for (final entry in values.entries)
        if (_last[entry.key] != entry.value) entry.key: entry.value,
    };
    _last = values;
    if (changed.isNotEmpty) {
      unawaited(
        emitPropertiesChanged(
          playerInterface,
          changedProperties: changed,
        ).catchError((Object _) {}),
      );
    }
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectArgument arg(String signature) => DBusIntrospectArgument(
      DBusSignature(signature),
      DBusArgumentDirection.in_,
    );
    final writable = {'LoopStatus', 'Shuffle', 'Volume', 'Rate'};
    return [
      DBusIntrospectInterface(
        rootInterface,
        methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
        properties: [
          for (final e in rootProperties.entries)
            DBusIntrospectProperty(
              e.key,
              e.value.signature,
              access: DBusPropertyAccess.read,
            ),
        ],
      ),
      DBusIntrospectInterface(
        playerInterface,
        methods: [
          for (final name in [
            'Next',
            'Previous',
            'Pause',
            'PlayPause',
            'Stop',
            'Play',
          ])
            DBusIntrospectMethod(name),
          DBusIntrospectMethod('Seek', args: [arg('x')]),
          DBusIntrospectMethod('SetPosition', args: [arg('o'), arg('x')]),
          DBusIntrospectMethod('OpenUri', args: [arg('s')]),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
              ),
            ],
          ),
        ],
        properties: [
          for (final e in playerProperties.entries)
            DBusIntrospectProperty(
              e.key,
              e.value.signature,
              access: writable.contains(e.key)
                  ? DBusPropertyAccess.readwrite
                  : DBusPropertyAccess.read,
            ),
        ],
      ),
    ];
  }

  Map<String, DBusValue>? _properties(String interface) =>
      interface == rootInterface
      ? rootProperties
      : interface == playerInterface
      ? playerProperties
      : null;
  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final properties = _properties(interface);
    if (properties == null) return DBusMethodErrorResponse.unknownInterface();
    final value = properties[name];
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final properties = _properties(interface);
    return properties == null
        ? DBusMethodErrorResponse.unknownInterface()
        : DBusGetAllPropertiesResponse(properties);
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    final properties = _properties(interface);
    if (properties == null) return DBusMethodErrorResponse.unknownInterface();
    if (!properties.containsKey(name)) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    if (interface != playerInterface ||
        !{'LoopStatus', 'Shuffle', 'Volume', 'Rate'}.contains(name)) {
      return DBusMethodErrorResponse.propertyReadOnly();
    }
    if (value.signature != properties[name]!.signature) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    try {
      switch (name) {
        case 'Volume':
          final level = value.asDouble();
          if (!level.isFinite) return DBusMethodErrorResponse.invalidArgs();
          await setVolume(level.clamp(0, 1));
        case 'Shuffle':
          if (value.asBoolean()) {
            queue.mode = QueueMode.shuffle;
          } else if (queue.mode == QueueMode.shuffle) {
            queue.mode = QueueMode.loop;
          }
          queue.save();
        case 'LoopStatus':
          final mode = value.asString();
          if (!['Track', 'Playlist', 'None'].contains(mode)) {
            return DBusMethodErrorResponse.invalidArgs();
          }
          queue.mode = mode == 'Track'
              ? QueueMode.single
              : mode == 'None'
              ? QueueMode.once
              : QueueMode.loop;
          queue.save();
        case 'Rate':
          if (value.asDouble() != 1) {
            return DBusMethodErrorResponse.notSupported();
          }
      }
      refresh();
      return DBusMethodSuccessResponse();
    } catch (_) {
      return DBusMethodErrorResponse.failed('Playback command failed');
    }
  }

  Future<void> _seek(int microseconds) async {
    final length = ((queue.current?.seconds ?? 0) * 1000000).round();
    final target = microseconds.clamp(
      0,
      length > 0 ? length : microseconds.abs(),
    );
    await queue.seek(Duration(microseconds: target));
    await emitSignal(playerInterface, 'Seeked', [
      DBusInt64(queue.position.inMicroseconds),
    ]);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    final signatures = methodCall.interface == rootInterface
        ? {'Raise': '', 'Quit': ''}
        : methodCall.interface == playerInterface
        ? {
            'Next': '',
            'Previous': '',
            'Pause': '',
            'PlayPause': '',
            'Stop': '',
            'Play': '',
            'Seek': 'x',
            'SetPosition': 'ox',
            'OpenUri': 's',
          }
        : null;
    if (signatures == null) return DBusMethodErrorResponse.unknownInterface();
    if (!signatures.containsKey(methodCall.name)) {
      return DBusMethodErrorResponse.unknownMethod();
    }
    if (methodCall.signature != DBusSignature(signatures[methodCall.name]!)) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    try {
      switch (methodCall.name) {
        case 'Raise':
          await raise();
        // Let the D-Bus response leave before the process starts shutting down.
        case 'Quit':
          Timer.run(() => unawaited(quit()));
        case 'Next':
          await queue.next();
        case 'Previous':
          await queue.previous();
        case 'PlayPause':
          await queue.toggle();
        case 'Play':
          if (!queue.playing) await queue.toggle();
        case 'Pause':
          if (queue.playing) await queue.toggle();
        case 'Stop':
          await queue.stop();
          if (queue.current != null) await queue.seek(Duration.zero);
          _stopped = true;
          refresh();
        case 'Seek':
          if (queue.current != null) {
            final target =
                queue.position.inMicroseconds + methodCall.values[0].asInt64();
            if (target > (queue.current!.seconds * 1000000).round() &&
                queue.current!.seconds > 0) {
              await queue.next();
            } else {
              await _seek(target);
            }
          }
        case 'SetPosition':
          if (methodCall.values[0] == trackPath &&
              methodCall.values[1].asInt64() >= 0 &&
              queue.current != null &&
              methodCall.values[1].asInt64() <=
                  (queue.current!.seconds * 1000000).round()) {
            await _seek(methodCall.values[1].asInt64());
          }
        case 'OpenUri':
          return DBusMethodErrorResponse.notSupported(
            'Use Takt to add music folders',
          );
      }
      return DBusMethodSuccessResponse();
    } catch (_) {
      return DBusMethodErrorResponse.failed('Playback command failed');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    queue.removeListener(refresh);
    await _bus?.close();
    _bus = null;
  }
}
