import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../services/receipts.dart';
import 'common.dart';
import 'dashboard.dart';

class PaymentFormScreen extends StatefulWidget {
  final String tenancyId;
  const PaymentFormScreen({super.key, required this.tenancyId});
  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      reference = TextEditingController(),
      notes = TextEditingController();
  String period = periodOf(DateTime.now()), method = 'Cash';
  DateTime paidOn = DateTime.now();
  bool initialized = false, busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final store = StoreScope.of(context), t = store.tenancy(widget.tenancyId);
      amount.text = (store.outstanding(t, period) / 100).toStringAsFixed(2);
      reference.text = store.newReference;
      initialized = true;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final store = StoreScope.of(context);
    try {
      final id = await store.submitPayment(
        tenancyId: widget.tenancyId,
        period: period,
        amountCents: parseMoney(amount.text),
        method: method,
        paidOn: paidOn,
        reference: reference.text,
        notes: notes.text,
      );
      if (mounted && ModalRoute.of(context)?.isCurrent == true)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentDetailsScreen(paymentId: id),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), t = store.tenancy(widget.tenancyId);
    final start = periodDate(t.startPeriod), now = DateTime.now();
    final months = <String>[];
    for (
      var m = DateTime(start.year, start.month);
      !m.isAfter(DateTime(now.year, now.month));
      m = DateTime(m.year, m.month + 1)
    ) {
      months.add(periodOf(m));
    }
    return PageShell(
      title: 'Record rent payment',
      children: [
        panel(
          const Text(
            'Record money already paid to your landlord. BackyardPay does not transfer money. Cash, EFT and PayShap all remain pending until reviewed. Partial payments are allowed; overpayments are not.',
          ),
        ),
        Form(
          key: form,
          child: Column(
            children: [
              gap(),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Rent month'),
                items: months.reversed
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => period = v!),
              ),
              gap(),
              TextFormField(
                key: const ValueKey('amount'),
                controller: amount,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Amount (rand)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  try {
                    parseMoney(v ?? '');
                    return null;
                  } catch (e) {
                    return errorText(e);
                  }
                },
              ),
              gap(),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: ['Cash', 'EFT', 'PayShap', 'Other']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => method = v!),
              ),
              gap(),
              ListTile(
                title: Text(
                  'Payment date: ${paidOn.toIso8601String().split('T').first}',
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: paidOn,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null && mounted)
                          setState(() => paidOn = date);
                      },
              ),
              gap(),
              TextFormField(
                key: const ValueKey('reference'),
                controller: reference,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Unique payment reference',
                ),
                validator: requiredField,
              ),
              gap(),
              TextFormField(
                controller: notes,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                maxLines: 3,
              ),
              gap(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              action(
                busy ? 'Submitting…' : 'Submit payment',
                busy ? null : submit,
                icon: Icons.send_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PaymentsScreen extends StatefulWidget {
  final String? tenancyId;
  const PaymentsScreen({super.key, this.tenancyId});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String filter = 'All', period = periodOf(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ps = store.payments
        .where(
          (p) =>
              p.period == period &&
              (widget.tenancyId == null || p.tenancyId == widget.tenancyId) &&
              (filter == 'All' || p.state.name == filter.toLowerCase()),
        )
        .toList();
    return PageShell(
      title: 'Payment records',
      children: [
        MonthSelector(
          period: period,
          onChanged: (v) => setState(() => period = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final f in ['All', 'Pending', 'Confirmed', 'Rejected'])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        gap(),
        if (ps.isEmpty)
          panel(const Text('No payment records for these filters.')),
        for (final p in ps)
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${store.tenantAccount(store.tenancy(p.tenancyId)).name} • ${money(p.amountCents)}',
              ),
              subtitle: Text(
                '${p.period} • ${p.method} • ${p.state.name.toUpperCase()}\n${p.reference}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(context, PaymentDetailsScreen(paymentId: p.id)),
            ),
          ),
        const Text(
          'Missing payments appear as outstanding balances on the dashboard, not as fictional payment records.',
        ),
      ],
    );
  }
}

class PaymentDetailsScreen extends StatefulWidget {
  final String paymentId;
  const PaymentDetailsScreen({super.key, required this.paymentId});
  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  bool busy = false;
  Future<void> review(bool confirm) async {
    final store = StoreScope.of(context);
    String reason = '';
    if (!confirm) {
      final c = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject payment'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, c.text),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      // Keep the controller alive until the dialog exit transition completes.
      Future<void>.delayed(const Duration(milliseconds: 400), c.dispose);
      if (result == null) return;
      reason = result;
    } else {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm you received this payment?'),
          content: const Text(
            'Check the cash or bank record first. This confirms the record and makes a receipt available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm received'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    await perform(
      context,
      () => store.reviewPayment(
        widget.paymentId,
        confirm: confirm,
        reason: reason,
      ),
      success: confirm ? 'Payment confirmed.' : 'Payment rejected.',
    );
    if (mounted) setState(() => busy = false);
  }

  Future<void> pdf(bool share) async {
    final store = StoreScope.of(context);
    setState(() => busy = true);
    await perform(context, () async {
      final p = store.payment(widget.paymentId);
      final bytes = await receiptPdf(store, p.id);
      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'BackyardPay-${p.reference}.pdf',
        );
      } else {
        await Printing.layoutPdf(
          name: 'BackyardPay-${p.reference}',
          onLayout: (_) async => bytes,
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        p = store.payment(widget.paymentId),
        t = store.tenancy(p.tenancyId);
    final tenant = store.tenantAccount(t),
        property = store.property(t.propertyId);
    final confirmed = p.state == ReviewState.confirmed;
    return PageShell(
      title: confirmed ? 'Digital payment receipt' : 'Payment submission',
      children: [
        heading(p.state.name.toUpperCase()),
        if (p.state == ReviewState.pending)
          panel(
            const Text(
              'Payment submitted. Waiting for landlord confirmation. This acknowledgement is not a confirmed receipt.',
            ),
          ),
        if (p.state == ReviewState.rejected)
          panel(Text('Rejected: ${p.rejectionReason}')),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Tenant', tenant.name),
              detail('Property', property.name),
              detail('Room', t.room),
              detail('Rent month', p.period),
              detail('Amount', money(p.amountCents)),
              detail('Method', p.method),
              detail(
                'Payment date',
                p.paidOn.toIso8601String().split('T').first,
              ),
              detail('Reference', p.reference),
              if (p.notes.isNotEmpty) detail('Notes', p.notes),
              if (confirmed) ...[
                detail(
                  'Confirmed on',
                  p.reviewedAt!.toLocal().toString().split('.').first,
                ),
                detail('Paid after due date', store.isLate(p) ? 'Yes' : 'No'),
                detail('Month balance', money(store.outstanding(t, p.period))),
              ],
            ],
          ),
        ),
        if (store.currentUser!.role == Role.landlord &&
            p.state == ReviewState.pending) ...[
          action(
            'Confirm payment',
            busy ? null : () => review(true),
            icon: Icons.check_circle_outline,
          ),
          OutlinedButton(
            onPressed: busy ? null : () => review(false),
            child: const Text('Reject payment'),
          ),
        ],
        if (confirmed) ...[
          action(
            'Print / save PDF',
            busy ? null : () => pdf(false),
            icon: Icons.picture_as_pdf_outlined,
          ),
          action(
            'Download / share receipt',
            busy ? null : () => pdf(true),
            icon: Icons.share_outlined,
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        action(
          'Back to dashboard',
          () => home(context),
          icon: Icons.home_outlined,
        ),
      ],
    );
  }
}
