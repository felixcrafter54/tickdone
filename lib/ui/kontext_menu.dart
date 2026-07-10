import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'aufgaben_screen.dart' show istDesktop;

/// Gemeinsame Kontextmenü-Komponente für Aufgaben, Schritte und Listen –
/// EINE Optik, EINE Auslösung: Rechtsklick am Klickpunkt (Desktop) über
/// [KontextMenuBereich] bzw. ein Drei-Punkte-Button (Touch) über
/// [KontextMenuKnopf]. So sehen und verhalten sich alle Menüs gleich.
///
/// Ein Menü ist eine Liste von [KontextEintrag]: [KontextAktion] (Icon, Text,
/// optionales Kürzel, optional rot), [KontextUntermenu] (aufklappbar) oder
/// [KontextTrenner].
sealed class KontextEintrag {
  const KontextEintrag();
}

/// Eine anklickbare Aktion.
class KontextAktion extends KontextEintrag {
  const KontextAktion({
    required this.icon,
    required this.text,
    required this.onTap,
    this.kuerzel,
    this.rot = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  /// Tastenkürzel – wird nur auf dem Desktop rechts angezeigt.
  final String? kuerzel;

  /// Destruktive Aktion (rot dargestellt, z.B. Löschen).
  final bool rot;
}

/// Ein aufklappbares Untermenü (z.B. "Verschieben in …").
class KontextUntermenu extends KontextEintrag {
  const KontextUntermenu({
    required this.icon,
    required this.text,
    required this.kinder,
  });

  final IconData icon;
  final String text;
  final List<KontextAktion> kinder;
}

/// Ein Trennstrich zwischen Gruppen.
class KontextTrenner extends KontextEintrag {
  const KontextTrenner();
}

/// Baut aus den Einträgen die Menü-Kinder (MenuItemButton/SubmenuButton/Divider).
List<Widget> kontextMenuKinder(
    BuildContext context, List<KontextEintrag> eintraege) {
  return [
    for (final e in eintraege)
      switch (e) {
        KontextTrenner() => const Divider(height: 1),
        KontextAktion() => _aktionButton(context, e),
        KontextUntermenu() => SubmenuButton(
            leadingIcon: Icon(e.icon, size: 18, color: context.farben.text),
            menuChildren: [
              for (final k in e.kinder) _aktionButton(context, k),
            ],
            child: Text(e.text, style: TextStyle(color: context.farben.text)),
          ),
      },
  ];
}

Widget _aktionButton(BuildContext context, KontextAktion a) {
  final farbe = a.rot ? context.farben.ueberfaellig : context.farben.text;
  return MenuItemButton(
    leadingIcon: Icon(a.icon, size: 18, color: farbe),
    trailingIcon: (a.kuerzel != null && istDesktop)
        ? Text(a.kuerzel!,
            style: TextStyle(color: context.farben.textGedimmt, fontSize: 12))
        : null,
    onPressed: a.onTap,
    child: Text(a.text, style: TextStyle(color: farbe)),
  );
}

/// Umschließt eine Zeile: Rechtsklick öffnet das Menü am Klickpunkt (Desktop).
class KontextMenuBereich extends StatelessWidget {
  const KontextMenuBereich({
    super.key,
    required this.eintraege,
    required this.child,
  });

  final List<KontextEintrag> eintraege;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: kontextMenuKinder(context, eintraege),
      builder: (context, controller, child) => GestureDetector(
        onSecondaryTapDown: (details) {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open(position: details.localPosition);
          }
        },
        child: child,
      ),
      child: child,
    );
  }
}

/// Drei-Punkte-Button, der dasselbe Menü öffnet (für Touch-Geräte ohne
/// Rechtsklick).
class KontextMenuKnopf extends StatelessWidget {
  const KontextMenuKnopf({
    super.key,
    required this.eintraege,
    this.icon = Icons.more_vert,
    this.iconGroesse,
    this.farbe,
    this.tooltip,
  });

  final List<KontextEintrag> eintraege;
  final IconData icon;
  final double? iconGroesse;
  final Color? farbe;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: kontextMenuKinder(context, eintraege),
      builder: (context, controller, child) => IconButton(
        icon: Icon(icon, size: iconGroesse, color: farbe),
        tooltip: tooltip,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
