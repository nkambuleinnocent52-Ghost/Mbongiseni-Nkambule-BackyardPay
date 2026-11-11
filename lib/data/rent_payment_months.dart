import '../models/models.dart';

/// Months a payment may cover: tenancy start through twelve months ahead.
/// This list does not post future charges to the current month's account.
List<String> rentPaymentMonths(Tenancy tenancy, DateTime today) {
  final start = periodDate(tenancy.startPeriod);
  var end = DateTime(today.year, today.month + 12);
  if (tenancy.endedOn != null) {
    final returned = DateTime(tenancy.endedOn!.year, tenancy.endedOn!.month);
    if (returned.isBefore(end)) end = returned;
  }
  return [
    for (
      var date = start;
      !date.isAfter(end);
      date = DateTime(date.year, date.month + 1)
    )
      periodOf(date),
  ];
}
