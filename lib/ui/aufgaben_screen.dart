import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgabe_detail_screen.dart';

/// Zeigt die Wurzel-Aufgaben der geöffneten Liste.
///
/// Bedienung:
/// - Tippen aufs Status-Icon = abhaken (optimistisch, ohne Neuladen).
/// - Stern = als wichtig markieren (hohe Priorität).
/// - Langes Drücken = Mehrfachauswahl (Aktionen oben rechts).
/// - Rechtsklick (Desktop) = Kontextmenü mit Schnellaktionen.
/// - Plus-Button = neue Aufgabe.
class AufgabenScreen extends StatefulWidget {
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
  /// auf dem Desktop per Rechtsklick.
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
                    aufgabe.wichtig ? Icons.star : Icons.star_border),
                title: Text(aufgabe.wichtig
                    ? 'Wichtig entfernen'
                    : 'Als wichtig markieren'),
                onTap: () => schliessenUnd(() =>
                    appState.setzeWichtig(aufgabe.uid, !aufgabe.wichtig)),
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
                    aufgabe.uid,
                    DateTime(heute.year, heute.month, heute.day))),
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
  State<AufgabenScreen> createState() => _AufgabenScreenState();
}

class _AufgabenScreenState extends State<AufgabenScreen> {
  /// UIDs der ausgewählten Aufgaben (Mehrfachauswahl auf dem Handy).
  final Set<String> _auswahl = {};

  bool get _auswahlModus => _auswahl.isNotEmpty;

  void _auswahlUmschalten(String uid) {
    setState(() {
      if (!_auswahl.remove(uid)) {
        _auswahl.add(uid);
      }
    });
  }

  void _auswahlBeenden() => setState(_auswahl.clear);

  List<Aufgabe> _ausgewaehlteAufgaben(AppState appState) => [
        for (final uid in _auswahl)
          if (appState.aufgabeMitUid(uid) != null)
            appState.aufgabeMitUid(uid)!,
      ];

  /// "Mein Tag" für die Auswahl: sind schon alle markiert, wird
  /// entfernt – sonst gesetzt.
  Future<void> _auswahlMeinTag() async {
    final appState = context.read<AppState>();
    final aufgaben = _ausgewaehlteAufgaben(appState);
    final alleMarkiert = aufgaben.every((a) => a.meinTag);
    for (final aufgabe in aufgaben) {
      await appState.setzeMeinTag(aufgabe.uid, !alleMarkiert);
    }
    _auswahlBeenden();
  }

  /// Fälligkeit für alle ausgewählten Aufgaben setzen.
  Future<void> _auswahlFaellig() async {
    final heute = DateTime.now();
    final datum = await showDatePicker(
      context: context,
      initialDate: heute,
      firstDate: DateTime(heute.year - 1),
      lastDate: DateTime(heute.year + 10),
    );
    if (datum == null || !mounted) return;
    final appState = context.read<AppState>();
    for (final aufgabe in _ausgewaehlteAufgaben(appState)) {
      await appState.setzeFaellig(aufgabe.uid, datum);
    }
    _auswahlBeenden();
  }

  /// "Wichtig" für die Auswahl (analog zu Mein Tag).
  Future<void> _auswahlWichtig() async {
    final appState = context.read<AppState>();
    final aufgaben = _ausgewaehlteAufgaben(appState);
    final alleWichtig = aufgaben.every((a) => a.wichtig);
    for (final aufgabe in aufgaben) {
      await appState.setzeWichtig(aufgabe.uid, !alleWichtig);
    }
    _auswahlBeenden();
  }

  void _alleAuswaehlen() {
    final appState = context.read<AppState>();
    setState(() {
      _auswahl.addAll(appState.wurzelAufgaben.map((a) => a.uid));
    });
  }

  Future<void> _auswahlLoeschen() async {
    final anzahl = _auswahl.length;
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$anzahl Aufgaben löschen?'),
        content: const Text('Auch deren Schritte werden gelöscht.'),
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
    if (bestaetigt != true || !mounted) return;
    final appState = context.read<AppState>();
    for (final uid in _auswahl.toList()) {
      await appState.loescheAufgabe(uid);
    }
    _auswahlBeenden();
  }

