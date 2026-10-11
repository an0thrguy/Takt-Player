import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../artwork/artwork.dart';
import '../core/store.dart';
import '../playback/queue.dart';
import '../playback/sleep_timer.dart';
import '../ui/app.dart';
import '../ui/appearance.dart';
import 'android_analysis.dart';
import 'android_library.dart';
import 'android_playback.dart';

// Desktop window, tray, DBus and subprocess monitors never initialize on Android.
Future<void> startAndroid() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final store = TaktStore('${directory.path}/takt.sqlite');
  final library = AndroidMusicLibrary(
    store,
    artworkDirectory: '${directory.path}/artwork',
  );
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  final engine = AndroidMediaEngine(session);
  // Android owns the media stream volume; app gain remains at unity.
  await engine.volume(100);
  final queue = TaktQueue(store, engine, () => library.tracks);
  await queue.restore(loadMedia: false);
  final analysis = AndroidAnalysis();
  final artwork = ArtworkService('${directory.path}/artwork');
  late AndroidAudioHandler handler;
  late SleepTimer sleep;
  Timer? saver;
  bool quitting = false, visible = true, restored = true;
  bool demand() => visualizationDemand(
    Map<String, dynamic>.from(store.read('settings') as Map? ?? {}),
  );
  void updateAnalysis() {
    if (!quitting) analysis.setActive(visible && queue.playing && demand());
  }

  Future<void> shutdown() async {
    if (quitting) return;
    quitting = true;
    await queue.stop();
    queue.save();
    saver?.cancel();
    await sleep.cancel();
    sleep.dispose();
    analysis.dispose();
    artwork.cancel();
    library.dispose();
    await engine.player.dispose();
    // Stopping the media service may destroy Flutter when the activity is gone.
    await AndroidMusicLibrary.channel.invokeMethod<void>('quit');
    await handler.closeService();
    handler.dispose();
    store.close();
  }

  handler = await AudioService.init<AndroidAudioHandler>(
    builder: () => AndroidAudioHandler(queue, shutdown: shutdown),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.takt.player.playback',
      androidNotificationChannelName: 'Takt',
      androidNotificationIcon: 'drawable/ic_notification',
      androidStopForegroundOnPause: false,
      androidResumeOnClick: false,
    ),
  );
  sleep = SleepTimer(
    pause: queue.stop,
    quit: () async {
      await shutdown();
    },
    setVolume: engine.volume,
    getVolume: () => engine.player.state.volume,
    onError: (e) => library.reportError(e.toString()),
  );
  engine.player.stream.position.listen(queue.updatePosition);
  engine.player.stream.duration.listen((duration) {
    queue.current?.seconds = duration.inMilliseconds / 1000;
    handler.refresh();
  });
  engine.player.stream.playing.listen((playing) {
    queue.updatePlaying(playing);
    updateAnalysis();
  });
  engine.player.stream.completed.listen((done) {
    if (done && engine.player.state.completed) {
      unawaited(queue.completed(queue.currentId));
    }
  });
  engine.player.stream.error.listen((error) {
    if (!quitting) {
      library.reportError(error);
      unawaited(queue.stop());
    }
  });
  session.interruptionEventStream.listen((event) {
    if (event.begin) unawaited(queue.stop());
  });
  session.becomingNoisyEventStream.listen((_) {
    if ((store.read('settings') as Map?)?['pauseOnHeadphonesDisconnect'] !=
        false) {
      unawaited(queue.stop());
    }
  });
  String? analyzed;
  queue.addListener(() {
    final track = queue.current;
    if (track != null && analyzed != track.path) {
      analyzed = track.path;
      unawaited(analysis.load(track.path));
    }
    updateAnalysis();
  });
  bool fetching = false;
  final attempted = <String>{};
  bool permitted = false;
  Future<void> updateArtwork() async {
    if (quitting) return;
    final online = (store.read('settings') as Map?)?['onlineArtwork'] == true;
    if (online != permitted) {
      permitted = online;
      artwork.cancel();
      attempted.clear();
    }
    if (fetching || !online) return;
    final track = queue.current;
    if (track == null || track.artwork != null || !attempted.add(track.id)) {
      return;
    }
    fetching = true;
    try {
      final path = await artwork.resolve(track, online: online);
      if (!quitting && track.artwork == null && path != null) {
        track.artwork = path;
        library.persist();
      }
    } catch (e) {
      if (!quitting) library.reportError(e.toString());
    } finally {
      fetching = false;
    }
  }

  queue.addListener(updateArtwork);
  library.addListener(handler.refresh);
  final lifecycle = _AndroidLifecycle((state) {
    if (quitting) return;
    visible = state == AppLifecycleState.resumed;
    updateAnalysis();
    if (restored) queue.save();
    if (visible && restored) unawaited(library.scan());
  });
  WidgetsBinding.instance.addObserver(lifecycle);
  AndroidMusicLibrary.channel.setMethodCallHandler((call) async {
    if (call.method == 'mediaChanged' && !quitting) await library.scan();
  });
  runApp(
    TaktApp(
      mobile: true,
      library: library,
      queue: queue,
      store: store,
      sleepTimer: sleep,
      exit: () async {
        await shutdown();
      },
      close: () async {
        queue.save();
        await AndroidMusicLibrary.channel.invokeMethod<void>('background');
      },
      onSettingsChanged: () {
        updateAnalysis();
        unawaited(updateArtwork());
      },
      onVisualDemandChanged: (_) => updateAnalysis(),
      amplitudes: () => quitting
          ? const []
          : analysis.frame(
              queue.position,
              queue.playing,
              sensitivity:
                  ((store.read('settings') as Map?)?['visualizerSensitivity']
                              as num? ??
                          1)
                      .toDouble(),
            ),
    ),
  );
  // Permission requests happen after a visible first frame, never on a blank launch screen.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await library.start();
    if (quitting) return;
    if (store.read('android:notificationAsked') != true) {
      await AndroidMusicLibrary.channel.invokeMethod<bool>('notifications');
      store.write('android:notificationAsked', true);
    }
    restored = true;
    saver = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!quitting) queue.save();
    });
    unawaited(updateArtwork());
  });
}

class _AndroidLifecycle extends WidgetsBindingObserver {
  final ValueChanged<AppLifecycleState> changed;
  _AndroidLifecycle(this.changed);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => changed(state);
}
