import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import '../rentals/rental_account.dart';
import '../rentals/research_records.dart';

import '../shared/dashboard_widgets.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});
  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String query = '', filter = 'All', period = periodOf(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final matches = store.tenancies.where((t) {
      final status = store.rentStatus(t, period),
          pending = store.payments.any(
            (p) =>
                p.tenancyId == t.id &&
                p.splits.any((a) => a.period == period) &&
                p.state == ReviewState.pending,
          );
      return '${store.tenantAccount(t).name} ${t.room} ${store.property(t.propertyId).name}'
              .toLowerCase()
              .contains(query.toLowerCase()) &&
          (filter == 'All' ||
              filter == status ||
              (filter == 'Overdue' && store.overdue(t, period)) ||
              (filter == 'Pending' && pending));
    }).toList();
    return PageShell(
      title: 'My tenants',
      children: [
        if (store.researchReady)
          action('Add tenant record', () => createTenantRecord(context)),
        MonthSelector(
          period: period,
          onChanged: (v) => setState(() => period = v),
        ),
        gap(18),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search name, room or property',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        gap(16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in [
              'All',
              'Paid',
              'Partially paid',
              'Outstanding',
              'Overdue',
              'Pending',
            ])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        gap(18),
        Text(
          '${matches.length} tenants · ${monthLabel(period)}',
          style: const TextStyle(color: Palette.muted, fontSize: 12),
        ),
        gap(10),
        if (matches.isEmpty)
          panel(const Text('No tenants match these filters.')),
        for (final t in matches)
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF302817),
                foregroundColor: Palette.gold,
                child: Text(
                  store.tenantAccount(t).name.substring(0, 1).toUpperCase(),
                ),
              ),
              title: Text(store.tenantAccount(t).name),
              subtitle: Text(
                'Room ${t.room} · ${store.property(t.propertyId).name}\n${store.rentStatus(t, period)} · ${money(store.outstanding(t, period))} outstanding',
              ),
              trailing: const Icon(Icons.arrow_forward, size: 18),
              isThreeLine: true,
              onTap: () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
            ),
          ),
        gap(16),
        const Text(
          'Assign an available room first. Share the rental’s private invitation so the tenant can create their login.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class TenancyDetailsScreen extends StatelessWidget {
  final String tenancyId;
  const TenancyDetailsScreen({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) => RentalDetailsView(tenancyId: tenancyId);
}

void reminder(BuildContext context, String tenancyId, String period) {
  final store = StoreScope.of(context), t = store.tenancy(tenancyId);
  open(
    context,
    EditorPage(
      title: 'Send rent reminder',
      button: 'Send reminder',
      help: 'A notification is delivered to this tenant’s account. No SMS is sent.',
      fields: [
        FieldSpec('period', 'Rent month (YYYY-MM)', initial: period),
        FieldSpec(
          'message',
          'Message',
          multiline: true,
          initial: store.outstanding(t, period) > 0
              ? 'Your remaining rent for ${monthLabel(period)} is ${money(store.outstanding(t, period))}, due ${dateLabel(store.dueDate(t, period))}. Please contact your landlord if you need assistance.'
              : 'Your rent for ${monthLabel(period)} is fully paid. Thank you. Please keep your confirmed receipt.',
        ),
      ],
      save: (v) =>
          store.sendReminder(tenancyId, v['period']!.trim(), v['message']!),
    ),
  );
}
