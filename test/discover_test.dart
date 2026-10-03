// Regression checks for discover; use independent local fixtures and mocked boundaries where appropriate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takt/library/discover_music.dart';

void main() {
  test(
    'XDG localized music is found and disabled Home is not scanned',
    () async {
      final home = await Directory.systemTemp.createTemp('takt-home-');
      addTearDown(() => home.delete(recursive: true));
      final config = await Directory('${home.path}/.config').create(),
          music = await Directory('${home.path}/Музыка').create();
      final file = File('${config.path}/user-dirs.dirs');
      await file.writeAsString('XDG_MUSIC_DIR="\$HOME/Музыка"\n');
      expect(
        await discoverMusic(home: home.path, configHome: config.path),
        music.path,
      );
      await music.delete();
      await file.writeAsString('XDG_MUSIC_DIR="\$HOME"\n');
      expect(
        await discoverMusic(home: home.path, configHome: config.path),
        isNull,
      );
    },
  );
}
