import 'package:flutter_test/flutter_test.dart';

bool _isProviderBackedService(Map<String, dynamic> service) {
  final providerId = service['provider_id'];
  final providerName = (service['provider_name'] ?? '').toString().trim();
  final title = (service['title'] ?? '').toString().trim();

  final serviceDeleted =
      service['is_deleted'] == true || service['deleted_at'] != null;
  final providerDeleted = service['provider_is_deleted'] == true ||
      service['provider_deleted_at'] != null;
  final providerIsProvider = service['provider_is_provider'];

  if (serviceDeleted || providerDeleted) return false;
  if (providerIsProvider == false) return false;
  if (providerId == null || providerName.isEmpty || title.isEmpty) return false;

  return true;
}

List<Map<String, dynamic>> _filterValidServices(
    List<Map<String, dynamic>> rows) {
  return rows.where(_isProviderBackedService).toList();
}

void main() {
  group('12 Service Provider Filtering Logic', () {
    test('keeps only valid provider-backed rows', () {
      print('--- TEST START ---');
      print('Test: keeps only valid provider-backed rows');

      // Arrange
      final rows = <Map<String, dynamic>>[
        {
          'id': 1,
          'title': 'Plumbing',
          'provider_id': 99,
          'provider_name': 'Hari',
          'provider_is_provider': true,
          'is_deleted': false,
        },
        {
          'id': 2,
          'title': 'Invalid Missing Provider Name',
          'provider_id': 100,
          'provider_name': '',
          'provider_is_provider': true,
        },
      ];
      print('Input Payload: $rows');
      print('Expected: exactly one valid row with id=1');

      // Act
      final filtered = _filterValidServices(rows);
      print('Actual Result: $filtered');

      // Assert
      expect(filtered, hasLength(1));
      expect(filtered.first['id'], 1);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('removes deleted service rows', () {
      print('--- TEST START ---');
      print('Test: removes deleted service rows');

      // Arrange
      final rows = <Map<String, dynamic>>[
        {
          'id': 10,
          'title': 'Electrical',
          'provider_id': 1,
          'provider_name': 'Sita',
          'provider_is_provider': true,
          'is_deleted': true,
        }
      ];
      print('Input Payload: $rows');
      print('Expected: filtered list should be empty');

      // Act
      final filtered = _filterValidServices(rows);
      print('Actual Result: $filtered');

      // Assert
      expect(filtered, isEmpty);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('removes rows where provider is deleted', () {
      print('--- TEST START ---');
      print('Test: removes rows where provider is deleted');

      // Arrange
      final rows = <Map<String, dynamic>>[
        {
          'id': 22,
          'title': 'Carpentry',
          'provider_id': 2,
          'provider_name': 'Mina',
          'provider_is_provider': true,
          'provider_deleted_at': '2025-01-01T00:00:00Z',
        }
      ];
      print('Input Payload: $rows');
      print('Expected: filtered list should be empty');

      // Act
      final filtered = _filterValidServices(rows);
      print('Actual Result: $filtered');

      // Assert
      expect(filtered, isEmpty);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('removes rows where linked account is not a provider role', () {
      print('--- TEST START ---');
      print('Test: removes rows where linked account is not a provider role');

      // Arrange
      final rows = <Map<String, dynamic>>[
        {
          'id': 33,
          'title': 'Cleaning',
          'provider_id': 3,
          'provider_name': 'Ram',
          'provider_is_provider': false,
        }
      ];
      print('Input Payload: $rows');
      print('Expected: filtered list should be empty');

      // Act
      final filtered = _filterValidServices(rows);
      print('Actual Result: $filtered');

      // Assert
      expect(filtered, isEmpty);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
