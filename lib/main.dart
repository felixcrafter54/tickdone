import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/app_theme.dart';
import 'ui/login_screen.dart';

void main() {
  runApp(const TickdoneApp());
}

/// Einstiegspunkt: stellt den AppState per Provider bereit
/// und startet mit dem Anmeldebildschirm.
class TickdoneApp extends StatelessWidget {
  const TickdoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Tickdone',
        // Dunkles Theme mit violettem Akzent (TICKDONE_DESIGN.md).
        theme: tickdoneTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}
