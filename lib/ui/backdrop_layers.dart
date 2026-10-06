import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'appearance.dart';
import 'visualizer.dart';

// Background layers share the existing spectrum provider; they never decode audio.
class BackdropLayers extends StatelessWidget {
  final AppearanceProfile profile;
  final int refreshHz;
  final double maxBlur;
  final List<double> Function()? sample;
  final Widget child;
  const BackdropLayers({
    super.key,
    required this.profile,
    required this.refreshHz,
    required this.child,
    this.sample,
    this.maxBlur = 30,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, size) => Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(profile.background)),
        if (profile.wallpaper != null && File(profile.wallpaper!).existsSync())
          Opacity(
            opacity: profile.wallpaperOpacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: profile.wallpaperBlur.clamp(0, maxBlur),
                sigmaY: profile.wallpaperBlur.clamp(0, maxBlur),
              ),
              child: Image.file(
                File(profile.wallpaper!),
                fit: profile.wallpaperFill ? BoxFit.cover : BoxFit.contain,
                cacheWidth: 1920,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (profile.wallpaper != null && File(profile.wallpaper!).existsSync())
          ColoredBox(
            color: Colors.black.withValues(alpha: profile.wallpaperDim),
          ),
        if (profile.backgroundVisualizer)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: profile.backgroundFull
                ? size.maxHeight
                : size.maxHeight * profile.backgroundHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: profile.backgroundOpacity,
                child: WaveSignal(
                  key: const Key('background-spectrum'),
                  values: const [],
                  color: Color(profile.backgroundColor),
                  bars: true,
                  bottomAligned: !profile.backgroundFull,
                  smoothness: profile.backgroundSmoothness,
                  refreshHz: refreshHz,
                  sample: () => [
                    for (final v in sample?.call() ?? const <double>[])
                      (v * profile.backgroundSensitivity).clamp(0, .8),
                  ],
                ),
              ),
            ),
          ),
        child,
      ],
    ),
  );
}
