import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import 'property_terms.dart';

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
    controls['deposit']!.text = t.depositCents == null
        ? ''
        : (t.depositCents! / 100).toStringAsFixed(2);
    controls['received']!.text = ((t.depositReceivedCents ?? 0) / 100)
        .toStringAsFixed(2);
    controls['utilities']!.text = t.utilities;
    controls['rules']!.text = t.houseRules;
    controls['emergencyName']!.text = t.emergencyName;
    controls['emergencyPhone']!.text = t.emergencyPhone;
    final property = StoreScope.of(context).property(t.propertyId);
    final defaults = StoreScope.of(context).agreementDefaultsFor(t.propertyId);
    if (controls['utilities']!.text.isEmpty)
      controls['utilities']!.text = defaults['utilities'] ?? '';
    if (controls['rules']!.text.isEmpty)
      controls['rules']!.text = defaults['houseRules'] ?? '';
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
      controls[key]!.text =
          (t.record[key]?.toString().trim().isNotEmpty == true
              ? t.record[key]
              : defaults[key]) ??
          '';
    }
    if (controls['tenantAddress']!.text.isEmpty)
      controls['tenantAddress']!.text =
          '${property.fullAddress}, Room ${t.room}';
    if (controls['dwellingDescription']!.text.isEmpty)
      controls['dwellingDescription']!.text =
          'Room ${t.room} at ${property.fullAddress}';
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
    final missing = controls.entries
        .where(
          (e) =>
              ![
                'end',
                'emergencyName',
                'emergencyPhone',
                'received',
              ].contains(e.key) &&
              e.value.text.trim().isEmpty,
        )
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      setState(
        () => error = 'Complete This tenant and room and Property terms before saving. Use Manage property terms to enter shared information once.',
      );
      return;
    }
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
    String? help,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: TextFormField(
      key: ValueKey('lease-$key'),
      controller: controls[key],
      enabled: !busy,
      readOnly: readOnly,
      maxLines: multiline ? 2 : 1,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        helperMaxLines: 3,
      ),
      validator: optional ? null : requiredField,
    ),
  );
  Widget group(String title, List<Widget> children, {bool expanded = false}) =>
      Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          title: Text(title),
          childrenPadding: const EdgeInsets.all(16),
          children: children,
        ),
      );

  void usePropertyDefaults() {
    final s = StoreScope.of(context), t = s.tenancy(widget.tenancyId);
    final defaults = s.agreementDefaultsFor(t.propertyId);
    setState(() {
      for (final key in propertyTermLabels.keys) {
        final controlKey = key == 'houseRules' ? 'rules' : key;
        if (controls.containsKey(controlKey))
          controls[controlKey]!.text = defaults[key] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        t = s.tenancy(widget.tenancyId),
        p = s.property(t.propertyId);
    return PageShell(
      title: 'Rental agreement details',
      maxWidth: 740,
      children: [
        heading('${p.name} · Room ${t.room}'),
        const Text(
          'Rent is due on the 1st. Move-in date and security deposit come from onboarding.',
          style: TextStyle(color: Palette.muted),
        ),
        gap(14),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Move-in date', controls['start']!.text),
              detail(
                'Security deposit',
                t.depositCents == null
                    ? 'Not recorded'
                    : money(t.depositCents!),
              ),
              const Text(
                'These amounts and dates cannot be changed here.',
                style: TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (t.depositCents == null)
                field(
                  'deposit',
                  'Security deposit for this rental (rand; 0 if none)',
                  numeric: true,
                  help: 'Record the original requirement once. It cannot be changed here after saving.',
                ),
              group('Rental duration', [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'How long is this rental?',
                    helperText:
                        'Duration is separate from the monthly rent amount.',
                    helperMaxLines: 2,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Month-to-month',
                      child: Text('Ongoing monthly rental'),
                    ),
                    DropdownMenuItem(
                      value: 'Fixed term',
                      child: Text('Rental with an agreed end date'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => type = value!),
                ),
                gap(12),
                Text(
                  type == 'Month-to-month'
                      ? 'Continues each month until ended with the required notice.'
                      : 'Runs until the agreed end date; changing rent still needs the applicable agreement and notice.',
                  style: const TextStyle(color: Palette.muted),
                ),
                if (type == 'Fixed term')
                  field(
                    'end',
                    'Agreed end date (YYYY-MM-DD)',
                    help: 'A planned end date does not confirm that the keys were returned.',
                  ),
              ], expanded: true),
              group('This tenant and room', [
                field(
                  'tenantAddress',
                  'Address for notices to this tenant',
                  multiline: true,
                  help: 'Where written rental notices should be delivered. Usually this property and room.',
                ),
                field(
                  'dwellingDescription',
                  'Room description',
                  multiline: true,
                  help: 'Identify the room and any space rented with it.',
                ),
                field(
                  'emergencyName',
                  'Emergency contact name (optional)',
                  optional: true,
                  help: 'Someone the tenant agrees may be contacted in an emergency.',
                ),
                field(
                  'emergencyPhone',
                  'Emergency contact phone (optional)',
                  optional: true,
                ),
              ], expanded: true),
              group('Property terms', [
                const Text(
                  'Shared terms are saved once for the property. Each rental keeps its own recorded copy; editing the property defaults does not rewrite existing agreements.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => open(
                              context,
                              PropertyTermsScreen(propertyId: p.id),
                            ),
                      child: const Text('Manage property terms'),
                    ),
                    if (s.agreementDefaultsFor(p.id).isNotEmpty)
                      TextButton(
                        onPressed: busy ? null : usePropertyDefaults,
                        child: const Text('Use current property terms'),
                      ),
                  ],
                ),
                for (final entry in propertyTermLabels.entries)
                  detail(
                    entry.value,
                    controls[entry.key == 'houseRules' ? 'rules' : entry.key]!
                            .text
                            .isEmpty
                        ? 'Set up property terms first'
                        : controls[entry.key == 'houseRules'
                                  ? 'rules'
                                  : entry.key]!
                              .text,
                  ),
              ]),
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
}
