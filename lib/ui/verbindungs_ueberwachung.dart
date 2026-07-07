import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/verbindung_waechter.dart';
import '../state/app_state.dart';

/// Umhüllt die App und stößt bei RÜCKKEHR der Netzwerkverbindung automatisch
/// das Nachsynchronisieren an – so muss der Nutzer offline gesammelte
/// Änderungen nicht von Hand hochladen.
class VerbindungsUeberwachung extends StatefulWidget {
  const VerbindungsUeberwachung({super.key, required this.child});

  final Widget child;

  @override
  State<VerbindungsUeberwachung> createState() =>
      _VerbindungsUeberwachungState();
}

class _VerbindungsUeberwachungState extends State<VerbindungsUeberwachung> {
  final VerbindungWaechter _waechter = VerbindungWaechter();
  StreamSubscription<bool>? _abo;
  bool? _warOnline;

  @override
  void initState() {
    super.initState();
    _abo = _waechter.online.listen(_beiVerbindungswechsel);
  }

  void _beiVerbindungswechsel(bool online) {
    // Nur beim Übergang offline -> online synchronisieren.
    if (online && _warOnline != true && mounted) {
      context.read<AppState>().synchronisiereJetzt();
    }
    _warOnline = online;
  }

  @override
  void dispose() {
    _abo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
