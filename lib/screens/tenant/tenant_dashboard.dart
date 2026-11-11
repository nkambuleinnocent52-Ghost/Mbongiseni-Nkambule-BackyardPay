import '../payments/deposit_reminder_notice.dart';
import '../rentals/simple_rentals.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import '../payments/payments.dart';
import '../rentals/rental_account.dart';

import '../shared/shared_dashboard.dart';
import '../shared/dashboard_widgets.dart';
import '../landlord/tenants_page.dart';

class TenantDashboardScreen extends StatelessWidget {
  const TenantDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => DashboardLayout(
    role: Role.tenant,
    contentBuilder: (context, period) {
      final s = StoreScope.of(context), t = s.tenancies.firstOrNull;
      if (t == null)
        return [
          heading('No rental linked'),
          const Text('Ask your landlord for your private invitation.'),
        ];
      final balance = s.outstanding(t, period);
      final pending = s.payments
          .where((p) => p.tenancyId == t.id && p.state == ReviewState.pending)
          .fold(0, (sum, p) => sum + p.amountCents);
      final deposit = s.researchReady
          ? s.research.depositOutstanding(t)
          : t.depositCents == null
          ? null
          : math.max(0, t.depositCents! - (t.depositReceivedCents ?? 0));
      final property = s.property(t.propertyId);
      return [
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${property.name} · Room ${t.room}',
                style: const TextStyle(color: Palette.muted),
              ),
              gap(16),
              const Text('Rent still due'),
              Semantics(
                label: 'Rent still due: ${money(balance)}',
                child: Text(
                  money(balance),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              gap(8),
              Text(
                s.expected(t, period) == 0
                    ? 'No rent charged for ${monthLabel(period)}'
                    : balance == 0
                    ? 'Rent paid for ${monthLabel(period)}'
                    : 'Due ${dateLabel(s.dueDate(t, period))}',
              ),
              if (pending > 0)
                Text(
                  '${money(pending)} waiting for your landlord to confirm',
                  style: const TextStyle(color: Palette.goldLight),
                ),
              if (s.totalArrears(t) > 0)
                Text(
                  'Total overdue rent: ${money(s.totalArrears(t))}',
                  style: const TextStyle(color: Palette.red),
                ),
              if (s.creditFor(t) > 0)
                Text('Rent credit to assign: ${money(s.creditFor(t))}'),
              gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: action(
                  'Record payment',
                  () => open(context, PaymentFormScreen(tenancyId: t.id)),
                  icon: Icons.add_card,
                ),
              ),
            ],
          ),
        ),
        DepositReminderNotice(tenancyId: t.id),
        panel(
          Column(
            children: [
              dashboardLink(
                context,
                'Security deposit',
                Icons.savings_outlined,
                () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
                subtitle: deposit == null
                    ? 'Amount not recorded'
                    : deposit == 0
                    ? 'Paid · one-off deposit'
                    : '${money(deposit)} still due · within 10 days of move-in',
              ),
              dashboardLink(
                context,
                'Payment history',
                Icons.receipt_long_outlined,
                () => open(context, const PaymentsScreen()),
              ),
              dashboardLink(
                context,
                'Monthly rental account',
                Icons.calendar_month_outlined,
                () => open(context, RentalAccountScreen(tenancyId: t.id)),
              ),
              dashboardLink(
                context,
                'Report a problem / account query',
                Icons.chat_bubble_outline,
                () => open(context, SimpleReportsScreen(tenancyId: t.id)),
              ),
              dashboardLink(
                context,
                'Rental details',
                Icons.home_outlined,
                () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
              ),
            ],
          ),
        ),
        if (s.researchReady && s.tenancies.every((r) => r.endedOn != null))
          action(
            'Join another rental',
            () => open(
              context,
              EditorPage(
                title: 'Join another rental',
                help: 'Enter the invitation from your new landlord.',
                fields: const [
                  FieldSpec('invitation', 'Private invitation from landlord'),
                ],
                save: (v) async {
                  await s.researchAction('join_rental', {
                    'invitation': v['invitation'],
                  });
                },
              ),
            ),
          ),
        Text(
          'Landlord: ${s.landlordFor(t).name} · ${s.landlordFor(t).phone}',
          style: const TextStyle(color: Palette.muted),
        ),
      ];
    },
  );
}
