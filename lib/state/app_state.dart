import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';

import '../services/caldav_service.dart';

/// Zentraler App-Zustand: Verbindung und geladene Aufgabenlisten.
///
/// Bewusst einfach gehalten: EIN ChangeNotifier, den `provider` der
/// Widget-Hierarchie bereitstellt. Mehr Struktur (z.B. mehrere Notifier)
/// erst, wenn die App wirklich danach verlangt.
class AppState extends ChangeNotifier {
  final CalDavService _caldav = CalDavService();

  bool laedt = false;
  String? fehlermeldung;
  List<Calendar> aufgabenlisten = [];

  bool get istVerbunden => _caldav.istVerbunden;
  String? get verbundeneUrl => _caldav.verbundeneUrl;

  /// Anmelden und direkt die Aufgabenlisten laden.
  /// Gibt true zurück, wenn beides geklappt hat.
  Future<bool> anmelden({
    required String serverUrl,
    required String benutzer,
    required String passwort,
  }) async {
    laedt = true;
    fehlermeldung = null;
    notifyListeners();
    try {
      await _caldav.verbinden(
        serverUrl: serverUrl,
        benutzer: benutzer,
        passwort: passwort,
      );
      aufgabenlisten = await _caldav.ladeAufgabenlisten();
      return true;
    } catch (fehler) {
      fehlermeldung = _lesbareMeldung(fehler);
      return false;
    } finally {
      laedt = false;
      notifyListeners();
    }
  }

  /// Listen neu vom Server holen (z.B. per Pull-to-Refresh).
  Future<void> listenNeuLaden() async {
    if (!istVerbunden) return;
    laedt = true;
    fehlermeldung = null;
    notifyListeners();
    try {
      aufgabenlisten = await _caldav.ladeAufgabenlisten();
    } catch (fehler) {
      fehlermeldung = _lesbareMeldung(fehler);
    } finally {
      laedt = false;
      notifyListeners();
    }
  }

  /// Verbindung trennen und Zustand leeren.
  void abmelden() {
    _caldav.trennen();
    aufgabenlisten = [];
    fehlermeldung = null;
    notifyListeners();
  }

  /// Technische Präfixe entfernen, damit die Meldung in der UI lesbar ist.
  String _lesbareMeldung(Object fehler) {
    return fehler.toString().replaceFirst('Exception: ', '');
  }
}
