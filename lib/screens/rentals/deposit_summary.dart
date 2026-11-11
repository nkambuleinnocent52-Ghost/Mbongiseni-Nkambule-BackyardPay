import '../payments/deposit_reminder_notice.dart';
import '../payments/deposit_payments.dart';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../shared/common.dart';
import 'research_records.dart' show isoDay, checkedDate;

import 'rental_forms.dart';

class DepositSummary extends StatefulWidget {
  final String tenancyId;
  const DepositSummary({super.key, required this.tenancyId});
  @override
  State<DepositSummary> createState() => _DepositSummaryState();
}

class _DepositSummaryState extends State<DepositSummary> {
  bool recording = false, grounds = false;
  String event = 'refund', method = 'Cash';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        t = s.tenancy(widget.tenancyId),
        owner = s.currentUser!.role == Role.landlord;
    final due = s.research.depositOutstanding(t),
        held = s.research.depositBalance(t),
        received = s.research.depositReceived(t);
    final pendingReports = s.depositPaymentReports
        .where((r) => r['tenancyId'] == t.id && r['state'] == 'pending')
        .length;
    final done = due != null && due == 0;
    return RentalSection(
      title: 'Security deposit',
      subtitle:
          '${money(received)} received · ${due == null ? 'Amount not specified' : money(due) + ' still due'}',
      children: [
        DepositReminderNotice(tenancyId: t.id),
        DepositReminderSettings(tenancyId: t.id),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: done,
          onChanged: owner && !done && due != null && pendingReports == 0
              ? (v) => setState(() => recording = v ?? false)
              : null,
          title: Text(
            t.depositCents == 0 ? 'No deposit required' : 'Deposit received',
          ),
          subtitle: const Text('Kept separate from rent.'),
        ),
        if (!owner && due != null && due > 0 && t.endedOn == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  open(context, DepositPaymentScreen(tenancyId: t.id)),
              icon: const Icon(Icons.add_card),
              label: const Text('Report deposit payment'),
            ),
          ),
        if (pendingReports > 0)
          const Text('Deposit payment waiting for landlord confirmation.'),
        DepositReportsList(tenancyId: t.id),
        if (recording && !done) ...[
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              'Cash',
              'EFT',
              'Cash deposit',
              'PayShap',
              'Other',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => method = v!),
          ),
          InlineRentalForm(
            key: ValueKey('deposit-received-$due'),
            fields: const {
              'amount': 'Deposit received (rand)',
              'date': 'Payment date (YYYY-MM-DD)',
              'reference': 'Receipt / bank reference',
            },
            initial: {
              'amount': ((due ?? 0) / 100).toStringAsFixed(2),
              'date': isoDay(DateTime.now()),
            },
            label: 'Confirm deposit received',
            save: (v, id) async {
              checkedDate(v['date']!);
              await s.researchAction('deposit_update', {
                'tenancyId': t.id,
                'eventId': id,
                'body': {
                  'event': 'received',
                  'amountCents': parseMoney(v['amount']!),
                  'date': v['date'],
                  'reference': v['reference'],
                  'method': method,
                  'payer': s.tenantAccount(t).name,
                  'note': 'Deposit payment confirmed by landlord',
                },
              });
              if (mounted) setState(() => recording = false);
            },
          ),
        ],
        gap(12),
        detail('Deposit and interest held', money(held)),
        if (owner && held > 0)
          RentalSection(
            title: 'Return / deduction',
            subtitle: 'Record the amount and reason; the tenant is notified',
            children: [
              DropdownButtonFormField<String>(
                initialValue: event,
                decoration: const InputDecoration(labelText: 'Deposit action'),
                items: const [
                  DropdownMenuItem(
                    value: 'refund',
                    child: Text('Money returned to tenant'),
                  ),
                  DropdownMenuItem(
                    value: 'deduction',
                    child: Text('Supported damage / other deduction'),
                  ),
                  DropdownMenuItem(
                    value: 'interest',
                    child: Text('Interest earned'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  event = v!;
                  grounds = false;
                }),
              ),
              if (event == 'deduction') ...[
                const Text(
                  'Deduct only supported repair costs, not the whole deposit automatically. Return the remaining balance.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: grounds,
                  onChanged: (v) => setState(() => grounds = v ?? false),
                  title: const Text(
                    'I checked the lawful grounds and supporting evidence',
                  ),
                ),
              ],
              InlineRentalForm(
                key: ValueKey('deposit-$event'),
                fields: {
                  'amount': event == 'deduction'
                      ? 'Supported deduction (rand)'
                      : 'Amount (rand)',
                  'date': 'Actual date (YYYY-MM-DD)',
                  'reference': 'Payment / cost reference',
                  'reason': 'Reason / explanation',
                  if (event == 'deduction')
                    'evidence': 'Condition evidence and actual cost details',
                },
                initial: {
                  'date': isoDay(DateTime.now()),
                  if (event == 'refund')
                    'amount': (held / 100).toStringAsFixed(2),
                },
                label: 'Save deposit update',
                save: (v, id) async {
                  checkedDate(v['date']!);
                  if (event == 'deduction' && !grounds)
                    throw StateError('Confirm the grounds and evidence first.');
                  await s.researchAction('deposit_update', {
                    'tenancyId': t.id,
                    'eventId': id,
                    'body': {
                      'event': event,
                      'amountCents': parseMoney(v['amount']!),
                      'date': v['date'],
                      'reference': v['reference'],
                      'note': v['reason'],
                      if (event == 'deduction') ...{
                        'evidence': v['evidence'],
                        'groundsConfirmed': grounds,
                      },
                    },
                  });
                },
              ),
            ],
          ),
        for (final r in s.research.forTenancy(t.id, 'deposit').reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${r['body']['date']} · ${r['body']['event']} · ${money(r['body']['amountCents'])}',
            ),
            subtitle: Text(r['body']['note'] ?? ''),
          ),
      ],
    );
  }
}
