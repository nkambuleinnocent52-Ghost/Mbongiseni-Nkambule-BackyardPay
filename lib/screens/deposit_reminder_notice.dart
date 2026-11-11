import 'package:flutter/material.dart';

import '../data/deposit_reminders.dart';
import '../models/models.dart';
import '../ui/design.dart';
import 'common.dart';
import 'dashboard.dart' show dateLabel;
import 'deposit_payments.dart';
import 'simple_rentals.dart' show InlineRentalForm, RentalSection;
import 'research_records.dart' show isoDay, checkedDate;

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
                  ? '${money(info.unreportedCents)} of this tenant’s deposit is still not recorded as received or reported. The agreed due date was ${dateLabel(info.dueOn)}.'
                  : '${money(info.unreportedCents)} of your deposit is still not recorded as received or reported. Please pay it, report it if you already paid, or contact your landlord.',
            ),
          if (info.pendingCents > 0)
            Text(
              owner
                  ? '${money(info.pendingCents)} has been reported by the tenant and needs your confirmation. Check the money before asking them to pay again.'
                  : 'You have reported ${money(info.pendingCents)}. Your landlord still needs to check it. Do not pay that reported amount again just to confirm it.',
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
    final details = <Widget>[
      detail('Agreed deposit due date', dateLabel(info.dueOn)),
      detail('Reminder from', dateLabel(info.eligibleOn)),
      const Text(
        'If a deposit remains unpaid, a reminder is due after 10 calendar days. This does not give extra time to pay or create a penalty.',
      ),
    ];
    if (!owner)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      );
    return RentalSection(
      title: 'Deposit due date and reminder',
      subtitle: 'A reminder after 10 days',
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
        const Text(
          'Use the date agreed with this tenant. Record the agreement if you allow a later payment date.',
        ),
        InlineRentalForm(
          fields: const {
            'date': 'Agreed deposit due date (YYYY-MM-DD)',
            'note': 'Reason / agreement for this due date',
          },
          initial: {'date': isoDay(info.dueOn)},
          label: 'Save agreed due date',
          save: (v, id) async {
            checkedDate(v['date']!);
            await s.researchAction('deposit_deadline', {
              'tenancyId': t.id,
              'date': v['date'],
              'note': v['note'],
            });
          },
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
