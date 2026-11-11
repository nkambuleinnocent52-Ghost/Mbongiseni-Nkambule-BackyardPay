import 'package:flutter/material.dart';

import '../../ui/design.dart';
import '../shared/common.dart';
import 'research_records.dart' show isoDay, checkedDate;

import 'rental_forms.dart';

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
