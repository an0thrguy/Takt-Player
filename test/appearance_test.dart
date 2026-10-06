import 'package:flutter_test/flutter_test.dart';
import 'package:takt/ui/appearance.dart';

void main() {
  test(
    'background spectrum demand is independent of foreground visualizer',
    () {
      expect(
        visualizationDemand({
          'visualizerEnabled': false,
          'appearanceLight': {'backgroundVisualizer': true},
        }),
        true,
      );
      expect(visualizationDemand({'visualizerEnabled': false}), false);
    },
  );

  test('appearance validates input and keeps independent theme drafts', () {
    final p = AppearanceProfile.fromMap({
      'windowOpacity': 0,
      'glassOpacity': 2,
      'blur': double.nan,
      'radius': 99,
      'textScale': 10,
    });
    expect(p.windowOpacity, .25);
    expect(p.glassOpacity, 1);
    expect(p.blur, 10);
    expect(p.radius, 36);
    expect(p.textScale, 1.5);
    final data = <String, dynamic>{
      'volume': 77,
      'appearanceLight': {'background': 0xffabcdef},
      'appearanceDark': {'background': 0xff111111},
    };
    final draft = AppearanceDraft(data);
    draft.update(false, 'background', 0xff222222);
    expect(draft.profile(false).background, 0xff222222);
    expect(data['appearanceLight']['background'], 0xffabcdef);
    draft.copyTheme(fromDark: false);
    expect(draft.profile(true).background, 0xff222222);
    final saved = draft.settings;
    expect(saved['volume'], 77);
    expect(saved['appearanceDark']['background'], 0xff222222);
    expect(data['appearanceDark']['background'], 0xff111111);
  });
  test('preset roundtrip rejects unsafe imports and leaves unrelated data', () {
    final preset = AppearancePreset(
      name: 'Soft',
      scope: 'appearance',
      light: AppearanceProfile.fromMap({'wallpaper': '/local/picture.png'})
          .toMap(),
      dark: {},
      layout: {},
    );
    final imported = AppearancePreset.fromJson(preset.toJson());
    expect(imported.name, 'Soft');
    expect(imported.light['wallpaper'], isNull);
    expect(
      () => AppearancePreset.fromJson('{"schema":99}'),
      throwsFormatException,
    );
  });
}
