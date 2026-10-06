import 'dart:math' as math;

import 'package:flutter/material.dart';

// Descendants use the constrained state, not the full window width.
class SidebarScope extends InheritedWidget {
  final bool collapsed;
  const SidebarScope({
    super.key,
    required this.collapsed,
    required super.child,
  });
  static bool? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarScope>()?.collapsed;
  @override
  bool updateShouldNotify(SidebarScope oldWidget) =>
      collapsed != oldWidget.collapsed;
}

// Resizing never writes the temporary width forced by a narrow window.
class ResizableSidebar extends StatefulWidget {
  final double preferredWidth, availableWidth;
  final bool collapsed;
  final Widget child;
  final ValueChanged<double> onResizeEnd;
  final ValueChanged<bool> onCollapsedChanged;
  const ResizableSidebar({
    super.key,
    required this.preferredWidth,
    required this.availableWidth,
    required this.collapsed,
    required this.child,
    required this.onResizeEnd,
    required this.onCollapsedChanged,
  });
  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  double? draft;
  @override
  Widget build(BuildContext context) {
    final maximum = math.min(320.0, widget.availableWidth - 380);
    final forced = maximum < 150 || widget.availableWidth < 626;
    final collapsed = forced || widget.collapsed;
    final width = collapsed
        ? 62.0
        : (draft ?? widget.preferredWidth).clamp(150.0, maximum).toDouble();
    return SizedBox(
      key: const Key('sidebar-panel'),
      width: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: SidebarScope(collapsed: collapsed, child: widget.child),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const Key('sidebar-collapse'),
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              onPressed: forced
                  ? null
                  : () => widget.onCollapsedChanged(!widget.collapsed),
              icon: Icon(
                collapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 16,
              ),
            ),
          ),
          if (!collapsed)
            Positioned(
              top: 40,
              bottom: 0,
              right: 0,
              width: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  key: const Key('sidebar-resize'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => draft = width,
                  onHorizontalDragUpdate: (d) => setState(
                    () => draft = ((draft ?? width) + d.delta.dx)
                        .clamp(150.0, math.max(150.0, maximum))
                        .toDouble(),
                  ),
                  onHorizontalDragEnd: (_) {
                    final value = (draft ?? width)
                        .clamp(150.0, math.max(150.0, maximum))
                        .toDouble();
                    setState(() => draft = null);
                    widget.onResizeEnd(value);
                  },
                  onHorizontalDragCancel: () => setState(() => draft = null),
                  child: Center(
                    child: Container(
                      width: 1,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: .15),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
