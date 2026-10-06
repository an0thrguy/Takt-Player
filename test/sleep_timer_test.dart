import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/playback/sleep_timer.dart';

void main() {
  test('manual adjustment during expiry prevents restore and exit', () async {
    var now = DateTime(2026);
    final pause = Completer<void>();
    double volume = 80;
    int quit = 0;
    final t = SleepTimer(
      now: () => now,
      getVolume: () => 80,
      setVolume: (v) async => volume = v,
      pause: () => pause.future,
      quit: () async {
        quit++;
      },
    );
    await t.start(const Duration(seconds: 20), fade: true, exitWhenDone: true);
    now = now.add(const Duration(seconds: 10));
    await t.tick();
    now = now.add(const Duration(seconds: 10));
    final expiry = t.tick();
    expect(t.fading, true);
    final cancel = t.cancel(restore: false);
    pause.complete();
    await expiry;
    await cancel;
    volume = 42;
    expect(volume, 42);
    expect(quit, 0);
    t.dispose();
  });

  test(
    'fade is temporary, expiry pauses before restoring and quitting',
    () async {
      var now = DateTime(2026);
      final events = <String>[];
      double volume = 80;
      final timer = SleepTimer(
        now: () => now,
        getVolume: () => 80,
        setVolume: (v) async {
          volume = v;
          events.add('volume:${v.round()}');
        },
        pause: () async {
          events.add('pause');
        },
        quit: () async {
          events.add('quit');
        },
      );
      await timer.start(
        const Duration(seconds: 30),
        fade: true,
        exitWhenDone: true,
      );
      now = now.add(const Duration(seconds: 20));
      await timer.tick();
      expect(volume, closeTo(80 * 10 / 15, .1));
      expect(timer.active, true);
      now = now.add(const Duration(seconds: 10));
      await timer.tick();
      expect(events.sublist(events.length - 3), ['pause', 'volume:80', 'quit']);
      expect(timer.active, false);
      timer.dispose();
    },
  );
  test('cancel waits for in-flight fade and prevents late quit', () async {
    var now = DateTime(2026);
    final gate = Completer<void>();
    int quits = 0;
    double volume = 70;
    final timer = SleepTimer(
      now: () => now,
      getVolume: () => 70,
      setVolume: (v) async {
        await gate.future;
        volume = v;
      },
      pause: () async {},
      quit: () async {
        quits++;
      },
    );
    await timer.start(
      const Duration(seconds: 20),
      fade: true,
      exitWhenDone: true,
    );
    now = now.add(const Duration(seconds: 10));
    final tick = timer.tick();
    final cancel = timer.cancel(restore: false);
    gate.complete();
    await tick;
    await cancel;
    volume = 42;
    now = now.add(const Duration(seconds: 30));
    await timer.tick();
    expect(volume, 42);
    expect(quits, 0);
    timer.dispose();
  });
  test('cancel restores faded volume and invalid durations fail', () async {
    var now = DateTime(2026);
    double volume = 60;
    final timer = SleepTimer(
      now: () => now,
      getVolume: () => 60,
      setVolume: (v) async => volume = v,
      pause: () async {},
      quit: () async {},
    );
    await timer.start(const Duration(seconds: 20), fade: true);
    now = now.add(const Duration(seconds: 10));
    await timer.tick();
    expect(volume, lessThan(60));
    await timer.cancel();
    expect(volume, 60);
    expect(() => timer.start(Duration.zero), throwsArgumentError);
    timer.dispose();
  });
}
