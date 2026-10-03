# Takt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать первую версию личного локального музыкального плеера Takt для Arch Linux с согласованным интерфейсом и сохранением состояния.

**Изменение области по указанию пользователя:** Android — следующий этап, Windows отложен. До сообщения пользователя о готовности окружения продуктовый код не пишется. Далее план исполняется самостоятельно в текущем чате. Сохранённые ниже контракты Android описывают будущее расширение, а не обязательную работу первой версии. В задачах 1/2/7/10/12 выполняются только Linux-пункты; не нужны Android SDK, Kotlin, APK, мобильные экраны и проверка Windows. Список приёмки применяется к Linux: пункты о других платформах помечаются «вне текущей версии», а не как незавершённая Linux-функция.

**Architecture:** Flutter/Dart для общих экранов и прикладной логики; media_kit за интерфейсом PlaybackEngine. SQLite хранит библиотеку и персональные данные; платформенные адаптеры обслуживают Android URI, фон, события файлов, трей и реальный анализ звука. QueueController является единственным владельцем очереди.

**Tech Stack:** Flutter stable, Dart из той же поставки, media_kit + media_kit_libs_audio, audio_service/audio_session для Android, SQLite через drift, tray_manager/window_manager для ПК; Kotlin и FFI только для подтверждённых потребностей.

**Spec:** [Согласованный проект](../specs/2026-10-03-takt-design.md).

## Global Constraints

- Android 16, HyperOS 3 / Poco X7; Arch Linux / Lenovo IdeaPad 3; Windows 10 / компьютер пользователя.
- Первая версия устанавливается вручную; русский и английский интерфейс.
- Основное воспроизведение полностью работает без интернета.
- Ориентир — библиотека из нескольких сотен треков; измерения на 500 треках.
- Начальная сортировка — по названию; ручной порядок сохраняется отдельно для общей библиотеки и каждого плейлиста.
- Начальный режим — очередь по кругу; четыре режима: круг, один проход, перемешивание, один трек.
- После восстановления сессии музыка остаётся на паузе до явного нажатия «Пуск».
- Название и обложка меняются только внутри Takt; музыкальные файлы и теги не переписываются.
- Удаление файла с устройства — отдельное явное действие с подтверждением; отказ ОС не считается успехом.
- Сетевой поиск обложек выключен по умолчанию; разрешение даётся в настройках.
- Дубликат — повтор одного trackId; разные копии записи автоматически не объединяются.
- Постоянной боковой панели очереди нет; визуальная основа — `docs/mockups/takt-interface.html`.
- Нет эквалайзера, аккаунтов, синхронизации, видео, стриминговых сервисов и импорта/экспорта плейлистов.
- Цели отклика: до 100 мс на нажатие/подхват строки; поиск до 200 мс; анимации с целью 60 кадров/с. Не выдавать цели за измеренные результаты.
- Все сетевые запросы и сборки выполняются только в ходе исполнения плана, с фиксацией реального результата. Непроверенную платформу не отмечать как работающую.

## Review Focus

1. Исчезновение SD-карты и отказ разрешения должны сохранять пользовательские данные; проверка в задаче 4.
2. Совпадающие по содержимому копии после переноса не должны присваивать чужие названия и плейлисты; проверка в задаче 4.
3. Изменение очереди во время события завершения трека не должно запускать два следующих трека; проверка в задаче 5.
4. Прерванное групповое удаление должно сообщать об успехах и отказах отдельно; проверка в задаче 10.
5. Поздний сетевой ответ после выключения поиска не должен менять обложку; проверка в задаче 11.

## Состояние окружения и порядок исполнения

На момент подготовки плана Flutter/Dart не обнаружены в PATH; Java, adb, CMake, Ninja и Clang обнаружены. Путь Android SDK и его полнота не подтверждены. Готового приложения и Git-истории в рабочем каталоге нет. Подготовку выполнить внутри разрешённого рабочего каталога: SDK в `.tooling/`, кеш пакетов там же либо в разрешённом системном месте. Не менять глобальные настройки и не устанавливать системные пакеты без необходимости.

