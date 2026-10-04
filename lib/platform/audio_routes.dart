import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Immutable pactl/PipeWire view. Keep the previous headphone endpoint so a
// default-sink change after unplugging cannot hide the disappearance.
class AudioRouteSnapshot {
  final String defaultSink;
  final Map<String, Map<String, dynamic>> sinks;
  AudioRouteSnapshot.fromSinks(this.defaultSink, List<dynamic> data)
    : sinks = {
        for (final value in data)
          value['name'] as String: Map<String, dynamic>.from(value as Map),
      };
  Map<String, dynamic>? get current => sinks[defaultSink];
  static List<Map> _ports(Map sink) =>
      (sink['ports'] as List? ?? []).cast<Map>();
  static bool _unavailable(Object? value) => [
    'no',
    'not available',
    'unavailable',
  ].contains(value?.toString().toLowerCase());
  static bool _headphones(Map sink) {
    final properties = sink['properties'] as Map? ?? {};
    final form =
        properties['device.form_factor']?.toString().toLowerCase() ?? '';
    final active = sink['active_port']?.toString().toLowerCase() ?? '';
    final type =
        _ports(sink)
            .where((p) => p['name'] == sink['active_port'])
            .map((p) => p['type']?.toString().toLowerCase())
            .firstOrNull ??
        '';
    return form.contains('headphone') ||
        form.contains('headset') ||
        active.contains('headphone') ||
        type.contains('headphone') ||
        (properties['device.bus'] == 'bluetooth' && form != 'speaker');
  }

  bool disconnectedFrom(AudioRouteSnapshot? previous) {
    final old = previous?.current;
    if (old == null || !_headphones(old)) return false;
    final same = sinks[previous!.defaultSink];
    if (same == null) {
      final device = (old['properties'] as Map?)?['device.name'];
      // A profile switch can rename a connected Bluetooth sink.
      if (device != null &&
          sinks.values.any(
            (s) =>
                (s['properties'] as Map?)?['device.name'] == device &&
                _headphones(s),
          )) {
        return false;
      }
      return true;
    }
    final oldPort = old['active_port'];
    final port = _ports(same).where((p) => p['name'] == oldPort).firstOrNull;
    if (port != null && _unavailable(port['availability'])) return true;
    // A port change alone can be a manual routing choice. Require positive
    // disappearance or unavailability evidence before pausing playback.
    return false;
  }
}

// Event-driven device queries, plus a fallback poll if subscription stops.
// Failed queries do not replace the baseline and cannot trigger a false pause.
class HeadphoneMonitor {
  final Future<void> Function() onDisconnect;
  final bool Function() enabled;
  final Future<AudioRouteSnapshot?> Function()? read;
  AudioRouteSnapshot? _previous;
  Process? _subscription;
  Timer? _poll, _debounce;
  bool _disposed = false, _busy = false, _again = false;
  HeadphoneMonitor({
    required this.onDisconnect,
    required this.enabled,
    this.read,
  });
  Future<void> checkNow() => _check();
  Future<void> start() async {
    await _check();
    if (_disposed) return;
    _poll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_check()),
    );
    try {
      final process = await Process.start('pactl', ['subscribe']);
      if (_disposed) {
        process.kill();
        return;
      }
      _subscription = process;
      unawaited(process.stderr.drain<void>());
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((event) {
            if (!event.contains('sink') &&
                !event.contains('server') &&
                !event.contains('card')) {
              return;
            }
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 120),
              () => unawaited(_check()),
            );
          }, onError: (_) {});
    } catch (_) {
      /* Polling remains available if event subscription fails. */
    }
  }

  Future<void> _check() async {
    if (_disposed) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      final snapshot = await (read?.call() ?? _readSystem());
      if (_disposed || snapshot == null) return;
      final disconnect = snapshot.disconnectedFrom(_previous);
      _previous = snapshot;
      if (disconnect && enabled()) await onDisconnect();
    } catch (_) {
      /* Keep the last successful snapshot. */
    } finally {
      _busy = false;
      if (_again && !_disposed) {
        _again = false;
        unawaited(_check());
      }
    }
  }

  Future<AudioRouteSnapshot?> _readSystem() async {
    final results = await Future.wait([
      Process.run('pactl', [
        'get-default-sink',
      ]).timeout(const Duration(seconds: 2)),
      Process.run('pactl', [
        '-f',
        'json',
        'list',
        'sinks',
      ]).timeout(const Duration(seconds: 2)),
    ]);
    if (results[1].exitCode != 0) return null;
    final name = results[0].exitCode == 0
        ? results[0].stdout.toString().trim()
        : '';
    final snapshot = AudioRouteSnapshot.fromSinks(
      name,
      jsonDecode(results[1].stdout.toString()) as List,
    );
    // A genuinely empty successful sink list also proves device removal.
    if (snapshot.current == null && snapshot.sinks.isNotEmpty) return null;
    return snapshot;
  }

  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _debounce?.cancel();
    _subscription?.kill();
  }
}
