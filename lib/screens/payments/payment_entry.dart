import '../../data/rent_payment_months.dart';
import 'deposit_payments.dart';
import '../shared/dashboard.dart' show monthLabel;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import 'payments.dart';
import '../rentals/research_records.dart';

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
      final choices = rentPaymentMonths(
        t,
        DateTime.now(),
      ).where((m) => s.expected(t, m) > 0).toList();
      periods.add(
        choices.where((m) => s.outstanding(t, m) > 0).firstOrNull ??
            choices.lastOrNull ??
            periodOf(DateTime.now()),
      );
      allocated.add(
        TextEditingController(
          text: (s.outstanding(t, periods.first) / 100).toStringAsFixed(2),
        ),
      );
    }
    if (p == null && !widget.credit && allocated.isNotEmpty)
      amount.text = allocated.first.text;
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
            'You selected the same month twice. Enter its total in one row.',
          );
        splits.add({'period': periods[i], 'amountCents': cents});
        sum += cents;
      }
      final p = widget.paymentId == null ? null : s.payment(widget.paymentId!);
      final limit = widget.credit ? p!.creditCents : parseMoney(amount.text);
      if (sum > limit)
        throw ArgumentError(
          'The amounts entered for the months are more than the payment. Reduce them.',
        );
      if (owner && !received)
        throw ArgumentError(
          'Tick the box to confirm that you received the money and checked which months it covers.',
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
      onChanged: (_) {
        if (c == amount &&
            periods.length == 1 &&
            widget.paymentId == null &&
            !widget.credit)
          allocated.first.text = amount.text;
        setState(() {});
      },
      validator: optional ? null : requiredField,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        t = s.tenancy(widget.tenancyId),
        owner = s.currentUser!.role == Role.landlord;
    final months = rentPaymentMonths(
      t,
      DateTime.now(),
    ).where((m) => s.expected(t, m) > 0).toList();
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
          ? 'Choose rent months'
          : p != null
          ? 'Check and confirm payment'
          : owner
          ? 'Record money received'
          : 'Report a payment',
      maxWidth: 800,
      children: [
        if (!owner && p == null && !widget.credit)
          PaymentPurpose(tenancyId: t.id, deposit: false),
        panel(
          Text(
            widget.credit
                ? 'Choose which rent months this money covers. The money has already been received; this does not record another payment.'
                : owner
                ? 'Record cash or bank money you have received. BackyardPay does not transfer money.'
                : 'Already paid by cash or bank? Tell your landlord here. They will check and confirm it.',
          ),
        ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.credit) ...[
                field(
                  amount,
                  owner
                      ? 'Amount received (rand)'
                      : 'How much did you pay? (rand)',
                  edit: p == null,
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'How was it paid?',
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
                field(date, 'Date paid (YYYY-MM-DD)', edit: p == null),
                if (!['Cash', 'Other'].contains(method))
                  field(
                    bank,
                    'Bank payment reference (from your banking app)',
                    edit: p == null,
                  ),
                ExpansionTile(
                  title: const Text('Payment details (optional)'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    field(
                      payer,
                      'Name of the person who paid',
                      edit: p == null,
                    ),
                    field(reference, 'Payment record number', edit: false),
                  ],
                ),
              ] else
                panel(
                  Text(
                    'Money received but not yet linked to a month: ${money(p!.creditCents)}',
                  ),
                ),
              gap(16),
              heading(
                owner
                    ? 'Which month does this payment cover?'
                    : 'Which month did you pay for?',
              ),
              Text(
                !owner && p == null && !widget.credit
                    ? 'Choose the rent month. For a deposit, select Security deposit above.'
                    : 'Choose the rent month this money covers.',
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
                            labelText: 'Month paid for',
                          ),
                          items: months
                              .where(
                                (m) => m == periods[i] || !periods.contains(m),
                              )
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    '${monthLabel(m)}${s.outstanding(t, m) == 0 ? ' (paid)' : ''}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                  periods[i] = v!;
                                  if (p == null &&
                                      !widget.credit &&
                                      periods.length == 1) {
                                    final due = (s.outstanding(t, v) / 100)
                                        .toStringAsFixed(2);
                                    amount.text = due;
                                    allocated[i].text = due;
                                  }
                                }),
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
                            labelText: 'Amount for this month (rand)',
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
                        tooltip: 'Remove ${monthLabel(periods[i])}',
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
              if (months.any((m) => !periods.contains(m)))
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
                  label: const Text('Paying for another month? Add it'),
                ),
              if (remaining != null && remaining != 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    remaining < 0
                        ? 'The month amounts are more than the payment. Reduce them.'
                        : remaining == 0
                        ? ''
                        : '${money(remaining)} of this payment is not yet linked to a month.',
                    style: const TextStyle(color: Palette.goldLight),
                  ),
                ),
              field(
                notes,
                widget.credit
                    ? 'Explain which months this money is for'
                    : owner
                    ? 'Payment note (optional)'
                    : 'Anything else to tell the landlord? (optional)',
                optional: !widget.credit,
                multiline: true,
              ),
              if (owner)
                CheckboxListTile(
                  value: received,
                  onChanged: busy ? null : (v) => setState(() => received = v!),
                  title: const Text(
                    'I received this money and checked which rent months it covers.',
                  ),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Palette.red)),
              action(
                busy
                    ? 'Saving…'
                    : widget.credit
                    ? 'Save chosen months'
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
