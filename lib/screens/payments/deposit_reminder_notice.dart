import 'package:flutter/material.dart';

import '../../data/deposit_reminders.dart';
import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import '../shared/dashboard.dart' show dateLabel;
import 'deposit_payments.dart';
import '../rentals/simple_rentals.dart' show RentalSection;

DateTime _todayInSouthAfrica() =>
    DateTime.now().toUtc().add(const Duration(hours: 2));

class DepositReminderNotice extends StatelessWidget {
  final String tenancyId;
  const DepositReminderNotice({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), t = s.tenancy(tenancyId);
    final info = depositReminderInfo(
      tenancy: t,
      ledger: s.research,
      reports: s.depositPaymentReports,
      today: _todayInSouthAfrica(),
    );
    if (info == null || !info.overdue) return const SizedBox.shrink();
    final owner = s.currentUser!.role == Role.landlord;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: Palette.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.unreportedCents > 0
                      ? 'Deposit reminder'
                      : 'Deposit payment waiting for review',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Palette.goldLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (info.unreportedCents > 0)
            Text(
              owner
                  ? '${money(info.unreportedCents)} overdue · deadline ${dateLabel(info.dueOn)}.'
                  : '${money(info.unreportedCents)} overdue · deadline ${dateLabel(info.dueOn)}. Already paid? Report it below.',
            ),
          if (info.pendingCents > 0)
            Text(
              owner
                  ? '${money(info.pendingCents)} reported · check before requesting another payment.'
                  : '${money(info.pendingCents)} waiting for confirmation. Do not pay this amount again.',
            ),
          if (!owner && info.unreportedCents > 0)
            TextButton(
              onPressed: () =>
                  open(context, DepositPaymentScreen(tenancyId: t.id)),
              child: const Text('Report a deposit payment'),
            ),
        ],
      ),
    );
  }
}

class DepositReminderSettings extends StatelessWidget {
  final String tenancyId;
  const DepositReminderSettings({super.key, required this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), t = s.tenancy(tenancyId);
    final info = depositReminderInfo(
      tenancy: t,
      ledger: s.research,
      reports: s.depositPaymentReports,
      today: _todayInSouthAfrica(),
    );
    if (info == null) return const SizedBox.shrink();
    final owner = s.currentUser!.role == Role.landlord;
    final legacy =
        t.record['depositDeadlinePolicy'] == 'legacy_agreed' ||
        (t.record['depositDeadlinePolicy'] != 'move_in_plus_10' &&
            (t.record['depositDueNote']?.toString().trim().isNotEmpty ??
                false));
    final details = <Widget>[
      const Text(
        'One-off security deposit: pay within 10 calendar days of moving in.',
      ),
      detail('Deposit deadline', dateLabel(info.dueOn)),

      if (legacy)
        const Text('This rental keeps its previously agreed deposit deadline.'),
    ];
    if (!owner)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      );
    return RentalSection(
      title: 'Deposit deadline',
      subtitle: '10 days from move-in — paid once',
      children: [
        ...details,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            s.depositRemindersVersion < 1
                ? 'The reminder update is not active yet. The project owner must finish the database update.'
                : s.depositReminderScheduler
                ? 'Daily background reminders are active. Tenants see them in Notifications when they open BackyardPay.'
                : 'Reminders are checked when you open or refresh the app. Daily background checks are not active yet.',
          ),
        ),
      ],
    );
  }
}

class DepositReminderOverview extends StatelessWidget {
  const DepositReminderOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final outstanding = s.tenancies.where((t) {
      final info = depositReminderInfo(
        tenancy: t,
        ledger: s.research,
        reports: s.depositPaymentReports,
        today: _todayInSouthAfrica(),
      );
      return info?.overdue == true;
    }).toList();
    if (outstanding.isEmpty) return const SizedBox.shrink();
    return RentalSection(
      title: 'Deposit reminders (${outstanding.length})',
      subtitle: 'Deposits to follow up or payments to check',
      children: [
        for (final t in outstanding)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.tenantAccount(t).name} · Room ${t.room}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              DepositReminderNotice(tenancyId: t.id),
            ],
          ),
      ],
    );
  }
}
