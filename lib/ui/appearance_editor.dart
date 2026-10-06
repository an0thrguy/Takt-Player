import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'appearance.dart';
import 'glass.dart';
import 'layout_preferences.dart';

// All mutations stay in the draft until the root commits presentation keys.
class AppearanceEditor extends StatefulWidget {
  final Map<String, dynamic> settings;
  final ValueChanged<Map<String, dynamic>> onPreview;
  final Future<bool> Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;
  final Future<String?> Function() chooseWallpaper;
  const AppearanceEditor({
    super.key,
    required this.settings,
    required this.onPreview,
    required this.onSave,
    required this.onCancel,
    required this.chooseWallpaper,
  });
  @override
  State<AppearanceEditor> createState() => _AppearanceEditorState();
}

class _AppearanceEditorState extends State<AppearanceEditor> {
  late final draft = AppearanceDraft(widget.settings);
  late bool dark = widget.settings['dark'] == true;
  late List<Map<String, dynamic>> presets = [
    for (final p in widget.settings['appearancePresets'] as List? ?? [])
      if (p is Map) Map<String, dynamic>.from(p),
  ];
  Map<String, dynamic>? presetLayout;
  bool saving = false;
  String presetScope = 'both';
  final name = TextEditingController();
  bool get en => widget.settings['locale'] == 'en';
  String tr(String ru, String enText) => en ? enText : ru;
  AppearanceProfile get profile => draft.profile(dark);
  Map<String, dynamic> get snapshot => {
    ...draft.settings,
    'dark': dark,
    'appearancePresets': presets,
    if (presetLayout != null) 'layout': presetLayout,
  };
  void preview() {
    widget.onPreview(snapshot);
    setState(() {});
  }

  void change(String key, Object? value) {
    draft.update(dark, key, value);
    preview();
  }

