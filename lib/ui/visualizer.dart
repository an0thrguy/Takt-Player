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
  final bool bottomAligned;
  final double smoothness;
  final int refreshHz;
  final List<double> Function()? sample;
  const WaveSignal({
    super.key,
    required this.values,
    required this.color,
    this.bars = false,
    this.bottomAligned = false,
    this.smoothness = .5,
    this.refreshHz = 30,
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
    final target = widget.sample?.call() ?? widget.values;
    if (target.isEmpty) {
      if (signal.isNotEmpty) setState(() => signal = []);
      return;
    }
    final weight =
        (1 / (1 + widget.smoothness.clamp(0, 1) * widget.refreshHz * .12))
            .clamp(.05, 1.0);
    final next = List<double>.generate(target.length, (i) {
      final from = i < signal.length ? signal[i] : 0.0;
      final to = target[i];
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
        signal,
        widget.color,
        bars: widget.bars,
        bottomAligned: widget.bottomAligned,
      ),
    ),
  );
}

class WavePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool bars, bottomAligned;
  WavePainter(
    this.values,
    this.color, {
    this.bars = false,
    this.bottomAligned = false,
  });
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
      old.values != values ||
      old.color != color ||
      old.bars != bars ||
      old.bottomAligned != bottomAligned;
}
