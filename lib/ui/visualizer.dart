import 'dart:math' as math;

import 'package:flutter/material.dart';

// Interpolate actual frequency bands; a flat quiet line is never randomized.
class SignalTween extends Tween<List<double>> {
  SignalTween({super.end});
  @override
  List<double> lerp(double t) {
    final a = begin ?? [], b = end ?? [];
    return List.generate(math.max(a.length, b.length), (i) {
      final from = i < a.length ? a[i] : 0.0, to = i < b.length ? b[i] : 0.0;
      return from + (to - from) * t;
    });
  }
}

class WaveSignal extends StatelessWidget {
  final List<double> values;
  final Color color;
  final bool bars;
  final double smoothness;
  const WaveSignal({
    super.key,
    required this.values,
    required this.color,
    this.bars = false,
    this.smoothness = .5,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<List<double>>(
    tween: SignalTween(end: values),
    duration: Duration(
      milliseconds: (60 + smoothness.clamp(0, 1) * 200).round(),
    ),
    builder: (c, signal, _) =>
        CustomPaint(painter: WavePainter(signal, color, bars: bars)),
  );
}

class WavePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool bars;
  WavePainter(this.values, this.color, {this.bars = false});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = size.height / 2;
    if (values.isEmpty || values.every((v) => v < .001)) {
      canvas.drawLine(
        Offset(0, center),
        Offset(size.width, center),
        paint..strokeWidth = 1.2,
      );
      return;
    }
    if (bars) {
      final step = size.width / values.length;
      for (int i = 0; i < values.length; i++) {
        final amplitude = values[i].clamp(0.0, .8) * size.height * .42;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset((i + .5) * step, center),
              width: math.max(1, step * .55),
              height: math.max(1.2, amplitude * 2),
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      return;
    }
    // Soft local smoothing connects neighboring bands without washing out bass.
    final heights = List.generate(values.length, (i) {
      final left = i == 0 ? values[i] : values[i - 1],
          right = i == values.length - 1 ? values[i] : values[i + 1];
      final envelope = (left * .2 + values[i] * .6 + right * .2).clamp(0.0, .8);
      return .6 + envelope * size.height * .42;
    });
    final top = <Offset>[
      Offset(0, center - .6),
      for (int i = 0; i < heights.length; i++)
        Offset(
          (i + 1) / (heights.length + 1) * size.width,
          center - heights[i],
        ),
      Offset(size.width, center - .6),
    ];
    final bottom = top.reversed
        .map((p) => Offset(p.dx, size.height - p.dy))
        .toList();
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    void smooth(List<Offset> points) {
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1],
            next = points[i],
            mid = (prev.dx + next.dx) / 2;
        path.cubicTo(mid, prev.dy, mid, next.dy, next.dx, next.dy);
      }
    }

    smooth(top);
    path.lineTo(bottom.first.dx, bottom.first.dy);
    smooth(bottom);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter old) =>
      old.values != values || old.color != color || old.bars != bars;
}
