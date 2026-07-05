import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgaben_screen.dart';
import 'relative_zeit.dart';

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
  final TextEditingController _schrittController = TextEditingController();
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
    _schrittController.dispose();
    super.dispose();
  }

  /// Neuen Schritt aus der Eingabezeile anlegen (Design-Doc, Abschnitt 4).
  Future<void> _schrittAnlegen() async {
    final titel = _schrittController.text.trim();
    if (titel.isEmpty) return;
    _schrittController.clear();
    await context
        .read<AppState>()
        .erstelleAufgabe(titel, parentUid: widget.uid);
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
      backgroundColor: TickdoneFarben.detailFlaeche,
      appBar: AppBar(
        backgroundColor: TickdoneFarben.detailFlaeche,
        title: Text(appState.aktiveListe?.displayName ?? ''),
      ),
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
                  color: aufgabe.erledigt
                      ? TickdoneFarben.erledigt
                      : TickdoneFarben.textGedimmt,
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
              // "Mein Tag" umschalten – Marker verfällt über Nacht.
              FilterChip(
                avatar: aufgabe.meinTag
                    ? null
                    : const Icon(Icons.wb_sunny_outlined, size: 18),
                label: const Text('Mein Tag'),
                selected: aufgabe.meinTag,
                onSelected: (wert) =>
                    context.read<AppState>().setzeMeinTag(widget.uid, wert),
              ),
              // Stern = als wichtig markieren (hohe Priorität).
              IconButton(
                icon: aufgabe.wichtig
                    ? const Icon(Icons.star, color: TickdoneFarben.favorit)
                    : const Icon(Icons.star_border,
                        color: TickdoneFarben.textGedimmt),
                tooltip: aufgabe.wichtig
                    ? 'Wichtig entfernen'
                    : 'Als wichtig markieren',
                onPressed: () => context
                    .read<AppState>()
                    .setzeWichtig(widget.uid, !aufgabe.wichtig),
              ),
            ],
          ),

          // Schritte
          const SizedBox(height: 16),
          Text(
            fortschritt == null
                ? 'Schritte'
                : 'Schritte (${fortschritt.erledigt} von '
                    '${fortschritt.gesamt} erledigt)',
            style: Theme.of(context).textTheme.titleMedium,
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
                  color: schritt.erledigt
                      ? TickdoneFarben.erledigt
                      : TickdoneFarben.textGedimmt,
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
              // Drei-Punkte-Menü je Schritt (Design-Doc, Abschnitt 4).
              trailing: PopupMenuButton<void Function()>(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: 'Schritt-Aktionen',
                onSelected: (aktion) => aktion(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => context
                        .read<AppState>()
                        .setzeErledigt(schritt.uid, !schritt.erledigt),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(schritt.erledigt
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle_outline),
                      title: Text(schritt.erledigt
                          ? 'Als offen markieren'
                          : 'Als erledigt markieren'),
                    ),
                  ),
                  PopupMenuItem(
                    value: () => context
                        .read<AppState>()
                        .stufeSchrittHoch(schritt.uid),
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.upgrade),
                      title: Text('Zur Aufgabe höherstufen'),
                    ),
                  ),
                  PopupMenuItem(
                    value: () => AufgabenScreen.loeschenBestaetigen(
                        context, schritt),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline,
                          color: farben.error),
                      title: Text('Schritt löschen',
                          style: TextStyle(color: farben.error)),
                    ),
                  ),
                ],
              ),
            ),

          // Eingabezeile "Schritt hinzufügen" (Design-Doc, Abschnitt 4).
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextField(
              controller: _schrittController,
              decoration: const InputDecoration(
                hintText: 'Schritt hinzufügen',
                prefixIcon: Icon(Icons.radio_button_unchecked,
                    color: TickdoneFarben.textSchwach),
                isDense: true,
              ),
              onSubmitted: (_) => _schrittAnlegen(),
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
              hintText: 'Notiz hinzufügen …',
            ),
          ),

          // Fußzeile: Erstellt-Zeit links, Löschen rechts
          // (Design-Doc, Abschnitt 4).
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  aufgabe.erstellt == null
                      ? ''
                      : 'Erstellt ${relativeZeit(aufgabe.erstellt!)}',
                  style: const TextStyle(
                    color: TickdoneFarben.textGedimmt,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: TickdoneFarben.ueberfaellig),
                tooltip: 'Aufgabe löschen',
                onPressed: () async {
                  final geloescht =
                      await AufgabenScreen.loeschenBestaetigen(
                          context, aufgabe);
                  if (geloescht && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _datum(DateTime wert) {
    final tag = wert.day.toString().padLeft(2, '0');
    final monat = wert.month.toString().padLeft(2, '0');
    return '$tag.$monat.${wert.year}';
  }
}
