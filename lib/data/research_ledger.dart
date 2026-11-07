import '../models/models.dart';

/// As-of allocation view, distinct from cash received by payment date.
class ResearchLedger {
  final List<Map<String, dynamic>> terms, records;
  const ResearchLedger(this.terms, this.records);
  List<Map<String, dynamic>> forTenancy(String id, String kind) =>
      records.where((r) => r['tenancyId'] == id && r['kind'] == kind).toList()
        ..sort(
          (a, b) =>
              (a['createdAt'] as String).compareTo(b['createdAt'] as String),
        );
  Map<String, dynamic>? rate(Tenancy t, String period) {
    final rows =
        terms
            .where(
              (r) =>
                  r['tenancyId'] == t.id &&
                  (r['period'] as String).compareTo(period) <= 0,
            )
            .toList()
          ..sort(
            (a, b) => (b['period'] as String).compareTo(a['period'] as String),
          );
    return rows.firstOrNull;
  }

  int charge(Tenancy t, String period) {
    if (period.compareTo(t.startPeriod) < 0 ||
        (t.endedOn != null && period.compareTo(periodOf(t.endedOn!)) > 0))
      return 0;
    var base = rate(t, period)?['amountCents'] as int? ?? t.rentCents;
    if (period == t.startPeriod &&
        t.record['firstMonthProration'] == 'actual_days') {
      final start = DateTime.parse(t.record['tenancyStartedOn'] as String);
      base = proratedFirstCharge(base, start);
    }
    return base +
        forTenancy(t.id, 'adjustment')
            .where((r) => r['body']['period'] == period)
            .fold<int>(0, (sum, r) => sum + (r['body']['amountCents'] as int));
  }

  int depositReceived(Tenancy t) => forTenancy(t.id, 'deposit')
      .where((r) => ['received', 'opening'].contains(r['body']['event']))
      .fold(0, (sum, r) => sum + (r['body']['amountCents'] as int));
  int? depositOutstanding(Tenancy t) => t.depositCents == null
      ? null
      : (t.depositCents! - depositReceived(t)).clamp(0, 2147483647);
  int depositBalance(Tenancy t) => forTenancy(t.id, 'deposit').fold(
    0,
    (sum, r) =>
        sum +
        (['refund', 'deduction'].contains(r['body']['event']) ? -1 : 1) *
            (r['body']['amountCents'] as int),
  );
  String caseStatus(Map<String, dynamic> item) {
    final updates = forTenancy(item['tenancyId'], 'case_update')
        .where(
          (r) =>
              r['body']['parentId'] == item['id'] &&
              r['body']['status'] != 'comment',
        )
        .toList();
    return updates.isEmpty ? 'open' : updates.last['body']['status'];
  }
}

/// Calendar-day billing, including the move-in day. Round the final cents only.
int daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;
int proratedFirstCharge(int monthlyCents, DateTime start) {
  final days = daysInMonth(start), occupied = days - start.day + 1;
  return (monthlyCents * occupied * 2 + days) ~/ (2 * days);
}

String firstChargeExplanation(int monthlyCents, DateTime start, bool prorate) {
  final days = daysInMonth(start), occupied = days - start.day + 1;
  final amount = prorate
      ? proratedFirstCharge(monthlyCents, start)
      : monthlyCents;
  return prorate
      ? '${money(monthlyCents)} ÷ $days calendar days × $occupied occupied days = ${money(amount)}. Move-in day included; final amount rounded once. From the next month: ${money(monthlyCents)} per calendar month.'
      : 'First month: ${money(amount)} under the full-month agreement. From the next month: ${money(monthlyCents)} per calendar month.';
}
