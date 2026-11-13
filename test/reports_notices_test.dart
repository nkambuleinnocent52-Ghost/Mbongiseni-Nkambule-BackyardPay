import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/payments/payments.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/rentals/reports.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/common.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/notifications_screen.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

class ReportTestStore extends AppStore {
  ReportTestStore(super.storage);
  final operations = <Map<String, dynamic>>[];
  @override
  Future<dynamic> researchAction(
    String operation,
    Map<String, dynamic> args,
  ) async {
    operations.add({'operation': operation, ...args});
    if (operation == 'case' && ['repair', 'query'].contains(args['kind'])) {
      caseRecords.add({
        'id': args['eventId'],
        'tenancyId': args['tenancyId'],
        'kind': args['kind'],
        'createdAt': DateTime.now().toIso8601String(),
        'body': {...args['body'], 'status': 'open'},
      });
    } else if (operation == 'case') {
      caseRecords.add({
        'id': args['eventId'],
        'tenancyId': args['tenancyId'],
        'kind': args['kind'],
        'createdAt': DateTime.now().toIso8601String(),
        'body': args['body'],
      });
    }
    notifyListeners();
    return args['eventId'];
  }
}

void main() {
  late ReportTestStore store;
  late MemoryStorage storage;
  setUp(() async {
    storage = MemoryStorage();
    store = ReportTestStore(storage);
    await seedTestAccounts(store);
    await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
    store.researchVersion = 2;
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

  test(
    'notice metadata survives serialization while legacy notices remain valid',
    () {
      final n = AppNotice(
        id: 'n',
        userId: 'tenant',
        title: 'Rent reported',
        message: 'Room 1',
        createdAt: DateTime(2026, 11, 12),
        targetKind: 'rent_payment',
        targetId: 'payment-1',
        tenancyId: 'tenancy-1',
      );
      final restored = AppNotice.fromJson(jsonDecode(jsonEncode(n.toJson())));
      expect(restored.targetId, 'payment-1');
      expect(restored.targetKind, 'rent_payment');
      expect(restored.tenancyId, 'tenancy-1');
      expect(
        AppNotice.fromJson({
          'id': 'old',
          'userId': 'u',
          'title': 'Old notice',
          'message': 'Saved before links',
          'createdAt': '2026-11-01',
          'read': false,
        }).targetId,
        isNull,
      );
    },
  );

  testWidgets(
    'new issue uses location selection and clears the form after success',
    (tester) async {
      await pump(
        tester,
        SimpleReportsScreen(tenancyId: store.tenancies.first.id),
      );
      expect(find.text('Report a problem'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == 'Where is the problem?',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Water leaking from my ceiling',
      );
      await tester.ensureVisible(find.text('Send issue'));
      await tester.tap(find.text('Send issue'));
      await tester.pumpAndSettle();
      expect(store.operations.length, 1);
      expect(store.operations.first['body']['location'], 'Inside my room');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Submitted'), findsOneWidget);
      expect(find.text('Add message'), findsNothing);
      expect(find.text('Reply to this issue'), findsNothing);
      await tester.tap(find.text('Report a problem'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(field.controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'issue history is compact and selecting the report reveals replies',
    (tester) async {
      final t = store.tenancies.first;
      store.caseRecords = [
        {
          'id': 'issue-1',
          'tenancyId': t.id,
          'kind': 'repair',
          'createdAt': '2026-11-12T10:00:00Z',
          'body': {
            'description': 'Outside tap leaking',
            'location': 'Shared yard',
            'status': 'open',
          },
        },
      ];
      await pump(tester, SimpleReportsScreen(tenancyId: t.id));
      expect(find.text('Reply to this issue'), findsNothing);
      await tester.ensureVisible(find.text('Outside tap leaking'));
      await tester.tap(find.text('Outside tap leaking'));
      await tester.pumpAndSettle();
      expect(find.text('Reply to this issue'), findsOneWidget);
      expect(find.text('Add message'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landlord acknowledgement has an explicit status and never marks resolved',
    (tester) async {
      await tester.runAsync(() async {
        await store.logout();
        await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
      });
      final t = store.tenancies.first;
      store.caseRecords = [
        {
          'id': 'issue-1',
          'tenancyId': t.id,
          'kind': 'repair',
          'createdAt': '2026-11-12T10:00:00Z',
          'body': {
            'description': 'Outside tap leaking',
            'location': 'Shared yard',
            'status': 'open',
          },
        },
      ];
      await pump(
        tester,
        SimpleReportsScreen(tenancyId: t.id, reportId: 'issue-1'),
      );
      await tester.ensureVisible(find.text('Acknowledge issue'));
      await tester.tap(find.text('Acknowledge issue'));
      await tester.pumpAndSettle();
      expect(store.operations.last['body']['status'], 'acknowledged');
      expect(
        store.research.caseStatus(store.caseRecords.first),
        'acknowledged',
      );
      expect(find.text('Acknowledged by landlord'), findsOneWidget);
      expect(find.text('Mark in progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification link opens the exact issue and marks only that notice read',
    (tester) async {
      final t = store.tenancies.first;
      final saved = jsonDecode(storage.data!) as Map<String, dynamic>;
      saved['notices'] = [
        {
          'id': 'notice-1',
          'userId': store.currentUser!.id,
          'title': 'Problem acknowledged: Room 1',
          'message': 'Your landlord has received your report.',
          'createdAt': '2026-11-12T10:00:00Z',
          'read': false,
          'targetKind': 'issue',
          'targetId': 'issue-1',
          'tenancyId': t.id,
        },
      ];
      storage.data = jsonEncode(saved);
      await store.load();
      store.caseRecords = [
        {
          'id': 'issue-1',
          'tenancyId': t.id,
          'kind': 'repair',
          'createdAt': '2026-11-12T10:00:00Z',
          'body': {
            'description': 'Outside tap leaking',
            'location': 'Shared yard',
            'status': 'open',
          },
        },
      ];
      await pump(tester, const NotificationsScreen());
      await tester.tap(find.text('Problem acknowledged: Room 1'));
      await tester.pumpAndSettle();
      expect(find.text('Reported problem'), findsOneWidget);
      expect(find.text('Reply to this issue'), findsOneWidget);
      expect(store.notices.single.read, isTrue);
      expect(store.notices.single.targetId, 'issue-1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a stale rent notification falls back to payments without exposing an unscoped record',
    (tester) async {
      Widget? destination;
      await pump(
        tester,
        Builder(
          builder: (context) {
            destination = notificationDestination(
              context,
              AppNotice(
                id: 'n',
                userId: store.currentUser!.id,
                title: 'Rent payment',
                message: 'Old report',
                createdAt: DateTime.now(),
                targetKind: 'rent_payment',
                targetId: 'someone-elses-payment',
              ),
            );
            return const SizedBox();
          },
        ),
      );
      expect(destination, isA<PaymentsScreen>());
    },
  );
}
