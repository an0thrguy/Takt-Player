import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/layout_editor.dart';
import 'package:takt/ui/layout_preferences.dart';

void main() {
  testWidgets('layout preview is a draft and cancellation returns no result', (
    tester,
  ) async {
    LayoutPreferences? preview, result;
    final initial = LayoutPreferences.fromMap({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              child: const Text('edit'),
              onPressed: () async {
                result = await showDialog<LayoutPreferences>(
                  context: c,
                  builder: (_) => LayoutEditor(
                    initial: initial,
                    english: true,
                    dark: false,
                    onPreview: (v) => preview = v,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    final control = find.widgetWithText(ListTile, 'Recently played');
    await tester.ensureVisible(control);
    await tester.tap(
      find.descendant(of: control, matching: find.byType(Switch)),
    );
    await tester.pump();
    expect(preview!.hiddenSidebar, contains('recent'));
    expect(initial.hiddenSidebar, isEmpty);
    await tester.tap(find.byKey(const Key('layout-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
