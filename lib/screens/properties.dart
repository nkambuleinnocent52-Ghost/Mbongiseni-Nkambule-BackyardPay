import 'room_availability.dart';
import '../data/research_ledger.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'common.dart';
import '../ui/design.dart';

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
              subtitle: Text('${p.fullAddress}\nCode: ${p.code}'),
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
      help: 'Due day is 1–28. Rent and due-day changes apply to new tenancies; existing tenancy terms stay unchanged. Specify the agreed refundable security deposit (0 if none). It is separate from rent and due before occupation; a setting does not record money received. No payment processing is performed.',
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
          'Monthly rent (rand)',
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
        FieldSpec(
          'due',
          'Due day of month (1–28)',
          initial: '${property?.dueDay ?? 1}',
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
          dueDay: int.tryParse(v['due']!) ?? 0,
          prorateFirstMonth: v['proration'] == 'Prorate actual calendar days',
          securityDepositCents: parseDeposit(v['deposit']!),
        );
      },
    ),
  );
}

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  const PropertyDetailsScreen({super.key, required this.propertyId});
  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  bool locating = false;
  Future<void> locate() async {
    final store = StoreScope.of(context);
    setState(() => locating = true);
    await perform(context, () async {
      if (!await Geolocator.isLocationServiceEnabled())
        throw StateError('Turn on location services and try again.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission was not granted. Allow it in browser/device settings.',
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save this property location?'),
          content: Text(
            'Only capture while you are at the property.\n${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}\nEstimated accuracy: ${pos.accuracy.round()} metres',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save location'),
            ),
          ],
        ),
      );
      if (confirmed == true)
        await store.saveLocation(
          widget.propertyId,
          pos.latitude,
          pos.longitude,
        );
    });
    if (mounted) setState(() => locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.properties
        .where((p) => p.id == widget.propertyId)
        .firstOrNull;
    if (p == null)
      return const PageShell(title: 'Property removed', children: []);
    final landlord = store.currentUser!.role == Role.landlord;
    return PageShell(
      title: 'Property details',
      children: [
        heading(p.name),
        if (landlord) RoomAvailability(propertyId: p.id),
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
              detail('Address', p.fullAddress),
              detail('Total rooms', '${p.rooms}'),
              if (landlord)
                detail(
                  'Available for a new tenancy',
                  '${store.availableRoomNumbers(p.id).length}',
                ),
              detail('Rent for new tenants', money(p.rentCents)),
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
              detail('Due day', '${p.dueDay}'),
              SelectableText('Property code: ${p.code}'),
              if (landlord)
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: p.code));
                    if (context.mounted) tell(context, 'Property code copied.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy property code'),
                ),
            ],
          ),
        ),
        heading('Property location'),
        if (p.latitude == null)
          const Text('No device location has been captured yet.')
        else ...[
          SelectableText(
            '${p.latitude!.toStringAsFixed(6)}, ${p.longitude!.toStringAsFixed(6)}',
          ),
          action(
            'View on map',
            () => perform(context, () async {
              final uri = Uri.https('www.google.com', '/maps/search/', {
                'api': '1',
                'query': '${p.latitude},${p.longitude}',
              });
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
                throw StateError('The map could not be opened.');
            }),
            icon: Icons.map_outlined,
          ),
        ],
        if (landlord) ...[
          action(
            locating ? 'Finding your location…' : 'Capture current location',
            locating ? null : locate,
            icon: Icons.my_location,
          ),
          const Text(
            'Use HTTPS in the browser and allow location access. Capture only while at your property.',
          ),
          action(
            'Edit property',
            () => editProperty(context, p),
            icon: Icons.edit_outlined,
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
