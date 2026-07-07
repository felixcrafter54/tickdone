import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Design-Auswahl (auf ThemeMode gemappt in main.dart).
enum ThemeWahl { system, hell, dunkel }

/// Persistierte App-Einstellungen mit Standardwerten.
class Einstellungen {
  final ThemeWahl theme;
  final bool neueAufgabeOben;
  final bool wichtigeOben;
  final bool loeschenBestaetigen;

  const Einstellungen({
    this.theme = ThemeWahl.system,
    this.neueAufgabeOben = true,
    this.wichtigeOben = true,
    this.loeschenBestaetigen = true,
  });

  Einstellungen copyWith({
    ThemeWahl? theme,
    bool? neueAufgabeOben,
    bool? wichtigeOben,
    bool? loeschenBestaetigen,
  }) =>
      Einstellungen(
        theme: theme ?? this.theme,
        neueAufgabeOben: neueAufgabeOben ?? this.neueAufgabeOben,
        wichtigeOben: wichtigeOben ?? this.wichtigeOben,
        loeschenBestaetigen: loeschenBestaetigen ?? this.loeschenBestaetigen,
      );
}

/// Speichert die Einstellungen (nicht geheim, aber wir nutzen den schon
/// vorhandenen sicheren Speicher, um keine weitere Abhängigkeit zu haben).
class Einstellungenspeicher {
  static const _theme = 'e_theme';
  static const _neuOben = 'e_neu_oben';
  static const _wichtigOben = 'e_wichtig_oben';
  static const _loeschBest = 'e_loeschen_bestaetigen';

  final FlutterSecureStorage _storage;

  Einstellungenspeicher([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<Einstellungen> laden() async {
    bool flag(String? v, bool standard) => v == null ? standard : v == 'true';
    final theme = switch (await _storage.read(key: _theme)) {
      'hell' => ThemeWahl.hell,
      'dunkel' => ThemeWahl.dunkel,
      _ => ThemeWahl.system,
    };
    return Einstellungen(
      theme: theme,
      neueAufgabeOben: flag(await _storage.read(key: _neuOben), true),
      wichtigeOben: flag(await _storage.read(key: _wichtigOben), true),
      loeschenBestaetigen: flag(await _storage.read(key: _loeschBest), true),
    );
  }

  Future<void> speichern(Einstellungen e) async {
    await _storage.write(key: _theme, value: e.theme.name);
    await _storage.write(key: _neuOben, value: '${e.neueAufgabeOben}');
    await _storage.write(key: _wichtigOben, value: '${e.wichtigeOben}');
    await _storage.write(key: _loeschBest, value: '${e.loeschenBestaetigen}');
  }
}
