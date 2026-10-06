import 'dart:convert';

import 'layout_preferences.dart';

// Only these keys may enter a theme profile or an imported preset.
class AppearanceProfile {
  final Map<String, dynamic> _data;
  final bool dark;
  AppearanceProfile.fromMap(Map<String, dynamic> data, {this.dark = false})
    : _data = Map.of(data);
  double number(String key, double fallback, double min, double max) {
    final value = _data[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  bool flag(String key, bool fallback) =>
      _data[key] is bool ? _data[key] as bool : fallback;
  int color(String key, int fallback) =>
      _data[key] is int &&
          (_data[key] as int) >= 0 &&
          (_data[key] as int) <= 0xffffffff
      ? _data[key] as int
      : fallback;
  int get background => color('background', dark ? 0xff101112 : 0xfff4f4f4);
  int get accent => color('accent', 0xff777777);
  double get windowOpacity => number('windowOpacity', 1, .25, 1);
  double get glassOpacity => number('glassOpacity', .84, 0, 1);
  double get blur => number('blur', 10, 0, 30);
  double get radius => number('radius', 22, 0, 36);
  double get textScale => number('textScale', 1, .8, 1.5);
  double get glassBorder => number('glassBorder', .15, 0, 1);
  int get glassColor => color('glassColor', dark ? 0xff252627 : 0xffffffff);
  String? get wallpaper =>
      _data['wallpaper'] is String ? _data['wallpaper'] as String : null;
  bool get wallpaperFill => flag('wallpaperFill', true);
  double get wallpaperOpacity => number('wallpaperOpacity', 1, 0, 1);
  double get wallpaperDim => number('wallpaperDim', .3, 0, 1);
  double get wallpaperBlur => number('wallpaperBlur', 0, 0, 30);
  bool get backgroundVisualizer => flag('backgroundVisualizer', false);
  bool get backgroundFull => flag('backgroundFull', false);
  double get backgroundHeight => number('backgroundHeight', .4, .1, 1);
  double get backgroundOpacity => number('backgroundOpacity', .15, 0, 1);
  double get backgroundSensitivity => number('backgroundSensitivity', 1, .2, 3);
  double get backgroundSmoothness => number('backgroundSmoothness', .5, 0, 1);
  int get backgroundColor =>
      color('backgroundColor', dark ? 0xffffffff : 0xff000000);
  String get density =>
      ['compact', 'normal', 'comfortable'].contains(_data['density'])
      ? _data['density'] as String
      : 'normal';
  AppearanceProfile surface(String identity) {
    final override = _data['${identity}Override'];
    return override is Map && override['enabled'] == true
        ? AppearanceProfile.fromMap({
            ...toMap(),
            ...Map<String, dynamic>.from(override),
          }, dark: dark)
        : this;
  }

  Map<String, dynamic> toMap() => {
    'background': background,
    'accent': accent,
    'windowOpacity': windowOpacity,
    'glassOpacity': glassOpacity,
    'glassColor': glassColor,
    'glassBorder': glassBorder,
    'blur': blur,
    'radius': radius,
    'textScale': textScale,
    'density': density,
    'wallpaper': wallpaper,
    'wallpaperFill': wallpaperFill,
    'wallpaperOpacity': wallpaperOpacity,
    'wallpaperDim': wallpaperDim,
    'wallpaperBlur': wallpaperBlur,
    'backgroundVisualizer': backgroundVisualizer,
    'backgroundFull': backgroundFull,
    'backgroundHeight': backgroundHeight,
    'backgroundOpacity': backgroundOpacity,
    'backgroundSensitivity': backgroundSensitivity,
    'backgroundSmoothness': backgroundSmoothness,
    'backgroundColor': backgroundColor,
    for (final id in ['sidebar', 'player', 'menu'])
      if (_data['${id}Override'] is Map)
        '${id}Override': _validatedOverride(_data['${id}Override']),
  };
  Map<String, dynamic> _validatedOverride(Map values) {
    final p = AppearanceProfile.fromMap(
      Map<String, dynamic>.from(values),
      dark: dark,
    );
    return {
      'enabled': values['enabled'] == true,
      'glassColor': p.glassColor,
      'glassOpacity': p.glassOpacity,
      'glassBorder': p.glassBorder,
      'blur': p.blur,
      'radius': p.radius,
    };
  }
}

class AppearanceDraft {
  final Map<String, dynamic> _settings;
  AppearanceDraft(Map<String, dynamic> settings)
    : _settings = jsonDecode(jsonEncode(settings)) as Map<String, dynamic>;
  Map<String, dynamic> get settings =>
      jsonDecode(jsonEncode(_settings)) as Map<String, dynamic>;
  AppearanceProfile profile(bool dark) {
    final value = _settings[dark ? 'appearanceDark' : 'appearanceLight'];
    return AppearanceProfile.fromMap(
      value is Map
          ? Map<String, dynamic>.from(value)
          : {'accent': _settings['accent'] ?? 0xff777777},
      dark: dark,
    );
  }

  void update(bool dark, String key, Object? value) {
    final profileMap = profile(dark).toMap();
    profileMap[key] = value;
    _settings[dark ? 'appearanceDark' : 'appearanceLight'] =
        AppearanceProfile.fromMap(profileMap, dark: dark).toMap();
  }

  void copyTheme({required bool fromDark}) {
    _settings[fromDark ? 'appearanceLight' : 'appearanceDark'] = profile(
      fromDark,
    ).toMap();
  }

  void replace(bool dark, Map<String, dynamic> values) {
    _settings[dark ? 'appearanceDark' : 'appearanceLight'] =
        AppearanceProfile.fromMap(values, dark: dark).toMap();
  }
}

class AppearancePreset {
  final String name, scope;
  final Map<String, dynamic> light, dark, layout;
  AppearancePreset({
    required this.name,
    required this.scope,
    required this.light,
    required this.dark,
    required this.layout,
  });
  Map<String, dynamic> toMap() => {
    'schema': 1,
    'name': name,
    'scope': scope,
    'light': light,
    'dark': dark,
    'layout': layout,
  };
  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());
  factory AppearancePreset.fromJson(String source) {
    try {
      final data = jsonDecode(source);
      if (data is! Map ||
          data['schema'] != 1 ||
          data['name'] is! String ||
          !(data['name'] as String).trim().isNotEmpty ||
          !['appearance', 'layout', 'both'].contains(data['scope'])) {
        throw const FormatException('Invalid preset');
      }
      Map<String, dynamic> profile(String key, bool dark) {
        final raw = data[key];
        if (raw is! Map) throw const FormatException('Invalid theme');
        final value = AppearanceProfile.fromMap(
          Map<String, dynamic>.from(raw),
          dark: dark,
        ).toMap();
        value.remove('wallpaper');
        return value;
      }

      return AppearancePreset(
        name: (data['name'] as String).trim(),
        scope: data['scope'],
        light: profile('light', false),
        dark: profile('dark', true),
        layout: LayoutPreferences.fromMap(
          data['layout'] is Map
              ? Map<String, dynamic>.from(data['layout'])
              : {},
        ).toMap(),
      );
    } catch (_) {
      throw const FormatException('Invalid Takt preset');
    }
  }
}

// Audio analysis is required if either independently configured visualizer is visible.
bool visualizationDemand(Map<String, dynamic> settings) =>
    settings['visualizerEnabled'] != false ||
    AppearanceDraft(settings)
        .profile(settings['dark'] == true)
        .backgroundVisualizer;
