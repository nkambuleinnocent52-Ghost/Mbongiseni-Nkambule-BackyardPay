import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/research_ledger.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

void main() {
  const t = Tenancy(
    id: 't',
    userId: 'u',
    propertyId: 'p',
    room: '1',
    startPeriod: '2026-01',
    rentCents: 150000,
    dueDay: 1,
    depositCents: 200000,
  );
  test('deposit due counts receipts once and never confuses interest/refunds with new rent', () {
    Map<String, dynamic> e(String id, String event, int amount) => {
      'id': id,
      'tenancyId': 't',
      'kind': 'deposit',
      'createdAt': '2026-01-$id',
      'body': {'event': event, 'amountCents': amount},
    };
    final ledger = ResearchLedger([], [
      e('01', 'received', 50000),
      e('02', 'interest', 500),
      e('03', 'refund', 20000),
    ]);
    expect(ledger.depositOutstanding(t), 150000);
    expect(ledger.depositBalance(t), 30500);
    expect(ledger.charge(t, '2026-01'), 150000);
  });
  test('explicit zero deposit and unknown deposit are distinct', () {
    final zero = Tenancy.fromJson({...t.toJson(), 'depositCents': 0});
    final unknown = Tenancy.fromJson({...t.toJson(), 'depositCents': null});
    expect(const ResearchLedger([], []).depositOutstanding(zero), 0);
    expect(const ResearchLedger([], []).depositOutstanding(unknown), null);
    expect(parseDeposit('0.00'), 0);
    expect(parseDeposit('2000'), 200000);
    expect(() => parseDeposit('-1'), throwsFormatException);
  });
}
