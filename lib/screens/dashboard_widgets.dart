part of 'dashboard.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String monthLabel(String period) {
  final d = periodDate(period);
  return '${_monthNames[d.month - 1]} ${d.year}';
}

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month - 1]} ${d.year}';

class _RentalTile extends StatelessWidget {
  final Tenancy t;
  final String period;
  const _RentalTile({required this.t, required this.period});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), p = store.property(t.propertyId);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store.tenantAccount(t).name} • Room ${t.room}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap(16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              StatusPill(store.rentStatus(t, period)),
              if (store.overdue(t, period)) const StatusPill('Overdue'),
              Text(
                'Balance ${money(store.outstanding(t, period))}',
                style: const TextStyle(color: Palette.goldLight),
              ),
              Text(
                'Rent ${money(t.rentCents)}',
                style: const TextStyle(color: Palette.muted),
              ),
            ],
          ),
          gap(14),
          Text(
            p.fullAddress,
            style: const TextStyle(color: Palette.muted, fontSize: 12),
          ),
          action(
            'Rental details',
            () => open(context, TenancyDetailsScreen(tenancyId: t.id)),
            icon: Icons.arrow_outward,
          ),
        ],
      ),
    );
  }
}

class _CollectionChart extends StatelessWidget {
  final AppStore store;
  final String period;
  const _CollectionChart({required this.store, required this.period});
  @override
  Widget build(BuildContext context) {
    final end = periodDate(period),
        months = [
          for (var i = 5; i >= 0; i--)
            periodOf(DateTime(end.year, end.month - i)),
        ];
    final values = [
      for (final p in months)
        store.tenancies.fold(0, (sum, t) => sum + store.collected(t, p)),
    ];
    final peak = values.fold(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLLECTIONS OVER TIME',
          style: TextStyle(
            color: Palette.gold,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        gap(8),
        const Text(
          'Confirmed rent · last 6 months',
          style: TextStyle(color: Palette.muted, fontSize: 11),
        ),
        gap(24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < months.length; i++)
              Expanded(
                child: Semantics(
                  label:
                      '${monthLabel(months[i])}: ${money(values[i])} confirmed',
                  child: Column(
                    children: [
                      Text(
                        values[i] == 0 ? '—' : money(values[i]),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Palette.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: math.max(5.0, values[i] / peak * 80),
                        width: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: values[i] > 0
                                ? [Palette.goldLight, Palette.gold]
                                : [Palette.border, Palette.border],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _monthNames[periodDate(months[i]).month - 1],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class MonthSelector extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  const MonthSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final date = periodDate(period);
    return Container(
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () =>
                onChanged(periodOf(DateTime(date.year, date.month - 1))),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              monthLabel(period),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: period.compareTo(periodOf(DateTime.now())) >= 0
                ? null
                : () =>
                      onChanged(periodOf(DateTime(date.year, date.month + 1))),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }
}
