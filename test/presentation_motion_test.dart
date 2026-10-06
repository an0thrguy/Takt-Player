import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/glass.dart';
import 'package:takt/ui/presentation_preferences.dart';
import 'package:takt/ui/presentation_scope.dart';

void main() {
  testWidgets('economy avoids blur and disabled motion opens immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, child) => PresentationScope(
          preferences: PresentationPreferences.fromMap({
            'performanceMode': 'economy',
            'animationsEnabled': false,
          }),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) => GlassSurface(
              dark: false,
              child: TextButton(
                onPressed: () => showTaktDialog<void>(
                  context: c,
                  builder: (_) => const Dialog(child: Text('modal')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('modal'), findsOneWidget);
  });
}
