import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/store.dart';
import '../core/track.dart';
import 'engine.dart';

// Loop, play once, shuffle, repeat one. Enum indices are persisted; preserve their order.
enum QueueMode { loop, once, shuffle, single }

// Single owner of the queue: UI actions go here instead of manipulating the player directly.
class TaktQueue extends ChangeNotifier {
  final TaktStore store;
  final AudioEngine engine;
  final List<Track> Function() tracks;
  List<String> ids = [];
  List<String> _shuffled = [];
  List<String> _priorShuffle = [], _followingShuffle = [];
  String? currentId;
  String? _loadedPath;
  QueueMode _mode = QueueMode.loop;
  QueueMode get mode => _mode;
  set mode(QueueMode value) {
    if (value != _mode) {
      _shuffled.clear();
      _priorShuffle.clear();
      _followingShuffle.clear();
    }
    final changed = _mode != value;
    _mode = value;
    if (value == QueueMode.shuffle) _ensureShuffle();
    if (changed) notifyListeners();
  }

  // Keep a complete cycle, not a bag consumed by Next; Previous uses the same order.
  List<String> get playbackIds {
    if (mode != QueueMode.shuffle) return List.of(ids);
    _ensureShuffle();
    return List.of(_shuffled);
  }

  void _ensureShuffle() {
    _shuffled.removeWhere((id) => !ids.contains(id));
    if (_shuffled.isEmpty) {
      _shuffled = [...ids.where((id) => id != currentId)]..shuffle(Random());
      if (ids.contains(currentId)) _shuffled.insert(0, currentId!);
    } else if (_followingShuffle.isEmpty) {
      // Historical cycles exclude tracks added after they finished.
      // Queue edits append new tracks without rerandomizing the active cycle.
      _shuffled.addAll(ids.where((id) => !_shuffled.contains(id)));
    }
  }

  // Playback intent is separate from playing: the engine reports playing=false before EOF.
  bool _intendedPlaying = false;
  Duration position = Duration.zero;
  bool playing = false;
  bool opening = false;
  bool _completionPending = false;
  // Open/seek generation rejects completion events from an earlier playback state.
  int _generation = 0;
  Future<void> _pending = Future.value();
  TaktQueue(this.store, this.engine, this.tracks);
  void updatePosition(Duration value) {
    position = value;
    notifyListeners();
  }

  void updatePlaying(bool value) {
    playing = value;
    notifyListeners();
  }

  Track? get current {
    for (final t in tracks()) {
      if (t.id == currentId) return t;
    }
    return null;
  }

  // Persists IDs, current track, milliseconds and mode; automatic playback is deliberately not saved.
  void save() => store.write('session', {
    'ids': ids,
    'current': currentId,
    'position': position.inMilliseconds,
    'mode': mode.index,
    'shuffleOrder': playbackIds,
    'priorShuffle': _priorShuffle,
    'followingShuffle': _followingShuffle,
  });
  // Always restore paused, regardless of whether music was playing before exit.
  Future<void> restore({bool loadMedia = true}) async {
    final j = store.read('session');
    if (j == null) return;
    ids = List<String>.from(j['ids']);
    currentId = j['current'];
    position = Duration(milliseconds: j['position'] ?? 0);
    mode = QueueMode.values[(j['mode'] as int? ?? 0).clamp(0, 3)];
    if (mode == QueueMode.shuffle) {
      final saved = j['shuffleOrder'];
      if (saved is List) _shuffled = List<String>.from(saved).toSet().toList();
      _priorShuffle = List<String>.from(j['priorShuffle'] as List? ?? []);
      _followingShuffle = List<String>.from(
        j['followingShuffle'] as List? ?? [],
      );
      _ensureShuffle();
    }
    playing = false;
    if (loadMedia && current?.available == true) {
      final restoredPosition = position;
      await engine.open(current!, play: false);
      _loadedPath = current!.path;
      await engine.seek(restoredPosition);
      position = restoredPosition;
    }
    notifyListeners();
  }

  // The visible list becomes a queue snapshot; subsequent searches do not alter that snapshot.
  Future<void> start(List<String> list, String id) => _serial(() async {
    ids = list.toSet().toList();
    currentId = id;
    position = Duration.zero;
    _shuffled.clear();
    _priorShuffle.clear();
    _followingShuffle.clear();
    if (mode == QueueMode.shuffle) _ensureShuffle();
    await _open(true);
  });
  // Open the current file while guarding missing tracks and obsolete completion events.
  Future<void> _open(bool play) async {
    _generation++;
    if (current?.available != true) {
      playing = false;
      _intendedPlaying = false;
      await engine.pause();
      notifyListeners();
      return;
    }
    _intendedPlaying = play;
    opening = true;
    try {
      await engine.open(current!, play: play);
      _loadedPath = current!.path;
      playing = play;
      save();
      notifyListeners();
    } finally {
      opening = false;
      notifyListeners();
    }
  }

  // Insert after the current track. false indicates a duplicate for the UI to report.
  bool addNext(String id) {
    if (ids.contains(id)) return false;
    final index = ids.indexOf(currentId ?? '');
    ids.insert(index < 0 ? ids.length : index + 1, id);
    if (mode == QueueMode.shuffle) {
      final index = _shuffled.indexOf(currentId ?? '');
      _shuffled.insert(index < 0 ? _shuffled.length : index + 1, id);
    }
    save();
    notifyListeners();
    return true;
  }

  // Append without duplicates; adding a track does not automatically start playback.
  bool add(String id) {
    if (ids.contains(id)) return false;
    ids.add(id);
    save();
    notifyListeners();
    return true;
  }

