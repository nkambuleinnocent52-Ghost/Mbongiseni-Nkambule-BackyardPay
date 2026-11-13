import 'package:flutter_test/flutter_test.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';
import 'package:mbongiseni_nkambule_apt_application/services/property_map.dart';

void main() {
  test('map searches the full supplied address without claiming a verified GPS pin', () {
    final p = RentalProperty.fromJson({
      'id': 'property',
      'landlordId': 'owner',
      'name': 'Atmasphere',
      'address': '19 Saint Georges Rd',
      'suburb': 'Southernwood',
      'city': 'East London',
      'postalCode': '5201',
      'rooms': 10,
      'rentCents': 150000,
      'dueDay': 1,
      'code': 'BP-test',
    });
    final uri = propertyMapUri(p);
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], p.fullAddress);
    expect(uri.queryParameters['query'], contains('East London'));
  });
}
