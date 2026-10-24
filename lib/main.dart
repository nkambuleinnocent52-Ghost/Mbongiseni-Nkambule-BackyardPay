import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cloud_gateway.dart';
import 'data/cloud_config.dart';

import 'data/store.dart';
import 'screens/common.dart';
import 'screens/auth.dart';
import 'screens/dashboard.dart';
import 'services/alerts.dart';
import 'services/auth_callback.dart';
import 'ui/design.dart';

export 'screens/auth.dart' show SplashScreen, UserTypeScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    runApp(const BackyardPayApp());
  } catch (_) {
    runApp(
      MaterialApp(
        theme: backyardTheme(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'BackyardPay could not connect. Check your connection and reload the app.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BackyardPayApp extends StatefulWidget {
  final AppStore? store;
  const BackyardPayApp({super.key, this.store});
  @override
  State<BackyardPayApp> createState() => _BackyardPayAppState();
}

class _BackyardPayAppState extends State<BackyardPayApp> {
  late final AppStore store =
      widget.store ??
      AppStore(
        PreferencesStorage(),
        cloud: CloudGateway(Supabase.instance.client),
      );
  Timer? syncTimer;
  StreamSubscription<AuthState>? authSubscription;
  bool recovery = false;
  bool callbackProcessed = false;
  bool ready = false;
  String? loadError;
  final Set<String> notified = {};
  @override
  void initState() {
    super.initState();
    store.addListener(alert);
    initialize();
    if (store.isCloud) {
      authSubscription = store.cloud!.client.auth.onAuthStateChange.listen(
        (event) {
          if (!mounted) return;
          if (event.event == AuthChangeEvent.passwordRecovery) {
            setState(() => recovery = true);
          } else if (event.event == AuthChangeEvent.signedOut) {
            store.refresh();
            setState(() => recovery = false);
          }
        },
        onError: (Object _) {
          /* The triggering auth operation reports the error. */
        },
      );
      syncTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
        if (store.currentUser == null || !ready) return;
        try {
          await store.refresh();
        } catch (_) {
          /* Last successful view remains; commands still require server acknowledgement. */
        }
      });
    }
  }

  Future<void> initialize() async {
    try {
      if (widget.store == null) {
        final uri = Uri.base;
        if (!callbackProcessed &&
            (uri.queryParameters.containsKey('code') ||
                uri.fragment.contains('access_token='))) {
          callbackProcessed = true;
          // Run after the auth listener is attached, including on a fresh page load.
          await Future<void>.delayed(Duration.zero);
          try {
            await store.cloud!.client.auth.getSessionFromUrl(uri);
          } finally {
            clearAuthCallbackUrl();
          }
        }
        await store.load();
      }
      if (mounted)
        setState(() {
          ready = true;
          loadError = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => loadError = 'Your account records could not be loaded. Check your connection and retry. If this is the first cloud setup, the database setup script must be run first.',
        );
    }
  }

  void alert() {
    if (store.currentUser == null) return;
    for (final n in store.notices) {
      if (notified.add(n.id) && !n.read) showAlert(n.title, n.message);
    }
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    authSubscription?.cancel();
    store.removeListener(alert);
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: MaterialApp(
      title: 'BackyardPay',
      debugShowCheckedModeBanner: false,
      theme: backyardTheme(),
      home: !ready
          ? Scaffold(
              body: Center(
                child: loadError == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(loadError!),
                          ),
                          FilledButton(
                            onPressed: initialize,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              ),
            )
          : recovery
          ? PasswordRecoveryScreen(
              store: store,
              onDone: () => setState(() => recovery = false),
            )
          : const HomeGateway(),
    ),
  );
}

class HomeGateway extends StatelessWidget {
  const HomeGateway({super.key});
  @override
  Widget build(BuildContext context) =>
      StoreScope.of(context).currentUser == null
      ? const SplashScreen()
      : const DashboardScreen();
}

class PasswordRecoveryScreen extends StatefulWidget {
  final AppStore store;
  final VoidCallback onDone;
  const PasswordRecoveryScreen({
    super.key,
    required this.store,
    required this.onDone,
  });
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose your new password',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
              if (error != null)
                Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (password.text != confirmation.text)
                            throw ArgumentError('Passwords do not match.');
                          await widget.store.completePasswordReset(
                            password.text,
                          );
                          if (mounted) widget.onDone();
                        } catch (e) {
                          if (mounted) setState(() => error = errorText(e));
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(busy ? 'Saving…' : 'Save password and sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
