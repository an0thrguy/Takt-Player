import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/volume_control.dart';

void main() {
  testWidgets(
    'volume wheel accumulates and clamps; inline and popup stay current',
    (tester) async {
      double value = 98;
      final notifier = ValueNotifier<double>(value);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: notifier,
              builder: (c, v, _) => VolumeControl(
                value: v,
                onChanged: (n) {
                  value = n;
                  notifier.value = n;
                },
                inline: false,
                wheelEnabled: true,
                dark: false,
                glass: false,
                english: true,
              ),
            ),
          ),
        ),
      );
      final target = tester.getCenter(find.byIcon(Icons.volume_up_outlined));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: target, scrollDelta: const Offset(0, -40)),
      );
      await tester.pump();
      expect(value, 98);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: target, scrollDelta: const Offset(0, -60)),
      );
      await tester.pump();
      expect(value, 100);
      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('volume-slider')), findsOneWidget);
      notifier.value = 25;
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byKey(const Key('volume-slider'))).value,
        25,
      );
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeControl(
              value: 25,
              onChanged: (_) {},
              inline: true,
              wheelEnabled: false,
              dark: false,
              glass: false,
              english: true,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('volume-slider')), findsOneWidget);
      notifier.dispose();
    },
  );
}
