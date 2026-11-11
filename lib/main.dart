// Entry point: connect Supabase and start the application.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/cloud_config.dart';
import 'ui/design.dart';

export 'app.dart' show BackyardPayApp, HomeGateway;
export 'screens/auth.dart' show SplashScreen, UserTypeScreen;
export 'screens/password_recovery.dart' show PasswordRecoveryScreen;

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
