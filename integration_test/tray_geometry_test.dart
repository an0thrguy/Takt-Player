import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:takt/platform/desktop.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Hyprland float geometry survives unmapping', (tester) async {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('Takt');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Tray geometry test'))),
    );
    await tester.runAsync(() async {
      Future<Map<String, dynamic>> client() async {
        final result = await Process.run('hyprctl', ['-j', 'clients']);
        final clients = jsonDecode(result.stdout as String) as List;
        return Map<String, dynamic>.from(
          clients.firstWhere((c) => c['pid'] == pid && c['title'] == 'Takt')
              as Map,
        );
      }

      await windowManager.show();
      final initial = await client();
      final address = 'address:${initial['address']}';
      for (final args in [
        ["hl.dsp.window.float({window='$address',action='on'})"],
        ["hl.dsp.window.resize({window='$address',x=900,y=650,relative=false})"],
        ["hl.dsp.window.move({window='$address',x=120,y=100,relative=false})"],
      ]) {
        final result = await Process.run('hyprctl', ['dispatch', ...args]);
        expect(result.exitCode, 0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final before = await client();
      final window = NativeDesktopWindow();
      await window.hide();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await window.show();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final after = await client();
      expect(after['floating'], true);
      expect(after['size'], before['size']);
      expect(after['at'], before['at']);
      await File('/tmp/takt-tray-geometry.json')
          .writeAsString(jsonEncode({'before': before, 'after': after}));
    });
  });
}
