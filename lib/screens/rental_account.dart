import 'package:flutter/services.dart';

import 'rental_costs.dart';
import '../data/research_ledger.dart';
import 'documents.dart';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../ui/design.dart';
import '../services/receipts.dart';
import 'common.dart';
import 'dashboard.dart';
import 'properties.dart';
import 'payments.dart';
import 'payment_entry.dart';
import 'research_records.dart';

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
                'Confirmed-record charge balance before unallocated credit',
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
                  'Unallocated received credit',
                  money(store.creditFor(t)),
                ),
                detail(
                  'Reports awaiting reconciliation',
                  money(store.pendingFor(t)),
                ),
              ],
              detail('Landlord', store.landlordFor(t).name),
              detail('Account begins', monthLabel(t.startPeriod)),
            ],
          ),
        ),
        const Text(
          'This view allocates payments to charge months as of today. It is not historical month-end cash flow: a later payment can settle an earlier charge. The cumulative balance carries each charge once. Pending reports are separate and are not proof of nonpayment.',
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
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        t = store.tenancy(tenancyId),
        p = store.property(t.propertyId),
        tenant = store.tenantAccount(t),
        landlord = store.landlordFor(t);
    final owner = store.currentUser!.role == Role.landlord;
    return PageShell(
      title: 'Rental details',
      children: [
        GoldHero(
          height: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR RENTAL RECORD',
                style: TextStyle(
                  color: Palette.gold,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              gap(18),
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(12),
              Text(
                'Room ${t.room} · ${money(t.rentCents)} / month',
                style: const TextStyle(color: Palette.goldLight, fontSize: 16),
              ),
              gap(12),
              Text(
                p.fullAddress,
                style: const TextStyle(color: Palette.muted, height: 1.6),
              ),
            ],
          ),
        ),
        gap(18),
        LayoutBuilder(
          builder: (context, c) {
            final parties = [
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading('Tenant'),
                    detail('Name', tenant.name),
                    detail('Email', tenant.email),
                    detail('Phone', tenant.phone),
                  ],
                ),
              ),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading('Landlord'),
                    detail('Name', landlord.name),
                    detail('Email', landlord.email),
                    detail('Phone', landlord.phone),
                  ],
                ),
              ),
            ];
            return c.maxWidth >= 650
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: parties[0]),
                      const SizedBox(width: 16),
                      Expanded(child: parties[1]),
                    ],
                  )
                : Column(children: parties);
          },
        ),
        if (store.researchReady) RentalCosts(tenancy: t),
        heading('Rental terms'),
        if (!t.agreementRecorded)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusPill('Incomplete rental record'),
                gap(12),
                const Text(
                  'The room and initial financial terms are linked. Complete the remaining lease particulars and responsibilities; missing terms are not assumed.',
                  style: TextStyle(color: Palette.muted, height: 1.8),
                ),
              ],
            ),
          ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Rental type', t.agreementType),
              detail(
                'Occupancy starts',
                t.record['tenancyStartedOn'] != null
                    ? dateLabel(DateTime.parse(t.record['tenancyStartedOn']))
                    : t.leaseStart == null
                    ? 'Not recorded'
                    : dateLabel(t.leaseStart!),
              ),
              detail(
                'Occupancy ends',
                t.leaseEnd == null
                    ? (t.agreementType == 'Month-to-month'
                          ? 'No fixed end date'
                          : 'Not recorded')
                    : dateLabel(t.leaseEnd!),
              ),
              detail('Monthly rent', money(t.rentCents)),
              detail('Due date', 'Day ${t.dueDay} of each calendar month'),
              detail(
                'Agreed deposit',
                t.depositCents == null
                    ? 'Not recorded'
                    : money(t.depositCents!),
              ),
              detail(
                'Deposit received',
                store.researchReady
                    ? money(store.research.depositReceived(t))
                    : t.depositReceivedCents == null
                    ? 'Not recorded'
                    : money(t.depositReceivedCents!),
              ),
              detail(
                'Deposit still due',
                t.depositCents == null
                    ? 'Not recorded'
                    : money(
                        (t.depositCents! -
                                (store.researchReady
                                    ? store.research.depositReceived(t)
                                    : (t.depositReceivedCents ?? 0)))
                            .clamp(0, 2147483647),
                      ),
              ),
              detail(
                'Utility responsibilities',
                t.utilities.isEmpty ? 'Not recorded' : t.utilities,
              ),
              detail(
                'House rules / notice terms',
                t.houseRules.isEmpty ? 'Not recorded' : t.houseRules,
              ),
              if (store.researchReady) ...[
                for (final field in const {
                  'landlordAddress': 'Landlord formal-notice address',
                  'tenantAddress': 'Tenant formal-notice address',
                  'authority': 'Authority to let (recorded, not verified)',
                  'dwellingDescription':
                      'Exact accommodation / room / yard space',
                  'sharedFacilities': 'Shared facilities and access',
                  'paymentInstructions': 'Agreed payment instructions',
                  'noticeTerms': 'Notice and continuation terms',
                  'escalationTerms': 'Escalation agreement',
                  'otherCharges': 'Other agreed charges',
                }.entries)
                  detail(field.value, t.record[field.key] ?? 'Not recorded'),
                detail(
                  'Actual handover',
                  t.endedOn == null
                      ? 'Not recorded; planned lease end does not close the account'
                      : dateLabel(t.endedOn!),
                ),
              ],
              if (t.emergencyName.isNotEmpty)
                detail(
                  'Emergency contact',
                  '${t.emergencyName} · ${t.emergencyPhone}',
                ),
              if (t.acknowledgedAt != null)
                detail(
                  'Tenant read acknowledgement',
                  dateLabel(t.acknowledgedAt!),
                ),
            ],
          ),
        ),
        if (owner)
          action(
            t.agreementRecorded ? 'Edit rental terms' : 'Complete rental terms',
            () => open(context, AgreementEditor(tenancyId: t.id)),
            icon: Icons.edit_document,
          ),
        if (!owner && t.agreementRecorded && t.acknowledgedAt == null)
          action(
            'Acknowledge reading these details',
            () => perform(
              context,
              () => store.acknowledgeAgreement(t.id),
              success: 'Your read acknowledgement was saved.',
            ),
            icon: Icons.fact_check_outlined,
          ),
        if (store.researchReady) ...[
          if (owner && t.userId.isEmpty)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Private account invitation'),
                  const Text(
                    'The room is already assigned. Share this private invitation only with this tenant. They use it once to create their own login; no room number is entered at registration.',
                  ),
                  gap(12),
                  SelectableText(t.invitation ?? 'Unavailable'),
                  if (t.invitation?.startsWith('JOIN-') == true)
                    action(
                      'Copy tenant invitation',
                      () => perform(
                        context,
                        () => Clipboard.setData(
                          ClipboardData(text: t.invitation!),
                        ),
                        success: 'Private tenant invitation copied.',
                      ),
                      icon: Icons.copy,
                    ),
                ],
              ),
            ),
          if (owner)
            action(
              'Record money received',
              () => open(context, ResearchPaymentEntry(tenancyId: t.id)),
            ),
          action(
            'Rental documents / supporting files',
            () => open(context, RentalDocuments(tenancyId: t.id)),
            icon: Icons.folder_outlined,
          ),
          action(
            'Deposit account',
            () => open(
              context,
              RentalRecordsScreen(tenancyId: t.id, kind: 'deposit'),
            ),
          ),
          action(
            'Inspections and defects',
            () => open(
              context,
              RentalRecordsScreen(tenancyId: t.id, kind: 'inspection'),
            ),
          ),
          action(
            'Repairs and account queries',
            () => open(
              context,
              RentalRecordsScreen(tenancyId: t.id, kind: 'repair'),
            ),
          ),
          action(
            'Charge adjustments',
            () => open(
              context,
              RentalRecordsScreen(tenancyId: t.id, kind: 'adjustment'),
            ),
          ),
          action(
            'Rental change history',
            () => open(
              context,
              RentalRecordsScreen(tenancyId: t.id, kind: 'audit'),
            ),
          ),
          if (owner) ...[
            action(
              'Record agreed rent change',
              () => recordRentChange(context, t.id),
            ),
            if (t.endedOn == null)
              action(
                'Record completed handover',
                () => closeTenancy(context, t.id),
              ),
          ],
        ],
        const Text(
          'This is a rental information record, not a signed legal lease. A read acknowledgement is not a signature. Keep the parties’ signed agreement separately. Rent and due-day changes require a separate agreement; this record preserves the existing rent terms.',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.8),
        ),
        gap(18),
        action(
          'Monthly rental account',
          () => open(context, RentalAccountScreen(tenancyId: t.id)),
          icon: Icons.calendar_month_outlined,
        ),
        action(
          'Payment history',
          () => open(context, PaymentsScreen(tenancyId: t.id)),
          icon: Icons.receipt_long_outlined,
        ),
        action(
          'View property and location',
          () => open(context, PropertyDetailsScreen(propertyId: p.id)),
          icon: Icons.location_on_outlined,
        ),
        if (owner && t.userId.isNotEmpty)
          action(
            'Send rent reminder',
            () => reminder(context, t.id, periodOf(DateTime.now())),
            icon: Icons.notifications_active_outlined,
          ),
      ],
    );
  }
}

