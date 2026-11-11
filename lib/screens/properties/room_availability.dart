import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';

class RoomAvailability extends StatelessWidget {
  final String propertyId;
  final DateTime? moveIn;
  const RoomAvailability({super.key, required this.propertyId, this.moveIn});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.currentUser?.role != Role.landlord)
      return const SizedBox.shrink();
    final p = store.property(propertyId), date = moveIn ?? DateTime.now();
    final available = store.availableRoomNumbers(p.id, from: date).toSet();
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Room availability'),
          Text(
            '${available.length} available • ${p.rooms - available.length} unavailable • ${p.rooms} total',
          ),
          Text(
            'For a new tenancy starting ${date.toIso8601String().split('T').first}',
          ),
          gap(12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var room = 1; room <= p.rooms; room++)
                Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: available.contains(room)
                          ? Palette.green
                          : Palette.border,
                    ),
                  ),
                  child: Text(
                    'Room $room: ${available.contains(room) ? 'Available' : 'Unavailable'}\n${money(p.rentForRoom(room))} / month',
                    style: TextStyle(
                      color: available.contains(room)
                          ? Palette.green
                          : Palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          gap(12),
          Text(
            available.isEmpty
                ? 'No rooms are available for this move-in date. Record the actual handover before assigning an occupied room.'
                : 'Choose one of the available rooms when onboarding.',
          ),
          const Text(
            'Rooms become available the day after they are returned. Availability is checked again when you save.',
            style: TextStyle(color: Palette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
