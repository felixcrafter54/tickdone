import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'aufgaben_screen.dart';
import 'login_screen.dart';

/// Übersicht der Aufgabenlisten (Collections mit VTODO) nach der Anmeldung.
///
/// Antippen öffnet die Aufgaben, langes Drücken bietet Löschen an,
/// der Plus-Button legt eine neue Liste an (MKCALENDAR mit VTODO).
class ListenScreen extends StatelessWidget {
  const ListenScreen({super.key});

  void _abmelden(BuildContext context) {
    context.read<AppState>().abmelden();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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

  Future<void> _loeschenBestaetigen(
      BuildContext context, Calendar liste) async {
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
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
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
    final appState = context.watch<AppState>();
    final listen = appState.aufgabenlisten;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Listen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () => _abmelden(context),
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
                  : ListView.builder(
                      itemCount: listen.length,
                      itemBuilder: (context, index) {
                        final liste = listen[index];
                        return ListTile(
                          leading: Icon(
                            Icons.checklist,
                            color: _farbeVon(liste) ??
                                Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(liste.displayName),
                          subtitle: (liste.description?.isNotEmpty ?? false)
                              ? Text(liste.description!)
                              : null,
                          onTap: () {
                            // Laden anstoßen und sofort navigieren –
                            // der Screen zeigt den Ladefortschritt selbst.
                            context.read<AppState>().oeffneListe(liste);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AufgabenScreen(),
                              ),
                            );
                          },
                          // Kontextaktion (Spec: langes Tippen auf Mobile).
                          onLongPress: () =>
                              _loeschenBestaetigen(context, liste),
                        );
                      },
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
