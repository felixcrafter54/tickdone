import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
