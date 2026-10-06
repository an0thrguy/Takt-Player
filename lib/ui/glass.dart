import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'presentation_scope.dart';

const interfaceDuration = Duration(milliseconds: 220);

// Shared easing keeps navigation and popup motion visually consistent.
Widget animatedPage(Widget child) => Builder(
  builder: (context) => AnimatedSwitcher(
    duration: PresentationScope.of(context).transitionDuration,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, outgoing) => Stack(
      alignment: Alignment.center,
      children: [
        for (final page in outgoing)
          IgnorePointer(child: ExcludeSemantics(child: page)),
        ?current,
      ],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.025, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  ),
);

Future<T?> showTaktDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black.withValues(alpha: .35),
  transitionDuration: PresentationScope.of(context).transitionDuration,
  pageBuilder: (c, _, _) => builder(c),
  transitionBuilder: (c, animation, _, child) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: ScaleTransition(
        scale: Tween(begin: .96, end: 1.0).animate(eased),
        child: child,
      ),
    );
  },
);

// One glass treatment for navigation, settings and popup menus in both themes.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final bool dark, enabled;
  final double radius;
  final String identity;
  const GlassSurface({
    super.key,
    required this.child,
    required this.dark,
    this.radius = 24,
    this.identity = 'menu',
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    final profile = PresentationScope.appearanceOf(context)?.surface(identity);
    final shape = BorderRadius.circular(profile?.radius ?? radius);
    final opacity = profile?.glassOpacity ?? .84;
    final blur = (profile?.blur ?? PresentationScope.of(context).blurSigma)
        .clamp(0, PresentationScope.of(context).blurSigma);
    final tint = profile == null
        ? (dark ? const Color(0xff252627) : Colors.white)
        : Color(profile.glassColor);
    final surface = Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: tint.withValues(alpha: enabled ? opacity : 1),
        gradient: enabled && profile == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: dark ? .10 : .88),
                  (dark ? const Color(0xff171819) : const Color(0xffeceeef))
                      .withValues(alpha: dark ? .88 : .82),
                ],
              )
            : null,
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(
            alpha: profile?.glassBorder ?? (dark ? .18 : .10),
          ),
        ),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: shape,
      child: enabled && blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur.toDouble(),
                sigmaY: blur.toDouble(),
              ),
              child: surface,
            )
          : surface,
    );
  }
}

// Anchored, scrollable glass menu. The transparent barrier dismisses it on tap.
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required BuildContext anchor,
  required Widget child,
  required bool dark,
  bool glass = true,
  double width = 292,
  double estimatedHeight = 400,
  bool above = false,
}) {
  final box = anchor.findRenderObject() as RenderBox;
  final offset = box.localToGlobal(Offset.zero);
  final rect = offset & box.size;
  final size = MediaQuery.sizeOf(context);
  final actualWidth = math.min(width, size.width - 24);
  final height = math.min(estimatedHeight, size.height - 24);
  final left = (rect.right - actualWidth).clamp(
    12.0,
    math.max(12.0, size.width - actualWidth - 12),
  );
  final top = (above ? rect.top - height - 8 : rect.bottom + 8).clamp(
    12.0,
    math.max(12.0, size.height - height - 12),
  );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: PresentationScope.of(context).transitionDuration,
    pageBuilder: (c, _, _) => Stack(
      children: [
        Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
          width: actualWidth,
          child: GlassSurface(
            dark: dark,
            enabled: glass,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height),
                child: Semantics(
                  role: SemanticsRole.menu,
                  container: true,
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    transitionBuilder: (c, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .02),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
  );
}
