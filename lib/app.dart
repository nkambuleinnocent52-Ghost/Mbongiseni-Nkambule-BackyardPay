import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cloud_gateway.dart';

import 'data/store.dart';
import 'screens/common.dart';
import 'screens/auth.dart';
import 'screens/dashboard.dart';
import 'services/alerts.dart';
import 'services/auth_callback.dart';
import 'ui/design.dart';

import 'screens/password_recovery.dart';

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
