// Track model: original tags remain separate from personal titles and artwork; media files are never rewritten.
class Track {
  // Stable ID connects a track to its queue and playlists after an unambiguous file move.
  final String id;
  String path, originalTitle, artist, album, signature;
  String? customTitle, artwork;
  bool available;
  double seconds;
  Track({
    required this.id,
    required this.path,
    required this.originalTitle,
    this.artist = '',
    this.album = '',
    this.signature = '',
    this.customTitle,
    this.artwork,
    this.available = true,
    this.seconds = 0,
  });
  // Personal titles take precedence over original metadata in the interface.
  String get title => customTitle ?? originalTitle;
  // SQLite snapshot. Add matching fromJson defaults when extending these fields.
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'title': originalTitle,
    'artist': artist,
    'album': album,
    'hash': signature,
    'custom': customTitle,
    'artwork': artwork,
    'available': available,
    'seconds': seconds,
  };
  factory Track.fromJson(Map<String, dynamic> j) => Track(
    id: j['id'],
    path: j['path'],
    originalTitle: j['title'],
    artist: j['artist'] ?? '',
    album: j['album'] ?? '',
    signature: j['hash'] ?? '',
    customTitle: j['custom'],
    artwork: j['artwork'],
    available: j['available'] ?? true,
    seconds: (j['seconds'] ?? 0).toDouble(),
  );
}

// A playlist stores ordered track IDs; files and metadata remain in the shared library.
class Playlist {
  // Playlist identity is independent of its editable name and ordered track IDs.
  final String id;
  String name;
  List<String> ids;
  Playlist(this.id, this.name, this.ids);
  // SQLite snapshot. Add matching fromJson defaults when extending these fields.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ids': ids};
  factory Playlist.fromJson(Map<String, dynamic> j) =>
      Playlist(j['id'], j['name'], List<String>.from(j['ids']));
}
