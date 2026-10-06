import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'presentation_scope.dart';

// Focus and touch reveal the action even when pointer-hover mode is selected.
class WindowCloseButton extends StatefulWidget {
  final VoidCallback onClose;
  final bool hoverOnly, english;
  const WindowCloseButton({
    super.key,
    required this.onClose,
    required this.hoverOnly,
    required this.english,
  });
  @override
  State<WindowCloseButton> createState() => _WindowCloseButtonState();
}

class _WindowCloseButtonState extends State<WindowCloseButton> {
  bool hovered = false, focused = false, touched = false;
  @override
  Widget build(BuildContext context) {
    final visible =
        !widget.hoverOnly ||
        hovered ||
        focused ||
        touched ||
        MediaQuery.of(context).navigationMode == NavigationMode.directional;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.touch) {
            setState(() => touched = true);
          }
        },
        child: Focus(
          onFocusChange: (v) => setState(() => focused = v),
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: PresentationScope.of(context).transitionDuration,
            child: IconButton(
              key: const Key('window-close'),
              tooltip: widget.english ? 'Close Takt' : 'Закрыть Takt',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
