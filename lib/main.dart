import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/store.dart';
import 'library/library.dart';
import 'library/discover_music.dart';
import 'playback/engine.dart';
import 'playback/queue.dart';
import 'analysis/audio_analysis.dart';
import 'ui/app.dart';
import 'platform/desktop.dart';
import 'platform/mpris.dart';
import 'platform/audio_routes.dart';
import 'artwork/artwork.dart';

// Application entry: storage, library, audio, events, window and UI. See docs/code-guide.md.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  // User data lives in app storage, separately from original music and project sources.
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final store = TaktStore('${directory.path}/takt.sqlite');
  final library = MusicLibrary(
        store,
        artworkDirectory: '${directory.path}/artwork',
      ),
      engine = MediaEngine(),
      analysis = AudioAnalysis();
  final queue = TaktQueue(store, engine, () => library.tracks);
  // Restore before showing the window, always without automatic playback.
  await queue.restore();
  final settings = store.read('settings') as Map?;
  await engine.volume((settings?['volume'] as num? ?? 70).toDouble());
  // Engine events update the shared queue; widgets observe it through ChangeNotifier.
  engine.player.stream.position.listen(queue.updatePosition);
  engine.player.stream.duration.listen((value) {
    if (queue.current != null) {
      queue.current!.seconds = value.inMilliseconds / 1000;
    }
  });
  // Analyze only while music plays and the window is visible.
  bool visible = true;
  engine.player.stream.playing.listen((value) {
    queue.updatePlaying(value);
    analysis.setActive(
      value &&
          visible &&
          (store.read('settings') as Map?)?['visualizerEnabled'] != false,
    );
  });
  engine.player.stream.completed.listen((value) {
    if (value && engine.player.state.completed) {
      queue.completed(queue.currentId);
    }
  });
  engine.player.stream.error.listen((error) {
    library.reportError(error);
    queue.stop();
  });
  analysis.setActive(queue.playing);
  // Analyze on track changes rather than every position update.
  String? analyzed;
  queue.addListener(() {
    if (queue.currentId != analyzed && queue.current != null) {
      analyzed = queue.currentId;
      analysis.load(queue.current!.path);
    }
  });
  if (queue.current != null) {
    analyzed = queue.currentId;
    analysis.load(queue.current!.path);
  }
  // Checkpoint the position every two seconds; full shutdown also saves it.
  final saver = Timer.periodic(const Duration(seconds: 2), (_) => queue.save());
  late DesktopLifecycle desktop;
  TaktMpris? mpris;
  HeadphoneMonitor? headphones;
  bool quitting = false;
  // Shared full exit for settings, tray, Super+Q and SIGTERM; repeated calls are ignored.
  Future<void> quit() async {
    if (quitting) return;
    quitting = true;
    saver.cancel();
    queue.save();
    headphones?.dispose();
    await mpris?.dispose();
    desktop.dispose();
    analysis.dispose();
    library.dispose();
    await engine.player.dispose();
    store.close();
    exit(0);
  }

  // The Hyprland helper sends SIGTERM: save state before releasing resources.
  ProcessSignal.sigterm.watch().listen((_) => unawaited(quit()));

  desktop = DesktopLifecycle(
    store,
    quit,
    queue.toggle,
    next: queue.next,
    previous: queue.previous,
    onVisibility: (value) {
      visible = value;
      analysis.setActive(
        value &&
            queue.playing &&
            (store.read('settings') as Map?)?['visualizerEnabled'] != false,
      );
    },
  );
  // Initial/minimum window size and title; adjust window dimensions here.
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1080, 760),
      minimumSize: Size(620, 520),
      title: 'Takt',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  mpris = TaktMpris(
    queue,
    raise: desktop.show,
    quit: quit,
    volume: () => engine.player.state.volume / 100,
    setVolume: (level) async {
      final preferences = Map<String, dynamic>.from(
        store.read('settings') as Map? ?? {},
      );
      preferences['volume'] = level * 100;
      store.write('settings', preferences);
      await engine.volume(level * 100);
      queue.updatePosition(queue.position);
    },
  );
  library.addListener(mpris.refresh);
  engine.player.stream.volume.listen((_) => mpris?.refresh());
  engine.player.stream.duration.listen((_) => mpris?.refresh());
  unawaited(
    mpris.start().catchError((Object error) {
      library.reportError('Linux media integration: $error');
    }),
  );
  headphones = HeadphoneMonitor(
    enabled: () =>
        (store.read('settings') as Map?)?['pauseOnHeadphonesDisconnect'] !=
        false,
    onDisconnect: () async {
      if (queue.playing) await queue.stop();
    },
  );
  unawaited(headphones.start());
  final artwork = ArtworkService('${directory.path}/artwork');
  bool artBusy = false;
  int permission = 0;
  final attempted = <String>{};
  // One cover attempt per track/permission state; revoking permission cancels pending network work.
  Future<void> updateArtwork() async {
    final online = (store.read('settings') as Map?)?['onlineArtwork'] == true;
    final nextPermission = online ? 1 : 0;
    if (nextPermission != permission) {
      permission = nextPermission;
      artwork.cancel();
      attempted.clear();
    }
    if (artBusy) return;
    artBusy = true;
    try {
      final t = queue.current;
      if (t != null && t.artwork == null && attempted.add(t.id)) {
        final path = await artwork.resolve(t, online: online);
        if (path != null && t.artwork == null) {
          t.artwork = path;
          library.persist();
        }
      }
    } catch (error) {
      library.reportError(error.toString());
    } finally {
      artBusy = false;
    }
  }

  queue.addListener(updateArtwork);
  // If the current file disappears, advance to an available track without parallel transitions.
  bool advancingMissing = false;
  library.addListener(() async {
    if (queue.current?.available == false &&
        queue.playing &&
        !advancingMissing) {
      advancingMissing = true;
      try {
        await queue.next();
      } finally {
        advancingMissing = false;
      }
    }
  });
  // First launch: discover Music or let the interface offer a directory picker.
  if (library.sources.isEmpty) {
    final path = await discoverMusic();
    if (path != null) library.sources.add(path);
  }
  runApp(
    TaktApp(
      library: library,
      queue: queue,
      store: store,
      amplitudes: () =>
          visible &&
              (store.read('settings') as Map?)?['visualizerEnabled'] != false
          ? analysis.frame(
              queue.position,
              queue.playing,
              sensitivity:
                  ((store.read('settings') as Map?)?['visualizerSensitivity']
                              as num? ??
                          1)
                      .toDouble(),
            )
          : const [],
      exit: quit,
      onSettingsChanged: () {
        desktop.refreshLanguage();
        analysis.setActive(
          queue.playing &&
              visible &&
              (store.read('settings') as Map?)?['visualizerEnabled'] != false,
        );
        updateArtwork();
      },
      promptForFolder: library.sources.isEmpty,
    ),
  );
  // The window is usable already; slower scanning/initialization must not block its appearance.
  unawaited(desktop.initialize(directory.path));

  unawaited(library.start());
  unawaited(updateArtwork());
}
