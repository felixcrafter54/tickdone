import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';

import '../models/aufgabe.dart';
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

  // ---- Aufgaben der geöffneten Liste ----

  Calendar? aktiveListe;
  List<Aufgabe> aufgaben = [];
  bool aufgabenLaden = false;
  String? aufgabenFehler;

  /// Nur die Wurzel-Aufgaben – Schritte (Subtasks) erscheinen erst
  /// in der Detailansicht (Spec, Abschnitt 3).
  List<Aufgabe> get wurzelAufgaben =>
      aufgaben.where((a) => !a.istSchritt).toList();

  /// Aufgabe per UID – null, wenn sie (nach einem Neuladen) nicht mehr da ist.
  Aufgabe? aufgabeMitUid(String uid) =>
      aufgaben.where((a) => a.uid == uid).firstOrNull;

  /// Die Schritte einer Aufgabe, manuell sortiert (X-APPLE-SORT-ORDER,
  /// ohne Wert ans Ende).
  List<Aufgabe> schritteVon(String parentUid) {
    final schritte =
        aufgaben.where((a) => a.parentUid == parentUid).toList()
          ..sort((a, b) {
            if (a.sortOrder == null && b.sortOrder == null) return 0;
            if (a.sortOrder == null) return 1;
            if (b.sortOrder == null) return -1;
            return a.sortOrder!.compareTo(b.sortOrder!);
          });
    return schritte;
  }

  /// Fortschritt "x von y" – null, wenn die Aufgabe keine Schritte hat.
  ({int erledigt, int gesamt})? fortschrittVon(String uid) {
    final schritte = aufgaben.where((a) => a.parentUid == uid);
    if (schritte.isEmpty) return null;
    return (
      erledigt: schritte.where((s) => s.erledigt).length,
      gesamt: schritte.length,
    );
  }

  /// Liste öffnen und ihre Aufgaben laden.
  Future<void> oeffneListe(Calendar liste) async {
    aktiveListe = liste;
    aufgaben = [];
    aufgabenFehler = null;
    await aufgabenNeuLaden();
  }

  /// Aufgaben der aktiven Liste (neu) vom Server holen.
  Future<void> aufgabenNeuLaden() async {
    final liste = aktiveListe;
    if (liste == null || !istVerbunden) return;
    aufgabenLaden = true;
    aufgabenFehler = null;
    notifyListeners();
    try {
      aufgaben = await _caldav.ladeAufgaben(liste);
    } catch (fehler) {
      aufgabenFehler = _lesbareMeldung(fehler);
    } finally {
      aufgabenLaden = false;
      notifyListeners();
    }
  }

  /// Verbindung trennen und Zustand leeren.
  void abmelden() {
    _caldav.trennen();
    aufgabenlisten = [];
    aktiveListe = null;
    aufgaben = [];
    aufgabenFehler = null;
    fehlermeldung = null;
    notifyListeners();
  }

  /// Technische Präfixe entfernen, damit die Meldung in der UI lesbar ist.
  String _lesbareMeldung(Object fehler) {
    return fehler.toString().replaceFirst('Exception: ', '');
  }
}
