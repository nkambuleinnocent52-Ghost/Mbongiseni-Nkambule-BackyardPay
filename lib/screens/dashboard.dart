import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';
import 'payments.dart';
import 'properties.dart';
import 'profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String period = periodOf(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), user = store.currentUser;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final ts = store.tenancies;
    final expected = ts.fold(0, (sum, t) => sum + store.expected(t, period));
    final collected = ts.fold(0, (sum, t) => sum + store.collected(t, period));
    final pending = store.payments
        .where((p) => p.state == ReviewState.pending)
        .length;
    final unread = store.notices.where((n) => !n.read).length;
    return PageShell(
      title: '${user.role == Role.landlord ? 'Landlord' : 'Tenant'} dashboard',
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => open(context, const ProfileScreen()),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      children: [
        heading('Hello, ${user.name}'),
        const Text('Your rental records, in one place.'),
        gap(),
        MonthSelector(
          period: period,
          onChanged: (value) => setState(() => period = value),
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Expected rent', money(expected)),
              detail('Confirmed collections', money(collected)),
              detail(
                'Outstanding',
                money((expected - collected).clamp(0, expected)),
              ),
              detail('Payments awaiting review', '$pending'),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (user.role == Role.tenant && ts.isNotEmpty)
              action(
                'Record payment',
                () => open(context, PaymentFormScreen(tenancyId: ts.first.id)),
                icon: Icons.add_card,
              ),
            action(
              user.role == Role.landlord
                  ? 'Payment records'
                  : 'Payment history',
              () => open(context, const PaymentsScreen()),
              icon: Icons.receipt_long_outlined,
            ),
            action(
              'Notifications ($unread)',
              () => open(context, const NotificationsScreen()),
              icon: Icons.notifications_outlined,
            ),
            action(
              'Profile',
              () => open(context, const ProfileScreen()),
              icon: Icons.person_outline,
            ),
            if (user.role == Role.landlord) ...[
              action(
                'My tenants',
                () => open(context, const TenantsScreen()),
                icon: Icons.people_outline,
              ),
              action(
                'My properties',
                () => open(context, const PropertiesScreen()),
                icon: Icons.home_work_outlined,
              ),
            ],
          ],
        ),
        if (user.role == Role.landlord && store.properties.isEmpty)
          panel(
            Column(
              children: [
                heading('Start with your property'),
                const Text(
                  'Create a property to get a code. Share that code with a tenant who registers on this device.',
                ),
                action('Add property', () => editProperty(context)),
              ],
            ),
          ),
        if (ts.isNotEmpty)
          heading(
            user.role == Role.tenant ? 'My rental' : 'Tenancies • $period',
          ),
        for (final t in ts)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${store.tenantAccount(t).name} • Room ${t.room}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                detail('Property', store.property(t.propertyId).name),
                detail('Monthly rent', money(t.rentCents)),
                detail('Status', store.rentStatus(t, period)),
                if (store.overdue(t, period))
                  const Text('Overdue', style: TextStyle(color: Colors.red)),
                action(
                  'Rental details',
                  () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
                ),
              ],
            ),
          ),
        gap(),
        const Text(
          'Records are saved on this browser/device. Pending payments are not included in collections. No money is transferred.',
        ),
      ],
    );
  }
}

class MonthSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  const MonthSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final date = periodDate(period);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () =>
              onChanged(periodOf(DateTime(date.year, date.month - 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          period,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: period.compareTo(periodOf(DateTime.now())) >= 0
              ? null
              : () => onChanged(periodOf(DateTime(date.year, date.month + 1))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});
  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final matches = store.tenancies
        .where(
          (t) =>
              '${store.tenantAccount(t).name} ${t.room} ${store.property(t.propertyId).name}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return PageShell(
      title: 'My tenants',
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search name, room or property',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        gap(),
        const Text(
          'Tenants join by registering with your property code and an available room number.',
        ),
        if (matches.isEmpty) panel(const Text('No tenants match.')),
        for (final t in matches)
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(store.tenantAccount(t).name),
              subtitle: Text(
                'Room ${t.room} • ${store.property(t.propertyId).name}\n${store.rentStatus(t, periodOf(DateTime.now()))}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
            ),
          ),
      ],
    );
  }
}

class TenancyDetailsScreen extends StatelessWidget {
  final String tenancyId;
  const TenancyDetailsScreen({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), t = store.tenancy(tenancyId);
    final user = store.tenantAccount(t),
        p = store.property(t.propertyId),
        period = periodOf(DateTime.now());
    return PageShell(
      title: 'Rental details',
      children: [
        heading(user.name),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Email', user.email),
              detail('Phone', user.phone),
              detail('Property', p.name),
              detail('Room', t.room),
              detail('Monthly rent', money(t.rentCents)),
              detail('Due day', '${t.dueDay} of each month'),
              detail('Tenancy started', t.startPeriod),
              detail('Status', store.rentStatus(t, period)),
              detail(
                'Outstanding for $period',
                money(store.outstanding(t, period)),
              ),
            ],
          ),
        ),
        action(
          'View property and location',
          () => open(context, PropertyDetailsScreen(propertyId: p.id)),
          icon: Icons.location_on_outlined,
        ),
        action(
          'Payment history',
          () => open(context, PaymentsScreen(tenancyId: t.id)),
        ),
        if (store.currentUser!.role == Role.landlord)
          action(
            'Send rent reminder',
            () => reminder(context, t.id, period),
            icon: Icons.notifications_active_outlined,
          ),
      ],
    );
  }
}

void reminder(BuildContext context, String tenancyId, String period) {
  final store = StoreScope.of(context), t = store.tenancy(tenancyId);
  open(
    context,
    EditorPage(
      title: 'Send rent reminder',
      button: 'Send reminder',
      help: 'This creates a notification in the tenant account on this browser/device. It does not send an SMS.',
      fields: [
        FieldSpec('period', 'Rent month (YYYY-MM)', initial: period),
        FieldSpec(
          'message',
          'Message',
          multiline: true,
          initial:
              'Your outstanding rent for $period is ${money(store.outstanding(t, period))}. Please contact your landlord if you need assistance.',
        ),
      ],
      save: (v) =>
          store.sendReminder(tenancyId, v['period']!.trim(), v['message']!),
    ),
  );
}
