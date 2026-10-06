import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../playback/queue.dart';
import 'glass.dart';
import 'volume_control.dart';

class CompactPlayer extends StatelessWidget {
  final TaktQueue queue;
  final bool english, dark, pinned;
  final double volume;
  final Future<void> Function(double) onVolume;
  final Future<void> Function() restore, onPin;
  final Future<void> Function()? close;
  final Widget art;
  const CompactPlayer({
    super.key,
    required this.queue,
    required this.english,
    required this.dark,
    required this.pinned,
    required this.volume,
    required this.onVolume,
    required this.restore,
    required this.onPin,
    this.close,
    required this.art,
  });
  String t(String ru, String en) => english ? en : ru;
  @override
  Widget build(BuildContext context) {
    final total = queue.current?.seconds ?? 0;
    final position = total <= 0
        ? 0.0
        : (queue.position.inMilliseconds / 1000 / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GlassSurface(
        identity: 'player',
        dark: dark,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onPanStart: (_) => windowManager.startDragging(),
                      child: Text(
                        'Takt',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('compact-pin'),
                    tooltip: t('Поверх окон', 'Always on top'),
                    onPressed: onPin,
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                    ),
                  ),
                  IconButton(
                    key: const Key('compact-restore'),
                    tooltip: t('Обычный режим', 'Restore main window'),
                    onPressed: restore,
                    icon: const Icon(Icons.open_in_full, size: 18),
                  ),
                  IconButton(
                    tooltip: t('Закрыть', 'Close'),
                    onPressed: close,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: art,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            queue.current?.title ??
                                t('Выбери музыку', 'Choose music'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            queue.current?.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: queue.previous,
                                icon: const Icon(Icons.skip_previous),
                              ),
                              IconButton.filled(
                                key: const Key('compact-play'),
                                onPressed: queue.toggle,
                                icon: Icon(
                                  queue.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                              ),
                              IconButton(
                                onPressed: queue.next,
                                icon: const Icon(Icons.skip_next),
                              ),
                              VolumeControl(
                                value: volume,
                                onChanged: onVolume,
                                inline: false,
                                wheelEnabled: true,
                                dark: dark,
                                glass: true,
                                english: english,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 28,
                child: Slider(
                  key: const Key('compact-seek'),
                  value: position,
                  onChanged: total <= 0
                      ? null
                      : (v) => queue.seek(
                          Duration(milliseconds: (v * total * 1000).round()),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
