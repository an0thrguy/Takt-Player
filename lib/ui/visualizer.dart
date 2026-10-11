import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';

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

// Local scheduled interpolation caps all spectrum paints, including smoothing.
class WaveSignal extends StatefulWidget {
  final List<double> values;
  final Color color;
  final bool bars;
  final bool linear;
  final bool bottomAligned;
  final double smoothness;
  final int refreshHz;
  final int? bandCount;
  final List<double> Function()? sample;
  const WaveSignal({
    super.key,
    required this.values,
    required this.color,
    this.bars = false,
    this.linear = false,
    this.bottomAligned = false,
    this.smoothness = .5,
    this.refreshHz = 30,
    this.bandCount,
    this.sample,
  });
  @override
  State<WaveSignal> createState() => _WaveSignalState();
}

class _WaveSignalState extends State<WaveSignal> {
  Timer? timer;
  List<double> signal = [];
  @override
  void initState() {
    super.initState();
    signal = List.of(widget.values);
    schedule();
  }

  void schedule() {
    timer?.cancel();
    timer = Timer.periodic(
      Duration(microseconds: (1000000 / widget.refreshHz.clamp(1, 60)).ceil()),
      (_) => tick(),
    );
  }

  @override
  void didUpdateWidget(WaveSignal old) {
    super.didUpdateWidget(old);
    if (old.refreshHz != widget.refreshHz) schedule();
  }

  void tick() {
    final sampled = widget.sample?.call() ?? widget.values;
    final target = sampled.isEmpty
        ? List<double>.filled(signal.length, 0)
        : sampled;
    if (target.isEmpty) return;
    // Fast attack keeps beats clear; a longer release makes silence settle gently.
    final smoothness = widget.smoothness.clamp(0, 1);
    final elapsed = 1 / widget.refreshHz.clamp(1, 60);
    final next = List<double>.generate(target.length, (i) {
      final from = i < signal.length ? signal[i] : 0.0;
      final to = target[i];
      final seconds = to > from
          ? .012 + smoothness * .04
          : .07 + smoothness * .18;
      final weight = 1 - math.exp(-elapsed / seconds);
      return (from - to).abs() < .001 ? to : from + (to - from) * weight;
    });
    if (!listEquals(next, signal)) setState(() => signal = next);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: WavePainter(
        _resample(signal, widget.bandCount),
        widget.color,
        bars: widget.bars,
        linear: widget.linear,
        bottomAligned: widget.bottomAligned,
      ),
    ),
  );
}

// Add visual detail by interpolating adjacent measured bands, without another FFT.
List<double> _resample(List<double> values, int? requested) {
  if (values.isEmpty || requested == null) return values;
  final count = requested.clamp(2, 96);
  if (values.length == count) return values;
  return List.generate(count, (i) {
    final position = i * (values.length - 1) / (count - 1);
    final left = position.floor(), right = position.ceil();
    return values[left] + (values[right] - values[left]) * (position - left);
  });
}

class WavePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool bars, linear, bottomAligned;
  WavePainter(
    this.values,
    this.color, {
    this.bars = false,
    this.linear = false,
    this.bottomAligned = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = bottomAligned && !bars ? size.height : size.height / 2;
    if (values.isEmpty || values.every((v) => v < .001)) {
      canvas.drawLine(
        Offset(0, center),
        Offset(size.width, center),
        paint..strokeWidth = 1.2,
      );
      return;
    }
    // Low frequencies meet at the center; both halves use the same spectrum.
    final mirrored = [...values.reversed, ...values];
    if (bars) {
      final step = size.width / mirrored.length;
      for (int i = 0; i < mirrored.length; i++) {
        final amplitude = mirrored[i].clamp(0.0, .8) * size.height * .55;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                (i + .5) * step,
                bottomAligned ? size.height - amplitude : center,
              ),
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
    final heights = List.generate(mirrored.length, (i) {
      final left = i == 0 ? mirrored[i] : mirrored[i - 1],
          right = i == mirrored.length - 1 ? mirrored[i] : mirrored[i + 1];
      final envelope = (left * .15 + mirrored[i] * .7 + right * .15).clamp(
        0.0,
        .8,
      );
      return .6 + envelope * size.height * (bottomAligned ? 1.1 : .55);
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
    final bottom = bottomAligned
        ? [Offset(size.width, size.height), Offset(0, size.height)]
        : top.reversed.map((p) => Offset(p.dx, size.height - p.dy)).toList();
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
    if (linear) {
      canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    path.lineTo(bottom.first.dx, bottom.first.dy);
    smooth(bottom);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter old) =>
      old.values != values ||
      old.color != color ||
      old.bars != bars ||
      old.linear != linear ||
      old.bottomAligned != bottomAligned;
}
