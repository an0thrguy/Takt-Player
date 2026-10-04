import 'dart:io';
import 'dart:ui' as ui;

import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../core/store.dart';

// Window boundary for tests: hide/show without requiring an actual desktop session.
abstract class DesktopWindow {
  Future<void> hide();
  Future<void> show();
}

class NativeDesktopWindow implements DesktopWindow {
  @override
  Future<void> hide() => windowManager.hide();
  @override
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }
}

// Linux window and tray lifecycle. Full exit invokes quit; normal close respects closeToTray.
class DesktopLifecycle with WindowListener {
  final void Function(bool)? onVisibility;
  final DesktopWindow window;
  final Future<bool> Function()? trayAvailable;
  final TaktStore store;
  final Future<void> Function() quit;
  final Future<void> Function() toggle;
  final Future<void> Function()? next;
  final Future<void> Function()? previous;
  bool visible = true;
  void _visibility(bool value) {
    visible = value;
    onVisibility?.call(value);
    refreshLanguage();
  }

  Future<void> show() async {
    await window.show();
    _visibility(true);
  }

  Future<void> toggleVisibility() async {
    if (visible) {
      await window.hide();
      _visibility(false);
    } else {
      await show();
    }
  }

  tray.TrayIcon? icon;
  tray.Menu? menu;
  final entries = <tray.MenuItem>[];
  // Translate the existing tray menu after the user changes the app language.
  void refreshLanguage() {
    final english = (store.read('settings') as Map?)?['locale'] == 'en';
    final labels = english
        ? [
            visible ? 'Hide Takt' : 'Show Takt',
            'Previous track',
            'Play / Pause',
            'Next track',
            'Quit',
          ]
        : [
            visible ? 'Спрятать Takt' : 'Показать Takt',
            'Предыдущий трек',
            'Пуск / Пауза',
            'Следующий трек',
            'Выход',
          ];
    for (var i = 0; i < entries.length; i++) {
      entries[i].label = labels[i];
    }
  }

  DesktopLifecycle(
    this.store,
    this.quit,
    this.toggle, {
    this.onVisibility,
    this.next,
    this.previous,
    DesktopWindow? window,
    this.trayAvailable,
  }) : window = window ?? NativeDesktopWindow();
  // Create the tray icon and menu; tray failures must not make the application inaccessible.
  Future<void> initialize(String directory) async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      // Generate the icon locally as PNG; change its shape and colors here.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawCircle(
        const ui.Offset(32, 32),
        29,
        ui.Paint()..color = const ui.Color(0xffeeeeee),
      );
      final p = ui.Paint()
        ..color = const ui.Color(0xff202020)
        ..strokeWidth = 5;
      canvas.drawLine(const ui.Offset(28, 18), const ui.Offset(28, 43), p);
      canvas.drawLine(const ui.Offset(28, 18), const ui.Offset(44, 22), p);
      canvas.drawOval(const ui.Rect.fromLTWH(15, 37, 16, 11), p);
      final image = await recorder.endRecording().toImage(64, 64),
          bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = await File('$directory/tray.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      icon = tray.TrayIcon.create();
      if (icon == null) return;
      icon!.icon = tray.Image.fromFile(file.path);
      icon!.setTooltip('Takt');
      icon!.setTitle('Takt');
      menu = tray.Menu.create();
      for (final item in [
        ('Показать Takt', toggleVisibility),
        ('Предыдущий трек', previous ?? () async {}),
        ('Пуск / Пауза', toggle),
        ('Следующий трек', next ?? () async {}),
        ('Выход', quit),
      ]) {
        final entry = tray.MenuItem.createWithLabelAndType(
          item.$1,
          tray.MenuItemType.normal,
        );
        entry?.addListener((event) {
          if (event is tray.MenuItemClickedEvent) item.$2();
        });
        menu?.addItem(entry);
        if (entry != null) entries.add(entry);
      }
      icon!.addListener((event) {
        if (event is tray.TrayIconClickedEvent ||
            event is tray.TrayIconDoubleClickedEvent) {
          show();
        }
      });
      refreshLanguage();
      icon!.setContextMenu(menu);
      icon!.setVisible(true);
    } catch (_) {
      icon = null;
    }
  }

  Future<bool> _trayAvailable() async => icon != null && await hasHost();
  // Check the actual StatusNotifierHost; creating an icon alone does not prove a tray is available.
  Future<bool> hasHost() async {
    try {
      final result = await Process.run('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.kde.StatusNotifierWatcher',
        '--object-path',
        '/StatusNotifierWatcher',
        '--method',
        'org.freedesktop.DBus.Properties.Get',
        'org.kde.StatusNotifierWatcher',
        'IsStatusNotifierHostRegistered',
      ]).timeout(const Duration(seconds: 2));
      return result.exitCode == 0 && result.stdout.toString().contains('true');
    } catch (_) {
      return false;
    }
  }

  @override
  void onWindowClose() {
    close();
  }

  // Hide only with an accessible tray host; otherwise keep the window available.
  Future<void> close() async {
    if ((store.read('settings') as Map?)?['closeToTray'] == false) {
      await quit();
      return;
    }
    if (await (trayAvailable?.call() ?? _trayAvailable())) {
      await window.hide();
      _visibility(false);
    } else {
      await show();
    }
  }

  @override
  void onWindowMinimize() {
    _visibility(false);
  }

  @override
  void onWindowRestore() {
    _visibility(true);
  }

  @override
  void onWindowFocus() {
    _visibility(true);
  }

  void dispose() {
    windowManager.removeListener(this);
    icon?.dispose();
    menu?.dispose();
  }
}
