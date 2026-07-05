import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgabe_detail_screen.dart';
import 'relative_zeit.dart';

/// Läuft die App auf einem Desktop-Betriebssystem? Dann Rechtsklick-
/// Kontextmenü mit Tastenkürzeln statt Mehrfachauswahl per langem Tippen.
bool get istDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

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
          const NeueAufgabeZeile(),
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
                        return AufgabenZeile(
                          aufgabe: aufgabe,
                          fortschritt:
                              appState.fortschrittVon(aufgabe.uid),
                          ausgewaehlt: _auswahl.contains(aufgabe.uid),
                          onTap: () {
                            if (_auswahlModus) {
                              _auswahlUmschalten(aufgabe.uid);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AufgabeDetailScreen(uid: aufgabe.uid),
                                ),
                              );
                            }
                          },
                          // Handy: langes Drücken = Mehrfachauswahl.
                          onLongPress: () => _auswahlUmschalten(aufgabe.uid),
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
class NeueAufgabeZeile extends StatefulWidget {
  const NeueAufgabeZeile({super.key, this.focusNode});

  /// Optional, damit Strg+N (Desktop) den Fokus hierher setzen kann.
  final FocusNode? focusNode;

  @override
  State<NeueAufgabeZeile> createState() => _NeueAufgabeZeileState();
}

class _NeueAufgabeZeileState extends State<NeueAufgabeZeile> {
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
        focusNode: widget.focusNode,
        decoration: const InputDecoration(
          hintText: 'Aufgabe hinzufügen und Enter drücken …',
          prefixIcon: Icon(Icons.add, color: TickdoneFarben.akzent),
          isDense: true,
        ),
        onSubmitted: (_) => _anlegen(),
      ),
    );
  }
}

/// Eine Zeile der Aufgabenliste: Status-Icon, Titel, Meta-Zeile
/// (Mein Tag · Fälligkeit · x von y · Notiz), Stern (wichtig).
///
/// [onTap]/[onLongPress] steuern Verhalten je Plattform (Handy: Auswahl,
/// Desktop: Detail wählen). Rechtsklick öffnet das Kontextmenü; Hovern
/// meldet die Aufgabe für Tastenkürzel.
class AufgabenZeile extends StatelessWidget {
  const AufgabenZeile({
    super.key,
    required this.aufgabe,
    this.fortschritt,
    required this.ausgewaehlt,
    required this.onTap,
    this.onLongPress,
  });

  final Aufgabe aufgabe;
  final ({int erledigt, int gesamt})? fortschritt;
  final bool ausgewaehlt;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final zeile = ListTile(
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
        tooltip:
            aufgabe.wichtig ? 'Wichtig entfernen' : 'Als wichtig markieren',
        onPressed: () => context
            .read<AppState>()
            .setzeWichtig(aufgabe.uid, !aufgabe.wichtig),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      // Hovern meldet die Aufgabe – Tastenkürzel wirken darauf (Desktop).
      child: MouseRegion(
        onEnter: (_) => context.read<AppState>().setzeHover(aufgabe.uid),
        onExit: (_) => context.read<AppState>().setzeHover(null),
        child: AufgabeKontextMenu(aufgabe: aufgabe, child: zeile),
      ),
    );
  }

  /// Meta-Zeile: Mein Tag · Fälligkeit (rot wenn überfällig) · x von y · Notiz.
  Widget? _untertitel() {
    final teile = <(String, bool)>[]; // (Text, überfällig-rot)
    if (aufgabe.meinTag) teile.add(('Mein Tag', false));
    if (aufgabe.faellig != null) {
      teile.add((faelligText(aufgabe.faellig!), _istUeberfaellig()));
    }
    if (fortschritt != null) {
      teile.add(('${fortschritt!.erledigt} von ${fortschritt!.gesamt}', false));
    }
    if (aufgabe.notiz.isNotEmpty) teile.add(('Notiz', false));
    if (teile.isEmpty) return null;

    final spans = <TextSpan>[];
    for (var i = 0; i < teile.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' · '));
      spans.add(TextSpan(
        text: teile[i].$1,
        style: teile[i].$2
            ? const TextStyle(color: TickdoneFarben.ueberfaellig)
            : null,
      ));
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(
            color: TickdoneFarben.textGedimmt, fontSize: 12),
        children: spans,
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
}

