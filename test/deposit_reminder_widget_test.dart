import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/common.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/deposit_reminder_notice.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  late AppStore store;
  setUp(() async {
    final storage = MemoryStorage();
    store = AppStore(storage);
    await seedTestAccounts(store);
    final saved = jsonDecode(storage.data!) as Map<String, dynamic>;
    saved['researchVersion'] = 2;
    saved['depositRemindersVersion'] = 1;
    saved['depositReminderScheduler'] = false;
    final today = DateTime.now().toUtc().add(const Duration(hours: 2));
    final moveIn = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 10));
    for (final tenancy in saved['tenancies']) {
      tenancy['depositCents'] = 200000;
      tenancy['depositReceivedCents'] = 0;
      tenancy['record'] = {
        ...Map<String, dynamic>.from(tenancy['record'] ?? {}),
        'tenancyStartedOn': moveIn.toIso8601String().split('T').first,
        'depositDueOn': moveIn.add(const Duration(days: 10)).toIso8601String().split('T').first,
        'depositDeadlinePolicy': 'move_in_plus_10',
      };
    }
    storage.data = jsonEncode(saved);
    await store.load();
    await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
  });
  tearDown(() => store.dispose());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: backyardTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tenant sees the ten-day unpaid amount and a report-payment action',
    (tester) async {
      final t = store.tenancies.first;
      await pump(tester, DepositReminderNotice(tenancyId: t.id));
      expect(find.text('Deposit reminder'), findsOneWidget);
      expect(find.textContaining('R 2000.00 of your deposit'), findsOneWidget);
      expect(find.text('Report a deposit payment'), findsOneWidget);
      expect(find.textContaining('evict'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a fully reported deposit asks for review without asking tenant to pay again',
    (tester) async {
      final t = store.tenancies.first;
      store.depositPaymentReports = [
        {
          'id': 'pending',
          'tenancyId': t.id,
          'state': 'pending',
          'amountCents': 200000,
        },
      ];
      await pump(tester, DepositReminderNotice(tenancyId: t.id));
      expect(find.text('Deposit payment waiting for review'), findsOneWidget);
      expect(
        find.textContaining('Do not pay that reported amount again'),
        findsOneWidget,
      );
      expect(find.text('Report a deposit payment'), findsNothing);
      expect(
        find.textContaining('still not recorded as received or reported'),
        findsNothing,
      );
      expect(store.research.depositReceived(t), 0);
      expect(store.research.depositOutstanding(t), 200000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed deposit clears the warning rather than leaving a stale banner',
    (tester) async {
      final t = store.tenancies.first;
      await pump(tester, DepositReminderNotice(tenancyId: t.id));
      expect(find.text('Deposit reminder'), findsOneWidget);
      store.caseRecords = [
        {
          'id': 'confirmed',
          'tenancyId': t.id,
          'kind': 'deposit',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'body': {'event': 'received', 'amountCents': 200000},
        },
      ];
      await pump(tester, DepositReminderNotice(tenancyId: t.id));
      expect(find.text('Deposit reminder'), findsNothing);
      expect(find.text('Report a deposit payment'), findsNothing);
      expect(store.research.depositOutstanding(t), 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final active in [false, true]) {
    testWidgets(
      'landlord scheduler status is truthful when background checks are $active',
      (tester) async {
        await tester.runAsync(() async {
          await store.logout();
          await store.login(
            'landlord@demo.test',
            'DemoPass123!',
            Role.landlord,
          );
        });
        store.depositReminderScheduler = active;
        await pump(
          tester,
          DepositReminderSettings(tenancyId: store.tenancies.first.id),
        );
        await tester.tap(find.text('Deposit deadline'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            active
                ? 'Daily background reminders are active. Tenants see them in Notifications when they open BackyardPay.'
                : 'Reminders are checked when you open or refresh the app. Daily background checks are not active yet.',
          ),
          findsOneWidget,
        );
        expect(find.text('Save agreed due date'), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(
          find.textContaining(
            'One-off security deposit: pay within 10 calendar days of moving in.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Evict'), findsNothing);
        expect(find.textContaining('Lock out'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'tenant can read agreed reminder dates without landlord settings controls',
    (tester) async {
      await pump(
        tester,
        DepositReminderSettings(tenancyId: store.tenancies.first.id),
      );
      expect(find.textContaining('Deposit deadline'), findsOneWidget);
      expect(find.textContaining('Reminder from'), findsOneWidget);
      expect(find.text('Save agreed due date'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
