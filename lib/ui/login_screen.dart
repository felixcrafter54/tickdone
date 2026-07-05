import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'listen_screen.dart';

/// Anmeldebildschirm: Server-URL, Benutzername, Passwort.
///
/// Das Passwort wird bewusst NICHT dauerhaft gespeichert –
/// das kommt später mit flutter_secure_storage (Spec, Schritt 8).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _benutzerController = TextEditingController();
  final _passwortController = TextEditingController();
  bool _passwortSichtbar = false;

  @override
  void dispose() {
    _serverController.dispose();
    _benutzerController.dispose();
    _passwortController.dispose();
    super.dispose();
  }

  Future<void> _anmelden() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final erfolgreich = await appState.anmelden(
      serverUrl: _serverController.text,
      benutzer: _benutzerController.text.trim(),
      passwort: _passwortController.text,
    );
    if (erfolgreich && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ListenScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tickdone – Anmeldung')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.task_alt, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    'Mit CalDAV-Server verbinden',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'Server-URL',
                      hintText: 'z.B. https://server.example.de',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (wert) => (wert == null || wert.trim().isEmpty)
                        ? 'Bitte Server-URL eingeben'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _benutzerController,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    autocorrect: false,
                    validator: (wert) => (wert == null || wert.trim().isEmpty)
                        ? 'Bitte Benutzername eingeben'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwortController,
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_passwortSichtbar
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _passwortSichtbar = !_passwortSichtbar),
                      ),
                    ),
                    obscureText: !_passwortSichtbar,
                    validator: (wert) => (wert == null || wert.isEmpty)
                        ? 'Bitte Passwort eingeben'
                        : null,
                    onFieldSubmitted: (_) => _anmelden(),
                  ),
                  const SizedBox(height: 24),
                  if (appState.fehlermeldung != null) ...[
                    Text(
                      appState.fehlermeldung!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: appState.laedt ? null : _anmelden,
                    child: appState.laedt
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verbinden'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
