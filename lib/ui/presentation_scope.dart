import 'package:flutter/widgets.dart';

import 'presentation_preferences.dart';
import 'appearance.dart';

class PresentationScope extends InheritedWidget {
  final PresentationPreferences preferences;
  final AppearanceProfile? appearance;
  const PresentationScope({
    super.key,
    required this.preferences,
    this.appearance,
    required super.child,
  });
  static PresentationPreferences of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PresentationScope>()
          ?.preferences ??
      PresentationPreferences.fromMap({});
  static AppearanceProfile? appearanceOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PresentationScope>()
      ?.appearance;
  @override
  bool updateShouldNotify(PresentationScope oldWidget) =>
      preferences != oldWidget.preferences ||
      appearance != oldWidget.appearance;
}