  // Play/pause. Reopen a moved file at the retained position when its path changes.
  Future<void> toggle() => _serial(() async {
    if (current == null || current?.available != true) {
      final available = ids.where(
        (id) => tracks().any((t) => t.id == id && t.available),
      );
      if (available.isEmpty) return;
      currentId = available.first;
      position = Duration.zero;
      await _open(true);
      return;
    }
    if (playing) {
      await engine.pause();
      playing = false;
      _intendedPlaying = false;
    } else {
      if (_loadedPath != current!.path) {
        final retainedPosition = position;
        await engine.open(current!, play: false);
        _loadedPath = current!.path;
        await engine.seek(retainedPosition);
        position = retainedPosition;
      }
      await engine.play();
      playing = true;
      _intendedPlaying = true;
    }
    save();
    notifyListeners();
  });

  // A seek belongs to the track selected when requested; discard it if that track changes.
  Future<void> seek(Duration value) {
    final id = currentId;
    return _serial(() async {
      if (id != currentId || current == null) return;
      _generation++;
      position = value;
      await engine.seek(value);
      save();
      notifyListeners();
    });
  }

  // Pause while retaining the selected track and position for later continuation.
  Future<void> stop() => _serial(() async {
    _intendedPlaying = false;
    await engine.pause();
    playing = false;
    save();
    notifyListeners();
  });

  // Natural EOF rechecks playback intent and generation inside the serialized command.
  Future<void> completed(String? id) async {
    final generation = _generation;
    if (opening || _completionPending || !_intendedPlaying || id != currentId) {
      return;
    }
    _completionPending = true;
    try {
      await _serial(() async {
        if (_intendedPlaying && id == currentId && generation == _generation) {
          await _advance(1);
        }
      });
    } finally {
      _completionPending = false;
    }
  }

  Future<void> next() => _serial(() => _advance(1));
  Future<void> previous() => _serial(() => _advance(-1));
  // Commands run sequentially. Errors reach callers without preventing the next command.
  Future<void> _serial(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object _) {});
    return result;
  }

  // Select the next available track. Change transition and shuffle rules here.
  Future<void> _advance(int direction) async {
    final available = ids
        .where((id) => tracks().any((t) => t.id == id && t.available))
        .toList();
    if (available.isEmpty) {
      playing = false;
      _intendedPlaying = false;
      await engine.pause();
      notifyListeners();
      return;
    }
    String next;
    if (mode == QueueMode.single && direction > 0) {
      next = available.contains(currentId) ? currentId! : available.first;
    } else if (mode == QueueMode.shuffle) {
      _ensureShuffle();
      var cycle = _shuffled.where(available.contains).toList();
      final index = cycle.indexOf(currentId ?? '') + direction;
      if (direction > 0 && index >= cycle.length) {
        // Only crossing the final track starts a new cycle. Avoid an immediate repeat.
        _priorShuffle = List.of(_shuffled);
        final returning = _followingShuffle.isNotEmpty;
        _shuffled = returning
            ? List.of(_followingShuffle)
            : ([...ids]..shuffle(Random()));
        _followingShuffle.clear();
        _ensureShuffle();
        cycle = _shuffled.where(available.contains).toList();
        if (!returning && cycle.length > 1 && cycle.first == currentId) {
          final swap = _shuffled.indexOf(cycle[1]);
          final first = _shuffled.indexOf(cycle.first);
          final value = _shuffled[first];
          _shuffled[first] = _shuffled[swap];
          _shuffled[swap] = value;
          cycle = _shuffled.where(available.contains).toList();
        }
        next = cycle.first;
      } else if (direction < 0 &&
          index < 0 &&
          _priorShuffle.any(available.contains)) {
        _followingShuffle = List.of(_shuffled);
        _shuffled = List.of(_priorShuffle);
        _priorShuffle.clear();
        _ensureShuffle();
        next = _shuffled.where(available.contains).last;
      } else {
        next = cycle[index.clamp(0, cycle.length - 1)];
      }
    } else {
      final index = available.indexOf(currentId ?? '') + direction;
      if (mode == QueueMode.once && index >= available.length) {
        playing = false;
        _intendedPlaying = false;
        await engine.pause();
        save();
        notifyListeners();
        return;
      }
      next =
          available[(index % available.length + available.length) %
              available.length];
    }
    currentId = next;
    position = Duration.zero;
    await _open(true);
  }

  // Reorder visible IDs only; filtered-out tracks keep their original slots.
  void reorderVisible(List<String> order) {
    var index = 0;
    final reordered = playbackIds
        .map((id) => order.contains(id) ? order[index++] : id)
        .toList();
    if (mode == QueueMode.shuffle) {
      _shuffled = reordered;
    } else {
      ids = reordered;
    }
    save();
    notifyListeners();
  }

  // ReorderableListView indices need adjustment when the removed item moves downward.
  void move(int from, int to) {
    final order = mode == QueueMode.shuffle ? _shuffled : ids;
    final id = order.removeAt(from);
    if (to > from) to--;
    order.insert(to.clamp(0, order.length), id);
    save();
    notifyListeners();
  }

  // Removing the current track pauses first; this operation never deletes a media file.
  Future<void> remove(String id) => _serial(() async {
    ids.remove(id);
    _shuffled.remove(id);
    _priorShuffle.remove(id);
    _followingShuffle.remove(id);
    if (currentId == id) {
      _intendedPlaying = false;
      await engine.pause();
      currentId = null;
      playing = false;
      position = Duration.zero;
    }
    save();
    notifyListeners();
  });
}
