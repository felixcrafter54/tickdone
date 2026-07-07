import 'dart:async';

import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';

import '../models/aufgabe.dart';
import '../services/caldav_service.dart';
import '../services/einstellungen_speicher.dart';
import '../services/vtodo_patch.dart';
import '../services/zugangsspeicher.dart';

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

/// Listenübergreifende Smart-Listen (wie MS To Do).
enum Smartliste {
  meinTag('Mein Tag'),
  wichtig('Wichtig'),
  geplant('Geplant');

  const Smartliste(this.anzeige);
  final String anzeige;
}

/// Zentraler App-Zustand: Verbindung und geladene Aufgabenlisten.
///
/// Bewusst einfach gehalten: EIN ChangeNotifier, den `provider` der
/// Widget-Hierarchie bereitstellt. Mehr Struktur (z.B. mehrere Notifier)
/// erst, wenn die App wirklich danach verlangt.
class AppState extends ChangeNotifier {
  final CalDavService _caldav = CalDavService();
  final Zugangsspeicher _speicher;
  final Einstellungenspeicher _einstellungenSpeicher;

  AppState([Zugangsspeicher? speicher, Einstellungenspeicher? einstellungen])
      : _speicher = speicher ?? Zugangsspeicher(),
        _einstellungenSpeicher = einstellungen ?? Einstellungenspeicher() {
    unawaited(_ladeEinstellungen());
  }

  // ---- Einstellungen ----

  Einstellungen einstellungen = const Einstellungen();

  Future<void> _ladeEinstellungen() async {
    try {
      einstellungen = await _einstellungenSpeicher.laden();
      notifyListeners();
    } catch (_) {
      // Kein Speicher verfügbar (z.B. Test) – bei Standardwerten bleiben.
    }
  }

  Future<void> _speichereEinstellungen(Einstellungen neu) async {
    einstellungen = neu;
    notifyListeners();
    await _einstellungenSpeicher.speichern(neu);
  }

  Future<void> setzeTheme(ThemeWahl theme) =>
      _speichereEinstellungen(einstellungen.copyWith(theme: theme));

  Future<void> setzeNeueAufgabeOben(bool oben) =>
      _speichereEinstellungen(einstellungen.copyWith(neueAufgabeOben: oben));

  Future<void> setzeWichtigeOben(bool oben) {
    final neu = _speichereEinstellungen(
        einstellungen.copyWith(wichtigeOben: oben));
    notifyListeners(); // Sortierung neu anwenden
    return neu;
  }

  Future<void> setzeLoeschenBestaetigen(bool an) => _speichereEinstellungen(
      einstellungen.copyWith(loeschenBestaetigen: an));

  bool laedt = false;
  String? fehlermeldung;
  List<Calendar> aufgabenlisten = [];

  bool get istVerbunden => _caldav.istVerbunden;
  String? get verbundeneUrl => _caldav.verbundeneUrl;

  /// Gespeicherte Zugangsdaten (für das Vorbefüllen des Login-Formulars,
  /// falls die automatische Anmeldung scheitert).
  Zugang? gespeicherterZugang;

  /// Beim Start EINMAL versuchen, mit gespeicherten Zugangsdaten anzumelden.
  /// Nutzt die zuletzt funktionierende URL (spart die Discovery-Kette).
  /// Gibt true zurück, wenn die automatische Anmeldung geklappt hat.
  Future<bool> automatischAnmelden() async {
    final zugang = await _speicher.laden();
    gespeicherterZugang = zugang;
    if (zugang == null) return false;
    return anmelden(
      serverUrl: zugang.aufloesung ?? zugang.server,
      benutzer: zugang.benutzer,
      passwort: zugang.passwort,
      // Beim Auto-Login den ursprünglich eingegebenen Server als Anzeige
      // behalten (nicht die aufgelöste URL).
      anzeigeServer: zugang.server,
    );
  }

  /// Anmelden und direkt die Aufgabenlisten laden.
  /// Gibt true zurück, wenn beides geklappt hat. Bei Erfolg werden die
  /// Zugangsdaten sicher gespeichert.
  Future<bool> anmelden({
    required String serverUrl,
    required String benutzer,
    required String passwort,
    String? anzeigeServer,
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
      // Zugangsdaten + funktionierende URL sicher speichern.
      await _speicher.speichern(
        server: anzeigeServer ?? serverUrl,
        benutzer: benutzer,
        passwort: passwort,
        aufloesung: _caldav.verbundeneUrl,
      );
      // Standardliste direkt öffnen, Detailbereich bleibt zu.
      if (aufgabenlisten.isNotEmpty) {
        await oeffneListe(aufgabenlisten.first);
      }
      // Offene-Zähler für die Sidebar im Hintergrund nachladen.
      unawaited(aktualisiereOffeneAnzahlen());
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
      unawaited(aktualisiereOffeneAnzahlen());
    } catch (fehler) {
      fehlermeldung = _lesbareMeldung(fehler);
    } finally {
      laedt = false;
      notifyListeners();
    }
  }

