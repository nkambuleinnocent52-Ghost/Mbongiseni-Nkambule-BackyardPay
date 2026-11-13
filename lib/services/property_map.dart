import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Search the address supplied by the landlord. This is not a verified map pin.
Uri propertyMapUri(RentalProperty property) {
  final address = property.fullAddress.trim();
  if (address.isEmpty)
    throw StateError('The landlord has not added an address yet.');
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': address,
  });
}

Future<void> openPropertyMap(RentalProperty property) async {
  if (!await launchUrl(
    propertyMapUri(property),
    mode: LaunchMode.externalApplication,
  )) {
    throw StateError('Google Maps could not be opened.');
  }
}
