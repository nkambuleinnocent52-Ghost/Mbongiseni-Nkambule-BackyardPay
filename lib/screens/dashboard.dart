import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../data/store.dart';
import '../ui/design.dart';
import 'common.dart';
import 'payments.dart';
import 'properties.dart';
import 'profile.dart';
import 'rental_account.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String monthLabel(String period) {
  final d = periodDate(period);
  return '${_monthNames[d.month - 1]} ${d.year}';
}

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month - 1]} ${d.year}';

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
    final owner = user.role == Role.landlord, ts = store.tenancies;
    final expected = ts.fold(0, (sum, t) => sum + store.expected(t, period));
    final collected = ts.fold(0, (sum, t) => sum + store.collected(t, period));
    final pending = store.payments
        .where((p) => p.period == period && p.state == ReviewState.pending)
        .toList();
    final unread = store.notices.where((n) => !n.read).length;
    final balance = math.max(0, expected - collected), first = ts.firstOrNull;
    final arrears = ts.fold(0, (sum, t) => sum + store.totalArrears(t));
    final reviewAmount = pending.fold(0, (sum, p) => sum + p.amountCents);
    return PageShell(
      title: owner ? 'Landlord dashboard' : 'Tenant dashboard',
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => open(context, const ProfileScreen()),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner ? 'YOUR PROPERTY PORTFOLIO' : 'YOUR RENTAL WORKSPACE',
                    style: const TextStyle(
                      color: Palette.gold,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  heading('Hello, ${user.name}'),
                  Text(
                    owner
                        ? 'A clear view of every room, every tenant and every rand.'
                        : 'Your home, your payments and your peace of mind.',
                    style: const TextStyle(color: Palette.muted, height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
        gap(22),
        Align(
          alignment: Alignment.centerLeft,
          child: MonthSelector(
            period: period,
            onChanged: (v) => setState(() => period = v),
          ),
        ),
        gap(18),
        GoldHero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owner
                    ? 'CONFIRMED RENT • ${monthLabel(period).toUpperCase()}'
                    : 'REMAINING RENT • ${monthLabel(period).toUpperCase()}',
                style: const TextStyle(
                  color: Palette.goldLight,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              gap(18),
              Text(
                money(owner ? collected : balance),
                style: const TextStyle(
                  fontSize: 43,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              gap(12),
              Text(
                owner
                    ? '${expected == 0 ? 0 : (collected / expected * 100).round()}% of ${money(expected)} expected rent has been confirmed.'
                    : balance == 0 && expected > 0
                    ? 'All settled for this month. Your confirmed receipts are ready.'
                    : '${money(collected)} confirmed · ${money(reviewAmount)} waiting for review',
                style: const TextStyle(
                  color: Palette.muted,
                  height: 1.8,
                  fontSize: 12,
                ),
              ),
              gap(18),
              SizedBox(
                width: 360,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: expected == 0
                        ? 0
                        : (collected / expected).clamp(0, 1),
                    minHeight: 6,
                    color: Palette.gold,
                    backgroundColor: Palette.border,
                  ),
                ),
              ),
              gap(20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusPill(
                    owner
                        ? '${pending.length} awaiting review'
                        : first == null
                        ? 'No rental'
                        : store.rentStatus(first, period),
                  ),
                  if (!owner && first != null)
                    StatusPill(
                      'Due ${dateLabel(store.dueDate(first, period))}',
                    ),
                ],
              ),
            ],
          ),
        ),
        gap(18),
        LayoutBuilder(
          builder: (context, c) {
            final count = c.maxWidth >= 960
                ? 4
                : c.maxWidth >= 320
                ? 2
                : 1;
            final metrics = [
              MetricCard(
                label: owner ? 'Expected rent' : 'Monthly rent',
                value: money(expected),
                icon: Icons.account_balance_wallet_outlined,
                caption: monthLabel(period),
              ),
              Semantics(
                label: 'Outstanding: ${money(balance)}',
                child: MetricCard(
                  label: 'Outstanding',
                  value: money(balance),
                  icon: Icons.pie_chart_outline,
                  caption: 'Pending submissions are not deducted',
                  highlight: balance > 0,
                ),
              ),
              MetricCard(
                label: owner ? 'Arrears across months' : 'Total overdue rent',
                value: money(arrears),
                icon: Icons.history_rounded,
                caption: 'Unpaid rent past its due date',
              ),
              MetricCard(
                label: owner ? 'Occupied rooms' : 'Deposit still due',
                value: owner
                    ? '${ts.where(store.isOccupied).length} / ${store.properties.fold(0, (sum, p) => sum + p.rooms)}'
                    : first?.depositCents == null
                    ? 'Not recorded'
                    : money(
                        first!.depositCents! -
                            (first.depositReceivedCents ?? 0),
                      ),
                icon: owner
                    ? Icons.meeting_room_outlined
                    : Icons.savings_outlined,
                caption: owner
                    ? 'Current occupancy across properties'
                    : 'Kept separate from rent',
              ),
            ];
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final m in metrics)
                  SizedBox(
                    width: (c.maxWidth - 14 * (count - 1)) / count,
                    child: m,
                  ),
              ],
            );
          },
        ),
        gap(24),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (!owner && first != null)
              action(
                'Record payment',
                () => open(context, PaymentFormScreen(tenancyId: first.id)),
                icon: Icons.add_card,
              ),
            action(
              owner ? 'Payment records' : 'Payment history',
              () => open(context, const PaymentsScreen()),
              icon: Icons.receipt_long_outlined,
            ),
            if (!owner && first != null)
              action(
                'Monthly rental account',
                () => open(context, RentalAccountScreen(tenancyId: first.id)),
                icon: Icons.calendar_month_outlined,
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
            if (owner) ...[
              action(
                'My tenants',
                () => open(context, const TenantsScreen()),
                icon: Icons.people_outline,
              ),
              action(
                'My properties',
                () => open(context, const PropertiesScreen()),
                icon: Icons.apartment_outlined,
              ),
            ],
          ],
        ),
        gap(20),
        if (owner) ...[
          LayoutBuilder(
            builder: (context, c) {
              final occupied = store.tenancies.where(store.isOccupied).length,
                  totalRooms = store.properties.fold(
                    0,
                    (sum, p) => sum + p.rooms,
                  );
              final occupancy = panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PORTFOLIO SNAPSHOT',
                      style: TextStyle(
                        color: Palette.gold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    gap(18),
                    detail('Properties', '${store.properties.length}'),
                    detail('Occupied rooms', '$occupied / $totalRooms'),
                    detail(
                      'Available rooms',
                      '${math.max(0, totalRooms - occupied)}',
                    ),
                    detail(
                      'Awaiting review',
                      '${pending.length} payments · ${money(reviewAmount)}',
                    ),
                    detail(
                      'Rental records to complete',
                      '${ts.where((t) => !t.agreementRecorded).length}',
                    ),
                  ],
                ),
              );
              final history = panel(
                _CollectionChart(store: store, period: period),
              );
              return c.maxWidth >= 720
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: history),
                        const SizedBox(width: 18),
                        Expanded(child: occupancy),
                      ],
                    )
                  : Column(children: [history, occupancy]);
            },
          ),
          if (pending.isNotEmpty) ...[
            heading('Needs your attention'),
            for (final p in pending.take(3))
              panel(
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule, color: Palette.gold),
                  title: Text(
                    '${store.tenantAccount(store.tenancy(p.tenancyId)).name} · ${money(p.amountCents)}',
                  ),
                  subtitle: Text(
                    '${p.method} · ${monthLabel(p.period)} · Pending',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () =>
                      open(context, PaymentDetailsScreen(paymentId: p.id)),
                ),
              ),
          ],
          heading('Who has paid?'),
          const Text(
            'Every tenant is included, even when no payment has been submitted.',
            style: TextStyle(color: Palette.muted, fontSize: 12),
          ),
          gap(),
          for (final t in ts) _RentalTile(t: t, period: period),
          if (store.properties.isEmpty)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Start with your property'),
                  const Text(
                    'Add the address and rooms, then share the property code with your tenant.',
                  ),
                  action('Add property', () => editProperty(context)),
                ],
              ),
            ),
        ] else if (first != null) ...[
          heading('My rental'),
          _RentalTile(t: first, period: period),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR RENTAL CONTACT',
                  style: TextStyle(
                    color: Palette.gold,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                gap(12),
                Text(
                  store.landlordFor(first).name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                detail('Phone', store.landlordFor(first).phone),
                detail(
                  'Property',
                  store.property(first.propertyId).fullAddress,
                ),
                if (!first.agreementRecorded)
                  const Text(
                    'Your landlord has not completed the rental terms yet. Open Rental details to see what is recorded.',
                    style: TextStyle(color: Palette.goldLight, height: 1.7),
                  ),
              ],
            ),
          ),
        ],
        gap(24),
        const Text(
          'Only landlord-confirmed payments reduce rent balances. Bank payments are made outside BackyardPay.',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.7),
        ),
      ],
    );
  }
}

