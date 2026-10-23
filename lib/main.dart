import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/common.dart';
import 'screens/auth.dart';
import 'screens/dashboard.dart';
import 'services/alerts.dart';
import 'ui/design.dart';

export 'screens/auth.dart' show SplashScreen, UserTypeScreen;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BackyardPayApp());
}

class BackyardPayApp extends StatefulWidget {
  final AppStore? store;
  const BackyardPayApp({super.key, this.store});
  @override
  State<BackyardPayApp> createState() => _BackyardPayAppState();
}

class _BackyardPayAppState extends State<BackyardPayApp> {
  late final AppStore store = widget.store ?? AppStore(PreferencesStorage());
  bool ready = false;
  String? loadError;
  final Set<String> notified = {};
  @override
  void initState() {
    super.initState();
    store.addListener(alert);
    initialize();
  }

  Future<void> initialize() async {
    try {
      if (widget.store == null) await store.load();
      if (mounted)
        setState(() {
          ready = true;
          loadError = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => loadError = 'Your saved data could not be opened. It has not been erased. Check browser storage access and retry.',
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
