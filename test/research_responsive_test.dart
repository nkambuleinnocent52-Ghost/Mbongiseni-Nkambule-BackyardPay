import 'package:mbongiseni_nkambule_apt_application/screens/auth.dart';

import 'dart:convert';

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
  for (final name in [
    'payment',
    'deposit',
    'inspection',
    'account',
    'repair',
  ]) {
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
  testWidgets('onboarding previews January 15 charge before saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: backyardTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => createTenantRecord(context),
                child: const Text('Onboard'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Onboard'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enter tenant details'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter tenant details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('start')), '2026-01-15');
    await tester.pumpAndSettle();
    expect(find.textContaining('R 822.58'), findsNWidgets(2));
    expect(find.textContaining('R 2822.58'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'onboarding offers only available rooms and lists occupied room',
    (tester) async {
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: backyardTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => createTenantRecord(context),
                  child: const Text('Onboard'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Onboard'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Enter tenant details'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enter tenant details'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Room number'), findsNothing);
      final dropdown = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Available room',
      );
      expect(dropdown, findsOneWidget);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.text('Room 1'), findsNothing);
      expect(find.text('Room 2'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('room selection is cleared if another tenancy takes the room', (
    tester,
  ) async {
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: backyardTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => createTenantRecord(context),
                child: const Text('Onboard'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Onboard'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enter tenant details'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter tenant details'));
    await tester.pumpAndSettle();
    final finder = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == 'Available room',
    );
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Room 2').last);
    await tester.pumpAndSettle();
    expect(
      (tester.widget(finder) as DropdownButtonFormField<String>).initialValue,
      '2',
    );
    final storage = store.storage as MemoryStorage;
    final data = jsonDecode(storage.data!) as Map<String, dynamic>;
    data['researchVersion'] = 2;
    data['tenancies'].add({
      ...data['tenancies'][0],
      'id': 'new-room-2',
      'room': '2',
      'userId': '',
    });
    storage.data = jsonEncode(data);
    await store.load();
    await tester.pumpAndSettle();
    expect(
      (tester.widget(finder) as DropdownButtonFormField<String>).initialValue,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('a full property shows no selectable rooms', (tester) async {
    final storage = store.storage as MemoryStorage;
    final data = jsonDecode(storage.data!) as Map<String, dynamic>;
    data['researchVersion'] = 2;
    for (var n = 2; n <= 4; n++)
      data['tenancies'].add({
        ...data['tenancies'][0],
        'id': 'full-$n',
        'room': '$n',
        'userId': '',
      });
    storage.data = jsonEncode(data);
    await store.load();
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: backyardTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => createTenantRecord(context),
                child: const Text('Onboard'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Onboard'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enter tenant details'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter tenant details'));
    await tester.pumpAndSettle();
    final finder = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == 'Available room',
    );
    final inner = find
        .descendant(
          of: finder,
          matching: find.byWidgetPredicate((w) => w is DropdownButton<String>),
        )
        .first;
    expect((tester.widget(inner) as DropdownButton<String>).onChanged, isNull);
    expect(find.textContaining('No rooms available'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'tenant registration has invitation only, without a room chooser',
    (tester) async {
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: backyardTheme(),
            home: const AuthScreen(role: Role.tenant),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Create an account'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room')), findsNothing);
      expect(find.byKey(const ValueKey('code')), findsOneWidget);
      expect(
        find.textContaining('You do not choose a room here'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
