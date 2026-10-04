import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../core/store.dart';
import '../core/track.dart';
import '../library/library.dart';
import '../library/delete_tracks.dart';
import '../playback/queue.dart';
import 'glass.dart';
import 'visualizer.dart' as visuals;
import 'settings_panel.dart';

// Root interface. Library/queue own data changes; the exit callback performs full shutdown.
class TaktApp extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  final bool promptForFolder;
  final MusicLibrary library;
  final TaktQueue queue;
  final TaktStore store;
  final List<double> Function()? amplitudes;
  final Future<void> Function()? exit;
  const TaktApp({
    super.key,
    this.onSettingsChanged,
    this.promptForFolder = false,
    required this.library,
    required this.queue,
    required this.store,
    this.amplitudes,
    this.exit,
  });
  @override
  State<TaktApp> createState() => _TaktAppState();
}

class _TaktAppState extends State<TaktApp> {
  MusicLibrary get library => widget.library;
  TaktQueue get queue => widget.queue;
  // Stored under settings; string keys must stay consistent with main.dart and DesktopLifecycle.
  late Map<String, dynamic> settings;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final search = TextEditingController(),
      playlistName = TextEditingController();
  String? playlist, folder;
  bool creating = false, folders = false, showQueue = false, volumeOpen = false;
  bool showFavorites = false, settingsOpen = false;
  String get viewKey => showFavorites ? 'favorites' : playlist ?? 'all';
  final selected = <String>{};
  bool get dark => settings['dark'] == true;
  bool get en => settings['locale'] == 'en';
  Color get accent => Color(settings['accent'] ?? 0xff777777);
  // Keep Russian and English labels together; supply both translations for new text.
  String tr(String ru, String english) => en ? english : ru;
  @override
  // First-launch defaults; persisted settings take precedence.
  void initState() {
    super.initState();
    settings = Map<String, dynamic>.from(
      widget.store.read('settings') ??
          {
            'dark': false,
            'locale':
                WidgetsBinding
                        .instance
                        .platformDispatcher
                        .locale
                        .languageCode ==
                    'en'
                ? 'en'
                : 'ru',
            'accent': 0xff777777,
            'volume': 70.0,
            'closeToTray': true,
            'onlineArtwork': false,
            'wave': false,
          },
    );
    library.addListener(changed);
    queue.addListener(changed);
    if (widget.promptForFolder) {
      WidgetsBinding.instance.addPostFrameCallback((_) => chooseFolder());
    }
  }

  void changed() {
    // External MPRIS volume changes must not be overwritten by later UI settings.
    final persisted = widget.store.read('settings') as Map?;
    if (persisted?['volume'] != null) settings['volume'] = persisted!['volume'];
    if (mounted) setState(() {});
  }

  // Persist and notify audio/artwork/tray through onSettingsChanged.
  void saveSettings() {
    widget.store.write('settings', settings);
    widget.onSettingsChanged?.call();
    changed();
  }

  @override
  void dispose() {
    library.removeListener(changed);
    queue.removeListener(changed);
    search.dispose();
    playlistName.dispose();
    super.dispose();
  }

  void message(String text) {
    messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }

  // Choose a system directory, then connect the source and refresh the library.
  Future<void> chooseFolder() async {
    try {
      final path = await FilePicker.getDirectoryPath();
      if (path != null) {
        await library.addSource(path);
        if (library.error != null) message(library.error!);
      }
    } catch (error) {
      message(error.toString());
    }
  }

  // Immediate children of the current source for folder navigation.
  List<String> get childFolders {
    if (folder == null) return [];
    final prefix = '$folder/';
    final result = <String>{};
    for (final t in library.tracks.where(
      (t) => t.available && t.path.startsWith(prefix),
    )) {
      final parts = t.path.substring(prefix.length).split('/');
      if (parts.length > 1) result.add('$folder/${parts.first}');
    }
    return result.toList()..sort();
  }

  // One visible list: either the queue or the library with current filters.
  List<Track> get shown {
    if (showQueue) {
      return [
        for (final id in queue.ids)
          for (final t in library.tracks)
            if (t.id == id &&
                t.title.toLowerCase().contains(search.text.toLowerCase()))
              t,
      ];
    }
    return library
        .visible(
          query: search.text,
          playlist: playlist,
          folder: folder,
          favoritesOnly: showFavorites,
          manual: widget.store.read('manual:$viewKey') == true,
        )
        .where((t) => !showFavorites || library.favorites.contains(t.id))
        .toList();
  }

