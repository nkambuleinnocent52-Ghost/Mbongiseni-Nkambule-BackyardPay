import 'dart:math' as math;

import '../models/models.dart';
import 'research_ledger.dart';

/// Calendar-date status for a deposit reminder, separate from a legal grace period.
class DepositReminderInfo {
  final DateTime dueOn, eligibleOn;
  final int daysSinceDue, outstandingCents, pendingCents, unreportedCents;
  final bool overdue;

  const DepositReminderInfo({
    required this.dueOn,
    required this.eligibleOn,
    required this.daysSinceDue,
    required this.outstandingCents,
    required this.pendingCents,
    required this.unreportedCents,
    required this.overdue,
  });
}

/// Computes a one-off deposit deadline ten calendar days after actual move-in.
/// The reminder becomes eligible on the deadline itself, not ten days later.
///
/// A pending tenant report is not money received, but its amount is excluded
/// from a pay-again warning. When pending reports cover everything outstanding,
/// [DepositReminderInfo.overdue] remains true for the landlord's review warning,
/// while [DepositReminderInfo.unreportedCents] is zero for the tenant.
///
/// [today] must represent the desired local calendar date (South African time
/// in the application). Returned dates use UTC at midnight purely to keep date
/// arithmetic independent of daylight-saving changes; no instant conversion is
/// applied to [today].
DepositReminderInfo? depositReminderInfo({
  required Tenancy tenancy,
  required ResearchLedger ledger,
  required Iterable<Map<String, dynamic>> reports,
  required DateTime today,
}) {
  final requiredCents = tenancy.depositCents;
  if (tenancy.endedOn != null || requiredCents == null || requiredCents <= 0) {
    return null;
  }

  final actualStart =
      _recordDate(tenancy.record['tenancyStartedOn']) ??
      (tenancy.leaseStart == null
          ? null
          : _calendarDate(tenancy.leaseStart!)) ??
      _recordDate('${tenancy.startPeriod}-01');
  // Preserve an existing explicitly agreed deadline, but do not treat the old
  // automatic move-in-date value as a custom agreement. New records store the
  // move_in_plus_10 policy and its calculated date; deriving it here also keeps
  // active legacy records without an explicit agreement consistent.
  final policy = tenancy.record['depositDeadlinePolicy'];
  final note = tenancy.record['depositDueNote'];
  final explicitLegacyDate = policy == 'legacy_agreed' ||
      ((policy == null || policy == '') && note is String && note.trim().isNotEmpty);
  final customDue = explicitLegacyDate
      ? _recordDate(tenancy.record['depositDueOn'])
      : null;
  final dueOn = customDue ?? actualStart?.add(const Duration(days: 10));
  if (dueOn == null) return null;

  final date = _calendarDate(today);
  final eligibleOn = dueOn;
  final daysSinceDue = date.difference(dueOn).inDays;
  final outstanding = ledger.depositOutstanding(tenancy)!;
  final pending = reports
      .where((r) => r['tenancyId'] == tenancy.id && r['state'] == 'pending')
      .fold<int>(0, (sum, r) {
        final amount = r['amountCents'];
        return sum + (amount is num ? math.max(0, amount.toInt()) : 0);
      });

  return DepositReminderInfo(
    dueOn: dueOn,
    eligibleOn: eligibleOn,
    daysSinceDue: daysSinceDue,
    outstandingCents: outstanding,
    pendingCents: pending,
    unreportedCents: math.max(0, outstanding - pending),
    overdue: outstanding > 0 && !date.isBefore(eligibleOn),
  );
}

DateTime _calendarDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime? _recordDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null || date.toIso8601String().substring(0, 10) != value) {
    return null;
  }
  return _calendarDate(date);
}
