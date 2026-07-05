import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';

/// Zeigt die Wurzel-Aufgaben der geöffneten Liste.
///
/// Schritte (Subtasks) erscheinen hier bewusst NICHT – die kommen in die
/// Detailansicht (Spec Schritt 5). Abhaken/Bearbeiten folgt in Schritt 6.
class AufgabenScreen extends StatelessWidget {
  const AufgabenScreen({super.key});

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
                      itemBuilder: (context, index) =>
                          _AufgabenZeile(aufgabe: aufgaben[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Zeile der Aufgabenliste: Status-Icon, Titel, Fälligkeit, Favorit.
class _AufgabenZeile extends StatelessWidget {
  const _AufgabenZeile({required this.aufgabe});

  final Aufgabe aufgabe;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        aufgabe.erledigt
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        color: aufgabe.erledigt ? farben.primary : farben.outline,
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
        // Detailansicht mit Schritten kommt in Spec Schritt 5.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${aufgabe.titel}" – Detailansicht folgt '
                'im nächsten Schritt.'),
          ),
        );
      },
    );
  }

  Widget? _untertitel() {
    final teile = <String>[
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
