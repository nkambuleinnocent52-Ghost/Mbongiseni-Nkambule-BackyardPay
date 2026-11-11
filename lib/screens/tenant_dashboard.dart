part of 'dashboard.dart';

class TenantDashboardScreen extends StatelessWidget {
  const TenantDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => _DashboardLayout(
    role: Role.tenant,
    contentBuilder: (context, period) {
      final store = StoreScope.of(context), first = store.tenancies.firstOrNull;
      if (first == null) return [];
      return [
        heading('My rental'),
        _RentalTile(t: first, period: period),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR RENTAL CONTACT',
                style: TextStyle(
                  color: Palette.gold,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              gap(12),
              Text(
                store.landlordFor(first).name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              detail('Phone', store.landlordFor(first).phone),
              detail('Property', store.property(first.propertyId).fullAddress),
              if (!first.agreementRecorded)
                const Text(
                  'Your landlord has not completed the rental terms yet. Open Rental details to see what is recorded.',
                  style: TextStyle(color: Palette.goldLight, height: 1.7),
                ),
            ],
          ),
        ),
      ];
    },
  );
}
