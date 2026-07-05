# Tickdone Mobile – Spezifikation & CalDAV-Wissen

Diese Datei fasst das im Python-Desktop-Projekt (PySide6) erarbeitete Wissen
zusammen, damit die Flutter-App darauf aufbauen kann, statt bei null zu starten.
Die App ist ein CalDAV-Aufgabenclient (VTODO) im Stil von Microsoft To Do.

---

## 1. Ziel & Umfang

- Mobile App (Android zuerst, iOS möglich) mit Flutter/Dart.
- Spricht denselben CalDAV-Server wie die Desktop-App (Radicale/Baïkal/Nextcloud).
- Kernfunktionen wie Desktop: Konten, Listen, Aufgaben, Schritte (Subtasks),
  Favoriten, "Mein Tag", Fälligkeit, Priorität, Notiz, Sortieren, Filtern.

---

## 2. CalDAV – das Wichtigste (hier steckt die eigentliche Arbeit)

### Verbindung / Discovery
- Server-URL vom Nutzer, meist nur Domain. Kalenderpfad automatisch suchen:
  Reihenfolge der Kandidaten: gecachte URL (falls vorhanden) → eingegebene URL →
  `<base>/.well-known/caldav` → `<base>` → `<base>/caldav` → `<base>/radicale`.
- Nach erfolgreicher Verbindung den funktionierenden Pfad speichern und beim
  nächsten Start zuerst probieren (spart 2–3 Requests).
- Auth: HTTP Basic. Bei OpenCloud/manchen Servern App-Token statt Passwort.

### Aufgaben laden – KRITISCH für Performance
- EINEN `REPORT` (calendar-query) auf die Collection schicken, der die
  Kalenderdaten (calendar-data) direkt mitliefert. NICHT pro Aufgabe ein GET.
  (Im Python-Projekt: 1 Request statt 24, ~15x schneller.)
- Nach VTODO filtern (comp-filter VTODO), aber NICHT nach STATUS filtern –
  sonst verschwinden Aufgaben ohne STATUS-Feld.

### iCalendar (VTODO) – relevante Felder
- `UID` – eindeutige ID
- `SUMMARY` – Titel
- `STATUS` – NEEDS-ACTION | COMPLETED (kann fehlen!)
- `DUE` – Fälligkeit (Datum oder Datetime)
- `PRIORITY` – 0 keine, 1 hoch, 5 mittel, 9 niedrig
- `DESCRIPTION` – Notiz
- `PERCENT-COMPLETE` – 0..100
- `SEQUENCE` – Änderungszähler, bei jeder Änderung +1 (für Sync)
- `LAST-MODIFIED`, `DTSTAMP`, `CREATED` – Zeitstempel
- `RELATED-TO;RELTYPE=PARENT` – Verweis auf Eltern-UID (Subtask-Hierarchie)
- `X-APPLE-SORT-ORDER` – Zahl für manuelle Reihenfolge
- `CATEGORIES` – enthält Marker:
  - `FAVORITE` → Favorit
  - `MYDAY-<YYYY-MM-DD>` → "Mein Tag", nur gültig wenn Datum == heute

### Subtask-Hierarchie (WICHTIG, kompatibel mit jtx Board auf Android)
- Eltern-Kind über `RELATED-TO;RELTYPE=PARENT: <eltern-uid>`.
- jtx schreibt RELATED-TO teils mehrwertig (PARENT und CHILD). Nur den Eintrag
  mit RELTYPE=PARENT (oder ganz ohne RELTYPE) als Elternverweis werten.
- Beim Schreiben immer `RELTYPE=PARENT` setzen.

### Speichern / Sync
- Beim Ändern: SEQUENCE +1, LAST-MODIFIED = jetzt.
- ETag mitführen. Beim PUT den ETag als `If-Match` senden.
- Bei HTTP 412 (ETag-Konflikt): Objekt frisch per UID holen, Änderung erneut
  anwenden, nochmal speichern.
- Pro UID nur EIN Update gleichzeitig laufen lassen; weitere Änderungen queuen
  und nach Abschluss als einen weiteren Save nachschicken.

### Listen
- Collections des Principals auflisten, die VTODO unterstützen.
- Anlegen: MKCALENDAR mit supported-calendar-component-set VTODO.
- Löschen: DELETE auf die Collection.

---

## 3. UI-Verhalten (aus dem Desktop bewährt)

- Aufgabenliste zeigt nur Wurzel-Aufgaben. Schritte (Subtasks) erscheinen NUR
  in der Detailansicht der jeweiligen Aufgabe, nicht in der Hauptliste.
- Hauptliste zeigt bei Aufgaben mit Schritten einen Fortschritt "x von y".
- Optimistische Updates: Änderung sofort lokal anzeigen, im Hintergrund
  speichern, NICHT die ganze Liste neu laden. Nur bei Anlegen/Löschen neu laden.