/// Umschließt eine Zeile mit dem Rechtsklick-Kontextmenü (Design-Doc,
/// Abschnitt 5) als Material-Menü. "Verschieben in …" ist ein Untermenü,
/// das auf dem Desktop beim Hovern aufklappt. Tastenkürzel werden nur auf
/// dem Desktop rechts angezeigt.
class AufgabeKontextMenu extends StatelessWidget {
  const AufgabeKontextMenu({
    super.key,
    required this.aufgabe,
    required this.child,
  });

  final Aufgabe aufgabe;
  final Widget child;

  /// Menüeintrag mit Icon, Text und optional Kürzel (nur Desktop).
  Widget _eintrag({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    String? kuerzel,
    bool rot = false,
  }) {
    final farbe = rot ? TickdoneFarben.ueberfaellig : TickdoneFarben.text;
    return MenuItemButton(
      leadingIcon: Icon(icon, size: 18, color: farbe),
      trailingIcon: (kuerzel != null && istDesktop)
          ? Text(kuerzel,
              style: const TextStyle(
                  color: TickdoneFarben.textGedimmt, fontSize: 12))
          : null,
      onPressed: onPressed,
      child: Text(text, style: TextStyle(color: farbe)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final heute = DateTime.now();
    final morgen = heute.add(const Duration(days: 1));
    final andereListen = app.aufgabenlisten
        .where((l) => l.uid != app.aktiveListe?.uid)
        .toList();
    final verschiebbar = aufgabe.parentUid == null && andereListen.isNotEmpty;

    return MenuAnchor(
      menuChildren: [
        _eintrag(
          icon: Icons.wb_sunny_outlined,
          text: aufgabe.meinTag
              ? 'Aus "Mein Tag" entfernen'
              : 'Zu "Mein Tag" hinzufügen',
          kuerzel: 'Strg+T',
          onPressed: () => app.setzeMeinTag(aufgabe.uid, !aufgabe.meinTag),
        ),
        _eintrag(
          icon: aufgabe.wichtig ? Icons.star : Icons.star_border,
          text: aufgabe.wichtig ? 'Wichtig entfernen' : 'Als wichtig markieren',
          onPressed: () => app.setzeWichtig(aufgabe.uid, !aufgabe.wichtig),
        ),
        _eintrag(
          icon: aufgabe.erledigt
              ? Icons.radio_button_unchecked
              : Icons.check_circle_outline,
          text: aufgabe.erledigt
              ? 'Als offen markieren'
              : 'Als erledigt markieren',
          kuerzel: 'Strg+D',
          onPressed: () => app.setzeErledigt(aufgabe.uid, !aufgabe.erledigt),
        ),
        const Divider(height: 1),
        _eintrag(
          icon: Icons.today,
          text: 'Heute fällig',
          onPressed: () => app.setzeFaellig(
              aufgabe.uid, DateTime(heute.year, heute.month, heute.day)),
        ),
        _eintrag(
          icon: Icons.event,
          text: 'Morgen fällig',
          onPressed: () => app.setzeFaellig(
              aufgabe.uid, DateTime(morgen.year, morgen.month, morgen.day)),
        ),
        _eintrag(
          icon: Icons.event_busy,
          text: 'Termin entfernen',
          onPressed: () => app.setzeFaellig(aufgabe.uid, null),
        ),
        if (verschiebbar) const Divider(height: 1),
        if (verschiebbar)
          SubmenuButton(
            leadingIcon: const Icon(Icons.drive_file_move_outline,
                size: 18, color: TickdoneFarben.text),
            menuChildren: [
              for (final liste in andereListen)
                _eintrag(
                  icon: Icons.checklist,
                  text: liste.displayName,
                  onPressed: () =>
                      app.verschiebeAufgabe(aufgabe.uid, liste),
                ),
            ],
            child: const Text('Aufgabe verschieben in …',
                style: TextStyle(color: TickdoneFarben.text)),
          ),
        const Divider(height: 1),
        _eintrag(
          icon: Icons.delete_outline,
          text: 'Aufgabe löschen',
          kuerzel: 'Entf',
          rot: true,
          onPressed: () =>
              AufgabenScreen.loeschenBestaetigen(context, aufgabe),
        ),
      ],
      builder: (context, controller, child) => GestureDetector(
        // Rechtsklick öffnet/schließt das Menü am Klickpunkt.
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
