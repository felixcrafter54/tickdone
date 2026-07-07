import 'package:connectivity_plus/connectivity_plus.dart';

/// Dünner Wrapper um `connectivity_plus`: meldet, ob überhaupt eine
/// Netzwerkschnittstelle (WLAN/Mobil/Ethernet) verfügbar ist.
///
/// Achtung: Das ist nur die Schnittstelle, nicht die echte Internet-
/// Erreichbarkeit. Als Auslöser fürs Nachsynchronisieren reicht das – schlägt
/// der Sync trotz "online" fehl, bleibt die Queue einfach erhalten.
class VerbindungWaechter {
  final Connectivity _connectivity;

  VerbindungWaechter([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  static bool _hatVerbindung(List<ConnectivityResult> ergebnisse) =>
      ergebnisse.any((e) => e != ConnectivityResult.none);

  /// true, sobald mindestens eine Verbindung besteht; false bei keiner.
  Stream<bool> get online =>
      _connectivity.onConnectivityChanged.map(_hatVerbindung);

  /// Aktueller Stand (einmalig abgefragt).
  Future<bool> istOnline() async =>
      _hatVerbindung(await _connectivity.checkConnectivity());
}
