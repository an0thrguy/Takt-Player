import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

// Local SQLite store: each key contains a JSON snapshot of one part of application state.
class TaktStore {
  final Database db;
  TaktStore(String path) : db = sqlite3.open(path) {
    _init();
  }
  TaktStore.memory() : db = sqlite3.openInMemory() {
    _init();
  }
  // Storage schema. Plan a migration when changing the shape of existing snapshots.
  void _init() {
    db.execute(
      'CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  // Missing keys return null so callers can choose their initial defaults.
  dynamic read(String key) {
    final rows = db.select('SELECT value FROM state WHERE key=?', [key]);
    return rows.isEmpty ? null : jsonDecode(rows.first['value'] as String);
  }

  // Replaces the entire value; callers perform partial JSON updates before writing.
  void write(String key, Object? value) => db.execute(
    'INSERT INTO state VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, jsonEncode(value)],
  );
  // Writes related library snapshots together; any failure rolls back all changes.
  void transaction(void Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      action();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => db.close();
}
