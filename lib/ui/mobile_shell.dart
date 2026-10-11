part of 'app.dart';

// Phone layout reuses the desktop actions and settings rather than duplicating data rules.
extension _MobileShell on _TaktAppState {
  Widget _mobileShell(BuildContext ctx) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (selected.isNotEmpty) {
        mobileChanged(selected.clear);
      } else if (mobilePage != 0 ||
          showQueue ||
          playlist != null ||
          specialView != null) {
        _mobileNavigate(0);
      } else {
        widget.close?.call();
      }
    },
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: animatedPage(
                KeyedSubtree(
                  key: ValueKey('mobile-page-$mobilePage'),
                  child: switch (mobilePage) {
                    1 => _mobilePlaylists(ctx),
                    3 => SettingsPanel(
                      key: const Key('settings-panel'),
                      mobile: true,
                      settings: settings,
                      library: library,
                      save: saveSettings,
                      close: () => _mobileNavigate(0),
                      chooseFolder: chooseFolder,
                      appearance: () => _editAppearance(ctx),
                      editLayout: () => _mobileLayout(ctx),
                      sleepTimer: () => _sleepDialog(ctx),
                    ),
                    _ => _mobileLibrary(ctx),
                  },
                ),
              ),
            ),
          ),
          if (MediaQuery.viewInsetsOf(ctx).bottom == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListenableBuilder(
                listenable: queue,
                builder: (_, _) => _mobileMini(ctx),
              ),
            ),
          NavigationBar(
            key: const Key('mobile-navigation'),
            height: 68,
            backgroundColor: Colors.transparent,
            selectedIndex: mobilePage,
            onDestinationSelected: _mobileNavigate,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.music_note_outlined),
                label: tr('Музыка', 'Music'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.queue_music),
                label: tr('Плейлисты', 'Playlists'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.star_border),
                label: tr('Избранное', 'Favorites'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                label: tr('Настройки', 'Settings'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _mobileNavigate(int page) => mobileChanged(() {
    mobilePage = page;
    showFavorites = page == 2;
    settingsOpen = page == 3;
    playlist = null;
    showQueue = false;
    specialView = null;
    groupId = null;
    folders = false;
    folder = null;
    selected.clear();
    search.clear();
  });

  Widget _mobileLibrary(BuildContext ctx) {
    final rows = shown;
    final heading = showQueue
        ? tr('Очередь', 'Queue')
        : playlist != null
        ? library.playlists.firstWhere((p) => p.id == playlist).name
        : showFavorites
        ? tr('Избранное', 'Favorites')
        : specialView != null
        ? _groupHeading()
        : tr('Моя музыка', 'My music');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (playlist != null || showQueue || groupId != null)
                IconButton(
                  onPressed: () => mobileChanged(() {
                    playlist = null;
                    showQueue = false;
                    groupId = null;
                  }),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Сменить тему', 'Switch theme'),
                onPressed: () {
                  settings['dark'] = !dark;
                  saveSettings();
                },
                icon: Icon(
                  dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                ),
              ),
            ],
          ),
        ),
        TextField(
          key: const Key('track-search'),
          controller: search,
          onChanged: (_) => changed(),
          decoration: InputDecoration(
            hintText: tr('Поиск треков', 'Search tracks'),
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(ctx).colorScheme.onSurface
                .withValues(alpha: .04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (mobilePage == 0 && playlist == null && !showQueue)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final id in layoutPreferences.visibleSidebar.where(
                  (id) => ['all', 'recent', 'added', 'artists'].contains(id),
                ))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_navLabel(id)),
                      selected: (specialView ?? 'all') == id,
                      onSelected: (_) => mobileChanged(() {
                        specialView = id == 'all' ? null : id;
                        groupId = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        if (library.scanning) const LinearProgressIndicator(minHeight: 2),
        if (library is AndroidMusicLibrary &&
            !(library as AndroidMusicLibrary).permissionGranted &&
            !library.scanning)
          _glass(
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    tr(
                      'Разреши доступ к аудио, чтобы Takt нашёл музыку на устройстве.',
                      'Allow audio access so Takt can find music on this device.',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => (library as AndroidMusicLibrary).scan(
                          requestPermission: true,
                        ),
                        child: Text(tr('Разрешить', 'Allow')),
                      ),
                      TextButton(
                        onPressed: () => AndroidMusicLibrary.channel
                            .invokeMethod<void>('appSettings'),
                        child: Text(
                          tr('Настройки Android', 'Android settings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Text(
              '${rows.length} ${tr('треков', 'tracks')}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const Spacer(),
            if (selected.isNotEmpty) ...[
              Text('${selected.length}'),
              IconButton(
                onPressed: () => _batchMenu(ctx),
                icon: const Icon(Icons.more_horiz),
              ),
              IconButton(
                onPressed: () => mobileChanged(selected.clear),
                icon: const Icon(Icons.close),
              ),
            ] else
              IconButton(
                tooltip: tr('По названию', 'Sort by title'),
                onPressed: () {
                  widget.store.write('manual:$viewKey', false);
                  changed();
                },
                icon: const Icon(Icons.sort),
              ),
          ],
        ),
        Expanded(
          child:
              (specialView == 'albums' || specialView == 'artists') &&
                  groupId == null
              ? _groupCards(ctx)
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: rows.length,
                  proxyDecorator: (child, _, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (_, _) => Material(
                      color: Theme.of(ctx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 6,
                      child: child,
                    ),
                  ),
                  onReorderItem: (from, to) {
                    final ids = rows.map((t) => t.id).toList();
                    final id = ids.removeAt(from);
                    ids.insert(to, id);
                    if (showQueue) {
                      queue.reorderVisible(ids);
                    } else {
                      library.reorder(
                        ids,
                        playlist: playlist,
                        favoritesOnly: showFavorites,
                        baseOrder: library
                            .visible(
                              playlist: playlist,
                              favoritesOnly: showFavorites,
                              manual:
                                  widget.store.read('manual:$viewKey') == true,
                            )
                            .map((t) => t.id)
                            .toList(),
                      );
                      widget.store.write('manual:$viewKey', true);
                    }
                    changed();
                  },
                  itemBuilder: (c, i) => _row(c, rows[i], i, rows),
                ),
        ),
        if (library.error != null)
          Text(library.error!, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _mobilePlaylists(BuildContext ctx) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              tr('Плейлисты', 'Playlists'),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          IconButton(
            key: const Key('new-playlist'),
            icon: const Icon(Icons.add),
            onPressed: () async {
              await _createPlaylist(ctx);
              if (mounted && playlist != null) {
                mobileChanged(() {
                  mobilePage = 0;
                });
              }
            },
          ),
        ],
      ),
      Expanded(
        child: ListView(
          children: [
            for (final p in library.playlists)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _glass(
                  ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(p.name),
                    subtitle: Text('${p.ids.length} ${tr('треков', 'tracks')}'),
                    onLongPress: () => _playlistMenu(ctx, p),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => _playlistMenu(ctx, p),
                    ),
                    onTap: () => mobileChanged(() {
                      playlist = p.id;
                      mobilePage = 0;
                      showFavorites = false;
                      search.clear();
                    }),
                  ),
                ),
              ),
            if (library.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    'Нажми плюс, чтобы создать первый плейлист.',
                    'Tap plus to create your first playlist.',
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _mobileMini(BuildContext ctx) => _glass(
    Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('mobile-expand'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _mobileExpand(ctx),
              child: Row(
                children: [
                  _art(queue.current, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          queue.current?.title ?? 'Takt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          queue.current?.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: const Key('mobile-previous'),
            tooltip: tr('Предыдущий', 'Previous'),
            onPressed: () => queue.previous(),
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton.filled(
            key: const Key('mobile-play'),
            tooltip: tr('Пуск / пауза', 'Play / pause'),
            onPressed: () => queue.toggle(),
            icon: Icon(queue.playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            key: const Key('mobile-next'),
            tooltip: tr('Следующий', 'Next'),
            onPressed: () => queue.next(),
            icon: const Icon(Icons.skip_next),
          ),
        ],
      ),
    ),
    identity: 'player',
  );

  Future<void> _mobileExpand(BuildContext ctx) => showTaktDialog<void>(
    context: ctx,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        height: MediaQuery.sizeOf(c).height * .86,
        child: _glass(
          ListenableBuilder(
            listenable: Listenable.merge([queue, library]),
            builder: (c, _) => SingleChildScrollView(
              key: const Key('mobile-full-player'),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('mobile-collapse'),
                        onPressed: () => Navigator.pop(c),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      Expanded(
                        child: Text(
                          tr('Сейчас играет', 'Now playing'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(c);
                          mobileChanged(() {
                            mobilePage = 0;
                            showQueue = true;
                            showFavorites = false;
                            playlist = null;
                            specialView = null;
                          });
                        },
                        icon: const Icon(Icons.queue_music),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _art(
                    queue.current,
                    size: math.min(
                      MediaQuery.sizeOf(c).width - 88,
                      MediaQuery.sizeOf(c).height * .32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    queue.current?.title ?? 'Takt',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    queue.current?.artist ?? '',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _seek(c),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_time(queue.position)),
                      Text(
                        _time(
                          Duration(
                            seconds: queue.current?.seconds.toInt() ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _mobilePlayerControls(c),
                  const SizedBox(height: 14),
                  if (settings['visualizerEnabled'] != false)
                    SizedBox(
                      height: 70,
                      width: double.infinity,
                      child: _signal(Theme.of(c).colorScheme.onSurface),
                    ),
                ],
              ),
            ),
          ),
          identity: 'player',
          radius: BorderRadius.circular(28),
        ),
      ),
    ),
  );

  Widget _mobilePlayerControls(BuildContext ctx) {
    final controls = <String, Widget>{
      'mode': IconButton(
        tooltip: tr('Режим очереди', 'Queue mode'),
        onPressed: () {
          queue.mode = QueueMode.values[(queue.mode.index + 1) % 4];
          queue.save();
        },
        icon: Icon(
          [
            Icons.repeat,
            Icons.playlist_play,
            Icons.shuffle,
            Icons.repeat_one,
          ][queue.mode.index],
        ),
      ),
      'previous': IconButton(
        onPressed: () => queue.previous(),
        icon: const Icon(Icons.skip_previous),
      ),
      'play': IconButton.filled(
        iconSize: 32,
        onPressed: () => queue.toggle(),
        icon: Icon(queue.playing ? Icons.pause : Icons.play_arrow),
      ),
      'next': IconButton(
        onPressed: () => queue.next(),
        icon: const Icon(Icons.skip_next),
      ),
      'favorite': IconButton(
        onPressed: queue.current == null
            ? null
            : () => library.toggleFavorite([queue.currentId!]),
        icon: Icon(
          library.favorites.contains(queue.currentId)
              ? Icons.star
              : Icons.star_border,
        ),
      ),
      'timer': IconButton(
        tooltip: tr('Таймер сна', 'Sleep timer'),
        onPressed: () => _sleepDialog(ctx),
        icon: const Icon(Icons.timer_outlined),
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
    };
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: [
        for (final id in layoutPreferences.visibleControls)
          if (controls[id] != null) controls[id]!,
      ],
    );
  }

  Future<void> _mobileLayout(BuildContext ctx) async {
    final value = await showTaktDialog<LayoutPreferences>(
      context: ctx,
      builder: (_) => LayoutEditor(
        initial: layoutPreferences,
        english: en,
        dark: dark,
        mobile: true,
        onPreview: (_) {},
      ),
    );
    if (mounted && value != null) {
      settings['layout'] = value.toMap();
      saveSettings();
    }
  }

  Future<String?> _mobileChooseImage() async {
    final String? path;
    if (widget.pickImage != null) {
      path = await widget.pickImage!();
    } else {
      final files = await FilePicker.pickFiles(type: FileType.image);
      path = files.isEmpty ? null : files.single.path;
    }
    if (!mounted || path == null) return null;
    return showTaktDialog<String>(
      context: navigator.currentState!.overlay!.context,
      builder: (c) => AlertDialog(
        title: Text(tr('Предпросмотр', 'Preview')),
        content: SizedBox(
          width: 460,
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(path!),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(
                  tr('Не удалось открыть изображение', 'Cannot open image'),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('Отмена', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, path),
            child: Text(tr('Выбрать', 'Choose')),
          ),
        ],
      ),
    );
  }
}