При исполнении создать Git-репозиторий, если полноценного репозитория по-прежнему нет и разрешения позволяют. Если `.git` управляется приложением и недоступен для записи, сохранить файлы и использовать доступный механизм снимков; не обходить защиту. Коммиты задач ниже выполняются только при доступном Git. Изоляция проверяется навыком using-git-worktrees; незакоммиченная работа пользователя сохраняется.

Задачи идут последовательно. Рекомендуемый способ — самостоятельное исполнение в этом чате; запуск агентов не подразумевается планом и требует выбора пользователя. Аппаратные проверки Poco и Windows могут потребовать доступ к этим устройствам. Пока его нет, разрешено выполнять независимые задачи, но результаты остаются «не проверено», а выпуск для этой платформы не объявляется готовым.

## Карта файлов

```text
pubspec.yaml, pubspec.lock, analysis_options.yaml, .gitignore
lib/main.dart, lib/app.dart, lib/bootstrap.dart
lib/core/models/{track,source,queue_state,settings,results}.dart
lib/core/storage/{database,schema,settings_store,session_store}.dart
lib/library/{source_adapter,desktop_source_adapter,android_source_adapter,
             library_repository,library_scanner,identity_resolver}.dart
lib/playlists/playlist_repository.dart
lib/playback/{playback_engine,media_kit_engine,queue_controller,session_controller}.dart
lib/platform/{android_audio_handler,desktop_lifecycle}.dart
lib/artwork/{artwork_service,artwork_provider,musicbrainz_provider}.dart
lib/analysis/{audio_analysis,analysis_bridge,visualizer_frame}.dart
lib/ui/{app_shell,desktop_shell,mobile_shell,theme,settings_screen}.dart
lib/ui/library/{track_list,track_row,track_actions,selection_controller,
                playlist_tabs,folder_browser}.dart
lib/ui/player/{player_panel,now_playing_screen,seek_bar,volume_popover,visualizer}.dart
lib/l10n/{app_ru,app_en}.arb, l10n.yaml
android/app/src/main/kotlin/com/takt/player/{MainActivity,TaktSourcesPlugin}.kt
android/app/src/main/AndroidManifest.xml
native/audio_analysis/, native/CMakeLists.txt
test/{storage,library,playlists,playback,artwork,ui,analysis}/
integration_test/{capability_probe,platform_smoke,performance}_test.dart
test/fixtures/, docs/verification/, README.md
```

Генерируемые Flutter platform runners находятся в `android/`, `linux/`, `windows/`. Не редактировать сгенерированную сериализацию и SQLite-код вручную. Подключение native/audio_analysis допускается только при необходимости, доказанной задачей 2.

## Общие интерфейсы

`TrackId` и `SourceId` — typedef String. `Track` содержит id, sourceId, locator (URI), исходные title/artist/album, overrideTitle/overrideArtwork, duration и available. Имена файлов служат резервным названием. `QueueMode` — enum loop, once, shuffle, single. `QueueState` — неизменяемые ids, currentId, mode, position, playing. `Settings` — locale, dark, accent, seekStyle, sourceIds, onlineArtwork, closeToTray, volume; defaults: язык системы с русским резервом, светлая тема, нейтральный акцент, прямая шкала, сеть выключена, трей включён, громкость 70.

`AddResult` — added или duplicate. `DeleteResult` — trackId, success, error; `ScanOutcome` — complete, unavailable или permissionDenied. `AudioFrame` — timestamp и Float32List значений амплитуды. `PlaybackSnapshot` — generation, currentId, position, duration, playing, volume. `PlaybackCompletion` — generation и currentId. Эти типы создаются задачей 1; новые поля добавляются совместимо, не через отдельные несовместимые модели.

### Task 1: Рабочая сборка и контракт аудиодвижка

**Files:** создать `pubspec.yaml`, lockfile, `.gitignore`, `lib/main.dart`, `lib/app.dart`, `lib/bootstrap.dart`, `lib/core/models/*.dart`, `lib/playback/playback_engine.dart`, `lib/playback/media_kit_engine.dart`, `test/playback/engine_contract_test.dart`, `integration_test/capability_probe_test.dart`, `docs/verification/environment.md`; сгенерировать platform runners.

