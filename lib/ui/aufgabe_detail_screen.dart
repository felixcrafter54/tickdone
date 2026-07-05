import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';

/// Detailansicht einer Aufgabe: Schritte (Subtasks), Fälligkeit,
/// Priorität, Notiz. Nur hier erscheinen die Schritte (Spec, Abschnitt 3).
///
/// Bearbeiten/Abhaken folgt in Spec Schritt 6 – bis dahin reine Anzeige.
class AufgabeDetailScreen extends StatelessWidget {
  const AufgabeDetailScreen({super.key, required this.uid});

  /// UID statt Objekt, damit die Ansicht nach einem Neuladen
  /// automatisch den frischen Stand aus dem AppState zeigt.
  final String uid;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final aufgabe = appState.aufgabeMitUid(uid);
    if (aufgabe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aufgabe')),
        body: const Center(
          child: Text('Diese Aufgabe existiert nicht mehr.'),
        ),
      );
    }

    final schritte = appState.schritteVon(uid);
    final fortschritt = appState.fortschrittVon(uid);
    final farben = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(appState.aktiveListe?.displayName ?? '')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().aufgabenNeuLaden(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  aufgabe.erledigt
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: aufgabe.erledigt ? farben.primary : farben.outline,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    aufgabe.titel,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          decoration: aufgabe.erledigt
                              ? TextDecoration.lineThrough
                              : null,
                          color: aufgabe.erledigt ? farben.outline : null,
                        ),
                  ),
                ),
                if (aufgabe.favorit)
                  Icon(Icons.star, color: Colors.amber.shade600),
              ],
            ),
            const SizedBox(height: 12),
            _merkmalChips(aufgabe),
            if (schritte.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Schritte (${fortschritt!.erledigt} von '
                '${fortschritt.gesamt} erledigt)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              for (final schritt in schritte)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    schritt.erledigt
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        schritt.erledigt ? farben.primary : farben.outline,
                  ),
                  title: Text(
                    schritt.titel,
                    style: schritt.erledigt
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: farben.outline,
                          )
                        : null,
                  ),
                ),
            ],
            if (aufgabe.notiz.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Notiz', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(aufgabe.notiz),
            ],
          ],
        ),
      ),
    );
  }

  /// Fälligkeit, Priorität und "Mein Tag" als kleine Info-Chips.
  Widget _merkmalChips(Aufgabe aufgabe) {
    final chips = <Widget>[
      if (aufgabe.faellig != null)
        Chip(
          avatar: const Icon(Icons.event, size: 18),
          label: Text('Fällig: ${_datum(aufgabe.faellig!)}'),
        ),
      if (aufgabe.prioritaet != 0)
        Chip(
          avatar: const Icon(Icons.flag, size: 18),
          label: Text(_prioritaetsText(aufgabe.prioritaet)),
        ),
      if (aufgabe.meinTag)
        const Chip(
          avatar: Icon(Icons.wb_sunny_outlined, size: 18),
          label: Text('Mein Tag'),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  String _prioritaetsText(int prioritaet) {
    // 1 hoch, 5 mittel, 9 niedrig (Spec); Zwischenwerte sinnvoll zuordnen.
    if (prioritaet >= 1 && prioritaet <= 4) return 'Hohe Priorität';
    if (prioritaet == 5) return 'Mittlere Priorität';
    return 'Niedrige Priorität';
  }

  String _datum(DateTime wert) {
    final tag = wert.day.toString().padLeft(2, '0');
    final monat = wert.month.toString().padLeft(2, '0');
    return '$tag.$monat.${wert.year}';
  }
}
