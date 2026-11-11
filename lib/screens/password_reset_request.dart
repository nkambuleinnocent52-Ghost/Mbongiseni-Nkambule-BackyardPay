import 'package:flutter/material.dart';

import 'common.dart';

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
