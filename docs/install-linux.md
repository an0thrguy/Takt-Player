# Установка Takt на Linux / Installing Takt on Linux

## Русский

### Что скачать

Откройте [GitHub Releases](https://github.com/an0thrguy/Takt-Player/releases/latest) и скачайте **Takt-0.2.0-linux-x86_64.tar.gz** и **SHA256SUMS.txt**. Это готовое приложение для 64-битных компьютеров Intel/AMD. «Source code» и «Download ZIP» — исходники: их нужно собирать самостоятельно.

Готовый выпуск собирается на Ubuntu 22.04. Он использует библиотеки системы; установка зависимостей обязательна. Все дистрибутивы, ARM-компьютеры и все рабочие окружения не проверены. GTK 3, графическая сессия X11/Wayland и рабочий звуковой сервер необходимы. Flutter для запуска готовой сборки не нужен.

### Зависимости

**Ubuntu 22.04 / Linux Mint 21:**

```bash
sudo apt update
sudo apt install libgtk-3-0 libxi6 libmpv1 ffmpeg pulseaudio-utils python3
```

**Ubuntu 24.04 / Linux Mint 22:**

```bash
sudo apt update
sudo apt install libgtk-3-0t64 libxi6 libmpv2 ffmpeg pulseaudio-utils python3
```

**Arch Linux и совместимые системы:**

```bash
sudo pacman -Syu --needed gtk3 libxi mpv ffmpeg libpulse python
```

**Fedora:** нужны пакеты `gtk3`, `libXi`, `mpv-libs`, FFmpeg с `ffprobe`, `pulseaudio-utils` и `python3`. Доступность кодеков зависит от подключённых репозиториев Fedora. Этот вариант пока не проверен; не устанавливайте случайные RPM-файлы ради недостающих библиотек.

`pactl` из `pulseaudio-utils`/`libpulse` нужен для паузы при отключении наушников. Он работает с PulseAudio и совместимым сервером PipeWire-Pulse. Python 3 используется только необязательным установщиком меню; само приложение написано на Dart и не требует Python.

### Запуск

Откройте терминал в папке загрузки. Проверяйте контрольную сумму до распаковки:

```bash
sha256sum --check SHA256SUMS.txt
tar -xzf Takt-0.2.0-linux-x86_64.tar.gz
cd Takt-0.2.0-linux-x86_64
./start.sh
```

Держите `takt`, `lib` и `data` рядом. Не переносите один исполняемый файл. При первом запуске приложение найдёт XDG Music, `~/Music` или `~/Музыка`, либо предложит выбрать папку. Ваши песни и база настроек не входят в скачанный архив.

### Добавить в меню приложений

Закройте Takt через настройки или меню трея, затем в распакованной папке:

```bash
./install.sh
```

**Не используйте sudo.** Установка копирует приложение в `${XDG_DATA_HOME:-$HOME/.local/share}/takt` и создаёт ярлык `applications/takt.desktop` в том же каталоге данных. После этого запускайте Takt из меню рабочего окружения. Системные настройки, сочетания клавиш и музыкальные файлы установщик не меняет.

### Обновление и удаление

Для обновления завершите Takt, распакуйте новый выпуск и запустите его `./install.sh`. Библиотека, плейлисты и настройки хранятся отдельно и сохраняются. Простое скрытие в трей не завершает приложение.

Для удаления удалите только папку установленного приложения `takt` и ярлык `applications/takt.desktop` из своего XDG-каталога данных. Не удаляйте папку базы плеера, если хотите сохранить настройки; музыкальные файлы в этих каталогах не хранятся.

### Управление и особенности

- Пробел — пуск/пауза. Влево/вправо — перемотка; вверх/вниз — громкость. Ctrl + влево/вправо — смена песни. При вводе текста клавиши не перехватываются.
- Полный выход: настройки → «Выйти», меню трея → выход или Super + Q, если сочетание не перехватывает рабочее окружение.
- В Hyprland можно вручную использовать `tool/super-q.py` из исходников; установщик не заменяет ваши системные бинды.
- Перемещать плавающее окно можно за заголовок «Моя музыка»/название плейлиста. Внешняя рамка отсутствует.
- Трей требует StatusNotifierHost; GNOME может требовать отдельное расширение. Когда доступного трея нет, приложение не скрывает окно без возможности вернуть его.
- Системные медиакнопки и виджеты используют MPRIS. Когда одновременно играет несколько плееров, выбор активного плеера определяет оболочка.
- Определение отключения проводных наушников зависит от того, сообщает ли драйвер состояние разъёма. Автоматического продолжения после подключения нет.

### Если не запускается или нет звука

Запустите `./start.sh` из терминала. Для отсутствующих библиотек проверьте `ldd ./takt`; строки `not found` показывают недостающие системные пакеты. Сообщение `GLIBC_... not found` означает несовместимую версию системы: не подменяйте вручную glibc. Можно собрать исходники на своей системе.

Для звука проверьте выбранный выход и поток **Takt** в системном микшере. Для библиотеки/обложек/визуализатора должны быть доступны `ffmpeg` и `ffprobe`. В отчёт об ошибке включите дистрибутив, версию, окружение, X11/Wayland и текст ошибки; не прикладывайте свою базу или музыкальные файлы.

## English

Download the binary **Takt-0.2.0-linux-x86_64.tar.gz** and **SHA256SUMS.txt** from [Releases](https://github.com/an0thrguy/Takt-Player/releases/latest). “Source code” archives are not runnable builds. This release targets Intel/AMD x86_64, is built on Ubuntu 22.04 and uses system runtime libraries. ARM, Android and Windows builds are not included; not every distribution or desktop has been tested.

Install the runtime packages for your distribution using the commands above: GTK 3, libXi, libmpv, FFmpeg/ffprobe, and a working graphics/audio session. Optional headphone monitoring needs `pactl` with PulseAudio or PipeWire-Pulse. Python 3 is only needed by the optional application-menu installer. Flutter is not needed to run the binary.

```bash
sha256sum --check SHA256SUMS.txt
tar -xzf Takt-0.2.0-linux-x86_64.tar.gz
cd Takt-0.2.0-linux-x86_64
./start.sh
# Optional, current-user installation; never run with sudo:
./install.sh
```

Keep the executable, `lib` and `data` together. The installer copies the bundle to `${XDG_DATA_HOME:-$HOME/.local/share}/takt` and registers a desktop launcher; it does not modify your music, desktop configuration or keyboard shortcuts. Quit Takt before updating, then run the new bundle's installer. The separate library/settings database is preserved. To uninstall, remove the installed `takt` folder and `applications/takt.desktop` launcher; keep the separate database if you want your settings retained.

Space controls playback, arrows seek/change volume, and Ctrl+Left/Right changes tracks; editing text takes precedence. Quit from Settings or the tray; Super+Q works unless intercepted by your desktop. Move a floating window by dragging the content heading. Tray integration needs StatusNotifier support; GNOME may need an extension. MPRIS enables media controls and shell widgets, but the shell chooses among multiple active players. Wired headphone unplug detection depends on driver availability reporting.

Run `./start.sh` in a terminal to diagnose startup errors. `ldd ./takt` identifies missing libraries. Do not replace your system's glibc to satisfy an incompatible binary: build from source instead. Check the **Takt** stream and output device in the system mixer for audio problems. Report the distribution/version, desktop, X11/Wayland and error text, without uploading your personal database or music.

Package references: [Ubuntu libmpv1](https://packages.ubuntu.com/jammy/libmpv1), [Ubuntu libmpv2](https://packages.ubuntu.com/noble/libmpv2), [Fedora mpv-libs](https://packages.fedoraproject.org/pkgs/mpv/mpv-libs/).
