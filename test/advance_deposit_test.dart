import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/rent_payment_months.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/common.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/payments/deposit_payments.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/payments/payment_entry.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  Tenancy rental({String start = '2026-11', DateTime? endedOn}) => Tenancy(
    id: 'rental',
    userId: 'tenant',
    propertyId: 'property',
    room: '1',
    startPeriod: start,
    rentCents: 150000,
    dueDay: 1,
    endedOn: endedOn,
  );

  test('advance months include December and the next calendar year', () {
    final months = rentPaymentMonths(rental(), DateTime(2026, 11, 11));
    expect(months.first, '2026-11');
    expect(months, containsAllInOrder(['2026-11', '2026-12', '2027-01']));
    expect(months.last, '2027-11');
    expect(months.length, 13);
    expect(months.toSet().length, months.length);
  });

  test(
    'December rolls into January and actual handover limits payable months',
    () {
      final december = rentPaymentMonths(
        rental(start: '2026-12'),
        DateTime(2026, 12, 31),
      );
      expect(december.take(2), ['2026-12', '2027-01']);
      final returned = rentPaymentMonths(
        rental(endedOn: DateTime(2027, 1, 5)),
        DateTime(2026, 11, 11),
      );
      expect(returned, ['2026-11', '2026-12', '2027-01']);
      expect(returned, isNot(contains('2027-02')));
    },
  );

  late AppStore store;
  setUp(() async {
    final storage = MemoryStorage();
    store = AppStore(storage);
    await seedTestAccounts(store);
    final saved = jsonDecode(storage.data!) as Map<String, dynamic>;
    saved['researchVersion'] = 2;
    for (final tenancy in saved['tenancies']) {
      tenancy['depositCents'] = 200000;
      tenancy['depositReceivedCents'] = 0;
    }
    storage.data = jsonEncode(saved);
    await store.load();
    await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
  });
  tearDown(() => store.dispose());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(theme: backyardTheme(), home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> pendingReport() => {
    'id': 'pending-deposit',
    'tenancyId': store.tenancies.first.id,
    'amountCents': 100000,
    'method': 'Cash',
    'paidOn': periodOf(DateTime.now()) + '-01',
    'state': 'pending',
    'submittedAt': DateTime.now().toIso8601String(),
    'bankReference': '',
    'notes': '',
    'reason': '',
  };

  testWidgets(
    'when this month is paid, new rent report selects next month and its full rent',
    (tester) async {
      final tenancy = store.tenancies.first;
      final now = DateTime.now();
      final current = periodOf(now);
      await tester.runAsync(() async {
        final payment = await store.submitPayment(
          tenancyId: tenancy.id,
          period: current,
          amountCents: 150000,
          method: 'Cash',
          paidOn: now,
          reference: 'CURRENT-MONTH-PAID',
        );
        await store.logout();
        await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
        await store.reviewPayment(payment, confirm: true);
        await store.logout();
        await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
      });
      expect(store.outstanding(store.tenancies.first, current), 0);
      await pump(tester, ResearchPaymentEntry(tenancyId: tenancy.id));
      final next = periodOf(DateTime(now.year, now.month + 1));
      final monthSelector = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Month paid for',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(monthSelector)
            .initialValue,
        next,
      );
      final amounts = tester
          .widgetList<TextField>(find.byType(TextField))
          .where(
            (f) => [
              'How much did you pay? (rand)',
              'Amount for this month (rand)',
            ].contains(f.decoration?.labelText),
          )
          .toList();
      expect(amounts.length, 2);
      expect(amounts.map((f) => f.controller!.text), everyElement('1500.00'));
      expect(
        store
            .ledger(tenancy)
            .every((row) => row.period.compareTo(current) <= 0),
        isTrue,
      );
      expect(store.ledger(tenancy).last.closingBalanceCents, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tenant can switch rent purpose to security deposit without receipt-confirmation controls',
    (tester) async {
      final id = store.tenancies.first.id;
      await pump(tester, ResearchPaymentEntry(tenancyId: id));
      final purpose = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Payment for',
      );
      await tester.ensureVisible(purpose);
      await tester.tap(purpose);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Security deposit').last);
      await tester.pumpAndSettle();
      expect(find.byType(DepositPaymentScreen), findsOneWidget);
      expect(find.byType(ResearchPaymentEntry), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      final amount = tester
          .widgetList<TextField>(find.byType(TextField))
          .singleWhere((f) => f.decoration?.labelText == 'Deposit paid (rand)');
      expect(amount.controller!.text, '2000.00');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending deposit is shown separately and does not become money received',
    (tester) async {
      store.depositPaymentReports = [pendingReport()];
      final t = store.tenancies.first;
      expect(store.research.depositReceived(t), 0);
      expect(store.research.depositOutstanding(t), 200000);
      await pump(tester, DepositPaymentScreen(tenancyId: t.id));
      final amount = tester
          .widgetList<TextField>(find.byType(TextField))
          .singleWhere((f) => f.decoration?.labelText == 'Deposit paid (rand)');
      expect(amount.controller!.text, '1000.00');
      await tester.scrollUntilVisible(
        find.byType(DepositReportCard),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Waiting for landlord confirmation'), findsOneWidget);
      expect(find.text('Confirm deposit payment'), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(store.research.depositReceived(t), 0);
      expect(store.research.depositOutstanding(t), 200000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only landlord sees review controls and must tick receipt before confirmation',
    (tester) async {
      store.depositPaymentReports = [pendingReport()];
      await tester.runAsync(() async {
        await store.logout();
        await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
      });
      await pump(tester, const DepositReportsOverview());
      expect(find.text('Confirm deposit payment'), findsOneWidget);
      final button = find.widgetWithText(
        FilledButton,
        'Confirm deposit payment',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(store.research.depositReceived(store.tenancies.first), 0);
      expect(tester.takeException(), isNull);
    },
  );
}
