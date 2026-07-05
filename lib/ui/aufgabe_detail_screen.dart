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
  const AufgabeDetailScreen({
    super.key,
    required this.uid,
    this.eingebettet = false,
  });

  /// UID statt Objekt, damit die Ansicht immer den frischen Stand
  /// aus dem AppState zeigt.
  final String uid;

  /// true im Drei-Spalten-Layout: Schließen/Löschen setzt die
  /// Detail-Auswahl im State zurück, statt eine Route zu poppen.
  final bool eingebettet;

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
  void didUpdateWidget(AufgabeDetailScreen alt) {
    super.didUpdateWidget(alt);
    // Im Drei-Spalten-Layout bleibt dasselbe State-Objekt bestehen, wenn
    // eine andere Aufgabe gewählt wird – dann Textfelder neu befüllen.
    if (alt.uid != widget.uid) {
      final aufgabe = context.read<AppState>().aufgabeMitUid(widget.uid);
      _titelController.text = aufgabe?.titel ?? '';
      _notizController.text = aufgabe?.notiz ?? '';
    }
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

  /// Detailansicht schließen: eingebettet die Auswahl zurücksetzen,
  /// sonst die Route poppen.
  void _schliessen() {
    if (widget.eingebettet) {
      context.read<AppState>().waehleAufgabe(null);
    } else {
      Navigator.of(context).pop();
    }
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
        backgroundColor: TickdoneFarben.detailFlaeche,
        appBar: AppBar(
          backgroundColor: TickdoneFarben.detailFlaeche,
          automaticallyImplyLeading: !widget.eingebettet,
          actions: [
            if (widget.eingebettet)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Schließen',
                onPressed: _schliessen,
              ),
          ],
        ),
        body: const Center(
          child: Text('Diese Aufgabe existiert nicht mehr.'),
        ),
      );
    }

    final schritte = appState.schritteVon(widget.uid);

    return Scaffold(
      backgroundColor: TickdoneFarben.detailFlaeche,
      appBar: AppBar(
        backgroundColor: TickdoneFarben.detailFlaeche,
        // Kein Listenname mehr (MS-To-Do-Stil).
        automaticallyImplyLeading: !widget.eingebettet,
        actions: [
          if (widget.eingebettet)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen (Esc)',
              onPressed: _schliessen,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Karte 1: Titel + Schritte + "Nächster Schritt"
          _Karte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titelZeile(aufgabe),
                for (final schritt in schritte) _schrittZeile(schritt),
                _schrittHinzufuegenZeile(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // "Mein Tag"
          _Karte(child: _meinTagZeile(aufgabe)),
          const SizedBox(height: 8),
          // Fälligkeit
          _Karte(child: _faelligZeile(aufgabe)),
          const SizedBox(height: 8),
          // Notiz
          _Karte(child: _notizFeld()),
          const SizedBox(height: 16),
          _fusszeile(aufgabe),
        ],
      ),
    );
  }

  Widget _titelZeile(Aufgabe aufgabe) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            aufgabe.erledigt
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: aufgabe.erledigt
                ? TickdoneFarben.erledigt
                : TickdoneFarben.textGedimmt,
            size: 26,
          ),
          tooltip: aufgabe.erledigt ? 'Wieder öffnen' : 'Erledigt',
          onPressed: () =>
              context.read<AppState>().setzeErledigt(widget.uid, !aufgabe.erledigt),
        ),
        Expanded(
          child: TextField(
            controller: _titelController,
            focusNode: _titelFokus,
            maxLines: null,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              decoration:
                  aufgabe.erledigt ? TextDecoration.lineThrough : null,
              color: aufgabe.erledigt
                  ? TickdoneFarben.textSchwach
                  : TickdoneFarben.text,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: false,
              isCollapsed: true,
              hintText: 'Titel',
            ),
            onSubmitted: (wert) =>
                context.read<AppState>().setzeTitel(widget.uid, wert),
          ),
        ),
        IconButton(
          icon: aufgabe.wichtig
              ? const Icon(Icons.star, color: TickdoneFarben.favorit)
              : const Icon(Icons.star_border,
                  color: TickdoneFarben.textGedimmt),
          tooltip:
              aufgabe.wichtig ? 'Wichtig entfernen' : 'Als wichtig markieren',
          onPressed: () =>
              context.read<AppState>().setzeWichtig(widget.uid, !aufgabe.wichtig),
        ),
      ],
    );
  }

  Widget _schrittZeile(Aufgabe schritt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              schritt.erledigt
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: schritt.erledigt
                  ? TickdoneFarben.erledigt
                  : TickdoneFarben.textGedimmt,
              size: 20,
            ),
            tooltip: schritt.erledigt ? 'Wieder öffnen' : 'Erledigt',
            onPressed: () => context
                .read<AppState>()
                .setzeErledigt(schritt.uid, !schritt.erledigt),
          ),
          Expanded(
            child: Text(
              schritt.titel,
              style: schritt.erledigt
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: TickdoneFarben.textSchwach,
                    )
                  : const TextStyle(color: TickdoneFarben.text),
            ),
          ),
          PopupMenuButton<void Function()>(
            icon: const Icon(Icons.more_vert,
                size: 18, color: TickdoneFarben.textGedimmt),
            tooltip: 'Schritt-Aktionen',
            onSelected: (aktion) => aktion(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () => context
                    .read<AppState>()
                    .setzeErledigt(schritt.uid, !schritt.erledigt),
                child: Text(schritt.erledigt
                    ? 'Als offen markieren'
                    : 'Als erledigt markieren'),
              ),
              PopupMenuItem(
                value: () =>
                    context.read<AppState>().stufeSchrittHoch(schritt.uid),
                child: const Text('Zur Aufgabe höherstufen'),
              ),
              PopupMenuItem(
                value: () =>
                    AufgabenScreen.loeschenBestaetigen(context, schritt),
                child: const Text('Schritt löschen',
                    style: TextStyle(color: TickdoneFarben.ueberfaellig)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schrittHinzufuegenZeile() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Row(
        children: [
          const Icon(Icons.add, size: 20, color: TickdoneFarben.akzent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _schrittController,
              style: const TextStyle(color: TickdoneFarben.akzent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                isCollapsed: true,
                hintText: 'Nächster Schritt',
                hintStyle: TextStyle(color: TickdoneFarben.akzent),
              ),
              onSubmitted: (_) => _schrittAnlegen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meinTagZeile(Aufgabe aufgabe) {
    final aktiv = aufgabe.meinTag;
    return ListTile(
      leading: Icon(Icons.wb_sunny_outlined,
          color: aktiv ? TickdoneFarben.akzent : TickdoneFarben.textGedimmt),
      title: Text(
        aktiv ? 'Zu "Mein Tag" hinzugefügt' : 'Zu "Mein Tag" hinzufügen',
        style: TextStyle(
            color: aktiv ? TickdoneFarben.akzent : TickdoneFarben.text),
      ),
      trailing: aktiv
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Aus "Mein Tag" entfernen',
              onPressed: () =>
                  context.read<AppState>().setzeMeinTag(widget.uid, false),
            )
          : null,
      onTap: aktiv
          ? null
          : () => context.read<AppState>().setzeMeinTag(widget.uid, true),
    );
  }

  Widget _faelligZeile(Aufgabe aufgabe) {
    final hat = aufgabe.faellig != null;
    return ListTile(
      leading: Icon(Icons.calendar_today_outlined,
          color: hat ? TickdoneFarben.akzent : TickdoneFarben.textGedimmt),
      title: Text(
        hat ? 'Fällig: ${faelligText(aufgabe.faellig!)}'
            : 'Fälligkeitsdatum hinzufügen',
        style: TextStyle(
            color: hat ? TickdoneFarben.akzent : TickdoneFarben.text),
      ),
      trailing: hat
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Termin entfernen',
              onPressed: () =>
                  context.read<AppState>().setzeFaellig(widget.uid, null),
            )
          : null,
      onTap: () => _faelligWaehlen(aufgabe),
    );
  }

  Widget _notizFeld() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _notizController,
        focusNode: _notizFokus,
        maxLines: null,
        minLines: 3,
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: false,
          hintText: 'Notiz hinzufügen …',
        ),
      ),
    );
  }

  Widget _fusszeile(Aufgabe aufgabe) {
    return Row(
      children: [
        Expanded(
          child: Text(
            aufgabe.erstellt == null
                ? ''
                : 'Erstellt ${relativeZeit(aufgabe.erstellt!)}',
            style: const TextStyle(
                color: TickdoneFarben.textGedimmt, fontSize: 12),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              color: TickdoneFarben.ueberfaellig),
          tooltip: 'Aufgabe löschen',
          onPressed: () async {
            final geloescht =
                await AufgabenScreen.loeschenBestaetigen(context, aufgabe);
            if (geloescht && context.mounted) _schliessen();
          },
        ),
      ],
    );
  }
}

/// Rundes Karten-Panel im Detailbereich (MS-To-Do-Stil).
class _Karte extends StatelessWidget {
  const _Karte({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TickdoneFarben.flaeche,
        borderRadius: BorderRadius.circular(tickdoneRadius),
        border: Border.all(color: TickdoneFarben.rahmen),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: child,
    );
  }
}

