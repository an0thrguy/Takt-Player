// Layout validation keeps controls usable even for malformed imported presets.
class LayoutPreferences {
  static const sidebarIds = [
    'all',
    'favorites',
    'folders',
    'recent',
    'added',
    'albums',
    'artists',
    'new',
  ];
  static const controlIds = [
    'mode',
    'previous',
    'play',
    'next',
    'volume',
    'favorite',
    'timer',
    'visualizer',
    'compact',
  ];
  final List<String> sidebarOrder, controlsOrder, hiddenSidebar, hiddenControls;
  final double sidebarWidth, playerHeight;
  LayoutPreferences._(
    this.sidebarOrder,
    this.controlsOrder,
    this.hiddenSidebar,
    this.hiddenControls,
    this.sidebarWidth,
    this.playerHeight,
  );
  factory LayoutPreferences.fromMap(Map<String, dynamic> map) {
    List<String> order(String key, List<String> allowed) {
      final raw = map[key];
      final values = raw is List
          ? raw.whereType<String>().where(allowed.contains).toSet().toList()
          : <String>[];
      return [...values, ...allowed.where((id) => !values.contains(id))];
    }

    List<String> hidden(
      String key,
      List<String> allowed,
      List<String> fallback,
    ) {
      final raw = map[key];
      return raw is List
          ? raw
                .whereType<String>()
                .where((id) => allowed.contains(id) && id != 'play')
                .toSet()
                .toList()
          : List.of(fallback);
    }

    double number(String key, double fallback, double min, double max) {
      final v = map[key];
      return v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;
    }

    return LayoutPreferences._(
      order('sidebarOrder', sidebarIds),
      order('controlsOrder', controlIds),
      hidden('hiddenSidebar', sidebarIds, []),
      hidden('hiddenControls', controlIds, [
        'favorite',
        'timer',
        'visualizer',
        'compact',
      ]),
      number('sidebarWidth', 178, 150, 320),
      number('playerHeight', 180, 160, 280),
    );
  }
  List<String> get visibleSidebar =>
      sidebarOrder.where((id) => !hiddenSidebar.contains(id)).toList();
  List<String> get visibleControls =>
      controlsOrder.where((id) => !hiddenControls.contains(id)).toList();
  Map<String, dynamic> toMap() => {
    'sidebarOrder': sidebarOrder,
    'controlsOrder': controlsOrder,
    'hiddenSidebar': hiddenSidebar,
    'hiddenControls': hiddenControls,
    'sidebarWidth': sidebarWidth,
    'playerHeight': playerHeight,
  };
}
