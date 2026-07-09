import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/einstellungen_speicher.dart';
import '../state/app_state.dart';
import 'login_screen.dart';

/// Einstellungen: Design, Verhalten und Konto.
class EinstellungenScreen extends StatelessWidget {
  const EinstellungenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final e = app.einstellungen;
    final zugang = app.gespeicherterZugang;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const _Abschnitt('Design'),
          for (final (wahl, titel, unter) in const [
            (ThemeWahl.system, 'System', 'Hell oder dunkel wie das Gerät'),
            (ThemeWahl.hell, 'Hell', null),
            (ThemeWahl.dunkel, 'Dunkel', null),
          ])
            ListTile(
              leading: Icon(
                e.theme == wahl
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: e.theme == wahl
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(titel),
              subtitle: unter == null ? null : Text(unter),
              onTap: () => context.read<AppState>().setzeTheme(wahl),
            ),
          const Divider(),
          const _Abschnitt('Verhalten'),
          SwitchListTile(
            title: const Text('Neue Aufgabe oben einfügen'),
            subtitle: const Text('Sonst wird sie unten angehängt'),
            value: e.neueAufgabeOben,
            onChanged: (v) =>
                context.read<AppState>().setzeNeueAufgabeOben(v),
          ),
          SwitchListTile(
            title: const Text('Wichtige Aufgaben nach oben'),
            subtitle: const Text('Mit Stern markierte immer zuerst'),
            value: e.wichtigeOben,
            onChanged: (v) => context.read<AppState>().setzeWichtigeOben(v),
          ),
          SwitchListTile(
            title: const Text('Löschen bestätigen'),
            subtitle: const Text('Vor dem Löschen nachfragen'),
            value: e.loeschenBestaetigen,
            onChanged: (v) =>
                context.read<AppState>().setzeLoeschenBestaetigen(v),
          ),
          const Divider(),
          const _Abschnitt('Konto'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(zugang?.benutzer ?? 'Angemeldet'),
            // Im Web zeigt der echte CalDAV-Host (aus der Deploy-ENV) mehr als
            // die eigene Web-Domain; sonst der eingegebene Server.
            subtitle: Text(
                app.caldavAnzeigeHost ?? zugang?.server ?? app.verbundeneUrl ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Abmelden'),
            onTap: () async {
              await context.read<AppState>().abmelden();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const Divider(),
          const _Abschnitt('Über'),
          const _UeberTile(),
        ],
      ),
    );
  }
}

/// Zeigt App-Version (auch in der Web/PWA) und Lizenz; öffnet auf Tipp den
/// Standard-Über-Dialog inkl. Open-Source-Lizenzen.
class _UeberTile extends StatelessWidget {
  const _UeberTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final version = info == null
            ? '…'
            : '${info.version} (${info.buildNumber})';
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Tickdone'),
          subtitle: Text('Version $version\nLizenz: GPL-3.0'),
          isThreeLine: true,
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Tickdone',
            applicationVersion: 'Version $version',
            applicationLegalese: 'Lizenziert unter der GNU General Public '
                'License v3.0 (GPL-3.0).\n\n© 2026 Felix Noster',
          ),
        );
      },
    );
  }
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt(this.titel);
  final String titel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        titel.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