  // ---- Offene-Aufgaben-Zähler je Liste + Cache für Smart-Listen ----

  /// Gecachte Anzahl offener Wurzel-Aufgaben je Listen-UID (für andere als
  /// die aktive Liste). Die aktive Liste wird live aus [aufgaben] gezählt.
  final Map<String, int> _offeneAnzahl = {};

  /// Zuletzt geladene Aufgaben je Liste (für die listenübergreifenden
  /// Smart-Listen). Wird bei aktualisiereOffeneAnzahlen befüllt.
  final Map<String, List<Aufgabe>> _cacheProListe = {};

  List<Aufgabe> get _alleAufgaben =>
      [for (final liste in _cacheProListe.values) ...liste];

  /// Anzahl offener (nicht erledigter) Wurzel-Aufgaben einer Liste –
  /// null, solange noch nicht ermittelt.
  int? offeneAnzahl(String listenUid) {
    if (listenUid == aktiveListe?.uid) {
      return aufgaben.where((a) => !a.istSchritt && !a.erledigt).length;
    }
    return _offeneAnzahl[listenUid];
  }

  bool _passtZuSmart(Aufgabe a, Smartliste s) => switch (s) {
        Smartliste.meinTag => a.meinTag,
        Smartliste.wichtig => a.wichtig,
        Smartliste.geplant => a.faellig != null,
      };

  /// Anzahl offener Aufgaben in einer Smart-Liste (listenübergreifend).
  int smartAnzahl(Smartliste s) => _alleAufgaben
      .where((a) => !a.istSchritt && !a.erledigt && _passtZuSmart(a, s))
      .length;

  /// Lädt für alle Listen die Aufgaben, füllt den Cache und zählt die
  /// offenen Wurzel-Aufgaben. Läuft parallel; ist eine Smart-Liste offen,
  /// wird deren Anzeige danach neu aufgebaut.
  Future<void> aktualisiereOffeneAnzahlen() async {
    if (!istVerbunden) return;
    final listen = List<Calendar>.from(aufgabenlisten);
    await Future.wait(listen.map((liste) async {
      try {
        final aufg = await _caldav.ladeAufgaben(liste);
        _cacheProListe[liste.uid] = aufg;
        _offeneAnzahl[liste.uid] =
            aufg.where((a) => !a.istSchritt && !a.erledigt).length;
      } catch (_) {
        // Zähler dieser Liste bleibt einfach unbekannt.
      }
    }));
    if (aktiveSmartliste != null) {
      aufgaben = List<Aufgabe>.from(_alleAufgaben);
    }
    notifyListeners();
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

  /// Liste umbenennen.
  Future<bool> benenneListeUm(Calendar liste, String neuerName) async {
    final bereinigt = neuerName.trim();
    if (bereinigt.isEmpty || bereinigt == liste.displayName) return false;
    try {
      await _caldav.benenneListeUm(liste, bereinigt);
      await listenNeuLaden();
      return true;
    } catch (fehler) {
      fehlermeldung =
          'Umbenennen fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      notifyListeners();
      return false;
    }
  }

  /// Liste duplizieren (mit allen Aufgaben).
  Future<bool> dupliziereListe(Calendar liste, String neuerName) async {
    final bereinigt = neuerName.trim();
    if (bereinigt.isEmpty) return false;
    laedt = true;
    notifyListeners();
    try {
      await _caldav.dupliziereListe(liste, bereinigt);
      await listenNeuLaden();
      unawaited(aktualisiereOffeneAnzahlen());
      return true;
    } catch (fehler) {
      fehlermeldung =
          'Duplizieren fehlgeschlagen: ${_lesbareMeldung(fehler)}';
      return false;
    } finally {
      laedt = false;
      notifyListeners();
    }
  }

  // ---- Aufgaben der geöffneten Liste / Smart-Liste ----

  Calendar? aktiveListe;

  /// Ist eine Smart-Liste offen, ist [aktiveListe] null und [aufgaben]
  /// enthält die Aufgaben ALLER Listen (gefiltert wird in wurzelAufgaben).
  Smartliste? aktiveSmartliste;

  List<Aufgabe> aufgaben = [];
  bool aufgabenLaden = false;
  String? aufgabenFehler;

  /// Titel der aktuellen Ansicht (Liste oder Smart-Liste).
  String get ansichtTitel =>
      aktiveSmartliste?.anzeige ?? aktiveListe?.displayName ?? 'Aufgaben';

  /// Ob gerade überhaupt eine Ansicht (Liste oder Smart-Liste) offen ist.
  bool get hatAnsicht => aktiveListe != null || aktiveSmartliste != null;

  /// Smart-Liste öffnen (listenübergreifend). Zeigt sofort den Cache und
  /// frischt im Hintergrund auf.
  void oeffneSmartliste(Smartliste s) {
    aktiveSmartliste = s;
    aktiveListe = null;
    aktiveAufgabeUid = null;
    aufgabenFehler = null;
    aufgaben = List<Aufgabe>.from(_alleAufgaben);
    notifyListeners();
    unawaited(aktualisiereOffeneAnzahlen());
  }

  /// Im Drei-Spalten-Layout (Desktop/Tablet): die gerade im Detailbereich
  /// gezeigte Aufgabe. Auf dem Handy ungenutzt (dort Push-Navigation).
  String? aktiveAufgabeUid;

  /// Aufgabe, über der der Mauszeiger schwebt (Desktop). Tastenkürzel
  /// wirken darauf. Bewusst OHNE notifyListeners – reine Ziel-Info,
  /// die kein Neuzeichnen braucht.
  String? hoverAufgabeUid;

  void setzeHover(String? uid) => hoverAufgabeUid = uid;

  /// Liste, über der der Mauszeiger schwebt (Sidebar). Für die
  /// Listen-Tastenkürzel (F2 umbenennen, Entf löschen). Ohne notify.
  String? hoverListeUid;

  void setzeListenHover(String? uid) => hoverListeUid = uid;

  /// Liste per UID – null, wenn nicht (mehr) vorhanden.
  Calendar? listeMitUid(String? uid) {
    if (uid == null) return null;
    for (final l in aufgabenlisten) {
      if (l.uid == uid) return l;
    }
    return null;
  }

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
    final smart = aktiveSmartliste;
    final gefiltert = aufgaben.where((a) {
      if (a.istSchritt) return false;
      // In einer Smart-Liste nur passende Aufgaben (listenübergreifend).
      if (smart != null && !_passtZuSmart(a, smart)) return false;
      return switch (filter) {
        AufgabenFilter.alle => true,
        AufgabenFilter.offen => !a.erledigt,
        AufgabenFilter.erledigt => a.erledigt,
        AufgabenFilter.wichtig => a.wichtig,
      };
    }).toList();
    final vergleicher = _vergleicher(sortierung);
    if (einstellungen.wichtigeOben) {
      // Wichtige Aufgaben immer zuerst, dann die gewählte Sortierung.
      gefiltert.sort((a, b) {
        if (a.wichtig != b.wichtig) return a.wichtig ? -1 : 1;
        return vergleicher(a, b);
      });
    } else {
      gefiltert.sort(vergleicher);
    }
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
    final schritte = aufgaben.where((a) => a.parentUid == parentUid).toList()
      ..sort(_schrittVergleich);
    return schritte;
  }

