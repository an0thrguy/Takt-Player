import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/presentation_preferences.dart';

void main() {
  test(
    'profiles and animations have validated defaults without mutating data',
    () {
      final data = <String, dynamic>{'volume': 73, 'dark': true};
      final p = PresentationPreferences.fromMap(data);
      expect(
        [p.blurSigma, p.visualizerHz, p.transitionDuration.inMilliseconds],
        [10, 30, 220],
      );
      expect(data, {'volume': 73, 'dark': true});
      for (final entry in {
        'quality': [18, 60],
        'economy': [0, 15],
      }.entries) {
        final profile = PresentationPreferences.fromMap({
          'performanceMode': entry.key,
        });
        expect([profile.blurSigma, profile.visualizerHz], entry.value);
      }
      expect(
        PresentationPreferences.fromMap({'animationSpeed': 'fast'})
            .transitionDuration
            .inMilliseconds,
        120,
      );
      expect(
        PresentationPreferences.fromMap({'animationSpeed': 'smooth'})
            .transitionDuration
            .inMilliseconds,
        320,
      );
      expect(
        PresentationPreferences.fromMap({'animationsEnabled': false})
            .transitionDuration,
        Duration.zero,
      );
    },
  );
  test('invalid persisted preferences are safe and widths are constrained', () {
    for (final width in [double.nan, double.infinity, 'bad', null]) {
      expect(
        PresentationPreferences.fromMap({'sidebarWidth': width}).sidebarWidth,
        178,
      );
    }
    expect(
      PresentationPreferences.fromMap({'sidebarWidth': 999}).sidebarWidth,
      320,
    );
    expect(
      PresentationPreferences.fromMap({'sidebarWidth': 1}).sidebarWidth,
      150,
    );
    final p = PresentationPreferences.fromMap({
      'performanceMode': 9,
      'animationSpeed': {},
      'volumeWheel': 'no',
    });
    expect(p.blurSigma, 10);
    expect(p.transitionDuration.inMilliseconds, 220);
    expect(p.volumeWheel, true);
    expect(p.volumeInline, false);
  });
}
