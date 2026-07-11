import 'package:caldav/caldav.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/aufgabe.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgabe_detail_screen.dart';
import 'kontext_menu.dart';
import 'relative_zeit.dart';

/// Läuft die App auf einem Desktop (inkl. Desktop-Browser)? Dann Rechtsklick-
/// Kontextmenü mit Tastenkürzeln statt Mehrfachauswahl per langem Tippen.
/// Auch im Web zählt ein Desktop-Betriebssystem als Desktop – so funktionieren
/// die Kürzel (F2/Entf …) auch in der Web-Version; Mobil-Browser bleiben außen
/// vor (dort meldet defaultTargetPlatform android/iOS).
bool get istDesktop =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Ziehgriff für die Umsortier-Listen (Aufgaben & Schritte): sofortiges Ziehen.
Widget ziehGriff(BuildContext context, int index,
    {double? groesse, EdgeInsetsGeometry? padding}) {
  return ReorderableDragStartListener(
    index: index,
    child: Padding(
      padding: padding ?? const EdgeInsets.only(left: 4, right: 4),
      child: Icon(Icons.drag_handle,
          size: groesse, color: context.farben.textGedimmt),
    ),
  );
}

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

  /// Ein fester ScrollController für die Liste. Damit bleibt die
  /// Scroll-Position erhalten, wenn die Liste neu aufgebaut wird
  /// (z. B. beim Wechsel in den Auswahlmodus).
  final ScrollController _scrollController = ScrollController();

  /// Ist die "Erledigt"-Sektion eingeklappt (versteckt)? Standardmäßig ja –
  /// erledigte Aufgaben sollen die offene Liste nicht zumüllen.
  bool _erledigtEingeklappt = true;

  /// Nur in Smart-Listen: Aufgaben nach Herkunftsliste gruppieren (mit
  /// Überschrift je Liste) statt einer flachen Liste.
  bool _nachListeGruppieren = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        // Sortierung: manuell / Fälligkeit / Wichtig / Titel / Erstellt.
        // In "Geplant" ausgeblendet – dort ist die Reihenfolge fest
        // (überfälligste zuerst). Erneutes Wählen der aktiven Sortierung
        // kippt die Richtung; der Pfeil zeigt auf-/absteigend.
        if (appState.aktiveSmartliste != Smartliste.geplant)
          PopupMenuButton<Sortierung>(
            // Farbig hervorgehoben, wenn eine andere Sortierung als "Manuell"
            // aktiv ist – so sieht man auf einen Blick, dass sortiert wird.
            icon: Icon(
              Icons.sort,
              color: appState.sortierung != Sortierung.manuell
                  ? context.farben.akzent
                  : null,
            ),
            tooltip: 'Sortieren',
            onSelected: (wert) =>
                context.read<AppState>().waehleSortierung(wert),
            itemBuilder: (_) => [
              for (final wert in Sortierung.values)
                CheckedPopupMenuItem(
                  value: wert,
                  checked: appState.sortierung == wert,
                  child: Row(
                    children: [
                      Expanded(child: Text(wert.anzeige)),
                      // "Manuell" hat keine Richtung -> kein Pfeil.
                      if (appState.sortierung == wert && wert.hatRichtung)
                        Icon(
                          appState.aktiveRichtung == SortRichtung.aufsteigend
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                          color: context.farben.akzent,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        // Nur in Smart-Listen: nach Herkunftsliste gruppieren (mit Überschrift
        // je Liste). Farbig, wenn aktiv.
        if (appState.aktiveSmartliste != null)
          IconButton(
            icon: Icon(
              Icons.workspaces_outline,
              color: _nachListeGruppieren ? context.farben.akzent : null,
            ),
            tooltip: _nachListeGruppieren
                ? 'Gruppierung aufheben'
                : 'Nach Liste gruppieren',
            onPressed: () => setState(
                () => _nachListeGruppieren = !_nachListeGruppieren),
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
          // Dezenter Offline-Hinweis (kein roter Fehler): zeigt den gecachten
          // Stand. Nur wenn nichts aussteht – sonst reicht der Ausstehend-Hinweis.
          if (appState.offline && appState.ausstehendeAnzahl == 0)
            _OfflineHinweis(),
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

  /// Grundsätzlich eine manuell sortierbare Ansicht? Nur dann zeigt die
  /// Liste überhaupt Ziehgriffe (Sortierung "Manuell", keine Smart-Liste).
  /// Bewusst UNABHÄNGIG vom Auswahlmodus: So bleibt der Listen-Widget-Typ
  /// beim Wechsel in die Mehrfachauswahl gleich und die Scroll-Position
  /// springt nicht nach oben.
  bool _grundSortierbar(AppState app) =>
      app.sortierung == Sortierung.manuell &&
      app.aktiveSmartliste == null;

  /// Ziehgriff pro Zeile ist nur sinnvoll, wenn grundsätzlich sortierbar –
  /// und nicht im Auswahlmodus (dort wählt Tippen aus, statt zu ziehen).
  bool _umsortierbar(AppState app) => _grundSortierbar(app) && !_auswahlModus;

  /// Name der Herkunftsliste, den die Zeile im Untertitel zeigt: nur in
  /// Smart-Listen und nur, wenn NICHT ohnehin nach Liste gruppiert wird
  /// (sonst steht der Name schon in der Gruppenüberschrift).
  String? _listenNameFuer(AppState app, Aufgabe aufgabe) {
    if (app.aktiveSmartliste == null || _nachListeGruppieren) return null;
    return app.listeVonAufgabe(aufgabe.uid)?.displayName;
  }

  Widget _zeile(BuildContext context, AppState appState, Aufgabe aufgabe,
      {int? ziehIndex}) {
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
      ziehIndex: ziehIndex,
      listenName: _listenNameFuer(appState, aufgabe),
    );
  }

  /// Offene Aufgaben oben; erledigte darunter in einer einklappbaren Sektion
  /// ("Erledigt N"), damit sie sich verstecken lassen und die offene Liste
  /// nicht zumüllen. Neue (offene) Aufgaben landen dadurch automatisch ÜBER
  /// dem Erledigt-Bereich.
  Widget _liste(
      BuildContext context, AppState appState, List<Aufgabe> aufgaben) {
    final offen = [for (final a in aufgaben) if (!a.erledigt) a];
    final erledigt = [for (final a in aufgaben) if (a.erledigt) a];
    // Reorderbar hängt an _grundSortierbar (NICHT am Auswahlmodus): So bleibt
    // das Verhalten beim Wechsel in den Auswahlmodus gleich. Die Ziehgriffe
    // werden im Auswahlmodus per _umsortierbar ausgeblendet.
    final reorderbar = _grundSortierbar(appState);

    // Ziehbare Ansicht: bewusst das klassische ReorderableListView (nicht
    // SliverReorderableList) – dessen Umsortier-Animation (andere Zeilen weichen
    // aus) funktioniert auch auf Touch/Handy zuverlässig. Die Erledigt-Sektion
    // hängt als Footer darunter.
    if (reorderbar) {
      return ReorderableListView.builder(
        scrollController: _scrollController,
        buildDefaultDragHandles: false,
        proxyDecorator: tickdoneZiehProxy,
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: offen.length,
        onReorderItem: (alt, neu) =>
            context.read<AppState>().ordneAufgabenNeu(alt, neu),
        itemBuilder: (context, index) => _zeile(
          context,
          appState,
          offen[index],
          ziehIndex: _umsortierbar(appState) ? index : null,
        ),
        footer: erledigt.isEmpty
            ? null
            : _erledigtFooter(context, appState, erledigt),
      );
    }

    // Nicht ziehbar (Smart-Listen / andere Sortierungen): als Slivers, optional
    // nach Herkunftsliste gruppiert.
    final gruppiert = appState.aktiveSmartliste != null && _nachListeGruppieren;
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (gruppiert)
          ..._gruppierteSlivers(context, appState, offen)
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _zeile(context, appState, offen[index]),
              childCount: offen.length,
            ),
          ),
        if (offen.isEmpty && erledigt.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Keine offenen Aufgaben.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.farben.textGedimmt),
              ),
            ),
          ),
        ..._erledigtSlivers(context, appState, erledigt),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  /// Erledigt-Sektion als Footer (für die ziehbare ReorderableListView).
  Widget _erledigtFooter(
      BuildContext context, AppState appState, List<Aufgabe> erledigt) {
    return Column(
      key: const ValueKey('erledigt-footer'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _ErledigtKopf(
          anzahl: erledigt.length,
          eingeklappt: _erledigtEingeklappt,
          onToggle: () =>
              setState(() => _erledigtEingeklappt = !_erledigtEingeklappt),
        ),
        if (!_erledigtEingeklappt)
          for (final a in erledigt) _zeile(context, appState, a),
      ],
    );
  }

  /// Erledigt-Sektion als Slivers (für die nicht-ziehbare Ansicht).
  List<Widget> _erledigtSlivers(
      BuildContext context, AppState appState, List<Aufgabe> erledigt) {
    if (erledigt.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: _ErledigtKopf(
          anzahl: erledigt.length,
          eingeklappt: _erledigtEingeklappt,
          onToggle: () =>
              setState(() => _erledigtEingeklappt = !_erledigtEingeklappt),
        ),
      ),
      if (!_erledigtEingeklappt)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _zeile(context, appState, erledigt[index]),
            childCount: erledigt.length,
          ),
        ),
    ];
  }

  /// Offene Aufgaben nach Herkunftsliste gruppiert, je Liste eine Überschrift.
  List<Widget> _gruppierteSlivers(
      BuildContext context, AppState appState, List<Aufgabe> offen) {
    // Aufgaben ihrer Liste zuordnen (Reihenfolge = Reihenfolge der Listen).
    final proListe = <String, List<Aufgabe>>{};
    for (final a in offen) {
      final uid = appState.listeVonAufgabe(a.uid)?.uid ?? '';
      (proListe[uid] ??= []).add(a);
    }
    final reihenfolge = [for (final l in appState.aufgabenlisten) l.uid];
    int rang(String uid) {
      final i = reihenfolge.indexOf(uid);
      return i == -1 ? reihenfolge.length : i;
    }
    final schluessel = proListe.keys.toList()
      ..sort((a, b) => rang(a).compareTo(rang(b)));

    final slivers = <Widget>[];
    for (final uid in schluessel) {
      final gruppe = proListe[uid]!;
      final name = appState.listeMitUid(uid)?.displayName ?? 'Ohne Liste';
      slivers.add(SliverToBoxAdapter(
        child: _ListenGruppenKopf(name: name, anzahl: gruppe.length),
      ));
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _zeile(context, appState, gruppe[index]),
          childCount: gruppe.length,
        ),
      ));
    }
    return slivers;
  }
}

