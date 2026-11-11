import 'package:flutter/material.dart';

import '../../ui/design.dart';

/// The same payment policy is shown to landlords and tenants.
class RentalPaymentRules extends StatelessWidget {
  const RentalPaymentRules({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(
      spacing: 24,
      runSpacing: 8,
      children: const [
        Text(
          'Monthly rent: due on the 1st',
          style: TextStyle(
            color: Palette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Security deposit: once, within 10 days of move-in',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
