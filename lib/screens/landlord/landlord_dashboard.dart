import '../payments/deposit_reminder_notice.dart';
import '../payments/deposit_payments.dart';
import '../rentals/simple_rentals.dart';

import 'dart:math' as math;

import '../../data/room_availability.dart';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import '../payments/payments.dart';
import '../properties/properties.dart';
import '../rentals/research_records.dart';

import '../shared/shared_dashboard.dart';
import '../shared/dashboard_widgets.dart';
import 'tenants_page.dart';

class LandlordDashboardScreen extends StatelessWidget {
  const LandlordDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => DashboardLayout(
    role: Role.landlord,
    contentBuilder: (context, period) {
      final s = StoreScope.of(context), ts = s.tenancies;
      final expected = ts.fold(0, (sum, t) => sum + s.expected(t, period));
      final collected = ts.fold(0, (sum, t) => sum + s.collected(t, period));
      final pending = s.payments
          .where((p) => p.state == ReviewState.pending)
          .toList();
      final deposits = s.depositPaymentReports
          .where((r) => r['state'] == 'pending')
          .length;
      final occupied = ts.where(s.isOccupied).length;
      final total = s.properties.fold(0, (sum, p) => sum + p.rooms);
      final available = s.properties.fold(
        0,
        (sum, p) => sum + availableRoomsFor(p, ts, DateTime.now()).length,
      );
      return [
        dashboardTotals([
          MetricCard(
            label: 'Rent received',
            value: money(collected),
            icon: Icons.account_balance_wallet_outlined,
            caption: monthLabel(period),
          ),
          MetricCard(
            label: 'Rent still due',
            value: money(math.max(0, expected - collected)),
            icon: Icons.schedule,
            caption: 'Expected ${money(expected)}',
          ),
          MetricCard(
            label: 'Available rooms',
            value: '$available',
            icon: Icons.meeting_room_outlined,
            caption: '$occupied of $total occupied',
          ),
        ]),
        gap(20),
        if (s.properties.isEmpty) ...[
          heading('Add your first property'),
          const Text('Then add rooms and invite your tenants.'),
          action('Add property', () => editProperty(context)),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: action(
              'Add tenant record',
              () => createTenantRecord(context),
              icon: Icons.person_add_outlined,
            ),
          ),
        if (pending.isNotEmpty || deposits > 0) ...[
          heading('Payments to check'),
          if (deposits > 0)
            dashboardLink(
              context,
              'Deposit payments to check ($deposits)',
              Icons.savings_outlined,
              () => open(context, const DepositReportsOverview()),
            ),
          for (final p in pending.take(3))
            dashboardLink(
              context,
              '${s.tenantAccount(s.tenancy(p.tenancyId)).name} · ${money(p.amountCents)}',
              Icons.schedule,
              () => open(context, PaymentDetailsScreen(paymentId: p.id)),
              subtitle: 'Rent · ${p.method} · Waiting for confirmation',
            ),
        ],
        panel(
          Column(
            children: [
              dashboardLink(
                context,
                'Payment records',
                Icons.receipt_long_outlined,
                () => open(context, const PaymentsScreen()),
                subtitle: pending.isEmpty
                    ? 'Payments and receipts'
                    : '${pending.length} waiting for confirmation',
              ),
              dashboardLink(
                context,
                'My tenants',
                Icons.people_outline,
                () => open(context, const TenantsScreen()),
                subtitle: '${ts.length} rental records',
              ),
              dashboardLink(
                context,
                'My properties',
                Icons.apartment_outlined,
                () => open(context, const PropertiesScreen()),
                subtitle: '${s.properties.length} properties',
              ),
              dashboardLink(
                context,
                'Tenant reports',
                Icons.chat_bubble_outline,
                () => open(context, const SimpleReportsScreen()),
              ),
            ],
          ),
        ),
        if (s.researchReady) const DepositReminderOverview(),
      ];
    },
  );
}
