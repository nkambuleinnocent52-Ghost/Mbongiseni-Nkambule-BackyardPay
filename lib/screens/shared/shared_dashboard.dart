import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import 'common.dart';
import 'profile.dart';
import 'payment_rules.dart';

import 'dashboard_widgets.dart';

class DashboardLayout extends StatefulWidget {
  final Role role;
  final List<Widget> Function(BuildContext, String) contentBuilder;
  const DashboardLayout({required this.role, required this.contentBuilder});
  @override
  State<DashboardLayout> createState() => DashboardLayoutState();
}

class DashboardLayoutState extends State<DashboardLayout> {
  String period = periodOf(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), user = store.currentUser;
    if (user == null || user.role != widget.role)
      return const SizedBox.shrink();
    final owner = user.role == Role.landlord;
    return PageShell(
      title: owner ? 'Landlord dashboard' : 'Tenant dashboard',
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => open(context, const NotificationsScreen()),
          icon: Badge(
            isLabelVisible: store.notices.any((n) => !n.read),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => open(context, const ProfileScreen()),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      children: [
        heading('Hello, ${user.name}'),
        const RentalPaymentRules(),
        Align(
          alignment: Alignment.centerLeft,
          child: MonthSelector(
            period: period,
            onChanged: (value) => setState(() => period = value),
          ),
        ),
        gap(20),
        ...widget.contentBuilder(context, period),
      ],
    );
  }
}

/// Secondary destinations are quiet rows, not competing primary buttons.
Widget dashboardLink(
  BuildContext context,
  String label,
  IconData icon,
  VoidCallback onTap, {
  String? subtitle,
}) => Semantics(
  button: true,
  label: label,
  hint: subtitle,
  excludeSemantics: true,
  onTap: onTap,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, color: Palette.gold),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  ),
);

Widget dashboardTotals(List<Widget> cards) => LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth >= 760
        ? cards.length
        : constraints.maxWidth >= 360
        ? 2
        : 1;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final card in cards)
          SizedBox(
            width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
            child: card,
          ),
      ],
    );
  },
);
