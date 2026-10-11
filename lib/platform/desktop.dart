import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../core/store.dart';

// Window boundary for tests: hide/show without requiring an actual desktop session.
abstract class DesktopWindow {
  Future<ui.Size> getSize();
  Future<ui.Offset> getPosition();
  Future<void> setSize(ui.Size size);
  Future<void> setPosition(ui.Offset position);
  Future<void> hide();
  Future<void> show();
}

class NativeDesktopWindow implements DesktopWindow {
  Map<String, dynamic>? _hyprGeometry;
  Future<Map<String, dynamic>?> _hyprClient() async {
    if (Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'] == null) {
      return null;
    }
    try {
      final result = await Process.run('hyprctl', ['-j', 'clients']);
      if (result.exitCode != 0) return null;
      for (final client in jsonDecode(result.stdout as String) as List) {
        if (client['pid'] == pid && client['title'] == 'Takt') {
          return Map<String, dynamic>.from(client as Map);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _restoreHyprGeometry() async {
    final saved = _hyprGeometry;
    if (saved == null || saved['floating'] != true) return;
    Map<String, dynamic>? client;
    for (var attempt = 0; attempt < 20; attempt++) {
      client = await _hyprClient();
      if (client != null && client['mapped'] == true) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (client == null) return;
    final target = 'address:${client['address']}';
    final size = saved['size'] as List;
    final at = saved['at'] as List;
    // Remapping creates a new compositor client. Restore its float state first.
    final lua = [
      "hl.dsp.window.float({window='$target',action='on'})",
      "hl.dsp.window.resize({window='$target',x=${size[0]},y=${size[1]},relative=false})",
      "hl.dsp.window.move({window='$target',x=${at[0]},y=${at[1]},relative=false})",
    ];
    var index = 0;
    for (final command in [
      ['setfloating', target],
      ['resizewindowpixel', 'exact ${size[0]} ${size[1]},$target'],
      ['movewindowpixel', 'exact ${at[0]} ${at[1]},$target'],
    ]) {
      final result = await Process.run('hyprctl', ['dispatch', ...command]);
      if (result.exitCode != 0) {
        final fallback = await Process.run('hyprctl', ['dispatch', lua[index]]);
        if (fallback.exitCode != 0) {
          throw StateError('Could not restore Takt window: ${fallback.stderr}');
        }
      }
      index++;
    }
  }

  @override
  Future<ui.Size> getSize() => windowManager.getSize();
  @override
  Future<ui.Offset> getPosition() => windowManager.getPosition();
  @override
  Future<void> setSize(ui.Size size) => windowManager.setSize(size);
  @override
  Future<void> setPosition(ui.Offset position) =>
      windowManager.setPosition(position);
  @override
  Future<void> hide() async {
    _hyprGeometry = await _hyprClient();
    await windowManager.hide();
  }

  @override
  Future<void> show() async {
    await windowManager.show();
    await _restoreHyprGeometry();
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
  ui.Size? _visibleSize;
  ui.Offset? _visiblePosition;
  void _visibility(bool value) {
    visible = value;
    onVisibility?.call(value);
    refreshLanguage();
  }

  Future<void> show() async {
    await window.show();
    if (_visibleSize != null) await window.setSize(_visibleSize!);
    if (_visiblePosition != null) await window.setPosition(_visiblePosition!);
    _visibility(true);
  }

  Future<void> _rememberGeometry() async {
    _visibleSize = await window.getSize();
    _visiblePosition = await window.getPosition();
  }

  Future<void> toggleVisibility() async {
    if (visible) {
      await _rememberGeometry();
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
      await _rememberGeometry();
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
