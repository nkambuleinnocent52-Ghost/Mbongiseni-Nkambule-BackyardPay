import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/main.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

import 'test_storage.dart';
import 'fixtures.dart';

void main() {
  late MemoryStorage storage;
  late AppStore store;
  setUp(() async {
    storage = MemoryStorage();
    store = AppStore(storage);
    await seedTestAccounts(store);
    await store.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
  });
  tearDown(() => store.dispose());

  test(
    'a saved sign-in survives a new store; explicit logout survives restart',
    () async {
      final id = store.currentUser!.id;
      final restored = AppStore(storage);
      await restored.load();
      expect(restored.currentUser?.id, id);
      await restored.logout();
      restored.dispose();
      final signedOut = AppStore(storage);
      await signedOut.load();
      expect(signedOut.currentUser, isNull);
      signedOut.dispose();
    },
  );

  test('nine-digit alias keeps the same password and survives profile/password edits', () async {
    final alias = store.currentUser!.loginId!;
    expect(alias, matches(RegExp(r'^[1-9][0-9]{8}$')));
    await store.updateProfile('Tenant Updated', '0710000002');
    expect(store.currentUser!.loginId, alias);
    await store.changePassword('DemoPass123!', 'DifferentPass123!');
    expect(store.currentUser!.loginId, alias);
    await store.logout();
    final grouped =
        '${alias.substring(0, 3)} ${alias.substring(3, 6)} ${alias.substring(6)}';
    await expectLater(
      store.login(grouped, 'wrong-password', Role.tenant),
      throwsArgumentError,
    );
    await store.login(grouped, 'DifferentPass123!', Role.tenant);
    expect(store.currentUser!.name, 'Tenant Updated');
    await store.logout();
    await expectLater(
      store.login(alias, 'DifferentPass123!', Role.landlord),
      throwsArgumentError,
    );
    expect(store.currentUser, isNull);
    await store.login('tenant@demo.test', 'DifferentPass123!', Role.tenant);
    expect(store.currentUser!.loginId, alias);
  });

  testWidgets(
    'logout confirmation is anchored, cancel keeps the session and phone layout fits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(BackyardPayApp(store: store));
      await tester.pumpAndSettle();
      final icon = find.byTooltip('Log out');
      final iconBottom = tester.getBottomLeft(icon).dy;
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.getTopLeft(find.text('Log out of BackyardPay?')).dy,
        lessThan(iconBottom + 100),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.currentUser, isNotNull);
      expect(find.text('Log out of BackyardPay?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
