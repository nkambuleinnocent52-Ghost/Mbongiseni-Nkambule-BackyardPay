import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/alerts.dart';
import '../../ui/design.dart';
import '../payments/deposit_payments.dart';
import '../payments/payments.dart';
import '../properties/properties.dart';
import '../rentals/rental_details.dart';
import '../rentals/reports.dart';
import 'common.dart';

/// Resolve only records already present in this signed-in user's scoped snapshot.
/// A stale or legacy notice falls back to the relevant list, never another user.
Widget notificationDestination(BuildContext context, AppNotice notice) {
  final s = StoreScope.of(context);
  switch (notice.targetKind) {
    case 'rent_payment':
      final payment = s.payments
          .where((p) => p.id == notice.targetId)
          .firstOrNull;
      if (payment != null) return PaymentDetailsScreen(paymentId: payment.id);
      return const PaymentsScreen();
    case 'deposit_report':
      final report = s.depositPaymentReports
          .where(
            (r) =>
                r['id'] == notice.targetId &&
                s.tenancies.any((t) => t.id == r['tenancyId']),
          )
          .firstOrNull;
      if (report != null) return DepositNoticeScreen(report: report);
      return const DepositReportsOverview();
    case 'issue':
      final report = s.caseRecords
          .where(
            (r) =>
                r['id'] == notice.targetId &&
                ['repair', 'query'].contains(r['kind']) &&
                s.tenancies.any((t) => t.id == r['tenancyId']),
          )
          .firstOrNull;
      if (report != null)
        return SimpleReportsScreen(
          tenancyId: report['tenancyId'],
          reportId: report['id'],
        );
      return const SimpleReportsScreen();
    case 'rental':
      final t = s.tenancies
          .where((t) => t.id == (notice.tenancyId ?? notice.targetId))
          .firstOrNull;
      if (t != null) return SimpleRentalDetails(tenancyId: t.id);
      return const NotificationsUnavailableScreen();
    case 'property':
      final p = s.properties.where((p) => p.id == notice.targetId).firstOrNull;
      if (p != null) return PropertyDetailsScreen(propertyId: p.id);
      return const NotificationsUnavailableScreen();
  }
  final text = '${notice.title} ${notice.message}'.toLowerCase();
  if (text.contains('deposit')) return const DepositReportsOverview();
  if (text.contains('payment') || text.contains('rent reminder'))
    return const PaymentsScreen();
  if (text.contains('query') ||
      text.contains('issue') ||
      text.contains('repair'))
    return const SimpleReportsScreen();
  return const NotificationsUnavailableScreen();
}

class NotificationsUnavailableScreen extends StatelessWidget {
  const NotificationsUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageShell(
    title: 'Notification details',
    children: [
      Text(
        'This older notification has no linked record. Use Payments, Rental details or Tenant reports to check the latest information.',
      ),
    ],
  );
}

class DepositNoticeScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const DepositNoticeScreen({super.key, required this.report});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final current = s.depositPaymentReports
        .where((r) => r['id'] == report['id'])
        .firstOrNull;
    return PageShell(
      title: 'Security deposit payment',
      maxWidth: 900,
      children: [
        if (current == null)
          const Text(
            'This deposit report is no longer available in your account.',
          )
        else
          DepositReportCard(key: ValueKey(current['id']), report: current),
      ],
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), notices = store.notices;
    return PageShell(
      title: 'Notifications',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => perform(context, () async {
              final message = await enableAlerts();
              if (context.mounted) tell(context, message);
            }),
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Enable browser alerts'),
          ),
        ),
        const Text(
          'Open a notification to view its payment, problem or rental.',
          style: TextStyle(color: Palette.muted),
        ),
        gap(),
        if (notices.isEmpty) panel(const Text('No notifications yet.')),
        for (final n in notices)
          Card(
            child: ListTile(
              key: ValueKey('notice-${n.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              leading: Icon(
                n.read
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
                color: n.read ? Palette.muted : Palette.gold,
              ),
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.read ? FontWeight.normal : FontWeight.w700,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.message),
                    const SizedBox(height: 8),
                    Text(
                      n.createdAt.toLocal().toString().split('.').first,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final destination = notificationDestination(context, n);
                open(context, destination);
                // Opening a record must not wait for a read-status network write.
                // A failed write leaves the notification unread for the next visit.
                if (!n.read)
                  unawaited(store.markRead(n.id).catchError((Object _) {}));
              },
            ),
          ),
      ],
    );
  }
}
