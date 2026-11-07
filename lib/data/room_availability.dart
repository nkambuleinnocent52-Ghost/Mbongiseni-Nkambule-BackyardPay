import '../models/models.dart';

/// Matches onboarding's indefinite-tenancy overlap rule: an existing record
/// blocks the room unless its actual handover was before the new move-in day.
List<int> availableRoomsFor(
  RentalProperty property,
  Iterable<Tenancy> tenancies,
  DateTime moveIn, {
  bool actualHandover = true,
}) {
  final day = DateTime(moveIn.year, moveIn.month, moveIn.day);
  final blocked = <int>{};
  for (final t in tenancies.where((t) => t.propertyId == property.id)) {
    final end = actualHandover ? t.endedOn : t.leaseEnd;
    if (end == null || !DateTime(end.year, end.month, end.day).isBefore(day)) {
      final room = int.tryParse(t.room);
      if (room != null) blocked.add(room);
    }
  }
  return [
    for (var room = 1; room <= property.rooms; room++)
      if (!blocked.contains(room)) room,
  ];
}
