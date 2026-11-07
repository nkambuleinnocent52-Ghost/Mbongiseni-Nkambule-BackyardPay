import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

// Test-only accounts; never packaged into the application or a database seed.
Future<void> seedTestAccounts(AppStore store) async {
  await store.register(
    name: 'Test Landlord',
    email: 'landlord@demo.test',
    phone: '0710000001',
    password: 'DemoPass123!',
    role: Role.landlord,
  );
  final id = await store.saveProperty(
    name: 'Test Rooms',
    address: 'Test Address',
    rooms: 4,
    rentCents: 150000,
    securityDepositCents: 200000,
    dueDay: 1,
  );
  final code = store.property(id).code;
  await store.logout();
  await store.register(
    name: 'Test Tenant',
    email: 'tenant@demo.test',
    phone: '0710000002',
    password: 'DemoPass123!',
    role: Role.tenant,
    code: code,
    room: '1',
  );
  await store.logout();
}
