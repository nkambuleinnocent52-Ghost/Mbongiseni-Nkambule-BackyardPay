import 'package:flutter_test/flutter_test.dart';

import 'package:mbongiseni_nkambule_apt_application/main.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';

import 'test_storage.dart';

void main() {
  testWidgets('Get started opens user selection and back returns to splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(BackyardPayApp(store: AppStore(MemoryStorage())));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('BACKYARDPAY'), findsOneWidget);
    expect(find.text('Digital Rental Management'), findsOneWidget);

    await tester.ensureVisible(find.text('GET STARTED'));
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(find.byType(UserTypeScreen), findsOneWidget);
    expect(find.text('How will you use the app?'), findsOneWidget);
    expect(find.text('LANDLORD'), findsOneWidget);
    expect(find.text('TENANT'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.byType(UserTypeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
