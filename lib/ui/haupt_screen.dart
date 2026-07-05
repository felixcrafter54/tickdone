import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgabe_detail_screen.dart';
import 'aufgaben_screen.dart';
import 'listen_screen.dart';
import 'login_screen.dart';

/// Responsives Grundgerüst nach TICKDONE_DESIGN.md, Abschnitt 2:
/// - schmal (Handy): eine Seite, klassische Push-Navigation.
/// - breit (Tablet quer / Desktop): drei Spalten nebeneinander
///   (Listen | Aufgaben | Detail).
class HauptScreen extends StatelessWidget {
  const HauptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) return const _DreiSpalten();
        // Schmal: bewährter Handy-Fluss mit gestapelten Seiten.
        return const ListenScreen();
      },
    );
  }
}

/// Wandelt die Kalenderfarbe (#RRGGBB / #RRGGBBAA) in eine Flutter-Farbe.
Color? listenFarbe(Calendar liste) {
  final hex = liste.color;
  if (hex == null || !hex.startsWith('#')) return null;
  final wert = hex.substring(1);
  try {
    if (wert.length == 6) return Color(int.parse('FF$wert', radix: 16));
    if (wert.length == 8) {
      return Color(
          int.parse(wert.substring(6) + wert.substring(0, 6), radix: 16));
    }
  } on FormatException {
    // Ungültige Angabe – Standardfarbe verwenden.
  }
  return null;
}

// ---- Tastatur-Intents (Design-Doc, Abschnitt 7) ----
class _ErledigtIntent extends Intent {
  const _ErledigtIntent();
}

class _MeinTagIntent extends Intent {
  const _MeinTagIntent();
}

class _LoeschenIntent extends Intent {
  const _LoeschenIntent();
}

class _NeuIntent extends Intent {
  const _NeuIntent();
}

class _AktualisierenIntent extends Intent {
  const _AktualisierenIntent();
}

class _SchliessenIntent extends Intent {
  const _SchliessenIntent();
}

class _DreiSpalten extends StatefulWidget {
  const _DreiSpalten();

  @override
  State<_DreiSpalten> createState() => _DreiSpaltenState();
}

class _DreiSpaltenState extends State<_DreiSpalten> {
  final FocusNode _neueAufgabeFokus = FocusNode();

  @override
  void dispose() {
    _neueAufgabeFokus.dispose();
    super.dispose();
  }

  AppState get _app => context.read<AppState>();

