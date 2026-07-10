import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgabe_detail_screen.dart';
import 'aufgaben_screen.dart';
import 'einstellungen_screen.dart';
import 'kontext_menu.dart';
import 'listen_aktionen.dart';
import 'listen_screen.dart';

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

/// Icon je Smart-Liste.
IconData smartIcon(Smartliste s) => switch (s) {
      Smartliste.meinTag => Icons.wb_sunny_outlined,
      Smartliste.wichtig => Icons.star_border,
      Smartliste.geplant => Icons.event_outlined,
    };

/// Kleiner gedimmter Zähler offener Aufgaben rechts am Listeneintrag.
/// Zeigt nichts bei null (noch unbekannt) oder 0.
class ListenZaehler extends StatelessWidget {
  const ListenZaehler(this.anzahl, {super.key});

  final int? anzahl;

  @override
  Widget build(BuildContext context) {
    if (anzahl == null || anzahl == 0) return const SizedBox.shrink();
    return Text(
      '$anzahl',
      style: TextStyle(color: context.farben.textGedimmt, fontSize: 13),
    );
  }
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

class _ListeUmbenennenIntent extends Intent {
  const _ListeUmbenennenIntent();
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

  /// Tastenkürzel wirken auf die Aufgabe unter dem Mauszeiger, sonst auf
  /// die im Detailbereich gewählte.
  void _mitZiel(void Function(String uid) aktion) {
    final uid = _app.hoverAufgabeUid ?? _app.aktiveAufgabeUid;
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
        const SingleActivator(LogicalKeyboardKey.f2):
            const _ListeUmbenennenIntent(),
        const SingleActivator(LogicalKeyboardKey.f5):
            const _AktualisierenIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _SchliessenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ErledigtIntent: CallbackAction<_ErledigtIntent>(
            onInvoke: (_) {
              _mitZiel((uid) {
                final a = _app.aufgabeMitUid(uid);
                if (a != null) _app.setzeErledigt(uid, !a.erledigt);
              });
              return null;
            },
          ),
          _MeinTagIntent: CallbackAction<_MeinTagIntent>(
            onInvoke: (_) {
              _mitZiel((uid) {
                final a = _app.aufgabeMitUid(uid);
                if (a != null) _app.setzeMeinTag(uid, !a.meinTag);
              });
              return null;
            },
          ),
          _LoeschenIntent: CallbackAction<_LoeschenIntent>(
            onInvoke: (_) {
              // Schwebt die Maus über einer Liste, wird die Liste gelöscht,
              // sonst die anvisierte Aufgabe.
              final liste = _app.listeMitUid(_app.hoverListeUid);
              if (liste != null) {
                ListenAktionen.loeschen(context, liste);
                return null;
              }
              _mitZiel((uid) {
                final a = _app.aufgabeMitUid(uid);
                if (a != null) AufgabenScreen.loeschenBestaetigen(context, a);
              });
              return null;
            },
          ),
          _ListeUmbenennenIntent: CallbackAction<_ListeUmbenennenIntent>(
            onInvoke: (_) {
              // F2 benennt die überschwebte, sonst die aktive Liste um.
              final liste = _app.listeMitUid(_app.hoverListeUid) ??
                  _app.aktiveListe;
              if (liste != null) ListenAktionen.umbenennen(context, liste);
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
                  child: !app.hatAnsicht
                      ? Center(
                          child: Text('Wähle links eine Liste.',
                              style: TextStyle(
                                  color: context.farben.textGedimmt)),
                        )
                      : AufgabenScreen(
                          // Neuaufbau bei Ansichtswechsel (frische Auswahl).
                          key: ValueKey(app.aktiveListe?.uid ??
                              'smart-${app.aktiveSmartliste?.name}'),
                          eingebettet: true,
                          neueAufgabeFokus: _neueAufgabeFokus,
                          onOeffneDetail: (uid) =>
                              context.read<AppState>().waehleAufgabe(uid),
                        ),
                ),
                // Detailspalte nur zeigen, wenn eine Aufgabe gewählt ist –
                // sonst füllt die mittlere Spalte den Platz (X schließt).
                if (aktiveUid != null &&
                    app.aufgabeMitUid(aktiveUid) != null) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 380,
                    child: AufgabeDetailScreen(
                      key: ValueKey(aktiveUid),
                      uid: aktiveUid,
                      eingebettet: true,
                    ),
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      color: context.farben.sidebar,
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
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: 'Einstellungen',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const EinstellungenScreen()),
                  ),
                ),
              ],
            ),
          ),
          // Smart-Listen (listenübergreifend) oben, wie MS To Do.
          for (final smart in Smartliste.values)
            ListTile(
              dense: true,
              selected: app.aktiveSmartliste == smart,
              selectedTileColor: context.farben.flaecheGewaehlt,
              leading: Icon(smartIcon(smart), color: context.farben.akzent),
              title: Text(smart.anzeige),
              trailing: ListenZaehler(app.smartAnzahl(smart)),
              onTap: () => context.read<AppState>().oeffneSmartliste(smart),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('LISTEN',
                style: TextStyle(
                    color: context.farben.textSchwach,
                    fontSize: 12,
                    letterSpacing: 1)),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final liste in app.aufgabenlisten)
                  MouseRegion(
                    // Hovern meldet die Liste für F2/Entf.
                    onEnter: (_) =>
                        context.read<AppState>().setzeListenHover(liste.uid),
                    onExit: (_) =>
                        context.read<AppState>().setzeListenHover(null),
                    // PC: Rechtsklick öffnet das Listen-Menü am Klickpunkt.
                    child: KontextMenuBereich(
                      eintraege: ListenAktionen.eintraege(context, liste),
                      child: ListTile(
                        dense: true,
                        selected: app.aktiveListe?.uid == liste.uid,
                        selectedTileColor: context.farben.flaecheGewaehlt,
                        leading: Icon(Icons.checklist,
                            color:
                                listenFarbe(liste) ?? context.farben.akzent),
                        title: Text(liste.displayName,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        // Anzahl offener Aufgaben + Drei-Punkte-Menü.
                        // Der Button ist wichtig für Touch-Geräte (Tablet
                        // quer), wo es keinen Rechtsklick gibt.
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListenZaehler(app.offeneAnzahl(liste.uid)),
                            KontextMenuKnopf(
                              eintraege:
                                  ListenAktionen.eintraege(context, liste),
                              tooltip: 'Listen-Aktionen',
                            ),
                          ],
                        ),
                        onTap: () =>
                            context.read<AppState>().oeffneListe(liste),
                      ),
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
