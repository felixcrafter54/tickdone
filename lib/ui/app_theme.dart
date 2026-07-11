import 'package:flutter/material.dart';

/// Semantische Farbpalette als ThemeExtension – hell UND dunkel.
/// Zugriff in Widgets über `context.farben`.
@immutable
class TickdoneFarben extends ThemeExtension<TickdoneFarben> {
  final Color hintergrund;
  final Color sidebar;
  final Color detailFlaeche;
  final Color flaeche;
  final Color flaecheHover;
  final Color flaecheGewaehlt;
  final Color rahmen;
  final Color text;
  final Color textGedimmt;
  final Color textSchwach;
  final Color akzent;
  final Color akzentHell;
  final Color akzentGedimmt;
  final Color erledigt;
  final Color ueberfaellig;
  final Color favorit;

  const TickdoneFarben({
    required this.hintergrund,
    required this.sidebar,
    required this.detailFlaeche,
    required this.flaeche,
    required this.flaecheHover,
    required this.flaecheGewaehlt,
    required this.rahmen,
    required this.text,
    required this.textGedimmt,
    required this.textSchwach,
    required this.akzent,
    required this.akzentHell,
    required this.akzentGedimmt,
    required this.erledigt,
    required this.ueberfaellig,
    required this.favorit,
  });

  /// Dunkle Palette (1:1 aus der Desktop-Version, TICKDONE_DESIGN.md).
  static const dunkel = TickdoneFarben(
    hintergrund: Color(0xFF1B1B21),
    sidebar: Color(0xFF17171C),
    detailFlaeche: Color(0xFF1F1F25),
    flaeche: Color(0xFF26262E),
    flaecheHover: Color(0xFF2F2F39),
    flaecheGewaehlt: Color(0xFF34343F),
    rahmen: Color(0xFF33333D),
    text: Color(0xFFECECF1),
    textGedimmt: Color(0xFF9A9AA7),
    textSchwach: Color(0xFF6B6B78),
    akzent: Color(0xFF7C6CF0),
    akzentHell: Color(0xFF8F80FF),
    akzentGedimmt: Color(0xFF5A4FB5),
    erledigt: Color(0xFF3ECF8E),
    ueberfaellig: Color(0xFFF0676B),
    favorit: Color(0xFFF3C969),
  );

  /// Helle Palette – gleicher violetter Akzent, heller Untergrund.
  static const hell = TickdoneFarben(
    hintergrund: Color(0xFFF7F7FA),
    sidebar: Color(0xFFEFEFF3),
    detailFlaeche: Color(0xFFFFFFFF),
    flaeche: Color(0xFFFFFFFF),
    flaecheHover: Color(0xFFF0F0F5),
    flaecheGewaehlt: Color(0xFFE7E3FB),
    rahmen: Color(0xFFDCDCE3),
    text: Color(0xFF1B1B21),
    textGedimmt: Color(0xFF6B6B78),
    textSchwach: Color(0xFF9A9AA7),
    akzent: Color(0xFF6A5AE0),
    akzentHell: Color(0xFF8F80FF),
    akzentGedimmt: Color(0xFFBBB2F4),
    erledigt: Color(0xFF2FA875),
    ueberfaellig: Color(0xFFD64550),
    favorit: Color(0xFFD9A400),
  );

  @override
  TickdoneFarben copyWith({
    Color? hintergrund,
    Color? sidebar,
    Color? detailFlaeche,
    Color? flaeche,
    Color? flaecheHover,
    Color? flaecheGewaehlt,
    Color? rahmen,
    Color? text,
    Color? textGedimmt,
    Color? textSchwach,
    Color? akzent,
    Color? akzentHell,
    Color? akzentGedimmt,
    Color? erledigt,
    Color? ueberfaellig,
    Color? favorit,
  }) {
    return TickdoneFarben(
      hintergrund: hintergrund ?? this.hintergrund,
      sidebar: sidebar ?? this.sidebar,
      detailFlaeche: detailFlaeche ?? this.detailFlaeche,
      flaeche: flaeche ?? this.flaeche,
      flaecheHover: flaecheHover ?? this.flaecheHover,
      flaecheGewaehlt: flaecheGewaehlt ?? this.flaecheGewaehlt,
      rahmen: rahmen ?? this.rahmen,
      text: text ?? this.text,
      textGedimmt: textGedimmt ?? this.textGedimmt,
      textSchwach: textSchwach ?? this.textSchwach,
      akzent: akzent ?? this.akzent,
      akzentHell: akzentHell ?? this.akzentHell,
      akzentGedimmt: akzentGedimmt ?? this.akzentGedimmt,
      erledigt: erledigt ?? this.erledigt,
      ueberfaellig: ueberfaellig ?? this.ueberfaellig,
      favorit: favorit ?? this.favorit,
    );
  }

