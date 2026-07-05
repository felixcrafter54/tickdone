# Tickdone – Design & Bedienung (Verhaltensspezifikation)

Diese Datei beschreibt das Aussehen UND – vor allem – die Bedien-Feinheiten der
App, damit sich die Flutter-Version genauso anfühlt wie die erprobte Desktop-Version.
Der Fokus liegt auf **Verhalten**, nicht nur auf Optik.

Grundprinzip: Es soll sich anfühlen wie Microsoft To Do, aber mit eigener,
etwas wärmerer Note (violetter Akzent statt MS-Blau).

---

## 1. Farbpalette (exakt aus der Desktop-Version)

Dunkles Theme. Diese Hex-Werte 1:1 übernehmen:

| Rolle | Hex | Verwendung |
|-------|-----|-----------|
| Hintergrund | `#1b1b21` | App-Hintergrund (mittlere Spalte) |
| Sidebar | `#17171c` | Listen-/Navigationsbereich |
| Detail-Fläche | `#1f1f25` | Detailbereich einer Aufgabe |
| Fläche | `#26262e` | Karten, Aufgabenzeilen |
| Fläche Hover | `#2f2f39` | Zeile unter Finger/Maus |
| Fläche gewählt | `#34343f` | ausgewählte Zeile |
| Rahmen/Linie | `#33333d` | Trennlinien, Zeilenrahmen |
| Text | `#ececf1` | Haupttext |
| Text gedimmt | `#9a9aa7` | Sekundärtext (Meta, Datum) |
| Text schwach | `#6b6b78` | Platzhalter, sehr Nebensächliches |
| **Akzent** | `#7c6cf0` | **Signature-Farbe** (Indigo-Violett), Buttons, Auswahl |
| Akzent hell | `#8f80ff` | Hover auf Akzent |
| Akzent gedimmt | `#5a4fb5` | Ränder ausgewählter Zeilen, Textauswahl |
| Erledigt | `#3ecf8e` | grüner Haken in Checkbox |
| Überfällig | `#f0676b` | rotes Fälligkeitsdatum, Löschen-Aktion |
| Favorit | `#f3c969` | goldener Stern |

Rundung: ca. **10 px** Eckenradius für Karten/Zeilen/Eingaben.
Auf dem Handy dürfen Flächen etwas größere Radien haben (Material-typisch), aber
die Palette bleibt gleich.

---

## 2. Struktur: die drei „Seiten"

Die Desktop-Version hat drei Bereiche nebeneinander:
1. **Listen** (Navigation: Konten + Aufgabenlisten)
2. **Aufgaben** (die Aufgaben der gewählten Liste)
3. **Detail** (die gewählte Aufgabe bearbeiten, inkl. Schritte)

### Auf dem Handy (kleiner Bildschirm): immer NUR EINE dieser Seiten zeigen
- Start: **Listen-Seite**. Tippt man eine Liste an → Navigation zur **Aufgaben-Seite**.
- Auf der Aufgaben-Seite eine Aufgabe antippen → Navigation zur **Detail-Seite**.
- Zurück-Geste/Pfeil führt jeweils eine Ebene zurück (Detail → Aufgaben → Listen).
- Also klassische **Push-Navigation** (Stack), nicht drei Spalten nebeneinander.

### Auf großem Bildschirm (Tablet quer / Desktop / breites Web)
- Zwei oder drei Spalten nebeneinander erlaubt (wie Desktop). Optional, später.
- Responsives Umschalten anhand der Breite (z.B. Breakpoint ~600/900 px).

---

## 3. Aufgabenliste (mittlere Seite) – Verhalten

- Zeigt **nur Wurzel-Aufgaben**. Schritte (Subtasks) erscheinen NICHT hier,
  sondern nur in der Detailansicht der jeweiligen Aufgabe.
- Jede Zeile: runde Checkbox (links), Titel, darunter ggf. Meta-Zeile, Stern (rechts).
- **Meta-Zeile** (klein, gedimmt) zeigt je nach Vorhandensein, mit „ · " getrennt:
  Fälligkeit, Priorität-Label, Fortschritt „x von y" (wenn Schritte existieren),
  Hinweis „Notiz" (wenn eine Notiz vorhanden ist).
- **Fälligkeit überfällig** (Datum in der Vergangenheit, Aufgabe offen) → Datum in
  Rot (`#f0676b`). Sonst gedimmt.
