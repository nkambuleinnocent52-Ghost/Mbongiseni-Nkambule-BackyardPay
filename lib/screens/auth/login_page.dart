import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../shared/common.dart';
import '../../ui/design.dart';

import 'password_reset_request.dart';

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
