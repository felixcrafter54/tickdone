import 'package:flutter/material.dart';

/// Farbpalette 1:1 aus der Desktop-Version (TICKDONE_DESIGN.md, Abschnitt 1).
abstract final class TickdoneFarben {
  static const hintergrund = Color(0xFF1B1B21);
  static const sidebar = Color(0xFF17171C);
  static const detailFlaeche = Color(0xFF1F1F25);
  static const flaeche = Color(0xFF26262E);
  static const flaecheHover = Color(0xFF2F2F39);
  static const flaecheGewaehlt = Color(0xFF34343F);
  static const rahmen = Color(0xFF33333D);
  static const text = Color(0xFFECECF1);
  static const textGedimmt = Color(0xFF9A9AA7);
  static const textSchwach = Color(0xFF6B6B78);
  static const akzent = Color(0xFF7C6CF0);
  static const akzentHell = Color(0xFF8F80FF);
  static const akzentGedimmt = Color(0xFF5A4FB5);
  static const erledigt = Color(0xFF3ECF8E);
  static const ueberfaellig = Color(0xFFF0676B);
  static const favorit = Color(0xFFF3C969);
}

/// Eckenradius für Karten/Zeilen/Eingaben (Design-Doc, Abschnitt 1).
const tickdoneRadius = 10.0;

/// Dunkles Theme: ruhiges Bild, genau EIN kräftiger Akzent (Indigo-Violett);
/// Farbe nur für Bedeutung (grün = erledigt, rot = überfällig, gold = wichtig).
ThemeData tickdoneTheme() {
  const abrundung = BorderRadius.all(Radius.circular(tickdoneRadius));

  const schema = ColorScheme.dark(
    primary: TickdoneFarben.akzent,
    onPrimary: Colors.white,
    secondary: TickdoneFarben.akzentHell,
    onSecondary: Colors.white,
    primaryContainer: TickdoneFarben.akzentGedimmt,
    onPrimaryContainer: TickdoneFarben.text,
    surface: TickdoneFarben.hintergrund,
    onSurface: TickdoneFarben.text,
    surfaceContainerHighest: TickdoneFarben.flaeche,
    onSurfaceVariant: TickdoneFarben.textGedimmt,
    outline: TickdoneFarben.textGedimmt,
    outlineVariant: TickdoneFarben.rahmen,
    error: TickdoneFarben.ueberfaellig,
    onError: Colors.white,
  );

  final basis = ThemeData(colorScheme: schema, useMaterial3: true);

  return basis.copyWith(
    scaffoldBackgroundColor: TickdoneFarben.hintergrund,
    appBarTheme: const AppBarTheme(
      backgroundColor: TickdoneFarben.hintergrund,
      foregroundColor: TickdoneFarben.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: TickdoneFarben.text,
      iconColor: TickdoneFarben.textGedimmt,
      shape: RoundedRectangleBorder(borderRadius: abrundung),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TickdoneFarben.flaeche,
      hintStyle: const TextStyle(color: TickdoneFarben.textSchwach),
      labelStyle: const TextStyle(color: TickdoneFarben.textGedimmt),
      border: const OutlineInputBorder(
        borderRadius: abrundung,
        borderSide: BorderSide(color: TickdoneFarben.rahmen),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: abrundung,
        borderSide: BorderSide(color: TickdoneFarben.rahmen),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: abrundung,
        borderSide: BorderSide(color: TickdoneFarben.akzent),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: TickdoneFarben.detailFlaeche,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(tickdoneRadius)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TickdoneFarben.detailFlaeche,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tickdoneRadius),
        ),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: TickdoneFarben.flaecheHover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(tickdoneRadius)),
      ),
    ),
    // Material-Menü (MenuAnchor) fürs Kontextmenü: dunkle Fläche mit Rahmen.
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor:
            const WidgetStatePropertyAll(TickdoneFarben.flaecheHover),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tickdoneRadius),
            side: const BorderSide(color: TickdoneFarben.rahmen),
          ),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TickdoneFarben.akzent,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: TickdoneFarben.flaecheHover,
      contentTextStyle: TextStyle(color: TickdoneFarben.text),
    ),
    chipTheme: basis.chipTheme.copyWith(
      backgroundColor: TickdoneFarben.flaeche,
      selectedColor: TickdoneFarben.akzentGedimmt,
      side: const BorderSide(color: TickdoneFarben.rahmen),
      labelStyle: const TextStyle(color: TickdoneFarben.text),
    ),
    dividerTheme: const DividerThemeData(color: TickdoneFarben.rahmen),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TickdoneFarben.akzent,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: TickdoneFarben.akzent,
      selectionColor: TickdoneFarben.akzentGedimmt,
      selectionHandleColor: TickdoneFarben.akzent,
    ),
  );
}
