import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';

import '../models/aufgabe.dart';
import '../services/caldav_service.dart';
import '../services/vtodo_patch.dart';

/// Sortierung der Aufgabenliste (Spec, Abschnitt 3).
enum Sortierung {
  manuell('Manuell'),
  faelligkeit('Fälligkeit'),
  wichtig('Wichtig'),
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
  wichtig('Wichtig');

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
      // Standardliste direkt öffnen, Detailbereich bleibt zu.
      if (aufgabenlisten.isNotEmpty) {
        await oeffneListe(aufgabenlisten.first);
      }
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

  /// Im Drei-Spalten-Layout (Desktop/Tablet): die gerade im Detailbereich
  /// gezeigte Aufgabe. Auf dem Handy ungenutzt (dort Push-Navigation).
  String? aktiveAufgabeUid;

  /// Aufgabe, über der der Mauszeiger schwebt (Desktop). Tastenkürzel
  /// wirken darauf. Bewusst OHNE notifyListeners – reine Ziel-Info,
  /// die kein Neuzeichnen braucht.
  String? hoverAufgabeUid;

  void setzeHover(String? uid) => hoverAufgabeUid = uid;

  /// Aufgabe für den Detailbereich wählen (null schließt ihn).
  void waehleAufgabe(String? uid) {
    if (aktiveAufgabeUid == uid) return;
    aktiveAufgabeUid = uid;
    notifyListeners();
  }

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
        AufgabenFilter.wichtig => a.wichtig,
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
      // Wichtige (Stern) zuerst.
      Sortierung.wichtig => (a, b) {
        if (a.wichtig == b.wichtig) return 0;
        return a.wichtig ? -1 : 1;
      },
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
    // Beim Listenwechsel keine alte Detail-Auswahl behalten.
    aktiveAufgabeUid = null;
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

  /// Anzahl laufender Hintergrund-Speicherungen – für die Sync-Anzeige oben.
  int _laufendeSpeicher = 0;
  bool get speichertGerade => _laufendeSpeicher > 0;

  void _speichernBegonnen() {
    _laufendeSpeicher++;
    notifyListeners();
  }

  void _speichernBeendet() {
    if (_laufendeSpeicher > 0) _laufendeSpeicher--;
    notifyListeners();
  }

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

  /// Fälligkeit setzen oder entfernen (sofort speichern).
  Future<void> setzeFaellig(String uid, DateTime? datum) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) => datum == null
            ? a.kopieMit(faelligEntfernen: true)
            : a.kopieMit(faellig: datum),
        patch: faelligPatch(datum),
      );

  /// "Wichtig" (Stern) setzen/entfernen – gespeichert als PRIORITY 1.
  Future<void> setzeWichtig(String uid, bool wichtig) =>
      _aendereUndSpeichere(
        uid,
        lokal: (a) => a.kopieMit(
          prioritaet: wichtig ? 1 : 0,
          favorit: wichtig ? null : false,
        ),
        patch: wichtigPatch(wichtig),
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
  /// Neue Aufgabe/Schritt OPTIMISTISCH anlegen: sofort unten anhängen und
  /// anzeigen, im Hintergrund speichern (kein Neuladen, kein Warten – so
  /// bleibt der Fokus im Eingabefeld für schnelle Mehrfacheingabe).
  Future<bool> erstelleAufgabe(String titel, {String? parentUid}) async {
    final liste = aktiveListe;
    final bereinigt = titel.trim();
    if (liste == null || bereinigt.isEmpty) return false;

    final uid = neueUid();
    // Neue Hauptaufgaben nach ganz oben (kleinste Sortierung); Schritte
    // ohne Sortierung, damit sie unten angehängt werden.
    final int? sortOrder =
        parentUid == null ? _naechsterSortWertOben() : null;
    final ical = neuesVTodoIcal(
      uid: uid,
      titel: bereinigt,
      parentUid: parentUid,
      sortOrder: sortOrder,
    );
    final href = liste.href.resolve('$uid.ics');
    final lokal = Aufgabe.ausICalendar(ical, href: href);
    if (lokal == null) return false;

    aufgaben.add(lokal);
    _speichernBegonnen();
    try {
      final etag = await _caldav.legeAnMitIcal(href: href, ical: ical);
      final index = aufgaben.indexWhere((a) => a.uid == uid);
      if (index >= 0) aufgaben[index] = aufgaben[index].kopieMit(etag: etag);
      return true;
    } catch (fehler) {
      aufgaben.removeWhere((a) => a.uid == uid);
      aufgabenFehler = 'Anlegen fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      return false;
    } finally {
      _speichernBeendet();
    }
  }

  /// Sortierwert, der eine neue Hauptaufgabe an den Anfang stellt:
  /// 1024 unter das aktuelle Minimum (kleiner = weiter oben).
  int _naechsterSortWertOben() {
    final werte = aufgaben
        .where((a) => !a.istSchritt && a.sortOrder != null)
        .map((a) => a.sortOrder!);
    final minWert = werte.isEmpty ? 1024 : werte.reduce((a, b) => a < b ? a : b);
    return minWert - 1024;
  }

  /// Schritt zur eigenständigen Aufgabe höherstufen
  /// (Design-Doc, Abschnitt 4: Eltern-Bezug entfernen).
  Future<void> stufeSchrittHoch(String uid) {
    final schritt = aufgabeMitUid(uid);
    if (schritt == null || !schritt.istSchritt) return Future.value();
    return _aendereUndSpeichere(
      uid,
      // Lokal sofort als Wurzel-Aufgabe zeigen: Neu-Parsen des
      // gepatchten iCals passiert nach dem Speichern automatisch.
      lokal: (a) => Aufgabe(
        uid: a.uid,
        titel: a.titel,
        erledigt: a.erledigt,
        parentUid: null,
        faellig: a.faellig,
        prioritaet: a.prioritaet,
        notiz: a.notiz,
        prozent: a.prozent,
        sequence: a.sequence,
        sortOrder: a.sortOrder,
        favorit: a.favorit,
        meinTag: a.meinTag,
        erstellt: a.erstellt,
        etag: a.etag,
        href: a.href,
        rohIcal: a.rohIcal,
      ),
      patch: hochstufenPatch(),
    );
  }

  /// Aufgabe samt ihrer Schritte in eine andere Liste verschieben
  /// (Design-Doc, Abschnitt 5).
  Future<bool> verschiebeAufgabe(String uid, Calendar ziel) async {
    final aufgabe = aufgabeMitUid(uid);
    if (aufgabe == null) return false;
    final zuVerschieben = [
      aufgabe,
      ...aufgaben.where((a) => a.parentUid == uid),
    ];
    aufgaben.removeWhere((a) => a.uid == uid || a.parentUid == uid);
    notifyListeners();
    try {
      for (final einzelne in zuVerschieben) {
        await _caldav.verschiebeAufgabe(einzelne, ziel);
      }
      await aufgabenNeuLaden();
      return true;
    } catch (fehler) {
      aufgabenFehler =
          'Verschieben fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      await aufgabenNeuLaden();
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

    _speichernBegonnen();
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
    }).whenComplete(_speichernBeendet);
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
    aktiveAufgabeUid = null;
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
