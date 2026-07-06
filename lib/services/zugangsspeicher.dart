import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gespeicherte Zugangsdaten (aus dem sicheren Speicher).
class Zugang {
  final String server;
  final String benutzer;
  final String passwort;

  /// Die zuletzt funktionierende, aufgelöste CalDAV-URL (spart beim
  /// nächsten Start die Discovery-Kette). Kann null sein.
  final String? aufloesung;

  const Zugang({
    required this.server,
    required this.benutzer,
    required this.passwort,
    this.aufloesung,
  });
}

/// Speichert die Zugangsdaten sicher (Android Keystore / Windows DPAPI /
/// Keychain …) über flutter_secure_storage.
class Zugangsspeicher {
  static const _server = 'server';
  static const _benutzer = 'benutzer';
  static const _passwort = 'passwort';
  static const _aufloesung = 'aufloesung';

  final FlutterSecureStorage _storage;

  // flutter_secure_storage 10.x verschlüsselt standardmäßig sicher
  // (Android Keystore-Cipher, Windows DPAPI, Keychain …).
  Zugangsspeicher([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> speichern({
    required String server,
    required String benutzer,
    required String passwort,
    String? aufloesung,
  }) async {
    await _storage.write(key: _server, value: server);
    await _storage.write(key: _benutzer, value: benutzer);
    await _storage.write(key: _passwort, value: passwort);
    if (aufloesung != null) {
      await _storage.write(key: _aufloesung, value: aufloesung);
    }
  }

  /// Lädt die Zugangsdaten – null, wenn nichts (Vollständiges) gespeichert ist.
  Future<Zugang?> laden() async {
    final server = await _storage.read(key: _server);
    final benutzer = await _storage.read(key: _benutzer);
    final passwort = await _storage.read(key: _passwort);
    if (server == null || benutzer == null || passwort == null) return null;
    return Zugang(
      server: server,
      benutzer: benutzer,
      passwort: passwort,
      aufloesung: await _storage.read(key: _aufloesung),
    );
  }

  Future<void> loeschen() async {
    await _storage.delete(key: _server);
    await _storage.delete(key: _benutzer);
    await _storage.delete(key: _passwort);
    await _storage.delete(key: _aufloesung);
  }
}
