import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/glass.dart';

void main() {
  testWidgets('global button hover and focus use a rounded shape', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final style = harmoniousIconButtonStyle(context);
    final shape = style.shape?.resolve({WidgetState.hovered});
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(14),
    );
  });
}
