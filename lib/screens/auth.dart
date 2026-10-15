import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.home_work_rounded,
                    size: 64,
                    color: Color(0xFF0A1931),
                  ),
                ),
                gap(24),
                const Text(
                  'BACKYARDPAY',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A1931),
                  ),
                ),
                gap(),
                const Text(
                  'Digital Rental Management',
                  style: TextStyle(fontSize: 20),
                ),
                gap(),
                const Text(
                  'Rental payment recording made simple.',
                  textAlign: TextAlign.center,
                ),
                gap(24),
                action(
                  'GET STARTED',
                  busy ? null : () => open(context, const UserTypeScreen()),
                ),
                gap(),
                panel(
                  const Text(
                    'Student prototype: records payments; does not transfer money. Accounts share data only on this browser/device. Browser data may be cleared by your browser.',
                  ),
                ),
                if (!StoreScope.of(context).hasAccounts)
                  action(
                    busy ? 'Creating demo…' : 'Try with demo accounts',
                    busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            await perform(
                              context,
                              () => StoreScope.of(context).createDemo(),
                              success: 'Demo accounts created. Use the details shown below.',
                            );
                            if (mounted) setState(() => busy = false);
                          },
                    icon: Icons.science_outlined,
                  ),
                panel(
                  const Text(
                    'Optional demo login\nLandlord: landlord@demo.test\nTenant: tenant@demo.test\nPassword for both: DemoPass123!\nUse the matching role when signing in. These logins work only after demo accounts have been created.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class UserTypeScreen extends StatelessWidget {
  const UserTypeScreen({super.key});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Welcome to BackyardPay',
    children: [
      heading('How will you use the app?'),
      for (final role in Role.values)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                role == Role.landlord
                    ? Icons.home_work_rounded
                    : Icons.person_rounded,
                size: 38,
              ),
              action(
                role.name.toUpperCase(),
                () => open(context, AuthScreen(role: role)),
              ),
              Text(
                role == Role.landlord
                    ? 'Manage my rental property'
                    : 'Manage my rental payments',
              ),
            ],
          ),
        ),
      gap(),
      const Text(
        'New here? Create a landlord account and property first, then register your tenant with the property code.',
      ),
    ],
  );
}

class AuthScreen extends StatefulWidget {
  final Role role;
  const AuthScreen({super.key, required this.role});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final controls = {
    for (final key in [
      'name',
      'email',
      'phone',
      'password',
      'confirm',
      'code',
      'room',
    ])
      key: TextEditingController(),
  };
  bool registration = false, busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final store = StoreScope.of(context);
    try {
      if (registration) {
        await store.register(
          name: controls['name']!.text,
          email: controls['email']!.text,
          phone: controls['phone']!.text,
          password: controls['password']!.text,
          role: widget.role,
          code: controls['code']!.text,
          room: controls['room']!.text,
        );
      } else {
        await store.login(
          controls['email']!.text,
          controls['password']!.text,
          widget.role,
        );
      }
      if (mounted) home(context);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    bool secret = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      key: ValueKey(key),
      controller: controls[key],
      enabled: !busy,
      obscureText: secret,
      keyboardType: number
          ? TextInputType.number
          : key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (requiredField(v) != null) return requiredField(v);
        if (key == 'confirm' && v != controls['password']!.text)
          return 'Passwords do not match.';
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PageShell(
    title:
        '${widget.role == Role.landlord ? 'Landlord' : 'Tenant'} ${registration ? 'registration' : 'login'}',
    children: [
      Form(
        key: form,
        child: Column(
          children: [
            if (registration) ...[
              field('name', 'Full name'),
              field('phone', 'Phone number'),
            ],
            field('email', 'Email'),
            field('password', 'Password', secret: true),
            if (registration) ...[
              field('confirm', 'Confirm password', secret: true),
              if (widget.role == Role.tenant) ...[
                field('code', 'Property code from your landlord'),
                field('room', 'Room number', number: true),
              ],
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            action(
              busy
                  ? 'Please wait…'
                  : registration
                  ? 'Create account'
                  : 'Login',
              busy ? null : submit,
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        registration = !registration;
                        error = null;
                        form.currentState?.reset();
                      });
                    },
              child: Text(
                registration
                    ? 'Already registered? Login'
                    : 'Create an account',
              ),
            ),
            if (!registration)
              TextButton(
                onPressed: () => tell(
                  context,
                  'This local prototype has no email reset service. Change your password from Profile while signed in. Keep your demo credentials for rehearsal.',
                ),
                child: const Text('Forgot password?'),
              ),
          ],
        ),
      ),
    ],
  );
}
