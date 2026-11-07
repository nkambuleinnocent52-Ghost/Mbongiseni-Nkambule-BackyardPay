import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/common.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/simple_rentals.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/room_rents.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  test(
    'Room-specific rates survive serialization, other rooms inherit default',
    () {
      final p = RentalProperty(
        id: 'p',
        landlordId: 'l',
        name: 'Rooms',
        address: 'Address',
        code: 'private',
        rooms: 10,
        rentCents: 150000,
        dueDay: 1,
        roomRents: const {'6': 200000, '7': 210000},
      );
      final restored = RentalProperty.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      );
      expect(restored.rentForRoom(6), 200000);
      expect(restored.rentForRoom(7), 210000);
      expect(restored.rentForRoom(1), 150000);
    },
  );
  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await seedTestAccounts(store);
    await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
    store.researchVersion = 2;
  });
  tearDown(() => store.dispose());
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(theme: backyardTheme(), home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Rental overview removes the button wall and expands deposit in place',
    (tester) async {
      await pump(
        tester,
        SimpleRentalDetails(tenancyId: store.tenancies.first.id),
      );
      for (final removed in [
        'Rental documents / supporting files',
        'Inspections and defects',
        'Charge adjustments',
        'Rental change history',
        'Record completed handover',
        'Record agreed rent change',
      ])
        expect(find.text(removed), findsNothing);
      expect(find.text('Record money received'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Security deposit'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Security deposit'));
      await tester.pumpAndSettle();
      expect(find.text('Deposit received'), findsOneWidget);
      expect(find.text('Deposit account'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Room rate editor selects several rooms without an extra screen',
    (tester) async {
      await pump(
        tester,
        PageShell(
          title: 'Rooms',
          children: [RoomRentEditor(propertyId: store.properties.first.id)],
        ),
      );
      await tester.tap(find.text('Room rent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Room 2'));
      await tester.tap(find.text('Room 3'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Room 2'), findsOneWidget);
      expect(
        find.text('Monthly rent for selected rooms (rand)'),
        findsOneWidget,
      );
      await tester.tap(find.text('Use property default'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly rent for selected rooms (rand)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
