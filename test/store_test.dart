// Regression checks for store; use independent local fixtures and mocked boundaries where appropriate.
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/core/store.dart';

void main() {
  test('transaction rolls back all state keys after failure', () {
    final store = TaktStore.memory();
    addTearDown(store.close);
    store.write('tracks', ['a']);
    expect(
      () => store.transaction(() {
        store.write('tracks', ['b']);
        store.write('playlists', ['changed']);
        throw StateError('interrupt');
      }),
      throwsStateError,
    );
    expect(store.read('tracks'), ['a']);
    expect(store.read('playlists'), isNull);
  });
}