- **Erledigte Aufgabe**: Titel durchgestrichen + ausgegraut (Text schwach).
  Die runde Checkbox zeigt einen grünen gefüllten Kreis mit Haken.
- **Abhaken reagiert sofort** (optimistisch): Durchstreichen/Ausgrauen passiert
  ohne Verzögerung, das Speichern läuft im Hintergrund. KEIN Neuladen der Liste.
- Ganz oben eine Zeile **„Aufgabe hinzufügen"** (Eingabefeld). Enter/Bestätigen
  legt sofort eine neue Aufgabe an und zeigt sie sofort in der Liste (optimistisch).

### Kopfbereich der Aufgaben-Seite
- Titel = Name der Liste.
- Drei Icon-Aktionen: **Sortieren**, **Filtern**, **Aktualisieren**.
  - Sortieren-Icon öffnet ein Menü: **Manuell, Fälligkeit, Priorität, Titel, Erstellt**.
  - Filtern-Icon öffnet ein Menü: **Alle, Offen, Erledigt, Favoriten**.
  - Aktualisieren lädt die aktuelle Liste neu vom Server.
- „Manuell" = benutzerdefinierte Reihenfolge (per Drag&Drop, Feld X-APPLE-SORT-ORDER).

---

## 4. Detailseite einer Aufgabe – Verhalten

Aufbau von oben nach unten:
1. **Kopf**: runde Checkbox + Titel (editierbar) + Stern (Favorit).
2. **Schritte** (Subtasks): Liste, darunter eine Zeile „Schritt hinzufügen"
   (leerer Kreis + Eingabefeld, wie bei MS To Do).
3. **Termin** (Fälligkeit an/aus + Datum/Zeit).
4. **Priorität** (Keine / Hoch / Mittel / Niedrig).
5. **Notiz** (mehrzeiliges Textfeld).
6. **Fußzeile**: links „Erstellt <relative Zeit>", rechts Mülltonnen-Icon (löschen).

### Auto-Save (KEIN Speichern-Button!)
- **Titel**: speichert beim Verlassen des Feldes (nicht bei jedem Zeichen).
- **Priorität, Termin, Favorit-Stern**: speichern sofort bei Änderung.
- **Notiz**: speichert erst beim **Verlassen** des Feldes – NICHT pro Tastendruck.
  (Pro-Zeichen-Speichern verursacht ETag-Konflikte, siehe CalDAV-Spec.)
- Beim reinen Befüllen der Ansicht (Auswahl einer Aufgabe) darf NICHTS gespeichert
  werden – nur echte Nutzereingaben lösen Speichern aus.

### Schritte (Subtasks)
- Nur Aufgaben der ersten Ebene können Schritte haben. Ein Schritt kann KEINE
  weiteren Unterschritte haben (keine tiefere Verschachtelung).
- Schritt abhaken → sofort durchgestrichen (optimistisch), Fortschritt „x von y"
  der Elternaufgabe aktualisiert sich mit.
- Jeder Schritt hat ein **Drei-Punkte-Menü** (auf Handy: Icon oder langes Tippen) mit:
  - **Als erledigt / offen markieren**
  - **Zur Aufgabe höherstufen** (Schritt wird eigenständige Wurzel-Aufgabe;
    der Eltern-Bezug wird entfernt)
  - **Schritt löschen** (rot). Löschen fragt per Bestätigungsdialog nach
    („… wird endgültig gelöscht.", Buttons „Löschen" rot / „Abbrechen").
- Schritt löschen wird **live** entfernt (Panel aktualisiert sich sofort, kein
  erneutes Öffnen der Aufgabe nötig).

### Detailseite schließen
- Desktop: X oben rechts blendet den Detailbereich aus.
- Handy: Zurück-Geste/Pfeil führt zurück zur Aufgabenliste.
- Beim Start (ohne Auswahl) wird KEINE leere Detailseite gezeigt.

### Live-Durchstreichen (wichtige Feinheit)
- Hakt man eine Aufgabe im Detail ab, wird der Titel im Detail UND die Zeile in
  der Liste sofort durchgestrichen. Umgekehrt genauso. Kein Nachladen.

---

## 5. Kontextmenü der Aufgaben (Rechtsklick / langes Tippen)

Auf dem Handy per **langem Tippen** auf eine Aufgabenzeile. Einträge mit Icon davor,
in dieser Reihenfolge:

1. **Zu „Mein Tag" hinzufügen** / **Aus „Mein Tag" entfernen** (Sonnen-Icon) — Kürzel Strg+T
2. **Als wichtig markieren** / **Wichtig entfernen** (Stern-Icon)
3. **Als erledigt markieren** / **Als offen markieren** (Haken-Icon) — Kürzel Strg+D
4. — Trenner —
5. **Heute fällig** (Kalender-Icon)
6. **Morgen fällig** (Kalender-Icon)
7. **Termin entfernen** (Kalender-mit-X-Icon)
8. — Trenner —
9. **Aufgabe verschieben in …** (Pfeil-Icon) → Untermenü mit den anderen Listen
10. — Trenner —
11. **Aufgabe löschen** (rote Mülltonne) — Kürzel Entf

- „Verschieben in" zeigt nur die *anderen* Listen (nicht die aktuelle) und
  verschiebt die Aufgabe samt ihrer Schritte.
- Auf Desktop werden die Tastenkürzel rechts im Menü angezeigt.

---

## 6. „Mein Tag" (tagesaktuelle Markierung)

- Eine Aufgabe kann für „Mein Tag" markiert werden (Kontextmenü / Strg+T).
- **Verfällt automatisch über Nacht**: Die Markierung gilt nur, wenn ihr Datum
  „heute" ist. Am nächsten Tag ist die Markierung ungültig (technisch: Kategorie
  `FELIX-MYDAY-<YYYY-MM-DD>`, nur gültig wenn Datum == heute).
