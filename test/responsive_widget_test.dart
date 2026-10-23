import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/main.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

import 'test_storage.dart';

void main() {
  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await store.createDemo();
    await store.login('landlord@demo.test', 'DemoPass123!', Role.landlord);
  });
  tearDown(() => store.dispose());
  for (final size in [const Size(320, 780), const Size(1440, 650)]) {
    testWidgets(
      'black and gold dashboard fits ${size.width} pixels without overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(BackyardPayApp(store: store));
        await tester.pumpAndSettle();
        expect(find.text('Landlord dashboard'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
