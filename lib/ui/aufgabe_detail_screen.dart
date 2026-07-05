import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';
import 'aufgaben_screen.dart';

/// Detailansicht einer Aufgabe: Schritte, Fälligkeit, Priorität, Notiz.
///
/// Bearbeiten mit Auto-Save (Spec, Abschnitt 3): Titel und Notiz werden
/// beim Verlassen des Feldes gespeichert (nicht pro Zeichen – sonst
/// ETag-Konflikte), Priorität und Termin sofort. Alles optimistisch,
/// ohne die Liste neu zu laden.
class AufgabeDetailScreen extends StatefulWidget {
  const AufgabeDetailScreen({super.key, required this.uid});

  /// UID statt Objekt, damit die Ansicht immer den frischen Stand
  /// aus dem AppState zeigt.
  final String uid;

  @override
  State<AufgabeDetailScreen> createState() => _AufgabeDetailScreenState();
}

class _AufgabeDetailScreenState extends State<AufgabeDetailScreen> {
  late final TextEditingController _titelController;
  late final TextEditingController _notizController;
  final FocusNode _titelFokus = FocusNode();
  final FocusNode _notizFokus = FocusNode();

  @override
  void initState() {
    super.initState();
    final aufgabe = context.read<AppState>().aufgabeMitUid(widget.uid);
    _titelController = TextEditingController(text: aufgabe?.titel ?? '');
    _notizController = TextEditingController(text: aufgabe?.notiz ?? '');
    // Auto-Save beim Verlassen des Feldes (Spec, Abschnitt 3).
    _titelFokus.addListener(() {
      if (!_titelFokus.hasFocus) {
        context
            .read<AppState>()
            .setzeTitel(widget.uid, _titelController.text);
      }
    });
    _notizFokus.addListener(() {
      if (!_notizFokus.hasFocus) {
        context
            .read<AppState>()
            .setzeNotiz(widget.uid, _notizController.text);
      }
    });
  }

  @override
  void dispose() {
    _titelFokus.dispose();
    _notizFokus.dispose();
    _titelController.dispose();
    _notizController.dispose();
    super.dispose();
  }

  Future<void> _faelligWaehlen(Aufgabe aufgabe) async {
    final heute = DateTime.now();
    final gewaehlt = await showDatePicker(
      context: context,
      initialDate: aufgabe.faellig ?? heute,
      firstDate: DateTime(heute.year - 1),
      lastDate: DateTime(heute.year + 10),
    );
    if (gewaehlt != null && mounted) {
      await context.read<AppState>().setzeFaellig(widget.uid, gewaehlt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final aufgabe = appState.aufgabeMitUid(widget.uid);
    if (aufgabe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aufgabe')),
        body: const Center(
          child: Text('Diese Aufgabe existiert nicht mehr.'),
        ),
      );
    }

    final schritte = appState.schritteVon(widget.uid);
    final fortschritt = appState.fortschrittVon(widget.uid);
    final farben = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(appState.aktiveListe?.displayName ?? '')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Titelzeile: abhaken + Titel bearbeiten
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(
                  aufgabe.erledigt
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: aufgabe.erledigt ? farben.primary : farben.outline,
                  size: 28,
                ),
                tooltip: aufgabe.erledigt ? 'Wieder öffnen' : 'Erledigt',
                onPressed: () => context
                    .read<AppState>()
                    .setzeErledigt(widget.uid, !aufgabe.erledigt),
              ),
              Expanded(
                child: TextField(
                  controller: _titelController,
                  focusNode: _titelFokus,
                  maxLines: null,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        decoration: aufgabe.erledigt
                            ? TextDecoration.lineThrough
                            : null,
                        color: aufgabe.erledigt ? farben.outline : null,
                      ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Titel',
                  ),
                  onSubmitted: (wert) =>
                      context.read<AppState>().setzeTitel(widget.uid, wert),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fälligkeit + Priorität (sofort speichern)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InputChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text(aufgabe.faellig == null
                    ? 'Fällig am …'
                    : 'Fällig: ${_datum(aufgabe.faellig!)}'),
                onPressed: () => _faelligWaehlen(aufgabe),
                onDeleted: aufgabe.faellig == null
                    ? null
                    : () => context
                        .read<AppState>()
                        .setzeFaellig(widget.uid, null),
                deleteButtonTooltipMessage: 'Fälligkeit entfernen',
              ),
              DropdownButton<int>(
                value: _prioStufe(aufgabe.prioritaet),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Keine Priorität')),
                  DropdownMenuItem(value: 1, child: Text('Hoch')),
                  DropdownMenuItem(value: 5, child: Text('Mittel')),
                  DropdownMenuItem(value: 9, child: Text('Niedrig')),
                ],
                onChanged: (wert) {
                  if (wert != null) {
                    context
                        .read<AppState>()
                        .setzePrioritaet(widget.uid, wert);
                  }
                },
              ),
              if (aufgabe.meinTag)
                const Chip(
                  avatar: Icon(Icons.wb_sunny_outlined, size: 18),
                  label: Text('Mein Tag'),
                ),
              if (aufgabe.favorit)
                Icon(Icons.star, color: Colors.amber.shade600),
            ],
          ),

          // Schritte
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  fortschritt == null
                      ? 'Schritte'
                      : 'Schritte (${fortschritt.erledigt} von '
                          '${fortschritt.gesamt} erledigt)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Schritt'),
                onPressed: () => AufgabenScreen.neueAufgabeDialog(
                  context,
                  parentUid: widget.uid,
                ),
              ),
            ],
          ),
          for (final schritt in schritte)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: IconButton(
                icon: Icon(
                  schritt.erledigt
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: schritt.erledigt ? farben.primary : farben.outline,
                ),
                tooltip: schritt.erledigt ? 'Wieder öffnen' : 'Erledigt',
                onPressed: () => context
                    .read<AppState>()
                    .setzeErledigt(schritt.uid, !schritt.erledigt),
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

          // Notiz (Auto-Save beim Verlassen des Feldes)
          const SizedBox(height: 16),
          Text('Notiz', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          TextField(
            controller: _notizController,
            focusNode: _notizFokus,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Notiz hinzufügen …',
            ),
          ),
        ],
      ),
    );
  }

  /// Priorität aufs Dropdown-Raster abbilden (1–4 hoch, 5 mittel, 6–9 niedrig).
  int _prioStufe(int prioritaet) {
    if (prioritaet == 0) return 0;
    if (prioritaet <= 4) return 1;
    if (prioritaet == 5) return 5;
    return 9;
  }

  String _datum(DateTime wert) {
    final tag = wert.day.toString().padLeft(2, '0');
    final monat = wert.month.toString().padLeft(2, '0');
    return '$tag.$monat.${wert.year}';
  }
}
