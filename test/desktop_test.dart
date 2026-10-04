// Regression checks for desktop; use independent local fixtures and mocked boundaries where appropriate.
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';
import 'package:takt/platform/desktop.dart';

class TestWindow implements DesktopWindow {
  bool hidden = false;
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
    await desktop.toggleVisibility();
    expect(window.hidden, isFalse);
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
