import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';

import '../models/aufgabe.dart';
import '../services/caldav_service.dart';
import '../services/vtodo_patch.dart';

/// Sortierung der Aufgabenliste (Spec, Abschnitt 3).
enum Sortierung {
  manuell('Manuell'),
  faelligkeit('Fälligkeit'),
  prioritaet('Priorität'),
  titel('Titel'),
  erstellt('Erstellt');

  const Sortierung(this.anzeige);
  final String anzeige;
}

/// Filter der Aufgabenliste (Spec, Abschnitt 3).
enum AufgabenFilter {
  alle('Alle'),
  offen('Offen'),
  erledigt('Erledigt'),
  favoriten('Favoriten');

  const AufgabenFilter(this.anzeige);
  final String anzeige;
}

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

  /// Neue Aufgabenliste anlegen und die Übersicht aktualisieren.
  Future<bool> erstelleListe(String name) async {
    final bereinigt = name.trim();
    if (bereinigt.isEmpty || !istVerbunden) return false;
    try {
      await _caldav.erstelleListe(bereinigt);
      await listenNeuLaden();
      return true;
    } catch (fehler) {
      fehlermeldung = 'Liste anlegen fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      notifyListeners();
      return false;
    }
  }

  /// Liste samt Inhalt löschen.
  Future<bool> loescheListe(Calendar liste) async {
    try {
      await _caldav.loescheListe(liste);
      if (aktiveListe?.uid == liste.uid) {
        aktiveListe = null;
        aufgaben = [];
      }
      await listenNeuLaden();
      return true;
    } catch (fehler) {
      fehlermeldung = 'Liste löschen fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      notifyListeners();
      return false;
    }
  }

  // ---- Aufgaben der geöffneten Liste ----

  Calendar? aktiveListe;
  List<Aufgabe> aufgaben = [];
  bool aufgabenLaden = false;
  String? aufgabenFehler;

  Sortierung sortierung = Sortierung.manuell;
  AufgabenFilter filter = AufgabenFilter.alle;

  void setzeSortierung(Sortierung neue) {
    sortierung = neue;
    notifyListeners();
  }

  void setzeFilter(AufgabenFilter neuer) {
    filter = neuer;
    notifyListeners();
  }

  /// Nur die Wurzel-Aufgaben, gefiltert und sortiert – Schritte (Subtasks)
  /// erscheinen erst in der Detailansicht (Spec, Abschnitt 3).
  List<Aufgabe> get wurzelAufgaben {
    final gefiltert = aufgaben.where((a) {
      if (a.istSchritt) return false;
      return switch (filter) {
        AufgabenFilter.alle => true,
        AufgabenFilter.offen => !a.erledigt,
        AufgabenFilter.erledigt => a.erledigt,
        AufgabenFilter.favoriten => a.favorit,
      };
    }).toList();
    gefiltert.sort(_vergleicher(sortierung));
    return gefiltert;
  }

  /// Vergleicher je Sortierung; fehlende Werte immer ans Ende.
  static int Function(Aufgabe, Aufgabe) _vergleicher(Sortierung sortierung) {
    int fehlendeAnsEnde<T>(T? a, T? b, int Function(T, T) vergleich) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return vergleich(a, b);
    }

    return switch (sortierung) {
      Sortierung.manuell => (a, b) =>
          fehlendeAnsEnde(a.sortOrder, b.sortOrder, (x, y) => x.compareTo(y)),
      Sortierung.faelligkeit => (a, b) =>
          fehlendeAnsEnde(a.faellig, b.faellig, (x, y) => x.compareTo(y)),
      // 0 = keine Priorität gilt als fehlend, 1 (hoch) kommt zuerst.
      Sortierung.prioritaet => (a, b) => fehlendeAnsEnde(
          a.prioritaet == 0 ? null : a.prioritaet,
          b.prioritaet == 0 ? null : b.prioritaet,
          (x, y) => x.compareTo(y)),
      Sortierung.titel => (a, b) =>
          a.titel.toLowerCase().compareTo(b.titel.toLowerCase()),
      // Neueste zuerst.
      Sortierung.erstellt => (a, b) =>
          fehlendeAnsEnde(a.erstellt, b.erstellt, (x, y) => y.compareTo(x)),
    };
  }

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

  // ---- Ändern, Abhaken, Erstellen (Spec Schritt 6) ----

  /// Pro UID läuft immer nur EIN Speichern gleichzeitig; weitere
  /// Änderungen werden hinten angehängt (Spec, Abschnitt 2).
  final Map<String, Future<void>> _speicherKette = {};

  /// Abhaken bzw. wieder öffnen – optimistisch.
  Future<void> setzeErledigt(String uid, bool erledigt) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) =>
            a.kopieMit(erledigt: erledigt, prozent: erledigt ? 100 : 0),
        patch: erledigtPatch(erledigt),
      );

  /// Titel ändern (Auto-Save beim Verlassen des Feldes).
  Future<void> setzeTitel(String uid, String titel) {
    final bereinigt = titel.trim();
    if (bereinigt.isEmpty || aufgabeMitUid(uid)?.titel == bereinigt) {
      return Future.value();
    }
    return _aendereUndSpeichere(
      uid,
      lokal: (a) => a.kopieMit(titel: bereinigt),
      patch: titelPatch(bereinigt),
    );
  }

  /// Notiz ändern (Auto-Save beim Verlassen des Feldes, Spec Abschnitt 3).
  Future<void> setzeNotiz(String uid, String notiz) {
    if (aufgabeMitUid(uid)?.notiz == notiz) return Future.value();
    return _aendereUndSpeichere(
      uid,
      lokal: (a) => a.kopieMit(notiz: notiz),
      patch: notizPatch(notiz),
    );
  }

  /// Priorität ändern (sofort speichern).
  Future<void> setzePrioritaet(String uid, int prioritaet) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) => a.kopieMit(prioritaet: prioritaet),
        patch: prioritaetPatch(prioritaet),
      );

  /// Fälligkeit setzen oder entfernen (sofort speichern).
  Future<void> setzeFaellig(String uid, DateTime? datum) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) => datum == null
            ? a.kopieMit(faelligEntfernen: true)
            : a.kopieMit(faellig: datum),
        patch: faelligPatch(datum),
      );

  /// Favorit setzen/entfernen (sofort speichern).
  Future<void> setzeFavorit(String uid, bool favorit) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) => a.kopieMit(favorit: favorit),
        patch: favoritPatch(favorit),
      );

  /// "Mein Tag" setzen/entfernen (sofort speichern).
  /// Der Marker trägt das heutige Datum und verfällt über Nacht.
  Future<void> setzeMeinTag(String uid, bool meinTag) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) => a.kopieMit(meinTag: meinTag),
        patch: meinTagPatch(meinTag),
      );

  /// Neue Aufgabe (oder mit [parentUid] einen Schritt) anlegen.
  /// Nur hier wird die Liste neu geladen (Spec, Abschnitt 3).
  Future<bool> erstelleAufgabe(String titel, {String? parentUid}) async {
    final liste = aktiveListe;
    final bereinigt = titel.trim();
    if (liste == null || bereinigt.isEmpty) return false;
    try {
      await _caldav.erstelleAufgabe(liste,
          titel: bereinigt, parentUid: parentUid);
      await aufgabenNeuLaden();
      return true;
    } catch (fehler) {
      aufgabenFehler = 'Anlegen fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      notifyListeners();
      return false;
    }
  }

  /// Aufgabe samt ihrer Schritte löschen (wie in der Desktop-App:
  /// Schritte hängen an der Aufgabe und gehen mit ihr).
  /// Optimistisch aus der Anzeige entfernt, danach neu geladen
  /// (Spec: bei Anlegen/Löschen neu laden).
  Future<bool> loescheAufgabe(String uid) async {
    final aufgabe = aufgabeMitUid(uid);
    if (aufgabe == null) return false;
    final zuLoeschen = [
      ...aufgaben.where((a) => a.parentUid == uid),
      aufgabe,
    ];
    aufgaben.removeWhere((a) => a.uid == uid || a.parentUid == uid);
    notifyListeners();
    try {
      for (final einzelne in zuLoeschen) {
        await _caldav.loescheAufgabe(einzelne);
      }
      await aufgabenNeuLaden();
      return true;
    } catch (fehler) {
      aufgabenFehler = 'Löschen fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      // Anzeige wieder mit dem Server abgleichen.
      await aufgabenNeuLaden();
      return false;
    }
  }

  /// Kern der optimistischen Updates: lokal sofort ändern und anzeigen,
  /// dann im Hintergrund speichern – OHNE die Liste neu zu laden.
  /// Schlägt das Speichern endgültig fehl, wird neu geladen, damit die
  /// Anzeige wieder dem Server entspricht.
  Future<void> _aendereUndSpeichere(
    String uid, {
    required Aufgabe Function(Aufgabe) lokal,
    required IcalPatch patch,
  }) {
    final aufgabe = aufgabeMitUid(uid);
    if (aufgabe == null) return Future.value();

    _ersetzeAufgabe(lokal(aufgabe));
    notifyListeners();

    final vorgaenger = _speicherKette[uid] ?? Future.value();
    final eigener = vorgaenger.then((_) async {
      // Frischen Stand nehmen: Ein vorheriges Update in der Kette kann
      // ETag und Roh-iCalendar bereits geändert haben.
      final aktuelle = aufgabeMitUid(uid);
      if (aktuelle == null) return;
      try {
        final gespeichert = await _caldav.speichereAenderung(aktuelle, patch);
        _ersetzeAufgabe(gespeichert);
      } catch (fehler) {
        aufgabenFehler =
            'Speichern fehlgeschlagen: ${_lesbareMeldung(fehler)}';
        await aufgabenNeuLaden();
      }
      notifyListeners();
    });
    _speicherKette[uid] = eigener;
    return eigener;
  }

  void _ersetzeAufgabe(Aufgabe neue) {
    final index = aufgaben.indexWhere((a) => a.uid == neue.uid);
    if (index >= 0) {
      aufgaben[index] = neue;
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
