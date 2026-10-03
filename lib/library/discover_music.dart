import 'dart:io';

// Find accessible XDG Music, then Music/Музыка. Parse user-dirs.dirs as data; never execute it.
Future<String?> discoverMusic({String? home, String? configHome}) async {
  home ??= Platform.environment['HOME'];
  if (home == null) return null;
  final candidates = <String>[];
  try {
    final config = File(
      '${configHome ?? Platform.environment['XDG_CONFIG_HOME'] ?? '$home/.config'}/user-dirs.dirs',
    );
    if (await config.exists()) {
      final match = RegExp(
        r'^XDG_MUSIC_DIR="([^"]+)"',
        multiLine: true,
      ).firstMatch(await config.readAsString());
      if (match != null) {
        candidates.add(
          match
              .group(1)!
              .replaceAll(r'${HOME}', home)
              .replaceAll(r'$HOME', home),
        );
      }
    }
  } catch (_) {}
  candidates.addAll(['$home/Music', '$home/Музыка']);
  for (final path in candidates) {
    try {
      // XDG Music=Home disables that directory; do not scan the entire home folder.
      if (path == home ||
          !path.startsWith('/') ||
          !await Directory(path).exists()) {
        continue;
      }
      final directory = Directory(path);
      await directory.list().isEmpty;
      return await directory.resolveSymbolicLinks();
    } catch (_) {}
  }
  return null;
}
