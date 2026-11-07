import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/room_availability.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

void main() {
  const p = RentalProperty(
    id: 'p',
    landlordId: 'l',
    name: 'Rooms',
    address: '1 Test Street',
    code: 'CODE',
    rooms: 4,
    rentCents: 150000,
    dueDay: 1,
  );
  Tenancy t(
    String id,
    String room, {
    DateTime? end,
    DateTime? planned,
    String property = 'p',
  }) => Tenancy(
    id: id,
    userId: 'u',
    propertyId: property,
    room: room,
    startPeriod: '2026-01',
    rentCents: 150000,
    dueDay: 1,
    endedOn: end,
    leaseEnd: planned,
  );
  test('lists exact free rooms and does not free a room on planned expiry', () {
    expect(
      availableRoomsFor(p, [
        t('one', '1', planned: DateTime(2026, 10, 1)),
        t('two', '2', end: DateTime(2026, 11, 6)),
        t('three', '3', end: DateTime(2026, 11, 7)),
      ], DateTime(2026, 11, 7)),
      [2, 4],
    );
  });
  test(
    'handover day is inclusive and selected historical date is respected',
    () {
      final tenants = [t('one', '1', end: DateTime(2026, 11, 7))];
      expect(
        availableRoomsFor(p, tenants, DateTime(2026, 11, 7)).contains(1),
        false,
      );
      expect(
        availableRoomsFor(p, tenants, DateTime(2026, 11, 8)).contains(1),
        true,
      );
      expect(
        availableRoomsFor(p, tenants, DateTime(2026, 11, 6)).contains(1),
        false,
      );
    },
  );
  test(
    'history is counted by room and another property cannot block a room',
    () {
      expect(
        availableRoomsFor(p, [
          t('old', '1', end: DateTime(2025, 1, 1)),
          t('current', '1'),
          t('elsewhere', '2', property: 'other'),
        ], DateTime(2026, 11, 7)),
        [2, 3, 4],
      );
    },
  );
  test(
    'all occupied produces no selectable rooms and none occupied lists all',
    () {
      expect(availableRoomsFor(p, [], DateTime(2026, 11, 7)), [1, 2, 3, 4]);
      expect(
        availableRoomsFor(p, [
          for (var n = 1; n <= 4; n++) t('$n', '$n'),
        ], DateTime(2026, 11, 7)),
        isEmpty,
      );
    },
  );
}
