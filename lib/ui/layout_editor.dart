import 'package:flutter/material.dart';

import 'glass.dart';
import 'layout_preferences.dart';

// The editor changes a local zone draft; cancel returns no layout.
class LayoutEditor extends StatefulWidget {
  final LayoutPreferences initial;
  final bool english, dark;
  final ValueChanged<LayoutPreferences> onPreview;
  const LayoutEditor({
    super.key,
    required this.initial,
    required this.english,
    required this.dark,
    required this.onPreview,
  });
  @override
  State<LayoutEditor> createState() => _LayoutEditorState();
}

class _LayoutEditorState extends State<LayoutEditor> {
  late Map<String, dynamic> draft = widget.initial.toMap();
  String tr(String ru, String en) => widget.english ? en : ru;
  void update() {
    setState(() {});
    widget.onPreview(LayoutPreferences.fromMap(draft));
  }

  String label(String id) =>
      {
        'all': tr('Моя музыка', 'My music'),
        'favorites': tr('Избранное', 'Favorites'),
        'folders': tr('Папки', 'Folders'),
        'recent': tr('Недавно прослушанное', 'Recently played'),
        'added': tr('Недавно добавленное', 'Recently added'),
        'albums': tr('Альбомы', 'Albums'),
        'artists': tr('Исполнители', 'Artists'),
        'new': tr('Новый плейлист', 'New playlist'),
        'mode': tr('Режим очереди', 'Queue mode'),
        'previous': tr('Предыдущий', 'Previous'),
        'play': tr('Пуск / пауза', 'Play / pause'),
        'next': tr('Следующий', 'Next'),
        'volume': tr('Громкость', 'Volume'),
        'favorite': tr('Избранное', 'Favorite'),
        'timer': tr('Таймер сна', 'Sleep timer'),
        'visualizer': tr('Визуализатор', 'Visualizer'),
        'compact': tr('Компактный режим', 'Compact mode'),
      }[id] ??
      id;
  Widget zone(String key, String hiddenKey, String title) {
    final order = List<String>.from(draft[key]);
    final hidden = List<String>.from(draft[hiddenKey]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: order.length,
          onReorderItem: (from, to) {
            final id = order.removeAt(from);
            order.insert(to, id);
            draft[key] = order;
            update();
          },
          itemBuilder: (c, index) {
            final id = order[index];
            return Material(
              key: ValueKey('$key-$id'),
              type: MaterialType.transparency,
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text(label(id)),
                trailing: Switch(
                  value: !hidden.contains(id),
                  onChanged: id == 'play'
                      ? null
                      : (v) {
                          if (v) {
                            hidden.remove(id);
                          } else {
                            hidden.add(id);
                          }
                          draft[hiddenKey] = hidden;
                          update();
                        },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: SizedBox(
      width: 640,
      height: MediaQuery.sizeOf(context).height * .8,
      child: GlassSurface(
        dark: widget.dark,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  tr('Редактировать интерфейс', 'Edit interface'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        zone(
                          'sidebarOrder',
                          'hiddenSidebar',
                          tr('Левая панель', 'Sidebar'),
                        ),
                        const SizedBox(height: 20),
                        zone(
                          'controlsOrder',
                          'hiddenControls',
                          tr('Воспроизведение', 'Playback'),
                        ),
                        const SizedBox(height: 12),
                        Text(tr('Ширина панели', 'Sidebar width')),
                        Slider(
                          value: (draft['sidebarWidth'] as num).toDouble(),
                          min: 150,
                          max: 320,
                          onChanged: (v) {
                            draft['sidebarWidth'] = v;
                            update();
                          },
                        ),
                        Text(
                          tr(
                            'Высота панели воспроизведения',
                            'Playback panel height',
                          ),
                        ),
                        Slider(
                          value: (draft['playerHeight'] as num).toDouble(),
                          min: 160,
                          max: 280,
                          onChanged: (v) {
                            draft['playerHeight'] = v;
                            update();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        draft = LayoutPreferences.fromMap({}).toMap();
                        update();
                      },
                      child: Text(tr('Сброс расположения', 'Reset layout')),
                    ),
                    TextButton(
                      key: const Key('layout-cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('Отмена', 'Cancel')),
                    ),
                    FilledButton(
                      key: const Key('layout-done'),
                      onPressed: () => Navigator.pop(
                        context,
                        LayoutPreferences.fromMap(draft),
                      ),
                      child: Text(tr('Готово', 'Done')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
