import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/playback/sleep_timer.dart';
import 'package:takt/ui/sleep_timer_dialog.dart';

void main() {
  testWidgets('sleep timer fits a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final timer = SleepTimer(
      pause: () async {},
      quit: () async {},
      setVolume: (_) async {},
      getVolume: () => 100,
    );
    addTearDown(timer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SleepTimerDialog(timer: timer, english: false, dark: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2));
    final first = tester.getRect(switches.at(0));
    final second = tester.getRect(switches.at(1));
    expect(first.bottom, lessThanOrEqualTo(second.top));
    expect(find.byKey(const Key('sleep-start')), findsOneWidget);
  });
}
