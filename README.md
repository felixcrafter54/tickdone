# Tickdone

Ein plattformübergreifender **CalDAV-Aufgabenclient** (VTODO) im Stil von
Microsoft To Do – aus **einer** Flutter/Dart-Codebasis für **Android**,
**Web/PWA** und **Desktop** (Windows/Linux/macOS).

Tickdone spricht direkt mit einem CalDAV-Server (z. B. Radicale, Nextcloud/
OpenCloud) und speichert Aufgaben verlustfrei als standardkonforme VTODOs –
kompatibel u. a. mit jtx Board und anderen CalDAV-Clients.

## Funktionen

- **Listen & Aufgaben** mit Titel, Notiz, Fälligkeit, „Wichtig" (Stern) und
  Fortschritt.
- **Schritte (Subtasks)** über `RELATED-TO;RELTYPE=PARENT`.
- **Smart-Listen** listenübergreifend: **Mein Tag**, **Wichtig**, **Geplant**.
- **Manuelle Reihenfolge** per **Drag & Drop** (Aufgaben *und* Schritte,
  `X-APPLE-SORT-ORDER`).
- **Listenverwaltung**: umbenennen, duplizieren, löschen; Aufgaben zwischen
  Listen verschieben.
- **Offline-fähig**: sofortiger Start aus lokalem Cache; Änderungen werden
  offline gesammelt und bei Verbindung automatisch synchronisiert (mit
  ETag-/Konfliktbehandlung) – ohne Datenverlust.
- **Responsive**: schmales Handy-Layout (Push-Navigation) und breites
  Drei-Spalten-Layout (Listen | Aufgaben | Detail) für Tablet quer/Desktop.
- **Desktop-Komfort**: Rechtsklick-Kontextmenüs und Tastenkürzel (F2, Entf …),
  auch im Desktop-Browser.
- **Helles & dunkles Theme** (Standard: System).

## Technik

- **Flutter/Dart**, State via `provider` (ein zentraler `AppState`).
- CalDAV über das Paket [`caldav`](https://pub.dev/packages/caldav),
  iCalendar über [`enough_icalendar`](https://pub.dev/packages/enough_icalendar).
- Sichere Zugangsdaten: `flutter_secure_storage`; lokaler Cache/Queue:
  `shared_preferences`; Online-Erkennung: `connectivity_plus`.
- Aufgaben werden in **einem** REPORT geladen (calendar-query, VTODO,
  calendar-data + ETag). Beim Speichern bleibt fremdes/unbekanntes iCalendar
  erhalten (verlustfreies Patchen).

## Bauen & Starten

Voraussetzung: **Flutter 3.44.4** (siehe `pubspec.yaml`).

```bash
flutter pub get

flutter run                 # Debug auf angeschlossenem Gerät/Desktop
flutter build apk --release # Android
flutter build windows --release
flutter build web --release
```

Beim Start mit dem CalDAV-Server verbinden (Benutzer/Passwort; auf
Android/Desktop zusätzlich die Server-URL).

## Web/PWA

Im Browser blockiert CORS direkte CalDAV-Requests. Tickdone löst das über einen
**Same-Origin-Reverse-Proxy** (die Web-App spricht `/caldav/` auf der eigenen
Domain an). Ein fertiges Docker-Setup (nginx + Proxy) sowie ein GitHub-Actions-
Workflow, der das Image nach GHCR pusht, liegen unter
[`deploy/web/`](deploy/web/README.md).

## App-Icon

Quelle: `assets/icon/tickdone.svg`. Für die Icon-Generierung wird ein
1024×1024-PNG unter `assets/icon/tickdone.png` benötigt; danach:

```bash
flutter pub run flutter_launcher_icons
```

Details: [`assets/icon/README.md`](assets/icon/README.md).

## Lizenz

Tickdone steht unter der **GNU General Public License v3.0** – siehe
[`LICENSE`](LICENSE).
