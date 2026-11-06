import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/common.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/payment_entry.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/research_records.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/rental_account.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await seedTestAccounts(store);
    await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
    store.researchVersion = 2;
  });
  tearDown(() => store.dispose());
  for (final name in ['payment', 'deposit', 'inspection', 'account']) {
    testWidgets('research $name form fits a 320 pixel phone', (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = store.tenancies.first.id;
      final Widget page = switch (name) {
        'payment' => ResearchPaymentEntry(tenancyId: id),
        'account' => RentalAccountScreen(tenancyId: id),
        _ => RecordEditor(tenancyId: id, kind: name),
      };
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(theme: backyardTheme(), home: page),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
