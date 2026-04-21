import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('11 Services Catalog Fetch Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('fetches services with district/city query params', () async {
      print('--- TEST START ---');
      print('Test: fetches services with district/city query params');
      print('Input Payload: {"district":"Kathmandu","city":"Lalitpur"}');
      print(
          'Expected: query params should be included and one Plumbing service should return');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {'id': 1, 'title': 'Plumbing', 'provider_name': 'Hari'}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final services = await ApiService.getServices(
        district: 'Kathmandu',
        city: 'Lalitpur',
      );

      // Assert
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/services/');
      expect(capturedRequest.url.queryParameters['district'], 'Kathmandu');
      expect(capturedRequest.url.queryParameters['city'], 'Lalitpur');
      print('Actual Result: $services');
      print('Actual Query Params: ${capturedRequest.url.queryParameters}');
      expect(services, hasLength(1));
      expect((services.first as Map<String, dynamic>)['title'], 'Plumbing');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns empty list when success payload is not a list', () async {
      print('--- TEST START ---');
      print('Test: returns empty list when success payload is not a list');
      print('Input Mock Data: {"status":200,"body":"not-json-list"}');
      print('Expected: should return empty list');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response('not-json-list', 200);
      }));

      // Act
      final services = await ApiService.getServices();
      print('Actual Result: $services');

      // Assert
      expect(services, isEmpty);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces backend status errors from services endpoint', () async {
      print('--- TEST START ---');
      print('Test: surfaces backend status errors from services endpoint');
      print(
          'Input Mock Data: {"status":503,"message":"Service catalog unavailable"}');
      print('Expected: should throw service catalog unavailable error');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Service catalog unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.getServices(),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('Service catalog unavailable');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failures to friendly message', () async {
      print('--- TEST START ---');
      print('Test: maps network failures to friendly message');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.getServices(),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Cannot reach backend');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
