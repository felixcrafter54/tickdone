import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';
import 'aufgabe_detail_screen.dart';

/// Zeigt die Wurzel-Aufgaben der geöffneten Liste.
///
/// Schritte (Subtasks) erscheinen hier bewusst NICHT – die stehen in der
/// Detailansicht. Abhaken: aufs Status-Icon tippen (optimistisch, ohne
/// Neuladen). Neue Aufgabe: Plus-Button.
class AufgabenScreen extends StatelessWidget {
  const AufgabenScreen({super.key});

  /// Dialog für eine neue Aufgabe (bzw. einen Schritt, siehe Detailansicht).
  static Future<void> neueAufgabeDialog(
    BuildContext context, {
    String? parentUid,
  }) async {
    final controller = TextEditingController();
    final titel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentUid == null ? 'Neue Aufgabe' : 'Neuer Schritt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Titel'),
          onSubmitted: (wert) => Navigator.of(dialogContext).pop(wert),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (titel == null || titel.trim().isEmpty || !context.mounted) return;
    await context
        .read<AppState>()
        .erstelleAufgabe(titel, parentUid: parentUid);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final aufgaben = appState.wurzelAufgaben;
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.aktiveListe?.displayName ?? 'Aufgaben'),
      ),
      body: Column(
        children: [
          if (appState.aufgabenLaden) const LinearProgressIndicator(),
          if (appState.aufgabenFehler != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                appState.aufgabenFehler!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AppState>().aufgabenNeuLaden(),
              child: aufgaben.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            appState.aufgabenLaden
                                ? 'Lade Aufgaben …'
                                : 'Keine Aufgaben in dieser Liste.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: aufgaben.length,
                      itemBuilder: (context, index) {
                        final aufgabe = aufgaben[index];
                        return _AufgabenZeile(
                          aufgabe: aufgabe,
                          fortschritt:
                              appState.fortschrittVon(aufgabe.uid),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Aufgabe',
        onPressed: () => neueAufgabeDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Eine Zeile der Aufgabenliste: Status-Icon, Titel, Fortschritt der
/// Schritte ("x von y"), Fälligkeit, Favorit.
class _AufgabenZeile extends StatelessWidget {
  const _AufgabenZeile({required this.aufgabe, this.fortschritt});

  final Aufgabe aufgabe;
  final ({int erledigt, int gesamt})? fortschritt;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return ListTile(
      // Tippen aufs Icon hakt ab bzw. öffnet wieder – optimistisch,
      // gespeichert wird im Hintergrund.
      leading: IconButton(
        icon: Icon(
          aufgabe.erledigt
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: aufgabe.erledigt ? farben.primary : farben.outline,
        ),
        tooltip: aufgabe.erledigt ? 'Wieder öffnen' : 'Erledigt',
        onPressed: () => context
            .read<AppState>()
            .setzeErledigt(aufgabe.uid, !aufgabe.erledigt),
      ),
      title: Text(
        aufgabe.titel,
        style: aufgabe.erledigt
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: farben.outline,
              )
            : null,
      ),
      subtitle: _untertitel(),
      trailing: aufgabe.favorit
          ? Icon(Icons.star, color: Colors.amber.shade600)
          : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AufgabeDetailScreen(uid: aufgabe.uid),
          ),
        );
      },
    );
  }

  Widget? _untertitel() {
    final teile = <String>[
      if (fortschritt != null)
        '${fortschritt!.erledigt} von ${fortschritt!.gesamt}',
      if (aufgabe.faellig != null) 'Fällig: ${_datum(aufgabe.faellig!)}',
      if (aufgabe.prioritaet == 1) 'Hohe Priorität',
      if (aufgabe.meinTag) 'Mein Tag',
    ];
    if (teile.isEmpty) return null;
    return Text(teile.join(' · '));
  }

  String _datum(DateTime wert) {
    final tag = wert.day.toString().padLeft(2, '0');
    final monat = wert.month.toString().padLeft(2, '0');
    return '$tag.$monat.${wert.year}';
  }
}
