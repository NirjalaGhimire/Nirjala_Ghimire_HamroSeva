import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('03 Provider Registration Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('submits multipart provider registration payload', () async {
      print('--- TEST START ---');
      print('Test: submits multipart provider registration payload');
      print(
          'Input Payload: {"username":"provider1","email":"provider1@example.com","profession":"Electrician","district":" Kathmandu ","city":" Tokha ","services_offered":[{"category_id":2,"title":"House Wiring"}]}');
      print(
          'Expected: multipart request should include provider fields and services');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Provider registration submitted'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.registerProvider(
        username: 'provider1',
        email: 'provider1@example.com',
        phone: '9811111111',
        password: 'SecurePass1!',
        passwordConfirm: 'SecurePass1!',
        profession: 'Electrician',
        district: ' Kathmandu ',
        city: ' Tokha ',
        idDocumentType: 'citizenship',
        idDocumentNumber: '01-12345',
        certificateNumber: 'CERT-9',
        servicesOffered: [
          {'category_id': 2, 'title': 'House Wiring'}
        ],
      );

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/auth/register/provider/');
      expect(
        capturedRequest.headers['content-type'] ?? '',
        contains('multipart/form-data'),
      );
      print('Actual Result: $result');
      final bodySnippet = capturedRequest.body.length > 120
          ? '${capturedRequest.body.substring(0, 120)}...'
          : capturedRequest.body;
      print('Actual Request Body Snippet: $bodySnippet');
      expect(capturedRequest.body, contains('name="username"'));
      expect(capturedRequest.body, contains('provider1'));
      expect(capturedRequest.body, contains('name="district"'));
      expect(capturedRequest.body, contains('Kathmandu'));
      expect(capturedRequest.body, contains('name="city"'));
      expect(capturedRequest.body, contains('Tokha'));
      expect(capturedRequest.body, contains('name="services_offered"'));
      expect(capturedRequest.body, contains('House Wiring'));
      expect(result['message'], 'Provider registration submitted');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces server-side provider validation errors', () async {
      print('--- TEST START ---');
      print('Test: surfaces server-side provider validation errors');
      print('Input Payload: {"profession":""}');
      print(
          'Input Mock Data: {"status":400,"message":"Profession is required"}');
      print('Expected: should throw profession required message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Profession is required'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.registerProvider(
          username: 'provider1',
          email: 'provider1@example.com',
          phone: '9811111111',
          password: 'SecurePass1!',
          passwordConfirm: 'SecurePass1!',
          profession: '',
          district: 'Kathmandu',
          city: 'Tokha',
        ),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Profession is required');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failures for provider registration', () async {
      print('--- TEST START ---');
      print('Test: maps network failures for provider registration');
      print('Input Mock Data: SocketException("Network is unreachable")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Network is unreachable');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.registerProvider(
          username: 'provider1',
          email: 'provider1@example.com',
          phone: '9811111111',
          password: 'SecurePass1!',
          passwordConfirm: 'SecurePass1!',
          profession: 'Electrician',
          district: 'Kathmandu',
          city: 'Tokha',
        ),
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
