import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';

/// Rent and refundable security remain separate even when presenting their sum.
class RentalCosts extends StatelessWidget {
  final Tenancy tenancy;
  const RentalCosts({super.key, required this.tenancy});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), t = tenancy;
    final rows = store.ledger(t),
        depositDue = store.research.depositOutstanding(t);
    final rentDue = rows.isEmpty ? 0 : rows.last.closingBalanceCents;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Rent and security deposit'),
          detail(
            'Agreed security deposit',
            t.depositCents == null ? 'Not recorded' : money(t.depositCents!),
          ),
          detail(
            'Deposit received — separate from rent',
            money(store.research.depositReceived(t)),
          ),
          if (t.record['depositDueOn'] != null)
            detail('Deposit due by move-in', t.record['depositDueOn']),
          detail(
            'Deposit still due',
            depositDue == null ? 'Not recorded' : money(depositDue),
          ),
          detail(
            'First rent charge (${t.startPeriod})',
            money(store.expected(t, t.startPeriod)),
          ),
          detail('Rent balance through this month', money(rentDue)),
          detail(
            'Total recorded amount due',
            depositDue == null
                ? 'Complete deposit terms first'
                : money(rentDue + depositDue),
          ),
          if (store.creditFor(t) > 0)
            detail(
              'Received rent money awaiting allocation',
              money(store.creditFor(t)),
            ),
          const Text(
            'The deposit is refundable security, subject to lawful supported deductions and applicable rules. It is due before occupation under the agreed terms and is not rent. Pending reports do not reduce these recorded balances. Check any unallocated money before collecting more.',
          ),
        ],
      ),
    );
  }
}
