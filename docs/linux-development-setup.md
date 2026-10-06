# Окружение разработки Takt на Arch Linux

Первая версия - Linux, Hyprland/Wayland. Проверено 3 октября 2026 года. Android и Windows отложены; их SDK сейчас не нужны.

## Пакеты и фактическое наличие

| Назначение | Пакеты Arch | Проверка |
| --- | --- | --- |
| Сборка | base-devel, clang, cmake, ninja, pkgconf, gcc | Установлены |
| Окно Flutter | gtk3, libx11, libxi | Установлены |
| SDK и архивы | git, curl, unzip, xz, glu | Установлены |
| Дополнительная упаковка | zip | Для .tar.gz не нужен |
| Музыка и тестовые образцы | mpv, ffmpeg | Установлены; pkg-config обнаруживает mpv |
| База | sqlite | Установлен; библиотеку Dart подключает проект |
| Звук | pipewire, pipewire-pulse, wireplumber | Установлены |
| Трей | dbus, waybar | Установлены; работающий StatusNotifierHost подтверждён через D-Bus |
| Диагностика GPU | mesa-utils | Установлен |
| Flutter и Dart | Flutter SDK stable со встроенным Dart | Установлен: Flutter 3.47.6 / Dart 3.13.5; Linux toolchain исправна |

В Arch заголовки обычно входят в тот же пакет; названия Debian вида libgtk-3-dev здесь не используются. libayatana-appindicator уже есть, но актуальный tray_manager 0.7 использует StatusNotifierItem/D-Bus и не требует этой библиотеки; ему нужны GTK3, X11 и Xi. Подключение проекта фиксирует совместимые версии в lockfile.

## Установка недостающего

```bash
sudo pacman -Syu --needed zip
```

Flutter рекомендуется установить из stable bundle по официальной инструкции в `/home/anotherguy/develop/flutter` либо из stable-ветки официального Git-репозитория:

```bash
mkdir -p "$HOME/develop"
git clone --branch stable https://github.com/flutter/flutter.git "$HOME/develop/flutter"
export PATH="$HOME/develop/flutter/bin:$PATH"
flutter config --enable-linux-desktop
flutter precache --linux
flutter doctor -v
flutter devices
```

Если каталог уже существует, не удалять его автоматически: проверить имеющуюся установку. Для Bash строку `export PATH="$HOME/develop/flutter/bin:$PATH"` добавить один раз в `~/.bashrc`; для другой оболочки использовать её настройку PATH. После установки перезапустить Codex, чтобы он увидел PATH, либо сообщить абсолютный путь к SDK. `dart` устанавливается вместе с Flutter.

В `flutter doctor` обязательна исправная Linux toolchain. Предупреждения об Android SDK, Android Studio и Chrome не препятствуют Linux-разработке. `flutter devices` должен показывать linux-device.

## Hyprland и трей

Waybar должен работать с модулем `tray` в одном из списков modules-left/modules-center/modules-right. Модуль может быть прописан в подключаемом конфигурационном файле. Отсутствие найденного стандартного config не доказывает отсутствие трея. Во время разработки проверяется действующая конфигурация; устанавливать дополнительную панель вместо имеющейся не требуется.

Пример добавляемого элемента в список модулей: `"tray"`. Изменение существующей конфигурации выполняется отдельно, без замены её целиком.

## Что подключает разработчик

media_kit, локальную SQLite-обвязку, зависимости интерфейса, трея, окна и тестирования подключает проект через pubspec и `flutter pub get`. Пользователю не нужно ставить их вручную. Сервер базы данных, Python, Node.js, Java и Android Studio для текущей версии не требуются. Редактор с Flutter-плагином необязателен.

Для первичной загрузки SDK/пакетов нужен интернет. Для проверки пригодится папка с несколькими аудиоформатами и локальная картинка; synthetic fixtures также создаются в проекте. Ограничений свободного диска сейчас не обнаружено: в разделе проекта доступно около 236 GiB.

## Источники

- [Flutter: Linux toolchain](https://docs.flutter.dev/platform-integration/linux/setup)
- [Flutter: установка SDK](https://docs.flutter.dev/install/manual)
- [Официальный репозиторий Flutter](https://github.com/flutter/flutter)
- [tray_manager: зависимости и D-Bus](https://pub.dev/packages/tray_manager)
- [Waybar: модуль tray](https://github.com/Alexays/Waybar/wiki/Module:-Tray)
