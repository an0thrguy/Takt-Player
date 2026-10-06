import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/layout_preferences.dart';

void main() {
  test('layout validates zones and always retains play access', () {
    final layout = LayoutPreferences.fromMap({
      'sidebarOrder': ['artists', 'artists', 'unsafe'],
      'controlsOrder': ['next', 'next'],
      'hiddenControls': ['play', 'volume', 'unsafe'],
      'sidebarWidth': 999,
    });
    expect(layout.sidebarOrder.first, 'artists');
    expect(layout.sidebarOrder.toSet().length, layout.sidebarOrder.length);
    expect(layout.sidebarOrder, isNot(contains('unsafe')));
    expect(layout.controlsOrder, contains('play'));
    expect(layout.visibleControls, contains('play'));
    expect(layout.visibleControls, isNot(contains('volume')));
    expect(layout.sidebarWidth, 320);
    final copy = LayoutPreferences.fromMap(layout.toMap());
    expect(copy.toMap(), layout.toMap());
  });
}
