import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/appearance.dart';
import 'package:takt/ui/backdrop_layers.dart';
import 'package:takt/ui/visualizer.dart';

void main() {
  testWidgets(
    'background solid persists through profile and dense bars render',
    (tester) async {
      for (final style in ['bars', 'solid']) {
        final profile = AppearanceProfile.fromMap({
          'backgroundVisualizer': true,
          'backgroundStyle': style,
          'backgroundBars': 128,
        });
        final restored = AppearanceProfile.fromMap(profile.toMap());
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: BackdropLayers(
                profile: restored,
                refreshHz: 30,
                sample: () => [.2, .5],
                child: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final signal = tester.widget<WaveSignal>(
          find.byKey(const Key('background-spectrum')),
        );
        expect(signal.bars, style == 'bars');
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<WavePainter>()
            .single;
        expect(painter.values.length, 64);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'missing wallpaper safely falls back and both bar layouts render',
    (tester) async {
      for (final full in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: BackdropLayers(
                profile: AppearanceProfile.fromMap({
                  'wallpaper': '/missing.png',
                  'backgroundVisualizer': true,
                  'backgroundFull': full,
                }),
                refreshHz: 15,
                sample: () => [.3, .5],
                child: const Text('foreground'),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('foreground'), findsOneWidget);
        expect(find.byKey(const Key('background-spectrum')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
