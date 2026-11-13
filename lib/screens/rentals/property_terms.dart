import 'package:flutter/material.dart';

import '../shared/common.dart';
import '../../ui/design.dart';

/// Shared once per property. A tenancy stores a copy instead of a live link.
const propertyTermLabels = {
  'landlordAddress': 'Landlord address for written notices',
  'authority': 'Your authority to rent out this property',
  'sharedFacilities': 'Shared spaces and access',
  'paymentInstructions': 'How tenants should pay',
  'utilities': 'Water and electricity responsibilities',
  'houseRules': 'House rules',
  'noticeTerms': 'Notice to end the rental',
  'escalationTerms': 'Terms for future rent changes',
  'otherCharges': 'Other charges',
};
const propertyTermHelp = {
  'landlordAddress': 'An address where the landlord can receive formal written rental notices.',
  'authority': 'For example: property owner, or an agent authorised by the owner. This records your statement; it does not verify ownership.',
  'sharedFacilities': 'For example: shared bathroom, outside tap and gate access. Enter None if there are no shared facilities.',
  'paymentInstructions': 'Record cash arrangements or bank/payment instructions tenants need. Never enter a PIN or password.',
  'utilities': 'State who pays water, electricity and any shared services.',
  'houseRules': 'Rules that apply to tenants at this property.',
  'noticeTerms': 'Record the actual notice arrangement and applicable requirements; the app does not create a right to evict.',
  'escalationTerms': 'Record what the rental agreement says about increases. Enter None if there is no increase clause.',
  'otherCharges': 'State each charge and how it is calculated, or None if there are no additional charges.',
};

class PropertyTermsScreen extends StatefulWidget {
  final String propertyId;
  const PropertyTermsScreen({super.key, required this.propertyId});
  @override
  State<PropertyTermsScreen> createState() => _PropertyTermsScreenState();
}

class _PropertyTermsScreenState extends State<PropertyTermsScreen> {
  final form = GlobalKey<FormState>();
  final controls = {
    for (final key in propertyTermLabels.keys) key: TextEditingController(),
  };
  bool loaded = false, busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    final values = StoreScope.of(context)
        .agreementDefaultsFor(widget.propertyId);
    for (final key in controls.keys)
      controls[key]!.text = values[key]?.toString() ?? '';
    loaded = true;
  }

  @override
  void dispose() {
    for (final value in controls.values) value.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await StoreScope.of(context).savePropertyAgreement(widget.propertyId, {
        for (final e in controls.entries) e.key: e.value.text.trim(),
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
    final s = StoreScope.of(context), p = s.property(widget.propertyId);
    return PageShell(
      title: 'Property terms',
      maxWidth: 760,
      children: [
        heading(p.name),
        const Text(
          'Enter shared information once. New rentals use a copy; existing rental agreements stay unchanged.',
        ),
        gap(16),
        if (s.isCloud && s.agreementDefaultsVersion < 1)
          const Text(
            'The property-terms database update is required before saving.',
            style: TextStyle(color: Palette.red),
          ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in propertyTermLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: controls[entry.key],
                    enabled: !busy,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      helperText: propertyTermHelp[entry.key],
                      helperMaxLines: 3,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter the terms, or None where it does not apply.'
                        : v.length > 1500
                        ? 'Use no more than 1500 characters.'
                        : null,
                  ),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Palette.red)),
              action(
                busy ? 'Saving…' : 'Save property terms',
                busy || (s.isCloud && s.agreementDefaultsVersion < 1)
                    ? null
                    : save,
                icon: Icons.save_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
