import 'package:media_kit/media_kit.dart' hide Track;

import '../core/track.dart';

// Audio boundary. Tests substitute an implementation without real playback devices.
abstract class AudioEngine {
  // Finish configuring the audio profile before the first media file opens.
  Future<void> open(Track track, {bool play = false});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration value);
  Future<void> volume(double value);
}

// Actual libmpv playback; queue order and playback modes belong to queue.dart.
class MediaEngine implements AudioEngine {
  final Player player = Player(
    configuration: const PlayerConfiguration(title: 'Takt'),
  );
  Future<void>? _initialized;
  // A dedicated Takt audio profile avoids inheriting the shared mpv mute state.
  Future<void> _initialize() => _initialized ??= () async {
    final native = player.platform;
    if (native is NativePlayer) {
      await native.setProperty('audio-client-name', 'Takt');
    }
  }();
  @override
  // Finish configuring the audio profile before the first media file opens.
  Future<void> open(Track track, {bool play = false}) async {
    await _initialize();
    await player.open(Media(track.path), play: play);
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration value) => player.seek(value);
  @override
  Future<void> volume(double value) => player.setVolume(value);
}
