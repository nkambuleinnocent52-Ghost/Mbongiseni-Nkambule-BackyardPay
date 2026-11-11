part of 'dashboard.dart';

class LandlordDashboardScreen extends StatelessWidget {
  const LandlordDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => _DashboardLayout(
    role: Role.landlord,
    contentBuilder: (context, period) {
      final store = StoreScope.of(context), ts = store.tenancies;
      final pending = store.payments
          .where((p) => p.period == period && p.state == ReviewState.pending)
          .toList();
      final reviewAmount = pending.fold(0, (sum, p) => sum + p.amountCents);
      return [
        LayoutBuilder(
          builder: (context, c) {
            final occupied = store.tenancies.where(store.isOccupied).length,
                totalRooms = store.properties.fold(
                  0,
                  (sum, p) => sum + p.rooms,
                );
            final occupancy = panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PORTFOLIO SNAPSHOT',
                    style: TextStyle(
                      color: Palette.gold,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  gap(18),
                  detail('Properties', '${store.properties.length}'),
                  detail('Occupied rooms', '$occupied / $totalRooms'),
                  detail(
                    'Available rooms',
                    '${math.max(0, totalRooms - occupied)}',
                  ),
                  detail(
                    'Awaiting review',
                    '${pending.length} payments · ${money(reviewAmount)}',
                  ),
                  detail(
                    'Rental records to complete',
                    '${ts.where((t) => !t.agreementRecorded).length}',
                  ),
                ],
              ),
            );
            final history = panel(
              _CollectionChart(store: store, period: period),
            );
            return c.maxWidth >= 720
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: history),
                      const SizedBox(width: 18),
                      Expanded(child: occupancy),
                    ],
                  )
                : Column(children: [history, occupancy]);
          },
        ),
        if (pending.isNotEmpty) ...[
          heading('Needs your attention'),
          for (final p in pending.take(3))
            panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: Palette.gold),
                title: Text(
                  '${store.tenantAccount(store.tenancy(p.tenancyId)).name} · ${money(p.amountCents)}',
                ),
                subtitle: Text(
                  '${p.method} · ${monthLabel(p.period)} · Pending',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () =>
                    open(context, PaymentDetailsScreen(paymentId: p.id)),
              ),
            ),
        ],
        heading('Who has paid?'),
        const Text(
          'Every tenant is included, even when no payment has been submitted.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
        gap(),
        for (final t in ts) _RentalTile(t: t, period: period),
        if (store.properties.isEmpty)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('Start with your property'),
                const Text(
                  'Add the address and rooms, assign a tenant, then share their private invitation.',
                ),
                action('Add property', () => editProperty(context)),
              ],
            ),
          ),
      ];
    },
  );
}
