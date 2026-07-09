// Tests für die Host-Anzeige der Web-App (Wert wie in der ENV eingetragen).
import 'package:flutter_test/flutter_test.dart';
import 'package:tickdone/services/app_konfiguration.dart';

void main() {
  group('AppKonfiguration.anzeigeHost', () {
    test('zeigt den Wert unverändert an (wie in der ENV eingetragen)', () {
      expect(AppKonfiguration.anzeigeHost('cloud.example.com'),
          'cloud.example.com');
      expect(AppKonfiguration.anzeigeHost('https://cloud.example.com/'),
          'https://cloud.example.com/');
      expect(
        AppKonfiguration.anzeigeHost('https://cloud.example.com/remote.php/dav'),
        'https://cloud.example.com/remote.php/dav',
      );
    });

    test('trimmt nur umgebenden Leerraum', () {
      expect(AppKonfiguration.anzeigeHost('  cloud.example.com  '),
          'cloud.example.com');
    });

    test('leerer Wert, null und nicht ersetzte envsubst-Variable → null', () {
      expect(AppKonfiguration.anzeigeHost(null), isNull);
      expect(AppKonfiguration.anzeigeHost(''), isNull);
      expect(AppKonfiguration.anzeigeHost('   '), isNull);
      expect(AppKonfiguration.anzeigeHost(r'${CALDAV_HOST}'), isNull);
    });
  });
}
