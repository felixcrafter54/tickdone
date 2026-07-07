import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const AufgabenScreen({
    super.key,
    this.eingebettet = false,
    this.onOeffneDetail,
    this.neueAufgabeFokus,
  });

  /// true = mittlere Spalte im Drei-Spalten-Layout: Antippen wählt die
  /// Aufgabe für den Detailbereich, statt eine Detail-Route zu pushen.
  final bool eingebettet;

  /// Callback beim Antippen einer Aufgabe im eingebetteten Modus.
  final void Function(String uid)? onOeffneDetail;

  /// Optionaler Fokus für die "Aufgabe hinzufügen"-Zeile (Strg+N).
  final FocusNode? neueAufgabeFokus;

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
    final app = context.read<AppState>();
    // Ohne Bestätigung (Einstellung) direkt löschen.
    if (!app.einstellungen.loeschenBestaetigen) {
      return app.loescheAufgabe(aufgabe.uid);
    }
    final schritte = app.fortschrittVon(aufgabe.uid)?.gesamt ?? 0;
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

  /// Antippen einer Zeile – je nach Plattform/Modus:
  /// - Desktop mit Strg: Zeile zur Mehrfachauswahl hinzufügen/entfernen.
  /// - Desktop ohne Strg: Auswahl leeren und Detail öffnen.
  /// - Touch im Auswahlmodus: Auswahl umschalten.
  /// - sonst: Detail öffnen (eingebettet wählen oder Route pushen).
  void _aufTap(Aufgabe aufgabe) {
    if (istDesktop && HardwareKeyboard.instance.isControlPressed) {
      _auswahlUmschalten(aufgabe.uid);
      return;
    }
    if (_auswahlModus) {
      if (istDesktop) {
        // Normaler Klick beendet die Mehrfachauswahl.
        setState(_auswahl.clear);
      } else {
        _auswahlUmschalten(aufgabe.uid);
        return;
      }
    }
    if (widget.eingebettet) {
      widget.onOeffneDetail?.call(aufgabe.uid);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AufgabeDetailScreen(uid: aufgabe.uid),
        ),
      );
    }
  }

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

  /// Ausgewählte Aufgaben in eine andere Liste verschieben.
  Future<void> _auswahlVerschieben() async {
    final appState = context.read<AppState>();
    final andereListen = appState.aufgabenlisten
        .where((l) => l.uid != appState.aktiveListe?.uid)
        .toList();
    if (andereListen.isEmpty) return;
    final ziel = await showModalBottomSheet<Calendar>(
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
                onTap: () => Navigator.of(sheetContext).pop(liste),
              ),
          ],
        ),
      ),
    );
    if (ziel == null || !mounted) return;
    for (final uid in _auswahl.toList()) {
      await appState.verschiebeAufgabe(uid, ziel);
    }
    _auswahlBeenden();
  }

  Future<void> _auswahlLoeschen() async {
    final appState = context.read<AppState>();
    if (!appState.einstellungen.loeschenBestaetigen) {
      for (final uid in _auswahl.toList()) {
        await appState.loescheAufgabe(uid);
      }
      _auswahlBeenden();
      return;
    }
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
            if (context
                .read<AppState>()
                .aufgabenlisten
                .where((l) => l.uid != context.read<AppState>().aktiveListe?.uid)
                .isNotEmpty)
              PopupMenuItem(
                value: _auswahlVerschieben,
                child: const Text('Verschieben in …'),
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
      title: Text(appState.ansichtTitel),
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
      // Auf dem Desktop keine Auswahl-Leiste – dort läuft die
      // Mehrfachauswahl über Strg+Klick und das Rechtsklick-Menü.
      appBar: (_auswahlModus && !istDesktop)
          ? _auswahlAppBar()
          : _normaleAppBar(appState),
      body: Column(
        children: [
          // Inline-Zeile "Aufgabe hinzufügen" – in Smart-Listen ausgeblendet
          // (das Anlegen dort wäre nicht eindeutig einer Liste zuzuordnen).
          if (appState.aktiveSmartliste == null)
            NeueAufgabeZeile(focusNode: widget.neueAufgabeFokus),
          // Hinweis auf offline gesammelte, noch nicht gespeicherte Änderungen.
          if (appState.ausstehendeAnzahl > 0)
            _AusstehendHinweis(anzahl: appState.ausstehendeAnzahl),
          // Dünne Anzeige oben, während im Hintergrund gesynct wird.
          if (appState.aufgabenLaden || appState.speichertGerade)
            const LinearProgressIndicator(minHeight: 2),
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
                                : appState.aktiveSmartliste != null
                                    ? 'Keine Aufgaben hier.'
                                    : 'Keine Aufgaben hier. '
                                        'Füge oben eine hinzu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: context.farben.textGedimmt),
                          ),
                        ),
                      ],
                    )
                  : _liste(context, appState, aufgaben),
            ),
          ),
        ],
      ),
    );
  }

  /// Umsortieren per Ziehgriff ist nur in Sortierung "Manuell" sinnvoll –
  /// und nicht im Auswahlmodus/Filter/Smart-Liste (dort ist die Anzeige
  /// nicht 1:1 die manuelle Reihenfolge).
  bool _umsortierbar(AppState app) =>
      app.sortierung == Sortierung.manuell &&
      app.filter == AufgabenFilter.alle &&
      app.aktiveSmartliste == null &&
      !_auswahlModus;

  Widget _zeile(BuildContext context, AppState appState, Aufgabe aufgabe,
      int index) {
    final markiert = _auswahlModus
        ? _auswahl.contains(aufgabe.uid)
        : widget.eingebettet && appState.aktiveAufgabeUid == aufgabe.uid;
    final ziele = (_auswahl.contains(aufgabe.uid) && _auswahl.length > 1)
        ? _ausgewaehlteAufgaben(appState)
        : [aufgabe];
    return AufgabenZeile(
      key: ValueKey(aufgabe.uid),
      aufgabe: aufgabe,
      fortschritt: appState.fortschrittVon(aufgabe.uid),
      ausgewaehlt: markiert,
      auswahlModus: _auswahlModus,
      kontextZiele: ziele,
      onTap: () => _aufTap(aufgabe),
      onLongPress: () => _auswahlUmschalten(aufgabe.uid),
      ziehIndex: _umsortierbar(appState) ? index : null,
    );
  }

  Widget _liste(
      BuildContext context, AppState appState, List<Aufgabe> aufgaben) {
    if (_umsortierbar(appState)) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: aufgaben.length,
        onReorderItem: (alt, neu) =>
            context.read<AppState>().ordneAufgabenNeu(alt, neu),
        itemBuilder: (context, index) =>
            _zeile(context, appState, aufgaben[index], index),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: aufgaben.length,
      itemBuilder: (context, index) =>
          _zeile(context, appState, aufgaben[index], index),
    );
  }
}

