// Regression checks for desktop; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/platform/desktop.dart';

class TestWindow implements DesktopWindow {
  bool hidden = false;
  Size size = const Size(960, 680);
  Offset position = const Offset(32, 48);
  final restoredSizes = <Size>[];
  final restoredPositions = <Offset>[];

  @override
  Future<Size> getSize() async => size;

  @override
  Future<Offset> getPosition() async => position;

  @override
  Future<void> setSize(Size value) async {
    size = value;
    restoredSizes.add(value);
  }

  @override
  Future<void> setPosition(Offset value) async {
    position = value;
    restoredPositions.add(value);
  }

  @override
  Future<void> hide() async {
    hidden = true;
  }

  @override
  Future<void> show() async {
    hidden = false;
  }
}

void main() {
  test('tray visibility toggles window without changing playback', () async {
    final store = TaktStore.memory(), window = TestWindow();
    addTearDown(store.close);
    final visibility = <bool>[];
    final desktop = DesktopLifecycle(
      store,
      () async {},
      () async {},
      window: window,
      onVisibility: visibility.add,
    );
    await desktop.toggleVisibility();
    expect(window.hidden, isTrue);
    expect(desktop.visible, isFalse);
    window
      ..size = const Size(640, 520)
      ..position = Offset.zero;
    await desktop.toggleVisibility();
    expect(window.hidden, isFalse);
    expect(window.size, const Size(960, 680));
    expect(window.position, const Offset(32, 48));
    expect(visibility, [false, true]);
  });
  test(
    'close hides only with accessible tray and never pauses music',
    () async {
      final store = TaktStore.memory(), window = TestWindow();
      addTearDown(store.close);
      var quit = 0, pauses = 0, host = true;
      final desktop = DesktopLifecycle(
        store,
        () async {
          quit++;
        },
        () async {
          pauses++;
        },
        window: window,
        trayAvailable: () async => host,
      );
      await desktop.close();
      expect(window.hidden, isTrue);
      window
        ..size = const Size(700, 540)
        ..position = Offset.zero;
      await desktop.show();
      expect(window.size, const Size(960, 680));
      expect(window.position, const Offset(32, 48));
      expect(pauses, 0);
      expect(quit, 0);
      host = false;
      await desktop.close();
      expect(window.hidden, isFalse);
      expect(quit, 0);
      store.write('settings', {'closeToTray': false});
      await desktop.close();
      expect(quit, 1);
    },
  );
}