**Interfaces:** `PlaybackEngine.open(List<Track> tracks, {required TrackId currentId, required bool play}) -> Future<void>`; `play/pause/seek(Duration)/setVolume(double)/dispose() -> Future<void>`; `int get generation`, `Stream<PlaybackSnapshot> snapshots`, `Stream<PlaybackCompletion> completed`, `Stream<String> errors`. generation увеличивается при каждом open, события старой загрузки сохраняют старое поколение. Минимальная оболочка позволяет выбрать один разрешённый локальный файл и управлять звуком.

- [ ] После установки окружения пользователем проверить Flutter stable, `flutter doctor -v`, версии и наличие linux-device. Зафиксировать вывод без секретов. Создать приложение Takt только с linux runner; исключить `.tooling/`, сборки и пользовательские файлы из Git.
- [ ] Написать `open_without_autoplay_never_calls_play`: fake backend получает `play:false`; позиция и id остаются доступными, команда play не отправляется. Assert: `expect(backend.playCalls, 0); expect(snapshot.playing, false);`. Написать `dispose_releases_player_once`: `expect(backend.disposeCalls, 1);`. Fake backend определяется в этом test-файле.
- [ ] Запустить `flutter test test/playback/engine_contract_test.dart`: получить ожидаемый отказ отсутствующей реализации.
- [ ] Реализовать адаптер media_kit и минимальные экраны; использовать аудиобиблиотеку без видеопакета. Подобрать совместимые версии зависимостей и сохранить lockfile.
- [ ] Запустить тест и `flutter analyze`; затем `flutter build linux`. На реальном аудиофайле проверить пуск, паузу, seek и отсутствие автостарта. Успех — слышимый звук и правильные переходы, а не только exit code сборки.
- [ ] Сохранить результаты и выполнить коммит `feat: bootstrap Takt with local audio playback`, если доступен Git.

### Task 2: Платформенные риски до полного интерфейса

**Files:** создать `lib/platform/android_audio_handler.dart`, `lib/library/{source_adapter,android_source_adapter}.dart`, Kotlin plugin, `lib/analysis/{audio_analysis,analysis_bridge,visualizer_frame}.dart`, `test/analysis/audio_analysis_test.dart`, `docs/verification/capabilities.md`; изменить manifest и integration probe; при необходимости создать `native/audio_analysis/`.

**Interfaces:** `SourceAdapter.discover() -> Future<List<Source>>`, `pick() -> Future<Source?>`, `enumerate(Source) -> Stream<SourceEntry>`, `changes(Source) -> Stream<void>`, `delete(Track) -> Future<DeleteResult>`; SourceEntry содержит locator, sourceId, metadata, size, modified, persistentId. `AudioAnalysis.frames -> Stream<AudioFrame>`, `attach(PlaybackEngine)/setVisible(bool)/dispose() -> Future<void>`. Android handler преобразует системные команды в команды PlaybackEngine; после задачи 5 — QueueController.

- [ ] Добавить тест `sine_and_silence_produce_distinct_frames`: анализ известных PCM sine и silence даёт ненулевую и нулевую амплитуду (`expect(sinePeak, greaterThan(0)); expect(silencePeak, 0);`). `pause_and_hidden_stop_frame_updates` проверяет отсутствие новых кадров после паузы или скрытия: `expect(framesAfterPause, isEmpty); expect(framesWhileHidden, isEmpty);`.
- [ ] Запустить `flutter test test/analysis/audio_analysis_test.dart`; убедиться в отказе до реализации.
- [ ] Проверить локальные пути Linux, выбранную папку и сменный носитель. Проверить работу окна под Hyprland/Wayland и загрузку libmpv. Android-адаптер и content URI отложены до этапа Android.
- [ ] Проверить способ получения реальных аудиоданных движка. Если требуется нативный мост, сначала реализовать и измерить его на одном файле. Применение разрешённых методов анализа воспроизводимого потока не запрашивает микрофон. Документировать выбранный метод и расход ресурсов.
- [ ] Запустить автоматические проверки и `flutter build linux`; проверить реальное воспроизведение, закрытие в трей и возврат через модуль tray Waybar. В отчёте указать окружение, действие и наблюдение. Проверки Poco и Windows вне текущего этапа.
- [ ] Если не подтверждаются Linux-источник или данные реального звука, зафиксировать конкретную причину и пересмотреть адаптер до полного интерфейса. Коммит `feat: verify platform audio and analysis adapters` только для работающих частей.

