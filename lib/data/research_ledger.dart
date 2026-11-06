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
    return (rate(t, period)?['amountCents'] as int? ?? t.rentCents) +
        forTenancy(t.id, 'adjustment')
            .where((r) => r['body']['period'] == period)
            .fold<int>(0, (sum, r) => sum + (r['body']['amountCents'] as int));
  }

  int depositReceived(Tenancy t) => forTenancy(t.id, 'deposit')
      .where((r) => ['received', 'opening'].contains(r['body']['event']))
      .fold(0, (sum, r) => sum + (r['body']['amountCents'] as int));
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
