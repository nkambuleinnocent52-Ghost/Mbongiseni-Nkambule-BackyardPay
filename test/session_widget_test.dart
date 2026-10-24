import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/main.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

import 'test_storage.dart';
import 'fixtures.dart';

void main() {
  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await seedTestAccounts(store);
    await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
  });
  tearDown(() => store.dispose());
  testWidgets('logout clears the session and leaves no authenticated screens', (
    tester,
  ) async {
    await tester.pumpWidget(BackyardPayApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Logout'));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(store.currentUser, isNull);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Tenant dashboard'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('deleting an empty property safely closes its details screen', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await store.logout();
      await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
      await store.saveProperty(
        name: 'Empty Test Property',
        address: 'East London',
        rooms: 1,
        rentCents: 100000,
        dueDay: 1,
      );
    });
    await tester.pumpWidget(BackyardPayApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('My properties'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('My properties'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My properties'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty Test Property'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete empty property'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete empty property'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      store.properties.where((p) => p.name == 'Empty Test Property'),
      isEmpty,
    );
    expect(find.text('My properties'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
