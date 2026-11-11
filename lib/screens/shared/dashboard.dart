import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'common.dart';
import '../landlord/landlord_dashboard.dart';
import '../tenant/tenant_dashboard.dart';
export 'dashboard_widgets.dart' show monthLabel, dateLabel, MonthSelector;
export '../landlord/tenants_page.dart'
    show TenantsScreen, TenancyDetailsScreen, reminder;
export '../landlord/landlord_dashboard.dart';
export '../tenant/tenant_dashboard.dart';

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