  /// AppBar im Auswahlmodus: Sonne (Mein Tag), Kalender (Fälligkeit),
  /// Drei-Punkte-Menü (Alle auswählen, Wichtig, Löschen).
  AppBar _auswahlAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Auswahl beenden',
        onPressed: _auswahlBeenden,
      ),
      title: Text('${_auswahl.length} ausgewählt'),
      actions: [
        IconButton(
          icon: const Icon(Icons.wb_sunny_outlined),
          tooltip: 'Mein Tag',
          onPressed: _auswahlMeinTag,
        ),
        IconButton(
          icon: const Icon(Icons.event),
          tooltip: 'Fälligkeit setzen',
          onPressed: _auswahlFaellig,
        ),
        PopupMenuButton<void Function()>(
          onSelected: (aktion) => aktion(),
          itemBuilder: (menuContext) => [
            PopupMenuItem(
              value: _alleAuswaehlen,
              child: const Text('Alle auswählen'),
            ),
            PopupMenuItem(
              value: _auswahlWichtig,
              child: const Text('Als wichtig markieren'),
            ),
            PopupMenuItem(
              value: _auswahlLoeschen,
              child: Text('Löschen',
                  style: TextStyle(
                      color: Theme.of(menuContext).colorScheme.error)),
            ),
          ],
        ),
      ],
    );
  }

  AppBar _normaleAppBar(AppState appState) {
    return AppBar(
      title: Text(appState.aktiveListe?.displayName ?? 'Aufgaben'),
      actions: [
        // Filter: alle / offen / erledigt / wichtig
        PopupMenuButton<AufgabenFilter>(
          icon: Icon(appState.filter == AufgabenFilter.alle
              ? Icons.filter_list
              : Icons.filter_list_alt),
          tooltip: 'Filtern',
          onSelected: (wert) => context.read<AppState>().setzeFilter(wert),
          itemBuilder: (_) => [
            for (final wert in AufgabenFilter.values)
              CheckedPopupMenuItem(
                value: wert,
                checked: appState.filter == wert,
                child: Text(wert.anzeige),
              ),
          ],
        ),
        // Sortierung: manuell / Fälligkeit / Wichtig / Titel / Erstellt
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final aufgaben = appState.wurzelAufgaben;
    return Scaffold(
      appBar: _auswahlModus ? _auswahlAppBar() : _normaleAppBar(appState),
      body: Column(
        children: [
          // Inline-Zeile "Aufgabe hinzufügen" (Design-Doc, Abschnitt 3).
          const _NeueAufgabeZeile(),
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
                                : 'Keine Aufgaben hier. '
                                    'Füge oben eine hinzu.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: TickdoneFarben.textGedimmt),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: aufgaben.length,
                      itemBuilder: (context, index) {
                        final aufgabe = aufgaben[index];
                        return _AufgabenZeile(
                          aufgabe: aufgabe,
                          fortschritt:
                              appState.fortschrittVon(aufgabe.uid),
                          ausgewaehlt: _auswahl.contains(aufgabe.uid),
                          auswahlModus: _auswahlModus,
                          onAuswahl: () => _auswahlUmschalten(aufgabe.uid),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eingabezeile "Aufgabe hinzufügen" oberhalb der Liste –
/// Enter legt sofort an (Design-Doc, Abschnitt 3).
class _NeueAufgabeZeile extends StatefulWidget {
  const _NeueAufgabeZeile();

  @override
  State<_NeueAufgabeZeile> createState() => _NeueAufgabeZeileState();
}

class _NeueAufgabeZeileState extends State<_NeueAufgabeZeile> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _anlegen() async {
    final titel = _controller.text.trim();
    if (titel.isEmpty) return;
    _controller.clear();
    await context.read<AppState>().erstelleAufgabe(titel);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Aufgabe hinzufügen',
          prefixIcon: Icon(Icons.add, color: TickdoneFarben.akzent),
          isDense: true,
        ),
        onSubmitted: (_) => _anlegen(),
      ),
    );
  }
}

/// Eine Zeile der Aufgabenliste: Status-Icon, Titel, Meta-Zeile
/// (Fälligkeit · x von y · Notiz), Stern (wichtig).
class _AufgabenZeile extends StatelessWidget {
  const _AufgabenZeile({
    required this.aufgabe,
    this.fortschritt,
    required this.ausgewaehlt,
    required this.auswahlModus,
    required this.onAuswahl,
  });

  final Aufgabe aufgabe;
  final ({int erledigt, int gesamt})? fortschritt;
  final bool ausgewaehlt;
  final bool auswahlModus;
  final VoidCallback onAuswahl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: GestureDetector(
        // Desktop: Rechtsklick öffnet das Kontextmenü.
        onSecondaryTap: () =>
            AufgabenScreen.kontextMenue(context, aufgabe),
        child: ListTile(
          selected: ausgewaehlt,
          tileColor: TickdoneFarben.flaeche,
          selectedTileColor: TickdoneFarben.flaecheGewaehlt,
          hoverColor: TickdoneFarben.flaecheHover,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tickdoneRadius),
            side: BorderSide(
              color: ausgewaehlt
                  ? TickdoneFarben.akzentGedimmt
                  : TickdoneFarben.rahmen,
            ),
          ),
          // Tippen aufs Icon hakt ab bzw. öffnet wieder – optimistisch,
          // gespeichert wird im Hintergrund.
          leading: IconButton(
            icon: Icon(
              aufgabe.erledigt
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: aufgabe.erledigt
                  ? TickdoneFarben.erledigt
                  : TickdoneFarben.textGedimmt,
            ),
            tooltip: aufgabe.erledigt ? 'Wieder öffnen' : 'Erledigt',
            onPressed: () => context
                .read<AppState>()
                .setzeErledigt(aufgabe.uid, !aufgabe.erledigt),
          ),
          title: Text(
            aufgabe.titel,
            style: aufgabe.erledigt
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: TickdoneFarben.textSchwach,
                  )
                : const TextStyle(color: TickdoneFarben.text),
          ),
          subtitle: _untertitel(),
          // Stern = als wichtig markieren (hohe Priorität).
          trailing: IconButton(
            icon: aufgabe.wichtig
                ? const Icon(Icons.star, color: TickdoneFarben.favorit)
                : const Icon(Icons.star_border,
                    color: TickdoneFarben.textGedimmt),
            tooltip: aufgabe.wichtig
                ? 'Wichtig entfernen'
                : 'Als wichtig markieren',
            onPressed: () => context
                .read<AppState>()
                .setzeWichtig(aufgabe.uid, !aufgabe.wichtig),
          ),
          onTap: () {
            if (auswahlModus) {
              onAuswahl();
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AufgabeDetailScreen(uid: aufgabe.uid),
              ),
            );
          },
          // Handy: langes Drücken startet/erweitert die Mehrfachauswahl.
          onLongPress: onAuswahl,
        ),
      ),
    );
  }

  /// Meta-Zeile: Fälligkeit (rot wenn überfällig) · x von y · Notiz.
  Widget? _untertitel() {
    final spans = <TextSpan>[];
    if (aufgabe.faellig != null) {
      spans.add(TextSpan(
        text: 'Fällig: ${_datum(aufgabe.faellig!)}',
        style: _istUeberfaellig()
            ? const TextStyle(color: TickdoneFarben.ueberfaellig)
            : null,
      ));
    }
    if (fortschritt != null) {
      spans.add(TextSpan(
          text: '${fortschritt!.erledigt} von ${fortschritt!.gesamt}'));
    }
    if (aufgabe.notiz.isNotEmpty) {
      spans.add(const TextSpan(text: 'Notiz'));
    }
    if (spans.isEmpty) return null;

    final mitTrennern = <TextSpan>[];
    for (var i = 0; i < spans.length; i++) {
      if (i > 0) mitTrennern.add(const TextSpan(text: ' · '));
      mitTrennern.add(spans[i]);
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(
            color: TickdoneFarben.textGedimmt, fontSize: 12),
        children: mitTrennern,
      ),
    );
  }

  /// Überfällig = Fälligkeit vor heute und noch offen.
  bool _istUeberfaellig() {
    final faellig = aufgabe.faellig;
    if (faellig == null || aufgabe.erledigt) return false;
    final jetzt = DateTime.now();
    final heuteStart = DateTime(jetzt.year, jetzt.month, jetzt.day);
    return faellig.isBefore(heuteStart);
  }

  String _datum(DateTime wert) {
    final tag = wert.day.toString().padLeft(2, '0');
    final monat = wert.month.toString().padLeft(2, '0');
    return '$tag.$monat.${wert.year}';
  }
}
