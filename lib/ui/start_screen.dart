import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_theme.dart';
import 'haupt_screen.dart';
import 'login_screen.dart';

/// Startbildschirm: zeigt zuerst den lokalen Cache (Sofortstart, auch offline)
/// und meldet sich dann im Hintergrund an, um frische Daten zu holen.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pruefen());
  }

  Future<void> _pruefen() async {
    final app = context.read<AppState>();
    // Lokalen Cache laden (zeigt sofort die letzten Daten) und prüfen,
    // ob überhaupt ein Konto gespeichert ist.
    await app.ladeCache();
    final hatKonto = await app.hatGespeichertesKonto();
    if (!mounted) return;

    if (!hatKonto) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Konto vorhanden: direkt in die App (mit Cache). Anmelden und Auffrischen
    // laufen im Hintergrund – klappt das nicht (offline), bleibt der Cache
    // sichtbar.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HauptScreen()),
    );
    unawaited(app.automatischAnmelden());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 64, color: context.farben.akzent),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
