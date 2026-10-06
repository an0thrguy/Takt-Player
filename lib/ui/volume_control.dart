import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'glass.dart';

// The popup listens to current values, including external MPRIS volume changes.
class VolumeControl extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool inline, wheelEnabled, dark, glass, english;
  const VolumeControl({
    super.key,
    required this.value,
    required this.onChanged,
    required this.inline,
    required this.wheelEnabled,
    required this.dark,
    required this.glass,
    required this.english,
  });
  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  late final level = ValueNotifier<double>(widget.value.clamp(0, 100));
  double remainder = 0;
  bool open = false;
  @override
  void didUpdateWidget(VolumeControl old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) level.value = widget.value.clamp(0, 100);
    });
    if (old.wheelEnabled != widget.wheelEnabled) remainder = 0;
  }

  @override
  void dispose() {
    level.dispose();
    super.dispose();
  }

  void setVolume(double value) {
    level.value = value.clamp(0, 100);
    widget.onChanged(level.value);
  }

  Widget slider() => ValueListenableBuilder<double>(
    valueListenable: level,
    builder: (c, v, _) => Row(
      children: [
        Expanded(
          child: Slider(
            key: const Key('volume-slider'),
            value: v,
            min: 0,
            max: 100,
            onChanged: setVolume,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text('${v.round()}%', style: const TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
  Future<void> popup(BuildContext anchor) async {
    if (open) return;
    open = true;
    try {
      await showGlassMenu<void>(
        context: anchor,
        anchor: anchor,
        dark: widget.dark,
        glass: widget.glass,
        width: 260,
        estimatedHeight: 86,
        above: true,
        child: Padding(padding: const EdgeInsets.all(12), child: slider()),
      );
    } finally {
      open = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (event) {
      if (!widget.wheelEnabled || event is! PointerScrollEvent) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        remainder -= (e as PointerScrollEvent).scrollDelta.dy;
        final steps = (remainder / 100).truncate();
        if (steps != 0) {
          remainder -= steps * 100;
          setVolume(level.value + steps * 5);
        }
      });
    },
    child: Builder(
      builder: (anchor) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip:
                '${widget.english ? 'Volume' : 'Громкость'}: ${widget.value.round()}%',
            onPressed: widget.inline ? null : () => popup(anchor),
            icon: const Icon(Icons.volume_up_outlined, size: 20),
          ),
          if (widget.inline) SizedBox(width: 140, child: slider()),
        ],
      ),
    ),
  );
}
