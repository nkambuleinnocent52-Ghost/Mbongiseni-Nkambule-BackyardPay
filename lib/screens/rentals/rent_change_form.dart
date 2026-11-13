import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import '../shared/dashboard_widgets.dart' show monthLabel;

/// Records a change for one existing tenancy; it never changes the rent due day.
class RentChangeForm extends StatefulWidget {
  final String tenancyId;
  const RentChangeForm({super.key, required this.tenancyId});
  @override
  State<RentChangeForm> createState() => _RentChangeFormState();
}

class _RentChangeFormState extends State<RentChangeForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), evidence = TextEditingController();
  late final months = [
    for (var n = 1; n <= 60; n++)
      periodOf(DateTime(DateTime.now().year, DateTime.now().month + n)),
  ];
  late String effective = months.first;
  bool busy = false, agreementChecked = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    evidence.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (!agreementChecked) {
      setState(
        () => error = 'Confirm the agreement or required notice before recording this change.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final s = StoreScope.of(context);
      if (s.rentTerms.any(
        (r) => r['tenancyId'] == widget.tenancyId && r['period'] == effective,
      ))
        throw ArgumentError(
          'This rental already has a rent amount recorded for ${monthLabel(effective)}. Choose another month.',
        );
      await s.researchAction('rent_term', {
        'tenancyId': widget.tenancyId,
        'period': effective,
        'amountCents': parseMoney(amount.text),
        'dueDay': 1,
        'evidence': evidence.text.trim(),
      });
      if (mounted) {
        amount.clear();
        evidence.clear();
        setState(() {
          agreementChecked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rent change recorded. The tenant can see the new amount and month.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), t = s.tenancy(widget.tenancyId);
    final current =
        s.research.rate(t, periodOf(DateTime.now()))?['amountCents'] as int? ??
        t.rentCents;
    int? proposed;
    try {
      proposed = parseMoney(amount.text);
    } catch (_) {}
    final difference = proposed == null ? null : proposed - current;
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Only ${s.tenantAccount(t).name} · Room ${t.room}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          gap(8),
          Text('Current rent: ${money(current)} per month · due on the 1st'),
          gap(14),
          DropdownButtonFormField<String>(
            initialValue: effective,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'New rent starts',
              helperText:
                  'The month the amount changes. Rent is still due on the 1st.',
              helperMaxLines: 2,
            ),
            items: [
              for (final m in months)
                DropdownMenuItem(value: m, child: Text(monthLabel(m))),
            ],
            onChanged: busy ? null : (v) => setState(() => effective = v!),
          ),
          gap(14),
          TextFormField(
            controller: amount,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'New monthly rent (rand)',
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              try {
                parseMoney(v ?? '');
                return null;
              } catch (_) {
                return 'Enter the new monthly rent.';
              }
            },
          ),
          if (difference != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                difference == 0
                    ? 'No change to the current rent.'
                    : '${difference > 0 ? 'Increase' : 'Decrease'}: ${money(difference.abs())} per month from ${monthLabel(effective)}',
                style: const TextStyle(color: Palette.goldLight),
              ),
            ),
          gap(12),
          TextFormField(
            controller: evidence,
            enabled: !busy,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Agreement or notice reference',
              helperText: 'For example: signed agreement or written notice dated 12 November.',
              helperMaxLines: 2,
            ),
            validator: (v) => (v?.trim().length ?? 0) < 3
                ? 'Record the actual agreement or notice reference.'
                : null,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: agreementChecked,
            onChanged: busy
                ? null
                : (v) => setState(() => agreementChecked = v ?? false),
            title: const Text(
              'I checked the rental agreement and any required notice.',
            ),
          ),
          const Text(
            'Saving records this change for this rental. It does not itself make an increase lawful or change every room’s rent.',
            style: TextStyle(color: Palette.muted, fontSize: 12),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Palette.red)),
          Align(
            alignment: Alignment.centerLeft,
            child: action(
              busy ? 'Saving…' : 'Save rent change',
              busy ? null : save,
              icon: Icons.save_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
