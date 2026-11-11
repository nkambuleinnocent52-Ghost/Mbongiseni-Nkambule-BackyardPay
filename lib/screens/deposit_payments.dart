import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../ui/design.dart';
import 'common.dart';
import 'payment_entry.dart';
import 'research_records.dart' show isoDay, checkedDate;

class PaymentPurpose extends StatelessWidget {
  final String tenancyId;
  final bool deposit;
  const PaymentPurpose({
    super.key,
    required this.tenancyId,
    required this.deposit,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: deposit ? 'deposit' : 'rent',
      decoration: const InputDecoration(labelText: 'Payment for'),
      items: const [
        DropdownMenuItem(value: 'rent', child: Text('Rent')),
        DropdownMenuItem(value: 'deposit', child: Text('Security deposit')),
      ],
      onChanged: (value) {
        if ((value == 'deposit') == deposit) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => value == 'deposit'
                ? DepositPaymentScreen(tenancyId: tenancyId)
                : ResearchPaymentEntry(tenancyId: tenancyId),
          ),
        );
      },
    ),
  );
}

class DepositPaymentScreen extends StatefulWidget {
  final String tenancyId;
  const DepositPaymentScreen({super.key, required this.tenancyId});
  @override
  State<DepositPaymentScreen> createState() => _DepositPaymentScreenState();
}

class _DepositPaymentScreenState extends State<DepositPaymentScreen> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      date = TextEditingController(),
      bank = TextEditingController(),
      note = TextEditingController();
  final eventId = const Uuid().v4();
  bool ready = false, busy = false;
  String method = 'Cash';
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    final s = StoreScope.of(context), t = s.tenancy(widget.tenancyId);
    final pending = s.depositPaymentReports
        .where((r) => r['tenancyId'] == t.id && r['state'] == 'pending')
        .fold<int>(0, (n, r) => n + (r['amountCents'] as int));
    amount.text =
        (((s.research.depositOutstanding(t) ?? 0) - pending).clamp(
                  0,
                  2147483647,
                ) /
                100)
            .toStringAsFixed(2);
    date.text = isoDay(DateTime.now());
    ready = true;
  }

  @override
  void dispose() {
    for (final c in [amount, date, bank, note]) c.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      checkedDate(date.text);
      final s = StoreScope.of(context), t = s.tenancy(widget.tenancyId);
      await s.researchAction('deposit_report', {
        'tenancyId': t.id,
        'eventId': eventId,
        'amountCents': parseMoney(amount.text),
        'paidOn': date.text,
        'method': method,
        'reference': 'DEP-$eventId',
        'bankReference': bank.text.trim(),
        'payer': s.currentUser!.name,
        'notes': note.text.trim(),
      });
      if (mounted) {
        tell(context, 'Deposit payment sent. Your landlord must confirm it.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      decoration: InputDecoration(labelText: label),
      validator: optional ? null : requiredField,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), t = s.tenancy(widget.tenancyId);
    final due = s.research.depositOutstanding(t);
    final waiting = s.depositPaymentReports
        .where((r) => r['tenancyId'] == t.id && r['state'] == 'pending')
        .fold<int>(0, (n, r) => n + (r['amountCents'] as int));
    final canReport =
        due != null &&
        due > waiting &&
        s.currentUser!.role == Role.tenant &&
        t.endedOn == null;
    return PageShell(
      title: 'Report deposit payment',
      maxWidth: 800,
      children: [
        PaymentPurpose(tenancyId: t.id, deposit: true),
        const Text(
          'Your security deposit is paid once, within 10 calendar days of moving in. Paid it by cash or through your bank? Tell your landlord here. This does not send money. The deposit stays separate from rent and is only marked received after your landlord confirms it.',
        ),
        gap(16),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail(
                'Agreed security deposit',
                t.depositCents == null
                    ? 'Not recorded'
                    : money(t.depositCents!),
              ),
              detail(
                'Confirmed received',
                money(s.research.depositReceived(t)),
              ),
              detail('Waiting for confirmation', money(waiting)),
              detail(
                'Deposit still due',
                due == null ? 'Not recorded' : money(due),
              ),
            ],
          ),
        ),
        if (canReport)
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(amount, 'Deposit paid (rand)'),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'How was it paid?',
                  ),
                  items:
                      [
                            'Cash',
                            'EFT',
                            'Cash deposit',
                            'PayShap',
                            'Debit order',
                            'Other',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: busy ? null : (v) => setState(() => method = v!),
                ),
                field(date, 'Date paid (YYYY-MM-DD)'),
                if (!['Cash', 'Other'].contains(method))
                  field(bank, 'Bank payment reference'),
                field(note, 'Payment note (optional)', optional: true),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Palette.red)),
                action(
                  busy ? 'Sending…' : 'Send deposit payment',
                  busy ? null : send,
                  icon: Icons.send_outlined,
                ),
              ],
            ),
          )
        else
          Text(
            due == null
                ? 'Ask your landlord to record the agreed deposit amount.'
                : due == 0
                ? (t.depositCents == 0
                      ? 'No security deposit is required for this rental.'
                      : 'Your agreed deposit has been received.')
                : t.endedOn != null
                ? 'This rental has ended.'
                : 'Your reported deposit payment is waiting for your landlord to confirm it.',
          ),
        DepositReportsList(tenancyId: t.id),
      ],
    );
  }
}