- Auto-Save statt Speichern-Button: Titel bei Verlassen des Feldes, Priorität/
  Termin/Favorit sofort, Notiz erst beim Verlassen des Feldes (nicht pro Zeichen!
  sonst ETag-Konflikte).
- Erledigte Aufgaben durchgestrichen + ausgegraut, live beim Abhaken.
- "Mein Tag": tagesaktuelle Markierung, verfällt über Nacht automatisch.
- Sortieren: manuell (X-APPLE-SORT-ORDER), Fälligkeit, Priorität, Titel, Erstellt.
- Filtern: alle / offen / erledigt / Favoriten.
- Kontextmenü (auf Mobile: langes Tippen) mit Schnellaktionen.

---

## 4. Datenmodell (Vorschlag für ein Dart-Model)

Eine Aufgabe hält: uid, summary, status, parentUid, due, priority, description,
percent, sequence, sortOrder, favorite, myday, created, etag.
Schritte = Aufgaben mit parentUid != null.

---

## 5. Empfohlene Flutter-Bausteine (Stand der Recherche – Versionen prüfen!)

- HTTP: `http` oder `dio`.
- iCalendar parsen/erzeugen: **`enough_icalendar`** (ausgereifte VTodo-Klasse mit
  priority, categories, children, last-modified etc.) oder `icalendar_plus`.
  Das ist der solide, gepflegte Teil – nimm eines davon fürs iCal-Handling.
- CalDAV (PROPFIND/REPORT/PUT/DELETE): **`caldav`** auf pub.dev (aktuell ~1.5.0,
  gepflegt – erste Wahl). Deckt Verbindung, Kalender auflisten, Objekte laden
  (mit calendar-data + etag) und erstellen/löschen ab. Die genaue API auf der
  pub.dev-Seite unter "Installing" und "API reference" nachschlagen.
  Fallback, falls etwas Server-Spezifisches fehlt: REPORT/PROPFIND selbst über
  `http`/`dio` bauen (siehe unten) und mit `enough_icalendar` parsen.
  Der wichtigste Request (alle VTODOs auf einmal) ist ein `REPORT` mit
  `calendar-query` und `comp-filter` auf VTODO, der `calendar-data` + `getetag`
  zurückliefert – genau ein Request für die ganze Liste.
- WICHTIG (aus der CalDAV-Praxis): Das vom Server gelieferte iCalendar möglichst
  im Original behalten und beim Speichern (PUT) unbekannte/eigene Properties
  erhalten (z.B. X-APPLE-SORT-ORDER, CATEGORIES-Marker), nicht wegwerfen.
- Passwörter sicher speichern: `flutter_secure_storage` (deckt Android/iOS/Desktop;
  fürs Web gelten andere Regeln).
- State-Management: nach Wahl (provider, riverpod, bloc).
- Lokaler Cache/Offline: `sqflite` oder `hive` (Web: andere Backend-Variante nötig).

WICHTIG: Alle Paketnamen/Versionen mit dem aktuellen Stand auf pub.dev abgleichen,
bevor sie verwendet werden. Diese Liste ist ein Startpunkt, kein fixer Stand.

## 5a. Plattform-Besonderheiten (eine Codebasis, kleine Unterschiede)

- **Passwort-Speicherung** unterscheidet sich je Plattform (Keystore/Keychain auf
  Mobile, sichere Speicher auf Desktop, Browser-Storage im Web). `flutter_secure_storage`
  deckt vieles ab; Web ggf. gesondert behandeln.
- **PWA / Web + CORS:** Ein Browser darf aus Sicherheitsgründen oft KEINE direkten
  CalDAV-Requests an einen fremden Server schicken (CORS-Sperre). Mögliche Lösungen:
  CORS am Server erlauben (falls man den Server kontrolliert) ODER einen kleinen
  Proxy dazwischenschalten, der die Requests weiterreicht. Das nur für die
  Web-Variante einplanen – Android/Desktop sind davon nicht betroffen.

---

## 6. Reihenfolge der Umsetzung (Vorschlag)

1. Flutter-Projekt anlegen, Grundgerüst, ein Screen mit Dummy-Liste.
2. CalDAV-Verbindung + Login (Discovery, Basic Auth), Listen laden.
3. Aufgaben einer Liste laden (der eine REPORT mit calendar-data).
4. VTODO parsen ins Dart-Model (inkl. RELATED-TO=PARENT, CATEGORIES).
5. Anzeige: Wurzel-Aufgaben, Detailansicht mit Schritten, Fortschritt.
6. Erstellen / Abhaken / Bearbeiten (mit SEQUENCE, ETag/If-Match, 412-Retry).
7. Favoriten, "Mein Tag", Sortieren, Filtern.
8. Lokaler Cache für schnellen Start; später Offline-Bearbeitung.