  // Playback keys are inactive inside text editing, while Super+Q remains global.
  void _shortcut(Future<void> Function() action) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context?.widget is EditableText ||
        context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return;
    }
    action().catchError((Object error) => message(error.toString()));
  }

  Future<void> _seekBy(int direction) async {
    final track = queue.current;
    if (track == null || track.seconds <= 0) return;
    final step = settings['seekStep'] as int? ?? 5;
    final target = (queue.position.inMilliseconds + direction * step * 1000)
        .clamp(0, (track.seconds * 1000).round());
    await queue.seek(Duration(milliseconds: target));
  }

  Future<void> _volumeBy(double delta) async {
    final volume = ((settings['volume'] as num? ?? 70).toDouble() + delta)
        .clamp(0.0, 100.0);
    settings['volume'] = volume;
    saveSettings();
    await queue.engine.volume(volume);
  }

  @override
  // Theme and overall layout: sidebar, main content and bottom playback panel.
  Widget build(BuildContext context) {
    final ink = dark ? const Color(0xffeeeeee) : const Color(0xff202020);
    final control = accent.toARGB32() == 0xff777777 ? ink : accent;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: dark ? Brightness.dark : Brightness.light,
          ).copyWith(
            primary: control,
            onPrimary: control.computeLuminance() > .4
                ? Colors.black
                : Colors.white,
            secondary: control,
            secondaryContainer: dark
                ? const Color(0xff3a3b3c)
                : const Color(0xffe1e2e3),
            onSecondaryContainer: ink,
            surfaceContainerHighest: dark
                ? const Color(0xff303132)
                : const Color(0xffe9eaeb),
            surfaceTint: Colors.transparent,
            surface: dark ? const Color(0xff191a1b) : const Color(0xfffafafa),
            onSurface: dark ? const Color(0xffeeeeee) : const Color(0xff202020),
          ),
      scaffoldBackgroundColor: dark
          ? const Color(0xff101112)
          : const Color(0xfff4f4f4),
      fontFamily: 'sans',
      sliderTheme: SliderThemeData(
        activeTrackColor: control,
        thumbColor: control,
        inactiveTrackColor: ink.withValues(alpha: .15),
        overlayColor: control.withValues(alpha: .1),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark
            ? const Color(0xff252627)
            : const Color(0xfff4f4f4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    return MaterialApp(
      // Super+Q invokes full exit, including while a text field has keyboard focus.
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyQ, meta: true): () {
            widget.exit?.call();
          },
          const _PlaybackActivator(LogicalKeyboardKey.space): () =>
              _shortcut(() => queue.toggle()),
          const _PlaybackActivator(LogicalKeyboardKey.arrowLeft): () =>
              _shortcut(() => _seekBy(-1)),
          const _PlaybackActivator(LogicalKeyboardKey.arrowRight): () =>
              _shortcut(() => _seekBy(1)),
          const _PlaybackActivator(
            LogicalKeyboardKey.arrowLeft,
            control: true,
          ): () =>
              _shortcut(() => queue.previous()),
          const _PlaybackActivator(
            LogicalKeyboardKey.arrowRight,
            control: true,
          ): () =>
              _shortcut(() => queue.next()),
          const _PlaybackActivator(LogicalKeyboardKey.arrowUp): () =>
              _shortcut(() => _volumeBy(5)),
          const _PlaybackActivator(LogicalKeyboardKey.arrowDown): () =>
              _shortcut(() => _volumeBy(-5)),
        },
        child: Focus(autofocus: true, child: child!),
      ),
      scaffoldMessengerKey: messenger,
      title: 'Takt',
      locale: Locale(en ? 'en' : 'ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (c, area) {
                        final panel = SettingsPanel(
                          key: const Key('settings-panel'),
                          settings: settings,
                          library: library,
                          save: saveSettings,
                          close: () => setState(() => settingsOpen = false),
                          chooseFolder: chooseFolder,
                          quit: widget.exit,
                        );
                        final wide = area.maxWidth >= 1000;
                        return Stack(
                          children: [
                            Row(
                              children: [
                                _sidebar(ctx),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: animatedPage(
                                    KeyedSubtree(
                                      key: ValueKey(
                                        '$viewKey:$showQueue:$folders:$folder',
                                      ),
                                      child: _body(ctx),
                                    ),
                                  ),
                                ),
                                if (wide)
                                  AnimatedSize(
                                    duration: interfaceDuration,
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.centerRight,
                                    child: settingsOpen
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              left: 16,
                                            ),
                                            child: SizedBox(
                                              width: 360,
                                              child: animatedPage(panel),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                            if (!wide)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                right: 0,
                                width: math.min(380, area.maxWidth - 76),
                                child: IgnorePointer(
                                  ignoring: !settingsOpen,
                                  child: animatedPage(
                                    settingsOpen
                                        ? panel
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _player(ctx),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Shared glass material: blur, transparency and corners. Adjust the effect here.
  Widget _glass(
    Widget child, {
    BorderRadius radius = const BorderRadius.all(Radius.circular(22)),
  }) => GlassSurface(
    dark: dark,
    enabled: settings['glass'] != false,
    radius: radius.topLeft.x,
    child: child,
  );
  // Left function panel; its bottom section places settings above playback controls.
  Widget _sidebar(BuildContext ctx) => SizedBox(
    width: MediaQuery.sizeOf(ctx).width < 650 ? 62 : 178,
    child: _glass(
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                      child: MediaQuery.sizeOf(ctx).width < 650
                          ? const Center(
                              child: Text('T', style: TextStyle(fontSize: 24)),
                            )
                          : const Text(
                              'Takt',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -1,
                              ),
                            ),
                    ),
                    _nav(
                      ctx,
                      Icons.music_note,
                      tr('Моя музыка', 'My music'),
                      () {
                        setState(() {
                          folders = false;
                          folder = null;
                          playlist = null;
                          showQueue = false;
                          showFavorites = false;
                          selected.clear();
                        });
                      },
                    ),
                    _nav(
                      ctx,
                      Icons.star_outline,
                      tr('Избранное', 'Favorites'),
                      () {
                        setState(() {
                          showFavorites = true;
                          showQueue = false;
                          folders = false;
                          playlist = null;
                          folder = null;
                          selected.clear();
                        });
                      },
                    ),
                    _nav(
                      ctx,
                      Icons.folder_outlined,
                      tr('Папки', 'Folders'),
                      () {
                        setState(() {
                          folders = true;
                          playlist = null;
                          folder = null;
                          showQueue = false;
                          showFavorites = false;
                          selected.clear();
                        });
                      },
                    ),
                    _nav(
                      ctx,
                      Icons.playlist_add,
                      tr('Новый плейлист', 'New playlist'),
                      () {
                        setState(() => creating = !creating);
                      },
                    ),
                  ],
                ),
              ),
            ),
            _nav(
              ctx,
              Icons.settings_outlined,
              tr('Настройки', 'Settings'),
              () => _settings(ctx),
            ),
          ],
        ),
      ),
    ),
  );
  // One navigation button: icon, label and active-state appearance.
  Widget _nav(
    BuildContext ctx,
    IconData icon,
    String title,
    VoidCallback action,
  ) => TextButton(
    onPressed: action,
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      foregroundColor: Theme.of(ctx).colorScheme.onSurface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        if (MediaQuery.sizeOf(ctx).width >= 650) ...[
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ],
    ),
  );
  // Main area: heading/theme, tabs, search or creation form, list and drag animation.
  Widget _body(BuildContext ctx) {
    final rows = shown;
    final heading = showQueue
        ? tr('Текущая очередь', 'Current queue')
        : showFavorites
        ? tr('Избранное', 'Favorites')
        : folders
        ? tr('Папки', 'Folders')
        : playlist == null
        ? tr('Моя музыка', 'My music')
        : library.playlists.firstWhere((p) => p.id == playlist).name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: DragToMoveArea(
                  child: Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: tr('Тёмная тема', 'Dark theme'),
                child: InkWell(
                  onTap: () {
                    settings['dark'] = !dark;
                    saveSettings();
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 56,
                    height: 30,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.onSurface
                          .withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      alignment: dark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (library.scanning) const LinearProgressIndicator(minHeight: 2),
        if (folders && folder == null)
          Expanded(
            child: ListView(
              children: [
                for (final source in library.sources)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(source),
                    onTap: () => setState(() => folder = source),
                  ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(tr('Добавить папку', 'Add folder')),
                  onTap: chooseFolder,
                ),
              ],
            ),
          )
        else ...[
          if (!showQueue && !folders && !showFavorites)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tab(
                  ctx,
                  tr('Все треки', 'All tracks'),
                  playlist == null,
                  () => setState(() {
                    playlist = null;
                    selected.clear();
                  }),
                ),
                for (final p in library.playlists)
                  GestureDetector(
                    onSecondaryTap: () => _playlistMenu(ctx, p),
                    onLongPress: () => _playlistMenu(ctx, p),
                    child: _tab(
                      ctx,
                      p.name,
                      playlist == p.id,
                      () => setState(() {
                        playlist = p.id;
                        selected.clear();
                      }),
                    ),
                  ),
                IconButton(
                  key: const Key('new-playlist'),
                  tooltip: tr('Создать плейлист', 'Create playlist'),
                  onPressed: () => setState(() => creating = !creating),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: interfaceDuration,
            curve: Curves.easeOutCubic,
            child: animatedPage(
              creating
                  ? Row(
                      key: const ValueKey("playlist-form"),
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('playlist-create'),
                            controller: playlistName,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: tr(
                                'Название плейлиста',
                                'Playlist name',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _createPlaylist(),
                          ),
                        ),
                        TextButton(
                          onPressed: _createPlaylist,
                          child: Text(tr('Создать', 'Create')),
                        ),
                        IconButton(
                          onPressed: () => setState(() => creating = false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    )
                  : TextField(
                      key: const Key('track-search'),
                      controller: search,
                      onChanged: (_) => changed(),
                      decoration: InputDecoration(
                        hintText: tr('Поиск треков', 'Search tracks'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
            ),
          ),
          if (folders && folder != null)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final child in childFolders)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(child.split('/').last),
                        onPressed: () => setState(() => folder = child),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${rows.length} ${tr('треков', 'tracks')}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface
                      .withValues(alpha: .5),
                ),
              ),
              const Spacer(),
              if (selected.isNotEmpty) ...[
                Text('${selected.length}'),
                IconButton(
                  onPressed: () => _batchMenu(ctx),
                  icon: const Icon(Icons.more_horiz),
                ),
                IconButton(
                  onPressed: () => setState(selected.clear),
                  icon: const Icon(Icons.close),
                ),
              ],
              if (folder != null)
                IconButton(
                  onPressed: () => setState(
                    () => folder = library.sources.contains(folder)
                        ? null
                        : Directory(folder!).parent.path,
                  ),
                  icon: const Icon(Icons.arrow_back),
                ),
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: dark ? const Color(0xff252627) : const Color(0xfff4f4f4),
                surfaceTintColor: Colors.transparent,
                popUpAnimationStyle: AnimationStyle(
                  duration: interfaceDuration,
                  reverseDuration: interfaceDuration,
                  curve: Curves.easeOutCubic,
                ),
                icon: const Icon(Icons.sort),
                onSelected: (v) {
                  if (v == 'name') {
                    widget.store.write('manual:$viewKey', false);
                  } else {
                    widget.store.write('manual:$viewKey', true);
                  }
                  changed();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'name',
                    child: Text(tr('По названию', 'By title')),
                  ),
                  PopupMenuItem(
                    value: 'manual',
                    child: Text(tr('Ручной порядок', 'Manual order')),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.library_music_outlined, size: 40),
                          const SizedBox(height: 16),
                          Text(
                            tr('Здесь пока нет музыки', 'No music here yet'),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: chooseFolder,
                            icon: const Icon(Icons.folder_open),
                            label: Text(tr('Выбрать папку', 'Choose folder')),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) =>
                        AnimatedBuilder(
                          animation: animation,
                          child: child,
                          builder: (ctx, child) => Transform.scale(
                            scale: 1 + animation.value * .015,
                            child: Material(
                              color: Theme.of(ctx).colorScheme.surface,
                              elevation: 8,
                              borderRadius: BorderRadius.circular(16),
                              child: child,
                            ),
                          ),
                        ),
                    itemCount: rows.length,
                    onReorderItem: (from, to) {
                      final ids = rows.map((t) => t.id).toList();
                      final id = ids.removeAt(from);
                      ids.insert(to, id);
                      if (showQueue) {
                        queue.reorderVisible(ids);
                      } else {
                        final base = library
                            .visible(
                              playlist: playlist,
                              favoritesOnly: showFavorites,
                              manual:
                                  widget.store.read('manual:$viewKey') == true,
                            )
                            .map((t) => t.id)
                            .toList();
                        library.reorder(
                          ids,
                          playlist: playlist,
                          favoritesOnly: showFavorites,
                          baseOrder: base,
                        );
                        widget.store.write('manual:$viewKey', true);
                      }
                      changed();
                    },
                    itemBuilder: (ctx, i) => _row(ctx, rows[i], i, rows),
                  ),
          ),
        ],
        if (library.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              library.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
      ],
    );
  }

  // Appearance shared by the All Tracks tab and playlist tabs.
  Widget _tab(
    BuildContext ctx,
    String text,
    bool active,
    VoidCallback action,
  ) => TextButton(
    onPressed: action,
    style: TextButton.styleFrom(
      backgroundColor: active
          ? Theme.of(ctx).colorScheme.surface
          : Colors.transparent,
      foregroundColor: Theme.of(ctx).colorScheme.onSurface,
    ),
    child: Text(text),
  );
  // Create from the temporary input, then hide and clear that input.
  void _createPlaylist() {
    if (playlistName.text.trim().isEmpty) return;
    playlist = library.createPlaylist(playlistName.text);
    showFavorites = false;
    showQueue = false;
    folders = false;
    folder = null;
    selected.clear();
    search.clear();
    playlistName.clear();
    setState(() => creating = false);
  }

  // Local artwork or placeholder, shared by track rows and the playback panel.
  Widget _art(Track? track, {double size = 40}) {
    if (track?.artwork != null && File(track!.artwork!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(track.artwork!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => Icon(Icons.music_note, size: size / 2),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: .3), accent.withValues(alpha: .08)],
        ),
      ),
      child: Icon(Icons.music_note_outlined, size: size / 2, color: accent),
    );
  }

  // Full track row: tap plays/selects, body hold selects, handle hold drags.
  Widget _row(
    BuildContext ctx,
    Track t,
    int index,
    List<Track> list,
  ) => Container(
    key: ValueKey(t.id),
    margin: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(
      color: selected.contains(t.id)
          ? accent.withValues(alpha: .2)
          : queue.currentId == t.id
          ? Theme.of(ctx).colorScheme.surface
          : null,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (selected.isNotEmpty) {
                setState(
                  () => selected.contains(t.id)
                      ? selected.remove(t.id)
                      : selected.add(t.id),
                );
              } else {
                queue.start(list.map((t) => t.id).toList(), t.id).catchError((
                  Object e,
                ) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                });
              }
            },
            onLongPress: () => setState(() => selected.add(t.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 0, 10),
              child: Row(
                children: [
                  _art(t),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          t.artist.isEmpty
                              ? tr('Неизвестный исполнитель', 'Unknown artist')
                              : t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurface
                                .withValues(alpha: .5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.sizeOf(ctx).width > 650)
                    Text(
                      _time(Duration(seconds: t.seconds.toInt())),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          // A long-press Tooltip on this handle can steal the drag gesture; keep it disabled.
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: Semantics(
              label: tr(
                'Меню. Удерживай для перемещения',
                'Menu. Hold to move',
              ),
              button: true,
              child: Builder(
                builder: (buttonCtx) => IconButton(
                  icon: const Icon(Icons.menu, size: 20),
                  onPressed: () async {
                    final action = await showGlassMenu<String>(
                      context: ctx,
                      anchor: buttonCtx,
                      dark: dark,
                      glass: settings['glass'] != false,
                      estimatedHeight: 520,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _actions(t),
                        ),
                      ),
                    );
                    if (action != null && ctx.mounted) {
                      await _trackAction(ctx, action, [t.id]);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  // Track menu entries; their string values are handled by _trackAction.
  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      );
  List<PopupMenuEntry<String>> _actions([Track? track]) => [
    _menuItem(
      'queue',
      Icons.playlist_add,
      tr('Добавить в очередь', 'Add to queue'),
    ),
    _menuItem(
      'playlist',
      Icons.playlist_add,
      tr('Добавить в плейлист', 'Add to playlist'),
    ),
    _menuItem(
      'favorite',
      library.favorites.contains(track?.id) ? Icons.star : Icons.star_outline,
      library.favorites.contains(track?.id)
          ? tr('Убрать из избранного', 'Remove from favorites')
          : tr('Добавить в избранное', 'Add to favorites'),
    ),
    _menuItem('select', Icons.check, tr('Выделить', 'Select')),
    _menuItem('rename', Icons.edit_outlined, tr('Переименовать', 'Rename')),
    _menuItem(
      'art',
      Icons.image_outlined,
      tr('Изменить обложку', 'Change artwork'),
    ),
    if (playlist != null)
      _menuItem(
        'remove',
        Icons.playlist_remove,
        tr('Убрать из плейлиста', 'Remove from playlist'),
      ),
    if (showQueue)
      _menuItem(
        'removequeue',
        Icons.playlist_remove,
        tr('Убрать из очереди', 'Remove from queue'),
      ),
    _menuItem('info', Icons.info_outline, tr('Сведения', 'Details')),
    const PopupMenuDivider(),
    _menuItem(
      'delete',
      Icons.delete_outline,
      tr('Удалить с устройства', 'Delete from device'),
    ),
  ];
  // Shared name/color input dialog; cancellation returns null.
  Future<String?> _textDialog(
    BuildContext ctx,
    String title,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    final result = await showTaktDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
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
    // The outgoing dialog still owns its field during the reverse transition.
    Future<void>.delayed(
      interfaceDuration + const Duration(milliseconds: 50),
      controller.dispose,
    );
    return result;
  }

  // Rename/delete a playlist without physically deleting its music.
  Future<void> _playlistMenu(BuildContext ctx, Playlist p) async {
    final action = await showTaktDialog<String>(
      context: ctx,
      builder: (c) => SimpleDialog(
        title: Text(p.name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'rename'),
            child: Text(tr('Переименовать', 'Rename')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'delete'),
            child: Text(tr('Удалить плейлист', 'Delete playlist')),
          ),
        ],
      ),
    );
    if (!ctx.mounted) return;
    if (action == 'rename') {
      final name = await _textDialog(
        ctx,
        tr('Название плейлиста', 'Playlist name'),
        p.name,
      );
      if (name != null) library.renamePlaylist(p.id, name);
    }
    if (action == 'delete') {
      if (playlist == p.id) playlist = null;
      library.deletePlaylist(p.id);
    }
  }

  // Batch actions reuse the same handler as individual track actions.
  Future<void> _batchMenu(BuildContext ctx) async {
    final action = await showTaktDialog<String>(
      context: ctx,
      builder: (c) => SimpleDialog(
        title: Text(tr('Выбранные треки', 'Selected tracks')),
        children: [
          for (final a in [
            'queue',
            'playlist',
            if (playlist != null) 'remove',
            'delete',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, a),
              child: Text(
                {
                  'queue': tr('Добавить в очередь', 'Add to queue'),
                  'playlist': tr('Добавить в плейлист', 'Add to playlist'),
                  'remove': tr('Убрать из плейлиста', 'Remove from playlist'),
                  'delete': tr('Удалить с устройства', 'Delete from device'),
                }[a]!,
              ),
            ),
        ],
      ),
    );
    if (action != null && ctx.mounted) {
      await _trackAction(ctx, action, selected.toList());
    }
  }

  // Menu dispatcher. Confirmation separates physical deletion from removing playlist/queue references.
  Future<void> _trackAction(
    BuildContext ctx,
    String action,
    List<String> ids,
  ) async {
    final t = library.tracks.firstWhere((t) => t.id == ids.first);
    void note(String text) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    try {
      switch (action) {
        case 'next':
          if (!queue.addNext(t.id)) {
            note(tr('Трек уже есть в очереди', 'Track is already in queue'));
          }
          break;
        case 'queue':
          int added = 0;
          for (final id in ids) {
            if (queue.add(id)) added++;
          }
          note(
            added == 0
                ? tr('Трек уже есть в очереди', 'Track is already in queue')
                : tr('Добавлено: $added', 'Added: $added'),
          );
          break;
        case 'favorite':
          library.toggleFavorite(ids);
          break;
        case 'select':
          setState(() => selected.addAll(ids));
          break;
        case 'rename':
          final name = await _textDialog(
            ctx,
            tr('Название в Takt', 'Title in Takt'),
            t.title,
          );
          if (name != null) library.rename(t.id, name);
          break;
        case 'art':
          final path = await const MethodChannel('takt/artwork_picker')
              .invokeMethod<String>('pick', {
                'title': tr('Выбрать обложку', 'Choose artwork'),
                'cancel': tr('Отмена', 'Cancel'),
                'open': tr('Открыть', 'Open'),
              });
          if (path != null) await library.setArtwork(t.id, path);
          break;
        case 'playlist':
          final choice = await showTaktDialog<String>(
            context: ctx,
            builder: (c) => SimpleDialog(
              title: Text(tr('Выбрать плейлист', 'Choose playlist')),
              children: [
                for (final p in library.playlists)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, p.id),
                    child: Text(p.name),
                  ),
                if (library.playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tr('Сначала создай плейлист', 'Create a playlist first'),
                    ),
                  ),
              ],
            ),
          );
          if (choice != null) {
            final count = library.addToPlaylist(choice, ids);
            note(
              count == 0
                  ? tr(
                      'Трек уже есть в плейлисте',
                      'Track is already in playlist',
                    )
                  : tr('Добавлено: $count', 'Added: $count'),
            );
          }
          break;
        case 'remove':
          if (playlist != null) library.removeFromPlaylist(playlist!, ids);
          selected.clear();
          break;
        case 'removequeue':
          for (final id in ids) {
            await queue.remove(id);
          }
          break;
        case 'info':
          await showTaktDialog<void>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: Text(t.title),
              content: SelectableText('${t.artist}\n${t.album}\n${t.path}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(tr('Закрыть', 'Close')),
                ),
              ],
            ),
          );
          break;
        case 'delete':
          final confirmed = await showTaktDialog<bool>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: Text(
                tr('Удалить файлы с устройства?', 'Delete files from device?'),
              ),
              content: Text(
                tr(
                  'Будет удалено файлов: ${ids.length}. Это действие нельзя отменить.',
                  'Files to delete: ${ids.length}. This cannot be undone.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(tr('Отмена', 'Cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(tr('Удалить', 'Delete')),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            final results = await deleteTracks(
              library.tracks.where((t) => ids.contains(t.id)).toList(),
              confirmed: true,
            );
            for (final result in results) {
              if (result.success) await queue.remove(result.track.id);
            }
            library.persist();
            selected.clear();
            final deleted = results.where((r) => r.success).length;
            final failed = results
                .where((r) => !r.success)
                .map((r) => '${r.track.title}: ${r.error}')
                .join('\n');
            note(
              '${tr('Удалено: $deleted из ${ids.length}', 'Deleted: $deleted of ${ids.length}')}\n$failed',
            );
          }
          break;
      }
    } catch (error) {
      note(error.toString());
    }
    changed();
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  // Bottom panel: left artwork, centered title/controls, right visualizer and timeline.
  Widget _player(BuildContext ctx) {
    final ink = Theme.of(ctx).colorScheme.onSurface;
    final current = queue.current;
    final center = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          current?.title ?? tr('Выбери музыку', 'Choose music'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          current?.artist ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ink.withValues(alpha: .5), fontSize: 12),
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: [
                    tr('По кругу', 'Loop'),
                    tr('Один проход', 'Once'),
                    tr('Перемешивание', 'Shuffle'),
                    tr('Повтор трека', 'Repeat track'),
                  ][queue.mode.index],
                  onPressed: () {
                    queue.mode = QueueMode.values[(queue.mode.index + 1) % 4];
                    queue.save();
                    changed();
                  },
                  icon: Icon(
                    [
                      Icons.repeat,
                      Icons.playlist_play,
                      Icons.shuffle,
                      Icons.repeat_one,
                    ][queue.mode.index],
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: () => queue.previous(),
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Theme.of(ctx).colorScheme.surface,
                  ),
                  onPressed: () => queue.toggle(),
                  icon: Icon(queue.playing ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  onPressed: () => queue.next(),
                  icon: const Icon(Icons.skip_next),
                ),
                Builder(
                  builder: (buttonCtx) => IconButton(
                    tooltip: tr('Громкость', 'Volume'),
                    onPressed: () => _volume(buttonCtx),
                    icon: const Icon(Icons.volume_up_outlined, size: 20),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              child: IconButton(
                tooltip: tr('Очередь', 'Queue'),
                onPressed: () => _queueMenu(ctx),
                icon: const Icon(Icons.queue_music_outlined, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _seek(ctx),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _time(queue.position),
              style: TextStyle(color: ink.withValues(alpha: .5), fontSize: 11),
            ),
            Text(
              _time(Duration(seconds: current?.seconds.toInt() ?? 0)),
              style: TextStyle(color: ink.withValues(alpha: .5), fontSize: 11),
            ),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: LayoutBuilder(
        builder: (ctx, size) {
          if (size.maxWidth < 600) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings['visualizerEnabled'] != false)
                  SizedBox(height: 24, width: 110, child: _signal(ink)),
                center,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => _queueMenu(ctx),
                    child: _glass(
                      _art(current, size: 96),
                      radius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(child: center),
              const SizedBox(width: 28),
              SizedBox(
                width: 120,
                height: 60,
                child: settings['visualizerEnabled'] != false
                    ? _signal(ink)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  // Convert pointer coordinates to playback position; SeekPainter controls the appearance.
  Widget _signal(Color ink) => visuals.WaveSignal(
    values: widget.amplitudes?.call() ?? [],
    color: settings['visualizerColor'] == null
        ? ink
        : Color(settings['visualizerColor']),
    bars: settings['visualizerStyle'] == 'bars',
    smoothness: (settings['visualizerSmoothness'] as num? ?? .5).toDouble(),
  );

  Widget _seek(BuildContext ctx) => LayoutBuilder(
    builder: (ctx, size) {
      final total = queue.current?.seconds ?? 0;
      final ratio = total <= 0
          ? 0.0
          : (queue.position.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
      return GestureDetector(
        onTapDown: (d) {
          if (total > 0) {
            queue.seek(
              Duration(
                milliseconds:
                    (d.localPosition.dx / size.maxWidth * total * 1000)
                        .round()
                        .clamp(0, (total * 1000).round()),
              ),
            );
          }
        },
        onHorizontalDragUpdate: (d) {
          if (total > 0) {
            queue.seek(
              Duration(
                milliseconds:
                    (d.localPosition.dx / size.maxWidth * total * 1000)
                        .round()
                        .clamp(0, (total * 1000).round()),
              ),
            );
          }
        },
        child: Semantics(
          label: tr('Перемотка', 'Seek'),
          child: SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              painter: SeekPainter(ratio, settings['wave'] == true, dark),
            ),
          ),
        ),
      );
    },
  );
  // Volume popup updates the engine and persists the chosen setting.
  Future<void> _volume(BuildContext ctx) async {
    await showGlassMenu<void>(
      context: ctx,
      anchor: ctx,
      dark: dark,
      glass: settings['glass'] != false,
      width: 250,
      estimatedHeight: 88,
      above: true,
      child: StatefulBuilder(
        builder: (c, update) => Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.volume_up_outlined, size: 20),
              Expanded(
                child: Slider(
                  key: const Key('volume-slider'),
                  value: (settings['volume'] as num? ?? 70).toDouble(),
                  min: 0,
                  max: 100,
                  onChanged: (v) {
                    settings['volume'] = v;
                    queue.engine.volume(v);
                    saveSettings();
                    update(() {});
                  },
                ),
              ),
              Text(
                '${(settings['volume'] as num? ?? 70).round()}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Switch the main area to the current queue and reset conflicting filters.
  Future<void> _queueMenu(BuildContext ctx) async {
    await showTaktDialog<void>(
      context: ctx,
      builder: (c) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(c);
              setState(() {
                showQueue = true;
                folders = false;
                playlist = null;
                selected.clear();
              });
            },
            child: Text(tr('Текущая очередь', 'Current queue')),
          ),
        ],
      ),
    );
  }

  // Settings dialog: language, timeline, tray, online covers, accent, sources and full exit.
  void _settings(BuildContext ctx) =>
      setState(() => settingsOpen = !settingsOpen);
}

// Straight/wavy timeline and contrasting handle; change their geometry and colors here.
class SeekPainter extends CustomPainter {
  final double ratio;
  final bool wave, dark;
  SeekPainter(this.ratio, this.wave, this.dark);
  double y(double x) => 14 + (wave ? math.sin(x / 12) * 4 : 0);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dark ? Colors.white : Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, y(0));
    for (double x = 1; x <= size.width; x++) {
      path.lineTo(x, y(x));
    }
    canvas.drawPath(path, paint);
    final x = ratio * size.width;
    canvas.drawCircle(
      Offset(x, y(x)),
      6,
      Paint()..color = dark ? Colors.white : Colors.black,
    );
    canvas.drawCircle(
      Offset(x, y(x)),
      3,
      Paint()..color = dark ? Colors.black : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant SeekPainter old) =>
      old.ratio != ratio || old.wave != wave || old.dark != dark;
}

// Solid visualizer silhouette from amplitude values; change its shape and fill here.
class WavePainter extends visuals.WavePainter {
  WavePainter(super.values, super.color, {super.bars});
}

// Smooth interpolation between actual amplitude arrays without random signal generation.
class SignalTween extends visuals.SignalTween {
  SignalTween({super.end});
}

// Animate new real data; TweenAnimationBuilder duration determines smoothness.
class _PlaybackActivator extends SingleActivator {
  const _PlaybackActivator(super.trigger, {super.control});

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.widget is EditableText ||
        focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    return super.accepts(event, state);
  }
}

class WaveSignal extends visuals.WaveSignal {
  const WaveSignal({
    super.key,
    required super.values,
    required super.color,
    super.bars,
    super.smoothness,
  });
}
