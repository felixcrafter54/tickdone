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
  late final AppState _app;
  late final TextEditingController _titelController;
  late final TextEditingController _notizController;
  final FocusNode _titelFokus = FocusNode();
  final FocusNode _notizFokus = FocusNode();

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    final aufgabe = _app.aufgabeMitUid(widget.uid);
    _titelController = TextEditingController(text: aufgabe?.titel ?? '');
    _notizController = TextEditingController(text: aufgabe?.notiz ?? '');
    // Auto-Save beim Verlassen des Feldes (Spec, Abschnitt 3).
    _titelFokus.addListener(() {
      if (!_titelFokus.hasFocus) {
        _app.setzeTitel(widget.uid, _titelController.text);
      }
    });
    _notizFokus.addListener(() {
      if (!_notizFokus.hasFocus) {
        _app.setzeNotiz(widget.uid, _notizController.text);
      }
    });
  }

  /// Titel und Notiz für [uid] speichern (falls geändert). Wird zusätzlich
  /// beim Schließen/Wechseln/Verwerfen aufgerufen, damit auf Touch-Geräten
  /// nichts verloren geht, wo "Feld verlassen" nicht immer auslöst.
  void _speichereFelder(String uid) {
    _app.setzeTitel(uid, _titelController.text);
    _app.setzeNotiz(uid, _notizController.text);
  }

  @override
  void didUpdateWidget(AufgabeDetailScreen alt) {
    super.didUpdateWidget(alt);
    // Im Drei-Spalten-Layout bleibt dasselbe State-Objekt bestehen, wenn
    // eine andere Aufgabe gewählt wird – erst die alte sichern, dann neu
    // befüllen.
    if (alt.uid != widget.uid) {
      _speichereFelder(alt.uid);
      final aufgabe = _app.aufgabeMitUid(widget.uid);
      _titelController.text = aufgabe?.titel ?? '';
      _notizController.text = aufgabe?.notiz ?? '';
    }
  }

  @override
  void dispose() {
    // Offene Eingaben sichern (z.B. wenn die Ansicht ohne Fokusverlust
    // geschlossen wird).
    _speichereFelder(widget.uid);
    _titelFokus.dispose();
    _notizFokus.dispose();
    _titelController.dispose();
    _notizController.dispose();
    super.dispose();
  }

  /// Detailansicht schließen: eingebettet die Auswahl zurücksetzen,
  /// sonst die Route poppen. Vorher offene Eingaben speichern.
  void _schliessen() {
    _speichereFelder(widget.uid);
    if (widget.eingebettet) {
      _app.waehleAufgabe(null);
    } else {
      Navigator.of(context).pop();
    }
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
      // Titel oben und Fußzeile unten bleiben stehen; nur die Mitte
      // (Schritte, Mein Tag, Termin, Notiz) scrollt.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: _titelZeile(aufgabe),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                for (final schritt in schritte)
                  _SchrittZeile(key: ValueKey(schritt.uid), schritt: schritt),
                // Stabiler Key: bleibt fokussiert, wenn oben ein neuer
                // Schritt optimistisch eingefügt wird (Cursor/Tastatur weg).
                _NaechsterSchritt(
                  key: const ValueKey('naechster-schritt'),
                  parentUid: widget.uid,
                ),
                const SizedBox(height: 20),
                _meinTagZeile(aufgabe),
                const Divider(height: 1, color: TickdoneFarben.rahmen),
                _faelligZeile(aufgabe),
                const Divider(height: 1, color: TickdoneFarben.rahmen),
                const SizedBox(height: 12),
                _notizFeld(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: _fusszeile(aufgabe),
          ),
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
            maxLines: 1,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              decoration:
                  aufgabe.erledigt ? TextDecoration.lineThrough : null,
              color: aufgabe.erledigt
                  ? TickdoneFarben.textSchwach
                  : TickdoneFarben.text,
            ),
            decoration: randloseDeko('Titel'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _notizController,
        focusNode: _notizFokus,
        maxLines: null,
        minLines: 3,
        decoration: randloseDeko('Notiz hinzufügen …'),
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

/// Randlose Eingabe-Dekoration (kein Rahmen, keine Füllung) – überschreibt
/// auch enabled/focused Border des Themes, sonst bliebe der Rahmen sichtbar.
InputDecoration randloseDeko([String? hint]) => InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      isCollapsed: true,
      hintText: hint,
    );

/// Ein editierbarer Schritt (Subtask): reinklicken und tippen wie beim
/// Haupttitel; speichert beim Verlassen des Feldes bzw. mit Enter.
class _SchrittZeile extends StatefulWidget {
  const _SchrittZeile({super.key, required this.schritt});

  final Aufgabe schritt;

  @override
  State<_SchrittZeile> createState() => _SchrittZeileState();
}

class _SchrittZeileState extends State<_SchrittZeile> {
  late final TextEditingController _controller;
  final FocusNode _fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.schritt.titel);
    _fokus.addListener(() {
      if (!_fokus.hasFocus) {
        context.read<AppState>().setzeTitel(widget.schritt.uid, _controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(_SchrittZeile alt) {
    super.didUpdateWidget(alt);
    // Externe Änderung übernehmen, solange nicht gerade editiert wird.
    if (!_fokus.hasFocus && widget.schritt.titel != _controller.text) {
      _controller.text = widget.schritt.titel;
    }
  }

  @override
  void dispose() {
    _fokus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schritt = widget.schritt;
    return Column(
      children: [
        Row(
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
          child: TextField(
            controller: _controller,
            focusNode: _fokus,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            style: TextStyle(
              decoration:
                  schritt.erledigt ? TextDecoration.lineThrough : null,
              color: schritt.erledigt
                  ? TickdoneFarben.textSchwach
                  : TickdoneFarben.text,
            ),
            decoration: randloseDeko(),
            onSubmitted: (wert) =>
                context.read<AppState>().setzeTitel(schritt.uid, wert),
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
        const Divider(height: 1, color: TickdoneFarben.rahmen),
      ],
    );
  }
}

/// "Nächster Schritt"-Eingabe im selben Stil wie ein Schritt: normale
/// Schrift, kein Rahmen. Das Plus sitzt an der Kreis-Position und wird
/// beim Reinklicken (Fokus) zum leeren Schrittkreis.
class _NaechsterSchritt extends StatefulWidget {
  const _NaechsterSchritt({super.key, required this.parentUid});

  final String parentUid;

  @override
  State<_NaechsterSchritt> createState() => _NaechsterSchrittState();
}

class _NaechsterSchrittState extends State<_NaechsterSchritt> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fokus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fokus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _anlegen() {
    final titel = _controller.text.trim();
    if (titel.isEmpty) return;
    _controller.clear();
    // Fokus/Cursor bleiben im Feld, damit man direkt den nächsten Schritt
    // tippen kann; das Anlegen läuft optimistisch im Hintergrund.
    _fokus.requestFocus();
    context
        .read<AppState>()
        .erstelleAufgabe(titel, parentUid: widget.parentUid);
  }

  @override
  Widget build(BuildContext context) {
    final aktiv = _fokus.hasFocus;
    return Row(
      children: [
        IconButton(
          icon: Icon(
            aktiv ? Icons.radio_button_unchecked : Icons.add,
            color: TickdoneFarben.textGedimmt,
            size: 20,
          ),
          tooltip: 'Schritt hinzufügen',
          onPressed: () => _fokus.requestFocus(),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _fokus,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: TickdoneFarben.text),
            decoration: randloseDeko('Nächster Schritt'),
            onSubmitted: (_) => _anlegen(),
          ),
        ),
      ],
    );
  }
}

