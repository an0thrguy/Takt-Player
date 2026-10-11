import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/android_library.dart';
import '../core/store.dart';
import '../core/track.dart';
import '../library/library.dart';
import '../library/delete_tracks.dart';
import '../playback/queue.dart';
import '../playback/sleep_timer.dart';
import 'sleep_timer_dialog.dart';
import 'compact_player.dart';
import 'glass.dart';
import 'playlist_dialog.dart';
import 'volume_control.dart';
import 'resizable_sidebar.dart';
import 'window_close_button.dart';
import 'appearance.dart';
import 'appearance_editor.dart';
import 'backdrop_layers.dart';
import 'layout_preferences.dart';
import 'layout_editor.dart';
import '../library/library_views.dart';

import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import 'presentation_preferences.dart';
import 'presentation_scope.dart';
import 'visualizer.dart' as visuals;
import 'settings_panel.dart';

part 'mobile_shell.dart';

// Root interface. Library/queue own data changes; the exit callback performs full shutdown.
class TaktApp extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  final ValueChanged<bool>? onVisualDemandChanged;
  final bool promptForFolder;
  final bool mobile;
  final Future<String?> Function()? pickImage;
  final SleepTimer? sleepTimer;
  final Future<void> Function(bool compact, bool alwaysOnTop)? onCompactChanged;
  final MusicLibrary library;
  final TaktQueue queue;
  final TaktStore store;
  final List<double> Function()? amplitudes;
  final Future<void> Function()? exit, close;
  const TaktApp({
    super.key,
    this.onSettingsChanged,
    this.onVisualDemandChanged,
    this.promptForFolder = false,
    this.mobile = false,
    this.pickImage,
    this.sleepTimer,
    this.onCompactChanged,
    required this.library,
    required this.queue,
    required this.store,
    this.amplitudes,
    this.exit,
    this.close,
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
  final navigator = GlobalKey<NavigatorState>();
  final search = TextEditingController();
  bool playlistDialogOpen = false;
  int mobilePage = 0;
  void mobileChanged(VoidCallback action) => setState(action);
  String? playlist, folder, specialView;
  String? groupId;
  late final views = LibraryViews(widget.store);
  String? lastPlayedId;
  bool lastPlaying = false;
  bool compact = false;
  bool? layoutCollapsedDraft;
  bool _compactChanging = false;
  bool _opacityUnsupported = false;
  double? _lastOpacity;
  late final SleepTimer sleep =
      widget.sleepTimer ??
      SleepTimer(
        pause: queue.stop,
        quit: widget.exit ?? () async {},
        setVolume: queue.engine.volume,
        getVolume: () => (settings['volume'] as num? ?? 70).toDouble(),
        onError: (e) => message(e.toString()),
      );
  bool layoutEditing = false;
  Map<String, dynamic>? layoutDraft;
  LayoutPreferences get layoutPreferences => LayoutPreferences.fromMap(
    layoutDraft ??
        (displaySettings['layout'] is Map
            ? Map<String, dynamic>.from(displaySettings['layout'])
            : {'sidebarWidth': settings['sidebarWidth'] ?? 178}),
  );
  bool folders = false, showQueue = false;
  bool showFavorites = false, settingsOpen = false;
  String get viewKey =>
      specialView ?? (showFavorites ? 'favorites' : playlist ?? 'all');
  final selected = <String>{};
  Map<String, dynamic>? appearancePreview;
  bool appearanceDialogOpen = false;
  Map<String, dynamic> get displaySettings => appearancePreview ?? settings;
  bool get dark => displaySettings['dark'] == true;
  AppearanceProfile get appearanceProfile =>
      AppearanceDraft(displaySettings).profile(dark);
  bool get customAppearance =>
      displaySettings[dark ? 'appearanceDark' : 'appearanceLight'] is Map;

  bool get en => settings['locale'] == 'en';
  Color get accent => Color(
    customAppearance
        ? appearanceProfile.accent
        : settings['accent'] ?? 0xff777777,
  );
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
    sleep.addListener(changed);
    library.addListener(changed);
    queue.addListener(queueChanged);
    queueChanged();
    if (widget.promptForFolder) {
      WidgetsBinding.instance.addPostFrameCallback((_) => chooseFolder());
    }
  }

  String _queueStamp = '';
  void queueChanged() {
    if (queue.playing &&
        !queue.opening &&
        queue.current != null &&
        (!lastPlaying || lastPlayedId != queue.currentId)) {
      views.recordPlay(queue.current!);
      lastPlayedId = queue.currentId;
      lastPlaying = true;
    }
    if (!queue.playing) lastPlaying = false;

    final volume = (widget.store.read('settings') as Map?)?['volume'];
    final stamp =
        '${queue.currentId}:${queue.ids.join(',')}:${queue.mode}:${queue.playing}:${queue.opening}:$volume';
    if (stamp != _queueStamp) {
      _queueStamp = stamp;
      changed();
    }
  }

  void _notifyVisualDemand() =>
      widget.onVisualDemandChanged?.call(visualizationDemand(displaySettings));
  void changed() {
    _notifyVisualDemand();
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
    sleep.removeListener(changed);
    if (widget.sleepTimer == null) sleep.dispose();
    library.removeListener(changed);
    queue.removeListener(queueChanged);
    search.dispose();
    super.dispose();
  }

  void message(String text) {
    messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }

  // Choose a system directory, then connect the source and refresh the library.
  Future<void> chooseFolder() async {
    try {
      if (widget.mobile) {
        if (library is AndroidMusicLibrary) {
          final android = library as AndroidMusicLibrary;
          await android.scan(requestPermission: true);
          if (!android.permissionGranted) return;
          final indexed =
              await AndroidMusicLibrary.channel.invokeListMethod<String>(
                'folders',
              ) ??
              [];
          if (!mounted) return;
          final options = {...android.sources, ...indexed}.toList()..sort();
          final ctx = navigator.currentState?.overlay?.context;
          if (ctx == null || !ctx.mounted) return;
          var source = await showTaktDialog<String>(
            context: ctx,
            builder: (c) => Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: GlassSurface(
                dark: dark,
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: 380,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr('Папка с музыкой', 'Music folder'),
                            style: Theme.of(c).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (options.isNotEmpty)
                            SizedBox(
                              height: math.min(options.length * 72.0, 360),
                              child: ListView(
                                children: [
                                  for (final path in options)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.folder_outlined,
                                      ),
                                      title: Text(
                                        path
                                                .split(':')
                                                .last
                                                .replaceAll(RegExp(r'/$'), '')
                                                .isEmpty
                                            ? tr(
                                                'Память устройства',
                                                'Device storage',
                                              )
                                            : path
                                                  .split(':')
                                                  .last
                                                  .replaceAll(
                                                    RegExp(r'/$'),
                                                    '',
                                                  ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle:
                                          path.startsWith('external_primary:')
                                          ? null
                                          : Text(tr('Карта памяти', 'SD card')),
                                      onTap: () => Navigator.pop(c, path),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(c, ''),
                            icon: const Icon(Icons.folder_open),
                            label: Text(tr('Другая папка', 'Browse folders')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(tr('Отмена', 'Cancel')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          if (source == '') {
            source = await AndroidMusicLibrary.channel.invokeMethod<String>(
              'pickFolder',
            );
          }

          if (source != null) await android.addSource(source);
        } else {
          await library.scan();
        }
        return;
      }
      final path = await FilePicker.getDirectoryPath();
      if (path != null) {
        await library.addSource(path);
        if (library.error != null) message(library.error!);
      }
    } catch (error) {
      message(
        error is PlatformException && error.code == 'local_folder'
            ? tr(
                'Выбери папку в памяти устройства или на карте памяти',
                'Choose a folder on this device or SD card',
              )
            : error.toString(),
      );
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
        for (final id in queue.playbackIds)
          for (final t in library.tracks)
            if (t.id == id &&
                t.title.toLowerCase().contains(search.text.toLowerCase()))
              t,
      ];
    }
    final base = library
        .visible(
          query: search.text,
          playlist: playlist,
          folder: folder,
          favoritesOnly: showFavorites,
          manual: widget.store.read('manual:$viewKey') == true,
        )
        .where(
          (t) =>
              !widget.mobile ||
              library is! AndroidMusicLibrary ||
              playlist != null ||
              showFavorites ||
              (library as AndroidMusicLibrary).inActiveSource(t),
        )
        .where((t) => !showFavorites || library.favorites.contains(t.id))
        .toList();
    if (specialView == 'recent') return views.recent(base);
    if (specialView == 'added') return views.added(base);
    if ((specialView == 'albums' || specialView == 'artists') &&
        groupId != null) {
      final groups = views.groups(
        library.tracks,
        albums: specialView == 'albums',
      );
      final match = groups.where((g) => g.id == groupId);
      final ids = match.isEmpty
          ? <String>{}
          : match.first.tracks.map((t) => t.id).toSet();
      return base.where((t) => ids.contains(t.id)).toList();
    }
    return base;
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

  Future<void> setVolume(double value) async {
    if (sleep.fading) await sleep.cancel(restore: false);
    settings['volume'] = value.clamp(0, 100);
    saveSettings();
    await queue.engine.volume((settings['volume'] as num).toDouble());
  }

  Future<void> _sleepDialog(BuildContext ctx) => showTaktDialog<void>(
    context: ctx,
    builder: (_) => SleepTimerDialog(timer: sleep, english: en, dark: dark),
  );
  Future<void> _toggleCompact() async {
    if (_compactChanging) return;
    _compactChanging = true;
    try {
      await widget.onCompactChanged?.call(
        !compact,
        settings['compactAlwaysOnTop'] == true,
      );
      if (mounted) setState(() => compact = !compact);
    } catch (e) {
      message(e.toString());
    } finally {
      _compactChanging = false;
    }
  }

  Future<void> _pinCompact() async {
    if (_compactChanging) return;
    _compactChanging = true;
    final value = settings['compactAlwaysOnTop'] != true;
    try {
      await widget.onCompactChanged?.call(true, value);
      settings['compactAlwaysOnTop'] = value;
      saveSettings();
    } catch (e) {
      message(e.toString());
    } finally {
      _compactChanging = false;
    }
  }

  Future<void> _volumeBy(double delta) =>
      setVolume((settings['volume'] as num? ?? 70).toDouble() + delta);

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
      iconButtonTheme: IconButtonThemeData(
        style: harmoniousIconButtonStyle(context),
      ),
      listTileTheme: ListTileThemeData(shape: harmoniousButtonShape()),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(42, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: harmoniousButtonShape(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(42, 42),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: harmoniousButtonShape(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(42, 42),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: harmoniousButtonShape(),
        ),
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
              widget.mobile ? null : _shortcut(() => _volumeBy(5)),
          const _PlaybackActivator(LogicalKeyboardKey.arrowDown): () =>
              widget.mobile ? null : _shortcut(() => _volumeBy(-5)),
        },
        child: PresentationScope(
          preferences: PresentationPreferences.fromMap(settings),
          appearance: customAppearance ? appearanceProfile : null,
          child: BackdropLayers(
            mobile: widget.mobile,
            profile: appearanceProfile,
            refreshHz: PresentationPreferences.fromMap(settings).visualizerHz,
            maxBlur: PresentationPreferences.fromMap(settings).blurSigma,
            sample: widget.amplitudes,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(appearanceProfile.textScale),
              ),
              child: Focus(autofocus: true, child: child!),
            ),
          ),
        ),
      ),
      scaffoldMessengerKey: messenger,
      navigatorKey: navigator,
      title: 'Takt',
      locale: Locale(en ? 'en' : 'ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Builder(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.transparent,
          body: widget.mobile
              ? _mobileShell(ctx)
              : compact
              ? ListenableBuilder(
                  listenable: queue,
                  builder: (c, _) => CompactPlayer(
                    queue: queue,
                    english: en,
                    dark: dark,
                    volume:
                        sleep.currentVolume ??
                        (settings['volume'] as num? ?? 70).toDouble(),
                    onVolume: setVolume,
                    restore: () => _toggleCompact(),
                    close: widget.close ?? widget.exit,
                    pinned: settings['compactAlwaysOnTop'] == true,
                    onPin: () => _pinCompact(),
                    art: _art(queue.current, size: 60),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(taktSpace),
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (c, area) {
                              final panel = Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: SettingsPanel(
                                  key: const Key('settings-panel'),
                                  settings: settings,
                                  library: library,
                                  save: saveSettings,
                                  close: () =>
                                      setState(() => settingsOpen = false),
                                  chooseFolder: chooseFolder,
                                  quit: widget.exit,
                                  appearance: () => _editAppearance(ctx),
                                  editLayout: () => _startLayoutEdit(),
                                  sleepTimer: () => _sleepDialog(ctx),
                                  compact: () => _toggleCompact(),
                                ),
                              );
                              final wide = area.maxWidth >= 1000;
                              return Stack(
                                children: [
                                  Row(
                                    children: [
                                      ResizableSidebar(
                                        preferredWidth: layoutEditing
                                            ? math.max(
                                                240,
                                                layoutPreferences.sidebarWidth,
                                              )
                                            : layoutPreferences.sidebarWidth,
                                        availableWidth:
                                            area.maxWidth -
                                            (wide && settingsOpen ? 376 : 0),
                                        collapsed:
                                            layoutCollapsedDraft ??
                                            PresentationPreferences.fromMap(
                                              settings,
                                            ).sidebarCollapsed,
                                        onResizeEnd: (v) {
                                          if (layoutEditing) {
                                            layoutDraft = {
                                              ...layoutPreferences.toMap(),
                                              'sidebarWidth': v,
                                            };
                                            setState(() {});
                                          } else {
                                            settings['layout'] = {
                                              ...layoutPreferences.toMap(),
                                              'sidebarWidth': v,
                                            };
                                            saveSettings();
                                          }
                                        },
                                        onCollapsedChanged: (v) {
                                          if (layoutEditing) {
                                            setState(
                                              () => layoutCollapsedDraft = v,
                                            );
                                          } else {
                                            settings['sidebarCollapsed'] = v;
                                            saveSettings();
                                          }
                                        },
                                        child: Builder(
                                          builder: (sideCtx) =>
                                              _sidebar(sideCtx),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: animatedPage(
                                          KeyedSubtree(
                                            key: ValueKey(
                                              '$viewKey:$showQueue:$folders:$folder:$groupId',
                                            ),
                                            child: LayoutBuilder(
                                              builder: (c, area) =>
                                                  SingleChildScrollView(
                                                    child: SizedBox(
                                                      height: math.max(
                                                        area.maxHeight,
                                                        300 *
                                                            appearanceProfile
                                                                .textScale,
                                                      ),
                                                      child: _body(ctx),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (wide)
                                        AnimatedSize(
                                          duration:
                                              PresentationPreferences.fromMap(
                                                settings,
                                              ).transitionDuration,
                                          curve: Curves.easeOutCubic,
                                          alignment: Alignment.centerRight,
                                          child: settingsOpen
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
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
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: WindowCloseButton(
                                      onClose: () =>
                                          (widget.close ?? widget.exit)?.call(),
                                      hoverOnly:
                                          PresentationPreferences.fromMap(
                                            settings,
                                          ).closeOnHover,
                                      english: en,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (layoutEditing) _layoutToolbar(ctx),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: layoutEditing
                              ? math.max(220, layoutPreferences.playerHeight)
                              : layoutPreferences.playerHeight,
                          child: ListenableBuilder(
                            listenable: queue,
                            builder: (_, _) => _player(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<String?> _chooseImage() => widget.mobile
      ? _mobileChooseImage()
      : const MethodChannel('takt/artwork_picker')
            .invokeMethod<String>('pick', {
              'title': tr('Выбрать картинку', 'Choose image'),
              'cancel': tr('Отмена', 'Cancel'),
              'open': tr('Выбрать', 'Choose'),
              'theme': dark ? 'dark' : 'light',
              'error': tr(
                'Не удалось открыть изображение',
                'Cannot preview this image',
              ),
            });
  Future<void> _applyOpacity(double value) async {
    if (widget.mobile || _opacityUnsupported || _lastOpacity == value) return;
    _lastOpacity = value;
    try {
      await windowManager.setOpacity(value);
    } catch (_) {
      _opacityUnsupported = true;
      if (mounted) {
        message(
          tr(
            'Оконный менеджер не поддерживает прозрачность окна',
            'Window manager does not support window opacity',
          ),
        );
      }
    }
  }

  Future<void> _editAppearance(BuildContext ctx) async {
    if (appearanceDialogOpen) return;
    appearanceDialogOpen = true;
    try {
      await showTaktDialog<void>(
        context: ctx,
        builder: (_) => AppearanceEditor(
          mobile: widget.mobile,
          settings: settings,
          chooseWallpaper: _chooseImage,
          onPreview: (value) {
            if (!mounted) return;
            setState(() => appearancePreview = value);
            _notifyVisualDemand();
            _applyOpacity(appearanceProfile.windowOpacity);
          },
          onCancel: () {
            if (mounted) setState(() => appearancePreview = null);
          },
          onSave: (value) async {
            try {
              for (final key in ['appearanceLight', 'appearanceDark']) {
                final profile = value[key];
                if (profile is! Map) continue;
                final path = profile['wallpaper'];
                if (path is! String) continue;
                final file = File(path);
                if (!await file.exists()) {
                  final previous = settings[key];
                  if (previous is Map && previous['wallpaper'] == path) {
                    profile.remove('wallpaper');
                    continue;
                  }
                  throw FileSystemException('Wallpaper is unavailable', path);
                }
                final directory = await getApplicationSupportDirectory();
                final target = Directory('${directory.path}/wallpapers');
                await target.create(recursive: true);
                final hash = (await sha256.bind(file.openRead()).first)
                    .toString();
                final name = file.uri.pathSegments.last;
                final suffix = name.contains('.') ? name.split('.').last : '';
                final extension =
                    RegExp(r'^[a-zA-Z0-9]{1,10}$').hasMatch(suffix)
                    ? '.$suffix'
                    : '';
                final destination = '${target.path}/$hash$extension';
                if (file.path != destination) await file.copy(destination);
                profile['wallpaper'] = destination;
              }
              for (final key in [
                'appearanceLight',
                'appearanceDark',
                'appearancePresets',
                'dark',
                'layout',
              ]) {
                if (value.containsKey(key)) settings[key] = value[key];
              }
              appearancePreview = null;
              saveSettings();
              _notifyVisualDemand();
              await _applyOpacity(appearanceProfile.windowOpacity);
              return true;
            } catch (error) {
              if (mounted) message(error.toString());
              return false;
            }
          },
        ),
      );
    } finally {
      appearanceDialogOpen = false;
      if (mounted) {
        setState(() => appearancePreview = null);
        _notifyVisualDemand();
        _applyOpacity(appearanceProfile.windowOpacity);
      }
    }
  }

  // Shared glass material: blur, transparency and corners. Adjust the effect here.
  Widget _glass(
    Widget child, {
    String identity = 'sidebar',
    BorderRadius radius = const BorderRadius.all(Radius.circular(22)),
  }) => GlassSurface(
    identity: identity,
    dark: dark,
    enabled: settings['glass'] != false,
    radius: radius.topLeft.x,
    child: child,
  );
  bool _sidebarCompact(BuildContext ctx) =>
      SidebarScope.of(ctx) ??
      (layoutCollapsedDraft ??
          PresentationPreferences.fromMap(settings).sidebarCollapsed);
  // Left function panel; its bottom section places settings above playback controls.
  Widget _sidebar(BuildContext ctx) => SizedBox(
    width: double.infinity,
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
                      child: _sidebarCompact(ctx)
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
                    if (layoutEditing)
                      _editableSidebar(ctx)
                    else
                      for (final id in layoutPreferences.visibleSidebar)
                        _sidebarAction(ctx, id),
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
  String _navLabel(String id) =>
      {
        'all': tr('Моя музыка', 'My music'),
        'favorites': tr('Избранное', 'Favorites'),
        'folders': tr('Папки', 'Folders'),
        'recent': tr('Недавно прослушанное', 'Recently played'),
        'added': tr('Недавно добавленное', 'Recently added'),
        'albums': tr('Альбомы', 'Albums'),
        'artists': tr('Исполнители', 'Artists'),
        'new': tr('Новый плейлист', 'New playlist'),
      }[id] ??
      id;
  IconData _navIcon(String id) =>
      {
        'all': Icons.music_note,
        'favorites': Icons.star_outline,
        'folders': Icons.folder_outlined,
        'recent': Icons.history,
        'added': Icons.fiber_new_outlined,
        'albums': Icons.album_outlined,
        'artists': Icons.person_outline,
        'new': Icons.playlist_add,
      }[id] ??
      Icons.music_note;
  Widget _sidebarAction(BuildContext ctx, String id) =>
      _nav(ctx, _navIcon(id), _navLabel(id), () {
        if (id == 'new') {
          _createPlaylist(ctx);
          return;
        }
        setState(() {
          playlist = null;
          folder = null;
          showQueue = false;
          showFavorites = id == 'favorites';
          folders = id == 'folders';
          groupId = null;
          specialView = ['recent', 'added', 'albums', 'artists'].contains(id)
              ? id
              : null;
          selected.clear();
          search.clear();
        });
      });
  void _startLayoutEdit() {
    setState(() {
      layoutCollapsedDraft = settings['sidebarCollapsed'] == true;
      layoutDraft = layoutPreferences.toMap();
      layoutEditing = true;
      settingsOpen = false;
    });
  }

  void _finishLayoutEdit(bool save) {
    if (save) {
      settings['sidebarCollapsed'] = layoutCollapsedDraft ?? false;
      settings['layout'] = layoutPreferences.toMap();
      settings['sidebarWidth'] = layoutPreferences.sidebarWidth;
    }
    setState(() {
      layoutCollapsedDraft = null;
      layoutDraft = null;
      layoutEditing = false;
    });
    if (save) saveSettings();
  }

  Widget _layoutToolbar(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(tr('Редактирование интерфейса', 'Editing interface')),
        TextButton(
          onPressed: () => setState(
            () => layoutDraft = LayoutPreferences.fromMap({}).toMap(),
          ),
          child: Text(tr('Сброс', 'Reset')),
        ),
        TextButton(
          onPressed: () async {
            final value = await showTaktDialog<LayoutPreferences>(
              context: ctx,
              builder: (_) => LayoutEditor(
                initial: layoutPreferences,
                english: en,
                dark: dark,
                onPreview: (_) {},
              ),
            );
            if (mounted && value != null) {
              setState(() => layoutDraft = value.toMap());
            }
          },
          child: Text(tr('Параметры', 'Options')),
        ),
        TextButton(
          onPressed: () => _finishLayoutEdit(false),
          child: Text(tr('Отмена', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => _finishLayoutEdit(true),
          child: Text(tr('Готово', 'Done')),
        ),
      ],
    ),
  );
  Widget _editableSidebar(BuildContext ctx) {
    final order = layoutPreferences.sidebarOrder;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: order.length,
      onReorderItem: (from, to) {
        final next = List<String>.of(order);
        final id = next.removeAt(from);
        next.insert(to, id);
        setState(
          () => layoutDraft = {
            ...layoutPreferences.toMap(),
            'sidebarOrder': next,
          },
        );
      },
      itemBuilder: (_, i) {
        final id = order[i];
        return Flex(
          direction: _sidebarCompact(ctx) ? Axis.vertical : Axis.horizontal,
          key: ValueKey('nav-edit-$id'),
          children: [
            ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle, size: 16),
            ),
            if (_sidebarCompact(ctx))
              _sidebarAction(ctx, id)
            else
              Expanded(child: _sidebarAction(ctx, id)),
            IconButton(
              icon: Icon(
                layoutPreferences.hiddenSidebar.contains(id)
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
              ),
              onPressed: () {
                final hidden = List<String>.of(layoutPreferences.hiddenSidebar);
                hidden.contains(id) ? hidden.remove(id) : hidden.add(id);
                setState(
                  () => layoutDraft = {
                    ...layoutPreferences.toMap(),
                    'hiddenSidebar': hidden,
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

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
        if (!_sidebarCompact(ctx)) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    ),
  );
  String _groupHeading() {
    if (groupId != null) {
      final matching = views
          .groups(library.tracks, albums: specialView == 'albums')
          .where((g) => g.id == groupId);
      if (matching.isNotEmpty) return _groupName(matching.first);
    }
    return _navLabel(specialView!);
  }

  String _groupName(LibraryGroup group) => group.name.isNotEmpty
      ? group.name
      : (specialView == 'albums'
            ? tr('Неизвестный альбом', 'Unknown album')
            : tr('Неизвестный исполнитель', 'Unknown artist'));
  Widget _groupCards(BuildContext ctx) {
    final groups = views
        .groups(library.tracks, albums: specialView == 'albums')
        .where(
          (g) => '${_groupName(g)} ${g.artist}'.toLowerCase().contains(
            search.text.toLowerCase(),
          ),
        )
        .toList();
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 190,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final group = groups[i];
        final covers = group.tracks.where((t) => t.artwork != null);
        return Material(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() {
              groupId = group.id;
              search.clear();
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _art(
                    covers.isEmpty ? group.tracks.first : covers.first,
                    size: 76,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _groupName(group),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (group.artist.isNotEmpty)
                    Text(
                      group.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  Text(
                    '${group.tracks.length} ${tr('треков', 'tracks')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Main area: heading/theme, tabs, search or creation form, list and drag animation.
  Widget _body(BuildContext ctx) {
    final rows = shown;
    final heading = specialView != null
        ? _groupHeading()
        : showQueue
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
                    _applyOpacity(appearanceProfile.windowOpacity);
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
                      duration: PresentationPreferences.fromMap(settings)
                          .transitionDuration,
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
                    specialView = null;
                    groupId = null;
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
                        specialView = null;
                        groupId = null;
                        playlist = p.id;
                        selected.clear();
                      }),
                    ),
                  ),
                IconButton(
                  key: const Key('new-playlist'),
                  tooltip: tr('Создать плейлист', 'Create playlist'),
                  onPressed: () => _createPlaylist(ctx),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: PresentationPreferences.fromMap(settings)
                .transitionDuration,
            curve: Curves.easeOutCubic,
            child: animatedPage(
              TextField(
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
              if (groupId != null)
                IconButton(
                  tooltip: tr('Назад', 'Back'),
                  onPressed: () => setState(() {
                    groupId = null;
                    search.clear();
                  }),
                  icon: const Icon(Icons.arrow_back),
                ),
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
                borderRadius: BorderRadius.circular(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: dark ? const Color(0xff252627) : const Color(0xfff4f4f4),
                surfaceTintColor: Colors.transparent,
                popUpAnimationStyle: AnimationStyle(
                  duration: PresentationPreferences.fromMap(settings)
                      .transitionDuration,
                  reverseDuration: PresentationPreferences.fromMap(settings)
                      .transitionDuration,
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
            child:
                (specialView == 'albums' || specialView == 'artists') &&
                    groupId == null
                ? _groupCards(ctx)
                : rows.isEmpty
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
  Future<void> _createPlaylist(BuildContext ctx) async {
    if (playlistDialogOpen) return;
    playlistDialogOpen = true;
    try {
      final name = await showPlaylistDialog(
        context: ctx,
        dark: dark,
        glass: settings['glass'] != false,
        english: en,
      );
      if (!mounted || name == null) return;
      specialView = null;
      groupId = null;
      playlist = library.createPlaylist(name);
      setState(() {
        showFavorites = false;
        showQueue = false;
        folders = false;
        folder = null;
        selected.clear();
        search.clear();
      });
    } finally {
      playlistDialogOpen = false;
    }
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
              padding: EdgeInsets.fromLTRB(
                20,
                {
                  'compact': 6.0,
                  'normal': 10.0,
                  'comfortable': 16.0,
                }[appearanceProfile.density]!,
                0,
                {
                  'compact': 6.0,
                  'normal': 10.0,
                  'comfortable': 16.0,
                }[appearanceProfile.density]!,
              ),
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
                        padding: EdgeInsets.symmetric(vertical: 8),
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
      RoundedPopupMenuItem(
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
          final path = await _chooseImage();
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
    final controls = <String, Widget>{
      'timer': IconButton(
        tooltip: sleep.active
            ? '${tr('Таймер', 'Timer')}: ${_time(sleep.remaining)}'
            : tr('Таймер сна', 'Sleep timer'),
        onPressed: () => _sleepDialog(ctx),
        icon: Icon(sleep.active ? Icons.timer : Icons.timer_outlined),
      ),
      'visualizer': IconButton(
        tooltip: tr('Визуализатор', 'Visualizer'),
        onPressed: () {
          settings['visualizerEnabled'] =
              settings['visualizerEnabled'] == false;
          saveSettings();
        },
        icon: const Icon(Icons.graphic_eq),
      ),
      'compact': IconButton(
        tooltip: tr('Компактный режим', 'Compact mode'),
        onPressed: () => _toggleCompact(),
        icon: const Icon(Icons.picture_in_picture_alt),
      ),
      'mode': IconButton(
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
      'previous': IconButton(
        onPressed: () => queue.previous(),
        icon: const Icon(Icons.skip_previous),
      ),
      'play': IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Theme.of(ctx).colorScheme.surface,
        ),
        onPressed: () => queue.toggle(),
        icon: Icon(queue.playing ? Icons.pause : Icons.play_arrow),
      ),
      'next': IconButton(
        onPressed: () => queue.next(),
        icon: const Icon(Icons.skip_next),
      ),
      'volume': VolumeControl(
        value:
            sleep.currentVolume ??
            (settings['volume'] as num? ?? 70).toDouble(),
        onChanged: setVolume,
        inline: PresentationPreferences.fromMap(settings).volumeInline,
        wheelEnabled: PresentationPreferences.fromMap(settings).volumeWheel,
        dark: dark,
        glass: settings['glass'] != false,
        english: en,
      ),
      'favorite': IconButton(
        tooltip: tr('Избранное', 'Favorite'),
        onPressed: current == null
            ? null
            : () => library.toggleFavorite([current.id]),
        icon: Icon(
          current != null && library.favorites.contains(current.id)
              ? Icons.star
              : Icons.star_outline,
        ),
      ),
    };
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: tr('Очередь', 'Queue'),
                onPressed: () => _queueMenu(ctx),
                icon: const Icon(Icons.queue_music_outlined, size: 20),
              ),
            ),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final id
                      in layoutEditing
                          ? layoutPreferences.controlsOrder
                          : layoutPreferences.visibleControls)
                    if (controls.containsKey(id))
                      _layoutControl(id, controls[id]!),
                ],
              ),
            ),
            const SizedBox(width: 48),
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
    return GlassSurface(
      identity: 'player',
      dark: dark,
      enabled: settings['glass'] != false,
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: LayoutBuilder(
          builder: (ctx, size) {
            if (size.maxWidth < 600) {
              return Column(
                children: [
                  if (settings['visualizerEnabled'] != false)
                    SizedBox(height: 24, width: 110, child: _signal(ink)),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(width: size.maxWidth, child: center),
                    ),
                  ),
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
                        identity: 'player',
                        radius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: center),
                const SizedBox(width: 20),
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
      ),
    );
  }

  Widget _layoutControl(String id, Widget child) {
    if (!layoutEditing) return child;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) =>
          LayoutPreferences.controlIds.contains(d.data),
      onAcceptWithDetails: (d) {
        if (d.data == id) return;
        final order = List<String>.of(layoutPreferences.controlsOrder);
        order.remove(d.data);
        order.insert(order.indexOf(id), d.data);
        setState(
          () => layoutDraft = {
            ...layoutPreferences.toMap(),
            'controlsOrder': order,
          },
        );
      },
      builder: (c, _, _) => LongPressDraggable<String>(
        data: id,
        feedback: Material(
          color: Theme.of(c).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: IgnorePointer(child: child),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnorePointer(
              child: Opacity(
                opacity: layoutPreferences.hiddenControls.contains(id)
                    ? .3
                    : 1.0,
                child: child,
              ),
            ),
            if (id == 'play')
              const SizedBox(height: 24)
            else
              IconButton(
                style: IconButton.styleFrom(
                  minimumSize: const Size(24, 24),
                  padding: const EdgeInsets.all(4),
                  shape: harmoniousButtonShape(10),
                ),
                icon: Icon(
                  layoutPreferences.hiddenControls.contains(id)
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: 14,
                ),
                onPressed: () {
                  final hidden = List<String>.of(
                    layoutPreferences.hiddenControls,
                  );
                  hidden.contains(id) ? hidden.remove(id) : hidden.add(id);
                  setState(
                    () => layoutDraft = {
                      ...layoutPreferences.toMap(),
                      'hiddenControls': hidden,
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Convert pointer coordinates to playback position; SeekPainter controls the appearance.
  Widget _signal(Color ink) => visuals.WaveSignal(
    values: widget.amplitudes?.call() ?? [],
    color: settings['visualizerColor'] == null
        ? ink
        : Color(settings['visualizerColor']),
    bandCount: !widget.mobile && settings['visualizerStyle'] == 'bars'
        ? 48
        : null,
    bars: settings['visualizerStyle'] == 'bars',
    linear: settings['visualizerStyle'] == 'linear',
    smoothness: (settings['visualizerSmoothness'] as num? ?? .5).toDouble(),
    refreshHz: PresentationPreferences.fromMap(settings).visualizerHz,
    sample: widget.amplitudes,
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
    super.linear,
    super.smoothness,
  });
}
