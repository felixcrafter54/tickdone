// Tests für die tolerante Host-Normalisierung der Web-Anzeige.
import 'package:flutter_test/flutter_test.dart';
import 'package:tickdone/services/app_konfiguration.dart';

void main() {
  group('AppKonfiguration.normalisiereHost', () {
    test('blanker Host bleibt unverändert', () {
      expect(AppKonfiguration.normalisiereHost('cloud.example.com'),
          'cloud.example.com');
    });

    test('Schema und End-Slash werden entfernt', () {
      expect(AppKonfiguration.normalisiereHost('https://cloud.example.com/'),
          'cloud.example.com');
      expect(AppKonfiguration.normalisiereHost('http://cloud.example.com'),
          'cloud.example.com');
    });

    test('Pfad bleibt erhalten (z.B. Nextcloud /remote.php/dav)', () {
      expect(
        AppKonfiguration.normalisiereHost(
            'https://cloud.example.com/remote.php/dav/'),
        'cloud.example.com/remote.php/dav',
      );
    });

    test('Leerzeichen werden getrimmt', () {
      expect(AppKonfiguration.normalisiereHost('  cloud.example.com  '),
          'cloud.example.com');
    });

    test('leerer Wert, null und nicht ersetzte envsubst-Variable → null', () {
      expect(AppKonfiguration.normalisiereHost(null), isNull);
      expect(AppKonfiguration.normalisiereHost(''), isNull);
      expect(AppKonfiguration.normalisiereHost('   '), isNull);
      expect(AppKonfiguration.normalisiereHost(r'${CALDAV_HOST}'), isNull);
    });
  });
}
