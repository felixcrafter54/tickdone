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

  /// Kontextmenü einer Aufgabe (Design-Doc, Abschnitt 5) –
  /// auf Mobile per langem Tippen.
  static Future<void> kontextMenue(
    BuildContext context,
    Aufgabe aufgabe,
  ) async {
    final appState = context.read<AppState>();
    final heute = DateTime.now();
    final morgen = heute.add(const Duration(days: 1));
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void schliessenUnd(void Function() aktion) {
          Navigator.of(sheetContext).pop();
          aktion();
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: Text(aufgabe.meinTag
                    ? 'Aus "Mein Tag" entfernen'
                    : 'Zu "Mein Tag" hinzufügen'),
                onTap: () => schliessenUnd(() =>
                    appState.setzeMeinTag(aufgabe.uid, !aufgabe.meinTag)),
              ),
              ListTile(
                leading: Icon(
                    aufgabe.favorit ? Icons.star : Icons.star_border),
                title: Text(aufgabe.favorit
                    ? 'Wichtig entfernen'
                    : 'Als wichtig markieren'),
                onTap: () => schliessenUnd(() =>
                    appState.setzeFavorit(aufgabe.uid, !aufgabe.favorit)),
              ),
              ListTile(
                leading: Icon(aufgabe.erledigt
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline),
                title: Text(aufgabe.erledigt
                    ? 'Als offen markieren'
                    : 'Als erledigt markieren'),
                onTap: () => schliessenUnd(() =>
                    appState.setzeErledigt(aufgabe.uid, !aufgabe.erledigt)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Heute fällig'),
                onTap: () => schliessenUnd(() => appState.setzeFaellig(
                    aufgabe.uid, DateTime(heute.year, heute.month, heute.day))),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Morgen fällig'),
                onTap: () => schliessenUnd(() => appState.setzeFaellig(
                    aufgabe.uid,
                    DateTime(morgen.year, morgen.month, morgen.day))),
              ),
              if (aufgabe.faellig != null)
                ListTile(
                  leading: const Icon(Icons.event_busy),
                  title: const Text('Termin entfernen'),
                  onTap: () => schliessenUnd(
                      () => appState.setzeFaellig(aufgabe.uid, null)),
                ),
              const Divider(height: 1),
              // Nur die ANDEREN Listen anbieten (Design-Doc, Abschnitt 5).
              if (aufgabe.parentUid == null &&
                  appState.aufgabenlisten
                      .where((l) => l.uid != appState.aktiveListe?.uid)
                      .isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Aufgabe verschieben in …'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _verschiebenMenue(context, aufgabe);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(sheetContext).colorScheme.error),
                title: Text(
                  'Aufgabe löschen',
                  style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.error),
                ),
                onTap: () => schliessenUnd(
                    () => loeschenBestaetigen(context, aufgabe)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Untermenü "Verschieben in …" mit den anderen Listen.
  static Future<void> _verschiebenMenue(
    BuildContext context,
    Aufgabe aufgabe,
  ) async {
    final appState = context.read<AppState>();
    final andereListen = appState.aufgabenlisten
        .where((l) => l.uid != appState.aktiveListe?.uid)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Verschieben in …',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final liste in andereListen)
              ListTile(
                leading: const Icon(Icons.checklist),
                title: Text(liste.displayName),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  appState.verschiebeAufgabe(aufgabe.uid, liste);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Nachfrage und Löschen einer Aufgabe bzw. eines Schritts.
  /// Gibt true zurück, wenn gelöscht wurde.
  static Future<bool> loeschenBestaetigen(
    BuildContext context,
    Aufgabe aufgabe,
  ) async {
    final schritte =
        context.read<AppState>().fortschrittVon(aufgabe.uid)?.gesamt ?? 0;
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('"${aufgabe.titel}" löschen?'),
        content: schritte > 0
            ? Text('Auch die $schritte Schritte werden gelöscht.')
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !context.mounted) return false;
    return context.read<AppState>().loescheAufgabe(aufgabe.uid);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final aufgaben = appState.wurzelAufgaben;
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.aktiveListe?.displayName ?? 'Aufgaben'),
        actions: [
          // Filter: alle / offen / erledigt / Favoriten
          PopupMenuButton<AufgabenFilter>(
            icon: Icon(appState.filter == AufgabenFilter.alle
                ? Icons.filter_list
                : Icons.filter_list_alt),
            tooltip: 'Filtern',
            onSelected: (wert) =>
                context.read<AppState>().setzeFilter(wert),
            itemBuilder: (_) => [
              for (final wert in AufgabenFilter.values)
                CheckedPopupMenuItem(
                  value: wert,
                  checked: appState.filter == wert,
                  child: Text(wert.anzeige),
                ),
            ],
          ),
          // Sortierung: manuell / Fälligkeit / Priorität / Titel / Erstellt
          PopupMenuButton<Sortierung>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sortieren',
            onSelected: (wert) =>
                context.read<AppState>().setzeSortierung(wert),
            itemBuilder: (_) => [
              for (final wert in Sortierung.values)
                CheckedPopupMenuItem(
                  value: wert,
                  checked: appState.sortierung == wert,
                  child: Text(wert.anzeige),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () => context.read<AppState>().aufgabenNeuLaden(),
          ),
        ],
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
      // Stern antippen = Favorit umschalten (Marker in CATEGORIES).
      trailing: IconButton(
        icon: aufgabe.favorit
            ? Icon(Icons.star, color: Colors.amber.shade600)
            : Icon(Icons.star_border, color: farben.outline),
        tooltip: aufgabe.favorit
            ? 'Favorit entfernen'
            : 'Als Favorit markieren',
        onPressed: () => context
            .read<AppState>()
            .setzeFavorit(aufgabe.uid, !aufgabe.favorit),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AufgabeDetailScreen(uid: aufgabe.uid),
          ),
        );
      },
      // Kontextmenü mit Schnellaktionen (Design-Doc, Abschnitt 5).
      onLongPress: () => AufgabenScreen.kontextMenue(context, aufgabe),
    );
  }

  // Meta-Zeile nach Design-Doc, Abschnitt 3:
  // Fälligkeit · Priorität · Fortschritt · Notiz-Hinweis
  Widget? _untertitel() {
    final teile = <String>[
      if (aufgabe.faellig != null) 'Fällig: ${_datum(aufgabe.faellig!)}',
      if (aufgabe.prioritaet != 0) _prioritaetsLabel(aufgabe.prioritaet),
      if (fortschritt != null)
        '${fortschritt!.erledigt} von ${fortschritt!.gesamt}',
      if (aufgabe.notiz.isNotEmpty) 'Notiz',
    ];
    if (teile.isEmpty) return null;
    return Text(teile.join(' · '));
  }

  String _prioritaetsLabel(int prioritaet) {
    if (prioritaet <= 4) return 'Hohe Priorität';
    if (prioritaet == 5) return 'Mittlere Priorität';
    return 'Niedrige Priorität';
  }

  String _datum(DateTime wert) {
    final tag = wert.day.toString().padLeft(2, '0');
    final monat = wert.month.toString().padLeft(2, '0');
    return '$tag.$monat.${wert.year}';
  }
}
