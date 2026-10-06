import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/appearance_editor.dart';

void main() {
  testWidgets('a save in progress cannot be dismissed before committing', (
    tester,
  ) async {
    final save = Completer<bool>();
    late BuildContext c;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            c = ctx;
            return const Scaffold();
          },
        ),
      ),
    );
    final dialog = showDialog<void>(
      context: c,
      builder: (_) => AppearanceEditor(
        settings: const {'locale': 'en'},
        onPreview: (_) {},
        onSave: (_) => save.future,
        onCancel: () {},
        chooseWallpaper: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-save')));
    await tester.pump();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceEditor), findsOneWidget);
    save.complete(true);
    await tester.pumpAndSettle();
    await dialog;
    expect(find.byType(AppearanceEditor), findsNothing);
  });

  testWidgets('appearance previews immediately and cancel never saves', (
    tester,
  ) async {
    Map<String, dynamic>? preview, saved;
    int cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppearanceEditor(
            settings: const {'dark': false, 'volume': 70},
            onPreview: (v) => preview = v,
            onSave: (v) async {
              saved = v;
              return true;
            },
            onCancel: () {
              cancelled++;
            },
            chooseWallpaper: () async => null,
          ),
        ),
      ),
    );
    final slider = find.byKey(const Key('appearance-glassOpacity'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(-80, 0));
    await tester.pump();
    expect(preview, isNotNull);
    expect(preview!['appearanceLight']['glassOpacity'], lessThan(.84));
    await tester.tap(find.byKey(const Key('appearance-cancel')));
    await tester.pump();
    expect(cancelled, 1);
    expect(saved, isNull);
  });
}
