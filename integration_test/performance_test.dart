// Native Linux integration checks; fixtures and reports live in /tmp to keep user data untouched.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/core/track.dart';
import 'package:takt/library/library.dart';
import 'package:takt/playback/engine.dart';
import 'package:takt/playback/queue.dart';
import 'package:takt/ui/app.dart';

class SilentEngine implements AudioEngine {
  @override
  Future<void> open(Track t, {bool play = false}) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration d) async {}
  @override
  Future<void> volume(double v) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('500 track search UI frame measurements', (tester) async {
    Future<void> input(String value) async {
      final editable = find.descendant(
        of: find.byKey(const Key('track-search')),
        matching: find.byType(EditableText),
      );
      tester
          .state<EditableTextState>(editable)
          .updateEditingValue(
            TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            ),
          );
    }

    final store = TaktStore.memory(),
        library = MusicLibrary(TaktStore.memory());
    library.tracks = [
      for (var i = 0; i < 500; i++)
        Track(
          id: '$i',
          path: '/sample/$i.flac',
          originalTitle: 'Song ${i.toString().padLeft(3, '0')}',
          artist: 'Test artist',
        ),
    ];
    final queue = TaktQueue(store, SilentEngine(), () => library.tracks);
    final frames = <double>[];
    void timings(List<FrameTiming> values) {
      frames.addAll(values.map((f) => f.totalSpan.inMicroseconds / 1000));
    }

    SchedulerBinding.instance.addTimingsCallback(timings);
    await tester.pumpWidget(
      TaktApp(library: library, queue: queue, store: store),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('track-search')));
    await tester.pumpAndSettle();
    final search = Stopwatch()..start();
    await input('499');
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    search.stop();
    expect(find.text('Song 499'), findsOneWidget);
    final click = Stopwatch()..start();
    await tester.tap(find.text('Song 499'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    click.stop();
    expect(queue.currentId, '499');
    await input('');
    await tester.pumpAndSettle();
    expect(queue.ids, ['499']);
    await tester.fling(
      find.byType(ReorderableListView),
      const Offset(0, -900),
      1200,
    );
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(timings);
    frames.sort();
    final report = {
      'tracks': 500,
      'searchVisibleMs': search.elapsedMicroseconds / 1000,
      'tapToFirstUpdatedFramesMs': click.elapsedMicroseconds / 1000,
      'frameSamples': frames.length,
      'frameMedianMs': frames.isEmpty ? null : frames[frames.length ~/ 2],
      'frameP95Ms': frames.isEmpty
          ? null
          : frames[(frames.length * .95).floor().clamp(0, frames.length - 1)],
      'method': 'Flutter Linux native; selected build mode;  TextInputClient update to settled UI (IME dispatch excluded); tap includes input dispatch, frame timing includes build/raster pipeline; synthetic indexed library',
    };
    await File('/tmp/takt-performance.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    debugPrint(jsonEncode(report));
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    library.dispose();
    library.store.close();
    store.close();
  });
}
