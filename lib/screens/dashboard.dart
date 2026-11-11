import 'payment_rules.dart';
import 'deposit_reminder_notice.dart';
import 'deposit_payments.dart';
import 'simple_rentals.dart';
import 'rental_costs.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../data/store.dart';
import '../ui/design.dart';
import 'common.dart';
import 'payments.dart';
import 'properties.dart';
import 'profile.dart';
import 'rental_account.dart';
import 'research_records.dart';

part 'shared_dashboard.dart';
part 'landlord_dashboard.dart';
part 'tenant_dashboard.dart';
part 'dashboard_widgets.dart';
part 'tenants_page.dart';

// Select the page from the signed-in account's role.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = StoreScope.of(context).currentUser;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    return user.role == Role.landlord
        ? const LandlordDashboardScreen()
        : const TenantDashboardScreen();
  }
}
