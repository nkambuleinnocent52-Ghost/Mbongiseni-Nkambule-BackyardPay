import 'room_rents.dart';
import '../rentals/simple_rentals.dart';
import 'room_availability.dart';
import '../../data/research_ledger.dart';

import 'package:flutter/material.dart';

import '../../services/property_map.dart';
import '../rentals/property_terms.dart';

import '../../models/models.dart';
import '../shared/common.dart';
import '../../ui/design.dart';

class PropertiesScreen extends StatelessWidget {
  const PropertiesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return PageShell(
      title: 'My properties',
      children: [
        action(
          'Add property',
          () => editProperty(context),
          icon: Icons.add_home_outlined,
        ),
        if (store.properties.isEmpty)
          panel(const Text('No properties yet. Add your first property.')),
        for (final p in store.properties)
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text(p.fullAddress),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  open(context, PropertyDetailsScreen(propertyId: p.id)),
            ),
          ),
      ],
    );
  }
}

void editProperty(BuildContext context, [RentalProperty? property]) {
  final store = StoreScope.of(context);
  open(
    context,
    EditorPage(
      title: property == null ? 'Add property' : 'Edit property',
      help: 'Rent is due on the 1st. Set the one-off deposit separately; new tenants have 10 days from move-in to pay it.',
      preview: (context, v) {
        try {
          final cents = parseMoney(v['rent']!);
          final now = DateTime.now();
          return panel(
            Text(
              'Daily equivalent this month (${daysInMonth(now)} days): approximately ${money((cents / daysInMonth(now)).round())}. The exact move-in month determines the calculation; daily amounts are not rounded before multiplying.',
            ),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      },
      fields: [
        FieldSpec('name', 'Property name', initial: property?.name ?? ''),
        FieldSpec(
          'address',
          'Street address / stand number',
          initial: property?.address ?? '',
        ),
        FieldSpec('suburb', 'Suburb / area', initial: property?.suburb ?? ''),
        FieldSpec('city', 'Town / city', initial: property?.city ?? ''),
        FieldSpec(
          'postal',
          'Postal code (4 digits)',
          initial: property?.postalCode ?? '',
        ),
        FieldSpec(
          'rooms',
          'Total rooms',
          initial: '${property?.rooms ?? 1}',
          numeric: true,
        ),
        FieldSpec(
          'rent',
          'Default monthly rent (rand)',
          initial: ((property?.rentCents ?? 150000) / 100).toStringAsFixed(2),
          numeric: true,
        ),
        FieldSpec(
          'proration',
          'First month billing',
          initial: (property?.prorateFirstMonth ?? true)
              ? 'Prorate actual calendar days'
              : 'Charge full month',
          options: const ['Prorate actual calendar days', 'Charge full month'],
        ),
        FieldSpec(
          'deposit',
          'Security deposit per new tenancy (rand; 0 if none)',
          initial: property?.securityDepositCents == null
              ? ''
              : (property!.securityDepositCents! / 100).toStringAsFixed(2),
          numeric: true,
        ),
      ],
      save: (v) async {
        await store.saveProperty(
          id: property?.id,
          name: v['name']!,
          address: v['address']!,
          suburb: v['suburb']!,
          city: v['city']!,
          postalCode: v['postal']!,
          rooms: int.tryParse(v['rooms']!) ?? 0,
          rentCents: parseMoney(v['rent']!),
          dueDay: 1,
          prorateFirstMonth: v['proration'] == 'Prorate actual calendar days',
          securityDepositCents: parseDeposit(v['deposit']!),
        );
      },
    ),
  );
}

class PropertyDetailsScreen extends StatelessWidget {
  final String propertyId;
  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.properties.where((p) => p.id == propertyId).firstOrNull;
    if (p == null)
      return const PageShell(title: 'Property removed', children: []);
    final landlord = store.currentUser!.role == Role.landlord;
    return PageShell(
      title: 'Property details',
      actions: [
        if (landlord)
          IconButton(
            tooltip: 'Edit property',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => editProperty(context, p),
          ),
      ],
      children: [
        heading(p.name),
        if (landlord) RoomAvailability(propertyId: p.id),
        if (landlord) RoomRentEditor(propertyId: p.id),
        if (landlord)
          RentalSection(
            title: 'Message tenants',
            subtitle: 'One update for this property',
            children: [PropertyMessage(propertyId: p.id)],
          ),
        if (landlord && p.city.isEmpty)
          panel(
            const Text(
              'Complete this property’s street address, suburb, town and postal code so tenants can identify the rental clearly.',
              style: TextStyle(color: Palette.goldLight, height: 1.8),
            ),
          ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => perform(context, () => openPropertyMap(p)),
                icon: const Icon(Icons.location_on_outlined),
                label: Text(p.fullAddress),
              ),
              detail('Total rooms', '${p.rooms}'),
              if (landlord)
                detail(
                  'Available for a new tenancy',
                  '${store.availableRoomNumbers(p.id).length}',
                ),
              detail('Default monthly rent', money(p.rentCents)),
              detail(
                'Security deposit for new tenants',
                p.securityDepositCents == null
                    ? 'Not specified — set before onboarding'
                    : money(p.securityDepositCents!),
              ),
              detail(
                'First month billing',
                p.prorateFirstMonth
                    ? 'Actual calendar days from move-in, inclusive'
                    : 'Full month by agreement',
              ),
              detail('Monthly rent due', '1st of every month'),
              if (landlord)
                const Text(
                  'Assign the tenant an available room first. Share the private invitation from that tenant’s rental record; property codes cannot be used for account registration.',
                ),
            ],
          ),
        ),
        if (landlord) ...[
          TextButton.icon(
            onPressed: () =>
                open(context, PropertyTermsScreen(propertyId: p.id)),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Property terms'),
          ),
          if (!store.tenancies.any((t) => t.propertyId == p.id))
            TextButton(
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete this empty property?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (yes == true &&
                    context.mounted &&
                    await perform(context, () => store.deleteProperty(p.id)) &&
                    context.mounted)
                  Navigator.pop(context);
              },
              child: const Text('Delete empty property'),
            ),
        ],
      ],
    );
  }
}
