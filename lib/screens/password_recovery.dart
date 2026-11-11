import 'package:flutter/material.dart';

import '../data/store.dart';
import 'common.dart';

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
