import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/appearance.dart';
import 'package:takt/ui/backdrop_layers.dart';

void main() {
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
