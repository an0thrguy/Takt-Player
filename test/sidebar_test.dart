import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/resizable_sidebar.dart';

void main() {
  testWidgets(
    'sidebar persists only completed drag and narrow mode keeps preference',
    (tester) async {
      double saved = 178;
      bool collapsed = false;
      double available = 800;
      int writes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (c, set) {
                update = set;
                return Row(
                  children: [
                    ResizableSidebar(
                      preferredWidth: saved,
                      collapsed: collapsed,
                      availableWidth: available,
                      onResizeEnd: (v) {
                        writes++;
                        update(() => saved = v);
                      },
                      onCollapsedChanged: (v) => update(() => collapsed = v),
                      child: const Text('nav'),
                    ),
                    const Expanded(child: Text('content')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final handle = find.byKey(const Key('sidebar-resize'));
      expect(
        find.descendant(
          of: handle,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.constraints?.maxWidth == 1,
          ),
        ),
        findsNothing,
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(62, 0));
      await tester.pump();
      expect(writes, 0);
      await gesture.up();
      await tester.pump();
      expect(saved, 240);
      update(() => available = 440);
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('sidebar-panel'))).width, 62);
      expect(saved, 240);
      update(() => available = 800);
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('sidebar-panel'))).width, 240);
    },
  );
}
