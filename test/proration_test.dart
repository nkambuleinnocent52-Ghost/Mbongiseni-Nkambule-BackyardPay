import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';

import 'test_storage.dart';

import 'package:mbongiseni_nkambule_apt_application/data/research_ledger.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

void main() {
  test(
    'inclusive calendar days and final-only cent rounding across month lengths',
    () {
      expect(proratedFirstCharge(150000, DateTime(2026, 1, 15)), 82258);
      expect(proratedFirstCharge(150000, DateTime(2026, 2, 15)), 75000);
      expect(proratedFirstCharge(150000, DateTime(2024, 2, 15)), 77586);
      expect(proratedFirstCharge(150000, DateTime(2026, 4, 15)), 80000);
      expect(proratedFirstCharge(150000, DateTime(2026, 1, 31)), 4839);
      expect(proratedFirstCharge(150000, DateTime(2026, 1, 1)), 150000);
      expect(
        proratedFirstCharge(1, DateTime(2026, 4, 16)),
        1,
      ); // exactly half a cent rounds up
    },
  );
  test('first month uses its recorded basis, subsequent rates and adjustments remain separate', () {
    const t = Tenancy(
      id: 't',
      userId: 'u',
      propertyId: 'p',
      room: '1',
      startPeriod: '2026-01',
      rentCents: 150000,
      dueDay: 1,
      record: {
        'firstMonthProration': 'actual_days',
        'tenancyStartedOn': '2026-01-15',
      },
      ledgerVersion: 2,
    );
    final ledger = ResearchLedger(
      [
        {'tenancyId': 't', 'period': '2026-02', 'amountCents': 160000},
      ],
      [
        {
          'tenancyId': 't',
          'kind': 'adjustment',
          'createdAt': '2026-01-15',
          'body': {'period': '2026-01', 'amountCents': -1000},
        },
      ],
    );
    expect(ledger.charge(t, '2026-01'), 81258);
    expect(ledger.charge(t, '2026-02'), 160000);
    final old = Tenancy.fromJson({
      ...t.toJson(),
      'record': {
        'firstMonthProration': 'full_month',
        'tenancyStartedOn': '2026-01-15',
      },
    });
    expect(ledger.charge(old, '2026-01'), 149000);
  });
  test('first charge due date cannot precede actual move-in', () {
    final store = AppStore(MemoryStorage())..researchVersion = 2;
    const t = Tenancy(
      id: 't',
      userId: 'u',
      propertyId: 'p',
      room: '1',
      startPeriod: '2026-01',
      rentCents: 150000,
      dueDay: 1,
      record: {
        'firstMonthProration': 'actual_days',
        'tenancyStartedOn': '2026-01-15',
      },
      ledgerVersion: 2,
    );
    expect(store.dueDate(t, '2026-01'), DateTime(2026, 1, 15));
    expect(store.dueDate(t, '2026-02'), DateTime(2026, 2, 1));
    store.dispose();
  });
}
