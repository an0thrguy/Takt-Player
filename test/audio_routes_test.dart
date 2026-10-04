import 'package:flutter_test/flutter_test.dart';
import 'package:takt/platform/audio_routes.dart';

Map<String, dynamic> sink(
  String name,
  String port, {
  String availability = 'yes',
  bool bluetooth = false,
}) => {
  'name': name,
  'active_port': port,
  'properties': {'device.bus': bluetooth ? 'bluetooth' : 'pci'},
  'ports': [
    {'name': 'headphones', 'availability': availability},
    {'name': 'speaker', 'availability': 'yes'},
  ],
};
void main() {
  test('manual port change with unknown availability does not pause', () {
    final before = AudioRouteSnapshot.fromSinks('wired', [
      sink('wired', 'headphones', availability: 'availability unknown'),
    ]);
    final after = AudioRouteSnapshot.fromSinks('wired', [
      sink('wired', 'speaker', availability: 'availability unknown'),
    ]);
    expect(after.disconnectedFrom(before), false);
  });
  test(
    'unplug pauses, manual device switch and unchanged headphones do not',
    () {
      final before = AudioRouteSnapshot.fromSinks('wired', [
        sink('wired', 'headphones'),
      ]);
      final unplugged = AudioRouteSnapshot.fromSinks('wired', [
        sink('wired', 'speaker', availability: 'no'),
      ]);
      expect(unplugged.disconnectedFrom(before), true);
      expect(before.disconnectedFrom(null), false);
      expect(before.disconnectedFrom(before), false);
      final manual = AudioRouteSnapshot.fromSinks('other', [
        sink('wired', 'headphones'),
        sink('other', 'speaker'),
      ]);
      expect(manual.disconnectedFrom(before), false);
    },
  );
  test('Bluetooth disappearance is detected after default sink changed', () {
    final before = AudioRouteSnapshot.fromSinks('bt', [
      sink('bt', 'headphones', bluetooth: true),
    ]);
    final after = AudioRouteSnapshot.fromSinks('wired', [
      sink('wired', 'speaker'),
    ]);
    expect(after.disconnectedFrom(before), true);
  });
  test(
    'monitor ignores failed queries and detects loss without a fallback sink',
    () async {
      final headphones = AudioRouteSnapshot.fromSinks('bt', [
        sink('bt', 'headphones', bluetooth: true),
      ]);
      final absent = AudioRouteSnapshot.fromSinks('', []);
      final snapshots = <AudioRouteSnapshot?>[headphones, null, absent];
      int pauses = 0, index = 0;
      final monitor = HeadphoneMonitor(
        enabled: () => true,
        onDisconnect: () async {
          pauses++;
        },
        read: () async => snapshots[index++],
      );
      await monitor.checkNow();
      expect(pauses, 0);
      await monitor.checkNow();
      expect(pauses, 0);
      await monitor.checkNow();
      expect(pauses, 1);
      monitor.dispose();
    },
  );
}
