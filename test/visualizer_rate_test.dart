import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/visualizer.dart';

void main() {
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