  @override
  TickdoneFarben lerp(ThemeExtension<TickdoneFarben>? other, double t) {
    if (other is! TickdoneFarben) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return TickdoneFarben(
      hintergrund: m(hintergrund, other.hintergrund),
      sidebar: m(sidebar, other.sidebar),
      detailFlaeche: m(detailFlaeche, other.detailFlaeche),
      flaeche: m(flaeche, other.flaeche),
      flaecheHover: m(flaecheHover, other.flaecheHover),
      flaecheGewaehlt: m(flaecheGewaehlt, other.flaecheGewaehlt),
      rahmen: m(rahmen, other.rahmen),
      text: m(text, other.text),
      textGedimmt: m(textGedimmt, other.textGedimmt),
      textSchwach: m(textSchwach, other.textSchwach),
      akzent: m(akzent, other.akzent),
      akzentHell: m(akzentHell, other.akzentHell),
      akzentGedimmt: m(akzentGedimmt, other.akzentGedimmt),
      erledigt: m(erledigt, other.erledigt),
      ueberfaellig: m(ueberfaellig, other.ueberfaellig),
      favorit: m(favorit, other.favorit),
    );
  }
}

/// Kurzzugriff auf die aktive Palette.
extension TickdoneFarbenContext on BuildContext {
  TickdoneFarben get farben =>
      Theme.of(this).extension<TickdoneFarben>() ?? TickdoneFarben.dunkel;
}

/// Eckenradius für Karten/Zeilen/Eingaben (Design-Doc, Abschnitt 1).
const tickdoneRadius = 10.0;

/// Gemeinsamer Drag-Proxy fürs Umsortieren (Aufgaben & Schritte). Der Material-
/// Standard-proxyDecorator zeigt beim Ziehen einen großen grauen Kasten
/// (elevierte M3-Fläche, rechteckig) – besonders auffällig im Web. Stattdessen
/// zeigen wir die gezogene Zeile EXAKT wie im Ruhezustand: gleiche Breite,
/// gleiche Karte, keine Skalierung (Skalierung machte die Zeile breiter als die
/// übrigen und sah damit „daneben" aus).
Widget tickdoneZiehProxy(
    Widget child, int index, Animation<double> animation) {
  return Material(type: MaterialType.transparency, child: child);
}

/// Scroll-Verhalten ohne das Material-„Stretch" am Rand – so bleiben die
/// abgerundeten Karten formstabil an Ort und Stelle. Stattdessen ein
/// dezenter Schimmer (Glow) in der Akzentfarbe.
class TickdoneScrollBehavior extends MaterialScrollBehavior {
  const TickdoneScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
      child: child,
    );
  }
}

/// Dunkles Theme (Standard).
ThemeData tickdoneTheme() => _theme(TickdoneFarben.dunkel, Brightness.dark);

/// Helles Theme.
ThemeData tickdoneThemeHell() => _theme(TickdoneFarben.hell, Brightness.light);

ThemeData _theme(TickdoneFarben f, Brightness helligkeit) {
  const abrundung = BorderRadius.all(Radius.circular(tickdoneRadius));

  final schema = ColorScheme(
    brightness: helligkeit,
    primary: f.akzent,
    onPrimary: Colors.white,
    secondary: f.akzentHell,
    onSecondary: Colors.white,
    primaryContainer: f.akzentGedimmt,
    onPrimaryContainer: f.text,
    surface: f.hintergrund,
    onSurface: f.text,
    surfaceContainerHighest: f.flaeche,
    onSurfaceVariant: f.textGedimmt,
    outline: f.textGedimmt,
    outlineVariant: f.rahmen,
    error: f.ueberfaellig,
    onError: Colors.white,
  );

  final basis = ThemeData(colorScheme: schema, useMaterial3: true);

  return basis.copyWith(
    extensions: [f],
    scaffoldBackgroundColor: f.hintergrund,
    appBarTheme: AppBarTheme(
      backgroundColor: f.hintergrund,
      foregroundColor: f.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      textColor: f.text,
      iconColor: f.textGedimmt,
      shape: const RoundedRectangleBorder(borderRadius: abrundung),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: f.flaeche,
      hintStyle: TextStyle(color: f.textSchwach),
      labelStyle: TextStyle(color: f.textGedimmt),
      border: OutlineInputBorder(
        borderRadius: abrundung,
        borderSide: BorderSide(color: f.rahmen),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: abrundung,
        borderSide: BorderSide(color: f.rahmen),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: abrundung,
        borderSide: BorderSide(color: f.akzent),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: f.detailFlaeche,
      shape: const RoundedRectangleBorder(borderRadius: abrundung),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: f.detailFlaeche,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tickdoneRadius)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: f.flaecheHover,
      shape: const RoundedRectangleBorder(borderRadius: abrundung),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(f.flaecheHover),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tickdoneRadius),
            side: BorderSide(color: f.rahmen),
          ),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: f.akzent,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: f.flaecheHover,
      contentTextStyle: TextStyle(color: f.text),
    ),
    chipTheme: basis.chipTheme.copyWith(
      backgroundColor: f.flaeche,
      selectedColor: f.akzentGedimmt,
      side: BorderSide(color: f.rahmen),
      labelStyle: TextStyle(color: f.text),
    ),
    dividerTheme: DividerThemeData(color: f.rahmen),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: f.akzent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: f.akzent,
      selectionColor: f.akzentGedimmt,
      selectionHandleColor: f.akzent,
    ),
  );
}
