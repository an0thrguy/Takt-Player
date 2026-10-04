import 'package:flutter/material.dart';

import '../library/library.dart';
import 'glass.dart';

// Settings stay inside the main content; playback remains accessible below.
class SettingsPanel extends StatefulWidget {
  final Map<String, dynamic> settings;
  final MusicLibrary library;
  final VoidCallback save, close;
  final Future<void> Function() chooseFolder;
  final Future<void> Function()? quit;
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.library,
    required this.save,
    required this.close,
    required this.chooseFolder,
    this.quit,
  });
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  Map<String, dynamic> get s => widget.settings;
  bool get dark => s['dark'] == true;
  bool get en => s['locale'] == 'en';
  String tr(String ru, String english) => en ? english : ru;
  void set(String key, Object? value) {
    s[key] = value;
    widget.save();
    if (mounted) setState(() {});
  }

  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: (dark ? Colors.white : Colors.black).withValues(alpha: .035),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: .07),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
  Widget toggle(String key, String label, {bool defaultValue = false}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: s[key] as bool? ?? defaultValue,
        onChanged: (v) => set(key, v),
      );
  Widget slider(
    String key,
    String label,
    double fallback,
    double min,
    double max,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${(((s[key] as num?)?.toDouble() ?? fallback) * 100).round()}%',
          ),
        ],
      ),
      Slider(
        key: Key(key),
        value: ((s[key] as num?)?.toDouble() ?? fallback).clamp(min, max),
        min: min,
        max: max,
        onChanged: (v) => set(key, v),
      ),
    ],
  );
  Future<void> customColor(String key) async {
    final controller = TextEditingController(
      text:
          '#${((s[key] as int? ?? 0xff808080) & 0xffffff).toRadixString(16).padLeft(6, '0')}',
    );
    final value = await showTaktDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Свой цвет HEX', 'Custom HEX color')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 7,
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('Отмена', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: Text(tr('Сохранить', 'Save')),
          ),
        ],
      ),
    );
    // The dialog's field finishes disposing after its reverse animation.
    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
    if (!mounted || value == null) return;
    final hex = value.trim().replaceFirst('#', '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      set(key, 0xff000000 | int.parse(hex, radix: 16));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Нужно шесть символов HEX', 'Enter six HEX characters'),
          ),
        ),
      );
    }
  }

  Widget colors(String key, {bool followTheme = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (followTheme)
            ChoiceChip(
              label: Text(tr('По теме', 'Theme')),
              selected: s[key] == null,
              onSelected: (_) => set(key, null),
            ),
          for (final color in [
            0xffeeeeee,
            0xff202020,
            0xff777777,
            0xffd7b2b2,
            0xff788bad,
            0xff709983,
          ])
            Semantics(
              label: '#${(color & 0xffffff).toRadixString(16)}',
              button: true,
              child: InkWell(
                onTap: () => set(key, color),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: s[key] == color
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey,
                      width: s[key] == color ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => customColor(key),
          icon: const Icon(Icons.palette_outlined, size: 18),
          label: Text(tr('Свой цвет', 'Custom color')),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => GlassSurface(
    dark: dark,
    enabled: s['glass'] != false,
    radius: 28,
    child: Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Настройки', 'Settings'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                IconButton(
                  key: const Key('close-settings'),
                  tooltip: tr('Закрыть', 'Close'),
                  onPressed: widget.close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  section(tr('Визуализатор', 'Visualizer'), [
                    toggle(
                      'visualizerEnabled',
                      tr('Визуализатор', 'Visualizer'),
                      defaultValue: true,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'solid',
                          label: Text(tr('Сплошной', 'Solid')),
                        ),
                        ButtonSegment(
                          value: 'bars',
                          label: Text(tr('Столбики', 'Bars')),
                        ),
                      ],
                      selected: {s['visualizerStyle'] as String? ?? 'solid'},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) =>
                          set('visualizerStyle', v.first),
                    ),
                    const SizedBox(height: 20),
                    slider(
                      'visualizerSensitivity',
                      tr('Чувствительность', 'Sensitivity'),
                      1,
                      .25,
                      2.5,
                    ),
                    slider(
                      'visualizerSmoothness',
                      tr('Плавность', 'Smoothness'),
                      .5,
                      0,
                      1,
                    ),
                    Text(tr('Цвет', 'Color')),
                    const SizedBox(height: 8),
                    colors('visualizerColor', followTheme: true),
                  ]),
                  section(tr('Перемотка', 'Seeking'), [
                    SegmentedButton<int>(
                      segments: [
                        for (final step in [5, 10, 15])
                          ButtonSegment(
                            value: step,
                            label: Text('$step ${tr('с', 's')}'),
                          ),
                      ],
                      selected: {s['seekStep'] as int? ?? 5},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => set('seekStep', v.first),
                    ),
                  ]),
                  section(tr('Интерфейс', 'Interface'), [
                    toggle('dark', tr('Тёмная тема', 'Dark theme')),
                    toggle('glass', tr('Стекло', 'Glass'), defaultValue: true),
                    toggle('wave', tr('Волнистая шкала', 'Wavy timeline')),
                    Builder(
                      builder: (anchor) => ListTile(
                        key: const Key('language-picker'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: (dark ? Colors.white : Colors.black)
                            .withValues(alpha: .06),
                        title: Text(tr('Язык', 'Language')),
                        subtitle: Text(en ? 'English' : 'Русский'),
                        trailing: const Icon(Icons.expand_more),
                        onTap: () async {
                          final value = await showGlassMenu<String>(
                            context: context,
                            anchor: anchor,
                            dark: dark,
                            glass: s['glass'] != false,
                            width: 240,
                            estimatedHeight: 120,
                            child: Builder(
                              builder: (c) => Column(
                                children: [
                                  for (final entry in const {
                                    'ru': 'Русский',
                                    'en': 'English',
                                  }.entries)
                                    ListTile(
                                      title: Text(entry.value),
                                      trailing: s['locale'] == entry.key
                                          ? const Icon(Icons.check)
                                          : null,
                                      onTap: () => Navigator.pop(c, entry.key),
                                    ),
                                ],
                              ),
                            ),
                          );
                          if (mounted && value != null) set('locale', value);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('Акцентный цвет', 'Accent color')),
                    const SizedBox(height: 8),
                    colors('accent'),
                  ]),
                  section(tr('Воспроизведение', 'Playback'), [
                    toggle(
                      'pauseOnHeadphonesDisconnect',
                      tr(
                        'Пауза при отключении наушников',
                        'Pause when headphones disconnect',
                      ),
                      defaultValue: true,
                    ),
                    toggle(
                      'closeToTray',
                      tr('Закрывать в трей', 'Close to tray'),
                      defaultValue: true,
                    ),
                  ]),
                  section(tr('Обложки', 'Artwork'), [
                    toggle(
                      'onlineArtwork',
                      tr('Искать обложки в интернете', 'Find artwork online'),
                    ),
                    Text(
                      tr(
                        'Отправляются исполнитель, альбом и название.',
                        'Artist, album and title are sent.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                  section(tr('Музыкальные папки', 'Music folders'), [
                    for (final path in widget.library.sources)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(path, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            widget.library.sources.remove(path);
                            widget.library.persist();
                            widget.library.scan();
                            setState(() {});
                          },
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        await widget.chooseFolder();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.folder_open),
                      label: Text(
                        tr('Добавить музыкальную папку', 'Add music folder'),
                      ),
                    ),
                  ]),
                  TextButton(
                    onPressed: widget.close,
                    child: Text(tr('Закрыть', 'Close')),
                  ),
                  if (widget.quit != null)
                    TextButton.icon(
                      onPressed: widget.quit,
                      icon: const Icon(Icons.power_settings_new),
                      label: Text(tr('Выйти из Takt', 'Quit Takt')),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
