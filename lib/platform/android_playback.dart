import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../core/track.dart';
import '../playback/engine.dart';
import '../playback/queue.dart';

// The app and Android media buttons operate on the same serialized queue.
class AndroidAudioHandler extends BaseAudioHandler {
  final TaktQueue takt;
  final Future<void> Function() shutdown;
  String _metadataStamp = '';
  String _queueStamp = '';
  AndroidAudioHandler(this.takt, {required this.shutdown}) {
    takt.addListener(refresh);
    refresh();
  }
  MediaItem _item(Track t) => MediaItem(
    id: t.id,
    title: t.title,
    artist: t.artist,
    album: t.album,
    duration: Duration(milliseconds: (t.seconds * 1000).round()),
    artUri: t.artwork == null ? null : Uri.file(t.artwork!),
  );
  void refresh() {
    final current = takt.current;
    final stamp =
        '${current?.id}:${current?.title}:${current?.artist}:${current?.artwork}:${current?.seconds}';
    if (stamp != _metadataStamp) {
      _metadataStamp = stamp;
      mediaItem.add(current == null ? null : _item(current));
    }
    final queueStamp = takt.ids.join(',');
    if (queueStamp != _queueStamp) {
      _queueStamp = queueStamp;
      final tracks = {for (final t in takt.tracks()) t.id: t};
      queue.add([
        for (final id in takt.ids)
          if (tracks[id] != null) _item(tracks[id]!),
      ]);
    }
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          takt.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: current == null
            ? AudioProcessingState.idle
            : takt.opening
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: takt.playing,
        updatePosition: takt.position,
        queueIndex: current == null ? null : takt.ids.indexOf(current.id),
      ),
    );
  }

  @override
  Future<void> play() async {
    if (!takt.playing) await takt.toggle();
  }

  @override
  Future<void> pause() => takt.stop();
  @override
  Future<void> skipToNext() => takt.next();
  @override
  Future<void> skipToPrevious() => takt.previous();
  @override
  Future<void> seek(Duration position) => takt.seek(position);
  @override
  Future<void> stop() async {
    await takt.stop();
    takt.save();
    // Notification dismissal stops music but keeps the app and native callbacks alive.
    // Only coordinated shutdown is allowed to publish idle and close the service.
  }

  // Use after disposing libmpv: publishing idle may tear down Flutter itself.
  Future<void> closeService() async {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    // Keep the Flutter engine alive until libmpv callbacks have been detached.
    await takt.stop();
    takt.save();
    await shutdown();
  }

  void dispose() => takt.removeListener(refresh);
}

// Request system focus before audible playback, while retaining broad libmpv decoding.
class AndroidMediaEngine extends MediaEngine {
  final AudioSession session;
  AndroidMediaEngine(this.session);
  Future<void> _focus() async {
    if (!await session.setActive(true)) {
      throw StateError('Android audio focus unavailable');
    }
  }

  @override
  Future<void> open(Track track, {bool play = false}) async {
    if (play) await _focus();
    await super.open(track, play: play);
  }

  @override
  Future<void> play() async {
    await _focus();
    await super.play();
  }

  @override
  Future<void> pause() async {
    await super.pause();
    await session.setActive(false);
  }
}
