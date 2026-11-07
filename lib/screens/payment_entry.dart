import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/design.dart';
import 'common.dart';
import 'payments.dart';
import 'research_records.dart';

class ResearchPaymentEntry extends StatefulWidget {
  final String tenancyId;
  final String? paymentId;
  final bool credit;
  const ResearchPaymentEntry({
    super.key,
    required this.tenancyId,
    this.paymentId,
    this.credit = false,
  });
  @override
  State<ResearchPaymentEntry> createState() => _ResearchPaymentEntryState();
}

class _ResearchPaymentEntryState extends State<ResearchPaymentEntry> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      payer = TextEditingController(),
      reference = TextEditingController(),
      bank = TextEditingController(),
      notes = TextEditingController(),
      date = TextEditingController();
  final periods = <String>[], allocated = <TextEditingController>[];
  bool ready = false, busy = false, received = false;
  String method = 'Cash';
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    final s = StoreScope.of(context),
        t = s.tenancy(widget.tenancyId),
        p = widget.paymentId == null ? null : s.payment(widget.paymentId!);
    amount.text =
        ((p?.amountCents ?? s.outstanding(t, periodOf(DateTime.now()))) / 100)
            .toStringAsFixed(2);
    payer.text = p?.payer.isNotEmpty == true
        ? p!.payer
        : s.tenantAccount(t).name;
    reference.text = p?.reference ?? s.newReference;
    bank.text = p?.bankReference ?? '';
    notes.text = p?.notes ?? '';
    date.text = isoDay(p?.paidOn ?? DateTime.now());
    method = p?.method ?? 'Cash';
    if (p != null && !widget.credit) {
      for (final a in p.splits) {
        periods.add(a.period);
        allocated.add(
          TextEditingController(text: (a.amountCents / 100).toStringAsFixed(2)),
        );
      }
    } else if (!widget.credit) {
      periods.add(periodOf(DateTime.now()));
      allocated.add(
        TextEditingController(
          text: (s.outstanding(t, periods.first) / 100).toStringAsFixed(2),
        ),
      );
    }
    ready = true;
  }

  @override
  void dispose() {
    for (final c in [amount, payer, reference, bank, notes, date, ...allocated])
      c.dispose();
    super.dispose();
  }

  int centsOrZero(String v) =>
      RegExp(r'^0(?:\.0{1,2})?$').hasMatch(v.trim()) ? 0 : parseMoney(v);
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = StoreScope.of(context),
          owner = s.currentUser!.role == Role.landlord;
      final splits = <Map<String, dynamic>>[];
      final seen = <String>{};
      var sum = 0;
      for (var i = 0; i < periods.length; i++) {
        final cents = centsOrZero(allocated[i].text);
        if (cents == 0) continue;
        if (!seen.add(periods[i]))
          throw ArgumentError(
            'Combine allocations for the same month into one row.',
          );
        splits.add({'period': periods[i], 'amountCents': cents});
        sum += cents;
      }
      final p = widget.paymentId == null ? null : s.payment(widget.paymentId!);
      final limit = widget.credit ? p!.creditCents : parseMoney(amount.text);
      if (sum > limit)
        throw ArgumentError('Allocations exceed the amount available.');
      if (owner && !received)
        throw ArgumentError(
          'Confirm you checked receipt of the money and this allocation.',
        );
      dynamic id;
      if (widget.credit) {
        await s.researchAction('allocate_credit', {
          'id': p!.id,
          'allocations': splits,
          'reason': notes.text,
        });
        id = p.id;
      } else if (p != null) {
        await s.researchAction('review', {
          'id': p.id,
          'confirm': true,
          'allocations': splits,
        });
        id = p.id;
      } else {
        checkedDate(date.text);
        id = await s.researchAction('payment', {
          'tenancyId': widget.tenancyId,
          'amountCents': limit,
          'method': method,
          'paidOn': date.text,
          'reference': reference.text,
          'bankReference': bank.text,
          'notes': notes.text,
          'payer': payer.text,
          'received': owner && received,
          'allocations': splits,
        });
      }
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentDetailsScreen(paymentId: id as String),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool optional = false,
    bool edit = true,
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: c,
      enabled: !busy && edit,
      decoration: InputDecoration(labelText: label),
      maxLines: multiline ? 3 : 1,
      validator: optional ? null : requiredField,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        t = s.tenancy(widget.tenancyId),
        owner = s.currentUser!.role == Role.landlord;
    final months = s
        .ledger(t)
        .where((r) => r.chargedCents > 0)
        .map((r) => r.period)
        .toList();
    for (final p in periods) {
      if (!months.contains(p)) months.add(p);
    }
    months.sort();
    final p = widget.paymentId == null ? null : s.payment(widget.paymentId!);
    int? remaining;
    try {
      remaining =
          (widget.credit ? p!.creditCents : parseMoney(amount.text)) -
          allocated.fold(0, (sum, c) => sum + centsOrZero(c.text));
    } catch (_) {}
    return PageShell(
      title: widget.credit
          ? 'Allocate recorded credit'
          : p != null
          ? 'Review money and allocation'
          : owner
          ? 'Record money received'
          : 'Report a payment',
      maxWidth: 800,
      children: [
        panel(
          Text(
            widget.credit
                ? 'This allocates money already received. It does not create a new payment or replace its original receipt.'
                : owner
                ? 'Check the actual cash or beneficiary bank transaction. Record money already received, its actual payer and its allocations. This issues a landlord receipt; BackyardPay does not move or bank-verify money.'
                : 'Pay through your usual bank or cash arrangement, then report the payment here. Your report awaits landlord reconciliation; it is not evidence that the landlord has not received the money.',
          ),
        ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.credit) ...[
                field(amount, 'Amount (rand)', edit: p == null),
                field(
                  payer,
                  'Actual payer (may differ from tenant)',
                  edit: p == null,
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items:
                      [
                            'Cash',
                            'Cash deposit',
                            'EFT',
                            'PayShap',
                            'Debit order',
                            'Other',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: busy || p != null
                      ? null
                      : (v) => setState(() => method = v!),
                ),
                field(
                  date,
                  'Actual payment date (YYYY-MM-DD)',
                  edit: p == null,
                ),
                if (!['Cash', 'Other'].contains(method))
                  field(
                    bank,
                    'Bank transaction reference (not a PIN)',
                    edit: p == null,
                  ),
                field(reference, 'Unique record reference', edit: p == null),
              ] else
                panel(
                  Text(
                    'Unallocated credit available: ${money(p!.creditCents)}',
                  ),
                ),
              gap(16),
              heading('Allocate to rental charges'),
              const Text(
                'One payment may cover several months. Any remainder stays as unallocated credit. Leave all allocations at zero if the purpose needs clarification. Deposits are recorded separately in the Security deposit section of rental details. If one bank transfer covers both, enter only its rent portion here and its deposit portion there, using the same actual bank transaction reference. Do not record the full transfer twice.',
              ),
              gap(12),
              for (var i = 0; i < periods.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey('allocation-month-$i-${periods[i]}'),
                          initialValue: periods[i],
                          decoration: const InputDecoration(
                            labelText: 'Rental month',
                          ),
                          items: months
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => periods[i] = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: allocated[i],
                          enabled: !busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Allocation ${i + 1} (rand)',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            try {
                              centsOrZero(v ?? '');
                              return null;
                            } catch (e) {
                              return errorText(e);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove allocation ${i + 1}',
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                periods.removeAt(i);
                                allocated.removeAt(i).dispose();
                              }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              if (months.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          periods.add(
                            months.firstWhere(
                              (m) => !periods.contains(m),
                              orElse: () => months.first,
                            ),
                          );
                          allocated.add(TextEditingController(text: '0.00'));
                        }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another rental month'),
                ),
              if (remaining != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${owner ? 'Remaining unallocated credit' : 'Proposed unallocated amount'}: ${money(math.max(0, remaining))}',
                    style: const TextStyle(color: Palette.goldLight),
                  ),
                ),
              field(
                notes,
                widget.credit
                    ? 'Allocation explanation'
                    : 'Notes / payment purpose (optional)',
                optional: !widget.credit,
                multiline: true,
              ),
              if (owner)
                CheckboxListTile(
                  value: received,
                  onChanged: busy ? null : (v) => setState(() => received = v!),
                  title: const Text(
                    'I checked the money received and the allocation. This is my confirmation, not bank verification.',
                  ),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Palette.red)),
              action(
                busy
                    ? 'Saving…'
                    : widget.credit
                    ? 'Allocate existing credit'
                    : p != null
                    ? 'Confirm received'
                    : owner
                    ? 'Save received payment'
                    : 'Submit payment',
                busy ? null : save,
                icon: Icons.save_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