class AgreementEditor extends StatefulWidget {
  final String tenancyId;
  const AgreementEditor({super.key, required this.tenancyId});
  @override
  State<AgreementEditor> createState() => _AgreementEditorState();
}

class _AgreementEditorState extends State<AgreementEditor> {
  final form = GlobalKey<FormState>();
  final controls = {
    for (final k in [
      'start',
      'end',
      'deposit',
      'received',
      'utilities',
      'rules',
      'emergencyName',
      'emergencyPhone',
      'landlordAddress',
      'tenantAddress',
      'authority',
      'dwellingDescription',
      'sharedFacilities',
      'paymentInstructions',
      'noticeTerms',
      'escalationTerms',
      'otherCharges',
    ])
      k: TextEditingController(),
  };
  bool initialized = false, busy = false;
  String type = 'Month-to-month';
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final t = StoreScope.of(context).tenancy(widget.tenancyId);
    controls['start']!.text =
        t.leaseStart?.toIso8601String().split('T').first ??
        t.record['tenancyStartedOn'] ??
        '${t.startPeriod}-01';
    controls['end']!.text =
        t.leaseEnd?.toIso8601String().split('T').first ?? '';
    controls['deposit']!.text = ((t.depositCents ?? 0) / 100).toStringAsFixed(
      2,
    );
    controls['received']!.text = ((t.depositReceivedCents ?? 0) / 100)
        .toStringAsFixed(2);
    controls['utilities']!.text = t.utilities;
    controls['rules']!.text = t.houseRules;
    controls['emergencyName']!.text = t.emergencyName;
    controls['emergencyPhone']!.text = t.emergencyPhone;
    for (final key in [
      'landlordAddress',
      'tenantAddress',
      'authority',
      'dwellingDescription',
      'sharedFacilities',
      'paymentInstructions',
      'noticeTerms',
      'escalationTerms',
      'otherCharges',
    ]) {
      controls[key]!.text = t.record[key] ?? '';
    }
    type = t.agreementType == 'Fixed term' ? 'Fixed term' : 'Month-to-month';
    initialized = true;
  }

  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime parseDate(String text) {
    final d = DateTime.tryParse(text.trim());
    if (d == null || d.toIso8601String().split('T').first != text.trim())
      throw const FormatException('Enter a real date in YYYY-MM-DD format.');
    return d;
  }

  int amount(String value) => RegExp(r'^0(?:\.0{1,2})?$').hasMatch(value.trim())
      ? 0
      : parseMoney(value);
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await StoreScope.of(context).saveAgreement(
        widget.tenancyId,
        start: parseDate(controls['start']!.text),
        end: type == 'Fixed term' ? parseDate(controls['end']!.text) : null,
        agreementType: type,
        depositCents: amount(controls['deposit']!.text),
        depositReceivedCents: amount(controls['received']!.text),
        utilities: controls['utilities']!.text,
        houseRules: controls['rules']!.text,
        emergencyName: controls['emergencyName']!.text,
        emergencyPhone: controls['emergencyPhone']!.text,
        details: {
          for (final key in [
            'landlordAddress',
            'tenantAddress',
            'authority',
            'dwellingDescription',
            'sharedFacilities',
            'paymentInstructions',
            'noticeTerms',
            'escalationTerms',
            'otherCharges',
          ])
            key: controls[key]!.text,
        },
      );
      if (mounted && ModalRoute.of(context)?.isCurrent == true)
        Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String key,
    String label, {
    bool optional = false,
    bool multiline = false,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: TextFormField(
      key: ValueKey('lease-$key'),
      controller: controls[key],
      enabled: !busy,
      maxLines: multiline ? 3 : 1,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: optional ? null : requiredField,
    ),
  );
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Rental agreement details',
    maxWidth: 740,
    children: [
      heading('Put the important details in writing.'),
      const Text(
        'Record the actual agreement, not assumed terms. Start dates with payment history are protected. A planned end date does not record handover. Deposits and agreed partial-month corrections have separate transaction records.',
        style: TextStyle(color: Palette.muted, height: 1.8),
      ),
      gap(18),
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Rental type'),
              items: [
                'Month-to-month',
                'Fixed term',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: busy ? null : (v) => setState(() => type = v!),
            ),
            field('start', 'Occupancy start (YYYY-MM-DD)'),
            if (type == 'Fixed term')
              field('end', 'Occupancy end (YYYY-MM-DD)'),
            field('deposit', 'Agreed deposit (rand; 0 if none)', numeric: true),
            if (!StoreScope.of(context).researchReady)
              field(
                'received',
                'Deposit already received (rand)',
                numeric: true,
              ),
            if (StoreScope.of(context).researchReady) ...[
              for (final entry in const {
                'landlordAddress': 'Landlord formal-notice address',
                'tenantAddress': 'Tenant formal-notice address',
                'authority': 'Owner / agent / lawful authority to let',
                'dwellingDescription':
                    'Exact dwelling, room or yard-space description',
                'sharedFacilities':
                    'Shared facilities and access (None if not applicable)',
                'paymentInstructions':
                    'Agreed payment instructions (never PINs or passwords)',
                'noticeTerms': 'Notice, termination and continuation agreement',
                'escalationTerms':
                    'Agreed escalation and notice (None if none)',
                'otherCharges':
                    'Additional charges and calculation (None if none)',
              }.entries)
                field(entry.key, entry.value, multiline: true),
            ],
            field(
              'utilities',
              'Who pays water, electricity and other utilities?',
              multiline: true,
            ),
            field(
              'rules',
              'House rules and agreed notice / termination terms',
              multiline: true,
            ),
            field(
              'emergencyName',
              'Emergency contact name (optional)',
              optional: true,
            ),
            field(
              'emergencyPhone',
              'Emergency contact phone (optional)',
              optional: true,
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Palette.red)),
            action(
              busy ? 'Saving…' : 'Save rental details',
              busy ? null : save,
              icon: Icons.save_outlined,
            ),
          ],
        ),
      ),
    ],
  );
}
