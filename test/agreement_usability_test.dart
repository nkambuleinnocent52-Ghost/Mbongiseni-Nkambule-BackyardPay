import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/rentals/agreement_editor.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/rentals/rent_change_form.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/common.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await seedTestAccounts(store);
    await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
    final t = store.tenancies.first;
    await store.saveAgreement(
      t.id,
      start: t.leaseStart ?? periodDate(t.startPeriod),
      agreementType: 'Month-to-month',
      depositCents: 200000,
      depositReceivedCents: 0,
      utilities: 'Water included',
      houseRules: 'Keep yard clear',
    );
    store.researchVersion = 2;
  });
  tearDown(() => store.dispose());

  testWidgets(
    'rental details show fixed move-in/deposit and explain duration',
    (tester) async {
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: backyardTheme(),
            home: AgreementEditor(tenancyId: store.tenancies.first.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Move-in date:'), findsOneWidget);
      expect(find.textContaining('Security deposit:'), findsOneWidget);
      expect(find.byKey(const ValueKey('lease-start')), findsNothing);
      expect(find.byKey(const ValueKey('lease-deposit')), findsNothing);
      expect(find.text('Ongoing monthly rental'), findsOneWidget);
      expect(
        find.text('Continues each month until ended with the required notice.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rent change selects a month and previews this tenant’s increase',
    (tester) async {
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: backyardTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RentChangeForm(tenancyId: store.tenancies.first.id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New rent starts'), findsOneWidget);
      expect(find.textContaining('Only Test Tenant'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      final amount = find.widgetWithText(
        TextFormField,
        'New monthly rent (rand)',
      );
      await tester.enterText(amount, '1800');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Increase: R 300.00 per month'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Rent is still due on the 1st.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'current agreement adapter protects onboarding dates and deposit',
    () async {
      final t = store.tenancies.first;
      final start = t.leaseStart ?? periodDate(t.startPeriod);
      Future<void> save(DateTime date, int deposit) => store.saveAgreement(
        t.id,
        start: date,
        agreementType: 'Month-to-month',
        depositCents: deposit,
        depositReceivedCents: 0,
        utilities: 'Water included',
        houseRules: 'Keep yard clear',
      );
      await expectLater(
        save(start.add(const Duration(days: 1)), t.depositCents!),
        throwsArgumentError,
      );
      await expectLater(save(start, t.depositCents! + 1), throwsArgumentError);
    },
  );

  test(
    'property defaults persist without altering existing rental terms',
    () async {
      final t = store.tenancies.first;
      final before = t.toJson();
      await store.savePropertyAgreement(t.propertyId, {
        'landlordAddress': '1 Owner Road',
        'utilities': 'Water included',
      });
      expect(
        store.agreementDefaultsFor(t.propertyId)['landlordAddress'],
        '1 Owner Road',
      );
      expect(store.tenancy(t.id).toJson(), before);
      await store.logout();
      await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
      await expectLater(
        store.savePropertyAgreement(t.propertyId, {'utilities': 'Changed'}),
        throwsStateError,
      );
    },
  );
}
