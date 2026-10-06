import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/appearance_editor.dart';

void main() {
  testWidgets(
    'presets create rename delete and persist without playback changes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> settings = {'locale': 'en', 'volume': 73};
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: c,
                  builder: (_) => AppearanceEditor(
                    settings: settings,
                    chooseWallpaper: () async => null,
                    onPreview: (_) {},
                    onCancel: () {},
                    onSave: (value) async {
                      settings = value;
                      saved = value;
                      return true;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final name = find.byType(TextField).first;
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Night');
      await tester.pump();
      await tester.tap(find.text('Create preset'));
      await tester.pumpAndSettle();
      final rename = find.byTooltip('Rename');
      await tester.ensureVisible(rename);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Evening');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Evening'), findsOneWidget);
      await tester.tap(find.byKey(const Key('appearance-save')));
      await tester.pumpAndSettle();
      expect(saved!['appearancePresets'].single['name'], 'Evening');
      expect(saved!['volume'], 73);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Delete'));
      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('appearance-save')));
      await tester.pumpAndSettle();
      expect(saved!['appearancePresets'], isEmpty);
    },
  );
}
