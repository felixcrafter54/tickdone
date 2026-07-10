import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_theme.dart';
import 'kontext_menu.dart';

/// Aktionen zur Listenverwaltung (Umbenennen, Duplizieren, Löschen) –
/// von PC (Rechtsklick-Menü) und Handy (Drei-Punkte-Menü) genutzt.
abstract final class ListenAktionen {
  /// Liste umbenennen (Dialog mit vorbefülltem Namen).
  static Future<void> umbenennen(BuildContext context, Calendar liste) async {
    final name = await _nameDialog(
      context,
      titel: 'Liste umbenennen',
      vorgabe: liste.displayName,
      knopf: 'Umbenennen',
    );
    if (name == null || !context.mounted) return;
    await context.read<AppState>().benenneListeUm(liste, name);
  }

  /// Liste duplizieren (Dialog mit vorgeschlagenem Namen "… Kopie").
  static Future<void> duplizieren(BuildContext context, Calendar liste) async {
    final name = await _nameDialog(
      context,
      titel: 'Liste duplizieren',
      vorgabe: '${liste.displayName} Kopie',
      knopf: 'Duplizieren',
    );
    if (name == null || !context.mounted) return;
    await context.read<AppState>().dupliziereListe(liste, name);
  }

  /// Liste löschen (mit Bestätigung, außer die Einstellung ist aus).
  static Future<void> loeschen(BuildContext context, Calendar liste) async {
    final app = context.read<AppState>();
    if (!app.einstellungen.loeschenBestaetigen) {
      await app.loescheListe(liste);
      return;
    }
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Liste "${liste.displayName}" löschen?'),
        content: const Text(
            'Alle Aufgaben dieser Liste werden endgültig gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.farben.ueberfaellig),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (bestaetigt == true && context.mounted) {
      await context.read<AppState>().loescheListe(liste);
    }
  }

  /// Die Menüeinträge (Umbenennen, Duplizieren, Löschen) für die gemeinsame
  /// Kontextmenü-Komponente ([KontextMenuBereich] per Rechtsklick /
  /// [KontextMenuKnopf] per Drei-Punkte).
  static List<KontextEintrag> eintraege(
    BuildContext context,
    Calendar liste,
  ) {
    return [
      KontextAktion(
        icon: Icons.edit_outlined,
        text: 'Liste umbenennen',
        kuerzel: 'F2',
        onTap: () => umbenennen(context, liste),
      ),
      KontextAktion(
        icon: Icons.copy_outlined,
        text: 'Liste duplizieren',
        onTap: () => duplizieren(context, liste),
      ),
      KontextAktion(
        icon: Icons.delete_outline,
        text: 'Liste löschen',
        kuerzel: 'Entf',
        rot: true,
        onTap: () => loeschen(context, liste),
      ),
    ];
  }

  static Future<String?> _nameDialog(
    BuildContext context, {
    required String titel,
    required String vorgabe,
    required String knopf,
  }) async {
    final controller = TextEditingController(text: vorgabe);
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: vorgabe.length);
    final ergebnis = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titel),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (w) => Navigator.of(dialogContext).pop(w),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(knopf),
          ),
        ],
      ),
    );
    controller.dispose();
    final name = ergebnis?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }
}
