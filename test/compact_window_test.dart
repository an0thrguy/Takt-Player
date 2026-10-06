import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/platform/compact_window.dart';

class FakeWindow implements CompactWindow {
  Size size = const Size(1000, 700), minimum = const Size(620, 520);
  Offset position = const Offset(40, 50);
  bool top = false, fail = false, maximized = false;
  @override
  Future<bool> isMaximized() async => maximized;
  @override
  Future<void> maximize() async {
    maximized = true;
  }

  @override
  Future<void> unmaximize() async {
    maximized = false;
  }

  @override
  Future<Size> getSize() async => size;
  @override
  Future<Offset> getPosition() async => position;
  @override
  Future<bool> isAlwaysOnTop() async => top;
  @override
  Future<void> setSize(Size value) async {
    if (fail && value.width == 420) throw StateError('resize');
    size = value;
  }

  @override
  Future<void> setPosition(Offset value) async {
    position = value;
  }

  @override
  Future<void> setMinimumSize(Size value) async {
    minimum = value;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    top = value;
  }
}

class DelayedWindow extends FakeWindow {
  final gate = Completer<void>();
  int concurrent = 0, maximum = 0;
  @override
  Future<void> setSize(Size value) async {
    concurrent++;
    if (concurrent > maximum) maximum = concurrent;
    await gate.future;
    await Future<void>.delayed(Duration.zero);
    await super.setSize(value);
    concurrent--;
  }
}

void main() {
  test(
    'maximized main window becomes compact and restores maximized state',
    () async {
      final w = FakeWindow()..maximized = true;
      final c = CompactWindowController(w);
      await c.change(true, false);
      expect(w.maximized, false);
      await c.change(false, false);
      expect(w.maximized, true);
    },
  );
  test(
    'three queued transitions never overlap platform resize calls',
    () async {
      final w = DelayedWindow();
      final c = CompactWindowController(w);
      final a = c.change(true, false);
      await Future<void>.delayed(Duration.zero);
      final b = c.change(false, false);
      final d = c.change(false, false);
      w.gate.complete();
      await Future.wait([a, b, d]);
      expect(w.maximum, 1);
      expect(w.size, const Size(1000, 700));
    },
  );

  test(
    'compact remembers main geometry and pin state across pin changes',
    () async {
      final w = FakeWindow();
      final c = CompactWindowController(w);
      await c.change(true, true);
      expect(w.size, const Size(420, 240));
      await c.change(true, false);
      await c.change(false, false);
      expect(w.size, const Size(1000, 700));
      expect(w.position, const Offset(40, 50));
      expect(w.top, false);
      expect(w.minimum, const Size(620, 520));
    },
  );
  test('failed compact transition restores usable main window', () async {
    final w = FakeWindow()..fail = true;
    final c = CompactWindowController(w);
    await expectLater(c.change(true, true), throwsStateError);
    expect(w.minimum, const Size(620, 520));
    expect(w.size, const Size(1000, 700));
    expect(c.compact, false);
  });
}
