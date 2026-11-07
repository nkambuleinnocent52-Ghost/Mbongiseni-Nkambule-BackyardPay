import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/design.dart';
import 'common.dart';
import 'simple_rentals.dart';

class RoomRentEditor extends StatefulWidget {
  final String propertyId;
  const RoomRentEditor({super.key, required this.propertyId});
  @override
  State<RoomRentEditor> createState() => _RoomRentEditorState();
}

class _RoomRentEditorState extends State<RoomRentEditor> {
  final selected = <int>{};
  final amount = TextEditingController();
  bool useDefault = false, busy = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), p = s.property(widget.propertyId);
    return RentalSection(
      title: 'Room rent',
      subtitle:
          'Default ${money(p.rentCents)} / month · ${p.roomRents.length} custom rates',
      children: [
        const Text(
          'All rooms use the default monthly rent unless you set a different amount. Select one or more rooms below.',
        ),
        gap(12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 1; n <= p.rooms; n++)
              FilterChip(
                label: Text('Room $n'),
                selected: selected.contains(n),
                onSelected: busy
                    ? null
                    : (v) => setState(() {
                        if (v) {
                          selected.add(n);
                        } else {
                          selected.remove(n);
                        }
                      }),
              ),
          ],
        ),
        if (selected.isNotEmpty) ...[
          gap(12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use property default'),
            value: useDefault,
            onChanged: busy ? null : (v) => setState(() => useDefault = v),
          ),
          if (!useDefault)
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly rent for selected rooms (rand)',
              ),
            ),
          gap(12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok = await perform(context, () async {
                        final rates = Map<String, int>.from(p.roomRents);
                        final cents = useDefault
                            ? null
                            : parseMoney(amount.text);
                        for (final n in selected) {
                          if (useDefault) {
                            rates.remove('$n');
                          } else {
                            rates['$n'] = cents!;
                          }
                        }
                        await s.researchAction('room_rents', {
                          'propertyId': p.id,
                          'rates': rates,
                        });
                      }, success: 'Room rents saved for new tenants.');
                      if (mounted)
                        setState(() {
                          busy = false;
                          if (ok) selected.clear();
                        });
                    },
              child: Text(busy ? 'Saving…' : 'Save room rent'),
            ),
          ),
        ],
        gap(12),
        for (final e in p.roomRents.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Room ${e.key} · ${money(e.value)} / month'),
          ),
        const Text(
          'New tenants use these room rates. Existing tenants keep their agreed rent; change it in their rental details with an effective month.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ],
    );
  }
}
