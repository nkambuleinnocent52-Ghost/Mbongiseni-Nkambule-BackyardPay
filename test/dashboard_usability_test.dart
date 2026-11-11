import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/common.dart';
import 'package:mbongiseni_nkambule_apt_application/screens/shared/dashboard.dart';
import 'package:mbongiseni_nkambule_apt_application/ui/design.dart';

import 'fixtures.dart';
import 'test_storage.dart';

void main() {
  for (final role in Role.values) {
    testWidgets('${role.name} home fits a narrow phone with larger text', (
      tester,
    ) async {
      final store = AppStore(MemoryStorage());
      await tester.runAsync(() async {
        await seedTestAccounts(store);
        await store.login('${role.name}@demo.test', 'DemoPass123!', role);
      });
      addTearDown(store.dispose);
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            theme: backyardTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Incomplete essential'), findsNothing);
      if (role == Role.tenant) {
        expect(find.text('Rent still due'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Record payment'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Record payment'));
        await tester.pumpAndSettle();
        expect(find.text('Record payment').hitTestable(), findsOneWidget);
      } else {
        expect(find.text('Rent received'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
