// Validated presentation values; unknown saved keys never alter library data.
class PresentationPreferences {
  final Map<String, dynamic> _data;
  PresentationPreferences.fromMap(Map<String, dynamic> data)
    : _data = Map.of(data);
  bool flag(String key, bool fallback) =>
      _data[key] is bool ? _data[key] as bool : fallback;
  String choice(String key, List<String> choices, String fallback) =>
      choices.contains(_data[key]) ? _data[key] as String : fallback;
  double number(String key, double fallback, double min, double max) {
    final value = _data[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  String get performanceMode =>
      choice('performanceMode', ['quality', 'balanced', 'economy'], 'balanced');
  double get blurSigma =>
      {'quality': 18.0, 'balanced': 10.0, 'economy': 0.0}[performanceMode]!;
  int get visualizerHz =>
      {'quality': 60, 'balanced': 30, 'economy': 15}[performanceMode]!;
  Duration get transitionDuration => flag('animationsEnabled', true)
      ? Duration(
          milliseconds: {
            'fast': 120,
            'normal': 220,
            'smooth': 320,
          }[choice('animationSpeed', ['fast', 'normal', 'smooth'], 'normal')]!,
        )
      : Duration.zero;
  bool get volumeWheel => flag('volumeWheel', true);
  bool get volumeInline => flag('volumeInline', false);
  bool get closeOnHover => flag('closeOnHover', false);
  double get sidebarWidth => number('sidebarWidth', 178, 150, 320);
  bool get sidebarCollapsed => flag('sidebarCollapsed', false);
}
