import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/visualizer.dart';

void main() {
  test(
    'all visualizer styles mirror their spectrum across the center',
    () async {
      for (final style in ['bars', 'linear', 'solid']) {
        final recorder = ui.PictureRecorder();
        WavePainter(
          [.8, .1, .3, .05],
          Colors.white,
          bars: style == 'bars',
          linear: style == 'linear',
        ).paint(Canvas(recorder), const Size(240, 120));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 120);
        final data = (await image.toByteData())!;
        var mismatch = 0;
        var painted = 0;
        for (var y = 0; y < 120; y++) {
          for (var x = 0; x < 120; x++) {
            final a = data.getUint8((y * 240 + x) * 4 + 3);
            final b = data.getUint8((y * 240 + 239 - x) * 4 + 3);
            if ((a - b).abs() > 4) mismatch++;
            if (a > 0) painted++;
          }
        }
        expect(painted, greaterThan(100), reason: style);
        // Allow less than 2% edge pixels for directional curve rasterization.
        expect(mismatch, lessThan(288), reason: style);
        image.dispose();
        picture.dispose();
      }
    },
  );

  testWidgets('spectrum reacts to a beat and releases smoothly into silence', (
    tester,
  ) async {
    var target = <double>[0];
    await tester.pumpWidget(
      MaterialApp(
        home: WaveSignal(
          values: const [],
          color: Colors.white,
          sample: () => target,
        ),
      ),
    );
    target = [1];
    await tester.pump(const Duration(milliseconds: 34));
    WavePainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<WavePainter>()
        .single;
    expect(painter().values.single, greaterThan(.5));
    target = [];
    await tester.pump(const Duration(milliseconds: 34));
    expect(painter().values.single, greaterThan(0));
    expect(painter().values.single, lessThan(.9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'economy samples no more than 15 times each second and stops on disposal',
    (tester) async {
      int samples = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WaveSignal(
            values: const [],
            color: Colors.black,
            refreshHz: 15,
            sample: () {
              samples++;
              return [.2, .4];
            },
          ),
        ),
      );
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(samples, lessThanOrEqualTo(15));
      expect(samples, greaterThan(5));
      await tester.pumpWidget(const SizedBox());
      final before = samples;
      await tester.pump(const Duration(seconds: 1));
      expect(samples, before);
    },
  );
}
