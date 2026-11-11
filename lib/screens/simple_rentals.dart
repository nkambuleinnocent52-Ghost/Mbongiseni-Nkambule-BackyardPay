import 'deposit_reminder_notice.dart';
import 'deposit_payments.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../ui/design.dart';
import 'common.dart';
import 'payment_entry.dart';
import 'payments.dart';
import 'properties.dart';
import 'rental_account.dart';
import 'research_records.dart' show isoDay, checkedDate;

/// Occasional actions expand in place; primary tasks remain easy to find.
class RentalSection extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const RentalSection({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class InlineRentalForm extends StatefulWidget {
  final Map<String, String> fields, initial;
  final String label;
  final Future<void> Function(Map<String, String>, String) save;
  const InlineRentalForm({
    super.key,
    required this.fields,
    this.initial = const {},
    required this.label,
    required this.save,
  });
  @override
  State<InlineRentalForm> createState() => _InlineRentalFormState();
}

class _InlineRentalFormState extends State<InlineRentalForm> {
  final form = GlobalKey<FormState>();
  late final controls = {
    for (final k in widget.fields.keys)
      k: TextEditingController(text: widget.initial[k] ?? ''),
  };
  String eventId = const Uuid().v4();
  bool busy = false;
  @override
  void dispose() {
    for (final c in controls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in widget.fields.entries)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              key: ValueKey('inline-${entry.key}'),
              controller: controls[entry.key],
              enabled: !busy,
              maxLines:
                  [
                    'message',
                    'reason',
                    'evidence',
                    'note',
                    'description',
                  ].contains(entry.key)
                  ? 2
                  : 1,
              decoration: InputDecoration(labelText: entry.value),
              validator: requiredField,
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() => busy = true);
                    final ok = await perform(
                      context,
                      () => widget.save({
                        for (final e in controls.entries)
                          e.key: e.value.text.trim(),
                      }, eventId),
                      success: 'Saved.',
                    );
                    if (mounted)
                      setState(() {
                        busy = false;
                        if (ok) eventId = const Uuid().v4();
                      });
                  },
            child: Text(busy ? 'Saving…' : widget.label),
          ),
        ),
      ],
    ),
  );
}

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
          subtitle: const Text(
            'Separate from monthly rent. Saving an actual payment confirms the tick.',
          ),
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
          const Text(
            'A deposit payment is waiting for the landlord to check. It is not counted as received yet.',
          ),
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
                  'Only supported lawful costs may be deducted. Damage does not automatically remove the whole deposit. Record condition evidence and the cost; keep any remaining amount available to return.',
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

class MoveOut extends StatefulWidget {
  final String tenancyId;
  const MoveOut({super.key, required this.tenancyId});
  @override
  State<MoveOut> createState() => _MoveOutState();
}

class _MoveOutState extends State<MoveOut> {
  bool returned = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: returned,
        onChanged: (v) => setState(() => returned = v ?? false),
        title: const Text('The tenant has returned the room and keys'),
      ),
      if (returned)
        InlineRentalForm(
          fields: const {
            'date': 'Actual return date (YYYY-MM-DD)',
            'note': 'Final rent / handover agreement',
          },
          initial: {'date': isoDay(DateTime.now())},
          label: 'Confirm move-out',
          save: (v, id) async {
            checkedDate(v['date']!);
            await StoreScope.of(context).researchAction('close_tenancy', {
              'tenancyId': widget.tenancyId,
              'date': v['date'],
              'note': v['note'],
            });
          },
        ),
      const Text(
        'The room becomes available the following day. Unpaid rent and the deposit remain on record.',
        style: TextStyle(color: Palette.muted, fontSize: 12),
      ),
    ],
  );
}

class SimpleReportsScreen extends StatelessWidget {
  final String? tenancyId;
  const SimpleReportsScreen({super.key, this.tenancyId});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Reported problems',
    maxWidth: 900,
    children: [SimpleReports(tenancyId: tenancyId)],
  );
}