class DepositReportsOverview extends StatelessWidget {
  const DepositReportsOverview({super.key});
  @override
  Widget build(BuildContext context) => const PageShell(
    title: 'Deposit payments to check',
    maxWidth: 900,
    children: [DepositReportsList(pendingOnly: true)],
  );
}

class DepositReportsList extends StatelessWidget {
  final String? tenancyId;
  final bool pendingOnly;
  const DepositReportsList({
    super.key,
    this.tenancyId,
    this.pendingOnly = false,
  });
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final reports =
        s.depositPaymentReports
            .where(
              (r) =>
                  (tenancyId == null || r['tenancyId'] == tenancyId) &&
                  (!pendingOnly || r['state'] == 'pending'),
            )
            .toList()
          ..sort(
            (a, b) => (b['submittedAt'] as String).compareTo(a['submittedAt']),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reports.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: heading('Reported deposit payments'),
          ),
        if (pendingOnly && reports.isEmpty)
          const Text('No deposit payments are waiting for confirmation.'),
        for (final r in reports)
          DepositReportCard(key: ValueKey(r['id']), report: r),
      ],
    );
  }
}

class DepositReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  const DepositReportCard({super.key, required this.report});
  @override
  State<DepositReportCard> createState() => _DepositReportCardState();
}

class _DepositReportCardState extends State<DepositReportCard> {
  bool checked = false, reject = false, busy = false;
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> review(bool confirm) async {
    if (!confirm && reason.text.trim().length < 3) {
      tell(context, 'Explain why the deposit payment could not be confirmed.');
      return;
    }
    setState(() => busy = true);
    await perform(
      context,
      () => StoreScope.of(context).researchAction('deposit_review', {
        'id': widget.report['id'],
        'confirm': confirm,
        'reason': confirm ? '' : reason.text.trim(),
      }),
      success: confirm
          ? 'Deposit payment confirmed.'
          : 'Tenant notified of the reason.',
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        r = widget.report,
        t = s.tenancy(r['tenancyId']);
    final owner = s.currentUser!.role == Role.landlord;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.tenantAccount(t).name} · Room ${t.room}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('${money(r['amountCents'])} · ${r['method']} · ${r['paidOn']}'),
          Text(
            r['state'] == 'pending'
                ? 'Waiting for landlord confirmation'
                : r['state'] == 'confirmed'
                ? 'Deposit received — confirmed by landlord'
                : 'Not confirmed: ${r['reason']}',
          ),
          if ((r['bankReference'] ?? '').isNotEmpty)
            Text('Bank reference: ${r['bankReference']}'),
          if ((r['notes'] ?? '').isNotEmpty) Text(r['notes']),
          if (owner && r['state'] == 'pending') ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: checked,
              onChanged: busy
                  ? null
                  : (v) => setState(() => checked = v ?? false),
              title: const Text(
                'I checked that this deposit payment was received.',
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: busy || !checked ? null : () => review(true),
                  child: const Text('Confirm deposit payment'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => reject = !reject),
                  child: const Text('Could not confirm'),
                ),
              ],
            ),
            if (reject) ...[
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason for not confirming',
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => review(false),
                child: const Text('Send reason to tenant'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
