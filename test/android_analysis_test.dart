import 'package:flutter_test/flutter_test.dart';
import 'package:takt/platform/android_analysis.dart';

void main() {
  test('spectrum advances between sparse playback position events', () async {
    var clock = Duration.zero;
    final analysis = AndroidAnalysis(
      connect: false,
      now: () => clock,
      invoke: (_, _) async {},
    );
    await analysis.load('content://clock');
    analysis.acceptBatch(1, 0, [
      [.01],
      [.4],
      [.8],
    ]);
    final first = analysis.frame(Duration.zero, true).single;
    clock = const Duration(milliseconds: 75);
    expect(analysis.frame(Duration.zero, true).single, greaterThan(first));
    analysis.dispose();
  });

  test('seek outside the playback cache restarts decoding at the requested position', () async {
    final calls = <Map<String, dynamic>>[];
    final analysis = AndroidAnalysis(
      connect: false,
      invoke: (method, data) async {
        if (method == 'analyze') calls.add(data);
      },
    );
    await analysis.load('content://a');
    analysis.acceptBatch(1, 0, List.generate(1600, (_) => [.1]));
    analysis.frame(Duration.zero, true);
    expect(analysis.frame(const Duration(seconds: 70), true), isEmpty);
    expect(calls.last['position'], 70000);
    expect(calls.last['uri'], 'content://a');
    analysis.dispose();
  });

  test(
    'decoded spectrum follows position and rejects obsolete track events',
    () async {
      final analysis = AndroidAnalysis(connect: false, invoke: (_, _) async {});
      await analysis.load('content://a');
      analysis.acceptBatch(1, 0, [
        [.1, .2],
        [.8, .3],
      ]);
      final first = analysis.frame(Duration.zero, true);
      final next = analysis.frame(const Duration(milliseconds: 50), true);
      expect(first, isNotEmpty);
      expect(next, isNot(first));
      expect(analysis.frame(Duration.zero, false), isEmpty);
      await analysis.load('content://b');
      analysis.acceptBatch(1, 0, [
        [1, 1],
      ]);
      expect(analysis.frame(Duration.zero, true), isEmpty);
      analysis.dispose();
    },
  );
}
