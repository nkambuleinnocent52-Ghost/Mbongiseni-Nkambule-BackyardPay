import 'package:flutter/material.dart';

export 'notifications_screen.dart' show NotificationsScreen;
import 'common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), user = store.currentUser;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    return PageShell(
      title: 'My profile',
      children: [
        heading(user.name),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Email', user.email),
              if (user.loginId != null)
                detail(
                  'Login ID',
                  user.loginId!.replaceAllMapped(
                    RegExp(r'([0-9]{3})([0-9]{3})([0-9]{3})'),
                    (m) => '${m[1]} ${m[2]} ${m[3]}',
                  ),
                ),
              if (user.loginId != null)
                const Text(
                  'Use your email or Login ID with the same password.',
                ),
              detail('Phone', user.phone),
              detail('Role', user.role.name),
            ],
          ),
        ),
        action(
          'Edit profile',
          () => open(
            context,
            EditorPage(
              title: 'Edit profile',
              fields: [
                FieldSpec('name', 'Full name', initial: user.name),
                FieldSpec('phone', 'Phone', initial: user.phone),
              ],
              save: (v) => store.updateProfile(v['name']!, v['phone']!),
            ),
          ),
          icon: Icons.edit_outlined,
        ),
        action(
          'Change password',
          () => open(
            context,
            EditorPage(
              title: 'Change password',
              fields: const [
                FieldSpec('old', 'Current password', secret: true),
                FieldSpec('new', 'New password', secret: true),
                FieldSpec('confirm', 'Confirm new password', secret: true),
              ],
              save: (v) async {
                if (v['new'] != v['confirm'])
                  throw ArgumentError('Passwords do not match.');
                await store.changePassword(v['old']!, v['new']!);
              },
            ),
          ),
          icon: Icons.lock_outline,
        ),
        panel(
          const Text(
            'Your records are shared only with the landlord or tenant linked to your rental.',
          ),
        ),
      ],
    );
  }
}