class _RentalTile extends StatelessWidget {
  final Tenancy t;
  final String period;
  const _RentalTile({required this.t, required this.period});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), p = store.property(t.propertyId);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store.tenantAccount(t).name} • Room ${t.room}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap(16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              StatusPill(store.rentStatus(t, period)),
              if (store.overdue(t, period)) const StatusPill('Overdue'),
              Text(
                'Balance ${money(store.outstanding(t, period))}',
                style: const TextStyle(color: Palette.goldLight),
              ),
              Text(
                'Rent ${money(t.rentCents)}',
                style: const TextStyle(color: Palette.muted),
              ),
            ],
          ),
          gap(14),
          Text(
            p.fullAddress,
            style: const TextStyle(color: Palette.muted, fontSize: 12),
          ),
          action(
            'Rental details',
            () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
            icon: Icons.arrow_outward,
          ),
        ],
      ),
    );
  }
}

class _CollectionChart extends StatelessWidget {
  final AppStore store;
  final String period;
  const _CollectionChart({required this.store, required this.period});
  @override
  Widget build(BuildContext context) {
    final end = periodDate(period),
        months = [
          for (var i = 5; i >= 0; i--)
            periodOf(DateTime(end.year, end.month - i)),
        ];
    final values = [
      for (final p in months)
        store.tenancies.fold(0, (sum, t) => sum + store.collected(t, p)),
    ];
    final peak = values.fold(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLLECTIONS OVER TIME',
          style: TextStyle(
            color: Palette.gold,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        gap(8),
        const Text(
          'Confirmed rent · last 6 months',
          style: TextStyle(color: Palette.muted, fontSize: 11),
        ),
        gap(24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: Semantics(
                  label:
                      '${monthLabel(months[i])}: ${money(values[i])} confirmed',
                  child: Column(
                    children: [
                      Text(
                        values[i] == 0 ? '—' : money(values[i]),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Palette.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: math.max(5.0, values[i] / peak * 80),
                        width: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: values[i] > 0
                                ? [Palette.goldLight, Palette.gold]
                                : [Palette.border, Palette.border],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _monthNames[periodDate(months[i]).month - 1],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () =>
                onChanged(periodOf(DateTime(date.year, date.month - 1))),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              monthLabel(period),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: period.compareTo(periodOf(DateTime.now())) >= 0
                ? null
                : () =>
                      onChanged(periodOf(DateTime(date.year, date.month + 1))),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }
}

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
                p.period == period &&
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
        heading('Every tenant. A clear balance.'),
        const Text(
          'View the selected month’s rent position, including tenants who have not submitted a payment.',
          style: TextStyle(color: Palette.muted, height: 1.7),
        ),
        gap(20),
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
          'Tenants join using your property code and an available room number.',
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