  /// Stabile Schritt-Reihenfolge: primär X-APPLE-SORT-ORDER (ohne Wert ans
  /// Ende), sekundär der Erstell-Zeitstempel. Da CREATED sich nie ändert,
  /// bleibt die Reihenfolge auch nach einem Neuladen erhalten (sonst käme
  /// die undeterministische Server-Reihenfolge durch).
  static int _schrittVergleich(Aufgabe a, Aufgabe b) {
    const ohneWert = 1 << 30;
    final sa = a.sortOrder ?? ohneWert;
    final sb = b.sortOrder ?? ohneWert;
    if (sa != sb) return sa.compareTo(sb);
    final ea = a.erstellt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final eb = b.erstellt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ea.compareTo(eb);
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
    aktiveSmartliste = null;
    aufgaben = [];
    aufgabenFehler = null;
    // Beim Listenwechsel keine alte Detail-Auswahl behalten.
    aktiveAufgabeUid = null;
    await aufgabenNeuLaden();
  }

  /// Aufgaben der aktuellen Ansicht (neu) vom Server holen.
  Future<void> aufgabenNeuLaden() async {
    if (!istVerbunden) return;
    // Smart-Liste: alle Listen frisch laden und Anzeige neu aufbauen.
    if (aktiveSmartliste != null) {
      aufgabenLaden = true;
      notifyListeners();
      await aktualisiereOffeneAnzahlen();
      aufgabenLaden = false;
      notifyListeners();
      return;
    }
    final liste = aktiveListe;
    if (liste == null) return;
    aufgabenLaden = true;
    aufgabenFehler = null;
    notifyListeners();
    try {
      aufgaben = await _caldav.ladeAufgaben(liste);
      _cacheProListe[liste.uid] = aufgaben;
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

  /// Aufgabe per Drag & Drop umsortieren (nur in Sortierung "Manuell").
  /// [neuIndex] ist bereits um das entfernte Element angepasst
  /// (ReorderableListView.onReorderItem). Vergibt neue
  /// X-APPLE-SORT-ORDER-Werte im Abstand 1024 und speichert nur die
  /// geänderten – optimistisch, ohne Neuladen.
  Future<void> ordneAufgabenNeu(int altIndex, int neuIndex) =>
      _ordneNeu(List<Aufgabe>.from(wurzelAufgaben), altIndex, neuIndex);

  /// Schritte einer Aufgabe per Drag & Drop umsortieren.
  Future<void> ordneSchritteNeu(
          String parentUid, int altIndex, int neuIndex) =>
      _ordneNeu(schritteVon(parentUid), altIndex, neuIndex);

  Future<void> _ordneNeu(
      List<Aufgabe> liste, int altIndex, int neuIndex) async {
    if (altIndex < 0 || altIndex >= liste.length) return;
    final ziel = neuIndex.clamp(0, liste.length - 1);
    if (ziel == altIndex) return;
    final bewegt = liste.removeAt(altIndex);
    liste.insert(ziel, bewegt);
    // Erst ALLE neuen Reihenfolge-Werte lokal setzen und nur EINMAL neu
    // zeichnen: So steht die Liste sofort komplett in der neuen Reihenfolge,
    // statt dass die Karten sichtbar nacheinander an ihren Platz springen.
    final zuSpeichern = <String, int>{};
    for (var i = 0; i < liste.length; i++) {
      final wert = (i + 1) * 1024;
      if (liste[i].sortOrder != wert) {
        _ersetzeAufgabe(liste[i].kopieMit(sortOrder: wert));
        zuSpeichern[liste[i].uid] = wert;
      }
    }
    if (zuSpeichern.isEmpty) return;
    notifyListeners();
    // Danach im Hintergrund speichern (parallel je UID, keine sichtbaren
    // Einzelschritte mehr).
    await Future.wait([
      for (final eintrag in zuSpeichern.entries)
        _speichereNur(eintrag.key, sortOrderPatch(eintrag.value)),
    ]);
  }

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
    final int? sortOrder = parentUid == null
        ? (einstellungen.neueAufgabeOben
            ? _naechsterSortWertOben()
            : _naechsterSortWertUnten())
        : null;
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

  /// Sortierwert, der eine neue Hauptaufgabe ans Ende stellt:
  /// 1024 über das aktuelle Maximum (größer = weiter unten).
  int _naechsterSortWertUnten() {
    final werte = aufgaben
        .where((a) => !a.istSchritt && a.sortOrder != null)
        .map((a) => a.sortOrder!);
    final maxWert = werte.isEmpty ? 1024 : werte.reduce((a, b) => a > b ? a : b);
    return maxWert + 1024;
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
      // Ziel-Liste hat jetzt mehr, Quell-Liste weniger – Zähler auffrischen.
      unawaited(aktualisiereOffeneAnzahlen());
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
    return _speichereNur(uid, patch);
  }

  /// Reiht nur das Speichern eines Patches in die Kette der UID ein – ohne
  /// lokale Änderung und ohne notifyListeners. Der lokale Stand muss also
  /// bereits gesetzt sein (z.B. beim Umsortieren, wo alle Werte auf einmal
  /// lokal geändert und nur einmal gezeichnet werden).
  Future<void> _speichereNur(String uid, IcalPatch patch) {
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
    // Zähler-Cache lokal mitziehen: So passen sich Offen- und Smart-Listen-
    // Zähler sofort an, ohne erneute Server-Abfrage – z.B. wenn in der
    // Wichtig-Liste ein Stern entfernt wird, sinkt die Anzahl direkt.
    for (final eintrag in _cacheProListe.entries) {
      final i = eintrag.value.indexWhere((a) => a.uid == neue.uid);
      if (i >= 0) {
        eintrag.value[i] = neue;
        _offeneAnzahl[eintrag.key] =
            eintrag.value.where((a) => !a.istSchritt && !a.erledigt).length;
        break;
      }
    }
  }

  /// Verbindung trennen, gespeicherte Zugangsdaten löschen, Zustand leeren.
  Future<void> abmelden() async {
    _caldav.trennen();
    await _speicher.loeschen();
    gespeicherterZugang = null;
    aufgabenlisten = [];
    aktiveListe = null;
    aktiveSmartliste = null;
    aktiveAufgabeUid = null;
    aufgaben = [];
    _cacheProListe.clear();
    _offeneAnzahl.clear();
    aufgabenFehler = null;
    fehlermeldung = null;
    notifyListeners();
  }

  /// Technische Präfixe entfernen, damit die Meldung in der UI lesbar ist.
  String _lesbareMeldung(Object fehler) {
    return fehler.toString().replaceFirst('Exception: ', '');
  }
}