### Task 3: Локальная база, настройки и персональные данные

**Files:** создать `lib/core/storage/{database,schema,settings_store,session_store}.dart`, `test/storage/database_test.dart`, `test/storage/settings_store_test.dart`.

**Interfaces:** `TaktDatabase.open(String path)/close() -> Future<void>`; `SettingsStore.read() -> Future<Settings>`, `write(Settings) -> Future<void>`; `SessionStore.load() -> Future<QueueState?>`, `save(QueueState) -> Future<void>`. SQLite реализуется через drift с миграциями и внешними ключами.

- [ ] Тест `reopen_preserves_overrides_and_settings`: создать трек, override и настройки, закрыть/открыть БД, сравнить значения (`expect(restored.overrideTitle, 'Моё название'); expect(settings.onlineArtwork, false);`). `failed_transaction_preserves_previous_session` откатывает неуспешную запись целиком: `expect(restoredSession.ids, previousSession.ids);`.
- [ ] `flutter test test/storage`: сначала отказ из-за отсутствующих методов.
- [ ] Реализовать таблицы Sources, Tracks, TrackIdentity, Playlists, PlaylistItems, LibraryOrder, Session, Settings. Оригинальные поля и overrides хранить отдельно; миграцию версии схемы сделать явной.
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter test test/storage`, `flutter analyze`: успешно; тесты используют временную SQLite без личной музыки.
- [ ] Коммит `feat: persist library settings and playback session`.

### Task 4: Источники, сканирование, идентичность и поиск

**Files:** создать `lib/library/{desktop_source_adapter,library_repository,library_scanner,identity_resolver}.dart`, `test/library/{scanner,identity,search}_test.dart`; расширить Android adapter задачи 2.

**Interfaces:** `LibraryScanner.rescan(Source) -> Future<ScanOutcome>`; `IdentityResolver.resolve(SourceEntry) -> Future<TrackId>`; `LibraryRepository.watch({String query='', SourceId? sourceId, bool manual=false}) -> Stream<List<Track>>`; `setManualOrder(List<TrackId>)/setOverride(TrackId,{String? title,String? artwork}) -> Future<void>`. Метаданные читаются через платформенный reader за SourceAdapter; файловое чтение и hash выполняются вне UI-потока.

- [ ] Тесты: `nested_sources_do_not_duplicate_same_file` (`expect(indexed.length, 1);`); `missing_sd_card_preserves_playlist_and_overrides` (`expect(track.available, false); expect(track.overrideTitle, 'Моё название');`); `ambiguous_identical_copies_do_not_steal_identity` (`expect(resolvedId, isNot(originalId));`); `rename_preserves_track_id` (`expect(resolvedId, originalId);`); `search_matches_cyrillic_case_insensitively` (`expect(found.map((t) => t.id), contains(expectedId));`).
- [ ] `flutter test test/library`: ожидаемый отказ до реализации.
- [ ] Реализовать стандартные источники, выбор и хранение разрешений, рекурсию, исключение дублей пути/URI, отложенную сверку недописанного файла и события изменений. Полные hashes известных файлов вычислять в фоне и хранить до переноса; спорное совпадение не присваивать автоматически.
- [ ] Реализовать поиск по исходным/пользовательским названиям, исполнителю, альбому, имени файла; сортировку по названию с устойчивым id при равных названиях; сохранение ручного порядка. Неподдерживаемые/повреждённые файлы дают локальную ошибку без срыва всего сканирования.
- [ ] `flutter test test/library`, integration probe добавления/удаления/переноса/возврата папки: проходят; исходные байты неизменны. Коммит `feat: index and monitor local music sources`.

### Task 5: Очередь, четыре режима и восстановление

**Files:** создать `lib/playback/{queue_controller,session_controller}.dart`, `test/playback/{queue_controller,session_controller}_test.dart`; изменить bootstrap и Android handler.

**Interfaces:** `QueueController.start(List<TrackId> ids, TrackId currentId) -> Future<void>`; `add(TrackId) -> Future<AddResult>`; `move(int from,int to)/remove(TrackId)/setMode(QueueMode)/next()/previous()/play()/pause()/seek(Duration) -> Future<void>`; `Stream<QueueState> states`. `SessionController.restore() -> Future<void>`, `flush() -> Future<void>`, `dispose() -> Future<void>`. События завершения идентифицируются поколением открытого источника.

- [ ] Тесты: `defaults_to_loop` (`expect(state.mode, QueueMode.loop);`); `duplicate_is_rejected` (`expect(await queue.add(existingId), AddResult.duplicate);`); `once_stops_at_end` (`expect(state.playing, false);`); `single_repeats_current` (`expect(state.currentId, originalId);`); `shuffle_visits_all_before_repeating` (`expect(cycle.toSet().length, ids.length);`); `restore_never_autoplays` (`expect(engine.playCalls, 0);`); `late_completed_event_cannot_advance_new_queue_twice` (`expect(state.currentId, expectedNextId); expect(openCallsForNext, 1);`).
- [ ] `flutter test test/playback`: убедиться в отказах для отсутствующих контроллеров.
- [ ] Реализовать последовательную обработку команд; единственный источник истины об очереди; отделить перестановку списка библиотеки от очереди. Переключение режима не сбрасывает трек/позицию. В shuffle один цикл содержит каждый доступный id один раз.
- [ ] Подключить сохранение каждые две секунды и flush на паузе, смене трека и выходе; восстановить с `play:false`. Недоступные источники сохраняются ссылками, но пропускаются при воспроизведении; не зациклить обработку очереди без доступных песен.
- [ ] Запустить тесты и реальный сценарий pause → exit → reopen → play. Коммит `feat: add persistent playback queue and four modes`.

### Task 6: Плейлисты и ручной порядок

**Files:** создать `lib/playlists/playlist_repository.dart`, `test/playlists/playlist_repository_test.dart`.

**Interfaces:** `create(String name) -> Future<String>`; `rename(String id,String name)/delete(String id) -> Future<void>`; `add(String id,List<TrackId> tracks) -> Future<Map<TrackId,AddResult>>`; `remove(String id,List<TrackId> tracks)/reorder(String id,List<TrackId> order) -> Future<void>`; `watchAll() -> Stream<List<Playlist>>`, `watchTracks(String id) -> Stream<List<Track>>`. Playlist — id/name; добавить в core/models.

- [ ] `duplicate_add_reports_duplicate_and_keeps_one_row` (`expect(result[id], AddResult.duplicate); expect(rows.length, 1);`); `delete_playlist_does_not_delete_files` (`expect(await file.exists(), true);`); `orders_are_independent_and_survive_reopen` (`expect(firstOrder, ['b', 'a']); expect(secondOrder, ['a', 'b']);`); пустое название после trim отклоняется. Допустить одинаковые отображаемые имена плейлистов при разных id.
- [ ] `flutter test test/playlists`: ожидаемый отказ, затем реализовать операции транзакционно и UNIQUE(playlistId,trackId).
- [ ] Повторить тесты с закрытием/открытием SQLite. Коммит `feat: manage playlists with persistent ordering`.

### Task 7: Оболочка, темы, локализация и навигация

**Files:** создать `lib/ui/{app_shell,desktop_shell,mobile_shell,theme,settings_screen}.dart`, ARB и l10n.yaml, `lib/ui/library/{playlist_tabs,folder_browser}.dart`, `test/ui/{shell,settings}_test.dart`; изменить app/bootstrap.

**Interfaces:** `TaktApp({required AppDependencies dependencies})`; AppDependencies содержит созданные репозитории, контроллеры и stores. `DesktopShell/MobileShell({required AppDependencies dependencies})`. Зависимости передаются явно; не создавать второй PlaybackEngine при смене экрана.

- [ ] Тесты: `playlist_changes_header` (`expect(find.text('Вечер'), findsWidgets);`); `search_visible_create_form_hidden_on_start` (`expect(find.byKey(const Key('track-search')), findsOneWidget); expect(find.byKey(const Key('playlist-create')), findsNothing);`); `both_create_buttons_open_same_form` (`expect(find.byKey(const Key('playlist-create')), findsOneWidget);`); `settings_survive_restart` (`expect(restored.locale, 'en');`); русская и английская локализации не содержат пропущенных ключей.
- [ ] `flutter test test/ui/shell_test.dart test/ui/settings_test.dart`: отказ до реализации.
- [ ] Перенести согласованную компоновку: стеклянная левая панель, функции, настройки внизу, заголовок и sun/moon switch, список плейлистов, поиск. Реализовать раздел «Папки», управление источниками и выход из пустого состояния.
- [ ] Подключить theme/locale/accent/seekStyle/onlineArtwork/closeToTray; следовать размерам из макета на ПК. Для Android показать компактную панель и раскрываемый NowPlayingScreen без перегруженной боковой колонки.
- [ ] Проверить widget tests, реальный resize и отсутствие перекрытий на ширинах 320, 600 и 1024; обе темы и языки. Коммит `feat: add adaptive Takt interface and settings`.

### Task 8: Строки, меню, выделение и перетаскивание

**Files:** создать `lib/ui/library/{track_list,track_row,track_actions,selection_controller}.dart`, `test/ui/{track_gestures,selection}_test.dart`.

**Interfaces:** `TrackList({required List<Track> tracks, required Future<void> Function(List<TrackId>) onReorder, required void Function(TrackId) onPlay})`; `SelectionController.toggle(TrackId)/clear()/begin(TrackId) -> void`, `Set<TrackId> selected`. TrackActions делегирует операции репозиториям и QueueController, не выполняет удаление файла напрямую.

- [ ] Тесты: tap строки запускает один трек (`expect(playCalls, [trackId]);`); long press строки включает выбор (`expect(selection.selected, {trackId});`); tap в selection не запускает звук (`expect(playCalls, isEmpty);`); короткий tap ручки открывает меню; drag ручки переставляет всю строку, не открывая меню (`expect(order.first, draggedId); expect(menuVisible, false);`); зажатие с автопрокруткой переносит строку за видимый экран.
- [ ] `flutter test test/ui/track_gestures_test.dart test/ui/selection_test.dart`: первоначальный отказ.
- [ ] Реализовать виртуализированный список, ReorderableListView с ручкой, прокси всей строки, устойчивые keys, автопрокрутку и анимации соседей. Жесты строки и ручки не конкурируют; drag включает ручной порядок.
- [ ] Подключить меню сведений/переименования/обложки/очереди/плейлиста/выделения, групповые действия. Недоступные песни не запускаются; одинаковые названия не смешивают выделение.
- [ ] Запустить тесты, профильный замер 500 строк и проверку мышью/касанием. Коммит `feat: add track gestures selection and animated reorder`.

### Task 9: Панель воспроизведения, шкалы и визуализатор

**Files:** создать `lib/ui/player/{player_panel,now_playing_screen,seek_bar,volume_popover,visualizer}.dart`, `test/ui/player_panel_test.dart`, `test/ui/seek_bar_test.dart`; подключить AudioAnalysis задачи 2.

**Interfaces:** `PlayerPanel({required QueueController queue, required PlaybackEngine engine, required AudioAnalysis analysis, required Settings settings})`; `SeekBar({required Duration position, required Duration duration, required bool wavy, required ValueChanged<Duration> onSeek})`. Visualizer получает AudioFrame, не инициирует новый decoder из build().

- [ ] Тесты: пуск только по действию (`expect(playCalls, 0);` до tap); четыре нажатия режима возвращают loop (`expect(state.mode, QueueMode.loop);`); громкость по умолчанию скрыта и меняется ползунком; hit testing шкалы выдаёт 0..duration (`expect(seek.inMilliseconds, inInclusiveRange(0, duration.inMilliseconds));`); при duration=0 нет NaN; цвета ползунка и волны меняются с темой (`expect(waveColor, dark ? Colors.white : Colors.black);`).
- [ ] `flutter test test/ui/player_panel_test.dart test/ui/seek_bar_test.dart`: отказ до реализации.
- [ ] Собрать согласованную панель: обложка 96×96 на широком экране, визуализатор исходной высоты 42, умеренный сдвиг элементов внутрь; центр текста точно над play, mode и volume симметричны. При тесной ширине перестраивать, не перекрывать цели касания.
- [ ] Рисовать прямую/волнистую шкалу через CustomPainter; использовать одну функцию координат для линии и ползунка. Привязать seek ко времени, сохранять положение при drag. Сплошной силуэт рисовать по сглаженным реальным амплитудам; пауза/скрытие прекращают ненужную работу.
- [ ] Добавить открытие «Текущей очереди» через меню панели без постоянной колонки; её список использует move/remove QueueController. Проверить обе темы, размеры и звук. Коммит `feat: finish playback panel and real audio visualization`.

### Task 10: Системные функции и удаление файлов

**Files:** создать `lib/platform/desktop_lifecycle.dart`, `lib/library/delete_tracks.dart`, `test/platform/desktop_lifecycle_test.dart`, `test/library/delete_tracks_test.dart`, расширить Android audio handler и manifest.

**Interfaces:** `DesktopLifecycle.onClose(bool closeToTray)/show()/exit() -> Future<void>`, зависит от QueueController, SessionController и TrayAdapter. `TrayAdapter.available() -> Future<bool>`, `showMenu()/hideWindow()/showWindow()/dispose() -> Future<void>`. `DeleteTracks.execute(List<TrackId>,{required bool confirmed}) -> Future<List<DeleteResult>>`.

- [ ] Тесты: `missing_tray_keeps_window_accessible` (`expect(window.hidden, false);`); `close_to_tray_keeps_music_playing` (`expect(state.playing, true);`); `exit_flushes_and_disposes`; `denied_delete_keeps_track` (`expect(result.success, false); expect(track.available, true);`); `mixed_batch_reports_partial_success` (`expect(results.where((r) => r.success).length, 1); expect(results.where((r) => !r.success).length, 1);`); `cancelled_confirmation_never_deletes_file` (`expect(deleteCalls, 0);`).
- [ ] Запустить тесты: отказ до реализации соответствующих адаптеров.
- [ ] Реализовать трей show/play-pause/exit, настройку closeToTray, сохранение при выходе; системные Android-команды направить в QueueController. Аудиофокус, звонок и отключение наушников ставят паузу без потери очереди.
- [ ] Выполнить физическое удаление через SourceAdapter только после подтверждения; обновить библиотеку после подтверждённого успеха; вывести результат по каждому файлу. Не удалять настройки или исходники под видом пользовательской музыки.
- [ ] Тесты проходят; аппаратные проверки Windows/Arch/Poco внесены в `docs/verification/platforms.md`. Коммит `feat: integrate background playback tray and file deletion`.

### Task 11: Обложки и разрешённый сетевой поиск

**Files:** создать `lib/artwork/{artwork_service,artwork_provider,musicbrainz_provider}.dart`, `test/artwork/artwork_service_test.dart`; подключить настройки и меню замены изображения.

**Interfaces:** `ArtworkService.resolve(Track) -> Future<String?>`, `setEnabled(bool) -> Future<void>`, `setOverride(TrackId,String imagePath) -> Future<void>`; `ArtworkProvider.find({required String artist, required String album, required String title}) -> Future<ArtworkCandidate?>`. Candidate содержит releaseId, HTTPS imageUri и сведения для проверки соответствия; HTTP-клиент и кеш внедряются для тестов.

- [ ] Тесты: `disabled_search_sends_zero_requests` (`expect(client.requests, isEmpty);`); `manual_cover_wins` (`expect(path, manualPath);`); `cache_works_offline` (`expect(path, cachedPath);`); `late_response_after_disable_is_discarded` (`expect(cacheWrites, 0);`); `ambiguous_release_keeps_placeholder` (`expect(path, isNull);`); `http_error_never_pauses_audio` (`expect(pauseCalls, 0);`).
- [ ] `flutter test test/artwork`: ожидаемый отказ, затем реализовать local-first, MusicBrainz → CAA, последовательные запросы с лимитом по текущей документации, timeout и retry с backoff.
- [ ] Включение требует настройки с понятным описанием отправляемых метаданных; отключение отменяет ожидающие операции поколением/токеном. Изображения копируются в личный кеш Takt; музыка не загружается и не переписывается.
- [ ] Повторить тесты и проверку сети с выключенным разрешением; исключить бесконечные запросы для отсутствующей обложки. Коммит `feat: add opt-in artwork lookup and local overrides`.

### Task 12: Сборки и приёмка первой версии

**Files:** создать `integration_test/{platform_smoke,performance}_test.dart`, `test/fixtures/README.md`, `docs/verification/{formats,performance,release-checklist}.md`, README и локальные сценарии сборки в `tool/`.

**Interfaces:** без нового продуктового API. Проверки используют публичные контракты предыдущих задач; фикстуры создаются из собственного синтетического аудио и собственного изображения, а не скачиваются из чужой музыки.

- [ ] Добавить regression tests: история переноса + overrides + плейлист + restart (`expect(restoredTrack.id, originalId); expect(restoredTrack.overrideTitle, 'Моё название');`); поиск → запуск результатов → изменение поиска без перестройки очереди (`expect(queue.ids, startedIds);`); разрешение обложек → выключение → restart без запросов (`expect(requestsAfterRestart, isEmpty);`); отсутствие доступных треков не вызывает бесконечный цикл (`expect(state.playing, false);` после ограниченного числа попыток).
- [ ] Запустить `flutter analyze`, `flutter test`, `flutter test integration_test/platform_smoke_test.dart -d <реальное устройство>`; успех — отсутствие ошибок и фактически наблюдённое поведение.
- [ ] Проверить MP3, FLAC, PCM WAV/AIFF, AAC ADTS/M4A, ALAC M4A, Vorbis OGG, Opus, WMA, APE, WavPack, Musepack; по каждому указать codec/container/platform/результат, включая seek и конец файла. Не отмечать неподготовленный образец как проверенный.
- [ ] Измерить отклик, поиск и анимации в profile/release с 500 треками. Если цели не достигнуты, локализовать причину, исправить и повторить только затронутые проверки.
- [ ] Собрать `flutter build linux --release`. Подготовить локальный Linux bundle и desktop entry, описать зависимости и запуск под Hyprland. APK и Windows-сборка вне текущей версии.
- [ ] Пройти все относящиеся к Linux сценарии приёмки из spec. Проверить 15 минут проигрывания после скрытия окна в трей, возврат через Waybar, восстановление позиции и реальные данные визуализатора. Другие платформы отмечаются «вне текущей версии».
- [ ] Коммит `chore: package and verify Takt personal release`. Открыть готовые файлы и дать пользователю ссылки на артефакты и короткие инструкции. Готовность всей версии объявлять только после обязательных платформенных проверок.

## Самопроверка плана

Соответствие требованиям: библиотека/источники/перенос — задача 4; плейлисты — 6; очередь/сессия — 5; согласованный дизайн/настройки/языки — 7 и 9; жесты/выделение — 8; Android-фон/трей/удаление — 2 и 10; обложки — 11; форматы/производительность/сборки — 1, 2 и 12. Пять Review Focus имеют тесты в указанных задачах. Технические проверки не заменяются fake-тестами, и отказ доступа к устройству не маскируется успехом.

Этот план подготовлен, но ещё не исполнен. По последующему указанию пользователя сначала он устанавливает Linux-окружение, затем исполнитель начинает самостоятельно в текущем чате. Дополнительное согласование способа исполнения не требуется.
