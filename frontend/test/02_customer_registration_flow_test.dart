import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('02 Customer Registration Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('sends expected payload and parses successful response', () async {
      print('--- TEST START ---');
      print('Test: sends expected payload and parses successful response');
      print(
          'Input Payload: {"username":"sita","email":"sita@example.com","phone":"9800000000","district":" Kathmandu ","city":" Kirtipur ","referral_code":"REF123"}');
      print(
          'Expected: customer registration request should be normalized and successful');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Registration successful'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.registerCustomer(
        username: 'sita',
        email: 'sita@example.com',
        phone: '9800000000',
        password: 'SecurePass1!',
        passwordConfirm: 'SecurePass1!',
        district: ' Kathmandu ',
        city: ' Kirtipur ',
        referralCode: 'REF123',
      );

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/auth/register/customer/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['username'], 'sita');
      expect(payload['email'], 'sita@example.com');
      expect(payload['phone'], '9800000000');
      expect(payload['district'], 'Kathmandu');
      expect(payload['city'], 'Kirtipur');
      expect(payload['referral_code'], 'REF123');
      expect(result['message'], 'Registration successful');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces field-level validation errors', () async {
      print('--- TEST START ---');
      print('Test: surfaces field-level validation errors');
      print('Input Payload: {"username":"sita","email":""}');
      print(
          'Input Mock Data: {"status":400,"email":["This field is required."]}');
      print('Expected: should throw field-level validation message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({
            'email': ['This field is required.']
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.registerCustomer(
          username: 'sita',
          email: '',
          phone: '9800000000',
          password: 'SecurePass1!',
          passwordConfirm: 'SecurePass1!',
          district: 'Kathmandu',
          city: 'Kirtipur',
        ),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('email: This field is required.');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces duplicate email backend error', () async {
      print('--- TEST START ---');
      print('Test: surfaces duplicate email backend error');
      print('Input Payload: {"email":"sita@example.com"}');
      print('Input Mock Data: {"status":409,"message":"Email already exists"}');
      print('Expected: should throw duplicate email message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Email already exists'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.registerCustomer(
          username: 'sita',
          email: 'sita@example.com',
          phone: '9800000000',
          password: 'SecurePass1!',
          passwordConfirm: 'SecurePass1!',
          district: 'Kathmandu',
          city: 'Kirtipur',
        ),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Email already exists');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failure to friendly message', () async {
      print('--- TEST START ---');
      print('Test: maps network failure to friendly message');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.registerCustomer(
          username: 'sita',
          email: 'sita@example.com',
          phone: '9800000000',
          password: 'SecurePass1!',
          passwordConfirm: 'SecurePass1!',
          district: 'Kathmandu',
          city: 'Kirtipur',
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
