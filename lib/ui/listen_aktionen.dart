import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_theme.dart';

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

  /// Liste löschen (mit Bestätigung).
  static Future<void> loeschen(BuildContext context, Calendar liste) async {
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
                backgroundColor: TickdoneFarben.ueberfaellig),
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

  /// Die Menüeinträge (Umbenennen, Duplizieren, Löschen) als PopupMenuItems –
  /// für den Drei-Punkte-Button (Handy).
  static List<PopupMenuEntry<void Function()>> menueEintraege(
    BuildContext context,
    Calendar liste,
  ) {
    return [
      PopupMenuItem(
        value: () => umbenennen(context, liste),
        child: const _Zeile(Icons.edit_outlined, 'Liste umbenennen'),
      ),
      PopupMenuItem(
        value: () => duplizieren(context, liste),
        child: const _Zeile(Icons.copy_outlined, 'Liste duplizieren'),
      ),
      PopupMenuItem(
        value: () => loeschen(context, liste),
        child: const _Zeile(Icons.delete_outline, 'Liste löschen',
            rot: true),
      ),
    ];
  }

  /// Verankertes Menü am Klickpunkt (PC-Rechtsklick).
  static Future<void> menue(
    BuildContext context,
    Calendar liste,
    Offset position,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final aktion = await showMenu<void Function()>(
      context: context,
      color: TickdoneFarben.flaecheHover,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: menueEintraege(context, liste),
    );
    aktion?.call();
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

class _Zeile extends StatelessWidget {
  const _Zeile(this.icon, this.text, {this.rot = false});

  final IconData icon;
  final String text;
  final bool rot;

  @override
  Widget build(BuildContext context) {
    final farbe = rot ? TickdoneFarben.ueberfaellig : TickdoneFarben.text;
    return Row(
      children: [
        Icon(icon, size: 18, color: farbe),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: farbe)),
      ],
    );
  }
}
