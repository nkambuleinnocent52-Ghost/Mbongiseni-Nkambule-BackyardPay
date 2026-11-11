import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import '../payments/payment_entry.dart';
import '../payments/payments.dart';
import '../properties/properties.dart';
import 'rental_account.dart';
import 'research_records.dart' show isoDay;

import 'rental_forms.dart';
import 'deposit_summary.dart';
import 'move_out.dart';
import 'reports.dart';

class SimpleRentalDetails extends StatelessWidget {
  final String tenancyId;
  const SimpleRentalDetails({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        t = s.tenancy(tenancyId),
        p = s.property(t.propertyId),
        tenant = s.tenantAccount(t);
    final owner = s.currentUser!.role == Role.landlord;
    final rate = s.research.rate(t, periodOf(DateTime.now()));
    final rows = s.ledger(t);
    return PageShell(
      title: 'Rental details',
      maxWidth: 900,
      children: [
        heading('${tenant.name} · Room ${t.room}'),
        Text(
          '${p.name} · ${p.fullAddress}',
          style: const TextStyle(color: Palette.muted),
        ),
        gap(20),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail(
                'Monthly rent',
                money(rate?['amountCents'] ?? t.rentCents),
              ),
              detail(
                'Rent balance',
                money(rows.isEmpty ? 0 : rows.last.closingBalanceCents),
              ),
              detail(
                'Move-in date',
                t.record['tenancyStartedOn'] ?? '${t.startPeriod}-01',
              ),
              detail(
                'Room status',
                t.endedOn == null
                    ? 'Occupied'
                    : 'Returned ${isoDay(t.endedOn!)}',
              ),
              if (owner)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () =>
                        open(context, ResearchPaymentEntry(tenancyId: t.id)),
                    icon: const Icon(Icons.add),
                    label: const Text('Record money received'),
                  ),
                ),
              const Text(
                'Cash or bank payment. Record only money actually received; bank transfers must be checked against your bank records.',
                style: TextStyle(color: Palette.muted, fontSize: 12),
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () =>
                        open(context, PaymentsScreen(tenancyId: t.id)),
                    child: const Text('Payment history'),
                  ),
                  TextButton(
                    onPressed: () =>
                        open(context, RentalAccountScreen(tenancyId: t.id)),
                    child: const Text('Monthly account'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (owner && t.userId.isEmpty)
          RentalSection(
            title: 'Invite this tenant',
            subtitle: 'Their room is already assigned',
            children: [
              const Text(
                'Share this private invitation only with this tenant. They use it once to create their login.',
              ),
              gap(12),
              SelectableText(t.invitation ?? 'Unavailable'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: t.invitation?.startsWith('JOIN-') == true
                      ? () => perform(
                          context,
                          () => Clipboard.setData(
                            ClipboardData(text: t.invitation!),
                          ),
                          success: 'Invitation copied.',
                        )
                      : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy invitation'),
                ),
              ),
            ],
          ),
        if (s.researchReady) ...[
          DepositSummary(tenancyId: t.id),
          RentalSection(
            title: 'Reported problems',
            subtitle: 'Write an issue or check its acknowledgement',
            children: [SimpleReports(tenancyId: t.id)],
          ),
          RentalSection(
            title: 'Monthly rent',
            subtitle: 'Due on the 1st · agreed changes and dates',
            children: [
              if (owner && t.endedOn == null)
                InlineRentalForm(
                  fields: const {
                    'period': 'Effective month (YYYY-MM)',
                    'amount': 'New monthly rent (rand)',
                    'evidence': 'Agreed change / notice reference',
                  },
                  initial: {
                    'period': periodOf(
                      DateTime(DateTime.now().year, DateTime.now().month + 1),
                    ),
                  },
                  label: 'Save rent change',
                  save: (v, id) async {
                    periodDate(v['period']!);
                    await s.researchAction('rent_term', {
                      'tenancyId': t.id,
                      'period': v['period'],
                      'amountCents': parseMoney(v['amount']!),
                      'dueDay': 1,
                      'evidence': v['evidence'],
                    });
                  },
                ),
              gap(16),
              const Text(
                'Rent changes',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final r
                  in s.rentTerms.where((r) => r['tenancyId'] == t.id).toList()
                    ..sort(
                      (a, b) => (b['period'] as String).compareTo(a['period']),
                    ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${r['period']} · ${money(r['amountCents'])} / month',
                  ),
                  subtitle: Text(r['evidence'] ?? 'Agreed rent'),
                ),
              const Text(
                'Changes apply from a future month. Earlier rent and payments stay unchanged.',
                style: TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ],
          ),
        ],
        RentalSection(
          title: 'Contact and agreement',
          subtitle: 'Tenant, landlord and agreed responsibilities',
          children: [
            detail('Tenant', '${tenant.name} · ${tenant.phone}'),
            detail(
              'Landlord',
              '${s.landlordFor(t).name} · ${s.landlordFor(t).phone}',
            ),
            detail('Due day', '${rate?['dueDay'] ?? t.dueDay} of each month'),
            if (t.utilities.isNotEmpty)
              detail('Water and electricity', t.utilities),
            if (t.houseRules.isNotEmpty)
              detail('House rules / notice', t.houseRules),
            if (owner)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      open(context, AgreementEditor(tenancyId: t.id)),
                  child: const Text('Edit agreement details'),
                ),
              ),
            TextButton(
              onPressed: () =>
                  open(context, PropertyDetailsScreen(propertyId: p.id)),
              child: const Text('Property and location'),
            ),
            const Text(
              'This record is not a signed lease.',
              style: TextStyle(color: Palette.muted, fontSize: 12),
            ),
          ],
        ),
        if (owner && s.researchReady)
          RentalSection(
            title: 'Move-out',
            subtitle: t.endedOn == null
                ? 'Record only when the room and keys have been returned'
                : 'Room returned on ${isoDay(t.endedOn!)}',
            children: [
              if (t.endedOn == null)
                MoveOut(tenancyId: t.id)
              else
                const Text(
                  'Rental ended. Existing balances and deposit records are retained.',
                ),
            ],
          ),
      ],
    );
  }
}