class SimpleReports extends StatelessWidget {
  final String? tenancyId;
  const SimpleReports({super.key, this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        owner = s.currentUser!.role == Role.landlord;
    final reports =
        s.caseRecords
            .where(
              (r) =>
                  ['repair', 'query'].contains(r['kind']) &&
                  (tenancyId == null || r['tenancyId'] == tenancyId),
            )
            .toList()
          ..sort(
            (a, b) => (b['createdAt'] as String).compareTo(a['createdAt']),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tenancyId != null && !owner)
          InlineRentalForm(
            fields: const {
              'location': 'Where is the problem?',
              'description': 'Describe the issue',
            },
            label: 'Send issue',
            save: (v, id) async {
              await s.researchAction('case', {
                'tenancyId': tenancyId,
                'eventId': id,
                'kind': 'repair',
                'body': {
                  'category': 'Other',
                  'urgency': 'Routine',
                  'incidentDate': isoDay(DateTime.now()),
                  'cause': 'Unknown',
                  'location': v['location'],
                  'description': v['description'],
                  'accessAvailability': '',
                },
              });
            },
          ),
        if (reports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No issues reported.'),
          ),
        for (final r in reports)
          Builder(
            builder: (context) {
              final noted = s.research.caseStatus(r) != 'open',
                  t = s.tenancy(r['tenancyId']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Room ${t.room} · ${s.tenantAccount(t).name}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(r['body']['description']),
                    if (r['body']['location'] != null)
                      Text(
                        r['body']['location'],
                        style: const TextStyle(color: Palette.muted),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: noted,
                      onChanged: owner && !noted
                          ? (v) => perform(
                              context,
                              () => s.researchAction('case', {
                                'tenancyId': t.id,
                                'eventId': const Uuid().v4(),
                                'kind': 'case_update',
                                'body': {
                                  'parentId': r['id'],
                                  'status': 'in_progress',
                                  'message': 'Landlord has noted your issue.',
                                },
                              }),
                            )
                          : null,
                      title: const Text('Noted by landlord'),
                      subtitle: Text(
                        noted
                            ? 'Acknowledgement visible to both parties'
                            : 'Waiting for acknowledgement',
                      ),
                    ),
                    if (s.research.caseStatus(r) == 'resolved')
                      const Text(
                        'Resolved',
                        style: TextStyle(color: Palette.green),
                      ),
                    if (owner &&
                        noted &&
                        s.research.caseStatus(r) != 'resolved')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => perform(
                            context,
                            () => s.researchAction('case', {
                              'tenancyId': t.id,
                              'eventId': const Uuid().v4(),
                              'kind': 'case_update',
                              'body': {
                                'parentId': r['id'],
                                'status': 'resolved',
                                'message':
                                    'Landlord marked this issue resolved.',
                              },
                            }),
                          ),
                          child: const Text('Mark resolved'),
                        ),
                      ),
                    for (final reply
                        in s.research
                            .forTenancy(t.id, 'case_update')
                            .where((x) => x['body']['parentId'] == r['id']))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${reply['body']['message']} · ${reply['createdAt'].toString().split('T').first}',
                          style: const TextStyle(color: Palette.muted),
                        ),
                      ),
                    RentalSection(
                      title: owner ? 'Reply / send update' : 'Add message',
                      children: [
                        if (owner)
                          PropertyMessage(
                            propertyId: t.propertyId,
                            tenancyId: t.id,
                            parentId: r['id'],
                          )
                        else
                          InlineRentalForm(
                            fields: const {'message': 'Message'},
                            label: 'Send message',
                            save: (v, id) async {
                              await s.researchAction('case', {
                                'tenancyId': t.id,
                                'eventId': id,
                                'kind': 'case_update',
                                'body': {
                                  'parentId': r['id'],
                                  'status': 'comment',
                                  'message': v['message'],
                                },
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class PropertyMessage extends StatefulWidget {
  final String propertyId;
  final String? tenancyId, parentId;
  const PropertyMessage({
    super.key,
    required this.propertyId,
    this.tenancyId,
    this.parentId,
  });
  @override
  State<PropertyMessage> createState() => _PropertyMessageState();
}

class _PropertyMessageState extends State<PropertyMessage> {
  bool all = false;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        linked = s.tenancies
            .where(
              (t) =>
                  t.propertyId == widget.propertyId &&
                  t.userId.isNotEmpty &&
                  t.endedOn == null,
            )
            .length;
    return Column(
      children: [
        if (widget.tenancyId != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: all,
            onChanged: (v) => setState(() => all = v),
            title: Text(
              all ? 'All current tenants at this property' : 'Only this tenant',
            ),
            subtitle: Text(
              all
                  ? '$linked linked tenant accounts receive the update'
                  : 'The issue remains private',
            ),
          )
        else
          Text('$linked linked tenant accounts at this property'),
        const Text(
          'In-app notification only. Do not include a tenant’s private information in a shared update.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
        InlineRentalForm(
          fields: const {'message': 'Update message'},
          label: 'Send update',
          save: (v, id) async {
            if (widget.tenancyId != null && !all && widget.parentId != null) {
              await s.researchAction('case', {
                'tenancyId': widget.tenancyId,
                'eventId': id,
                'kind': 'case_update',
                'body': {
                  'parentId': widget.parentId,
                  'status': 'comment',
                  'message': v['message'],
                },
              });
            } else {
              final sent = await s.researchAction('property_message', {
                'propertyId': widget.propertyId,
                'eventId': id,
                if (widget.tenancyId != null && !all)
                  'tenancyId': widget.tenancyId,
                'message': v['message'],
              });
              if (context.mounted)
                tell(context, 'Update sent to $sent tenant account(s).');
            }
          },
        ),
      ],
    );
  }
}
