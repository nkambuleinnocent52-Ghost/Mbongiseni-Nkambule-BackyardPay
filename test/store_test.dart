import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/services/receipts.dart';

import 'test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late MemoryStorage storage;
  late String propertyId, tenancyId;
  final period = periodOf(DateTime.now());
  Future<void> landlord() =>
      store.login('owner@test.com', 'password123', Role.landlord);
  Future<void> tenant() =>
      store.login('tenant@test.com', 'password123', Role.tenant);
  Future<String> submit(int cents, String reference) => store.submitPayment(
    tenancyId: tenancyId,
    period: period,
    amountCents: cents,
    method: 'Cash',
    paidOn: DateTime.now(),
    reference: reference,
  );
  setUp(() async {
    storage = MemoryStorage();
    store = AppStore(storage);
    await store.register(
      name: 'Owner',
      email: 'owner@test.com',
      phone: '0710000001',
      password: 'password123',
      role: Role.landlord,
    );
    propertyId = await store.saveProperty(
      name: 'Rental Rooms',
      address: 'East London',
      rooms: 3,
      rentCents: 150000,
      dueDay: 1,
    );
    final code = store.property(propertyId).code;
    await store.logout();
    await store.register(
      name: 'Tenant',
      email: 'tenant@test.com',
      phone: '0710000002',
      password: 'password123',
      role: Role.tenant,
      code: code,
      room: '1',
    );
    tenancyId = store.tenancies.single.id;
  });
  tearDown(() => store.dispose());
  test('cash submission, confirmation, partial balance, receipt and restart share durable records', () async {
    final id = await submit(50000, 'partial-1');
    expect(store.payment(id).state, ReviewState.pending);
    expect(store.collected(store.tenancy(tenancyId), period), 0);
    expect(store.outstanding(store.tenancy(tenancyId), period), 150000);
    await expectLater(receiptPdf(store, id), throwsStateError);
    await store.logout();
    await landlord();
    expect(
      store.notices.any((n) => n.title == 'Payment awaiting review'),
      isTrue,
    );
    await store.reviewPayment(id, confirm: true);
    expect(
      store.rentStatus(store.tenancy(tenancyId), period),
      'Partially paid',
    );
    expect(store.outstanding(store.tenancy(tenancyId), period), 100000);
    await expectLater(store.reviewPayment(id, confirm: true), throwsStateError);
    await store.logout();
    await tenant();
    final second = await submit(100000, 'partial-2');
    await store.logout();
    await landlord();
    await store.reviewPayment(second, confirm: true);
    final restored = AppStore(storage);
    await restored.load();
    expect(restored.rentStatus(restored.tenancy(tenancyId), period), 'Paid');
    expect(restored.collected(restored.tenancy(tenancyId), period), 150000);
    expect(restored.outstanding(restored.tenancy(tenancyId), period), 0);
    await restored.logout();
    await restored.login('tenant@test.com', 'password123', Role.tenant);
    expect(
      restored.notices.where((n) => n.title == 'Payment confirmed').length,
      2,
    );
    final bytes = await receiptPdf(restored, id);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    restored.dispose();
  });
  test(
    'rejection requires a reason and releases balance for replacement',
    () async {
      final id = await submit(150000, 'reject-1');
      await store.logout();
      await landlord();
      await expectLater(
        store.reviewPayment(id, confirm: false),
        throwsArgumentError,
      );
      expect(store.payment(id).state, ReviewState.pending);
      await store.reviewPayment(
        id,
        confirm: false,
        reason: 'Cash not received',
      );
      await store.logout();
      await tenant();
      expect(store.payment(id).rejectionReason, 'Cash not received');
      expect(store.notices.any((n) => n.title == 'Payment rejected'), isTrue);
      final replacement = await submit(150000, 'replacement');
      expect(store.payment(replacement).state, ReviewState.pending);
    },
  );
  test('duplicate references and pending overpayments are rejected without extra records', () async {
    await submit(100000, 'unique');
    await expectLater(submit(10000, 'UNIQUE'), throwsArgumentError);
    await expectLater(submit(50001, 'overpay'), throwsArgumentError);
    expect(store.payments.length, 1);
    await expectLater(
      store.submitPayment(
        tenancyId: tenancyId,
        period: period,
        amountCents: 100,
        method: 'Cash',
        paidOn: DateTime.now().add(const Duration(days: 2)),
        reference: 'future',
      ),
      throwsArgumentError,
    );
  });
  test('passwords are hashed, incorrect credentials fail and change password persists', () async {
    final saved = jsonDecode(storage.data!);
    expect(
      (saved['accounts'] as List).every(
        (a) => a['passwordHash'] != 'password123',
      ),
      isTrue,
    );
    expect(storage.data, isNot(contains('password123')));
    await store.logout();
    await expectLater(
      store.login('tenant@test.com', 'wrong', Role.tenant),
      throwsArgumentError,
    );
    await expectLater(
      store.login('tenant@test.com', 'password123', Role.landlord),
      throwsArgumentError,
    );
    expect(store.currentUser, isNull);
    await tenant();
    await store.changePassword('password123', 'newpassword123');
    await store.logout();
    await expectLater(tenant(), throwsArgumentError);
    await store.login('tenant@test.com', 'newpassword123', Role.tenant);
    expect(store.currentUser!.email, 'tenant@test.com');
  });
  test('ownership checks prevent another landlord or tenant reading or approving a payment', () async {
    final id = await submit(10000, 'private');
    await expectLater(store.reviewPayment(id, confirm: true), throwsStateError);
    await store.logout();
    await store.register(
      name: 'Other Owner',
      email: 'other@test.com',
      phone: '0710000003',
      password: 'password123',
      role: Role.landlord,
    );
    expect(store.properties, isEmpty);
    expect(store.tenancies, isEmpty);
    expect(store.payments, isEmpty);
    await expectLater(store.reviewPayment(id, confirm: true), throwsStateError);
    await expectLater(store.saveLocation(propertyId, 0, 0), throwsStateError);
    await store.logout();
    await landlord();
    final code = store.property(propertyId).code;
    await store.logout();
    await store.register(
      name: 'Other Tenant',
      email: 'other-tenant@test.com',
      phone: '0710000004',
      password: 'password123',
      role: Role.tenant,
      code: code,
      room: '2',
    );
    expect(store.payments, isEmpty);
    expect(() => store.payment(id), throwsStateError);
    await expectLater(submit(100, 'foreign'), throwsStateError);
  });
  test(
    'reminders and read status persist, and failed storage rolls back',
    () async {
      await store.logout();
      await landlord();
      await store.sendReminder(
        tenancyId,
        period,
        'Please check your rent balance.',
      );
      await store.logout();
      await tenant();
      final notice = store.notices.single;
      await store.markRead(notice.id);
      final restored = AppStore(storage);
      await restored.load();
      expect(restored.notices.single.read, isTrue);
      restored.dispose();
      storage.failWrites = true;
      await expectLater(
        store.updateProfile('Changed Name', '0710000009'),
        throwsStateError,
      );
      expect(store.currentUser!.name, 'Tenant');
      await expectLater(submit(10000, 'failed'), throwsStateError);
      expect(store.payments, isEmpty);
    },
  );
  test('occupied room and destructive property changes are rejected', () async {
    await store.logout();
    await landlord();
    final p = store.property(propertyId);
    await expectLater(store.deleteProperty(propertyId), throwsStateError);
    await store.saveLocation(propertyId, -33.0153, 27.9116);
    expect(store.property(propertyId).latitude, -33.0153);
    await store.logout();
    await expectLater(
      store.register(
        name: 'Duplicate Room',
        email: 'dup@test.com',
        phone: '0710000004',
        password: 'password123',
        role: Role.tenant,
        code: p.code,
        room: '1',
      ),
      throwsArgumentError,
    );
    expect(store.currentUser, isNull);
    await expectLater(
      store.register(
        name: 'Invalid Code',
        email: 'bad@test.com',
        phone: '0710000004',
        password: 'password123',
        role: Role.tenant,
        code: 'BAD',
        room: '2',
      ),
      throwsArgumentError,
    );
  });
  test(
    'lateness uses actual payment day rather than landlord approval time',
    () async {
      final today = DateTime.now();
      final id = await store.submitPayment(
        tenancyId: tenancyId,
        period: period,
        amountCents: 10000,
        method: 'EFT',
        paidOn: DateTime(today.year, today.month, 1),
        reference: 'on-time',
        bankReference: 'EFT-ON-TIME',
      );
      await store.logout();
      await landlord();
      await store.reviewPayment(id, confirm: true);
      expect(store.isLate(store.payment(id)), isFalse);
    },
  );
  test(
    'money is parsed as cents without rounding or accepting invalid input',
    () {
      expect(parseMoney('1500.01'), 150001);
      expect(parseMoney('0.1'), 10);
      for (final value in ['0', '-1', 'NaN', '1.001', '1,500', '']) {
        expect(() => parseMoney(value), throwsFormatException);
      }
    },
  );
  test('property edits do not rewrite existing rent or due dates', () async {
    await store.logout();
    await landlord();
    await store.saveProperty(
      id: propertyId,
      name: 'Renamed Rooms',
      address: 'East London',
      rooms: 3,
      rentCents: 200000,
      dueDay: 15,
    );
    final t = store.tenancy(tenancyId);
    expect(store.expected(t, period), 150000);
    expect(store.dueDate(t, period).day, 1);
    expect(store.property(propertyId).rentCents, 200000);
  });
  test('demo creation is atomic and does not sign the user in', () async {
    final memory = MemoryStorage();
    final demo = AppStore(memory);
    memory.failWrites = true;
    await expectLater(demo.createDemo(), throwsStateError);
    expect(demo.hasAccounts, isFalse);
    memory.failWrites = false;
    await demo.createDemo();
    expect(demo.currentUser, isNull);
    await demo.login('tenant@demo.test', 'DemoPass123!', Role.tenant);
    expect(demo.tenancies.single.rentCents, 150000);
    await expectLater(demo.createDemo(), throwsStateError);
    demo.dispose();
  });
  Future<void> recordTerms({
    DateTime? end,
    String type = 'Month-to-month',
  }) async {
    final now = DateTime.now();
    await store.saveAgreement(
      tenancyId,
      start: DateTime(now.year, now.month - 2, 1),
      end: end,
      agreementType: type,
      depositCents: 150000,
      depositReceivedCents: 50000,
      utilities: 'Tenant pays prepaid electricity; water included.',
      houseRules: 'One month notice agreed by the parties.',
    );
  }

  test('monthly account includes unpaid months and carries only confirmed balances', () async {
    await store.logout();
    await landlord();
    await recordTerms();
    await store.logout();
    await tenant();
    final now = DateTime.now(),
        start = DateTime(DateTime.now().year, DateTime.now().month - 2, 1);
    final id = await store.submitPayment(
      tenancyId: tenancyId,
      period: periodOf(start),
      amountCents: 90000,
      method: 'EFT',
      bankReference: 'BANK-900',
      paidOn: start,
      reference: 'ALLOCATION-900',
    );
    await store.logout();
    await landlord();
    await store.reviewPayment(id, confirm: true);
    await store.logout();
    await tenant();
    await store.submitPayment(
      tenancyId: tenancyId,
      period: period,
      amountCents: 60000,
      method: 'Cash',
      paidOn: now,
      reference: 'PENDING-600',
    );
    final rows = store.ledger(store.tenancy(tenancyId));
    expect(rows.length, 3);
    expect(rows[0].status, 'Partially paid');
    expect(rows[0].closingBalanceCents, 60000);
    expect(rows[1].status, 'Outstanding');
    expect(rows[1].confirmedCents, 0);
    expect(rows[1].closingBalanceCents, 210000);
    expect(rows.last.pendingCents, 60000);
    expect(rows.last.closingBalanceCents, 360000);
    final pdf = await accountStatementPdf(store, tenancyId);
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    expect(store.tenancy(tenancyId).depositReceivedCents, 50000);
  });
  test('bank references are required for transfer records and survive landlord review', () async {
    await expectLater(
      store.submitPayment(
        tenancyId: tenancyId,
        period: period,
        amountCents: 10000,
        method: 'EFT',
        paidOn: DateTime.now(),
        reference: 'NO-BANK',
      ),
      throwsArgumentError,
    );
    final id = await store.submitPayment(
      tenancyId: tenancyId,
      period: period,
      amountCents: 10000,
      method: 'PayShap',
      bankReference: 'BANK-TRANSFER-REF',
      paidOn: DateTime.now(),
      reference: 'APP-RECORD-REF',
    );
    expect(store.payment(id).state, ReviewState.pending);
    await store.logout();
    await landlord();
    await store.reviewPayment(id, confirm: true);
    expect(store.payment(id).bankReference, 'BANK-TRANSFER-REF');
    expect(store.payment(id).reference, 'APP-RECORD-REF');
    final restored = AppStore(storage);
    await restored.load();
    expect(restored.payment(id).bankReference, 'BANK-TRANSFER-REF');
    restored.dispose();
  });
  test('rental terms are owned, validated and acknowledgement resets after an edit', () async {
    await expectLater(recordTerms(), throwsStateError);
    await store.logout();
    await landlord();
    await recordTerms();
    expect(store.tenancy(tenancyId).agreementRecorded, isTrue);
    await store.logout();
    await tenant();
    await store.acknowledgeAgreement(tenancyId);
    expect(store.tenancy(tenancyId).acknowledgedAt, isNotNull);
    await store.logout();
    await landlord();
    await recordTerms();
    expect(store.tenancy(tenancyId).acknowledgedAt, isNull);
    await expectLater(
      store.saveAgreement(
        tenancyId,
        start: DateTime.now(),
        agreementType: 'Fixed term',
        depositCents: 10000,
        depositReceivedCents: 20000,
        utilities: 'Water included',
        houseRules: 'One month notice',
      ),
      throwsArgumentError,
    );
    expect(store.tenancy(tenancyId).depositReceivedCents, 50000);
  });
  test('ended rental stops future charges, releases room and prevents date overlap', () async {
    await store.logout();
    await landlord();
    final now = DateTime.now(),
        end = DateTime(DateTime.now().year, DateTime.now().month, 0);
    await recordTerms(end: end, type: 'Fixed term');
    final old = store.tenancy(tenancyId),
        code = store.property(propertyId).code;
    expect(store.expected(old, period), 0);
    expect(store.isOccupied(old), isFalse);
    await store.logout();
    await store.register(
      name: 'New Tenant',
      email: 'new@test.com',
      phone: '0710000009',
      password: 'password123',
      role: Role.tenant,
      code: code,
      room: '1',
    );
    await store.logout();
    await landlord();
    expect(store.tenancies.where(store.isOccupied).length, 1);
    await expectLater(
      recordTerms(end: now, type: 'Fixed term'),
      throwsArgumentError,
    );
  });
  test('old saved data loads without losing accounts, payments or inventing rental terms', () async {
    final id = await submit(20000, 'LEGACY');
    final data = jsonDecode(storage.data!);
    for (final p in data['properties']) {
      for (final k in ['city', 'suburb', 'postalCode']) {
        p.remove(k);
      }
    }
    for (final t in data['tenancies']) {
      for (final k in [
        'leaseStart',
        'leaseEnd',
        'depositCents',
        'depositReceivedCents',
        'agreementType',
        'utilities',
        'houseRules',
        'emergencyName',
        'emergencyPhone',
        'termsUpdatedAt',
        'acknowledgedAt',
      ]) {
        t.remove(k);
      }
    }
    for (final p in data['payments']) {
      p.remove('bankReference');
    }
    storage.data = jsonEncode(data);
    final restored = AppStore(storage);
    await restored.load();
    expect(restored.currentUser!.email, 'tenant@test.com');
    expect(restored.payment(id).amountCents, 20000);
    expect(restored.tenancy(tenancyId).agreementRecorded, isFalse);
    expect(restored.tenancy(tenancyId).depositCents, isNull);
    expect(restored.ledger(restored.tenancy(tenancyId)).length, 1);
    restored.dispose();
  });
}
