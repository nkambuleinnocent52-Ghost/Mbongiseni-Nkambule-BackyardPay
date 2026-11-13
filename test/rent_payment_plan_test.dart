import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/data/rent_payment_plan.dart';

void main() {
  test('R2000 covers R1200 first rent then R800 next month, leaving R700', () {
    final plan = proposeRentPayment(
      amountCents: 200000,
      firstPeriod: '2026-11',
      allowedMonths: ['2026-11', '2026-12'],
      amountStillToReport: (m) => m == '2026-11' ? 120000 : 150000,
    );
    expect(plan.map((p) => p.amountCents), [120000, 80000]);
    expect(150000 - plan.last.amountCents, 70000);
  });
  test('tenant choice of December does not silently pay November', () {
    final plan = proposeRentPayment(
      amountCents: 70000,
      firstPeriod: '2026-12',
      allowedMonths: ['2026-11', '2026-12'],
      amountStillToReport: (_) => 150000,
    );
    expect(plan.single.period, '2026-12');
    expect(plan.single.amountCents, 70000);
  });
  test('pending money is not proposed a second time; ended rental limit retains credit', () {
    final plan = proposeRentPayment(
      amountCents: 200000,
      firstPeriod: '2026-11',
      allowedMonths: ['2026-11', '2026-12'],
      amountStillToReport: (m) => m == '2026-11' ? 0 : 150000,
    );
    expect(plan.single.period, '2026-12');
    expect(plan.single.amountCents, 150000);
    expect(200000 - plan.single.amountCents, 50000);
  });
}
