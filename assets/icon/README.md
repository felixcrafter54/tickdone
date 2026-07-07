# App-Icon

- **Quelle (editierbar):** `tickdone.svg` – hier ablegen, bleibt im Repo.
- **Für die Generierung:** `tickdone.png`, **quadratisch, ideal 1024×1024** px.
  `flutter_launcher_icons` braucht ein Raster-PNG (kein SVG), daher aus dem
  SVG-Programm (Inkscape/Illustrator/Figma …) ein 1024er-PNG exportieren und
  hier als `tickdone.png` ablegen.
- Motiv am besten mit etwas Rand (Sicherheitszone), damit auf Android nichts
  abgeschnitten wird.

Danach die Icons für Android/Web/Windows generieren lassen:

```bash
flutter pub run flutter_launcher_icons
```

Die Konfiguration steht in `pubspec.yaml` unter `flutter_launcher_icons`.