  void _mitAktiver(void Function(String uid) aktion) {
    final uid = _app.aktiveAufgabeUid;
    if (uid != null) aktion(uid);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final aktiveUid = app.aktiveAufgabeUid;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            const _ErledigtIntent(),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            const _MeinTagIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const _NeuIntent(),
        const SingleActivator(LogicalKeyboardKey.delete):
            const _LoeschenIntent(),
        const SingleActivator(LogicalKeyboardKey.f5):
            const _AktualisierenIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _SchliessenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ErledigtIntent: CallbackAction<_ErledigtIntent>(
            onInvoke: (_) {
              _mitAktiver((uid) {
                final a = _app.aufgabeMitUid(uid);
                if (a != null) _app.setzeErledigt(uid, !a.erledigt);
              });
              return null;
            },
          ),
          _MeinTagIntent: CallbackAction<_MeinTagIntent>(
            onInvoke: (_) {
              _mitAktiver((uid) {
                final a = _app.aufgabeMitUid(uid);
                if (a != null) _app.setzeMeinTag(uid, !a.meinTag);
              });
              return null;
            },
          ),
          _LoeschenIntent: CallbackAction<_LoeschenIntent>(
            onInvoke: (_) {
              _mitAktiver((uid) {
                final a = _app.aufgabeMitUid(uid);
                if (a != null) AufgabenScreen.loeschenBestaetigen(context, a);
              });
              return null;
            },
          ),
          _NeuIntent: CallbackAction<_NeuIntent>(
            onInvoke: (_) {
              _neueAufgabeFokus.requestFocus();
              return null;
            },
          ),
          _AktualisierenIntent: CallbackAction<_AktualisierenIntent>(
            onInvoke: (_) {
              _app.aufgabenNeuLaden();
              return null;
            },
          ),
          _SchliessenIntent: CallbackAction<_SchliessenIntent>(
            onInvoke: (_) {
              _app.waehleAufgabe(null);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 280, child: _ListenSpalte()),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _AufgabenSpalte(neueAufgabeFokus: _neueAufgabeFokus),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 380,
                  child: aktiveUid != null &&
                          app.aufgabeMitUid(aktiveUid) != null
                      ? AufgabeDetailScreen(
                          key: ValueKey(aktiveUid),
                          uid: aktiveUid,
                          eingebettet: true,
                        )
                      : const _LeererDetail(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linke Spalte: Konto + Aufgabenlisten (wie die Desktop-Sidebar).
class _ListenSpalte extends StatelessWidget {
  const _ListenSpalte();

  Future<void> _neueListe(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Neue Liste'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (w) => Navigator.of(dialogContext).pop(w),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await context.read<AppState>().erstelleListe(name);
  }

  Future<void> _loeschen(BuildContext context, Calendar liste) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Liste "${liste.displayName}" löschen?'),
        content: const Text(
            'Alle Aufgaben dieser Liste werden endgültig gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: TickdoneFarben.ueberfaellig),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (bestaetigt == true && context.mounted) {
      await context.read<AppState>().loescheListe(liste);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      color: TickdoneFarben.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Aufgaben',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: 'Abmelden',
                  onPressed: () {
                    context.read<AppState>().abmelden();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('LISTEN',
                style: TextStyle(
                    color: TickdoneFarben.textSchwach,
                    fontSize: 12,
                    letterSpacing: 1)),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final liste in app.aufgabenlisten)
                  GestureDetector(
                    onSecondaryTap: () => _loeschen(context, liste),
                    child: ListTile(
                      dense: true,
                      selected: app.aktiveListe?.uid == liste.uid,
                      selectedTileColor: TickdoneFarben.flaecheGewaehlt,
                      leading: Icon(Icons.checklist,
                          color: listenFarbe(liste) ?? TickdoneFarben.akzent),
                      title: Text(liste.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => context.read<AppState>().oeffneListe(liste),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Neue Liste'),
            onPressed: () => _neueListe(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Mittlere Spalte: Aufgaben der aktiven Liste.
class _AufgabenSpalte extends StatelessWidget {
  const _AufgabenSpalte({required this.neueAufgabeFokus});

  final FocusNode neueAufgabeFokus;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.aktiveListe == null) {
      return const Center(
        child: Text('Wähle links eine Liste.',
            style: TextStyle(color: TickdoneFarben.textGedimmt)),
      );
    }
    final aufgaben = app.wurzelAufgaben;
    return Column(
      children: [
        // Kopfbereich: Listenname + Sortieren/Filtern/Aktualisieren.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(app.aktiveListe!.displayName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              PopupMenuButton<Sortierung>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sortieren',
                onSelected: (w) => context.read<AppState>().setzeSortierung(w),
                itemBuilder: (_) => [
                  for (final w in Sortierung.values)
                    CheckedPopupMenuItem(
                      value: w,
                      checked: app.sortierung == w,
                      child: Text(w.anzeige),
                    ),
                ],
              ),
              PopupMenuButton<AufgabenFilter>(
                icon: Icon(app.filter == AufgabenFilter.alle
                    ? Icons.filter_list
                    : Icons.filter_list_alt),
                tooltip: 'Filtern',
                onSelected: (w) => context.read<AppState>().setzeFilter(w),
                itemBuilder: (_) => [
                  for (final w in AufgabenFilter.values)
                    CheckedPopupMenuItem(
                      value: w,
                      checked: app.filter == w,
                      child: Text(w.anzeige),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Aktualisieren (F5)',
                onPressed: () => context.read<AppState>().aufgabenNeuLaden(),
              ),
            ],
          ),
        ),
        NeueAufgabeZeile(focusNode: neueAufgabeFokus),
        if (app.aufgabenLaden) const LinearProgressIndicator(),
        Expanded(
          child: aufgaben.isEmpty
              ? const Center(
                  child: Text('Keine Aufgaben hier. Füge oben eine hinzu.',
                      style: TextStyle(color: TickdoneFarben.textGedimmt)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: aufgaben.length,
                  itemBuilder: (context, index) {
                    final aufgabe = aufgaben[index];
                    return AufgabenZeile(
                      aufgabe: aufgabe,
                      fortschritt: app.fortschrittVon(aufgabe.uid),
                      ausgewaehlt: app.aktiveAufgabeUid == aufgabe.uid,
                      // Desktop: Antippen wählt die Aufgabe für den
                      // Detailbereich (kein Seitenwechsel).
                      onTap: () =>
                          context.read<AppState>().waehleAufgabe(aufgabe.uid),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Rechte Spalte ohne Auswahl (Design-Doc: keine leere Detailseite
/// aufdrängen, aber im Drei-Spalten-Layout einen ruhigen Platzhalter).
class _LeererDetail extends StatelessWidget {
  const _LeererDetail();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TickdoneFarben.detailFlaeche,
      child: const Center(
        child: Text('Keine Aufgabe ausgewählt',
            style: TextStyle(color: TickdoneFarben.textGedimmt)),
      ),
    );
  }
}