- Geplant (siehe Abschnitt 9): eine eigene **Smart-Liste „Mein Tag"** ganz oben,
  die alle heute markierten Aufgaben listenübergreifend sammelt.

---

## 7. Tastaturkürzel (Desktop/Web mit Tastatur)

| Kürzel | Aktion |
|--------|--------|
| Strg+D | Aufgabe erledigt / offen |
| Strg+T | Zu „Mein Tag" hinzufügen / entfernen |
| Entf | Aufgabe löschen |
| Strg+N | Fokus auf „Aufgabe hinzufügen" |
| F5 | Aktualisieren |
| Esc | Detailseite schließen |

Auf dem Handy entfallen Kürzel; dort zählen Tippen, langes Tippen und Wischgesten.
Optional (mobil-typisch): Wischen einer Aufgabenzeile für Schnellaktionen
(z.B. nach rechts = erledigt, nach links = löschen) – nur wenn es sauber umsetzbar
ist, sonst weglassen.

---

## 8. Relative Zeitangaben („Erstellt …")

Einheitliche Abstufung für Erstellt-/Änderungszeiten:
- < 1 Minute → „gerade eben"
- < 1 Stunde → „vor X Minuten"
- < 24 Stunden → „vor X Stunden"
- < 7 Tage → Wochentag ausgeschrieben („Montag", „Dienstag", …)
- gleiches Jahr → „25. Juni"
- älter → „25. Juni 2024"

Deutsche Monats- und Wochentagsnamen.

---

## 9. Einstellungen (Settings – GEPLANT)

Ein Einstellungsbereich ist vorgesehen (Icon/Eintrag in der Listen-/Navigationsseite).
Mögliche Inhalte, damit die Architektur das von Anfang an mitdenkt:
- Konten verwalten (hinzufügen/bearbeiten/entfernen, aktives Konto wählen)
- Standard-Sortierung und -Filter
- Theme (vorerst nur Dunkel; Hell evtl. später)
- Startverhalten (welche Liste beim Öffnen)
- Später: Offline-/Cache-Optionen, Benachrichtigungen

Für den Start genügt es, den Zugang zu „Konten verwalten" bereitzustellen; der Rest
kann als leeres Gerüst existieren. Wichtig ist nur, dass Navigation und State so
gebaut sind, dass ein Settings-Bereich sauber ergänzt werden kann.

---

## 10. Gefühlte Qualität – die Leitplanken

- **Alles reagiert sofort.** Optimistische Updates überall; der Server-Sync passiert
  im Hintergrund. Nie auf eine Server-Antwort warten, bevor die UI reagiert.
- **Keine leeren Zustände ohne Erklärung.** Leere Liste → freundlicher Hinweis
  („Keine Aufgaben hier. Füge oben eine hinzu.").
- **Nichts geht verloren.** Eingaben werden automatisch gesichert; unbekannte
  iCal-Felder beim Speichern erhalten.
- **Ruhiges, dunkles Bild** mit genau einem kräftigen Akzent (das Violett). Sparsam
  mit Farbe; Farbe nur für Bedeutung (grün=erledigt, rot=überfällig, gold=Favorit).