/// Dezenter Hinweis, dass Offline-Änderungen auf die Synchronisierung warten,
/// mit Button zum sofortigen erneuten Versuch.
class _AusstehendHinweis extends StatelessWidget {
  const _AusstehendHinweis({required this.anzahl});

  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final farben = context.farben;
    return Material(
      color: farben.flaecheGewaehlt,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: farben.textGedimmt),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                anzahl == 1
                    ? '1 Änderung wartet auf Synchronisierung'
                    : '$anzahl Änderungen warten auf Synchronisierung',
                style: TextStyle(color: farben.textGedimmt, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.read<AppState>().synchronisiereJetzt(),
              child: const Text('Jetzt syncen'),
            ),
          ],
        ),
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
  final _internFokus = FocusNode();

  FocusNode get _fokus => widget.focusNode ?? _internFokus;

  @override
  void dispose() {
    _controller.dispose();
    _internFokus.dispose();
    super.dispose();
  }

  void _anlegen() {
    final titel = _controller.text.trim();
    if (titel.isEmpty) return;
    _controller.clear();
    // Fokus/Tastatur bleiben, damit man mehrere Aufgaben hintereinander
    // eingeben kann. Das Anlegen läuft optimistisch im Hintergrund.
    _fokus.requestFocus();
    context.read<AppState>().erstelleAufgabe(titel);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _controller,
        focusNode: _fokus,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Aufgabe hinzufügen und Enter drücken …',
          prefixIcon: Icon(Icons.add, color: context.farben.akzent),
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
    this.auswahlModus = false,
    this.kontextZiele,
    required this.onTap,
    this.onLongPress,
    this.ziehIndex,
  });

  final Aufgabe aufgabe;
  final ({int erledigt, int gesamt})? fortschritt;
  final bool ausgewaehlt;

  /// Im Mehrfachauswahl-Modus wird links ein Auswahlkreis statt der
  /// Erledigt-Checkbox gezeigt.
  final bool auswahlModus;

  /// Ziele des Rechtsklick-Menüs (bei Mehrfachauswahl mehrere), sonst
  /// nur diese Aufgabe.
  final List<Aufgabe>? kontextZiele;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Wenn gesetzt (Sortierung "Manuell"): Ziehgriff rechts zum Umsortieren.
  final int? ziehIndex;

  @override
  Widget build(BuildContext context) {
    final zeile = ListTile(
      selected: ausgewaehlt,
      tileColor: context.farben.flaeche,
      selectedTileColor: context.farben.flaecheGewaehlt,
      hoverColor: context.farben.flaecheHover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tickdoneRadius),
        side: BorderSide(
          color: ausgewaehlt
              ? context.farben.akzentGedimmt
              : context.farben.rahmen,
        ),
      ),
      // Im Auswahlmodus: Auswahlkreis (gefüllt = markiert). Sonst:
      // Tippen aufs Icon hakt ab bzw. öffnet wieder (optimistisch).
      leading: auswahlModus
          ? IconButton(
              icon: Icon(
                ausgewaehlt
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: ausgewaehlt
                    ? context.farben.akzent
                    : context.farben.textGedimmt,
              ),
              tooltip: ausgewaehlt ? 'Abwählen' : 'Auswählen',
              onPressed: onTap,
            )
          : IconButton(
              icon: Icon(
                aufgabe.erledigt
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: aufgabe.erledigt
                    ? context.farben.erledigt
                    : context.farben.textGedimmt,
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
                color: context.farben.textSchwach,
              )
            : TextStyle(color: context.farben.text),
      ),
      subtitle: _untertitel(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stern = als wichtig markieren (hohe Priorität).
          IconButton(
            icon: aufgabe.wichtig
                ? Icon(Icons.star, color: context.farben.favorit)
                : Icon(Icons.star_border, color: context.farben.textGedimmt),
            tooltip: aufgabe.wichtig
                ? 'Wichtig entfernen'
                : 'Als wichtig markieren',
            onPressed: () => context
                .read<AppState>()
                .setzeWichtig(aufgabe.uid, !aufgabe.wichtig),
          ),
          // Ziehgriff nur in Sortierung "Manuell".
          if (ziehIndex != null)
            ReorderableDragStartListener(
              index: ziehIndex!,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Icon(Icons.drag_handle,
                    color: context.farben.textGedimmt),
              ),
            ),
        ],
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
        child: AufgabeKontextMenu(
          ziele: kontextZiele ?? [aufgabe],
          child: zeile,
        ),
      ),
    );
  }

  /// Meta-Zeile: Mein Tag · Fälligkeit (rot wenn überfällig) · x von y · Notiz.
  Widget? _untertitel(BuildContext context) {
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
            ? TextStyle(color: context.farben.ueberfaellig)
            : null,
      ));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(color: context.farben.textGedimmt, fontSize: 12),
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
    required this.ziele,
    required this.child,
  });

  /// Aufgaben, auf die die Aktionen wirken (bei Mehrfachauswahl mehrere).
  final List<Aufgabe> ziele;
  final Widget child;

  /// Menüeintrag mit Icon, Text und optional Kürzel (nur Desktop).
  Widget _eintrag(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    String? kuerzel,
    bool rot = false,
  }) {
    final farbe = rot ? context.farben.ueberfaellig : context.farben.text;
    return MenuItemButton(
      leadingIcon: Icon(icon, size: 18, color: farbe),
      trailingIcon: (kuerzel != null && istDesktop)
          ? Text(kuerzel,
              style: TextStyle(
                  color: context.farben.textGedimmt, fontSize: 12))
          : null,
      onPressed: onPressed,
      child: Text(text, style: TextStyle(color: farbe)),
    );
  }

  Future<void> _loeschen(BuildContext context, AppState app) async {
    if (ziele.length == 1) {
      await AufgabenScreen.loeschenBestaetigen(context, ziele.first);
      return;
    }
    if (!app.einstellungen.loeschenBestaetigen) {
      for (final a in ziele) {
        await app.loescheAufgabe(a.uid);
      }
      return;
    }
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${ziele.length} Aufgaben löschen?'),
        content: const Text('Auch deren Schritte werden gelöscht.'),
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
    if (bestaetigt != true) return;
    for (final a in ziele) {
      await app.loescheAufgabe(a.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final heute = DateTime.now();
    final morgen = heute.add(const Duration(days: 1));
    final andereListen = app.aufgabenlisten
        .where((l) => l.uid != app.aktiveListe?.uid)
        .toList();
    // Entscheidungen anhand ALLER Ziele (alle schon markiert → umschalten).
    final alleMeinTag = ziele.every((a) => a.meinTag);
    final alleWichtig = ziele.every((a) => a.wichtig);
    final alleErledigt = ziele.every((a) => a.erledigt);
    final wurzeln = ziele.where((a) => a.parentUid == null).toList();
    final verschiebbar = wurzeln.isNotEmpty && andereListen.isNotEmpty;
    final mehr = ziele.length > 1;

    return MenuAnchor(
      menuChildren: [
        _eintrag(
          context,
          icon: Icons.wb_sunny_outlined,
          text: alleMeinTag
              ? 'Aus "Mein Tag" entfernen'
              : 'Zu "Mein Tag" hinzufügen',
          kuerzel: 'Strg+T',
          onPressed: () {
            for (final a in ziele) {
              app.setzeMeinTag(a.uid, !alleMeinTag);
            }
          },
        ),
        _eintrag(
          context,
          icon: alleWichtig ? Icons.star : Icons.star_border,
          text: alleWichtig ? 'Wichtig entfernen' : 'Als wichtig markieren',
          onPressed: () {
            for (final a in ziele) {
              app.setzeWichtig(a.uid, !alleWichtig);
            }
          },
        ),
        _eintrag(
          context,
          icon: alleErledigt
              ? Icons.radio_button_unchecked
              : Icons.check_circle_outline,
          text: alleErledigt ? 'Als offen markieren' : 'Als erledigt markieren',
          kuerzel: 'Strg+D',
          onPressed: () {
            for (final a in ziele) {
              app.setzeErledigt(a.uid, !alleErledigt);
            }
          },
        ),
        const Divider(height: 1),
        _eintrag(
          context,
          icon: Icons.today,
          text: 'Heute fällig',
          onPressed: () {
            for (final a in ziele) {
              app.setzeFaellig(
                  a.uid, DateTime(heute.year, heute.month, heute.day));
            }
          },
        ),
        _eintrag(
          context,
          icon: Icons.event,
          text: 'Morgen fällig',
          onPressed: () {
            for (final a in ziele) {
              app.setzeFaellig(
                  a.uid, DateTime(morgen.year, morgen.month, morgen.day));
            }
          },
        ),
        _eintrag(
          context,
          icon: Icons.event_busy,
          text: 'Termin entfernen',
          onPressed: () {
            for (final a in ziele) {
              app.setzeFaellig(a.uid, null);
            }
          },
        ),
        if (verschiebbar) const Divider(height: 1),
        if (verschiebbar)
          SubmenuButton(
            leadingIcon: Icon(Icons.drive_file_move_outline,
                size: 18, color: context.farben.text),
            menuChildren: [
              for (final liste in andereListen)
                _eintrag(
          context,
                  icon: Icons.checklist,
                  text: liste.displayName,
                  onPressed: () {
                    for (final a in wurzeln) {
                      app.verschiebeAufgabe(a.uid, liste);
                    }
                  },
                ),
            ],
            child: Text(
                mehr ? 'Aufgaben verschieben in …' : 'Aufgabe verschieben in …',
                style: TextStyle(color: context.farben.text)),
          ),
        const Divider(height: 1),
        _eintrag(
          context,
          icon: Icons.delete_outline,
          text: mehr ? 'Aufgaben löschen' : 'Aufgabe löschen',
          kuerzel: 'Entf',
          rot: true,
          onPressed: () => _loeschen(context, app),
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
