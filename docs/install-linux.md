# Установка Takt на Linux

## 1. Скачайте файлы

Откройте [последний выпуск Takt](https://github.com/an0thrguy/Takt-Player/releases/latest) и скачайте два файла из раздела Assets:

- `Takt-0.3.0-linux-x86_64.tar.gz`;
- `SHA256SUMS.txt`.

Сборка предназначена для 64-битных компьютеров Intel и AMD. Flutter для запуска не нужен. Android, ARM и Windows пока не поддерживаются.

Не скачивайте автоматически созданный архив `Source code`, если хотите просто установить плеер. В нём нет готового приложения.

## 2. Установите зависимости

### Arch Linux и совместимые системы

```bash
sudo pacman -Syu --needed gtk3 libxi mpv ffmpeg libpulse python
```

### Ubuntu 22.04 и Linux Mint 21

```bash
sudo apt update
sudo apt install libgtk-3-0 libxi6 libmpv1 ffmpeg pulseaudio-utils python3
```

### Ubuntu 24.04 и Linux Mint 22

```bash
sudo apt update
sudo apt install libgtk-3-0t64 libxi6 libmpv2 ffmpeg pulseaudio-utils python3
```

На Fedora нужны GTK 3, libXi, mpv-libs, FFmpeg, `pactl` и Python 3. Названия пакетов могут отличаться в зависимости от подключённых репозиториев.

`pactl` нужен только для паузы при отключении наушников. Python используется установщиком ярлыка. Сам плеер написан на Dart и без Python запускается.

## 3. Проверьте и распакуйте архив

Откройте терминал в папке с загруженными файлами:

```bash
sha256sum --check SHA256SUMS.txt
tar -xzf Takt-0.3.0-linux-x86_64.tar.gz
cd Takt-0.3.0-linux-x86_64
./start.sh
```

Не переносите файл `takt` отдельно. Папки `lib` и `data` должны находиться рядом с ним.

При первом запуске Takt попробует открыть стандартную папку Music или Музыка. Если подходящей папки нет, плеер предложит выбрать её вручную.

## 4. Добавьте Takt в меню приложений

В распакованной папке выполните:

```bash
./install.sh
```

Не запускайте эту команду через `sudo`. Плеер установится только для текущего пользователя и появится в меню приложений. Музыка, системные сочетания клавиш и настройки рабочего окружения не меняются.

## Обновление

Полностью закройте старую версию Takt, распакуйте новый выпуск и выполните его `./install.sh`. Библиотека, плейлисты и настройки хранятся отдельно и сохранятся.

## Удаление

Удалите папку приложения:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/takt
```

Затем удалите ярлык:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/applications/takt.desktop
```

База Takt хранится отдельно. Не удаляйте её, если хотите сохранить плейлисты и настройки для будущей установки. Музыкальные файлы установщик не трогает.

## Если Takt не запускается

Запустите `./start.sh` из терминала и посмотрите текст ошибки.

Проверить отсутствующие библиотеки можно так:

```bash
ldd ./takt
```

Строка `not found` укажет на недостающий пакет. Если система сообщает об отсутствующей версии GLIBC, не заменяйте glibc вручную. Используйте сборку для своей системы или соберите Takt из исходников.

Если нет звука, проверьте поток Takt и выбранный выход в системном микшере. Для чтения метаданных, обложек и работы визуализатора должны быть доступны `ffmpeg` и `ffprobe`.

В отчёте об ошибке укажите дистрибутив, его версию, рабочее окружение, X11 или Wayland и полный текст ошибки. Не отправляйте свою базу Takt и музыкальные файлы.

## Особенности Linux

- трей требует поддержки StatusNotifierHost. В GNOME может понадобиться расширение;
- системные медиакнопки и виджеты используют MPRIS;
- определение отключения проводных наушников зависит от драйвера;
- в плиточном Hyprland компактный режим требует перевести окно в плавающий режим;
- прозрачность окна и режим поверх окон зависят от композитора.

## English quick install

Download `Takt-0.3.0-linux-x86_64.tar.gz` and `SHA256SUMS.txt` from [GitHub Releases](https://github.com/an0thrguy/Takt-Player/releases/latest). Install GTK 3, libXi, libmpv, FFmpeg and the normal graphics and audio packages for your distribution.

```bash
sha256sum --check SHA256SUMS.txt
tar -xzf Takt-0.3.0-linux-x86_64.tar.gz
cd Takt-0.3.0-linux-x86_64
./start.sh
# Optional user installation, without sudo:
./install.sh
```

Keep `takt`, `lib` and `data` together. Quit the old version before updating. The music library and settings database are stored separately and are preserved by the installer.
