import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/research_ledger.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

void main() {
  const t = Tenancy(
    id: 't',
    userId: '',
    propertyId: 'p',
    room: '1',
    startPeriod: '2026-09',
    rentCents: 150000,
    dueDay: 1,
    ledgerVersion: 2,
  );
  Map<String, dynamic> event(
    String id,
    String kind,
    Map<String, dynamic> body,
  ) => {
    'id': id,
    'tenancyId': 't',
    'kind': kind,
    'body': body,
    'createdAt': '2026-11-${id.padLeft(2, '0')}',
  };
  test('planned expiry does not stop monthly charges; dated changes and agreed adjustments preserve earlier months', () {
    final withExpiry = Tenancy.fromJson({
      ...t.toJson(),
      'leaseEnd': '2026-10-31',
    });
    final ledger = ResearchLedger(
      [
        {'tenancyId': 't', 'period': '2026-09', 'amountCents': 150000},
        {'tenancyId': 't', 'period': '2026-12', 'amountCents': 180000},
      ],
      [
        event('1', 'adjustment', {'period': '2026-09', 'amountCents': -75000}),
      ],
    );
    expect(ledger.charge(withExpiry, '2026-08'), 0);
    expect(ledger.charge(withExpiry, '2026-09'), 75000);
    expect(ledger.charge(withExpiry, '2026-11'), 150000);
    expect(ledger.charge(withExpiry, '2026-12'), 180000);
    final ended = Tenancy.fromJson({...t.toJson(), 'endedOn': '2026-11-05'});
    expect(ledger.charge(ended, '2026-11'), 150000);
    expect(ledger.charge(ended, '2026-12'), 0);
  });
  test('deposit receipts, interest and return have separate meanings; case comments preserve workflow state', () {
    final ledger = ResearchLedger([], [
      event('1', 'deposit', {'event': 'opening', 'amountCents': 50000}),
      event('2', 'deposit', {'event': 'received', 'amountCents': 100000}),
      event('3', 'deposit', {'event': 'interest', 'amountCents': 1000}),
      event('4', 'deposit', {'event': 'refund', 'amountCents': 40000}),
      event('5', 'deposit', {'event': 'deduction', 'amountCents': 10000}),
      event('6', 'case_update', {'parentId': 'q', 'status': 'resolved'}),
      event('7', 'case_update', {'parentId': 'q', 'status': 'comment'}),
    ]);
    expect(ledger.depositReceived(t), 150000);
    expect(ledger.depositBalance(t), 101000);
    expect(ledger.caseStatus({'id': 'q', 'tenancyId': 't'}), 'resolved');
  });
  test('a single received amount retains multi-month allocation and unallocated credit through serialization', () {
    final p = RentPayment.fromJson({
      'id': 'pay',
      'tenancyId': 't',
      'period': '2026-11',
      'amountCents': 350000,
      'method': 'EFT',
      'notes': '',
      'payer': 'Family contributor',
      'paidOn': '2026-11-06',
      'reference': 'BANK-RECORD',
      'submittedAt': '2026-11-06',
      'state': 'confirmed',
      'allocations': [
        {'period': '2026-09', 'amountCents': 150000},
        {'period': '2026-10', 'amountCents': 150000},
      ],
      'receiptDetails': {'issuedCreditCents': 50000},
    });
    final restored = RentPayment.fromJson(p.toJson());
    expect(restored.splits.length, 2);
    expect(restored.creditCents, 50000);
    expect(restored.payer, 'Family contributor');
    expect(restored.receiptDetails!['issuedCreditCents'], 50000);
  });
}
