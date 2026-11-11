export 'agreement_editor.dart';
import '../shared/dashboard.dart' show monthLabel;
import 'simple_rentals.dart';

import '../../data/research_ledger.dart';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../../services/receipts.dart';
import '../shared/common.dart';
import '../payments/payments.dart';

class RentalAccountScreen extends StatelessWidget {
  final String tenancyId;
  const RentalAccountScreen({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        t = store.tenancy(tenancyId),
        p = store.property(t.propertyId),
        rows = store.ledger(t);
    final balance = rows.isEmpty ? 0 : rows.last.closingBalanceCents;
    return PageShell(
      title: 'Monthly rental account',
      children: [
        GoldHero(
          height: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A COMPLETE RENTAL HISTORY',
                style: TextStyle(
                  color: Palette.gold,
                  fontSize: 11,
                  letterSpacing: 1.7,
                ),
              ),
              gap(16),
              Text(
                money(balance),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(10),
              const Text(
                'Rent balance before applying money not yet linked to a month',
                style: TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        gap(18),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Tenant', store.tenantAccount(t).name),
              detail('Property', p.name),
              detail('Address', p.fullAddress),
              detail('Room', t.room),
              detail('Base rent', money(t.rentCents)),
              if (store.researchReady) ...[
                detail(
                  'Money received but not yet linked to a month',
                  money(store.creditFor(t)),
                ),
                detail(
                  'Payments waiting for the landlord to check',
                  money(store.pendingFor(t)),
                ),
              ],
              detail('Landlord', store.landlordFor(t).name),
              detail('Account begins', monthLabel(t.startPeriod)),
            ],
          ),
        ),
        const Text(
          'This account shows rent due and confirmed payments for each month. A payment made later can pay off an earlier month. Payments waiting for confirmation are shown separately.',
          style: TextStyle(color: Palette.muted, fontSize: 12, height: 1.8),
        ),
        gap(16),
        action(
          'Download account statement',
          () => perform(context, () async {
            final bytes = await accountStatementPdf(store, t.id);
            await Printing.sharePdf(
              bytes: bytes,
              filename: 'BackyardPay-account-${t.room}.pdf',
            );
          }),
          icon: Icons.download_outlined,
        ),
        if (store.researchReady) ...[
          if (t.record['firstMonthProration'] != null)
            panel(
              Text(
                firstChargeExplanation(
                  t.rentCents,
                  DateTime.parse(t.record['tenancyStartedOn']),
                  t.record['firstMonthProration'] == 'actual_days',
                ),
              ),
            ),
          heading('Dated rent terms'),
          for (final term in store.rentTerms.where(
            (r) => r['tenancyId'] == t.id,
          ))
            panel(
              Text(
                '${term['period']} • ${money(term['amountCents'])} • due day ${term['dueDay']}\n${term['evidence']}',
              ),
            ),
        ],
        gap(12),
        if (rows.isEmpty)
          panel(const Text('No rent has been charged for this tenancy yet.')),
        for (final row in rows.reversed)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        monthLabel(row.period),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    StatusPill(row.status),
                  ],
                ),
                gap(14),
                Wrap(
                  spacing: 28,
                  runSpacing: 10,
                  children: [
                    Text('Recorded charge: ${money(row.chargedCents)}'),
                    Text('Confirmed: ${money(row.confirmedCents)}'),
                    Text(
                      'Recorded balance: ${money(row.outstandingCents)}',
                      style: const TextStyle(color: Palette.goldLight),
                    ),
                  ],
                ),
                gap(12),
                Text(
                  'Pending: ${money(row.pendingCents)}  ·  Running balance: ${money(row.closingBalanceCents)}',
                  style: const TextStyle(
                    color: Palette.muted,
                    fontSize: 12,
                    height: 1.8,
                  ),
                ),
                if (row.overdue)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: StatusPill('Overdue'),
                  ),
                TextButton.icon(
                  onPressed: () => open(
                    context,
                    PaymentsScreen(tenancyId: t.id, initialPeriod: row.period),
                  ),
                  icon: const Icon(Icons.arrow_outward, size: 17),
                  label: const Text('View this month’s payment records'),
                ),
              ],
            ),
          ),
        gap(),
        const Text(
          'Monthly base charges and dated agreed rent changes are shown with documented charge adjustments. Agree and record any partial-month correction. Deposits remain separate. This statement does not decide legal liability.',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.8),
        ),
      ],
    );
  }
}

class RentalDetailsView extends StatelessWidget {
  final String tenancyId;
  const RentalDetailsView({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) =>
      SimpleRentalDetails(tenancyId: tenancyId);
}
