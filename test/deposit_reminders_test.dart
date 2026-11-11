import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/deposit_reminders.dart';
import 'package:mbongiseni_nkambule_apt_application/data/research_ledger.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

void main() {
  Tenancy rental({
    int? deposit = 200000,
    Map<String, dynamic> record = const {},
    DateTime? leaseStart,
    DateTime? endedOn,
    String startPeriod = '2026-11',
  }) => Tenancy(
    id: 'rental',
    userId: 'tenant',
    propertyId: 'property',
    room: '1',
    startPeriod: startPeriod,
    rentCents: 150000,
    dueDay: 1,
    depositCents: deposit,
    record: record,
    leaseStart: leaseStart,
    endedOn: endedOn,
  );
  Map<String, dynamic> receipt(int amount, {String event = 'received'}) => {
    'id': 'receipt',
    'tenancyId': 'rental',
    'kind': 'deposit',
    'createdAt': '2026-11-02T12:00:00Z',
    'body': {'event': event, 'amountCents': amount},
  };
  Map<String, dynamic> report(
    int amount, {
    String state = 'pending',
    String id = 'rental',
  }) => {'tenancyId': id, 'state': state, 'amountCents': amount};
  DepositReminderInfo? status({
    Tenancy? tenancy,
    DateTime? today,
    List<Map<String, dynamic>> receipts = const [],
    List<Map<String, dynamic>> reports = const [],
  }) => depositReminderInfo(
    tenancy: tenancy ?? rental(),
    ledger: ResearchLedger(const [], receipts),
    reports: reports,
    today: today ?? DateTime(2026, 11, 11),
  );

  test('warning starts on calendar day ten, not day nine', () {
    expect(status(today: DateTime(2026, 11, 10, 23, 59))!.overdue, isFalse);
    final dayTen = status(today: DateTime(2026, 11, 11, 0, 0))!;
    expect(dayTen.overdue, isTrue);
    expect(dayTen.daysSinceDue, 10);
    expect(dayTen.eligibleOn, DateTime.utc(2026, 11, 11));
    final dayEleven = status(today: DateTime(2026, 11, 12, 1, 15))!;
    expect(dayEleven.overdue, isTrue);
    expect(dayEleven.daysSinceDue, 11);
  });

  test('a later agreed due date postpones the reminder', () {
    final t = rental(record: {'depositDueOn': '2026-11-08'});
    expect(status(tenancy: t)!.overdue, isFalse);
    expect(status(tenancy: t)!.daysSinceDue, 3);
    expect(status(tenancy: t)!.eligibleOn, DateTime.utc(2026, 11, 18));
    expect(status(tenancy: t, today: DateTime(2026, 11, 18))!.overdue, isTrue);
  });

  test('actual move-in date precedes lease and month fallback', () {
    final t = rental(
      record: {'tenancyStartedOn': '2026-11-04'},
      leaseStart: DateTime(2026, 11, 3),
    );
    expect(status(tenancy: t)!.dueOn, DateTime.utc(2026, 11, 4));
    expect(
      status(tenancy: rental(leaseStart: DateTime(2026, 11, 3)))!.dueOn,
      DateTime.utc(2026, 11, 3),
    );
    expect(status()!.dueOn, DateTime.utc(2026, 11, 1));
  });

  test(
    'invalid or normalized dates fall back instead of inventing a due date',
    () {
      final t = rental(
        record: {
          'depositDueOn': '2026-02-30',
          'tenancyStartedOn': '2026-11-04',
        },
      );
      expect(status(tenancy: t)!.dueOn, DateTime.utc(2026, 11, 4));
      expect(
        status(
          tenancy: rental(
            record: {'depositDueOn': 123, 'tenancyStartedOn': 'not a date'},
            leaseStart: DateTime(2026, 11, 3),
          ),
        )!.dueOn,
        DateTime.utc(2026, 11, 3),
      );
      expect(status(tenancy: rental(startPeriod: 'invalid')), isNull);
    },
  );

  test('confirmed partial receipts reduce only the outstanding amount', () {
    final info = status(receipts: [receipt(50000)])!;
    expect(info.outstandingCents, 150000);
    expect(info.unreportedCents, 150000);
    expect(info.pendingCents, 0);
    expect(info.overdue, isTrue);
  });

  test('a fully received deposit has no unpaid reminder', () {
    final info = status(receipts: [receipt(200000)])!;
    expect(info.outstandingCents, 0);
    expect(info.unreportedCents, 0);
    expect(info.overdue, isFalse);
  });

  test(
    'pending funds do not settle the deposit or produce a pay-again amount',
    () {
      final info = status(reports: [report(200000)])!;
      expect(info.outstandingCents, 200000);
      expect(info.pendingCents, 200000);
      expect(info.unreportedCents, 0);
      expect(
        info.overdue,
        isTrue,
        reason: 'Landlord still needs to check the payment',
      );
    },
  );

  test(
    'partial pending funds leave only the unreported remainder to request',
    () {
      final info = status(
        receipts: [receipt(50000)],
        reports: [report(75000)],
      )!;
      expect(info.outstandingCents, 150000);
      expect(info.pendingCents, 75000);
      expect(info.unreportedCents, 75000);
    },
  );

  test(
    'rejected, confirmed and other-tenancy reports are excluded from pending',
    () {
      final info = status(
        reports: [
          report(50000, state: 'rejected'),
          report(50000, state: 'confirmed'),
          report(50000, id: 'other'),
          report(25000),
        ],
      )!;
      expect(info.pendingCents, 25000);
      expect(info.unreportedCents, 175000);
    },
  );

  test(
    'pending above remaining funds never creates a negative warning amount',
    () {
      final info = status(
        receipts: [receipt(150000)],
        reports: [report(100000)],
      )!;
      expect(info.outstandingCents, 50000);
      expect(info.pendingCents, 100000);
      expect(info.unreportedCents, 0);
    },
  );

  test(
    'refunds and deductions do not make an already received deposit unpaid',
    () {
      final info = status(
        receipts: [
          receipt(200000),
          receipt(200000, event: 'refund'),
        ],
      )!;
      expect(info.outstandingCents, 0);
      expect(info.overdue, isFalse);
    },
  );

  test('ended, zero and unknown-deposit rentals have no reminder status', () {
    expect(status(tenancy: rental(endedOn: DateTime(2026, 11, 10))), isNull);
    expect(status(tenancy: rental(deposit: 0)), isNull);
    expect(status(tenancy: rental(deposit: null)), isNull);
  });
}
