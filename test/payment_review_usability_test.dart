import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/payments/payment_entry.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/common.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await seedTestAccounts(store);
    await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
  });
  tearDown(() => store.dispose());
  Future<void> pump(WidgetTester tester, {String? payment}) async {
    store.researchVersion = 2;
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: backyardTheme(),
          home: ResearchPaymentEntry(
            tenancyId: store.tenancies.first.id,
            paymentId: payment,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'extra rent is proposed for next month before the tenant submits',
    (tester) async {
      await pump(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '2000.00');
      await tester.pumpAndSettle();
      final values = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .map((w) => w.controller?.text)
          .toList();
      expect(values, contains('1500.00'));
      expect(values, contains('500.00'));
      expect(find.textContaining('Extra money is proposed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'landlord confirms tenant amounts without changing their months',
    (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await store.submitPayment(
          tenancyId: store.tenancies.first.id,
          period: periodOf(DateTime.now()),
          amountCents: 150000,
          method: 'Cash',
          paidOn: DateTime.now(),
          reference: store.newReference,
        );
        await store.logout();
        await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
      });
      await pump(tester, payment: id);
      for (final f in tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      )) {
        expect(f.onChanged, isNull);
      }
      expect(
        find.textContaining('The tenant chose these rent months'),
        findsOneWidget,
      );
      expect(find.text('Paying for another month? Add it'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
