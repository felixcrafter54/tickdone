import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_theme.dart';
import 'aufgaben_screen.dart';
import 'einstellungen_screen.dart';
import 'haupt_screen.dart';
import 'listen_aktionen.dart';

/// Übersicht der Aufgabenlisten (Collections mit VTODO) nach der Anmeldung.
///
/// Antippen öffnet die Aufgaben, langes Drücken bietet Löschen an,
/// der Plus-Button legt eine neue Liste an (MKCALENDAR mit VTODO).
class ListenScreen extends StatelessWidget {
  const ListenScreen({super.key});

  void _oeffneSmart(BuildContext context, Smartliste smart) {
    context.read<AppState>().oeffneSmartliste(smart);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AufgabenScreen()),
    );
  }

  Future<void> _neueListeDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Neue Liste'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (wert) => Navigator.of(dialogContext).pop(wert),
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
    final appState = context.watch<AppState>();
    final listen = appState.aufgabenlisten;
    return Scaffold(
      // Navigationsbereich ist etwas dunkler (Design-Doc, Abschnitt 1).
      backgroundColor: context.farben.sidebar,
      appBar: AppBar(
        backgroundColor: context.farben.sidebar,
        title: const Text('Meine Listen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const EinstellungenScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (appState.fehlermeldung != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                appState.fehlermeldung!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AppState>().listenNeuLaden(),
              child: listen.isEmpty
                  // ListView statt Text, damit Pull-to-Refresh auch bei
                  // leerer Liste funktioniert.
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Keine Aufgabenlisten gefunden.\n'
                            'Zum Aktualisieren nach unten ziehen.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        // Smart-Listen (listenübergreifend) oben.
                        for (final smart in Smartliste.values)
                          ListTile(
                            leading: Icon(smartIcon(smart),
                                color: context.farben.akzent),
                            title: Text(smart.anzeige),
                            trailing:
                                ListenZaehler(appState.smartAnzahl(smart)),
                            onTap: () => _oeffneSmart(context, smart),
                          ),
                        const Divider(),
                        for (final liste in listen)
                          ListTile(
                            leading: Icon(
                              Icons.checklist,
                              color: _farbeVon(liste) ??
                                  Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(liste.displayName),
                            subtitle:
                                (liste.description?.isNotEmpty ?? false)
                                    ? Text(liste.description!)
                                    : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListenZaehler(
                                    appState.offeneAnzahl(liste.uid)),
                                PopupMenuButton<void Function()>(
                                  icon: const Icon(Icons.more_vert),
                                  tooltip: 'Listen-Aktionen',
                                  onSelected: (aktion) => aktion(),
                                  itemBuilder: (menuContext) =>
                                      ListenAktionen.menueEintraege(
                                          menuContext, liste),
                                ),
                              ],
                            ),
                            onTap: () {
                              context.read<AppState>().oeffneListe(liste);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AufgabenScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Liste',
        onPressed: () => _neueListeDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Wandelt die Kalenderfarbe (#RRGGBB oder #RRGGBBAA) in eine
  /// Flutter-Farbe um. Liefert null bei fehlender/ungültiger Angabe.
  Color? _farbeVon(Calendar liste) {
    final hex = liste.color;
    if (hex == null || !hex.startsWith('#')) return null;
    final wert = hex.substring(1);
    try {
      if (wert.length == 6) {
        return Color(int.parse('FF$wert', radix: 16));
      }
      if (wert.length == 8) {
        // #RRGGBBAA → Flutter erwartet AARRGGBB
        return Color(int.parse(wert.substring(6) + wert.substring(0, 6),
            radix: 16));
      }
    } on FormatException {
      // Ungültige Farbangabe vom Server – einfach Standardfarbe nutzen.
    }
    return null;
  }
}
