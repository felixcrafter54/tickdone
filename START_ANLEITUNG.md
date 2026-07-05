# Tickdone Mobile – Startanleitung (Setup, Befehle & Prompts)

Diese Anleitung führt dich vom leeren Rechner bis zur ersten laufenden
Flutter-Version, an der Claude Code weiterbaut. Reihenfolge einhalten.

---

## TEIL A – Einmalige Installation (nur beim ersten Mal)

### A1. Flutter + Editor
1. **VS Code** installieren (falls nicht vorhanden).
2. In VS Code die **Flutter-Extension** installieren (zieht Dart automatisch mit).
3. Kommandopalette (Strg+Umschalt+P) → `Flutter: New Project` → wenn Flutter fehlt,
   bietet VS Code an, das SDK herunterzuladen. Annehmen. (Installiert Dart mit.)
4. **Android Studio** von https://developer.android.com/studio installieren –
   liefert Android-SDK + Emulator (für die Handy-App nötig).

### A2. Prüfen
Terminal neu öffnen und ausführen:
```
flutter doctor
```
Alle Punkte abarbeiten, bis möglichst alles grün ist (Android-Toolchain wichtig;
"Windows"/"Chrome" sind optionale Ziele). Bei Problemen: Meldungen von flutter
doctor befolgen.

### A3. Claude Code (nativer Windows-Installer, kein Node.js nötig)
In **PowerShell**:
```
irm https://claude.ai/install.ps1 | iex
```
Terminal schließen, neu öffnen, prüfen:
```
claude --version
```

---

## TEIL B – Projekt anlegen

### B1. Neues Flutter-Projekt (in einem NEUEN, leeren Ordner – NICHT im Python-Ordner)
```
cd D:\Flutter            (oder wo du deine Projekte ablegst)
flutter create tickdone_mobile
cd tickdone_mobile
```

### B2. Die zwei Kontextdateien hineinlegen
Kopiere diese beiden Dateien in den Ordner `tickdone_mobile` (oberste Ebene,
neben `pubspec.yaml`):
- `CLAUDE.md`
- `TICKDONE_MOBILE_SPEC.md`

### B3. Testlauf, dass Flutter grundsätzlich läuft
Handy per USB anschließen (USB-Debugging an) ODER Emulator in Android Studio starten,
dann:
```
flutter run
```
Wenn die Demo-Zähler-App startet, ist alles bereit. Mit `q` im Terminal beenden.

### B4. Git initialisieren
```
git init
git add .
git commit -m "Flutter-Grundgeruest + Projektkontext (CLAUDE.md, Spec)"
```

### B5. GitHub-Repo anlegen
- Auf github.com: New repository → Name `tickdone-mobile` → Public/Private →
  KEINE Häkchen bei README/gitignore/License (hast du schon).
- Dann verbinden (DEINUSERNAME ersetzen):
```
git branch -M main
git remote add origin https://github.com/DEINUSERNAME/tickdone-mobile.git
git push -u origin main
```

---

## TEIL C – Mit Claude Code arbeiten

### C1. Feature-Branch anlegen und Claude Code starten
```
git checkout -b feature/verbindung-und-listen
claude
```

### C2. Erster Prompt (Verbindung + Listen laden)
Kopiere diesen Text in Claude Code:

> Lies zuerst CLAUDE.md und TICKDONE_MOBILE_SPEC.md vollständig. Wir bauen die App
> Schritt für Schritt gemäß der Reihenfolge in Abschnitt 6 der Spec. Sprache für
> UI und Kommentare: Deutsch.
>
> Setze jetzt Schritt 1 und 2 um:
> 1) Räume das Demo-Grundgerüst auf und lege eine saubere Projektstruktur an
>    (z.B. lib/models, lib/services, lib/ui). Wähle ein einfaches State-Management
>    und begründe kurz die Wahl.
> 2) Baue einen Login-/Verbindungs-Screen: Server-URL, Benutzer, Passwort. Nutze
>    das Paket `caldav` (auf pub.dev die aktuelle Version und API prüfen, per
>    `dart pub add caldav` hinzufügen) für die Verbindung inkl. Discovery, und
>    lade nach erfolgreichem Login die Aufgabenlisten (Collections mit VTODO).
>    Zeige die Listen in einer einfachen Übersicht an.
>
> Speichere das Passwort noch NICHT dauerhaft (kommt später mit
> flutter_secure_storage). Arbeite auf dem aktuellen Branch. Führe am Ende
> `flutter analyze` aus und committe mit aussagekräftiger deutscher Nachricht.
> Erkläre mir kurz, was du gebaut hast und wie ich es teste.

### C3. Testen und weiter
- Claude Codes Änderungen ansehen (es zeigt Diffs). Bei den kritischen CalDAV-
  Stellen genauer hinschauen.
- Selbst testen: `flutter run`, einloggen, ob die Listen erscheinen.
- Passt es? Dann weiter mit dem nächsten Prompt (Schritt 3/4 der Spec: Aufgaben
  einer Liste laden und ins Model parsen). Wenn ein Schritt rund ist, Branch
  pushen und per Pull Request auf GitHub nach main mergen:
```
git push -u origin feature/verbindung-und-listen
```

### Weitere Prompts (nacheinander, je ein Feature-Branch)
- "Setze Schritt 3 und 4 um: Aufgaben einer Liste in EINEM REPORT laden
  (calendar-query, comp-filter VTODO, mit calendar-data + etag) und ins Dart-Model
  parsen – inkl. RELATED-TO;RELTYPE=PARENT und der CATEGORIES-Marker. Zeige die
  Wurzel-Aufgaben in einer Liste."
- "Setze Schritt 5 um: Detailansicht einer Aufgabe mit ihren Schritten (Subtasks),
  Fortschritt 'x von y' in der Hauptliste."
- "Setze Schritt 6 um: Erstellen, Abhaken und Bearbeiten – mit SEQUENCE-Erhöhung,
  ETag/If-Match und 412-Retry, optimistischen Updates (lokal sofort, kein
  Neuladen der ganzen Liste)."
- "Setze Schritt 7 um: Favoriten, 'Mein Tag' (verfällt über Nacht), Sortieren,
  Filtern."
- "Setze Schritt 8 um: lokaler Cache für schnellen Start; Passwörter mit
  flutter_secure_storage sicher speichern."

---

## Tipps

- Immer nur EIN Feature pro Runde, testen, committen. Das hält alles überschaubar.
- Wenn Claude Code ein Paket nutzen will: kurz auf pub.dev gegenchecken, ob es
  gepflegt ist und zur aktuellen Flutter-Version passt.
- Dein Python-Tickdone bleibt als Referenz bestehen – bei Unsicherheit, wie sich
  etwas verhalten soll, dort nachsehen (oder die Spec fragen).
- Bei Fehlern in Claude Code: die genaue Fehlermeldung hereingeben, nicht nur
  "geht nicht".
