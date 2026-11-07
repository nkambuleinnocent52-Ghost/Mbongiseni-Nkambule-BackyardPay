import 'room_availability.dart';
import 'documents.dart';
import '../data/research_ledger.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/receipts.dart';
import '../ui/design.dart';
import 'common.dart';

String isoDay(DateTime date) => date.toIso8601String().split('T').first;
DateTime checkedDate(String text) {
  final d = DateTime.tryParse(text.trim());
  if (d == null || isoDay(d) != text.trim())
    throw const FormatException('Use a valid date in YYYY-MM-DD format.');
  return d;
}

void createTenantRecord(BuildContext context) {
  final store = StoreScope.of(context);
  if (store.properties.isEmpty) {
    tell(context, 'Add a property first.');
    return;
  }
  open(context, _TenantRecordForm());
}

class _TenantRecordForm extends StatefulWidget {
  @override
  State<_TenantRecordForm> createState() => _TenantRecordFormState();
}

class _TenantRecordFormState extends State<_TenantRecordForm> {
  String? propertyId;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    propertyId ??= store.properties.first.id;
    return PageShell(
      title: 'Add tenant record',
      maxWidth: 740,
      children: [
        const Text(
          'Create the actual rental record without making an account or password for the tenant. Give them the private invitation afterwards if they want app access.',
        ),
        gap(16),
        DropdownButtonFormField<String>(
          initialValue: propertyId,
          decoration: const InputDecoration(labelText: 'Property'),
          items: store.properties
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
              .toList(),
          onChanged: (v) => setState(() => propertyId = v),
        ),
        gap(16),
        RoomAvailability(propertyId: propertyId!),
        if (store.isCloud &&
            store.property(propertyId!).securityDepositCents == null)
          const Text(
            'Specify this property’s security deposit in Properties before onboarding (enter 0 if none).',
          ),
        action(
          'Enter tenant details',
          store.isCloud &&
                  store.property(propertyId!).securityDepositCents == null
              ? null
              : () => open(
                  context,
                  EditorPage(
                    title: 'Tenant and room',
                    preview: (context, v) {
                      try {
                        final date = checkedDate(v['start']!);
                        final property = store.property(propertyId!);
                        return panel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RoomAvailability(
                                propertyId: propertyId!,
                                moveIn: date,
                              ),
                              heading('Move-in costs'),
                              detail(
                                'Security deposit',
                                property.securityDepositCents == null
                                    ? 'Not specified — edit property first'
                                    : money(property.securityDepositCents!),
                              ),
                              detail(
                                'First rent charge',
                                money(
                                  property.prorateFirstMonth
                                      ? proratedFirstCharge(
                                          property.rentCents,
                                          date,
                                        )
                                      : property.rentCents,
                                ),
                              ),
                              if (property.securityDepositCents != null)
                                detail(
                                  'Total initially due',
                                  money(
                                    property.securityDepositCents! +
                                        (property.prorateFirstMonth
                                            ? proratedFirstCharge(
                                                property.rentCents,
                                                date,
                                              )
                                            : property.rentCents),
                                  ),
                                ),
                              Text(
                                firstChargeExplanation(
                                  property.rentCents,
                                  date,
                                  property.prorateFirstMonth,
                                ),
                              ),
                              const Text(
                                'Confirm this move-in date and billing basis with the tenant. The deposit is separate.',
                              ),
                            ],
                          ),
                        );
                      } catch (_) {
                        return const Text(
                          'Enter a valid move-in date to calculate the first charge.',
                        );
                      }
                    },
                    help: 'Record only necessary contact information. This does not verify ownership or create a signed lease.',
                    fields: [
                      const FieldSpec('name', 'Tenant full name'),
                      const FieldSpec(
                        'phone',
                        'Phone (optional)',
                        optional: true,
                      ),
                      const FieldSpec(
                        'email',
                        'Email (optional)',
                        optional: true,
                      ),
                      FieldSpec(
                        'start',
                        'Actual occupancy start (YYYY-MM-DD)',
                        initial: isoDay(DateTime.now()),
                      ),
                      FieldSpec(
                        'room',
                        'Available room',
                        optionPrefix: 'Room ',
                        emptyOptionsMessage:
                            'No rooms available for this move-in date',
                        optionsForValues: (v) {
                          try {
                            return store
                                .availableRoomNumbers(
                                  propertyId!,
                                  from: checkedDate(v['start']!),
                                )
                                .map((n) => '$n')
                                .toList();
                          } catch (_) {
                            return [];
                          }
                        },
                      ),
                    ],
                    save: (v) async {
                      final date = checkedDate(v['start']!);
                      if (!store
                          .availableRoomNumbers(propertyId!, from: date)
                          .contains(int.tryParse(v['room']!)))
                        throw StateError(
                          'This room is no longer available. Refresh and choose another room.',
                        );
                      await store.researchAction('tenancy', {
                        'propertyId': propertyId,
                        'name': v['name'],
                        'phone': v['phone'],
                        'email': v['email'],
                        'room': int.tryParse(v['room']!) ?? 0,
                        'start': v['start'],
                      });
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class RentalRecordsScreen extends StatelessWidget {
  final String tenancyId, kind;
  const RentalRecordsScreen({
    super.key,
    required this.tenancyId,
    required this.kind,
  });
  String get title => {
    'deposit': 'Deposit account',
    'inspection': 'Inspections and defects',
    'repair': 'Reports and queries',
    'adjustment': 'Charge adjustments',
    'audit': 'Rental change history',
  }[kind]!;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        t = store.tenancy(tenancyId),
        owner = store.currentUser!.role == Role.landlord;
    final rows =
        store.caseRecords
            .where(
              (r) =>
                  r['tenancyId'] == t.id &&
                  (kind == 'repair'
                      ? ['repair', 'query', 'case_update'].contains(r['kind'])
                      : r['kind'] == kind),
            )
            .toList()
          ..sort(
            (a, b) =>
                (b['createdAt'] as String).compareTo(a['createdAt'] as String),
          );
    return PageShell(
      title: title,
      children: [
        heading('${store.tenantAccount(t).name} • Room ${t.room}'),
        if (kind == 'deposit') ...[
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                detail(
                  'Agreed deposit',
                  t.depositCents == null
                      ? 'Not recorded'
                      : money(t.depositCents!),
                ),
                detail(
                  'Recorded receipts',
                  money(store.research.depositReceived(t)),
                ),
                detail(
                  'Deposit and interest held',
                  money(store.research.depositBalance(t)),
                ),
                detail(
                  'Still to record against agreed deposit',
                  money(
                    math.max(
                      0,
                      (t.depositCents ?? 0) - store.research.depositReceived(t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Deposits are separate from rent. Record actual interest from evidence; no fixed interest rate is assumed. Refund and deduction rules depend on inspections, liabilities and legal conditions. An opening balance imported from the old record is not new money received.',
          ),
        ],
        if (kind == 'inspection')
          const Text(
            'Record the actual inspection and named participants, condition/defects, keys and meter readings. This is the recorder’s account; it is not automatically a joint agreement or a signature.',
          ),
        if (kind == 'adjustment')
          const Text(
            'Use a documented agreed correction, including an agreed partial-month charge. Positive adjustments increase charges; credits reduce them. Received payments are never erased. A record here does not establish that a disputed charge is lawful.',
          ),
        if (kind == 'repair')
          const Text(
            'Report leaks, gates, safety concerns, noise or room damage, including damage you may have caused. Describe facts without assuming blame. Only this rental’s landlord and linked tenant can read the report. App reports are not monitored emergency calls; contact emergency/municipal services and the landlord directly for immediate danger.',
          ),
        if (kind != 'audit' && (owner || kind == 'repair'))
          action(
            kind == 'repair' ? 'Report a problem / query' : 'Add record',
            () => open(context, RecordEditor(tenancyId: t.id, kind: kind)),
          ),
        gap(16),
        if (rows.isEmpty)
          panel(const Text('No records yet. Missing evidence is not assumed.')),
        for (final row in rows)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recordTitle(row),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    if (['repair', 'query'].contains(row['kind']))
                      StatusPill(
                        _caseStatusLabel(store.research.caseStatus(row)),
                      ),
                  ],
                ),
                gap(8),
                Text(
                  'Recorded ${DateTime.parse(row['createdAt']).toLocal().toString().split('.').first} • ${row['actor'] == store.landlordFor(t).id ? 'Landlord' : 'Tenant'}',
                  style: const TextStyle(color: Palette.muted, fontSize: 11),
                ),
                for (final entry in (row['body'] as Map).entries)
                  if (![
                        'receiptDetails',
                        'previous',
                        'updated',
                        'parentId',
                        'paymentId',
                      ].contains(entry.key) &&
                      entry.value is! Map &&
                      entry.value is! List)
                    detail(
                      _fieldLabel(entry.key.toString()),
                      entry.key == 'amountCents'
                          ? money(entry.value as int)
                          : '${entry.value}',
                    ),
                if (kind == 'deposit' && row['body']['event'] == 'received')
                  action(
                    'Download deposit receipt',
                    () => perform(context, () async {
                      await Printing.sharePdf(
                        bytes: await depositReceiptPdf(store, t.id, row),
                        filename: 'BackyardPay-deposit-${row['id']}.pdf',
                      );
                    }),
                    icon: Icons.download_outlined,
                  ),
                if (['repair', 'query'].contains(row['kind']))
                  action(
                    'Open case / add message',
                    () => open(
                      context,
                      CaseThreadScreen(tenancyId: t.id, record: row),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String _fieldLabel(String key) =>
    {
      'event': 'Entry type',
      'amountCents': 'Amount',
      'reference': 'Reference / evidence',
      'date': 'Event date',
      'note': 'Explanation',
      'condition': 'Condition / defects',
      'participants': 'Named participants',
      'stage': 'Inspection stage',
      'description': 'Description',
      'message': 'Message',
      'status': 'Status',
      'period': 'Rental month',
      'reason': 'Agreement / reason',
      'payer': 'Actual payer',
      'category': 'Category',
      'urgency': 'Urgency',
      'incidentDate': 'Date noticed',
      'location': 'Location',
      'cause': 'Reporter’s account of cause',
      'accessAvailability': 'Proposed access availability',
      'method': 'Method',
      'action': 'Action',
      'keysMeters': 'Keys / meters / facilities',
    }[key] ??
    key;
String _caseStatusLabel(String status) =>
    const {
      'in_progress': 'In progress',
      'resolved': 'Resolved',
      'open': 'Open',
      'comment': 'Message',
    }[status] ??
    status;
String _recordTitle(Map<String, dynamic> r) => r['kind'] == 'deposit'
    ? 'Deposit • ${r['body']['event']}'
    : r['kind'] == 'inspection'
    ? '${r['body']['stage']} inspection'
    : r['kind'] == 'case_update'
    ? 'Case update'
    : r['kind'] == 'adjustment'
    ? 'Rental charge adjustment'
    : r['kind'] == 'audit'
    ? 'Recorded change'
    : '${r['body']['category'] ?? (r['kind'] == 'repair' ? 'Maintenance report' : 'Account query')}';

class CaseThreadScreen extends StatelessWidget {
  final String tenancyId;
  final Map<String, dynamic> record;
  const CaseThreadScreen({
    super.key,
    required this.tenancyId,
    required this.record,
  });
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        owner = store.currentUser!.role == Role.landlord;
    final replies = store.research
        .forTenancy(tenancyId, 'case_update')
        .where((r) => r['body']['parentId'] == record['id']);
    return PageShell(
      title: 'Report / account query',
      children: [
        heading(_recordTitle(record)),
        StatusPill(_caseStatusLabel(store.research.caseStatus(record))),
        gap(12),
        for (final key in [
          'category',
          'urgency',
          'incidentDate',
          'location',
          'cause',
          'accessAvailability',
        ])
          if (record['body'][key] != null)
            detail(_fieldLabel(key), record['body'][key].toString()),
        Text(record['body']['description']),
        const Text(
          'Reported cause is the reporter’s account, not a decision about liability. A report does not change rent, take money from a deposit or authorise entry. Arrange access separately.',
        ),
        if (store.isCloud)
          action(
            'Report photos / evidence',
            () => open(
              context,
              RentalDocuments(tenancyId: tenancyId, caseId: record['id']),
            ),
            icon: Icons.attach_file,
          ),
        for (final reply in replies)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reply['body']['message']),
                gap(8),
                Text(
                  '${DateTime.parse(reply['createdAt']).toLocal().toString().split('.').first} • ${_caseStatusLabel(reply['body']['status'])}',
                  style: const TextStyle(color: Palette.muted),
                ),
              ],
            ),
          ),
        for (final status
            in owner
                ? ['comment', 'in_progress', 'resolved', 'open']
                : ['comment'])
          action(
            status == 'comment'
                ? 'Add message'
                : 'Mark ${status.replaceAll('_', ' ')}',
            () => open(
              context,
              EditorPage(
                title: 'Case message',
                fields: const [
                  FieldSpec(
                    'message',
                    'Message / explanation',
                    multiline: true,
                  ),
                ],
                save: (v) async {
                  await store.researchAction('case', {
                    'tenancyId': tenancyId,
                    'eventId': const Uuid().v4(),
                    'kind': 'case_update',
                    'body': {
                      'parentId': record['id'],
                      'status': status,
                      'message': v['message'],
                    },
                  });
                },
              ),
            ),
          ),
      ],
    );
  }
}

class RecordEditor extends StatefulWidget {
  final String tenancyId, kind;
  const RecordEditor({super.key, required this.tenancyId, required this.kind});
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  final eventId = const Uuid().v4();
  final controls = <String, TextEditingController>{};
  String event = 'received',
      stage = 'Entry',
      issue = 'repair',
      sign = 'Credit',
      method = 'Cash';
  String category = 'Water / plumbing',
      urgency = 'Routine',
      location = 'Inside my room',
      cause = 'Unknown';
  bool busy = false, checked = false;
  String? error;
  TextEditingController c(String key, [String initial = '']) =>
      controls.putIfAbsent(key, () => TextEditingController(text: initial));
  @override
  void dispose() {
    for (final x in controls.values) x.dispose();
    super.dispose();
  }

  Widget field(
    String key,
    String label, {
    String initial = '',
    bool optional = false,
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: c(key, initial),
      enabled: !busy,
      maxLines: multiline ? 3 : 1,
      decoration: InputDecoration(labelText: label),
      validator: optional ? null : requiredField,
    ),
  );
  Widget choice(
    String label,
    String value,
    List<String> values,
    void Function(String) change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (v) =>
                DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '))),
          )
          .toList(),
      onChanged: busy ? null : (v) => setState(() => change(v!)),
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{};
      String kind = widget.kind;
      if (kind == 'deposit') {
        if (!checked)
          throw StateError(
            'Confirm you checked the event and its supporting evidence.',
          );
        checkedDate(c('date').text);
        body.addAll({
          'event': event,
          'date': c('date').text,
          'amountCents': parseMoney(c('amount').text),
          'reference': c('reference').text,
          'note': c('note').text,
          'method': method,
          'payer': c('payer').text,
        });
      } else if (kind == 'inspection') {
        checkedDate(c('date').text);
        body.addAll({
          'stage': stage,
          'date': c('date').text,
          'participants': c('participants').text,
          'condition': c('condition').text,
          'keysMeters': c('keys').text,
        });
      } else if (kind == 'adjustment') {
        periodDate(c('period').text);
        body.addAll({
          'period': c('period').text,
          'amountCents':
              parseMoney(c('amount').text) * (sign == 'Credit' ? -1 : 1),
          'reason': c('reason').text,
        });
      } else {
        kind = issue;
        checkedDate(c('incidentDate').text);
        body.addAll({
          'description': c('description').text,
          'category': category,
          'urgency': urgency,
          'location': c('location', location).text,
          'incidentDate': c('incidentDate').text,
          'cause': cause,
          'accessAvailability': c('access').text,
        });
      }
      await StoreScope.of(context).researchAction('case', {
        'tenancyId': widget.tenancyId,
        'kind': kind,
        'eventId': eventId,
        'body': body,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), t = store.tenancy(widget.tenancyId);
    return PageShell(
      title: 'New ${widget.kind} record',
      maxWidth: 740,
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.kind == 'deposit') ...[
                const Text(
                  'For a transfer covering rent and deposit, enter only the deposit portion here. Use the actual shared bank reference so the two purposes can be reconciled without counting the full transfer twice.',
                ),
                choice('Deposit event', event, [
                  'received',
                  'interest',
                  'deduction',
                  'refund',
                ], (v) => event = v),
                field(
                  'date',
                  'Actual event date (YYYY-MM-DD)',
                  initial: isoDay(DateTime.now()),
                ),
                field(
                  'amount',
                  event == 'deduction'
                      ? 'Supported deduction amount (rand)'
                      : 'Amount (rand)',
                ),
                if (event == 'deduction')
                  const Text(
                    'Enter only the supported lawful deduction, not the entire deposit automatically. The remaining deposit and interest stay available for reconciliation.',
                  ),
                choice('Method / source', method, [
                  'Cash',
                  'Cash deposit',
                  'EFT',
                  'PayShap',
                  'Bank interest',
                  'Other',
                ], (v) => method = v),
                field(
                  'payer',
                  'Actual payer / recipient / interest source',
                  initial: store.tenantAccount(t).name,
                ),
                field(
                  'reference',
                  'Transaction or expenditure evidence reference',
                ),
                field(
                  'note',
                  'Explanation / deduction basis',
                  multiline: true,
                  optional: event != 'deduction',
                ),
                CheckboxListTile(
                  value: checked,
                  onChanged: busy ? null : (v) => setState(() => checked = v!),
                  title: const Text(
                    'I checked the money/event and the supporting evidence. A deduction requires legal grounds and inspection evidence.',
                  ),
                ),
              ] else if (widget.kind == 'inspection') ...[
                choice('Inspection stage', stage, [
                  'Entry',
                  'Exit',
                ], (v) => stage = v),
                field(
                  'date',
                  'Actual inspection date (YYYY-MM-DD)',
                  initial: isoDay(DateTime.now()),
                ),
                field(
                  'participants',
                  'Who attended? Record names and any absence',
                  multiline: true,
                ),
                field(
                  'condition',
                  'Condition, defects and rectification agreed',
                  multiline: true,
                ),
                field(
                  'keys',
                  'Keys, shared facilities, inventory and meter readings',
                  multiline: true,
                  optional: true,
                ),
              ] else if (widget.kind == 'adjustment') ...[
                choice('Correction', sign, [
                  'Credit',
                  'Debit',
                ], (v) => sign = v),
                field(
                  'period',
                  'Rental month (YYYY-MM)',
                  initial: periodOf(DateTime.now()),
                ),
                field('amount', 'Adjustment amount (rand)'),
                field(
                  'reason',
                  'Actual agreement, reason and evidence reference',
                  multiline: true,
                ),
              ] else ...[
                choice('Report type', issue, [
                  'repair',
                  'query',
                ], (v) => issue = v),
                choice('Category', category, [
                  'Water / plumbing',
                  'Gate / shared facilities',
                  'Electrical / safety',
                  'Structure / damp',
                  'Noise / nuisance',
                  'Damage inside my room',
                  'Account / deposit query',
                  'Other',
                ], (v) => category = v),
                choice('Urgency', urgency, [
                  'Routine',
                  'Urgent',
                  'Immediate danger',
                ], (v) => urgency = v),
                if (urgency != 'Routine')
                  const Text(
                    'For immediate danger or ongoing serious damage, contact the landlord and relevant emergency/municipal service directly. Do not wait for an in-app reply or attempt dangerous repairs.',
                  ),
                field(
                  'incidentDate',
                  'Date noticed (YYYY-MM-DD)',
                  initial: isoDay(DateTime.now()),
                ),
                field(
                  'location',
                  'Where exactly? Room / shared area / outside',
                  initial: location,
                ),
                choice('What do you know about the cause?', cause, [
                  'Unknown',
                  'Wear / deterioration suspected',
                  'I or my household caused it',
                  'Third party suspected',
                  'Other',
                ], (v) => cause = v),
                field(
                  'access',
                  'Availability for an agreed inspection (optional)',
                  optional: true,
                  multiline: true,
                ),
                field(
                  'description',
                  'Describe the problem and immediate impact',
                  multiline: true,
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Palette.red)),
              action(
                busy ? 'Saving…' : 'Save record',
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

void recordRentChange(BuildContext context, String tenancyId) {
  final store = StoreScope.of(context), now = DateTime.now();
  open(
    context,
    EditorPage(
      title: 'Record agreed rent change',
      help: 'Future effective month only. Record the actual agreement; this does not impose a lawful rent increase by itself. Past charges remain unchanged.',
      fields: [
        FieldSpec(
          'period',
          'Effective month (YYYY-MM)',
          initial: periodOf(DateTime(now.year, now.month + 1)),
        ),
        const FieldSpec('amount', 'Agreed monthly rent (rand)', numeric: true),
        const FieldSpec('due', 'Due day (1–28)', initial: '1', numeric: true),
        const FieldSpec(
          'evidence',
          'Agreement / notice evidence and explanation',
          multiline: true,
        ),
      ],
      save: (v) async {
        periodDate(v['period']!);
        await store.researchAction('rent_term', {
          'tenancyId': tenancyId,
          'period': v['period'],
          'amountCents': parseMoney(v['amount']!),
          'dueDay': int.tryParse(v['due']!) ?? 0,
          'evidence': v['evidence'],
        });
      },
    ),
  );
}

void closeTenancy(BuildContext context, String tenancyId) {
  final store = StoreScope.of(context);
  open(
    context,
    EditorPage(
      title: 'Record completed handover',
      help: 'Only record actual handover. A planned lease expiry does not automatically evict a tenant or stop the rental account. Check final charges, credits, deposit and inspections. Use an agreed adjustment for partial-month billing.',
      fields: [
        FieldSpec(
          'date',
          'Actual handover date (YYYY-MM-DD)',
          initial: isoDay(DateTime.now()),
        ),
        const FieldSpec(
          'note',
          'Handover agreement and final billing explanation',
          multiline: true,
        ),
      ],
      save: (v) async {
        checkedDate(v['date']!);
        await store.researchAction('close_tenancy', {
          'tenancyId': tenancyId,
          'date': v['date'],
          'note': v['note'],
        });
      },
    ),
  );
}

class ReportsOverview extends StatelessWidget {
  const ReportsOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final reports =
        store.caseRecords
            .where((r) => ['repair', 'query'].contains(r['kind']))
            .toList()
          ..sort((a, b) {
            final resolved =
                (store.research.caseStatus(a) == 'resolved' ? 1 : 0).compareTo(
                  store.research.caseStatus(b) == 'resolved' ? 1 : 0,
                );
            if (resolved != 0) return resolved;
            return (b['createdAt'] as String).compareTo(
              a['createdAt'] as String,
            );
          });
    return PageShell(
      title: 'Tenant reports',
      children: [
        const Text(
          'Private reports from your linked rentals. Reporting does not assign repair liability, authorise entry or change any rent/deposit balance.',
        ),
        if (reports.isEmpty) panel(const Text('No reports yet.')),
        for (final r in reports)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading(_recordTitle(r)),
                Text(
                  '${store.tenantAccount(store.tenancy(r['tenancyId'])).name} • ${store.property(store.tenancy(r['tenancyId']).propertyId).name} • Room ${store.tenancy(r['tenancyId']).room}',
                ),
                Text('Urgency: ${r['body']['urgency'] ?? 'Not recorded'}'),
                StatusPill(_caseStatusLabel(store.research.caseStatus(r))),
                action(
                  'Open report',
                  () => open(
                    context,
                    CaseThreadScreen(tenancyId: r['tenancyId'], record: r),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
