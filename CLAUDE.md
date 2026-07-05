# Tickdone Mobile – Projektkontext für Claude Code

## Was ist das
Neuentwicklung von Tickdone als plattformübergreifende App mit **Flutter/Dart**.
Ein CalDAV-Aufgabenclient (VTODO) im Stil von Microsoft To Do.
Ziel: EINE Codebasis für **Android**, **Web/PWA** und **Desktop**.

Es gibt bereits eine funktionierende Desktop-Version in Python (PySide6) als
Referenz. Deren gesamtes CalDAV- und UI-Wissen steht in **TICKDONE_MOBILE_SPEC.md**
– diese Datei ist die maßgebliche fachliche Grundlage. IMMER zuerst dort nachlesen.

## Sprache
- UI-Texte und Code-Kommentare auf **Deutsch**.
- Klarer, gut lesbarer Code; keine übertriebene Abstraktion.

## Wichtigste technische Punkte (Details in der Spec)
- CalDAV über das gepflegte Paket **`caldav`** (pub.dev, ~1.5.0). iCalendar mit
  **`enough_icalendar`**. Vor Verwendung Paket-APIs/Versionen auf pub.dev prüfen.
- Aufgaben in EINEM REPORT laden (calendar-query, comp-filter VTODO, mit
  calendar-data + etag). Nicht pro Objekt einzeln laden.
- Subtask-Hierarchie über `RELATED-TO;RELTYPE=PARENT` (kompatibel mit jtx Board).
- Beim Speichern: SEQUENCE +1, ETag als If-Match, bei 412 frisch holen + erneut.
- Vom Server geliefertes iCalendar möglichst erhalten; eigene/unbekannte
  Properties (X-APPLE-SORT-ORDER, CATEGORIES-Marker) beim PUT nicht verlieren.
- Favoriten und "Mein Tag" über CATEGORIES-Marker (Details in der Spec).

## Arbeitsweise
- In kleinen, getesteten Schritten vorgehen (siehe Reihenfolge in der Spec, Abschn. 6).
- Nach jedem sinnvollen Schritt: `flutter analyze` laufen lassen, App starten/prüfen,
  dann committen.
- Neue Pakete immer mit `dart pub add <name>` hinzufügen und kurz auf pub.dev
  gegen die aktuelle Version/API abgleichen.

## Git-Workflow
- NICHT direkt auf `main` committen. Für jede Aufgabe einen eigenen Branch anlegen
  (`git checkout -b feature/<name>`) und dort arbeiten.
- Kleine, klare Commits mit deutscher Nachricht.
- main bleibt lauffähig. Zusammenführen erst nach Review durch den Nutzer.

## Plattform-Hinweise
- Passwörter sicher speichern: `flutter_secure_storage` (Mobile/Desktop; Web ggf.
  gesondert).
- Web/PWA: CORS kann direkte CalDAV-Requests im Browser blockieren – erst für
  Android/Desktop bauen, Web-Besonderheit später gezielt lösen (Proxy oder
  CORS am Server). Nicht am Anfang damit aufhalten.
