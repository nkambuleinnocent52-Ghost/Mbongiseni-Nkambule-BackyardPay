import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import 'common.dart';

import '../landlord/tenants_page.dart';

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

class RentalTile extends StatelessWidget {
  final Tenancy t;
  final String period;
  const RentalTile({required this.t, required this.period});
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
