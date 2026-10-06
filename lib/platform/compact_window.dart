import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// This boundary changes one existing window; audio and queue are never recreated.
abstract class CompactWindow {
  Future<Size> getSize();
  Future<Offset> getPosition();
  Future<bool> isAlwaysOnTop();
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> setSize(Size size);
  Future<void> setPosition(Offset position);
  Future<void> setMinimumSize(Size size);
  Future<void> setAlwaysOnTop(bool value);
}

class DesktopCompactWindow implements CompactWindow {
  @override
  Future<bool> isMaximized() => windowManager.isMaximized();
  @override
  Future<void> maximize() => windowManager.maximize();
  @override
  Future<void> unmaximize() => windowManager.unmaximize();
  @override
  Future<Size> getSize() => windowManager.getSize();
  @override
  Future<Offset> getPosition() => windowManager.getPosition();
  @override
  Future<bool> isAlwaysOnTop() => windowManager.isAlwaysOnTop();
  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);
  @override
  Future<void> setPosition(Offset position) =>
      windowManager.setPosition(position);
  @override
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);
  @override
  Future<void> setAlwaysOnTop(bool value) =>
      windowManager.setAlwaysOnTop(value);
}

class CompactWindowController {
  final CompactWindow window;
  CompactWindowController(this.window);
  Size? _size;
  Offset? _position;
  bool _top = false, _maximized = false;
  bool compact = false;
  Future<void> _pending = Future.value();
  Future<void> change(bool value, bool alwaysOnTop) {
    // Each caller receives its own result while the next call waits even after failure.
    final operation = _pending.then((_) => _change(value, alwaysOnTop));
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _change(bool value, bool alwaysOnTop) async {
    if (value && compact) {
      await window.setAlwaysOnTop(alwaysOnTop);
      return;
    }
    if (value) {
      _size = await window.getSize();
      _position = await window.getPosition();
      _top = await window.isAlwaysOnTop();
      _maximized = await window.isMaximized();
      try {
        if (_maximized) await window.unmaximize();
        await window.setMinimumSize(const Size(320, 200));
        await window.setSize(const Size(420, 240));
        await window.setAlwaysOnTop(alwaysOnTop);
        compact = true;
      } catch (_) {
        await _restore();
        rethrow;
      }
    } else if (compact) {
      await _restore();
      compact = false;
    }
  }

  Future<void> _restore() async {
    // A failed platform call must not prevent the remaining restoration attempts.
    Object? error;
    StackTrace? stack;
    for (final action in <Future<void> Function()>[
      () => window.setMinimumSize(const Size(620, 520)),
      () => window.setSize(_size ?? const Size(1080, 760)),
      () => window.setPosition(_position ?? Offset.zero),
      () => window.setAlwaysOnTop(_top),
      if (_maximized) () => window.maximize(),
    ]) {
      try {
        await action();
      } catch (e, s) {
        error ??= e;
        stack ??= s;
      }
    }
    if (error != null) Error.throwWithStackTrace(error, stack!);
  }
}