/// Einklappbarer Kopf der "Erledigt"-Sektion (Pfeil + Anzahl). Tippen
/// klappt die erledigten Aufgaben auf/zu.
class _ErledigtKopf extends StatelessWidget {
  const _ErledigtKopf({
    required this.anzahl,
    required this.eingeklappt,
    required this.onToggle,
  });

  final int anzahl;
  final bool eingeklappt;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final farben = context.farben;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Material(
        color: farben.flaeche,
        borderRadius: BorderRadius.circular(tickdoneRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(tickdoneRadius),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  eingeklappt ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                  color: farben.textGedimmt,
                ),
                const SizedBox(width: 8),
                Text('Erledigt',
                    style: TextStyle(
                        color: farben.text, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('$anzahl', style: TextStyle(color: farben.textGedimmt)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Überschrift einer Listen-Gruppe (bei "Nach Liste gruppieren" in Smart-Listen).
class _ListenGruppenKopf extends StatelessWidget {
  const _ListenGruppenKopf({required this.name, required this.anzahl});

  final String name;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final farben = context.farben;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Icon(Icons.checklist, size: 18, color: farben.akzent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: farben.text, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text('$anzahl', style: TextStyle(color: farben.textGedimmt)),
        ],
      ),
    );
  }
}

/// Dezenter Offline-Hinweis (kein Fehler): der gecachte Stand wird gezeigt,
/// die App verbindet sich automatisch neu.
class _OfflineHinweis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final farben = context.farben;
    return Container(
      width: double.infinity,
      color: farben.flaeche,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: farben.textGedimmt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline – gespeicherter Stand',
              style: TextStyle(color: farben.textGedimmt, fontSize: 13),
            ),
          ),
        ],
      ),
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
    this.listenName,
  });

  final Aufgabe aufgabe;
  final ({int erledigt, int gesamt})? fortschritt;
  final bool ausgewaehlt;

  /// Name der Herkunftsliste – in Smart-Listen unter dem Titel gezeigt,
  /// damit man sieht, aus welcher Liste die Aufgabe stammt. Sonst null.
  final String? listenName;

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
          if (ziehIndex != null) ziehGriff(context, ziehIndex!),
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

  /// Meta-Zeile: [Liste ·] Mein Tag · Fälligkeit (rot wenn überfällig) ·
  /// x von y · Notiz.
  Widget? _untertitel(BuildContext context) {
    final teile = <(String, bool)>[]; // (Text, überfällig-rot)
    // In Smart-Listen zuerst die Herkunftsliste.
    if (listenName != null && listenName!.isNotEmpty) {
      teile.add((listenName!, false));
    }
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

    final eintraege = <KontextEintrag>[
      KontextAktion(
        icon: Icons.wb_sunny_outlined,
        text: alleMeinTag
            ? 'Aus "Mein Tag" entfernen'
            : 'Zu "Mein Tag" hinzufügen',
        kuerzel: 'Strg+T',
        onTap: () {
          for (final a in ziele) {
            app.setzeMeinTag(a.uid, !alleMeinTag);
          }
        },
      ),
      KontextAktion(
        icon: alleWichtig ? Icons.star : Icons.star_border,
        text: alleWichtig ? 'Wichtig entfernen' : 'Als wichtig markieren',
        onTap: () {
          for (final a in ziele) {
            app.setzeWichtig(a.uid, !alleWichtig);
          }
        },
      ),
      KontextAktion(
        icon: alleErledigt
            ? Icons.radio_button_unchecked
            : Icons.check_circle_outline,
        text: alleErledigt ? 'Als offen markieren' : 'Als erledigt markieren',
        kuerzel: 'Strg+D',
        onTap: () {
          for (final a in ziele) {
            app.setzeErledigt(a.uid, !alleErledigt);
          }
        },
      ),
      const KontextTrenner(),
      KontextAktion(
        icon: Icons.today,
        text: 'Heute fällig',
        onTap: () {
          for (final a in ziele) {
            app.setzeFaellig(
                a.uid, DateTime(heute.year, heute.month, heute.day));
          }
        },
      ),
      KontextAktion(
        icon: Icons.event,
        text: 'Morgen fällig',
        onTap: () {
          for (final a in ziele) {
            app.setzeFaellig(
                a.uid, DateTime(morgen.year, morgen.month, morgen.day));
          }
        },
      ),
      KontextAktion(
        icon: Icons.event_busy,
        text: 'Termin entfernen',
        onTap: () {
          for (final a in ziele) {
            app.setzeFaellig(a.uid, null);
          }
        },
      ),
      if (verschiebbar) const KontextTrenner(),
      if (verschiebbar)
        KontextUntermenu(
          icon: Icons.drive_file_move_outline,
          text: mehr ? 'Aufgaben verschieben in …' : 'Aufgabe verschieben in …',
          kinder: [
            for (final liste in andereListen)
              KontextAktion(
                icon: Icons.checklist,
                text: liste.displayName,
                onTap: () {
                  for (final a in wurzeln) {
                    app.verschiebeAufgabe(a.uid, liste);
                  }
                },
              ),
          ],
        ),
      const KontextTrenner(),
      KontextAktion(
        icon: Icons.delete_outline,
        text: mehr ? 'Aufgaben löschen' : 'Aufgabe löschen',
        kuerzel: 'Entf',
        rot: true,
        onTap: () => _loeschen(context, app),
      ),
    ];

    return KontextMenuBereich(eintraege: eintraege, child: child);
  }
}