  Widget resetSection(List<String> keys) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      onPressed: () {
        final defaults = AppearanceProfile.fromMap({}, dark: dark).toMap();
        for (final key in keys) {
          draft.update(dark, key, defaults[key]);
        }
        preview();
      },
      child: Text(tr('Сбросить раздел', 'Reset section')),
    ),
  );

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    ),
  );
  Widget slider(
    String key,
    String title,
    double min,
    double max, {
    Map<String, dynamic>? override,
    String? identity,
  }) {
    final value = override?[key] is num
        ? (override![key] as num).toDouble()
        : ((profile.toMap()[key] as num?)?.toDouble() ?? min);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(value.toStringAsFixed(2)),
          ],
        ),
        Slider(
          key: Key('appearance-${identity == null ? '' : '$identity-'}$key'),
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            if (identity == null) {
              change(key, v);
            } else {
              final map = {...override!, key: v};
              change('${identity}Override', map);
            }
          },
        ),
      ],
    );
  }

  Widget toggle(String key, String title) => SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: profile.toMap()[key] == true,
    onChanged: (v) => change(key, v),
  );
  Future<void> color(String key, {String? identity}) async {
    final data = identity == null
        ? profile.toMap()
        : profile.surface(identity).toMap();
    final result = await showTaktDialog<int>(
      context: context,
      builder: (_) => _ColorDialog(
        initial: (data[key] as int?) ?? profile.glassColor,
        english: en,
      ),
    );
    if (!mounted || result == null) return;
    if (identity == null) {
      change(key, result);
    } else {
      change('${identity}Override', {
        ...profile.surface(identity).toMap(),
        'enabled': true,
        key: result,
      });
    }
  }

  Widget colorButton(String key, String label, {String? identity}) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Color(
          (identity == null
                  ? profile.toMap()
                  : profile.surface(identity).toMap())[key]
              as int,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .3),
        ),
      ),
    ),
    onTap: () => color(key, identity: identity),
  );
  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (await widget.onSave(snapshot) && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void cancel() {
    widget.onCancel();
    Navigator.of(context).maybePop();
  }

  void error(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tr('Не удалось выполнить действие', 'Could not complete action')}: $e',
        ),
      ),
    );
  }

  Future<void> importPreset() async {
    try {
      final file = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file.isEmpty || file.single.path == null) return;
      if (await File(file.single.path!).length() > 1024 * 1024) {
        throw const FormatException('Preset must be smaller than 1 MiB');
      }
      final imported = AppearancePreset.fromJson(
        await File(file.single.path!).readAsString(),
      );
      if (!mounted) return;
      setState(() => presets.add(imported.toMap()));
    } catch (e) {
      if (mounted) error(e);
    }
  }

  Future<void> exportPreset(Map<String, dynamic> preset) async {
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: tr('Экспорт пресета', 'Export preset'),
        fileName: 'takt-preset.json',
        bytes: Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(preset)),
        ),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;
    } catch (e) {
      if (mounted) error(e);
    }
  }

  void usePreset(Map<String, dynamic> p) {
    final scope = p['scope'];
    if (scope != 'layout') {
      for (final isDark in [false, true]) {
        final raw = p[isDark ? 'dark' : 'light'];
        if (raw is Map) draft.replace(isDark, Map<String, dynamic>.from(raw));
      }
    }
    if (scope != 'appearance' && p['layout'] is Map) {
      presetLayout = LayoutPreferences.fromMap(
        Map<String, dynamic>.from(p['layout']),
      ).toMap();
    }
    preview();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: !saving,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 720,
          height: (size.height - 80).clamp(300, 800),
          child: GlassSurface(
            dark: dark,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('Оформление', 'Appearance'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Switch(
                        value: dark,
                        onChanged: (v) {
                          dark = v;
                          preview();
                        },
                      ),
                      Text(
                        dark ? tr('Тёмная', 'Dark') : tr('Светлая', 'Light'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          section(tr('Стекло', 'Glass'), [
                            colorButton(
                              'glassColor',
                              tr('Цвет стекла', 'Glass color'),
                            ),
                            slider(
                              'glassOpacity',
                              tr('Непрозрачность стекла', 'Glass opacity'),
                              0,
                              1,
                            ),
                            slider('blur', tr('Размытие', 'Blur'), 0, 30),
                            slider(
                              'glassBorder',
                              tr('Рамка стекла', 'Glass border'),
                              0,
                              1,
                            ),
                            slider(
                              'radius',
                              tr('Скругления', 'Corners'),
                              0,
                              36,
                            ),
                            for (final id in ['sidebar', 'player', 'menu'])
                              Builder(
                                builder: (_) {
                                  final raw = profile.toMap()['${id}Override'];
                                  final data = raw is Map
                                      ? Map<String, dynamic>.from(raw)
                                      : {...profile.toMap(), 'enabled': false};
                                  return Column(
                                    children: [
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          {
                                            'sidebar': tr(
                                              'Свои параметры: левая панель',
                                              'Sidebar override',
                                            ),
                                            'player': tr(
                                              'Свои параметры: воспроизведение',
                                              'Playback override',
                                            ),
                                            'menu': tr(
                                              'Свои параметры: меню',
                                              'Menu override',
                                            ),
                                          }[id]!,
                                        ),
                                        value: data['enabled'] == true,
                                        onChanged: (v) => change(
                                          '${id}Override',
                                          {...data, 'enabled': v},
                                        ),
                                      ),
                                      if (data['enabled'] == true) ...[
                                        colorButton(
                                          'glassColor',
                                          tr('Цвет', 'Color'),
                                          identity: id,
                                        ),
                                        slider(
                                          'glassOpacity',
                                          tr('Непрозрачность', 'Opacity'),
                                          0,
                                          1,
                                          override: data,
                                          identity: id,
                                        ),
                                        slider(
                                          'blur',
                                          tr('Размытие', 'Blur'),
                                          0,
                                          30,
                                          override: data,
                                          identity: id,
                                        ),
                                        slider(
                                          'glassBorder',
                                          tr('Граница', 'Border'),
                                          0,
                                          1,
                                          override: data,
                                          identity: id,
                                        ),
                                        slider(
                                          'radius',
                                          tr('Скругления', 'Corners'),
                                          0,
                                          36,
                                          override: data,
                                          identity: id,
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            TextButton(
                              onPressed: () {
                                for (final key in [
                                  'glassColor',
                                  'glassOpacity',
                                  'blur',
                                  'glassBorder',
                                  'radius',
                                  'sidebarOverride',
                                  'playerOverride',
                                  'menuOverride',
                                ]) {
                                  draft.update(
                                    dark,
                                    key,
                                    AppearanceProfile.fromMap(
                                      {},
                                      dark: dark,
                                    ).toMap()[key],
                                  );
                                }
                                preview();
                              },
                              child: Text(tr('Сбросить стекло', 'Reset glass')),
                            ),
                          ]),
                          section(tr('Окно и текст', 'Window and text'), [
                            resetSection([
                              'background',
                              'accent',
                              'windowOpacity',
                              'textScale',
                              'density',
                            ]),
                            colorButton(
                              'background',
                              tr('Цвет фона', 'Background color'),
                            ),
                            colorButton('accent', tr('Акцент', 'Accent')),
                            slider(
                              'windowOpacity',
                              tr('Непрозрачность окна', 'Window opacity'),
                              .25,
                              1,
                            ),
                            Text(
                              tr(
                                'Прозрачность окна зависит от поддержки оконного менеджера.',
                                'Window opacity depends on window-manager support.',
                              ),
                            ),
                            slider(
                              'textScale',
                              tr('Размер текста', 'Text size'),
                              .8,
                              1.5,
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final entry in {
                                  'compact': tr('Плотно', 'Compact'),
                                  'normal': tr('Обычно', 'Normal'),
                                  'comfortable': tr('Свободно', 'Comfortable'),
                                }.entries)
                                  ChoiceChip(
                                    label: Text(entry.value),
                                    selected: profile.density == entry.key,
                                    onSelected: (_) =>
                                        change('density', entry.key),
                                  ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                draft.copyTheme(fromDark: !dark);
                                preview();
                              },
                              child: Text(
                                tr(
                                  'Скопировать из другой темы',
                                  'Copy from other theme',
                                ),
                              ),
                            ),
                          ]),
                          section(tr('Обои', 'Wallpaper'), [
                            resetSection([
                              'wallpaper',
                              'wallpaperFill',
                              'wallpaperOpacity',
                              'wallpaperDim',
                              'wallpaperBlur',
                            ]),
                            Text(
                              profile.wallpaper?.split('/').last ??
                                  tr('Не выбраны', 'None selected'),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    final path = await widget.chooseWallpaper();
                                    if (mounted && path != null) {
                                      change('wallpaper', path);
                                    }
                                  },
                                  child: Text(
                                    tr('Выбрать картинку', 'Choose image'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => change('wallpaper', null),
                                  child: Text(tr('Убрать', 'Remove')),
                                ),
                              ],
                            ),
                            toggle(
                              'wallpaperFill',
                              tr('Заполнять окно', 'Fill window'),
                            ),
                            slider(
                              'wallpaperOpacity',
                              tr('Непрозрачность обоев', 'Wallpaper opacity'),
                              0,
                              1,
                            ),
                            slider(
                              'wallpaperDim',
                              tr('Затемнение', 'Dimming'),
                              0,
                              1,
                            ),
                            slider(
                              'wallpaperBlur',
                              tr('Размытие обоев', 'Wallpaper blur'),
                              0,
                              30,
                            ),
                          ]),
                          section(
                            tr('Визуализатор на фоне', 'Background visualizer'),
                            [
                              resetSection([
                                'backgroundVisualizer',
                                'backgroundFull',
                                'backgroundHeight',
                                'backgroundOpacity',
                                'backgroundSensitivity',
                                'backgroundSmoothness',
                                'backgroundColor',
                              ]),
                              toggle(
                                'backgroundVisualizer',
                                tr('Включить', 'Enabled'),
                              ),
                              toggle(
                                'backgroundFull',
                                tr('На всё окно', 'Full window'),
                              ),
                              colorButton(
                                'backgroundColor',
                                tr('Цвет столбиков', 'Bar color'),
                              ),
                              slider(
                                'backgroundHeight',
                                tr('Высота', 'Height'),
                                .1,
                                1,
                              ),
                              slider(
                                'backgroundOpacity',
                                tr('Непрозрачность', 'Opacity'),
                                0,
                                1,
                              ),
                              slider(
                                'backgroundSensitivity',
                                tr('Чувствительность', 'Sensitivity'),
                                .2,
                                3,
                              ),
                              slider(
                                'backgroundSmoothness',
                                tr('Плавность', 'Smoothing'),
                                0,
                                1,
                              ),
                            ],
                          ),
                          section(tr('Пресеты', 'Presets'), [
                            TextField(
                              controller: name,
                              decoration: InputDecoration(
                                labelText: tr(
                                  'Название пресета',
                                  'Preset name',
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final entry in {
                                  'appearance': tr('Оформление', 'Appearance'),
                                  'layout': tr('Расположение', 'Layout'),
                                  'both': tr('Всё', 'Both'),
                                }.entries)
                                  ChoiceChip(
                                    label: Text(entry.value),
                                    selected: presetScope == entry.key,
                                    onSelected: (_) =>
                                        setState(() => presetScope = entry.key),
                                  ),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    if (name.text.trim().isEmpty) return;
                                    setState(
                                      () => presets.add(
                                        AppearancePreset(
                                          name: name.text.trim(),
                                          scope: presetScope,
                                          light: draft.profile(false).toMap(),
                                          dark: draft.profile(true).toMap(),
                                          layout: snapshot['layout'] is Map
                                              ? Map<String, dynamic>.from(
                                                  snapshot['layout'],
                                                )
                                              : {},
                                        ).toMap(),
                                      ),
                                    );
                                    name.clear();
                                  },
                                  child: Text(
                                    tr('Создать пресет', 'Create preset'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: importPreset,
                                  child: Text(tr('Импорт', 'Import')),
                                ),
                              ],
                            ),
                            for (final p in presets)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(p['name']?.toString() ?? ''),
                                onTap: () => usePreset(p),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: tr('Переименовать', 'Rename'),
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () async {
                                        final label =
                                            await showTaktDialog<String>(
                                              context: context,
                                              builder: (_) => _NameDialog(
                                                initial:
                                                    p['name']?.toString() ?? '',
                                                english: en,
                                              ),
                                            );
                                        if (mounted && label != null) {
                                          setState(() => p['name'] = label);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: tr('Экспорт', 'Export'),
                                      icon: const Icon(
                                        Icons.file_upload_outlined,
                                      ),
                                      onPressed: () => exportPreset(p),
                                    ),
                                    IconButton(
                                      tooltip: tr('Удалить', 'Delete'),
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          setState(() => presets.remove(p)),
                                    ),
                                  ],
                                ),
                              ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('appearance-cancel'),
                        onPressed: saving ? null : cancel,
                        child: Text(tr('Отмена', 'Cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('appearance-save'),
                        onPressed: saving ? null : save,
                        child: Text(tr('Сохранить', 'Save')),
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
}

// Small edit dialogs use the same material as the rest of the player.
Widget _formDialog(
  BuildContext context, {
  Widget? title,
  required Widget content,
  required List<Widget> actions,
}) => Dialog(
  backgroundColor: Colors.transparent,
  child: GlassSurface(
    dark: Theme.of(context).brightness == Brightness.dark,
    child: Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[title, const SizedBox(height: 16)],
              content,
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
            ],
          ),
        ),
      ),
    ),
  ),
);

class _ColorDialog extends StatefulWidget {
  final int initial;
  final bool english;
  const _ColorDialog({required this.initial, required this.english});
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late final input = TextEditingController(
    text: '#${(widget.initial & 0xffffff).toRadixString(16).padLeft(6, '0')}',
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    final value = input.text.trim().replaceFirst('#', '');
    if (RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(value)) {
      Navigator.pop(context, 0xff000000 | int.parse(value, radix: 16));
    }
  }

  @override
  Widget build(BuildContext context) => _formDialog(
    context,
    title: Text(widget.english ? 'Color HEX' : 'Цвет HEX'),
    content: TextField(
      controller: input,
      autofocus: true,
      maxLength: 7,
      onSubmitted: (_) => submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.english ? 'Cancel' : 'Отмена'),
      ),
      TextButton(
        onPressed: submit,
        child: Text(widget.english ? 'Apply' : 'Применить'),
      ),
    ],
  );
}

class _NameDialog extends StatefulWidget {
  final String initial;
  final bool english;
  const _NameDialog({required this.initial, required this.english});
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    if (input.text.trim().isNotEmpty) Navigator.pop(context, input.text.trim());
  }

  @override
  Widget build(BuildContext c) => _formDialog(
    c,
    content: TextField(
      controller: input,
      autofocus: true,
      onSubmitted: (_) => submit(),
    ),
    actions: [
      TextButton(
        onPressed: submit,
        child: Text(widget.english ? 'Save' : 'Сохранить'),
      ),
    ],
  );
}
