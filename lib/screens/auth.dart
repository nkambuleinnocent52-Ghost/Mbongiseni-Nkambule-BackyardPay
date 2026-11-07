import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';
import '../ui/design.dart';

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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 650 ? 22 : 48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    BrandMark(),
                    SizedBox(width: 14),
                    Text(
                      'BACKYARDPAY',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                gap(40),
                LayoutBuilder(
                  builder: (context, c) {
                    final intro = GoldHero(
                      height: c.maxWidth > 850 ? 560 : 340,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIGITAL RENTAL MANAGEMENT',
                            style: TextStyle(
                              color: Palette.gold,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          gap(24),
                          Text(
                            'Your rental.\nIn perfect order.',
                            style: TextStyle(
                              fontSize: c.maxWidth > 850 ? 52 : 36,
                              fontWeight: FontWeight.w700,
                              height: 1.18,
                              letterSpacing: -1,
                            ),
                          ),
                          gap(22),
                          if (c.maxWidth <= 850) ...[
                            action(
                              'GET STARTED',
                              busy
                                  ? null
                                  : () => open(context, const UserTypeScreen()),
                            ),
                            gap(18),
                          ],
                          const SizedBox(
                            width: 390,
                            child: Text(
                              'Know who has paid. See what is still owed. Keep a clear record for every room and every month.',
                              style: TextStyle(
                                color: Palette.muted,
                                fontSize: 16,
                                height: 1.8,
                              ),
                            ),
                          ),
                          gap(32),
                          const Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              StatusPill('Clear balances'),
                              StatusPill('Confirmed receipts'),
                              StatusPill('Two connected roles'),
                            ],
                          ),
                          gap(32),
                          const Text(
                            'Rental payment recording made simple.',
                            style: TextStyle(
                              color: Palette.goldLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                    final entry = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading('A better place to manage rent'),
                        const Text(
                          'Digital Rental Management',
                          style: TextStyle(color: Palette.muted, height: 1.7),
                        ),
                        gap(22),
                        if (c.maxWidth > 850)
                          action(
                            'GET STARTED',
                            busy
                                ? null
                                : () => open(context, const UserTypeScreen()),
                          ),
                        gap(12),
                        const Text(
                          'Already registered? Choose your role and sign in. New landlords can create a property and invite a tenant with its code.',
                          style: TextStyle(
                            color: Palette.muted,
                            height: 1.8,
                            fontSize: 12,
                          ),
                        ),
                        gap(22),
                        const Divider(),
                        gap(),
                        const Text(
                          'Your records are saved to your account. BackyardPay records payments; it never moves money.',
                          style: TextStyle(
                            color: Palette.muted,
                            fontSize: 11,
                            height: 1.7,
                          ),
                        ),
                      ],
                    );
                    return c.maxWidth > 850
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: intro),
                              const SizedBox(width: 56),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: entry,
                                ),
                              ),
                            ],
                          )
                        : Column(children: [intro, gap(24), panel(entry)]);
                  },
                ),
                gap(30),
                const Text(
                  'BUILT FOR BACKYARD COMMUNITIES. DESIGNED FOR EVERYDAY CLARITY.',
                  style: TextStyle(
                    color: Palette.muted,
                    fontSize: 10,
                    letterSpacing: 1.1,
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
      const Text(
        'YOUR SPACE. YOUR ROLE.',
        style: TextStyle(color: Palette.gold, fontSize: 11, letterSpacing: 2),
      ),
      heading('How will you use the app?'),
      const Text(
        'Choose the workspace that fits your rental journey.',
        style: TextStyle(color: Palette.muted),
      ),
      gap(18),
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
        'The landlord assigns the room first and shares a private invitation. Tenants use that invitation once to create their own login.',
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
    for (final key in ['name', 'email', 'phone', 'password', 'confirm', 'code'])
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
    maxWidth: 600,
    title:
        '${widget.role == Role.landlord ? 'Landlord' : 'Tenant'} ${registration ? 'registration' : 'login'}',
    children: [
      const BrandMark(size: 54),
      gap(16),
      heading(registration ? 'Make yourself at home.' : 'Welcome back.'),
      const Text(
        'Your rental records, connected across your devices.',
        style: TextStyle(color: Palette.muted),
      ),
      gap(20),
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
                const Text(
                  'Your landlord has already assigned your room, move-in date, rent and deposit. Enter the private JOIN- invitation they share with you. You do not choose a room here.',
                ),
                field('code', 'Private invitation from your landlord'),
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
                onPressed: busy
                    ? null
                    : () => open(context, const PasswordResetRequestScreen()),
                child: const Text('Forgot password?'),
              ),
          ],
        ),
      ),
    ],
  );
}

class PasswordResetRequestScreen extends StatefulWidget {
  const PasswordResetRequestScreen({super.key});
  @override
  State<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends State<PasswordResetRequestScreen> {
  final email = TextEditingController();
  bool busy = false, sent = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Reset password',
    maxWidth: 600,
    children: [
      heading('Get back into your account'),
      const Text(
        'Enter your account email. If an account exists, you will receive a password reset link.',
      ),
      gap(20),
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      gap(16),
      if (sent)
        const Text('Check your inbox and spam folder for a reset link.'),
      action(
        busy ? 'Sending…' : 'Send reset link',
        busy
            ? null
            : () async {
                setState(() => busy = true);
                final ok = await perform(
                  context,
                  () => StoreScope.of(context).resetPassword(email.text),
                );
                if (mounted)
                  setState(() {
                    busy = false;
                    sent = ok;
                  });
              },
      ),
    ],
  );
}
