import 'package:flutter/material.dart';

import '../services/alerts.dart';
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
        action('Logout', () async {
          if (await perform(context, store.logout) && context.mounted)
            home(context);
        }, icon: Icons.logout),
        panel(
          const Text(
            'Your rental records are saved to your Supabase account and shared with the relevant landlord or tenant. Payments are recorded here; money transfers take place through your bank or in cash.',
          ),
        ),
      ],
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), notices = store.notices;
    return PageShell(
      title: 'Notifications',
      children: [
        action(
          'Enable browser alerts',
          () => perform(context, () async {
            final message = await enableAlerts();
            if (context.mounted) tell(context, message);
          }),
          icon: Icons.notifications_active_outlined,
        ),
        const Text(
          'Notifications are stored in your account. Browser alerts work while the app is open; these are not SMS or remote push messages.',
        ),
        gap(),
        if (notices.isEmpty) panel(const Text('No notifications yet.')),
        for (final n in notices)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                gap(8),
                Text(n.message),
                gap(8),
                Text(n.createdAt.toLocal().toString().split('.').first),
                if (!n.read)
                  TextButton(
                    onPressed: () =>
                        perform(context, () => store.markRead(n.id)),
                    child: const Text('Mark as read'),
                  )
                else
                  const Text('Read'),
              ],
            ),
          ),
      ],
    );
  }
}
