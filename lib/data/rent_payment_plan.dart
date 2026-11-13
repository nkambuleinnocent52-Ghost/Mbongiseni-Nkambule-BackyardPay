import '../models/models.dart';

/// A proposed split of one actual rent payment, starting at the tenant's month.
/// It never turns a pending report into received money or mixes in the deposit.
List<PaymentAllocation> proposeRentPayment({
  required int amountCents,
  required String firstPeriod,
  required Iterable<String> allowedMonths,
  required int Function(String) amountStillToReport,
}) {
  var remaining = amountCents;
  final months =
      allowedMonths.where((m) => m.compareTo(firstPeriod) >= 0).toSet().toList()
        ..sort();
  final result = <PaymentAllocation>[];
  for (final month in months) {
    if (remaining <= 0) break;
    final available = amountStillToReport(month).clamp(0, 2147483647);
    final part = remaining < available ? remaining : available;
    if (part > 0) {
      result.add(PaymentAllocation(month, part));
      remaining -= part;
    }
  }
  return result;
}
